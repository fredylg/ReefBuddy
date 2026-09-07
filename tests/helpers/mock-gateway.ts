/**
 * Deterministic, offline stand-in for the Anthropic call through Cloudflare AI Gateway.
 *
 * Tests and the Worker run in one isolate under the Vitest plugin, so spying on the global `fetch`
 * intercepts the Worker's outbound gateway request. `SELF.fetch` is a service binding and is not
 * affected. Any outbound fetch to another origin throws, which keeps the suite hermetic: no test
 * can reach Anthropic, Apple, or anything else by accident.
 *
 * Usage (top level of a test file):
 *   installGatewayMock(successReply("Parameters look fine."));   // default reply for every call
 *   ...
 *   queueGatewayReply(500, {});   // one-off reply for the next call, consumed in order
 */
import { afterEach, vi } from "vitest";

export const GATEWAY_ORIGIN = "https://gateway.ai.cloudflare.com";

export interface GatewayReply {
  status: number;
  body: unknown;
}

export function successReply(text: string, extra: Record<string, unknown> = {}): GatewayReply {
  return {
    status: 200,
    body: {
      id: "msg_test",
      type: "message",
      role: "assistant",
      model: "claude-haiku-4-5-20251001",
      stop_reason: "end_turn",
      stop_sequence: null,
      usage: { input_tokens: 120, output_tokens: 80 },
      content: [{ type: "text", text }],
      ...extra,
    },
  };
}

let defaultReply: GatewayReply | null = null;
const queue: GatewayReply[] = [];
let calls = 0;
let installed = false;

export function installGatewayMock(reply: GatewayReply | null = successReply("Parameters look fine.")): void {
  defaultReply = reply;
  if (installed) return;
  installed = true;

  vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    if (!url.startsWith(GATEWAY_ORIGIN)) {
      throw new Error("Unexpected outbound fetch in test (suite must stay offline): " + url);
    }
    calls++;
    const next = queue.shift() ?? defaultReply;
    if (!next) throw new Error("No mocked gateway reply available; queue one with queueGatewayReply()");
    return new Response(JSON.stringify(next.body), {
      status: next.status,
      headers: { "content-type": "application/json" },
    });
  });

  afterEach(() => {
    const pending = queue.length;
    queue.length = 0;
    calls = 0;
    if (pending > 0) throw new Error(pending + " queued gateway replies were never consumed");
  });
}

/** Reply for the next gateway call only (consumed in order before the default). */
export function queueGatewayReply(status: number, body: unknown): void {
  queue.push({ status, body });
}

/** Replace the default reply for subsequent calls in this file. */
export function setDefaultGatewayReply(reply: GatewayReply | null): void {
  defaultReply = reply;
}

/** Gateway calls made during the current test. */
export function gatewayCallCount(): number {
  return calls;
}
