import path from "node:path";
import { fileURLToPath } from "node:url";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig(async () => {
  const migrations = await readD1Migrations(path.join(__dirname, "migrations"));

  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: "./wrangler.toml", environment: "dev" },
        miniflare: {
          d1Databases: { DB: "test-db" },
          kvNamespaces: ["REEF_KV"],
          bindings: {
            ENVIRONMENT: "test",
            FREE_ANALYSIS_LIMIT: "3",
            TEST_MIGRATIONS: migrations,
            // Fake key: the Worker takes the AI Gateway code path, and tests/helpers/mock-gateway.ts answers offline.
            ANTHROPIC_API_KEY: "test-key",
            CF_AI_GATEWAY_TOKEN: "",
            // .dev.vars may define APPLE_* for wrangler dev; tests expect DeviceCheck off unless overridden per test.
            APPLE_KEY_ID: "",
            APPLE_PRIVATE_KEY: "",
            APPLE_TEAM_ID: "",
          },
        },
      }),
    ],
    test: {
      testTimeout: 30_000,
      setupFiles: ["tests/apply-d1-migrations.ts"],
      include: ["tests/**/*.test.ts"],
      exclude: ["node_modules/**", "dist/**", "tests/e2e/**"],
      reporters: ["verbose"],
    },
  };
});
