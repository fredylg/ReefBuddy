# Backend test suite

Vitest runs the Worker inside the real Workers runtime through `@cloudflare/vitest-plugin`
(`vitest.config.ts`): Miniflare provides D1 and KV, `tests/apply-d1-migrations.ts` replays
`migrations/*.sql` before each file, and `tests/helpers/mock-gateway.ts` intercepts the AI Gateway so
no test talks to Anthropic. Storage is isolated per test file, not per test, so tests use unique device
ids and IPs instead of relying on rollback.

```bash
npm test                         # 243 tests, 6 skipped (need real Apple credentials)
npx vitest run tests/credits.test.ts
npx vitest run -t "refund"       # by name
```

## Files

| File | Covers |
|------|--------|
| `api.test.ts` | measurements validation, tank routes, CORS/security headers, request ids |
| `tanks-backward-compat.test.ts` | tank payload shapes the iOS app sends (uppercase ids, optional fields) |
| `device-routes.test.ts` | `X-Device-ID` access to every app route, bounds on device ids, rate-limit scopes |
| `credits.test.ts` | balance, free tier, consume/refund, concurrency (no negative credits) |
| `credits-purchase.test.ts` | StoreKit 2 JWS verification: signature, x5c chain, OIDs, environments (`fixtures/*.jws`) |
| `analyze-credits-refund.test.ts` | `/analyze` success/failure paths and credit refunds per failure kind |
| `ai-gateway.test.ts` | gateway request shape, structured output parsing, retries, error mapping |
| `devicecheck-bits.test.ts` | two-bit free-tier state machine |
| `devicecheck-security.test.ts` | DeviceCheck enforcement and dev/production gating |
| `livestock-notifications.test.ts` | `/api/tanks/:id/livestock`, logs, notification settings/history |
| `e2e/devicecheck-production.test.ts` | real DeviceCheck call; excluded from `npm test` (needs `.dev.vars`) |

Helpers: `helpers/mock-gateway.ts` (`installGatewayMock`, `queueGatewayReply`, `lastGatewayRequestBody`),
`env.d.ts` (adds `TEST_MIGRATIONS` to `Cloudflare.Env`), `raw-modules.d.ts` (`?raw` SQL imports).

## Bindings in tests

`vitest.config.ts` runs the `dev` environment of `wrangler.toml` with these overrides: `ENVIRONMENT=test`,
`FREE_ANALYSIS_LIMIT=3`, a dummy `ANTHROPIC_API_KEY`, empty `CF_AI_GATEWAY_TOKEN` and `APPLE_*`
secrets. `worker-configuration.d.ts` (from `npm run types`) types `env`.

## Writing a test

```typescript
import { env, SELF } from 'cloudflare:test';
import { beforeAll, describe, expect, it } from 'vitest';
import { installGatewayMock, queueGatewayReply } from './helpers/mock-gateway';

describe('feature', () => {
  beforeAll(() => installGatewayMock());

  it('does the thing', async () => {
    const deviceId = crypto.randomUUID(); // unique per test: storage is per file
    const res = await SELF.fetch('https://example.com/api/tanks', {
      headers: { 'X-Device-ID': deviceId },
    });
    expect(res.status).toBe(200);
  });
});
```

Rules of thumb: never hit the network; give each test its own device id and `CF-Connecting-IP`
(the limiter is 60/min per device, 10/min per IP on `/analyze`); assert on status and JSON shape,
not on log output; keep fixtures in `tests/fixtures/`.
