/**
 * Test-only bindings. `env` from "cloudflare:test" is typed as `Cloudflare.Env` (generated into
 * worker-configuration.d.ts by `npm run types`); this adds the migrations binding injected in
 * vitest.config.ts. When a test needs the Worker's narrower `Env` (src/index.ts), cast with
 * `as unknown as Env`.
 */
import type { D1Migration } from '@cloudflare/vitest-plugin';

declare global {
  namespace Cloudflare {
    interface Env {
      TEST_MIGRATIONS: D1Migration[];
    }
  }
}

export {};
