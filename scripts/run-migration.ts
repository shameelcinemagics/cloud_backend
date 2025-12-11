/**
 * Safe migration runner that applies SQL files in supabase/migrations
 * using a direct PG connection, skipping files already recorded and
 * tolerating "already exists" errors on reruns.
 */
import "dotenv/config";
import { readdir, readFile } from "fs/promises";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { Client } from "pg";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DB_URL =
  (process.env as Record<string, string | undefined>).SUPABASE_DB_URL ||
  (process.env as Record<string, string | undefined>).DATABASE_URL;

if (!DB_URL) {
  throw new Error("Missing SUPABASE_DB_URL or DATABASE_URL in environment.");
}

type Migration = {
  version: string;
  description: string;
  filename: string;
  sql: string;
};

async function loadMigrations(): Promise<Migration[]> {
  const dir = join(__dirname, "..", "supabase", "migrations");
  const files = await readdir(dir);
  const sqlFiles = files.filter((f) => f.endsWith(".sql"));

  const migrations: Migration[] = [];

  for (const file of sqlFiles) {
    const match = file.match(/^(\d{14})_(.+)\.sql$/);
    if (!match) continue;
    const [, version, name] = match;
    const sql = await readFile(join(dir, file), "utf8");
    migrations.push({
      version,
      description: name.replace(/_/g, " "),
      filename: file,
      sql,
    });
  }

  migrations.sort((a, b) => a.version.localeCompare(b.version));
  return migrations;
}

async function main() {
  const client = new Client({ connectionString: DB_URL });
  await client.connect();

  await client.query(`
    create table if not exists public.migrations (
      version text primary key,
      description text,
      applied_at timestamptz default now()
    )
  `);

  const appliedRes = await client.query<{
    version: string;
  }>("select version from public.migrations");
  const applied = new Set(appliedRes.rows.map((r) => r.version));

  const migrations = await loadMigrations();
  const pending = migrations.filter((m) => !applied.has(m.version));

  console.log("🚀 Safe migration runner\n");
  console.log(`Total migrations: ${migrations.length}`);
  console.log(`Applied: ${applied.size}`);
  console.log(`Pending: ${pending.length}\n`);

  for (const m of pending) {
    console.log(`📦 Applying ${m.filename} (${m.description})`);
    await client.query("begin");
    try {
      await client.query(m.sql);
      await client.query(
        `insert into public.migrations (version, description) values ($1, $2)
         on conflict (version) do update set description = excluded.description, applied_at = now()`,
        [m.version, m.description]
      );
      await client.query("commit");
      console.log("   ✅ applied");
    } catch (err: any) {
      await client.query("rollback");
      const code = err?.code as string | undefined;
      const msg = (err?.message as string | undefined) || "";
      const duplicate =
        code === "42P07" || // duplicate_table
        code === "42710" || // duplicate_object/index/trigger
        code === "42723" || // duplicate_function
        msg.toLowerCase().includes("already exists");
      const missing =
        code === "42704" || // undefined object (constraint/index/trigger)
        msg.toLowerCase().includes("does not exist");

      if (duplicate || missing) {
        console.warn(
          "   ⚠️  benign object error (duplicate/missing), marking as applied and continuing"
        );
        await client.query("begin");
        await client.query(
          `insert into public.migrations (version, description) values ($1, $2)
           on conflict (version) do update set description = excluded.description, applied_at = now()`,
          [m.version, m.description]
        );
        await client.query("commit");
        continue;
      }

      console.error("   ❌ failed:", err);
      await client.end();
      process.exit(1);
    }
  }

  console.log("\n✨ Done");
  await client.end();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
