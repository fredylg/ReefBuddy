import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { checkIPRateLimit } from '../src/http';

/** An env whose KV throws on every call, standing in for a KV outage. */
function brokenKvEnv(): typeof env {
  const failing = new Proxy(
    {},
    {
      get: () => async (): Promise<never> => {
        throw new Error('KV unavailable');
      },
    }
  );
  return { ...env, REEF_KV: failing as unknown as KVNamespace };
}

describe('checkIPRateLimit when KV is unavailable', () => {
  it('fails open by default (cheap routes stay up)', async () => {
    const result = await checkIPRateLimit(brokenKvEnv(), '203.0.113.10', 5, 60_000, 'device');
    expect(result.allowed).toBe(true);
  });

  it('fails closed when asked to (the /analyze limiter, security item H3)', async () => {
    const result = await checkIPRateLimit(brokenKvEnv(), '203.0.113.11', 10, 60_000, 'ip', 'deny');
    expect(result.allowed).toBe(false);
    expect(result.remaining).toBe(0);
  });

  it('still counts normally when KV works', async () => {
    const ip = `198.51.100.${Math.floor(Math.random() * 250)}`;
    const first = await checkIPRateLimit(env, ip, 2, 60_000, 'test-scope', 'deny');
    const second = await checkIPRateLimit(env, ip, 2, 60_000, 'test-scope', 'deny');
    const third = await checkIPRateLimit(env, ip, 2, 60_000, 'test-scope', 'deny');
    expect([first.allowed, second.allowed, third.allowed]).toEqual([true, true, false]);
  });
});
