/**
 * Copy data from dev to prod for selected tables only when prod is empty.
 * - Compares column lists; skips if columns differ.
 * - Skips tables that already have rows in prod.
 *
 * Usage:
 *   DEV_DB_URL=postgres://... PROD_DB_URL=postgres://... npx tsx scripts/copyDevToProd.ts
 *   # optionally choose tables via comma-separated CLI arg:
 *   DEV_DB_URL=... PROD_DB_URL=... npx tsx scripts/copyDevToProd.ts pages,roles,role_page_perms
 */
import "dotenv/config";
import { Client } from "pg";

const DEV_URL = process.env.DEV_DB_URL;
const PROD_URL = process.env.PROD_DB_URL;

if (!DEV_URL || !PROD_URL) {
  throw new Error("Set DEV_DB_URL and PROD_DB_URL in the environment.");
}

const defaultTables = [
  "pages",
  "roles",
  "role_page_perms",
  "user_page_perms",
  "user_roles",
];

const tablesArg = process.argv[2];
const tables = tablesArg ? tablesArg.split(",").map((t) => t.trim()).filter(Boolean) : defaultTables;

function qIdent(id: string) {
  return `"${id.replace(/"/g, '""')}"`;
}

async function getColumns(client: Client, table: string): Promise<string[]> {
  const { rows } = await client.query<{
    column_name: string;
  }>(
    `select column_name
     from information_schema.columns
     where table_schema = 'public' and table_name = $1
     order by ordinal_position`,
    [table]
  );
  return rows.map((r) => r.column_name);
}

async function getCount(client: Client, table: string): Promise<number> {
  const { rows } = await client.query<{ count: string }>(`select count(*)::bigint as count from ${qIdent(table)}`);
  return Number(rows[0].count);
}

async function fetchData(client: Client, table: string, columns: string[]) {
  const cols = columns.map(qIdent).join(", ");
  const { rows } = await client.query(`select ${cols} from ${qIdent(table)}`);
  return rows;
}

async function insertBatch(client: Client, table: string, columns: string[], rows: any[]) {
  if (!rows.length) return;
  const colNames = columns.map(qIdent).join(", ");
  const chunkSize = 200;
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const values: string[] = [];
    const params: any[] = [];
    chunk.forEach((row, idx) => {
      const paramIndexes = columns.map((_, cIdx) => `$${params.length + cIdx + 1}`);
      params.push(...columns.map((c) => row[c]));
      values.push(`(${paramIndexes.join(", ")})`);
    });
    const sql = `insert into ${qIdent(table)} (${colNames}) values ${values.join(", ")}`;
    await client.query(sql, params);
  }
}

async function copyTable(dev: Client, prod: Client, table: string) {
  console.log(`\n→ ${table}`);
  const prodCount = await getCount(prod, table);
  if (prodCount > 0) {
    console.log("   skip: prod has data");
    return;
  }

  const [devCols, prodCols] = await Promise.all([getColumns(dev, table), getColumns(prod, table)]);
  if (devCols.join(",") !== prodCols.join(",")) {
    console.log("   skip: column mismatch");
    console.log("   dev :", devCols);
    console.log("   prod:", prodCols);
    return;
  }

  const data = await fetchData(dev, table, devCols);
  if (!data.length) {
    console.log("   nothing to copy");
    return;
  }

  // Filter rows based on existing auth.users when user_id is present
  let filtered = data;
  if (devCols.includes("user_id")) {
    const { rows: userRows } = await prod.query<{ id: string }>("select id from auth.users");
    const userSet = new Set(userRows.map((r) => r.id));
    filtered = data.filter((r) => !r.user_id || userSet.has(r.user_id));
    const skipped = data.length - filtered.length;
    if (skipped > 0) {
      console.log(`   skipping ${skipped} rows due to missing user_id in prod`);
    }
    if (!filtered.length) {
      console.log("   nothing to copy after filtering");
      return;
    }
  }

  await prod.query("begin");
  try {
    await insertBatch(prod, table, devCols, filtered);
    await prod.query("commit");
    console.log(`   copied ${filtered.length} rows`);
  } catch (err) {
    await prod.query("rollback");
    throw err;
  }
}

async function main() {
  const dev = new Client({ connectionString: DEV_URL });
  const prod = new Client({ connectionString: PROD_URL });
  await dev.connect();
  await prod.connect();

  try {
    for (const table of tables) {
      await copyTable(dev, prod, table);
    }
  } finally {
    await dev.end();
    await prod.end();
  }
  console.log("\nDone.");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
