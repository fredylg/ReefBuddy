/**
 * Applies all SQL migrations in ./migrations to the test D1 binding (env.DB).
 * Required because Vitest/Miniflare uses an isolated DB, not wrangler's local SQLite file.
 */
import { applyD1Migrations, env } from "cloudflare:test";
import { beforeAll } from "vitest";

beforeAll(async () => {
  const migrations = (env as unknown as { TEST_MIGRATIONS: { name: string; queries: string[] }[] })
    .TEST_MIGRATIONS;
  if (!migrations?.length) {
    throw new Error("TEST_MIGRATIONS binding missing; check vitest.config.ts");
  }
  await applyD1Migrations(env.DB, migrations);
});
