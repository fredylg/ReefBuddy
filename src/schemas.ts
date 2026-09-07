import { z } from 'zod';
import { DEVICE_ID_PATTERN } from './env';

// =============================================================================
// ZOD SCHEMAS FOR REQUEST VALIDATION
// =============================================================================

/**
 * Schema for water parameter readings submission
 * All values are in standard aquarium measurement units.
 * When a parameter is present, ranges match typical reef test kit / API expectations.
 */
/** UUIDs arrive in any case (iOS sends uppercase); the database stores lowercase, so normalise at the boundary (P3-29). */
export const LowercaseUuid = z.uuid().transform((v) => v.toLowerCase());

export const WaterParametersSchema = z
  .object({
    salinity: z.number().nullish().describe('Salinity value (SG or PPT per salinity_unit)'),
    salinity_unit: z
      .enum(['SG', 'PPT'])
      .nullish()
      .describe('Salinity unit: SG (specific gravity) or PPT (parts per thousand)'),
    temperature: z.number().nullish().describe('Temperature in Fahrenheit'),
    ph: z.number().nullish().describe('pH level'),
    alkalinity: z.number().nullish().describe('Alkalinity in dKH'),
    calcium: z.number().nullish().describe('Calcium in ppm'),
    magnesium: z.number().nullish().describe('Magnesium in ppm'),
    nitrate: z.number().nullish().describe('Nitrate in ppm'),
    phosphate: z.number().nullish().describe('Phosphate in ppm'),
    ammonia: z.number().nullish().describe('Ammonia in ppm'),
    nitrite: z.number().nullish().describe('Nitrite in ppm'),
    notes: z.string().max(500).nullish().describe('User observations about the tank'),
  })
  .refine(
    (data) => {
      if (data.salinity == null || data.salinity === undefined) return true;
      const unit = data.salinity_unit ?? 'SG';
      // Physically plausible bounds only; whether a value is *healthy* is the analysis's job (B-26).
      if (unit === 'PPT') return data.salinity >= 0 && data.salinity <= 50;
      return data.salinity >= 1.0 && data.salinity <= 1.04;
    },
    { message: 'Salinity out of range: SG must be between 1.000 and 1.040, PPT between 0 and 50', path: ['salinity'] }
  )
  .superRefine((data, ctx) => {
    const add = (path: (string | number)[], message: string) => ctx.addIssue({ code: 'custom', message, path });

    // Plausibility bounds (test-kit ranges), not ideal-reef ranges: a crashing tank must still be analysable (B-26).
    const bounds: Array<[keyof typeof data, number, number, string]> = [
      ['ph', 6.0, 9.5, 'pH must be between 6.0 and 9.5'],
      ['temperature', 60, 95, 'Temperature must be between 60 and 95 °F'],
      ['alkalinity', 0, 20, 'Alkalinity must be between 0 and 20 dKH'],
      ['calcium', 200, 600, 'Calcium must be between 200 and 600 ppm'],
      ['magnesium', 800, 1800, 'Magnesium must be between 800 and 1800 ppm'],
      ['nitrate', 0, 200, 'Nitrate must be between 0 and 200 ppm'],
      ['phosphate', 0, 5, 'Phosphate must be between 0 and 5 ppm'],
      ['ammonia', 0, 10, 'Ammonia must be between 0 and 10 ppm'],
      ['nitrite', 0, 10, 'Nitrite must be between 0 and 10 ppm'],
    ];
    for (const [key, min, max, message] of bounds) {
      const value = data[key];
      if (typeof value === 'number' && (value < min || value > max)) add([key as string], message);
    }
  });

/**
 * Schema for user signup request
 */
export const SignupRequestSchema = z.object({
  email: z.email().max(255),
  password: z.string().min(8).max(128),
});

/**
 * Schema for user login request
 */
export const LoginRequestSchema = z.object({
  email: z.email(),
  password: z.string().max(128),
});

/**
 * Schema for creating a measurement
 * Uses z.coerce.number() to handle both string and number inputs
 * This fixes issues where iOS might send numeric strings due to decimal formatting
 */
export const CreateMeasurementSchema = z
  .object({
    tank_id: LowercaseUuid,
    ph: z.coerce.number().optional(),
    alkalinity: z.coerce.number().optional(),
    calcium: z.coerce.number().optional(),
    magnesium: z.coerce.number().optional(),
    nitrate: z.coerce.number().optional(),
    phosphate: z.coerce.number().optional(),
    salinity: z.coerce.number().optional(),
    salinity_unit: z.enum(['SG', 'PPT']).optional(),
    temperature: z.coerce.number().optional(),
    ammonia: z.coerce.number().optional(),
    nitrite: z.coerce.number().optional(),
    measured_at: z.iso.datetime().optional(),
    notes: z.string().optional(),
  })
  .refine(
    (data) => {
      if (data.salinity == null || data.salinity === undefined) return true;
      const unit = data.salinity_unit ?? 'SG';
      if (unit === 'PPT') return data.salinity > 30 && data.salinity < 40;
      return data.salinity > 0.5 && data.salinity < 2;
    },
    { message: 'Salinity out of range: SG must be between 0.5 and 2, PPT between 30 and 40', path: ['salinity'] }
  );

/**
 * Schema for creating a tank (iOS sends snake_case)
 */
export const TankCreateSchema = z.object({
  name: z.string().min(1).max(255).describe('Tank name'),
  volume_gallons: z.number().positive().describe('Tank volume in gallons'),
  tank_type: z.string().max(50).optional().describe('Type of tank (reef, fish-only, etc.)'),
});

/**
 * Schema for updating a tank (iOS sends snake_case)
 */
export const TankUpdateSchema = z.object({
  name: z.string().min(1).max(255).optional().describe('Tank name'),
  volume_gallons: z.number().positive().optional().describe('Tank volume in gallons'),
  tank_type: z.string().max(50).optional().describe('Type of tank'),
});

/**
 * Maintenance schedules (configuration storage only; local notifications are on-device)
 */
export const MaintenanceScheduleTypeEnum = z.enum(['water_change', 'filter', 'testing']);
export const MaintenanceScheduleKindEnum = z.enum(['interval_days', 'weekly']);

export const TimeLocalSchema = z
  .string()
  .regex(/^\d{2}:\d{2}$/, { message: 'timeLocal must be in HH:MM format' })
  .refine(
    (v) => {
      const [hh, mm] = v.split(':').map((n) => Number(n));
      return Number.isInteger(hh) && Number.isInteger(mm) && hh >= 0 && hh <= 23 && mm >= 0 && mm <= 59;
    },
    { message: 'timeLocal must be a valid time' }
  );

export const MaintenanceScheduleCreateSchema = z
  .object({
    tankId: LowercaseUuid,
    type: MaintenanceScheduleTypeEnum,
    enabled: z.boolean().optional().default(true),
    scheduleKind: MaintenanceScheduleKindEnum,
    intervalDays: z.number().int().min(1).optional(),
    weekdays: z.array(z.number().int().min(1).max(7)).min(1).optional(),
    timeLocal: TimeLocalSchema,
    timezone: z.string().min(1),
    notes: z.string().max(10000).optional(),
  })
  .superRefine((data, ctx) => {
    if (data.scheduleKind === 'interval_days') {
      if (data.intervalDays == null) {
        ctx.addIssue({
          code: 'custom',
          message: 'intervalDays is required when scheduleKind=interval_days',
          path: ['intervalDays'],
        });
      }
      if (data.weekdays != null) {
        ctx.addIssue({
          code: 'custom',
          message: 'weekdays is not allowed when scheduleKind=interval_days',
          path: ['weekdays'],
        });
      }
      return;
    }

    // weekly
    if (data.weekdays == null || data.weekdays.length === 0) {
      ctx.addIssue({
        code: 'custom',
        message: 'weekdays is required when scheduleKind=weekly',
        path: ['weekdays'],
      });
    }
    if (data.intervalDays != null) {
      ctx.addIssue({
        code: 'custom',
        message: 'intervalDays is not allowed when scheduleKind=weekly',
        path: ['intervalDays'],
      });
    }
  });

export const MaintenanceScheduleUpdateSchema = z
  .object({
    tankId: LowercaseUuid.optional(),
    type: MaintenanceScheduleTypeEnum.optional(),
    enabled: z.boolean().optional(),
    scheduleKind: MaintenanceScheduleKindEnum.optional(),
    intervalDays: z.number().int().min(1).optional(),
    weekdays: z.array(z.number().int().min(1).max(7)).min(1).optional(),
    timeLocal: TimeLocalSchema.optional(),
    timezone: z.string().min(1).optional(),
    notes: z.string().max(10000).optional(),
  })
  .superRefine((data, ctx) => {
    // Only enforce conditional constraints if scheduleKind is being set in this update,
    // or if the update tries to set intervalDays/weekdays (must be consistent).
    const kind = data.scheduleKind;

    if (kind === 'interval_days') {
      if (data.weekdays != null) {
        ctx.addIssue({
          code: 'custom',
          message: 'weekdays is not allowed when scheduleKind=interval_days',
          path: ['weekdays'],
        });
      }
      return;
    }

    if (kind === 'weekly') {
      if (data.intervalDays != null) {
        ctx.addIssue({
          code: 'custom',
          message: 'intervalDays is not allowed when scheduleKind=weekly',
          path: ['intervalDays'],
        });
      }
      return;
    }

    if (data.intervalDays != null && data.weekdays != null) {
      ctx.addIssue({
        code: 'custom',
        message: 'Provide only one of intervalDays or weekdays',
        path: ['intervalDays'],
      });
    }
  });

export const WaterChangeCreateSchema = z
  .object({
    performedAt: z.iso.datetime().optional(),
    percentReplaced: z.coerce.number().positive().max(100).optional(),
    gallonsReplaced: z.coerce.number().positive().optional(),
    notes: z.string().max(10000).optional(),
    sourceScheduleId: LowercaseUuid.optional(),
  })
  .superRefine((data, ctx) => {
    if (data.percentReplaced == null && data.gallonsReplaced == null) {
      ctx.addIssue({
        code: 'custom',
        message: 'percentReplaced or gallonsReplaced is required',
        path: ['percentReplaced'],
      });
    }
  });

export const WaterChangeListQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

/**
 * Schema for credit purchase request (StoreKit 2 JWS)
 */
export const CreditPurchaseJWSSchema = z.object({
  deviceId: z.string().regex(DEVICE_ID_PATTERN, 'Invalid device identifier').describe('iOS device identifier'),
  jwsRepresentation: z.string().min(1).describe('JWS-signed transaction from StoreKit 2'),
  transactionId: z
    .string()
    .optional()
    .describe('Client-reported transaction ID (informational; the signed payload is authoritative)'),
  originalTransactionId: z.string().optional().describe('Client-reported original transaction ID (informational)'),
  productId: z.string().min(1).describe('Product ID purchased'),
});

/**
 * Schema for historical data query parameters
 */
export const HistoryQuerySchema = z.object({
  start: z.iso.datetime().describe('Start date in ISO 8601 format'),
  end: z.iso.datetime().describe('End date in ISO 8601 format'),
});

/**
 * Schema for trends query parameters
 */
export const TrendsQuerySchema = z.object({
  days: z.coerce.number().min(1).max(365).default(30).describe('Number of days to analyze'),
});

/**
 * Schema for averages query parameters
 */
export const AveragesQuerySchema = z.object({
  period: z.enum(['daily', 'weekly']).describe('Aggregation period'),
  count: z.coerce.number().min(1).max(365).default(30).describe('Number of periods to retrieve'),
});

/**
 * Schema for CSV export query parameters
 */
export const ExportQuerySchema = z.object({
  start: z.iso.datetime().describe('Start date in ISO 8601 format'),
  end: z.iso.datetime().describe('End date in ISO 8601 format'),
});

// =============================================================================
// LIVESTOCK SCHEMAS
// =============================================================================

/**
 * Valid livestock categories from existing schema
 */
export const LivestockCategoryEnum = z.enum(['SPS', 'LPS', 'Soft', 'Fish', 'Invertebrate', 'Anemone', 'Other']);

/**
 * Valid health status values
 */
export const HealthStatusEnum = z.enum([
  'thriving',
  'healthy',
  'stressed',
  'declining',
  'critical',
  'sick',
  'deceased',
  'quarantine',
]);

/**
 * Valid log types for livestock health tracking
 */
export const LogTypeEnum = z.enum(['feeding', 'observation', 'treatment', 'death']);

/**
 * Schema for creating new livestock
 */
export const LivestockCreateSchema = z.object({
  name: z.string().min(1).max(255).describe('Display name for the livestock'),
  species: z.string().max(255).optional().describe('Scientific or common species name'),
  category: LivestockCategoryEnum.describe('Type of livestock: SPS, LPS, Soft, Fish, or Invertebrate'),
  quantity: z.number().int().min(1).default(1).describe('Number of individuals'),
  purchaseDate: z.iso.datetime().optional().describe('Date of purchase in ISO 8601 format'),
  purchasePrice: z.number().min(0).optional().describe('Purchase price'),
  healthStatus: HealthStatusEnum.optional().default('healthy').describe('Current health status'),
  notes: z.string().max(2000).optional().describe('Additional notes or observations'),
  imageUrl: z.url().max(2048).optional().describe('URL to livestock image'),
  id: LowercaseUuid.optional().describe(
    'Optional livestock ID (for retroactive compatibility with local-only livestock)'
  ),
});

/**
 * Schema for updating livestock details
 */
export const LivestockUpdateSchema = z.object({
  name: z.string().min(1).max(255).optional().describe('Display name for the livestock'),
  species: z.string().max(255).optional().describe('Scientific or common species name'),
  category: LivestockCategoryEnum.optional().describe('Type of livestock'),
  quantity: z.number().int().min(0).optional().describe('Number of individuals (0 for deceased)'),
  purchaseDate: z.iso.datetime().optional().describe('Date of purchase in ISO 8601 format'),
  purchasePrice: z.number().min(0).optional().describe('Purchase price'),
  healthStatus: HealthStatusEnum.optional().describe('Current health status'),
  notes: z.string().max(2000).optional().describe('Additional notes or observations'),
  imageUrl: z.url().max(2048).optional().describe('URL to livestock image'),
});

/**
 * Schema for creating livestock health log entries
 */
export const LivestockLogSchema = z.object({
  logType: LogTypeEnum.describe('Type of log entry: feeding, observation, treatment, or death'),
  description: z.string().max(2000).optional().describe('Details about the event'),
  loggedAt: z.iso.datetime().optional().describe('When the event occurred (defaults to now)'),
});

// Export schemas for external use
export type WaterParameters = z.infer<typeof WaterParametersSchema>;
export type SignupRequest = z.infer<typeof SignupRequestSchema>;
export type LoginRequest = z.infer<typeof LoginRequestSchema>;
export type CreateMeasurement = z.infer<typeof CreateMeasurementSchema>;
export type CreditPurchaseJWS = z.infer<typeof CreditPurchaseJWSSchema>;
export type LivestockCreate = z.infer<typeof LivestockCreateSchema>;
export type LivestockUpdate = z.infer<typeof LivestockUpdateSchema>;
export type LivestockLog = z.infer<typeof LivestockLogSchema>;
