# StoreKit 2 JWS Implementation Plan

## Overview

Migrate from legacy `verifyReceipt` API to StoreKit 2 JWS (JSON Web Signature) validation for in-app purchase verification.

## Current State (Broken)

- iOS uses StoreKit 2 for `product.purchase()`
- iOS tries to get legacy receipt from `Bundle.main.appStoreReceiptURL` (returns nil in Simulator)
- Backend has `validateAppleReceipt()` calling deprecated `verifyReceipt` endpoint
- **Result**: Purchases fail in Simulator, unreliable elsewhere

## Target State

- iOS sends `transaction.jwsRepresentation` (always available)
- Backend verifies JWS signature using Apple's public keys
- Works in Simulator, Sandbox, and Production

---

## Implementation Tasks

### Task 1: iOS - Update StoreManager.swift

**File**: `iOS/ReefBuddy/Sources/Store/StoreManager.swift`

**Current code** (lines 191-222):
```swift
private func validateAndAddCredits(for transaction: Transaction, productId: String) async -> Bool {
    // Get the App Store receipt (BROKEN - nil in Simulator)
    guard let receiptURL = Bundle.main.appStoreReceiptURL,
          let receiptData = try? Data(contentsOf: receiptURL) else {
        purchaseError = "Could not retrieve purchase receipt"
        return false
    }
    // ... sends receiptData to backend
}
```

**New code**:
```swift
private func validateAndAddCredits(for transaction: Transaction, productId: String) async -> Bool {
    // Use StoreKit 2 JWS representation (always available)
    let jwsRepresentation = transaction.jwsRepresentation
    let transactionId = String(transaction.id)
    let originalTransactionId = String(transaction.originalID)

    do {
        let response = try await apiClient.purchaseCredits(
            deviceId: deviceId,
            jwsRepresentation: jwsRepresentation,
            transactionId: transactionId,
            originalTransactionId: originalTransactionId,
            productId: productId
        )
        // Update credit balance...
        return true
    } catch {
        // Error handling...
        return false
    }
}
```

**Status**: [x] Complete

---

### Task 2: iOS - Update APIClient.swift

**File**: `iOS/ReefBuddy/Sources/Networking/APIClient.swift`

**Changes needed**:
1. Update `CreditsPurchaseRequest` struct
2. Update `purchaseCredits()` method

**New request structure**:
```swift
struct CreditsPurchaseRequest: Codable {
    let deviceId: String
    let jwsRepresentation: String    // NEW: The signed JWS from StoreKit 2
    let transactionId: String        // NEW: Transaction ID
    let originalTransactionId: String // NEW: Original transaction ID
    let productId: String
}
```

**Status**: [x] Complete

---

### Task 3: Backend - Add JWS Verification

**File**: `src/index.ts`

**New function to add** (~60 lines):
```typescript
interface JWSPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  type: string;
  inAppOwnershipType: string;
  signedDate: number;
  environment: 'Sandbox' | 'Production' | 'Xcode';
}

/**
 * Fetch Apple's public keys for JWS verification
 */
async function getApplePublicKeys(): Promise<JsonWebKeySet> {
  const response = await fetch('https://appleid.apple.com/auth/keys');
  return response.json();
}

/**
 * Verify StoreKit 2 JWS and extract payload
 */
async function verifyStoreKit2JWS(
  jwsRepresentation: string
): Promise<{ valid: boolean; payload?: JWSPayload; error?: string }> {
  try {
    // 1. Decode JWS header to get key ID (kid)
    const [headerB64, payloadB64, signatureB64] = jwsRepresentation.split('.');
    const header = JSON.parse(atob(headerB64));
    const kid = header.kid;

    // 2. Fetch Apple's public keys
    const jwks = await getApplePublicKeys();
    const key = jwks.keys.find(k => k.kid === kid);

    if (!key) {
      return { valid: false, error: 'Public key not found' };
    }

    // 3. Verify signature using Web Crypto API
    const cryptoKey = await crypto.subtle.importKey(
      'jwk',
      key,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify']
    );

    const data = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
    const signature = Uint8Array.from(atob(signatureB64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));

    const isValid = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      cryptoKey,
      signature,
      data
    );

    if (!isValid) {
      return { valid: false, error: 'Invalid signature' };
    }

    // 4. Decode and return payload
    const payload = JSON.parse(atob(payloadB64)) as JWSPayload;
    return { valid: true, payload };

  } catch (error) {
    return { valid: false, error: error instanceof Error ? error.message : 'Unknown error' };
  }
}
```

**Status**: [x] Complete - Implemented with full cryptographic verification using Web Crypto API

---

### Task 4: Backend - Update /credits/purchase Endpoint

**File**: `src/index.ts`

**Current endpoint**: `handleCreditsPurchase()` (lines ~1678-1771)

**Changes**:
1. Update Zod schema to accept new fields
2. Call `verifyStoreKit2JWS()` instead of `validateAppleReceipt()`
3. Extract transaction data from JWS payload
4. Keep duplicate transaction prevention logic

**New schema**:
```typescript
const CreditsPurchaseSchemaV2 = z.object({
  deviceId: z.string().min(1),
  jwsRepresentation: z.string().min(1),
  transactionId: z.string().min(1),
  originalTransactionId: z.string().min(1),
  productId: z.string().min(1),
});
```

**Status**: [x] Complete - Backward compatible with legacy receipt format

---

### Task 5: Testing

**Test scenarios**:
1. [ ] Simulator purchase (should now work)
2. [ ] Sandbox purchase on real device
3. [ ] Duplicate transaction prevention
4. [ ] Invalid JWS rejection
5. [ ] Credit balance updates correctly

**Status**: [ ] Not Started

---

## File Change Summary

| File | Action | Lines Changed |
|------|--------|---------------|
| `iOS/.../StoreManager.swift` | Modify | ~20 lines |
| `iOS/.../APIClient.swift` | Modify | ~15 lines |
| `src/index.ts` | Add + Modify | ~100 lines |

---

## Apple JWS Structure Reference

The JWS from `transaction.jwsRepresentation` is a standard JWT:

```
header.payload.signature
```

**Header** (base64):
```json
{
  "alg": "ES256",
  "kid": "key-id-from-apple",
  "x5c": ["certificate-chain"]
}
```

**Payload** (base64):
```json
{
  "transactionId": "1000000123456789",
  "originalTransactionId": "1000000123456789",
  "bundleId": "com.reefbuddy.app",
  "productId": "com.reefbuddy.credits5",
  "purchaseDate": 1705600000000,
  "type": "Consumable",
  "inAppOwnershipType": "PURCHASED",
  "signedDate": 1705600000000,
  "environment": "Sandbox"
}
```

**Verification**:
- Fetch Apple's public keys from `https://appleid.apple.com/auth/keys`
- Find key matching `kid` from header
- Verify ES256 signature using the public key

---

## Rollback Plan

If issues occur:
1. Revert to `prerelease` tag: `git checkout prerelease`
2. Or restore individual files from git

---

## References

- [Apple: Validating receipts on the device](https://developer.apple.com/documentation/storekit/in-app_purchase/original_api_for_in-app_purchase/validating_receipts_on_the_device)
- [Apple: JWS Transaction structure](https://developer.apple.com/documentation/appstoreserverapi/jwstransaction)
- [Apple: App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)

---

*Last Updated: 2026-01-18*
*Status: Implementation Complete - Ready for Testing*
