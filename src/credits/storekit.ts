import { z } from 'zod';
import { X509Certificate, X509ChainBuilder } from '@peculiar/x509';
import { CREDIT_PRODUCTS, addDeviceCredits, checkDeviceCredits } from './store';
import { DEFAULT_BUNDLE_ID, Env } from '../env';
import { debugLog, errorResponse, jsonResponse } from '../http';
import { CreditPurchaseJWSSchema } from '../schemas';

// =============================================================================
// STOREKIT 2 JWS VERIFICATION
// =============================================================================

/**
 * Apple JWS Transaction Payload structure
 * This is the decoded payload from a StoreKit 2 signed transaction
 */
export interface JWSTransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  type: string;
  inAppOwnershipType: string;
  signedDate: number;
  environment: 'Sandbox' | 'Production' | 'Xcode';
  // Optional fields
  expiresDate?: number;
  webOrderLineItemId?: string;
  subscriptionGroupIdentifier?: string;
  isUpgraded?: boolean;
  revocationDate?: number;
  revocationReason?: number;
}

/**
 * JWS verification result
 */
export interface JWSVerificationResult {
  /** True when x5c chained to the pinned Apple Root CA G3; false only when an unverified chain was explicitly allowed. */
  chainVerified?: boolean;
  valid: boolean;
  payload?: JWSTransactionPayload;
  error?: string;
}

/**
 * Base64URL decode (JWT/JWS uses base64url encoding, not standard base64)
 */
export function base64UrlDecode(input: string): Uint8Array {
  // Convert base64url to base64
  let base64 = input.replace(/-/g, '+').replace(/_/g, '/');

  // Add padding if needed
  const padding = base64.length % 4;
  if (padding) {
    base64 += '='.repeat(4 - padding);
  }

  // Decode base64 to binary string
  const binaryString = atob(base64);

  // Convert to Uint8Array
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }

  return bytes;
}

/**
 * Convert DER signature to raw format (r || s) for Web Crypto API
 * Apple uses DER encoding for ECDSA signatures, but Web Crypto expects raw format
 */
export function derSignatureToRaw(derSignature: Uint8Array, keySize: number = 32): Uint8Array {
  // DER signature format: 0x30 [length] 0x02 [r-length] [r] 0x02 [s-length] [s]
  let offset = 0;

  // Check for SEQUENCE tag (0x30)
  if (derSignature[offset++] !== 0x30) {
    // Not DER encoded, assume it's already raw format
    return derSignature;
  }

  // Skip sequence length
  let seqLength = derSignature[offset++];
  if (seqLength & 0x80) {
    // Long form length
    const lengthBytes = seqLength & 0x7f;
    offset += lengthBytes;
  }

  // Parse r
  if (derSignature[offset++] !== 0x02) {
    throw new Error('Invalid DER signature: expected INTEGER tag for r');
  }
  let rLength = derSignature[offset++];
  let rStart = offset;

  // Skip leading zero if present (DER uses signed integers)
  if (derSignature[rStart] === 0x00 && rLength > keySize) {
    rStart++;
    rLength--;
  }

  const r = derSignature.slice(rStart, rStart + rLength);
  offset = rStart + rLength;

  // Parse s
  if (derSignature[offset++] !== 0x02) {
    throw new Error('Invalid DER signature: expected INTEGER tag for s');
  }
  let sLength = derSignature[offset++];
  let sStart = offset;

  // Skip leading zero if present
  if (derSignature[sStart] === 0x00 && sLength > keySize) {
    sStart++;
    sLength--;
  }

  const s = derSignature.slice(sStart, sStart + sLength);

  // Create raw signature (r || s) with proper padding
  const rawSignature = new Uint8Array(keySize * 2);

  // Pad r to keySize bytes (left-pad with zeros)
  const rPadding = keySize - r.length;
  rawSignature.set(r, rPadding >= 0 ? rPadding : 0);

  // Pad s to keySize bytes
  const sPadding = keySize - s.length;
  rawSignature.set(s, keySize + (sPadding >= 0 ? sPadding : 0));

  return rawSignature;
}

// =============================================================================
// APPLE CERTIFICATE CHAIN VALIDATION (P3-10)
// =============================================================================

/** Apple Root CA - G3 (DER, base64). SHA-256 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79. Valid to 2039-04-30. */
export const APPLE_ROOT_CA_G3_B64 =
  'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==';
/** Marker OID Apple puts on App Store / iTunes receipt signing leaf certificates. */
export const APPLE_RECEIPT_SIGNING_OID = '1.2.840.113635.100.6.11.1';
/** Marker OID on the Apple Worldwide Developer Relations intermediate. */
export const APPLE_WWDR_OID = '1.2.840.113635.100.6.2.1';

export type ChainResult = { ok: true; leaf: X509Certificate } | { ok: false; error: string };

/**
 * Validate a StoreKit x5c chain: leaf -> WWDR intermediate -> Apple Root CA G3 (pinned).
 * Every link's signature and validity window is checked explicitly; the leaf must carry Apple's
 * receipt-signing marker OID and the chain must contain the WWDR marker.
 */
export async function verifyAppleCertificateChain(x5c: string[], now: Date = new Date()): Promise<ChainResult> {
  let certs: X509Certificate[];
  let root: X509Certificate;
  try {
    certs = x5c.map((b64) => new X509Certificate(b64));
    root = new X509Certificate(APPLE_ROOT_CA_G3_B64);
  } catch {
    return { ok: false, error: 'x5c contains an unparsable certificate' };
  }
  const leaf = certs[0];

  let chain: X509Certificate[];
  try {
    chain = await new X509ChainBuilder({ certificates: [...certs.slice(1), root] }).build(leaf);
  } catch {
    return { ok: false, error: 'Could not build certificate chain' };
  }
  if (chain.length < 2 || !chain[chain.length - 1].equal(root)) {
    return { ok: false, error: 'Certificate chain does not end at Apple Root CA G3' };
  }

  for (let i = 0; i < chain.length; i++) {
    const cert = chain[i];
    if (now < cert.notBefore || now > cert.notAfter) {
      return { ok: false, error: 'Certificate ' + i + ' is outside its validity period' };
    }
    const issuer = i + 1 < chain.length ? chain[i + 1] : cert; // the root is self-signed
    const signatureOk = await cert.verify({ publicKey: issuer.publicKey, signatureOnly: true });
    if (!signatureOk) {
      return { ok: false, error: 'Certificate ' + i + ' has an invalid signature' };
    }
  }

  if (!leaf.getExtension(APPLE_RECEIPT_SIGNING_OID)) {
    return { ok: false, error: 'Leaf certificate is not an App Store receipt signing certificate' };
  }
  if (!chain.slice(1, -1).some((c) => c.getExtension(APPLE_WWDR_OID))) {
    return { ok: false, error: 'Certificate chain is missing the Apple WWDR intermediate' };
  }
  return { ok: true, leaf };
}

/**
 * Verify a StoreKit 2 JWS (JSON Web Signature) signed transaction
 *
 * The JWS is in the format: header.payload.signature (base64url encoded)
 * - Header contains 'alg' (ES256) and 'x5c' (certificate chain)
 * - Payload contains the transaction details
 * - Signature is ECDSA with P-256 and SHA-256
 */
export async function verifyAppleJWS(
  jwsRepresentation: string,
  options: { allowUnverifiedChain: boolean } = { allowUnverifiedChain: false }
): Promise<JWSVerificationResult> {
  try {
    debugLog(`🔐 Starting JWS verification, JWS length: ${jwsRepresentation.length}`);

    // Split the JWS into its three parts
    const parts = jwsRepresentation.split('.');
    debugLog(`🔐 JWS parts: ${parts.length}`);
    if (parts.length !== 3) {
      return { valid: false, error: 'Invalid JWS format: expected 3 parts separated by dots' };
    }

    const [headerB64, payloadB64, signatureB64] = parts;
    debugLog(
      `🔐 Header length: ${headerB64.length}, Payload length: ${payloadB64.length}, Signature length: ${signatureB64.length}`
    );

    // Decode the header
    const headerBytes = base64UrlDecode(headerB64);
    const headerJson = new TextDecoder().decode(headerBytes);
    const header = JSON.parse(headerJson) as { alg: string; x5c?: string[]; kid?: string };
    debugLog(`🔐 Header parsed: alg=${header.alg}, hasX5C=${!!header.x5c}, hasKid=${!!header.kid}, kid=${header.kid}`);

    // Verify algorithm
    if (header.alg !== 'ES256') {
      return { valid: false, error: `Unsupported algorithm: ${header.alg}. Expected ES256.` };
    }

    // Decode the payload
    const payloadBytes = base64UrlDecode(payloadB64);
    const payloadJson = new TextDecoder().decode(payloadBytes);
    const payload = JSON.parse(payloadJson) as JWSTransactionPayload;

    // The signing key is the x5c leaf, accepted only if the chain reaches the pinned Apple root.
    // Xcode's StoreKit test transactions are signed by a local certificate that cannot chain to
    // Apple; callers outside production may opt into accepting those (chainVerified=false).
    if (!header.x5c || header.x5c.length === 0) {
      return { valid: false, error: 'JWS header missing x5c certificate chain' };
    }
    let publicKey: CryptoKey;
    let chainVerified: boolean;
    const chain = await verifyAppleCertificateChain(header.x5c);
    if (chain.ok) {
      publicKey = await chain.leaf.publicKey.export({ name: 'ECDSA', namedCurve: 'P-256' }, ['verify']);
      chainVerified = true;
    } else if (options.allowUnverifiedChain) {
      debugLog('x5c chain not trusted (' + chain.error + '); accepting unverified chain outside production');
      try {
        publicKey = await extractPublicKeyFromCert(header.x5c[0]);
      } catch {
        return { valid: false, error: 'Could not read signing certificate' };
      }
      chainVerified = false;
    } else {
      console.warn('JWS rejected: ' + chain.error);
      return { valid: false, error: chain.error };
    }

    // Decode and convert the signature
    const signatureBytes = base64UrlDecode(signatureB64);

    // JWS ES256 signatures are raw r||s (64 bytes). Only fall back to DER decoding for other lengths.
    let signature: Uint8Array;
    if (signatureBytes.length === 64) {
      signature = signatureBytes;
    } else {
      try {
        signature = derSignatureToRaw(signatureBytes, 32);
      } catch {
        return { valid: false, error: 'Malformed JWS signature' };
      }
    }

    // Create the signing input (header.payload)
    const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    debugLog(`🔐 Verifying signature...`);

    // Verify the signature
    const isValid = await crypto.subtle.verify(
      {
        name: 'ECDSA',
        hash: 'SHA-256',
      },
      publicKey,
      signature,
      signingInput
    );

    debugLog(`🔐 Signature verification result: ${isValid}`);

    if (!isValid) {
      return { valid: false, error: 'JWS signature verification failed' };
    }

    // Validate payload structure
    debugLog(
      `🔐 Payload validation: transactionId=${!!payload.transactionId}, productId=${!!payload.productId}, bundleId=${!!payload.bundleId}`
    );
    if (!payload.transactionId || !payload.productId || !payload.bundleId) {
      return { valid: false, error: 'Invalid payload: missing required fields' };
    }

    // Check if transaction has been revoked
    if (payload.revocationDate) {
      return { valid: false, error: 'Transaction has been revoked' };
    }

    debugLog(`🔐 JWS verification successful (chainVerified=${chainVerified})`);
    return { valid: true, payload, chainVerified };
  } catch (error) {
    console.error('JWS verification error:', error);
    return {
      valid: false,
      error: error instanceof Error ? error.message : 'JWS verification failed',
    };
  }
}

/**
 * DER prefix of a P-256 SubjectPublicKeyInfo:
 * SEQUENCE(91) { SEQUENCE { OID id-ecPublicKey, OID prime256v1 } BIT STRING(66) 0x00 <04||x||y> }
 * Every Apple StoreKit leaf certificate carries exactly this structure for its subject key.
 */
export const P256_SPKI_PREFIX = new Uint8Array([
  0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce,
  0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
]);
export const P256_SPKI_LENGTH = 91;

/**
 * Extract the subject public key from a base64 DER X.509 certificate by locating its
 * SubjectPublicKeyInfo and importing it with Web Crypto. The first SPKI in a certificate is the
 * subject's key (the issuer's key is not embedded), so the first match is the right one.
 */
export async function extractPublicKeyFromCert(certBase64: string): Promise<CryptoKey> {
  const certDer = Uint8Array.from(atob(certBase64), (c) => c.charCodeAt(0));
  outer: for (let i = 0; i + P256_SPKI_LENGTH <= certDer.length; i++) {
    for (let j = 0; j < P256_SPKI_PREFIX.length; j++) {
      if (certDer[i + j] !== P256_SPKI_PREFIX[j]) continue outer;
    }
    const spki = certDer.slice(i, i + P256_SPKI_LENGTH);
    return crypto.subtle.importKey('spki', spki, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  }
  throw new Error('No P-256 SubjectPublicKeyInfo found in certificate');
}

/**
 * Handle credit purchase
 * POST /credits/purchase
 * Accepts StoreKit 2 signed transactions (jwsRepresentation) only.
 */
export async function handleCreditsPurchase(request: Request, env: Env): Promise<Response> {
  try {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: 'Invalid JSON', message: 'Request body is not valid JSON' }, 400);
    }

    const parsed = CreditPurchaseJWSSchema.safeParse(body);
    if (!parsed.success) {
      return jsonResponse(
        {
          error: 'Validation failed',
          message: 'Request must include deviceId, productId and a StoreKit 2 jwsRepresentation',
          details: z.flattenError(parsed.error),
        },
        400
      );
    }

    return await handleJWSPurchase(env, parsed.data);
  } catch (error) {
    console.error('Credit purchase error:', error);
    return errorResponse('Internal server error', 'Purchase could not be processed', 500);
  }
}

/**
 * Handle StoreKit 2 JWS purchase verification.
 * SECURITY ORDER: verify the signature first, then read the payload, then apply policy.
 * Nothing in the payload (environment, product, transaction id) is trusted before verification.
 */
export async function handleJWSPurchase(env: Env, data: z.infer<typeof CreditPurchaseJWSSchema>): Promise<Response> {
  const { deviceId, jwsRepresentation, productId } = data;

  const creditsToAdd = CREDIT_PRODUCTS[productId];
  if (!creditsToAdd) {
    return jsonResponse({ error: 'Invalid product', message: 'Unknown product ID: ' + productId }, 400);
  }

  const isProduction = env.ENVIRONMENT === 'production';
  // Outside production, Xcode StoreKit-configuration transactions (local Xcode signing cert) are accepted.
  const verification = await verifyAppleJWS(jwsRepresentation, { allowUnverifiedChain: !isProduction });
  if (!verification.valid || !verification.payload) {
    console.warn('JWS verification failed for device ' + deviceId + ': ' + (verification.error || 'unknown'));
    return jsonResponse(
      { error: 'Invalid transaction', message: 'Transaction signature could not be verified', code: 'JWS_INVALID' },
      400
    );
  }
  const payload = verification.payload;

  if (!verification.chainVerified && payload.environment !== 'Xcode') {
    console.warn(
      'Rejected JWS with untrusted chain claiming environment=' + payload.environment + ' for device ' + deviceId
    );
    return jsonResponse(
      { error: 'Invalid transaction', message: 'Transaction certificate chain is not trusted', code: 'JWS_CHAIN' },
      400
    );
  }

  // Environment policy: production accepts App Store (Production) transactions only, unless
  // ALLOW_SANDBOX_PURCHASES=true is set (TestFlight). Dev/test accept Sandbox and Xcode.
  const allowSandbox = env.ALLOW_SANDBOX_PURCHASES === 'true';
  if (payload.environment !== 'Production' && isProduction && !allowSandbox) {
    console.warn('Rejected ' + payload.environment + ' transaction in production for device ' + deviceId);
    return jsonResponse(
      {
        error: 'Transaction environment not accepted',
        message: 'Only App Store purchases are accepted by this server',
        code: 'SANDBOX_NOT_ALLOWED',
        environment: payload.environment,
      },
      403
    );
  }

  if (payload.type && payload.type !== 'Consumable') {
    return jsonResponse(
      { error: 'Invalid transaction', message: 'Unsupported transaction type', code: 'JWS_TYPE' },
      400
    );
  }
  if (payload.inAppOwnershipType && payload.inAppOwnershipType !== 'PURCHASED') {
    return jsonResponse(
      { error: 'Invalid transaction', message: 'Transaction is not a direct purchase', code: 'JWS_OWNERSHIP' },
      400
    );
  }
  if (payload.productId !== productId) {
    return jsonResponse(
      { error: 'Product mismatch', message: 'Signed product does not match requested product', code: 'JWS_PRODUCT' },
      400
    );
  }
  const expectedBundleId = env.APPLE_BUNDLE_ID || DEFAULT_BUNDLE_ID;
  if (payload.bundleId !== expectedBundleId) {
    return jsonResponse(
      { error: 'Invalid bundle ID', message: 'Transaction does not belong to this app', code: 'JWS_BUNDLE' },
      400
    );
  }

  const result = await addDeviceCredits(
    env,
    deviceId,
    creditsToAdd,
    productId,
    payload.transactionId,
    jwsRepresentation
  );
  if (result === 'duplicate') {
    return jsonResponse(
      {
        error: 'Duplicate transaction',
        message: 'This transaction has already been processed',
        transactionId: payload.transactionId,
      },
      409
    );
  }
  if (result === 'error') {
    return errorResponse('Internal server error', 'Credits could not be added', 500);
  }

  console.log(
    'Credits added: device=' +
      deviceId +
      ' product=' +
      productId +
      ' env=' +
      payload.environment +
      ' tx=' +
      payload.transactionId
  );
  const credits = await checkDeviceCredits(env, deviceId);
  return jsonResponse({
    success: true,
    creditsAdded: creditsToAdd,
    environment: payload.environment,
    newBalance: {
      freeRemaining: credits.freeRemaining,
      paidCredits: credits.paidCredits,
      totalCredits: credits.freeRemaining + credits.paidCredits,
    },
  });
}
