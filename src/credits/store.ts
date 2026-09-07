import { Env } from '../env';

// =============================================================================
// CREDITS SYSTEM
// =============================================================================

/**
 * Device credits record from database
 */
export interface DeviceCreditsRecord {
  device_id: string;
  free_used: number;
  paid_credits: number;
  total_analyses: number;
  created_at: string;
  updated_at: string;
}

/**
 * Credit products configuration
 */
export const CREDIT_PRODUCTS: Record<string, number> = {
  'com.reefbuddy.credits5': 5,
  'com.reefbuddy.credits50': 50,
};

/**
 * Get or create device credits record
 */
export async function getOrCreateDeviceCredits(
  env: Env,
  deviceId: string
): Promise<DeviceCreditsRecord> {
  try {
    let record = (await env.DB.prepare(
      'SELECT * FROM device_credits WHERE device_id = ?'
    )
      .bind(deviceId)
      .first()) as DeviceCreditsRecord | null;

    if (!record) {
      const now = new Date().toISOString();
      const insertResult = await env.DB.prepare(
        'INSERT INTO device_credits (device_id, free_used, paid_credits, total_analyses, created_at, updated_at) VALUES (?, 0, 0, 0, ?, ?)'
      )
        .bind(deviceId, now, now)
        .run();

      if (!insertResult.success) {
        throw new Error(`Failed to create device credits record: ${insertResult.error}`);
      }

      record = {
        device_id: deviceId,
        free_used: 0,
        paid_credits: 0,
        total_analyses: 0,
        created_at: now,
        updated_at: now,
      };
    }

    return record;
  } catch (error) {
    console.error('Error in getOrCreateDeviceCredits:', error);
    // Check if error is due to missing table
    if (error instanceof Error && error.message.includes('no such table')) {
      throw new Error('Database migration not applied. Please run: npx wrangler d1 migrations apply reef-db --remote');
    }
    throw error;
  }
}

/**
 * Check if device has available credits (free or paid)
 */
export async function checkDeviceCredits(
  env: Env,
  deviceId: string
): Promise<{ allowed: boolean; freeRemaining: number; paidCredits: number; totalAnalyses: number }> {
  const record = await getOrCreateDeviceCredits(env, deviceId);
  const freeLimit = parseInt(env.FREE_ANALYSIS_LIMIT || '3', 10);
  const freeRemaining = Math.max(0, freeLimit - record.free_used);

  const allowed = freeRemaining > 0 || record.paid_credits > 0;

  return {
    allowed,
    freeRemaining,
    paidCredits: record.paid_credits,
    totalAnalyses: record.total_analyses,
  };
}

/** Which pool a consumed credit came from; needed to refund it to the same pool. */
export type CreditKind = 'free' | 'paid';

/**
 * Consume one credit from device (free first, then paid).
 * Each UPDATE is conditional on the balance, so two concurrent requests can never
 * take the same credit or drive a balance negative (the second UPDATE affects 0 rows).
 * Returns which pool was charged, or null when the device has no credits.
 */
export async function consumeDeviceCredit(
  env: Env,
  deviceId: string,
  options: { allowFree?: boolean } = {}
): Promise<CreditKind | null> {
  try {
    await getOrCreateDeviceCredits(env, deviceId);
    const freeLimit = parseInt(env.FREE_ANALYSIS_LIMIT || '3', 10);
    const now = new Date().toISOString();

    if (options.allowFree !== false) {
      const freeResult = await env.DB.prepare(
        'UPDATE device_credits SET free_used = free_used + 1, total_analyses = total_analyses + 1, updated_at = ? WHERE device_id = ? AND free_used < ?'
      )
        .bind(now, deviceId, freeLimit)
        .run();
      if (freeResult.meta.changes > 0) return 'free';
    }

    const paidResult = await env.DB.prepare(
      'UPDATE device_credits SET paid_credits = paid_credits - 1, total_analyses = total_analyses + 1, updated_at = ? WHERE device_id = ? AND paid_credits > 0'
    )
      .bind(now, deviceId)
      .run();
    if (paidResult.meta.changes > 0) return 'paid';

    return null;
  } catch (error) {
    console.error('Error in consumeDeviceCredit:', error);
    throw error;
  }
}

/**
 * Refund one credit to the pool it was consumed from.
 * Used whenever the AI call fails after the credit was taken.
 * Note: SQLite has no GREATEST(); scalar MAX() is the equivalent.
 */
export async function refundDeviceCredit(env: Env, deviceId: string, kind: CreditKind): Promise<boolean> {
  try {
    const now = new Date().toISOString();
    const sql =
      kind === 'free'
        ? 'UPDATE device_credits SET free_used = free_used - 1, total_analyses = MAX(0, total_analyses - 1), updated_at = ? WHERE device_id = ? AND free_used > 0'
        : 'UPDATE device_credits SET paid_credits = paid_credits + 1, total_analyses = MAX(0, total_analyses - 1), updated_at = ? WHERE device_id = ?';
    const result = await env.DB.prepare(sql).bind(now, deviceId).run();
    return result.success && result.meta.changes > 0;
  } catch (error) {
    console.error('Error in refundDeviceCredit:', error);
    return false;
  }
}

export type AddCreditsResult = 'added' | 'duplicate' | 'error';

/**
 * Add purchased credits to a device.
 * The purchase_history row is inserted first and carries UNIQUE(apple_transaction_id), so it is
 * the duplicate guard; the balance UPDATE runs in the same D1 batch (atomic), so credits can never
 * be granted without an audit row and a replayed transaction never grants twice.
 */
export async function addDeviceCredits(
  env: Env,
  deviceId: string,
  credits: number,
  productId: string,
  transactionId: string,
  receiptData: string
): Promise<AddCreditsResult> {
  const now = new Date().toISOString();
  const purchaseId = crypto.randomUUID();

  await getOrCreateDeviceCredits(env, deviceId);

  try {
    await env.DB.batch([
      env.DB.prepare(
        'INSERT INTO purchase_history (id, device_id, product_id, credits_added, apple_transaction_id, receipt_data, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).bind(purchaseId, deviceId, productId, credits, transactionId, receiptData, now),
      env.DB.prepare(
        'UPDATE device_credits SET paid_credits = paid_credits + ?, updated_at = ? WHERE device_id = ?'
      ).bind(credits, now, deviceId),
    ]);
    return 'added';
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (/UNIQUE constraint failed/i.test(message)) {
      console.warn('Duplicate transaction rejected: ' + transactionId);
      return 'duplicate';
    }
    console.error('addDeviceCredits failed:', message);
    return 'error';
  }
}
