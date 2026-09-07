import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineWorkersConfig, readD1Migrations } from "@cloudflare/vitest-pool-workers/config";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineWorkersConfig(async () => {
  const migrations = await readD1Migrations(path.join(__dirname, "migrations"));

  return {
    test: {
      // POST /analyze integration tests call the real AI Gateway; default 5s is too tight under parallel load.
      testTimeout: 120_000,
      setupFiles: ["tests/apply-d1-migrations.ts"],
      poolOptions: {
        workers: {
          wrangler: { configPath: "./wrangler.toml", environment: "dev" },
          miniflare: {
            d1Databases: {
              DB: "test-db",
            },
            kvNamespaces: ["REEF_KV"],
            bindings: {
              ENVIRONMENT: "test",
              FREE_ANALYSIS_LIMIT: "3",
              FREE_TIER_LIMIT: "3",
              TEST_MIGRATIONS: migrations,
              // .dev.vars may define APPLE_* for wrangler dev; tests expect DeviceCheck off unless overridden per test.
              APPLE_KEY_ID: "",
              APPLE_PRIVATE_KEY: "",
              APPLE_TEAM_ID: "",
            },
          },
        },
      },
      include: ["tests/**/*.test.ts"],
      exclude: ["node_modules/**", "dist/**"],
      reporters: ["verbose"],
      coverage: {
        provider: "v8",
        reporter: ["text", "json", "html"],
        exclude: ["node_modules/**", "tests/**", "vitest.config.ts"],
      },
    },
  };
});
