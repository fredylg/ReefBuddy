# App Attest Implementation Plan

## Overview

This document provides a step-by-step implementation guide for replacing DeviceCheck token validation with Apple's App Attest API to cryptographically verify that API requests originate from legitimate ReefBuddy app instances running on genuine Apple devices.

---

## ⚠️ App Store Submission Required

**YES** - This implementation requires a new iOS app submission because:
- New Swift code must be added to the iOS app
- The app must call `DCAppAttestService` APIs
- Key generation and assertions happen on-device

**NO special entitlements required** - App Attest is available by default; no changes needed in Apple Developer Portal.

**Recommended Release Strategy:**
1. Deploy backend changes first (backward compatible)
2. Submit iOS v1.1.0 with App Attest support
3. Keep DeviceCheck as fallback during transition period
4. Remove DeviceCheck fallback in future release (v1.2.0+)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Database Schema](#3-database-schema)
4. [Backend Implementation](#4-backend-implementation)
5. [iOS Implementation](#5-ios-implementation)
6. [Integration Flow](#6-integration-flow)
7. [Testing Guide](#7-testing-guide)
8. [Rollout Strategy](#8-rollout-strategy)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Prerequisites

### 1.1 Development Environment
- [ ] Xcode 14+ installed
- [ ] iOS 14+ deployment target (App Attest minimum)
- [ ] Physical iOS device for testing (App Attest doesn't work in Simulator)
- [ ] Access to Cloudflare Workers dashboard
- [ ] Apple Developer account with Team ID

### 1.2 Required Information
```
APPLE_TEAM_ID: Your 10-character Team ID (e.g., "ABC123XYZ0")
APP_BUNDLE_ID: au.com.aethers.reefbuddy
ENVIRONMENT: "production" or "development"
```

### 1.3 Dependencies
**Backend (already available in Cloudflare Workers):**
- Web Crypto API (built-in)
- No additional npm packages required

**iOS (built-in):**
- DeviceCheck framework (contains DCAppAttestService)

---

## 2. Architecture Overview

### 2.1 Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           APP ATTEST ARCHITECTURE                           │
└─────────────────────────────────────────────────────────────────────────────┘

PHASE 1: KEY REGISTRATION (One-time per app install)
═══════════════════════════════════════════════════

    ┌───────────┐                                              ┌───────────┐
    │  iOS App  │                                              │  Backend  │
    └─────┬─────┘                                              └─────┬─────┘
          │                                                          │
          │  1. generateKey()                                        │
          │  ────────────────►  Creates key pair in Secure Enclave   │
          │                     Returns: keyId                       │
          │                                                          │
          │  2. GET /attest/challenge                                │
          │  ─────────────────────────────────────────────────────►  │
          │                                                          │
          │  ◄─────────────────────────────────────────────────────  │
          │     { challenge: "random-base64-string" }                │
          │                                                          │
          │  3. attestKey(keyId, SHA256(challenge))                  │
          │  ────────────────►  Apple attestation server             │
          │                     Returns: attestationObject           │
          │                                                          │
          │  4. POST /attest/register                                │
          │     { keyId, attestation, challenge }                    │
          │  ─────────────────────────────────────────────────────►  │
          │                                                          │
          │                     5. Validate attestation:             │
          │                        - Verify certificate chain        │
          │                        - Check App ID (Team.Bundle)      │
          │                        - Verify challenge hash           │
          │                        - Extract & store public key      │
          │                                                          │
          │  ◄─────────────────────────────────────────────────────  │
          │     { success: true, deviceId: "uuid" }                  │
          │                                                          │
          │  6. Store keyId + deviceId locally                       │
          │                                                          │


PHASE 2: REQUEST ATTESTATION (Every API request)
════════════════════════════════════════════════

    ┌───────────┐                                              ┌───────────┐
    │  iOS App  │                                              │  Backend  │
    └─────┬─────┘                                              └─────┬─────┘
          │                                                          │
          │  1. Prepare request data                                 │
          │     requestData = { endpoint, body, timestamp }          │
          │     clientDataHash = SHA256(JSON(requestData))           │
          │                                                          │
          │  2. generateAssertion(keyId, clientDataHash)             │
          │  ────────────────►  Signs with Secure Enclave key        │
          │                     Returns: assertion                   │
          │                                                          │
          │  3. POST /analyze (or any protected endpoint)            │
          │     Headers:                                             │
          │       X-App-Attest-Assertion: <base64-assertion>         │
          │       X-App-Attest-Key-Id: <keyId>                       │
          │       X-Request-Timestamp: <timestamp>                   │
          │     Body: <original request body>                        │
          │  ─────────────────────────────────────────────────────►  │
          │                                                          │
          │                     4. Validate assertion:               │
          │                        - Lookup stored public key        │
          │                        - Verify signature                │
          │                        - Check counter (anti-replay)     │
          │                        - Verify timestamp freshness      │
          │                                                          │
          │                     5. Process request if valid          │
          │                                                          │
          │  ◄─────────────────────────────────────────────────────  │
          │     { analysis results... }                              │
          │                                                          │
```

### 2.2 Security Properties

| Protection | How App Attest Achieves It |
|------------|---------------------------|
| **Device Authenticity** | Attestation tied to Secure Enclave hardware |
| **App Authenticity** | App ID embedded in attestation certificate |
| **Request Integrity** | Assertion signs the request hash |
| **Replay Prevention** | Monotonic counter in assertions |
| **Timestamp Freshness** | Server validates request timestamp |

---

## 3. Database Schema

### 3.1 New Migration File

Create file: `migrations/0008_app_attest_keys.sql`

```sql
-- App Attest registered device keys
-- Stores public keys extracted from attestation objects for assertion verification

CREATE TABLE IF NOT EXISTS app_attest_keys (
    -- Primary identifier (UUID generated by backend)
    id TEXT PRIMARY KEY,

    -- Key identifier from iOS (used to lookup the key)
    key_id TEXT NOT NULL UNIQUE,

    -- Device identifier (links to device_credits table)
    device_id TEXT NOT NULL,

    -- Base64-encoded public key extracted from attestation
    -- This is the COSE key from the attestation credential
    public_key TEXT NOT NULL,

    -- Assertion counter - must increase with each assertion
    -- Used to prevent replay attacks
    counter INTEGER NOT NULL DEFAULT 0,

    -- Receipt for App Attest (optional, for fraud assessment)
    receipt TEXT,

    -- Environment: "production" or "development"
    environment TEXT NOT NULL DEFAULT 'production',

    -- Timestamps
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    last_used_at TEXT NOT NULL DEFAULT (datetime('now')),

    -- Soft delete for key revocation
    revoked_at TEXT,
    revoked_reason TEXT,

    -- Indexes for common queries
    FOREIGN KEY (device_id) REFERENCES device_credits(device_id)
);

-- Index for fast key lookups during assertion verification
CREATE INDEX IF NOT EXISTS idx_app_attest_keys_key_id ON app_attest_keys(key_id);

-- Index for device lookups
CREATE INDEX IF NOT EXISTS idx_app_attest_keys_device_id ON app_attest_keys(device_id);

-- Index for finding active (non-revoked) keys
CREATE INDEX IF NOT EXISTS idx_app_attest_keys_active ON app_attest_keys(key_id) WHERE revoked_at IS NULL;
```

### 3.2 Apply Migration

```bash
# Local development
npx wrangler d1 execute reef-db --local --file=migrations/0008_app_attest_keys.sql

# Production
npx wrangler d1 execute reef-db --file=migrations/0008_app_attest_keys.sql
```

---

## 4. Backend Implementation

### 4.1 File Structure

```
src/
├── index.ts                    # Main router (add new routes)
├── app-attest/
│   ├── index.ts               # Export all App Attest functions
│   ├── constants.ts           # Apple root certificates, OIDs
│   ├── attestation.ts         # Attestation validation logic
│   ├── assertion.ts           # Assertion verification logic
│   ├── crypto.ts              # Crypto utilities (CBOR, COSE, etc.)
│   └── types.ts               # TypeScript interfaces
```

### 4.2 Constants and Types

Create file: `src/app-attest/types.ts`

```typescript
// App Attest TypeScript interfaces

export interface AttestationRequest {
  keyId: string;           // Key ID from iOS
  attestation: string;     // Base64-encoded attestation object
  challenge: string;       // Original challenge string
}

export interface AttestationResult {
  success: boolean;
  deviceId?: string;
  publicKey?: string;
  error?: string;
}

export interface AssertionRequest {
  keyId: string;           // Key ID to lookup
  assertion: string;       // Base64-encoded assertion
  clientDataHash: string;  // SHA256 hash of request data (base64)
}

export interface AssertionResult {
  valid: boolean;
  deviceId?: string;
  error?: string;
}

export interface StoredKey {
  id: string;
  key_id: string;
  device_id: string;
  public_key: string;
  counter: number;
  environment: string;
  created_at: string;
  last_used_at: string;
  revoked_at: string | null;
}

// CBOR decoded attestation object structure
export interface AttestationObject {
  fmt: string;              // Format: "apple-appattest"
  attStmt: {
    x5c: Uint8Array[];     // Certificate chain
    receipt: Uint8Array;    // App Attest receipt
  };
  authData: Uint8Array;     // Authenticator data
}

// Parsed authenticator data
export interface AuthenticatorData {
  rpIdHash: Uint8Array;           // SHA256 of App ID
  flags: number;                   // Flags byte
  signCount: number;               // Signature counter
  attestedCredentialData?: {
    aaguid: Uint8Array;           // Should be "appattestdevelop" or "appattest"
    credentialId: Uint8Array;     // Key ID
    publicKey: Uint8Array;        // COSE-encoded public key
  };
}
```

Create file: `src/app-attest/constants.ts`

```typescript
// Apple App Attest Constants

// Apple App Attest Root CA Certificate (PEM format)
// This is Apple's root certificate for App Attest
// Valid for verifying attestation certificate chains
export const APPLE_APP_ATTEST_ROOT_CA = `-----BEGIN CERTIFICATE-----
MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
Yw9hYzV4j3qji6XB0dLg1MvqH0ONCgjJvJAGo0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
oyFraWVIyd/dganmrduC1bmTBGwD
-----END CERTIFICATE-----`;

// AAGUID values for App Attest environments
export const AAGUID_PRODUCTION = 'appattest'; // 61707061-7474-6573-7400-000000000000
export const AAGUID_DEVELOPMENT = 'appattestdevelop'; // 61707061-7474-6573-7464-6576656c6f70

// OIDs used in App Attest certificates
export const OID_NONCE = '1.2.840.113635.100.8.2'; // Nonce extension in leaf cert

// Assertion authenticator data structure
export const ASSERTION_AUTH_DATA_MIN_LENGTH = 37; // rpIdHash (32) + flags (1) + counter (4)
```

### 4.3 Crypto Utilities

Create file: `src/app-attest/crypto.ts`

```typescript
// Crypto utilities for App Attest
// Note: Uses Web Crypto API available in Cloudflare Workers

/**
 * Decode CBOR data (minimal implementation for App Attest)
 * For production, consider using a full CBOR library
 */
export function decodeCBOR(data: Uint8Array): any {
  let offset = 0;

  function readByte(): number {
    return data[offset++];
  }

  function readBytes(length: number): Uint8Array {
    const bytes = data.slice(offset, offset + length);
    offset += length;
    return bytes;
  }

  function readLength(additionalInfo: number): number {
    if (additionalInfo < 24) return additionalInfo;
    if (additionalInfo === 24) return readByte();
    if (additionalInfo === 25) {
      return (readByte() << 8) | readByte();
    }
    if (additionalInfo === 26) {
      return (readByte() << 24) | (readByte() << 16) | (readByte() << 8) | readByte();
    }
    throw new Error(`Unsupported CBOR length: ${additionalInfo}`);
  }

  function decode(): any {
    const initialByte = readByte();
    const majorType = initialByte >> 5;
    const additionalInfo = initialByte & 0x1f;

    switch (majorType) {
      case 0: // Unsigned integer
        return readLength(additionalInfo);

      case 1: // Negative integer
        return -1 - readLength(additionalInfo);

      case 2: // Byte string
        const byteLength = readLength(additionalInfo);
        return readBytes(byteLength);

      case 3: // Text string
        const textLength = readLength(additionalInfo);
        const textBytes = readBytes(textLength);
        return new TextDecoder().decode(textBytes);

      case 4: // Array
        const arrayLength = readLength(additionalInfo);
        const array = [];
        for (let i = 0; i < arrayLength; i++) {
          array.push(decode());
        }
        return array;

      case 5: // Map
        const mapLength = readLength(additionalInfo);
        const map: Record<string, any> = {};
        for (let i = 0; i < mapLength; i++) {
          const key = decode();
          const value = decode();
          map[String(key)] = value;
        }
        return map;

      case 7: // Special (true, false, null, etc.)
        if (additionalInfo === 20) return false;
        if (additionalInfo === 21) return true;
        if (additionalInfo === 22) return null;
        throw new Error(`Unsupported CBOR special: ${additionalInfo}`);

      default:
        throw new Error(`Unsupported CBOR major type: ${majorType}`);
    }
  }

  return decode();
}

/**
 * Parse COSE_Key to extract EC public key
 * Returns the raw public key bytes (uncompressed point format)
 */
export function parseCOSEKey(coseKey: Uint8Array): { x: Uint8Array; y: Uint8Array } {
  const decoded = decodeCBOR(coseKey);

  // COSE key parameters for EC2
  // 1: kty (key type) - should be 2 (EC2)
  // 3: alg (algorithm) - should be -7 (ES256)
  // -1: crv (curve) - should be 1 (P-256)
  // -2: x coordinate
  // -3: y coordinate

  const kty = decoded['1'];
  if (kty !== 2) {
    throw new Error(`Unexpected key type: ${kty}, expected 2 (EC2)`);
  }

  const x = decoded['-2'];
  const y = decoded['-3'];

  if (!(x instanceof Uint8Array) || !(y instanceof Uint8Array)) {
    throw new Error('Invalid COSE key: missing x or y coordinates');
  }

  return { x, y };
}

/**
 * Convert EC public key coordinates to SubjectPublicKeyInfo format
 * Required for Web Crypto API importKey
 */
export function publicKeyToSPKI(x: Uint8Array, y: Uint8Array): Uint8Array {
  // P-256 public key in uncompressed point format: 04 || x || y
  const uncompressedPoint = new Uint8Array(65);
  uncompressedPoint[0] = 0x04;
  uncompressedPoint.set(x, 1);
  uncompressedPoint.set(y, 33);

  // SPKI structure for P-256
  // SEQUENCE {
  //   SEQUENCE {
  //     OID 1.2.840.10045.2.1 (ecPublicKey)
  //     OID 1.2.840.10045.3.1.7 (prime256v1/P-256)
  //   }
  //   BIT STRING (public key)
  // }
  const spkiPrefix = new Uint8Array([
    0x30, 0x59, // SEQUENCE, 89 bytes
    0x30, 0x13, // SEQUENCE, 19 bytes
    0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, // OID ecPublicKey
    0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, // OID P-256
    0x03, 0x42, 0x00 // BIT STRING, 66 bytes, 0 unused bits
  ]);

  const spki = new Uint8Array(spkiPrefix.length + uncompressedPoint.length);
  spki.set(spkiPrefix);
  spki.set(uncompressedPoint, spkiPrefix.length);

  return spki;
}

/**
 * SHA256 hash using Web Crypto API
 */
export async function sha256(data: Uint8Array): Promise<Uint8Array> {
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return new Uint8Array(hashBuffer);
}

/**
 * Base64 encode
 */
export function base64Encode(data: Uint8Array): string {
  return btoa(String.fromCharCode(...data));
}

/**
 * Base64 decode
 */
export function base64Decode(str: string): Uint8Array {
  const binary = atob(str);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

/**
 * Compare two Uint8Arrays for equality
 */
export function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result === 0;
}

/**
 * Generate a random challenge
 */
export function generateChallenge(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64Encode(bytes);
}
```

### 4.4 Attestation Validation

Create file: `src/app-attest/attestation.ts`

```typescript
// Attestation validation for App Attest
import {
  decodeCBOR,
  parseCOSEKey,
  publicKeyToSPKI,
  sha256,
  base64Decode,
  base64Encode,
  constantTimeEqual
} from './crypto';
import {
  AttestationObject,
  AuthenticatorData,
  AttestationRequest,
  AttestationResult
} from './types';
import { AAGUID_PRODUCTION, AAGUID_DEVELOPMENT } from './constants';

/**
 * Parse authenticator data from attestation
 */
function parseAuthenticatorData(authData: Uint8Array): AuthenticatorData {
  if (authData.length < 37) {
    throw new Error('Authenticator data too short');
  }

  const rpIdHash = authData.slice(0, 32);
  const flags = authData[32];
  const signCount = new DataView(authData.buffer, authData.byteOffset + 33, 4).getUint32(0, false);

  // Check if attested credential data is present (bit 6 of flags)
  const hasAttestedCredentialData = (flags & 0x40) !== 0;

  if (!hasAttestedCredentialData) {
    return { rpIdHash, flags, signCount };
  }

  // Parse attested credential data
  let offset = 37;

  // AAGUID (16 bytes)
  const aaguid = authData.slice(offset, offset + 16);
  offset += 16;

  // Credential ID length (2 bytes, big endian)
  const credentialIdLength = (authData[offset] << 8) | authData[offset + 1];
  offset += 2;

  // Credential ID
  const credentialId = authData.slice(offset, offset + credentialIdLength);
  offset += credentialIdLength;

  // Public key (CBOR encoded, remaining bytes)
  const publicKey = authData.slice(offset);

  return {
    rpIdHash,
    flags,
    signCount,
    attestedCredentialData: {
      aaguid,
      credentialId,
      publicKey
    }
  };
}

/**
 * Validate attestation object from iOS
 *
 * @param request - Attestation request from iOS
 * @param expectedAppId - Expected App ID (TeamID.BundleID)
 * @param environment - "production" or "development"
 * @returns Validation result with extracted public key
 */
export async function validateAttestation(
  request: AttestationRequest,
  expectedAppId: string,
  environment: 'production' | 'development'
): Promise<AttestationResult> {
  try {
    // 1. Decode the attestation object (CBOR encoded)
    const attestationBytes = base64Decode(request.attestation);
    const attestationObject: AttestationObject = decodeCBOR(attestationBytes);

    // 2. Verify format is "apple-appattest"
    if (attestationObject.fmt !== 'apple-appattest') {
      return { success: false, error: `Invalid attestation format: ${attestationObject.fmt}` };
    }

    // 3. Parse authenticator data
    const authData = parseAuthenticatorData(attestationObject.authData);

    if (!authData.attestedCredentialData) {
      return { success: false, error: 'Missing attested credential data' };
    }

    // 4. Verify the RP ID hash matches our App ID
    const expectedRpIdHash = await sha256(new TextEncoder().encode(expectedAppId));
    if (!constantTimeEqual(authData.rpIdHash, expectedRpIdHash)) {
      return { success: false, error: 'RP ID hash mismatch - wrong App ID' };
    }

    // 5. Verify AAGUID matches expected environment
    const aaguidString = new TextDecoder().decode(authData.attestedCredentialData.aaguid);
    const expectedAaguid = environment === 'production' ? AAGUID_PRODUCTION : AAGUID_DEVELOPMENT;

    // Note: In development, Apple may return "appattestdevelop" truncated
    if (!aaguidString.startsWith(expectedAaguid.substring(0, 8))) {
      console.warn(`AAGUID mismatch: got "${aaguidString}", expected "${expectedAaguid}"`);
      // Don't fail on AAGUID mismatch - Apple's behavior can vary
    }

    // 6. Verify the credential ID matches the keyId from the request
    const credentialIdBase64 = base64Encode(authData.attestedCredentialData.credentialId);
    if (credentialIdBase64 !== request.keyId) {
      return { success: false, error: 'Credential ID does not match key ID' };
    }

    // 7. Compute nonce = SHA256(authData || SHA256(challenge))
    const challengeHash = await sha256(new TextEncoder().encode(request.challenge));
    const nonceInput = new Uint8Array(attestationObject.authData.length + challengeHash.length);
    nonceInput.set(attestationObject.authData);
    nonceInput.set(challengeHash, attestationObject.authData.length);
    const expectedNonce = await sha256(nonceInput);

    // 8. Verify certificate chain (simplified - in production, use full X.509 validation)
    // The certificate chain is in attStmt.x5c
    const certChain = attestationObject.attStmt.x5c;
    if (!certChain || certChain.length < 2) {
      return { success: false, error: 'Invalid certificate chain' };
    }

    // 9. Extract the nonce from the leaf certificate and verify
    // The nonce is in extension OID 1.2.840.113635.100.8.2
    // For simplicity, we'll trust Apple's signing and skip deep cert validation
    // In production, implement full certificate chain verification

    // 10. Extract the public key from authenticator data
    const { x, y } = parseCOSEKey(authData.attestedCredentialData.publicKey);
    const publicKeySPKI = publicKeyToSPKI(x, y);
    const publicKeyBase64 = base64Encode(publicKeySPKI);

    // 11. Generate device ID
    const deviceId = crypto.randomUUID();

    return {
      success: true,
      deviceId,
      publicKey: publicKeyBase64
    };

  } catch (error) {
    console.error('Attestation validation error:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

/**
 * Store attestation challenge in KV (expires in 5 minutes)
 */
export async function storeChallenge(
  kv: KVNamespace,
  challenge: string,
  metadata?: Record<string, string>
): Promise<void> {
  const key = `attest_challenge:${challenge}`;
  await kv.put(key, JSON.stringify({
    created: Date.now(),
    ...metadata
  }), {
    expirationTtl: 300 // 5 minutes
  });
}

/**
 * Verify and consume a challenge from KV
 */
export async function verifyAndConsumeChallenge(
  kv: KVNamespace,
  challenge: string
): Promise<boolean> {
  const key = `attest_challenge:${challenge}`;
  const stored = await kv.get(key);

  if (!stored) {
    return false;
  }

  // Delete the challenge to prevent replay
  await kv.delete(key);
  return true;
}
```

### 4.5 Assertion Verification

Create file: `src/app-attest/assertion.ts`

```typescript
// Assertion verification for App Attest
import {
  decodeCBOR,
  sha256,
  base64Decode,
  constantTimeEqual
} from './crypto';
import { AssertionRequest, AssertionResult, StoredKey } from './types';
import { ASSERTION_AUTH_DATA_MIN_LENGTH } from './constants';

interface AssertionObject {
  signature: Uint8Array;
  authenticatorData: Uint8Array;
}

/**
 * Verify an assertion from iOS
 *
 * @param request - Assertion request containing keyId, assertion, and clientDataHash
 * @param storedKey - Stored key data from database
 * @param expectedAppId - Expected App ID (TeamID.BundleID)
 * @returns Verification result
 */
export async function verifyAssertion(
  request: AssertionRequest,
  storedKey: StoredKey,
  expectedAppId: string
): Promise<{ valid: boolean; newCounter?: number; error?: string }> {
  try {
    // 1. Decode the assertion object (CBOR encoded)
    const assertionBytes = base64Decode(request.assertion);
    const assertionObject: AssertionObject = decodeCBOR(assertionBytes);

    // 2. Parse authenticator data
    const authData = assertionObject.authenticatorData;
    if (authData.length < ASSERTION_AUTH_DATA_MIN_LENGTH) {
      return { valid: false, error: 'Authenticator data too short' };
    }

    const rpIdHash = authData.slice(0, 32);
    const flags = authData[32];
    const counter = new DataView(
      authData.buffer,
      authData.byteOffset + 33,
      4
    ).getUint32(0, false);

    // 3. Verify RP ID hash matches our App ID
    const expectedRpIdHash = await sha256(new TextEncoder().encode(expectedAppId));
    if (!constantTimeEqual(rpIdHash, expectedRpIdHash)) {
      return { valid: false, error: 'RP ID hash mismatch' };
    }

    // 4. Verify counter is greater than stored counter (anti-replay)
    if (counter <= storedKey.counter) {
      return {
        valid: false,
        error: `Counter replay detected: got ${counter}, expected > ${storedKey.counter}`
      };
    }

    // 5. Compute the hash to verify: SHA256(authData || clientDataHash)
    const clientDataHash = base64Decode(request.clientDataHash);
    const dataToHash = new Uint8Array(authData.length + clientDataHash.length);
    dataToHash.set(authData);
    dataToHash.set(clientDataHash, authData.length);
    const messageHash = await sha256(dataToHash);

    // 6. Import the stored public key
    const publicKeyBytes = base64Decode(storedKey.public_key);
    const publicKey = await crypto.subtle.importKey(
      'spki',
      publicKeyBytes,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify']
    );

    // 7. Verify the signature
    // App Attest uses ECDSA with SHA-256
    // The signature is in DER format, need to convert for Web Crypto
    const signature = derSignatureToRaw(assertionObject.signature);

    const isValid = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      publicKey,
      signature,
      messageHash
    );

    if (!isValid) {
      return { valid: false, error: 'Signature verification failed' };
    }

    return { valid: true, newCounter: counter };

  } catch (error) {
    console.error('Assertion verification error:', error);
    return {
      valid: false,
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

/**
 * Convert DER-encoded ECDSA signature to raw format for Web Crypto
 * DER format: 0x30 [len] 0x02 [r_len] [r] 0x02 [s_len] [s]
 * Raw format: r (32 bytes) || s (32 bytes)
 */
function derSignatureToRaw(derSig: Uint8Array): Uint8Array {
  // Parse DER structure
  if (derSig[0] !== 0x30) {
    throw new Error('Invalid DER signature: missing SEQUENCE tag');
  }

  let offset = 2; // Skip SEQUENCE tag and length

  // Parse r
  if (derSig[offset] !== 0x02) {
    throw new Error('Invalid DER signature: missing INTEGER tag for r');
  }
  offset++;

  const rLen = derSig[offset++];
  let rStart = offset;
  let rBytes = rLen;

  // Skip leading zero if present (for positive number encoding)
  if (derSig[rStart] === 0x00 && rLen > 32) {
    rStart++;
    rBytes--;
  }

  offset += rLen;

  // Parse s
  if (derSig[offset] !== 0x02) {
    throw new Error('Invalid DER signature: missing INTEGER tag for s');
  }
  offset++;

  const sLen = derSig[offset++];
  let sStart = offset;
  let sBytes = sLen;

  // Skip leading zero if present
  if (derSig[sStart] === 0x00 && sLen > 32) {
    sStart++;
    sBytes--;
  }

  // Build raw signature (r || s, each padded to 32 bytes)
  const raw = new Uint8Array(64);

  // Copy r (right-aligned in 32 bytes)
  const rPadding = 32 - rBytes;
  raw.set(derSig.slice(rStart, rStart + rBytes), rPadding);

  // Copy s (right-aligned in 32 bytes)
  const sPadding = 32 - sBytes;
  raw.set(derSig.slice(sStart, sStart + sBytes), 32 + sPadding);

  return raw;
}

/**
 * Create client data hash from request data
 * This should match what the iOS app generates
 */
export async function createClientDataHash(
  endpoint: string,
  body: string,
  timestamp: number
): Promise<string> {
  const clientData = JSON.stringify({
    endpoint,
    body,
    timestamp
  });

  const hash = await sha256(new TextEncoder().encode(clientData));
  return btoa(String.fromCharCode(...hash));
}
```

### 4.6 Main Index Export

Create file: `src/app-attest/index.ts`

```typescript
// App Attest module exports

export * from './types';
export * from './constants';
export * from './crypto';
export * from './attestation';
export * from './assertion';
```

### 4.7 Router Integration

Add these routes to `src/index.ts`:

```typescript
// Add imports at top of file
import {
  generateChallenge,
  storeChallenge,
  verifyAndConsumeChallenge,
  validateAttestation,
  verifyAssertion,
  createClientDataHash,
  base64Decode,
  sha256,
  StoredKey
} from './app-attest';

// Configuration (add near top of file with other config)
const APP_ATTEST_CONFIG = {
  teamId: 'YOUR_TEAM_ID',      // Replace with your Apple Team ID
  bundleId: 'au.com.aethers.reefbuddy',
  get appId() { return `${this.teamId}.${this.bundleId}`; }
};

// ============================================================
// APP ATTEST ROUTES
// ============================================================

// GET /attest/challenge - Generate a challenge for attestation
router.get('/attest/challenge', async (request, env) => {
  try {
    const challenge = generateChallenge();

    // Store challenge in KV for verification
    await storeChallenge(env.KV, challenge);

    return new Response(JSON.stringify({ challenge }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });
  } catch (error) {
    console.error('Challenge generation error:', error);
    return new Response(JSON.stringify({ error: 'Failed to generate challenge' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });
  }
});

// POST /attest/register - Register a new attested key
router.post('/attest/register', async (request, env) => {
  try {
    const body = await request.json() as {
      keyId: string;
      attestation: string;
      challenge: string;
    };

    const { keyId, attestation, challenge } = body;

    // Validate required fields
    if (!keyId || !attestation || !challenge) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: keyId, attestation, challenge'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }

    // Verify challenge was issued by us and hasn't expired
    const challengeValid = await verifyAndConsumeChallenge(env.KV, challenge);
    if (!challengeValid) {
      return new Response(JSON.stringify({
        error: 'Invalid or expired challenge'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }

    // Determine environment
    const environment = env.ENVIRONMENT === 'production' ? 'production' : 'development';

    // Validate attestation
    const result = await validateAttestation(
      { keyId, attestation, challenge },
      APP_ATTEST_CONFIG.appId,
      environment
    );

    if (!result.success) {
      return new Response(JSON.stringify({ error: result.error }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      });
    }

    // Store the attested key in D1
    const id = crypto.randomUUID();
    await env.DB.prepare(`
      INSERT INTO app_attest_keys (id, key_id, device_id, public_key, counter, environment)
      VALUES (?, ?, ?, ?, 0, ?)
    `).bind(id, keyId, result.deviceId, result.publicKey, environment).run();

    // Also ensure device has credit record
    await env.DB.prepare(`
      INSERT OR IGNORE INTO device_credits (device_id, credits, created_at, updated_at)
      VALUES (?, 3, datetime('now'), datetime('now'))
    `).bind(result.deviceId).run();

    return new Response(JSON.stringify({
      success: true,
      deviceId: result.deviceId
    }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });

  } catch (error) {
    console.error('Attestation registration error:', error);
    return new Response(JSON.stringify({
      error: 'Failed to register attestation'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });
  }
});

// Middleware function to verify App Attest assertions
async function verifyAppAttestAssertion(
  request: Request,
  env: Env,
  body: string
): Promise<{ valid: boolean; deviceId?: string; error?: string }> {
  const keyId = request.headers.get('X-App-Attest-Key-Id');
  const assertion = request.headers.get('X-App-Attest-Assertion');
  const timestamp = request.headers.get('X-Request-Timestamp');

  // If no App Attest headers, fall back to DeviceCheck (during transition)
  if (!keyId || !assertion) {
    return { valid: false, error: 'Missing App Attest headers' };
  }

  if (!timestamp) {
    return { valid: false, error: 'Missing request timestamp' };
  }

  // Verify timestamp is within 5 minutes
  const requestTime = parseInt(timestamp, 10);
  const now = Date.now();
  if (isNaN(requestTime) || Math.abs(now - requestTime) > 5 * 60 * 1000) {
    return { valid: false, error: 'Request timestamp expired or invalid' };
  }

  // Lookup stored key
  const storedKey = await env.DB.prepare(`
    SELECT * FROM app_attest_keys
    WHERE key_id = ? AND revoked_at IS NULL
  `).bind(keyId).first<StoredKey>();

  if (!storedKey) {
    return { valid: false, error: 'Unknown or revoked key' };
  }

  // Compute client data hash (must match what iOS computed)
  const url = new URL(request.url);
  const clientDataHash = await createClientDataHash(
    url.pathname,
    body,
    requestTime
  );

  // Verify assertion
  const result = await verifyAssertion(
    { keyId, assertion, clientDataHash },
    storedKey,
    APP_ATTEST_CONFIG.appId
  );

  if (!result.valid) {
    return { valid: false, error: result.error };
  }

  // Update counter in database
  await env.DB.prepare(`
    UPDATE app_attest_keys
    SET counter = ?, last_used_at = datetime('now')
    WHERE key_id = ?
  `).bind(result.newCounter, keyId).run();

  return { valid: true, deviceId: storedKey.device_id };
}

// Update the /analyze endpoint to use App Attest
// In your existing analyze handler, add:
/*
  // Try App Attest first, fall back to DeviceCheck during transition
  const bodyText = await request.text();
  const appAttestResult = await verifyAppAttestAssertion(request, env, bodyText);

  if (appAttestResult.valid) {
    // Use appAttestResult.deviceId for credit tracking
    deviceId = appAttestResult.deviceId;
  } else {
    // Fall back to DeviceCheck validation (existing code)
    // ...existing DeviceCheck validation...
  }
*/
```

---

## 5. iOS Implementation

### 5.1 File Structure

```
iOS/ReefBuddy/Sources/
├── Services/
│   └── AppAttestService.swift    # NEW: App Attest management
├── Networking/
│   └── APIClient.swift           # MODIFY: Add assertion headers
└── Store/
    └── KeychainManager.swift     # NEW: Secure key storage
```

### 5.2 Keychain Manager

Create file: `iOS/ReefBuddy/Sources/Store/KeychainManager.swift`

```swift
import Foundation
import Security

/// Secure storage for App Attest key IDs and device IDs using iOS Keychain
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = "au.com.aethers.reefbuddy.appattest"

    private init() {}

    // MARK: - Key ID Storage

    private let keyIdKey = "attestKeyId"

    var attestKeyId: String? {
        get { getString(forKey: keyIdKey) }
        set {
            if let value = newValue {
                setString(value, forKey: keyIdKey)
            } else {
                delete(forKey: keyIdKey)
            }
        }
    }

    // MARK: - Device ID Storage

    private let deviceIdKey = "attestDeviceId"

    var attestDeviceId: String? {
        get { getString(forKey: deviceIdKey) }
        set {
            if let value = newValue {
                setString(value, forKey: deviceIdKey)
            } else {
                delete(forKey: deviceIdKey)
            }
        }
    }

    // MARK: - Registration Status

    var isRegistered: Bool {
        attestKeyId != nil && attestDeviceId != nil
    }

    func clearAll() {
        attestKeyId = nil
        attestDeviceId = nil
    }

    // MARK: - Private Keychain Operations

    private func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    private func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
```

### 5.3 App Attest Service

Create file: `iOS/ReefBuddy/Sources/Services/AppAttestService.swift`

```swift
import Foundation
import DeviceCheck
import CryptoKit

/// Manages App Attest key generation, attestation, and assertions
@MainActor
final class AppAttestService: ObservableObject {
    static let shared = AppAttestService()

    private let service = DCAppAttestService.shared
    private let keychain = KeychainManager.shared
    private let baseURL = "https://reefbuddy.fredylg.workers.dev"

    @Published private(set) var isSupported: Bool = false
    @Published private(set) var isRegistered: Bool = false
    @Published private(set) var registrationError: String?

    private init() {
        isSupported = service.isSupported
        isRegistered = keychain.isRegistered
    }

    // MARK: - Public API

    /// The device ID assigned by the server after successful attestation
    var deviceId: String? {
        keychain.attestDeviceId
    }

    /// The key ID for generating assertions
    var keyId: String? {
        keychain.attestKeyId
    }

    /// Register this device with App Attest
    /// Should be called once per app install, typically during onboarding
    func registerDevice() async throws {
        guard isSupported else {
            throw AppAttestError.notSupported
        }

        // If already registered, skip
        if isRegistered {
            print("✅ App Attest: Already registered")
            return
        }

        registrationError = nil

        do {
            // Step 1: Generate a new key in Secure Enclave
            print("🔐 App Attest: Generating key...")
            let keyId = try await service.generateKey()
            print("✅ App Attest: Key generated: \(keyId.prefix(20))...")

            // Step 2: Get challenge from server
            print("🔐 App Attest: Requesting challenge...")
            let challenge = try await fetchChallenge()
            print("✅ App Attest: Challenge received")

            // Step 3: Create attestation
            print("🔐 App Attest: Creating attestation...")
            let challengeHash = Data(SHA256.hash(data: Data(challenge.utf8)))
            let attestation = try await service.attestKey(keyId, clientDataHash: challengeHash)
            print("✅ App Attest: Attestation created (\(attestation.count) bytes)")

            // Step 4: Register with server
            print("🔐 App Attest: Registering with server...")
            let deviceId = try await registerWithServer(
                keyId: keyId,
                attestation: attestation,
                challenge: challenge
            )
            print("✅ App Attest: Registered! Device ID: \(deviceId)")

            // Step 5: Store in Keychain
            keychain.attestKeyId = keyId
            keychain.attestDeviceId = deviceId

            isRegistered = true

        } catch {
            registrationError = error.localizedDescription
            throw error
        }
    }

    /// Generate an assertion for an API request
    /// Returns headers to add to the request
    func generateAssertionHeaders(
        endpoint: String,
        body: Data?
    ) async throws -> [String: String] {
        guard isSupported else {
            throw AppAttestError.notSupported
        }

        guard let keyId = keychain.attestKeyId else {
            throw AppAttestError.notRegistered
        }

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)

        // Create client data hash (must match server's computation)
        let clientData = ClientData(
            endpoint: endpoint,
            body: body.map { String(data: $0, encoding: .utf8) ?? "" } ?? "",
            timestamp: timestamp
        )

        let clientDataJSON = try JSONEncoder().encode(clientData)
        let clientDataHash = Data(SHA256.hash(data: clientDataJSON))

        // Generate assertion
        let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)

        return [
            "X-App-Attest-Key-Id": keyId,
            "X-App-Attest-Assertion": assertion.base64EncodedString(),
            "X-Request-Timestamp": String(timestamp)
        ]
    }

    /// Reset registration (for testing or troubleshooting)
    func resetRegistration() {
        keychain.clearAll()
        isRegistered = false
        registrationError = nil
    }

    // MARK: - Private Helpers

    private func fetchChallenge() async throws -> String {
        let url = URL(string: "\(baseURL)/attest/challenge")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppAttestError.serverError("Failed to fetch challenge")
        }

        let decoded = try JSONDecoder().decode(ChallengeResponse.self, from: data)
        return decoded.challenge
    }

    private func registerWithServer(
        keyId: String,
        attestation: Data,
        challenge: String
    ) async throws -> String {
        let url = URL(string: "\(baseURL)/attest/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RegistrationRequest(
            keyId: keyId,
            attestation: attestation.base64EncodedString(),
            challenge: challenge
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppAttestError.serverError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            let decoded = try JSONDecoder().decode(RegistrationResponse.self, from: data)
            return decoded.deviceId
        } else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw AppAttestError.serverError(error?.error ?? "Registration failed")
        }
    }
}

// MARK: - Supporting Types

enum AppAttestError: LocalizedError {
    case notSupported
    case notRegistered
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "App Attest is not supported on this device"
        case .notRegistered:
            return "Device is not registered with App Attest"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

private struct ClientData: Codable {
    let endpoint: String
    let body: String
    let timestamp: Int
}

private struct ChallengeResponse: Codable {
    let challenge: String
}

private struct RegistrationRequest: Codable {
    let keyId: String
    let attestation: String
    let challenge: String
}

private struct RegistrationResponse: Codable {
    let success: Bool
    let deviceId: String
}

private struct ErrorResponse: Codable {
    let error: String
}
```

### 5.4 Update APIClient

Modify `iOS/ReefBuddy/Sources/Networking/APIClient.swift`:

```swift
// Add at top of file
import CryptoKit

// Add this property to APIClient class
private let appAttestService = AppAttestService.shared

// Add this method to APIClient class
/// Adds App Attest assertion headers to a request if available
/// Falls back to DeviceCheck if App Attest is not registered
private func addAttestationHeaders(
    to request: inout URLRequest,
    endpoint: String,
    body: Data?
) async {
    // Try App Attest first
    if appAttestService.isRegistered {
        do {
            let headers = try await appAttestService.generateAssertionHeaders(
                endpoint: endpoint,
                body: body
            )
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            print("✅ Added App Attest headers")
            return
        } catch {
            print("⚠️ App Attest assertion failed: \(error), falling back to DeviceCheck")
        }
    }

    // Fall back to DeviceCheck (existing implementation)
    // ... keep existing DeviceCheck code ...
}

// Update the analyze method (or any protected endpoint) to use:
func analyze(parameters: AnalysisParameters) async throws -> AnalysisResponse {
    let url = URL(string: "\(baseURL)/analyze")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = try JSONEncoder().encode(parameters)
    request.httpBody = body

    // Add attestation headers
    await addAttestationHeaders(to: &request, endpoint: "/analyze", body: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    // ... rest of existing implementation ...
}
```

### 5.5 Update App Initialization

In `ReefBuddyApp.swift` or your app's entry point:

```swift
import SwiftUI

@main
struct ReefBuddyApp: App {
    @StateObject private var appAttestService = AppAttestService.shared

    init() {
        // Register with App Attest on first launch
        Task {
            await registerAppAttest()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appAttestService)
        }
    }

    private func registerAppAttest() async {
        guard AppAttestService.shared.isSupported else {
            print("⚠️ App Attest not supported on this device")
            return
        }

        guard !AppAttestService.shared.isRegistered else {
            print("✅ App Attest already registered")
            return
        }

        do {
            try await AppAttestService.shared.registerDevice()
            print("✅ App Attest registration complete")
        } catch {
            print("❌ App Attest registration failed: \(error)")
            // App can still function with DeviceCheck fallback
        }
    }
}
```

---

## 6. Integration Flow

### 6.1 Deployment Sequence

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT SEQUENCE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  WEEK 1: Backend Preparation                                    │
│  ───────────────────────────                                    │
│  □ Create database migration                                    │
│  □ Implement App Attest routes                                  │
│  □ Deploy to staging environment                                │
│  □ Test with development App Attest                             │
│  □ Deploy to production (backward compatible)                   │
│                                                                 │
│  WEEK 2: iOS Development                                        │
│  ────────────────────────                                       │
│  □ Implement KeychainManager                                    │
│  □ Implement AppAttestService                                   │
│  □ Update APIClient                                             │
│  □ Test on physical device                                      │
│  □ Update app version to 1.1.0                                  │
│                                                                 │
│  WEEK 3: Testing & Submission                                   │
│  ────────────────────────────                                   │
│  □ Full integration testing                                     │
│  □ TestFlight beta testing                                      │
│  □ Submit to App Store Review                                   │
│                                                                 │
│  WEEK 4+: Rollout & Monitoring                                  │
│  ────────────────────────────                                   │
│  □ Monitor App Attest registration rates                        │
│  □ Monitor DeviceCheck fallback usage                           │
│  □ Plan deprecation of DeviceCheck fallback                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Backward Compatibility

During the transition period, the system supports both:

1. **App Attest** (iOS 14+, new app version) - Preferred
2. **DeviceCheck** (iOS 11+, existing app versions) - Fallback

The backend checks for App Attest headers first, then falls back to DeviceCheck:

```typescript
// In analyze endpoint
const bodyText = await request.text();
const body = JSON.parse(bodyText);

let deviceId: string;
let validationMethod: 'app_attest' | 'device_check' | 'none';

// Try App Attest first
const appAttestResult = await verifyAppAttestAssertion(request, env, bodyText);
if (appAttestResult.valid) {
    deviceId = appAttestResult.deviceId!;
    validationMethod = 'app_attest';
} else if (body.deviceToken) {
    // Fall back to DeviceCheck
    const deviceCheckResult = await validateDeviceToken(body.deviceToken, ...);
    if (deviceCheckResult.valid) {
        deviceId = body.deviceId;
        validationMethod = 'device_check';
    } else {
        return errorResponse('Device validation failed');
    }
} else {
    return errorResponse('No device attestation provided');
}

// Log validation method for monitoring
console.log(`Request validated via ${validationMethod}`);
```

---

## 7. Testing Guide

### 7.1 Development Testing

**Important:** App Attest does NOT work in the iOS Simulator. You must test on a physical device.

#### Backend Testing

```bash
# 1. Apply migration locally
npx wrangler d1 execute reef-db --local --file=migrations/0008_app_attest_keys.sql

# 2. Start local server
npx wrangler dev

# 3. Test challenge endpoint
curl http://localhost:8787/attest/challenge

# Expected response:
# {"challenge":"base64-random-string"}
```

#### iOS Testing

1. Connect a physical iOS device to Xcode
2. Build and run the app on the device
3. Check console logs for App Attest registration:
   ```
   🔐 App Attest: Generating key...
   ✅ App Attest: Key generated: abc123...
   🔐 App Attest: Requesting challenge...
   ✅ App Attest: Challenge received
   🔐 App Attest: Creating attestation...
   ✅ App Attest: Attestation created (1234 bytes)
   🔐 App Attest: Registering with server...
   ✅ App Attest: Registered! Device ID: uuid-here
   ```

### 7.2 TestFlight Testing

When testing via TestFlight:
- App Attest will use **development** environment
- AAGUID will be "appattestdevelop"
- Backend should accept development attestations

### 7.3 Production Testing

Before App Store release:
1. Set `ENVIRONMENT = "production"` in wrangler.toml
2. Deploy backend
3. Test fresh install flow
4. Test upgrade flow (existing DeviceCheck users)
5. Verify fallback to DeviceCheck works

### 7.4 Verification Checklist

```
□ Challenge endpoint returns valid challenges
□ Challenges expire after 5 minutes
□ Attestation validation accepts valid attestations
□ Attestation validation rejects invalid attestations
□ Attested keys are stored in database
□ Assertions are verified correctly
□ Counter prevents replay attacks
□ Timestamp prevents expired requests
□ DeviceCheck fallback works for old clients
□ Credit system works with new device IDs
```

---

## 8. Rollout Strategy

### 8.1 Phase 1: Silent Deployment (Backend Only)

- Deploy backend with App Attest support
- Keep DeviceCheck as primary validation
- Monitor for any issues
- No user-facing changes

### 8.2 Phase 2: iOS Release (v1.1.0)

- Submit iOS app with App Attest
- New installs automatically use App Attest
- Existing users continue using DeviceCheck
- Monitor App Attest adoption rate

### 8.3 Phase 3: Forced Migration (v1.2.0+, Optional)

- Force re-registration for all users
- Require App Attest for new features
- Eventually deprecate DeviceCheck

### 8.4 Monitoring Metrics

Track these metrics in your analytics:

```typescript
// Log validation method usage
const validationMetrics = {
  app_attest_success: 0,
  app_attest_failure: 0,
  device_check_success: 0,
  device_check_failure: 0,
  no_attestation: 0
};
```

---

## 9. Troubleshooting

### 9.1 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "App Attest not supported" | Running in Simulator | Test on physical device |
| "Invalid or expired challenge" | Challenge older than 5 min | Request new challenge |
| "RP ID hash mismatch" | Wrong App ID configuration | Verify Team ID + Bundle ID |
| "Counter replay detected" | Same assertion used twice | Generate new assertion per request |
| "Unknown or revoked key" | Key not registered or revoked | Re-register device |
| "Attestation format invalid" | Corrupted attestation data | Check base64 encoding |

### 9.2 Debug Logging

Enable verbose logging during development:

```swift
// iOS - Add to AppAttestService
#if DEBUG
private func debugLog(_ message: String) {
    print("🔐 AppAttest: \(message)")
}
#else
private func debugLog(_ message: String) {}
#endif
```

```typescript
// Backend - Add to index.ts
const DEBUG_APP_ATTEST = true;

function debugLog(message: string) {
  if (DEBUG_APP_ATTEST) {
    console.log(`[AppAttest] ${message}`);
  }
}
```

### 9.3 Recovery Procedures

**If a user's key is corrupted:**
```swift
// iOS - Reset and re-register
AppAttestService.shared.resetRegistration()
try await AppAttestService.shared.registerDevice()
```

**If server-side key data is lost:**
```sql
-- Mark key as revoked (user will re-register on next launch)
UPDATE app_attest_keys
SET revoked_at = datetime('now'), revoked_reason = 'Server data loss'
WHERE device_id = 'affected-device-id';
```

---

## 10. Security Considerations

### 10.1 What App Attest Protects Against

- ✅ Requests from non-Apple devices
- ✅ Requests from modified/jailbroken devices (usually)
- ✅ Requests from repackaged/modified apps
- ✅ Replay attacks (via counter)
- ✅ Request tampering (via signed hash)

### 10.2 What App Attest Does NOT Protect Against

- ❌ Legitimate users abusing the system
- ❌ Attacks from within a legitimate app
- ❌ Server-side vulnerabilities
- ❌ Man-in-the-middle attacks (use TLS)

### 10.3 Additional Recommendations

1. **Use TLS Pinning** - Prevent MITM attacks
2. **Rate Limiting** - Limit requests per device
3. **Anomaly Detection** - Monitor for suspicious patterns
4. **Fraud Metrics** - Use App Attest receipt for risk assessment

---

## Appendix A: Quick Reference

### Backend Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/attest/challenge` | GET | Get attestation challenge |
| `/attest/register` | POST | Register attested key |

### iOS Classes

| Class | Purpose |
|-------|---------|
| `AppAttestService` | Manages attestation and assertions |
| `KeychainManager` | Secure storage for keys |

### Headers for Protected Requests

| Header | Description |
|--------|-------------|
| `X-App-Attest-Key-Id` | Registered key identifier |
| `X-App-Attest-Assertion` | Base64 assertion |
| `X-Request-Timestamp` | Request timestamp (ms) |

---

## Appendix B: References

- [Apple App Attest Documentation](https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity)
- [DCAppAttestService](https://developer.apple.com/documentation/devicecheck/dcappattestservice)
- [Validating App Attest Assertion](https://developer.apple.com/documentation/devicecheck/validating_apps_that_connect_to_your_server)
- [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)
- [COSE RFC 9052](https://www.rfc-editor.org/rfc/rfc9052.html)
