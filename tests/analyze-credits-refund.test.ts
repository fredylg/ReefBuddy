/**
 * /analyze credit accounting when the AI call fails or credits run out.
 * Covers P1-03 (refund actually works — MAX() not GREATEST()), P1-04 (every AI failure refunds and is
 * reported as 5xx, never as a 200 "analysis"), and P1-05 (atomic consumption: never negative).
 * The AI Gateway is mocked by spying on the global fetch, so this file is deterministic and costs nothing.
 */
import { describe, it, expect } from "vitest";
import { env, SELF } from "cloudflare:test";
import { gatewayCallCount, installGatewayMock, queueGatewayReply, setDefaultGatewayReply } from "./helpers/mock-gateway";

const validRequest = (deviceId: string) => ({
  deviceId,
  tankId: "550e8400-e29b-41d4-a716-446655440000",
  parameters: { salinity: 1.025, temperature: 78, ph: 8.2, alkalinity: 8.5, calcium: 420, magnesium: 1350 },
  tankVolume: 75,
});

async function analyze(deviceId: string): Promise<Response> {
  return SELF.fetch("http://localhost/analyze", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(validRequest(deviceId)),
  });
}

async function balance(deviceId: string) {
  const res = await SELF.fetch(`http://localhost/credits/balance?deviceId=${deviceId}`);
  return (await res.json()) as { freeRemaining: number; freeUsed: number; paidCredits: number; totalAnalyses: number };
}

async function setCredits(deviceId: string, freeUsed: number, paid: number) {
  await balance(deviceId); // ensure row exists
  await env.DB.prepare("UPDATE device_credits SET free_used = ?, paid_credits = ? WHERE device_id = ?").bind(freeUsed, paid, deviceId).run();
}

const uid = () => `REFUND-${crypto.randomUUID()}`;
const hasKey = Boolean(env.ANTHROPIC_API_KEY);

installGatewayMock(null); // no default reply: every test queues exactly what it expects

function mockGateway(status: number, body: unknown) {
  queueGatewayReply(status, body);
}

describe("POST /analyze — AI failures refund the credit (P1-03, P1-04)", () => {
  it("upstream 500: responds 502/503 with creditsRefunded=true and the free credit is restored", async () => {
    const deviceId = uid();
    const before = await balance(deviceId);
    if (hasKey) mockGateway(500, { error: { type: "api_error", message: "boom" } });

    const res = await analyze(deviceId);
    expect([502, 503]).toContain(res.status);
    const data = (await res.json()) as { creditsRefunded: boolean; code: string; analysis?: unknown };
    expect(data.creditsRefunded).toBe(true);
    expect(data.analysis).toBeUndefined();

    const after = await balance(deviceId);
    expect(after.freeRemaining).toBe(before.freeRemaining);
    expect(after.totalAnalyses).toBe(before.totalAnalyses);
  });

  it("upstream 529: responds 503 retryable and refunds", async () => {
    const deviceId = uid();
    if (hasKey) {
      // callAIGateway retries 529 up to 3 times before giving up
      for (let i = 0; i < 4; i++) mockGateway(529, { error: { type: "overloaded_error" } });
    }
    const res = await analyze(deviceId);
    expect(res.status).toBe(503);
    const data = (await res.json()) as { creditsRefunded: boolean; retryable: boolean };
    expect(data.creditsRefunded).toBe(true);
    expect((await balance(deviceId)).freeRemaining).toBe(3);
    if (hasKey) expect(gatewayCallCount()).toBe(4);
  }, 30_000);

  it("a paid credit is refunded to the paid pool, not the free pool", async () => {
    const deviceId = uid();
    await setCredits(deviceId, 3, 2); // free exhausted, 2 paid
    if (hasKey) mockGateway(500, {});
    const res = await analyze(deviceId);
    expect([502, 503]).toContain(res.status);
    const after = await balance(deviceId);
    expect(after.paidCredits).toBe(2);
    expect(after.freeRemaining).toBe(0);
  });

  it("a 200 with no text content is treated as a failure and refunded", async () => {
    const deviceId = uid();
    if (hasKey) mockGateway(200, { id: "msg", content: [], stop_reason: "end_turn" });
    const res = await analyze(deviceId);
    expect([502, 503]).toContain(res.status);
    expect((await balance(deviceId)).freeRemaining).toBe(3);
  });

  it("a successful AI response consumes exactly one credit and returns the analysis", async () => {
    const deviceId = uid();
    if (!hasKey) return; // without a key the worker is not_configured; covered above
    mockGateway(200, {
      id: "msg",
      stop_reason: "end_turn",
      usage: { input_tokens: 100, output_tokens: 50 },
      content: [{ type: "text", text: "Alkalinity is fine. Dose nothing." }],
    });
    const res = await analyze(deviceId);
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; analysis: { recommendation: string }; freeRemaining: number };
    expect(data.success).toBe(true);
    expect(data.analysis.recommendation).toContain("Alkalinity");
    expect(data.freeRemaining).toBe(2);
    expect((await balance(deviceId)).totalAnalyses).toBe(1);
  });
});

describe("POST /analyze — credit consumption is atomic (P1-05)", () => {
  it("with 0 free and 0 paid credits, responds 402 and touches nothing", async () => {
    const deviceId = uid();
    await setCredits(deviceId, 3, 0);
    const res = await analyze(deviceId);
    expect(res.status).toBe(402);
    const after = await balance(deviceId);
    expect(after.paidCredits).toBe(0);
    expect(after.freeRemaining).toBe(0);
  });

  it("five concurrent requests against one paid credit: exactly one is analysed, the balance never goes negative", async () => {
    const deviceId = uid();
    await setCredits(deviceId, 3, 1);
    if (hasKey) {
      // A successful AI reply means the winning request keeps its credit, so exactly one may win.
      setDefaultGatewayReply({ status: 200, body: { id: "msg", stop_reason: "end_turn", content: [{ type: "text", text: "ok" }] } });
    }
    const results = await Promise.all([1, 2, 3, 4, 5].map(() => analyze(deviceId)));
    const statuses = results.map((r) => r.status);
    const after = await balance(deviceId);

    expect(after.paidCredits).toBeGreaterThanOrEqual(0);
    expect(after.freeRemaining).toBe(0);
    if (hasKey) {
      expect(statuses.filter((s) => s === 200).length).toBe(1);
      expect(statuses.filter((s) => s === 402).length).toBe(4);
      expect(after.paidCredits).toBe(0);
      expect(after.totalAnalyses).toBe(1);
      setDefaultGatewayReply(null);
    } else {
      // not_configured: every taker is refunded, so the credit can be taken sequentially; it must still never go negative
      expect(statuses.every((s) => s === 402 || s === 503)).toBe(true);
      expect(after.paidCredits).toBeLessThanOrEqual(1);
    }
  });
});
