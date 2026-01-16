/**
 * ReefBuddy D1 Database Integration Tests
 * @tester-agent - Quality Assurance Lead
 *
 * These tests validate database operations including:
 * - User creation with proper fields
 * - Tank management
 * - Measurement persistence
 * - Soft delete behavior
 * - Foreign key constraints
 *
 * Note: These tests use prepared statements instead of exec()
 * due to Miniflare compatibility requirements
 */

import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { env } from "cloudflare:test";

// =============================================================================
// TEST DATA
// =============================================================================

const testUser = {
  id: "user-test-001",
  email: "test@reefbuddy.app",
};

const testTank = {
  id: "tank-test-001",
  user_id: "user-test-001",
  name: "Test Reef Tank",
  volume_gallons: 75,
  salt_type: "Red Sea Coral Pro",
};

const testMeasurement = {
  id: "measurement-test-001",
  tank_id: "tank-test-001",
  ph: 8.2,
  alkalinity: 8.5,
  calcium: 420,
  magnesium: 1350,
  nitrate: 5,
  phosphate: 0.03,
  salinity: 1.025,
  temperature: 78,
};

// =============================================================================
// DATABASE SETUP / TEARDOWN
// =============================================================================

/**
 * Initialize test database schema using prepared statements
 * This runs individual CREATE TABLE statements
 */
async function initializeTestDb(): Promise<void> {
  // Drop existing tables if they exist (clean state)
  // Execute in correct order due to foreign keys
  try {
    await env.DB.prepare("DROP TABLE IF EXISTS livestock").run();
  } catch { /* ignore */ }
  try {
    await env.DB.prepare("DROP TABLE IF EXISTS measurements").run();
  } catch { /* ignore */ }
  try {
    await env.DB.prepare("DROP TABLE IF EXISTS tanks").run();
  } catch { /* ignore */ }
  try {
    await env.DB.prepare("DROP TABLE IF EXISTS users").run();
  } catch { /* ignore */ }

  // Create users table
  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
      deleted_at TEXT DEFAULT NULL
    )
  `).run();

  // Create tanks table
  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS tanks (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      volume_gallons REAL NOT NULL CHECK (volume_gallons > 0),
      salt_type TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `).run();

  // Create measurements table
  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS measurements (
      id TEXT PRIMARY KEY,
      tank_id TEXT NOT NULL,
      measured_at TEXT NOT NULL DEFAULT (datetime('now')),
      ph REAL CHECK (ph IS NULL OR (ph >= 0 AND ph <= 14)),
      alkalinity REAL CHECK (alkalinity IS NULL OR alkalinity >= 0),
      calcium REAL CHECK (calcium IS NULL OR calcium >= 0),
      magnesium REAL CHECK (magnesium IS NULL OR magnesium >= 0),
      nitrate REAL CHECK (nitrate IS NULL OR nitrate >= 0),
      phosphate REAL CHECK (phosphate IS NULL OR phosphate >= 0),
      salinity REAL CHECK (salinity IS NULL OR salinity >= 0),
      temperature REAL CHECK (temperature IS NULL OR temperature >= 0),
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (tank_id) REFERENCES tanks(id) ON DELETE CASCADE
    )
  `).run();

  // Create livestock table
  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS livestock (
      id TEXT PRIMARY KEY,
      tank_id TEXT NOT NULL,
      species TEXT NOT NULL,
      common_name TEXT,
      quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
      added_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (tank_id) REFERENCES tanks(id) ON DELETE CASCADE
    )
  `).run();

  // Enable foreign keys
  await env.DB.prepare("PRAGMA foreign_keys = ON").run();
}

/**
 * Clean up test data after each test
 */
async function cleanupTestDb(): Promise<void> {
  // Delete in correct order due to foreign key constraints
  // Use try-catch in case tables don't exist
  try { await env.DB.prepare("DELETE FROM livestock").run(); } catch { /* ignore */ }
  try { await env.DB.prepare("DELETE FROM measurements").run(); } catch { /* ignore */ }
  try { await env.DB.prepare("DELETE FROM tanks").run(); } catch { /* ignore */ }
  try { await env.DB.prepare("DELETE FROM users").run(); } catch { /* ignore */ }
}

// =============================================================================
// TEST SUITES
// =============================================================================

describe("D1 Database Integration", () => {
  beforeEach(async () => {
    await initializeTestDb();
  });

  afterEach(async () => {
    await cleanupTestDb();
  });

  describe("User Management", () => {
    it("should create a new user with default subscription tier", async () => {
      const result = await env.DB.prepare(
        "INSERT INTO users (id, email) VALUES (?, ?) RETURNING *"
      )
        .bind(testUser.id, testUser.email)
        .first();

      expect(result).toBeDefined();
      expect(result!.id).toBe(testUser.id);
      expect(result!.email).toBe(testUser.email);
      expect(result!.subscription_tier).toBe("free");
      expect(result!.created_at).toBeDefined();
    });

    it("should enforce unique email constraint", async () => {
      // Create first user
      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind(testUser.id, testUser.email)
        .run();

      // Try to create user with same email
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO users (id, email) VALUES (?, ?)"
        )
          .bind("user-test-002", testUser.email)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should allow premium subscription tier", async () => {
      const result = await env.DB.prepare(
        "INSERT INTO users (id, email, subscription_tier) VALUES (?, ?, ?) RETURNING *"
      )
        .bind(testUser.id, testUser.email, "premium")
        .first();

      expect(result!.subscription_tier).toBe("premium");
    });

    it("should reject invalid subscription tier", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO users (id, email, subscription_tier) VALUES (?, ?, ?)"
        )
          .bind(testUser.id, testUser.email, "invalid_tier")
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should support soft delete for users", async () => {
      // Create user
      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind(testUser.id, testUser.email)
        .run();

      // Soft delete user
      const now = new Date().toISOString();
      await env.DB.prepare("UPDATE users SET deleted_at = ? WHERE id = ?")
        .bind(now, testUser.id)
        .run();

      // Verify soft delete
      const result = await env.DB.prepare(
        "SELECT * FROM users WHERE id = ?"
      )
        .bind(testUser.id)
        .first();

      expect(result!.deleted_at).toBe(now);
    });

    it("should query only non-deleted users", async () => {
      // Create two users
      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind(testUser.id, testUser.email)
        .run();

      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind("user-test-002", "deleted@reefbuddy.app")
        .run();

      // Soft delete one user
      await env.DB.prepare(
        "UPDATE users SET deleted_at = datetime('now') WHERE id = ?"
      )
        .bind("user-test-002")
        .run();

      // Query active users only
      const activeUsers = await env.DB.prepare(
        "SELECT * FROM users WHERE deleted_at IS NULL"
      ).all();

      expect(activeUsers.results.length).toBe(1);
      expect(activeUsers.results[0].id).toBe(testUser.id);
    });
  });

  describe("Tank Management", () => {
    beforeEach(async () => {
      // Create test user for tank tests
      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind(testUser.id, testUser.email)
        .run();
    });

    it("should create a new tank associated with user", async () => {
      const result = await env.DB.prepare(
        "INSERT INTO tanks (id, user_id, name, volume_gallons, salt_type) VALUES (?, ?, ?, ?, ?) RETURNING *"
      )
        .bind(
          testTank.id,
          testTank.user_id,
          testTank.name,
          testTank.volume_gallons,
          testTank.salt_type
        )
        .first();

      expect(result).toBeDefined();
      expect(result!.id).toBe(testTank.id);
      expect(result!.user_id).toBe(testTank.user_id);
      expect(result!.name).toBe(testTank.name);
      expect(result!.volume_gallons).toBe(testTank.volume_gallons);
      expect(result!.salt_type).toBe(testTank.salt_type);
    });

    it("should enforce foreign key constraint on user_id", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
        )
          .bind(testTank.id, "non-existent-user", testTank.name, testTank.volume_gallons)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should enforce positive volume constraint", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
        )
          .bind(testTank.id, testTank.user_id, testTank.name, 0)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should cascade delete tanks when user is deleted", async () => {
      // Create tank
      await env.DB.prepare(
        "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
      )
        .bind(testTank.id, testTank.user_id, testTank.name, testTank.volume_gallons)
        .run();

      // Delete user (CASCADE)
      await env.DB.prepare("DELETE FROM users WHERE id = ?")
        .bind(testUser.id)
        .run();

      // Verify tank was deleted
      const tank = await env.DB.prepare("SELECT * FROM tanks WHERE id = ?")
        .bind(testTank.id)
        .first();

      expect(tank).toBeNull();
    });

    it("should fetch all tanks for a user", async () => {
      // Create multiple tanks
      await env.DB.prepare(
        "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
      )
        .bind("tank-1", testUser.id, "Tank One", 50)
        .run();

      await env.DB.prepare(
        "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
      )
        .bind("tank-2", testUser.id, "Tank Two", 100)
        .run();

      // Fetch all tanks
      const tanks = await env.DB.prepare(
        "SELECT * FROM tanks WHERE user_id = ?"
      )
        .bind(testUser.id)
        .all();

      expect(tanks.results.length).toBe(2);
    });
  });

  describe("Measurement Persistence", () => {
    beforeEach(async () => {
      // Create test user and tank for measurement tests
      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind(testUser.id, testUser.email)
        .run();

      await env.DB.prepare(
        "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
      )
        .bind(testTank.id, testTank.user_id, testTank.name, testTank.volume_gallons)
        .run();
    });

    it("should persist measurement with all parameters", async () => {
      const result = await env.DB.prepare(
        `INSERT INTO measurements
         (id, tank_id, ph, alkalinity, calcium, magnesium, nitrate, phosphate, salinity, temperature)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         RETURNING *`
      )
        .bind(
          testMeasurement.id,
          testMeasurement.tank_id,
          testMeasurement.ph,
          testMeasurement.alkalinity,
          testMeasurement.calcium,
          testMeasurement.magnesium,
          testMeasurement.nitrate,
          testMeasurement.phosphate,
          testMeasurement.salinity,
          testMeasurement.temperature
        )
        .first();

      expect(result).toBeDefined();
      expect(result!.id).toBe(testMeasurement.id);
      expect(result!.tank_id).toBe(testMeasurement.tank_id);
      expect(result!.ph).toBe(testMeasurement.ph);
      expect(result!.alkalinity).toBe(testMeasurement.alkalinity);
      expect(result!.calcium).toBe(testMeasurement.calcium);
      expect(result!.magnesium).toBe(testMeasurement.magnesium);
      expect(result!.nitrate).toBe(testMeasurement.nitrate);
      expect(result!.phosphate).toBe(testMeasurement.phosphate);
      expect(result!.salinity).toBe(testMeasurement.salinity);
      expect(result!.temperature).toBe(testMeasurement.temperature);
    });

    it("should persist measurement with partial parameters (nullable fields)", async () => {
      const result = await env.DB.prepare(
        `INSERT INTO measurements (id, tank_id, ph, alkalinity, calcium, magnesium)
         VALUES (?, ?, ?, ?, ?, ?)
         RETURNING *`
      )
        .bind(
          testMeasurement.id,
          testMeasurement.tank_id,
          testMeasurement.ph,
          testMeasurement.alkalinity,
          testMeasurement.calcium,
          testMeasurement.magnesium
        )
        .first();

      expect(result).toBeDefined();
      expect(result!.nitrate).toBeNull();
      expect(result!.phosphate).toBeNull();
      expect(result!.salinity).toBeNull();
      expect(result!.temperature).toBeNull();
    });

    it("should associate measurement with correct tank", async () => {
      // Create measurement
      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
      )
        .bind(testMeasurement.id, testMeasurement.tank_id, testMeasurement.ph)
        .run();

      // Fetch measurement with tank info using JOIN
      const result = await env.DB.prepare(
        `SELECT m.*, t.name as tank_name
         FROM measurements m
         JOIN tanks t ON m.tank_id = t.id
         WHERE m.id = ?`
      )
        .bind(testMeasurement.id)
        .first();

      expect(result!.tank_name).toBe(testTank.name);
    });

    it("should enforce foreign key constraint on tank_id", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
        )
          .bind(testMeasurement.id, "non-existent-tank", testMeasurement.ph)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should enforce pH range constraint (0-14)", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
        )
          .bind(testMeasurement.id, testMeasurement.tank_id, 15)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should enforce non-negative constraints on parameters", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO measurements (id, tank_id, alkalinity) VALUES (?, ?, ?)"
        )
          .bind(testMeasurement.id, testMeasurement.tank_id, -1)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should cascade delete measurements when tank is deleted", async () => {
      // Create measurement
      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
      )
        .bind(testMeasurement.id, testMeasurement.tank_id, testMeasurement.ph)
        .run();

      // Delete tank (CASCADE)
      await env.DB.prepare("DELETE FROM tanks WHERE id = ?")
        .bind(testTank.id)
        .run();

      // Verify measurement was deleted
      const measurement = await env.DB.prepare(
        "SELECT * FROM measurements WHERE id = ?"
      )
        .bind(testMeasurement.id)
        .first();

      expect(measurement).toBeNull();
    });

    it("should fetch measurements ordered by date descending", async () => {
      // Create multiple measurements with different timestamps
      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph, measured_at) VALUES (?, ?, ?, ?)"
      )
        .bind("m-1", testTank.id, 8.0, "2024-01-01T10:00:00Z")
        .run();

      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph, measured_at) VALUES (?, ?, ?, ?)"
      )
        .bind("m-2", testTank.id, 8.2, "2024-01-03T10:00:00Z")
        .run();

      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph, measured_at) VALUES (?, ?, ?, ?)"
      )
        .bind("m-3", testTank.id, 8.1, "2024-01-02T10:00:00Z")
        .run();

      // Fetch measurements ordered by date
      const measurements = await env.DB.prepare(
        "SELECT * FROM measurements WHERE tank_id = ? ORDER BY measured_at DESC"
      )
        .bind(testTank.id)
        .all();

      expect(measurements.results[0].id).toBe("m-2"); // Most recent
      expect(measurements.results[1].id).toBe("m-3");
      expect(measurements.results[2].id).toBe("m-1"); // Oldest
    });

    it("should support soft delete for measurements", async () => {
      // Create measurement
      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
      )
        .bind(testMeasurement.id, testMeasurement.tank_id, testMeasurement.ph)
        .run();

      // Soft delete measurement
      const now = new Date().toISOString();
      await env.DB.prepare(
        "UPDATE measurements SET deleted_at = ? WHERE id = ?"
      )
        .bind(now, testMeasurement.id)
        .run();

      // Verify soft delete
      const result = await env.DB.prepare(
        "SELECT * FROM measurements WHERE id = ?"
      )
        .bind(testMeasurement.id)
        .first();

      expect(result!.deleted_at).toBe(now);
    });

    it("should query only non-deleted measurements", async () => {
      // Create two measurements
      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
      )
        .bind("m-active", testTank.id, 8.2)
        .run();

      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, ph) VALUES (?, ?, ?)"
      )
        .bind("m-deleted", testTank.id, 8.0)
        .run();

      // Soft delete one measurement
      await env.DB.prepare(
        "UPDATE measurements SET deleted_at = datetime('now') WHERE id = ?"
      )
        .bind("m-deleted")
        .run();

      // Query active measurements only
      const activeMeasurements = await env.DB.prepare(
        "SELECT * FROM measurements WHERE tank_id = ? AND deleted_at IS NULL"
      )
        .bind(testTank.id)
        .all();

      expect(activeMeasurements.results.length).toBe(1);
      expect(activeMeasurements.results[0].id).toBe("m-active");
    });

    it("should handle high-precision floating point values", async () => {
      const precisePhosphate = 0.0312345;

      await env.DB.prepare(
        "INSERT INTO measurements (id, tank_id, phosphate) VALUES (?, ?, ?)"
      )
        .bind(testMeasurement.id, testMeasurement.tank_id, precisePhosphate)
        .run();

      const result = await env.DB.prepare(
        "SELECT phosphate FROM measurements WHERE id = ?"
      )
        .bind(testMeasurement.id)
        .first();

      expect(result!.phosphate).toBeCloseTo(precisePhosphate, 6);
    });
  });

  describe("Livestock Management", () => {
    beforeEach(async () => {
      // Create test user and tank for livestock tests
      await env.DB.prepare("INSERT INTO users (id, email) VALUES (?, ?)")
        .bind(testUser.id, testUser.email)
        .run();

      await env.DB.prepare(
        "INSERT INTO tanks (id, user_id, name, volume_gallons) VALUES (?, ?, ?, ?)"
      )
        .bind(testTank.id, testTank.user_id, testTank.name, testTank.volume_gallons)
        .run();
    });

    it("should create livestock entry with species information", async () => {
      const result = await env.DB.prepare(
        `INSERT INTO livestock (id, tank_id, species, common_name, quantity)
         VALUES (?, ?, ?, ?, ?)
         RETURNING *`
      )
        .bind(
          "livestock-1",
          testTank.id,
          "Amphiprion ocellaris",
          "Ocellaris Clownfish",
          2
        )
        .first();

      expect(result).toBeDefined();
      expect(result!.species).toBe("Amphiprion ocellaris");
      expect(result!.common_name).toBe("Ocellaris Clownfish");
      expect(result!.quantity).toBe(2);
    });

    it("should enforce positive quantity constraint", async () => {
      let errorThrown = false;
      try {
        await env.DB.prepare(
          "INSERT INTO livestock (id, tank_id, species, quantity) VALUES (?, ?, ?, ?)"
        )
          .bind("livestock-1", testTank.id, "Test Species", 0)
          .run();
      } catch {
        errorThrown = true;
      }

      expect(errorThrown).toBe(true);
    });

    it("should default quantity to 1", async () => {
      const result = await env.DB.prepare(
        "INSERT INTO livestock (id, tank_id, species) VALUES (?, ?, ?) RETURNING quantity"
      )
        .bind("livestock-1", testTank.id, "Test Species")
        .first();

      expect(result!.quantity).toBe(1);
    });

    it("should cascade delete livestock when tank is deleted", async () => {
      // Create livestock
      await env.DB.prepare(
        "INSERT INTO livestock (id, tank_id, species) VALUES (?, ?, ?)"
      )
        .bind("livestock-1", testTank.id, "Test Species")
        .run();

      // Delete tank (CASCADE)
      await env.DB.prepare("DELETE FROM tanks WHERE id = ?")
        .bind(testTank.id)
        .run();

      // Verify livestock was deleted
      const livestock = await env.DB.prepare(
        "SELECT * FROM livestock WHERE id = ?"
      )
        .bind("livestock-1")
        .first();

      expect(livestock).toBeNull();
    });
  });
});
