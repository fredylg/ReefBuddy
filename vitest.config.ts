import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    // Pool workers configuration for Cloudflare Workers testing
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.toml" },
        miniflare: {
          // D1 database binding for tests
          d1Databases: {
            DB: "test-db",
          },
          // KV namespace binding for tests
          kvNamespaces: ["REEF_KV"],
          // Environment variables for testing
          bindings: {
            ENVIRONMENT: "test",
            FREE_TIER_LIMIT: "3",
          },
        },
      },
    },
    // Test file patterns
    include: ["tests/**/*.test.ts"],
    // Exclude patterns
    exclude: ["node_modules/**", "dist/**"],
    // Reporter configuration
    reporters: ["verbose"],
    // Coverage configuration (optional, enable if needed)
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      exclude: [
        "node_modules/**",
        "tests/**",
        "vitest.config.ts",
      ],
    },
  },
});
