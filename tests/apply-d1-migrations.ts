/**
 * Applies all SQL migrations in ./migrations to the test D1 binding (env.DB) once per test file.
 * The Vitest plugin isolates storage per test *file*: tests within a file share D1/KV state, so
 * suites use unique device ids / client IPs per test instead of relying on per-test rollback.
 * Migrations come from the TEST_MIGRATIONS binding injected in vitest.config.ts.
 */
import { applyD1Migrations, env } from 'cloudflare:test';
import { beforeAll } from 'vitest';

beforeAll(async () => {
  const migrations = env.TEST_MIGRATIONS;
  if (!migrations?.length) {
    throw new Error('TEST_MIGRATIONS binding missing; check vitest.config.ts');
  }
  await applyD1Migrations(env.DB, migrations);
});
