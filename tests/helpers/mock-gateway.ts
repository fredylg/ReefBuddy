/**
 * Deterministic, offline stand-in for every outbound request the Worker makes.
 *
 * Tests and the Worker run in one isolate under the Vitest plugin, so spying on the global `fetch`
 * intercepts the Worker's outbound calls (AI Gateway, Apple DeviceCheck). `SELF.fetch` is a service
 * binding and is not affected. Any outbound fetch to an origin without a handler throws, which
 * keeps the suite hermetic: no test can reach Anthropic, Apple, or anything else by accident.
 *
 * Usage (top level of a test file):
 *   installGatewayMock(successReply("Parameters look fine."));   // default AI reply for every call
 *   queueGatewayReply(500, {});                                   // one-off reply for the next AI call
 *   mockOrigin("https://api.devicecheck.apple.com", (req) => ...) // any other origin
 */
import { afterEach, vi } from 'vitest';

export const GATEWAY_ORIGIN = 'https://gateway.ai.cloudflare.com';

export interface GatewayReply {
  status: number;
  body: unknown;
}

export function successReply(text: string, extra: Record<string, unknown> = {}): GatewayReply {
  return {
    status: 200,
    body: {
      id: 'msg_test',
      type: 'message',
      role: 'assistant',
      model: 'claude-haiku-4-5-20251001',
      stop_reason: 'end_turn',
      stop_sequence: null,
      usage: { input_tokens: 120, output_tokens: 80 },
      content: [{ type: 'text', text }],
      ...extra,
    },
  };
}

type OriginHandler = (request: Request) => Promise<Response> | Response;

let defaultReply: GatewayReply | null = null;
const queue: GatewayReply[] = [];
let calls = 0;
let installed = false;
let lastGatewayBody: unknown = null;
const originHandlers = new Map<string, OriginHandler>();

function jsonResponse(status: number, body: unknown): Response {
  return new Response(typeof body === 'string' ? body : JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function ensureInstalled(): void {
  if (installed) return;
  installed = true;

  vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
    const request = input instanceof Request ? input : new Request(input, init);
    const origin = new URL(request.url).origin;

    if (origin === GATEWAY_ORIGIN) {
      calls++;
      try {
        lastGatewayBody = await request.clone().json();
      } catch {
        lastGatewayBody = null;
      }
      const next = queue.shift() ?? defaultReply;
      if (!next) throw new Error('No mocked gateway reply available; queue one with queueGatewayReply()');
      return jsonResponse(next.status, next.body);
    }

    const handler = originHandlers.get(origin);
    if (handler) return handler(request);

    throw new Error('Unexpected outbound fetch in test (suite must stay offline): ' + request.url);
  });

  afterEach(() => {
    const pending = queue.length;
    queue.length = 0;
    calls = 0;
    if (pending > 0) throw new Error(pending + ' queued gateway replies were never consumed');
  });
}

/** Install the fetch spy with a default AI Gateway reply (null = every call must be queued). */
export function installGatewayMock(reply: GatewayReply | null = successReply('Parameters look fine.')): void {
  defaultReply = reply;
  ensureInstalled();
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

/** JSON body of the most recent gateway request (model, max_tokens, output_config, ...). */
export function lastGatewayRequestBody<T = Record<string, unknown>>(): T | null {
  return lastGatewayBody as T | null;
}

/** Route every outbound request to `origin` through `handler` (for the rest of the file). */
export function mockOrigin(origin: string, handler: OriginHandler): void {
  ensureInstalled();
  originHandlers.set(new URL(origin).origin, handler);
}

export { jsonResponse as mockJsonResponse };
