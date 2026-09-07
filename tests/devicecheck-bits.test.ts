/**
 * DeviceCheck free-tier bit (P3-12, B-04).
 * bit0 on the physical device means "free analyses consumed"; it follows the device across
 * reinstalls and rotated device ids. Apple's endpoints are mocked; the Worker signs its DeviceCheck
 * JWT with a test P-256 key injected through the env override.
 */
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { env, SELF, createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import worker, { type Env } from "../src/index";
import { installGatewayMock, mockOrigin, mockJsonResponse, successReply } from "./helpers/mock-gateway";

installGatewayMock(successReply("Parameters look fine."));

// ---- Apple DeviceCheck stand-in -------------------------------------------------------------
type Bits = { bit0: boolean; bit1: boolean } | null;
let deviceBits: Bits = null; // what Apple "knows" about the (single) test device
let queryStatus = 200; // force a failure status for query_two_bits
const updateCalls: Array<{ bit0: boolean; bit1: boolean }> = [];

mockOrigin("https://api.devicecheck.apple.com", async (request) => {
  const path = new URL(request.url).pathname;
  const body = (await request.json()) as { device_token: string; bit0?: boolean; bit1?: boolean };
  if (!request.headers.get("Authorization")?.startsWith("Bearer ")) return mockJsonResponse(401, "Unable to verify authorization token");
  if (!body.device_token || body.device_token.length < 500) return mockJsonResponse(400, "Missing or incorrectly formatted device token payload");
  if (path.endsWith("/query_two_bits")) {
    if (queryStatus !== 200) return mockJsonResponse(queryStatus, "Missing or incorrectly formatted device token payload");
    return deviceBits ? mockJsonResponse(200, { ...deviceBits, last_update_time: "2026-09" }) : mockJsonResponse(200, "Failed to find bit state");
  }
  if (path.endsWith("/update_two_bits")) {
    deviceBits = { bit0: body.bit0 === true, bit1: body.bit1 === true };
    updateCalls.push({ bit0: body.bit0 === true, bit1: body.bit1 === true });
    return new Response(null, { status: 200 });
  }
  return mockJsonResponse(404, "unknown endpoint");
});

// ---- Worker env with a real (test) DeviceCheck key -------------------------------------------
let deviceCheckEnv: Partial<Env>;
beforeAll(async () => {
  const key = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
  const pkcs8 = new Uint8Array((await crypto.subtle.exportKey("pkcs8", key.privateKey)) as ArrayBuffer);
  const b64 = btoa(String.fromCharCode(...pkcs8));
  const pem = "-----BEGIN PRIVATE KEY-----\n" + (b64.match(/.{1,64}/g) ?? []).join("\n") + "\n-----END PRIVATE KEY-----";
  deviceCheckEnv = { ENVIRONMENT: "test", APPLE_KEY_ID: "TESTKEY123", APPLE_TEAM_ID: "TEAM123456", APPLE_PRIVATE_KEY: pem };
});

beforeEach(() => {
  deviceBits = null;
  queryStatus = 200;
  updateCalls.length = 0;
});

const TOKEN = "A".repeat(640); // plausible base64 length; Apple's real tokens are ~1000+ chars
let ipCounter = 0;
const uid = () => `BITS-${crypto.randomUUID()}`;

async function analyze(deviceId: string): Promise<Response> {
  ipCounter++;
  const req = new Request("http://localhost/analyze", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": `10.9.0.${ipCounter}` },
    body: JSON.stringify({
      deviceId,
      deviceToken: TOKEN,
      tankId: "550e8400-e29b-41d4-a716-446655440000",
      parameters: { salinity: 1.025, temperature: 78, ph: 8.2, alkalinity: 8.5, calcium: 420, magnesium: 1350 },
      tankVolume: 75,
    }),
  });
  const ctx = createExecutionContext();
  const res = await worker.fetch(req, { ...env, ...deviceCheckEnv } as unknown as Env, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

async function balance(deviceId: string) {
  const res = await SELF.fetch(`http://localhost/credits/balance?deviceId=${deviceId}`);
  return (await res.json()) as { freeRemaining: number; paidCredits: number; totalAnalyses: number };
}

async function setPaid(deviceId: string, paid: number) {
  await balance(deviceId);
  await env.DB.prepare("UPDATE device_credits SET paid_credits = ? WHERE device_id = ?").bind(paid, deviceId).run();
}

describe("DeviceCheck free-tier bit", () => {
  it("a never-seen device is validated by setting bit1 and gets a free analysis", async () => {
    const deviceId = uid();
    const res = await analyze(deviceId);
    expect(res.status).toBe(200);
    expect(updateCalls[0]).toEqual({ bit0: false, bit1: true });
    expect((await balance(deviceId)).freeRemaining).toBe(2);
  });

  it("the third free analysis marks bit0 on the device", async () => {
    const deviceId = uid();
    expect((await analyze(deviceId)).status).toBe(200);
    expect((await analyze(deviceId)).status).toBe(200);
    expect((await analyze(deviceId)).status).toBe(200);
    expect(updateCalls.at(-1)).toEqual({ bit0: true, bit1: true });
    expect(deviceBits?.bit0).toBe(true);
    expect((await analyze(deviceId)).status).toBe(402);
  });

  it("a device with bit0 set gets no free analyses even with a fresh device id", async () => {
    deviceBits = { bit0: true, bit1: true };
    const freshId = uid();
    const res = await analyze(freshId);
    expect(res.status).toBe(402);
    const data = (await res.json()) as { freeRemaining: number; paidCredits: number };
    expect(data.freeRemaining).toBe(0);
    expect((await balance(freshId)).totalAnalyses).toBe(0);
  });

  it("a device with bit0 set can still spend paid credits, and its free pool is left alone", async () => {
    deviceBits = { bit0: true, bit1: true };
    const deviceId = uid();
    await setPaid(deviceId, 2);
    const res = await analyze(deviceId);
    expect(res.status).toBe(200);
    const after = await balance(deviceId);
    expect(after.paidCredits).toBe(1);
    expect(after.freeRemaining).toBe(3); // untouched: the device-level bit, not this row, says free is used up
  });

  it("Apple rejecting the token (400) yields 403 DEVICE_CHECK_FAILED and touches no credits", async () => {
    queryStatus = 400;
    const deviceId = uid();
    const res = await analyze(deviceId);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { code: string }).code).toBe("DEVICE_CHECK_FAILED");
    expect((await balance(deviceId)).totalAnalyses).toBe(0);
  });
});
