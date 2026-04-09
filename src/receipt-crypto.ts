/**
 * Optional encryption for legacy receipt payloads at rest (tests + future use).
 * Uses AES-GCM with a 256-bit key derived from RECEIPT_ENCRYPTION_KEY via SHA-256.
 */

function bytesToB64(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export interface ReceiptCryptoEnv {
  RECEIPT_ENCRYPTION_KEY?: string;
}

export async function encryptReceiptData(receipt: string, env: ReceiptCryptoEnv): Promise<string> {
  if (!env.RECEIPT_ENCRYPTION_KEY) {
    throw new Error('Receipt encryption key not configured');
  }

  const rawKey = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(env.RECEIPT_ENCRYPTION_KEY)
  );
  const key = await crypto.subtle.importKey('raw', rawKey, { name: 'AES-GCM' }, false, ['encrypt']);

  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ciphertext = new Uint8Array(
    await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, new TextEncoder().encode(receipt))
  );

  return `v1:${bytesToB64(iv)}:${bytesToB64(ciphertext)}`;
}

export async function decryptReceiptData(payload: string, env: ReceiptCryptoEnv): Promise<string> {
  if (!env.RECEIPT_ENCRYPTION_KEY) {
    throw new Error('Receipt encryption key not configured');
  }

  const parts = payload.split(':');
  if (parts.length !== 3 || parts[0] !== 'v1') {
    throw new Error('Invalid encrypted payload format');
  }

  const rawKey = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(env.RECEIPT_ENCRYPTION_KEY)
  );
  const key = await crypto.subtle.importKey('raw', rawKey, { name: 'AES-GCM' }, false, ['decrypt']);

  const iv = b64ToBytes(parts[1]);
  const ciphertext = b64ToBytes(parts[2]);

  const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ciphertext);
  return new TextDecoder().decode(plain);
}
