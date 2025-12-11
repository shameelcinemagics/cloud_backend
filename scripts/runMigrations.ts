// Script to run database migrations
import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import { readdir, readFile } from "fs/promises";
import { join } from "path";
import { fileURLToPath } from "url";
import { dirname } from "path";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env as Record<
  string,
  string
>;
const DB_URL =
  (process.env as Record<string, string | undefined>).SUPABASE_DB_URL ||
  (process.env as Record<string, string | undefined>).DATABASE_URL;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

interface Migration {
  version: string;
  filename: string;
  description: string;
  sql: string;
}

async function getAppliedMigrations(): Promise<Set<string>> {
  try {
    const { data, error } = await supabase.from("migrations").select("version");

    if (error) {
      // If table doesn't exist yet, return empty set
      if (
        error.message.includes("does not exist") ||
        error.message.includes("schema cache")
      ) {
        return new Set();
      }
      throw error;
    }

    return new Set(data?.map((m) => m.version) || []);
  } catch (err) {
    console.log(
      "No migration tracking table found. Will create on first migration."
    );
    return new Set();
  }
}

async function getMigrationFiles(): Promise<Migration[]> {
  const migrationsDir = join(__dirname, "..", "supabase", "migrations");

  try {
    const files = await readdir(migrationsDir);
    const sqlFiles = files.filter(
      (f) => f.endsWith(".sql") && !f.endsWith("_down.sql")
    );

    const migrations: Migration[] = [];

    for (const file of sqlFiles) {
      const filePath = join(migrationsDir, file);
      const sql = await readFile(filePath, "utf-8");

      // Extract version from filename (YYYYMMDDHHMMSS_description.sql)
      const match = file.match(/^(\d{14})_(.+)\.sql$/);
      let version: string;
      let description: string;

      if (match) {
        [, version, description] = match;
      } else if (file === "dev_schema.sql") {
        // Treat dev schema as a one-off snapshot
        version = "dev_schema";
        description = "dev schema snapshot";
      } else {
        console.warn(`⚠️  Skipping invalid migration filename: ${file}`);
        continue;
      }

      migrations.push({
        version,
        filename: file,
        description: description.replace(/_/g, " "),
        sql,
      });
    }

    // Sort by version
    migrations.sort((a, b) => a.version.localeCompare(b.version));

    return migrations;
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") {
      console.error("❌ Migrations directory not found:", migrationsDir);
      console.log("Create it with: mkdir -p supabase/migrations");
    }
    throw err;
  }
}

async function runMigration(migration: Migration): Promise<void> {
  console.log(`\n📦 Applying migration: ${migration.filename}`);
  console.log(`   Description: ${migration.description}`);

  try {
    // Execute the SQL (Supabase doesn't expose a direct SQL execution method,
    // so we use the REST API via rpc or execute via psql)
    // For now, we'll use a workaround with a function

    // Split by semicolons and execute each statement
    const statements = migration.sql
      .split(";")
      .map((s) => s.trim())
      .filter((s) => s.length > 0 && !s.startsWith("--"));

    for (const statement of statements) {
      if (statement.includes("migrations")) {
        // Handle migration tracking via Supabase client
        const versionMatch = statement.match(
          /values\s*\('(\d+)',\s*'([^']+)'\)/i
        );
        if (versionMatch) {
          const [, version, description] = versionMatch;
          await supabase
            .from("migrations")
            .upsert({ version, description }, { onConflict: "version" });
        }
      }
    }

    console.log("   ✅ Migration applied successfully");
  } catch (err) {
    console.error("   ❌ Migration failed:", err);
    throw err;
  }
}

async function main() {
  console.log("🚀 VendCloud Migration Runner\n");
  console.log("📊 Connecting to Supabase...");

  try {
    // Test connection
    const { error: connectionError } = await supabase
      .from("migrations")
      .select("version")
      .limit(1);

    if (
      connectionError &&
      !connectionError.message.includes("does not exist") &&
      !connectionError.message.includes("schema cache")
    ) {
      throw new Error(`Connection failed: ${connectionError.message}`);
    }

    console.log("✅ Connected to Supabase\n");

    // Get applied and pending migrations
    const appliedMigrations = await getAppliedMigrations();
    const allMigrations = await getMigrationFiles();
    const pendingMigrations = allMigrations.filter(
      (m) => !appliedMigrations.has(m.version)
    );

    console.log(`📋 Migration Status:`);
    console.log(`   Total migrations: ${allMigrations.length}`);
    console.log(`   Applied: ${appliedMigrations.size}`);
    console.log(`   Pending: ${pendingMigrations.length}\n`);

    if (pendingMigrations.length === 0) {
      console.log("✨ All migrations are up to date!");
      return;
    }

    if (!DB_URL) {
      console.log(
        "⚠️  No database connection string provided. Set SUPABASE_DB_URL or DATABASE_URL to apply automatically."
      );
      console.log("   Example: SUPABASE_DB_URL=postgres://user:pass@host:5432/db");
      console.log(
        "   Or apply manually via Supabase Dashboard SQL editor using the files below.\n"
      );

      console.log("📝 Pending migrations to apply manually:\n");
      for (const migration of pendingMigrations) {
        console.log(`   📄 ${migration.filename}`);
        console.log(`      ${migration.description}`);
      }
      return;
    }

    const { Client } = await import("pg").catch((err) => {
      console.error(
        "❌ The 'pg' package is required to apply migrations automatically."
      );
      console.error("   Install with: npm install pg");
      throw err;
    });

    const client = new Client({ connectionString: DB_URL });
    await client.connect();

    await client.query(`
      create table if not exists public.migrations (
        version text primary key,
        description text,
        applied_at timestamptz default now()
      )
    `);

    for (const migration of pendingMigrations) {
      console.log(`\n📦 Applying migration: ${migration.filename}`);
      console.log(`   Description: ${migration.description}`);

      try {
        await client.query("begin");
        await client.query(migration.sql);
        await client.query(
          `insert into public.migrations (version, description)
           values ($1, $2)
           on conflict (version) do update
             set description = excluded.description,
                 applied_at = now()`,
          [migration.version, migration.description]
        );
        await client.query("commit");
        console.log("   ✅ Migration applied successfully");
      } catch (err) {
        await client.query("rollback");
        console.error("   ❌ Migration failed:", err);
        throw err;
      }
    }

    await client.end();
    console.log("\n✨ All migrations applied.");
  } catch (err) {
    console.error("\n❌ Error:", err instanceof Error ? err.message : err);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
