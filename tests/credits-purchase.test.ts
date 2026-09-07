/**
 * POST /credits/purchase — StoreKit 2 JWS verification and credit granting.
 * Covers P1-01 (verify before trust), P1-02 (no transaction-id "0" bypass),
 * P1-06 (atomic add + duplicate guard) and the production environment policy.
 */
import { describe, it, expect, beforeAll } from "vitest";
import { env, SELF, createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import worker from "../src/index";

const BUNDLE_ID = "au.com.aethers.reefbuddy";
const PRODUCT_5 = "com.reefbuddy.credits5";

function b64url(bytes: Uint8Array | string): string {
  const bin = typeof bytes === "string" ? bytes : String.fromCharCode(...bytes);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

interface FakePayload {
  transactionId: string;
  originalTransactionId?: string;
  bundleId?: string;
  productId?: string;
  purchaseDate?: number;
  type?: string;
  inAppOwnershipType?: string;
  signedDate?: number;
  environment: "Sandbox" | "Production" | "Xcode";
}

function payloadFor(over: Partial<FakePayload> & { transactionId: string; environment: FakePayload["environment"] }): FakePayload {
  return {
    originalTransactionId: over.transactionId,
    bundleId: BUNDLE_ID,
    productId: PRODUCT_5,
    purchaseDate: Date.now(),
    type: "Consumable",
    inAppOwnershipType: "PURCHASED",
    signedDate: Date.now(),
    ...over,
  };
}

/** Unsigned JWS: header without x5c, random signature. Must always be rejected. */
function forgedJWS(payload: FakePayload): string {
  const header = b64url(JSON.stringify({ alg: "ES256" }));
  const body = b64url(JSON.stringify(payload));
  const sig = b64url(crypto.getRandomValues(new Uint8Array(64)));
  return `${header}.${body}.${sig}`;
}

/**
 * Self-signed JWS: a fresh P-256 key, its SPKI wrapped in a fake "certificate" blob placed in x5c[0],
 * and a valid ECDSA signature. Passes signature verification but NOT chain validation (Phase 3, P3-10).
 */
let signer: CryptoKeyPair;
let fakeCertB64: string;
beforeAll(async () => {
  signer = (await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"])) as CryptoKeyPair;
  const spki = new Uint8Array(await crypto.subtle.exportKey("spki", signer.publicKey));
  const prefix = crypto.getRandomValues(new Uint8Array(40));
  const suffix = crypto.getRandomValues(new Uint8Array(40));
  const cert = new Uint8Array(prefix.length + spki.length + suffix.length);
  cert.set(prefix, 0);
  cert.set(spki, prefix.length);
  cert.set(suffix, prefix.length + spki.length);
  fakeCertB64 = btoa(String.fromCharCode(...cert));
});

async function selfSignedJWS(payload: FakePayload): Promise<string> {
  const header = b64url(JSON.stringify({ alg: "ES256", x5c: [fakeCertB64] }));
  const body = b64url(JSON.stringify(payload));
  const signingInput = new TextEncoder().encode(`${header}.${body}`);
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, signer.privateKey, signingInput));
  return `${header}.${body}.${b64url(sig)}`;
}

async function balance(deviceId: string): Promise<{ paidCredits: number; freeRemaining: number }> {
  const res = await SELF.fetch(`http://localhost/credits/balance?deviceId=${deviceId}`);
  return (await res.json()) as { paidCredits: number; freeRemaining: number };
}

async function purchase(body: Record<string, unknown>, envOverride?: Partial<typeof env>): Promise<Response> {
  const req = new Request("http://localhost/credits/purchase", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!envOverride) return SELF.fetch(req);
  const ctx = createExecutionContext();
  const res = await worker.fetch(req, { ...env, ...envOverride } as typeof env, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

const uid = (p: string) => `${p}-${crypto.randomUUID()}`;

describe("POST /credits/purchase — request validation", () => {
  it("rejects a body without jwsRepresentation (legacy receiptData is gone)", async () => {
    const res = await purchase({ deviceId: uid("dev"), productId: PRODUCT_5, receiptData: "base64receipt" });
    expect(res.status).toBe(400);
    const data = (await res.json()) as { error: string };
    expect(data.error).toBe("Validation failed");
  });

  it("rejects invalid JSON with 400", async () => {
    const res = await SELF.fetch("http://localhost/credits/purchase", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "{not json",
    });
    expect(res.status).toBe(400);
  });

  it("rejects an unknown product", async () => {
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox", productId: "com.reefbuddy.unknown" }));
    const res = await purchase({ deviceId: uid("dev"), productId: "com.reefbuddy.unknown", jwsRepresentation: jws });
    expect(res.status).toBe(400);
  });
});

describe("POST /credits/purchase — signature is verified before anything is trusted (P1-01)", () => {
  it("rejects a forged, unsigned Sandbox payload and grants nothing", async () => {
    const deviceId = uid("dev");
    const before = await balance(deviceId);
    const res = await purchase({
      deviceId,
      productId: "com.reefbuddy.credits50",
      jwsRepresentation: forgedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox", productId: "com.reefbuddy.credits50" })),
    });
    expect(res.status).toBe(400);
    const data = (await res.json()) as { code: string };
    expect(data.code).toBe("JWS_INVALID");
    const after = await balance(deviceId);
    expect(after.paidCredits).toBe(before.paidCredits);
  });

  it("rejects a forged, unsigned Production payload the same way", async () => {
    const deviceId = uid("dev");
    const res = await purchase({
      deviceId,
      productId: PRODUCT_5,
      jwsRepresentation: forgedJWS(payloadFor({ transactionId: uid("tx"), environment: "Production" })),
    });
    expect(res.status).toBe(400);
    expect((await balance(deviceId)).paidCredits).toBe(0);
  });

  it("rejects a correctly signed JWS whose signed product differs from the requested product", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox", productId: PRODUCT_5 }));
    const res = await purchase({ deviceId, productId: "com.reefbuddy.credits50", jwsRepresentation: jws });
    expect(res.status).toBe(400);
    expect(((await res.json()) as { code: string }).code).toBe("JWS_PRODUCT");
    expect((await balance(deviceId)).paidCredits).toBe(0);
  });

  it("rejects a signed JWS for another bundle id", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox", bundleId: "com.example.other" }));
    const res = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws });
    expect(res.status).toBe(400);
    expect(((await res.json()) as { code: string }).code).toBe("JWS_BUNDLE");
  });
});

describe("POST /credits/purchase — environment policy", () => {
  it("in production, a Sandbox transaction is refused (SANDBOX_NOT_ALLOWED) and grants nothing", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox" }));
    const res = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws }, { ENVIRONMENT: "production", ALLOW_SANDBOX_PURCHASES: "false" } as Partial<typeof env>);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { code: string }).code).toBe("SANDBOX_NOT_ALLOWED");
    expect((await balance(deviceId)).paidCredits).toBe(0);
  });

  it("in production, an Xcode transaction is refused too", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Xcode" }));
    const res = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws }, { ENVIRONMENT: "production", ALLOW_SANDBOX_PURCHASES: "false" } as Partial<typeof env>);
    expect(res.status).toBe(403);
  });

  it("in production with ALLOW_SANDBOX_PURCHASES=true, a signed Sandbox transaction is accepted (TestFlight)", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox" }));
    const res = await purchase(
      { deviceId, productId: PRODUCT_5, jwsRepresentation: jws },
      { ENVIRONMENT: "production", ALLOW_SANDBOX_PURCHASES: "true" } as Partial<typeof env>
    );
    expect(res.status).toBe(200);
    expect((await balance(deviceId)).paidCredits).toBe(5);
  });

  // Documents the remaining gap closed in Phase 3 (P3-10): without x5c chain validation, a JWS
  // self-signed by anyone verifies in production when it claims environment=Production.
  // `it.fails` passes while the gap exists and will start failing once P3-10 lands — then
  // remove `.fails` and keep the assertion.
  it.fails("in production, a self-signed JWS claiming environment=Production is rejected (P3-10 chain validation)", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Production" }));
    const res = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws }, { ENVIRONMENT: "production", ALLOW_SANDBOX_PURCHASES: "false" } as Partial<typeof env>);
    expect(res.status).toBe(400);
  });
});

describe("POST /credits/purchase — granting and duplicate guard (P1-02, P1-06)", () => {
  it("accepts a signed Sandbox transaction outside production and adds the product's credits once", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox" }));
    const res = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws });
    expect(res.status).toBe(200);
    const data = (await res.json()) as { success: boolean; creditsAdded: number; newBalance: { paidCredits: number } };
    expect(data.success).toBe(true);
    expect(data.creditsAdded).toBe(5);
    expect(data.newBalance.paidCredits).toBe(5);
    expect((await balance(deviceId)).paidCredits).toBe(5);
  });

  it("replaying the same signed transaction returns 409 and does not add credits again", async () => {
    const deviceId = uid("dev");
    const jws = await selfSignedJWS(payloadFor({ transactionId: uid("tx"), environment: "Sandbox" }));
    expect((await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws })).status).toBe(200);
    const second = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws });
    expect(second.status).toBe(409);
    expect((await balance(deviceId)).paidCredits).toBe(5);
  });

  it("the same transaction id cannot be redeemed by a second device", async () => {
    const txId = uid("tx");
    const jws = await selfSignedJWS(payloadFor({ transactionId: txId, environment: "Sandbox" }));
    const a = uid("dev");
    const b = uid("dev");
    expect((await purchase({ deviceId: a, productId: PRODUCT_5, jwsRepresentation: jws })).status).toBe(200);
    expect((await purchase({ deviceId: b, productId: PRODUCT_5, jwsRepresentation: jws })).status).toBe(409);
    expect((await balance(b)).paidCredits).toBe(0);
  });

  it('transaction id "0" is no longer special: the second "0" transaction is a duplicate', async () => {
    const deviceId = uid("dev");
    const first = await selfSignedJWS(payloadFor({ transactionId: "0", environment: "Xcode", purchaseDate: Date.now() - 1000 }));
    const second = await selfSignedJWS(payloadFor({ transactionId: "0", environment: "Xcode" }));
    const r1 = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: first });
    // The very first "0" in this test database may or may not have been used by another file; either way the second must be 409.
    expect([200, 409]).toContain(r1.status);
    const r2 = await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: second });
    expect(r2.status).toBe(409);
    const paid = (await balance(deviceId)).paidCredits;
    expect(paid).toBeLessThanOrEqual(5);
  });

  it("every granted purchase has an audit row in purchase_history", async () => {
    const deviceId = uid("dev");
    const txId = uid("tx");
    const jws = await selfSignedJWS(payloadFor({ transactionId: txId, environment: "Sandbox" }));
    expect((await purchase({ deviceId, productId: PRODUCT_5, jwsRepresentation: jws })).status).toBe(200);
    const row = await env.DB.prepare("SELECT credits_added, device_id FROM purchase_history WHERE apple_transaction_id = ?")
      .bind(txId)
      .first<{ credits_added: number; device_id: string }>();
    expect(row?.credits_added).toBe(5);
    expect(row?.device_id).toBe(deviceId);
  });
});
