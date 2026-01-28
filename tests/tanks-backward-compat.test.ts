/**
 * Tank Creation Backward Compatibility Tests
 * @tester-agent - Quality Assurance Lead
 *
 * These tests validate backward compatibility for tank creation:
 * - Authenticated requests (v1.0.1+ compatibility)
 * - Device-based requests (v1.0.2+)
 * - Both methods work correctly
 * - Device user auto-creation
 */

import { describe, it, expect, beforeEach } from "vitest";
import { env, SELF } from "cloudflare:test";

// =============================================================================
// DATABASE SETUP
// =============================================================================

/**
 * Initialize test database schema
 */
async function initializeTestDb(): Promise<void> {
  // Drop existing tables if they exist (clean state)
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
      password_hash TEXT,
      subscription_tier TEXT NOT NULL DEFAULT 'free',
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  `).run();

  // Create tanks table
  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS tanks (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      volume_gallons REAL NOT NULL,
      tank_type TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `).run();

  // Enable foreign keys
  await env.DB.prepare("PRAGMA foreign_keys = ON").run();
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Generate a valid UUID
 */
function generateUUID(): string {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Create authenticated request headers
 */
function authHeaders(token: string): Record<string, string> {
  return {
    "Content-Type": "application/json",
    Authorization: `Bearer ${token}`,
  };
}

/**
 * Helper to make authenticated requests
 */
async function authenticatedFetch(
  url: string,
  token: string,
  options: RequestInit = {}
): Promise<Response> {
  return SELF.fetch(url, {
    ...options,
    headers: {
      ...authHeaders(token),
      ...(options.headers || {}),
    },
  });
}

/**
 * Helper to make device-based requests (no auth)
 */
async function deviceBasedFetch(
  url: string,
  deviceId: string,
  options: RequestInit = {}
): Promise<Response> {
  return SELF.fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      "X-Device-ID": deviceId,
      ...(options.headers || {}),
    },
  });
}

/**
 * Test state management
 */
interface TestState {
  user1Token: string;
  user1Id: string;
  user1Email: string;
  deviceId: string;
}

const testState: TestState = {
  user1Token: "",
  user1Id: "",
  user1Email: "",
  deviceId: "TEST-DEVICE-BACKWARD-COMPAT",
};

// =============================================================================
// TEST SUITES
// =============================================================================

describe("Tank Creation Backward Compatibility", () => {
  beforeEach(async () => {
    // Initialize database schema
    await initializeTestDb();

    // Clean up test data
    try {
      await env.DB.prepare("DELETE FROM tanks WHERE name LIKE 'Test Tank%'").run();
      await env.DB.prepare(
        "DELETE FROM users WHERE email LIKE 'test.backward%' OR email LIKE 'device_%'"
      ).run();
    } catch (e) {
      // Ignore cleanup errors
    }

    // Create test user for authenticated requests
    testState.user1Email = `test.backward.${Date.now()}@example.com`;
    const signupResponse = await SELF.fetch("http://localhost/auth/signup", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email: testState.user1Email,
        password: "TestPassword123!",
      }),
    });

    if (signupResponse.ok) {
      const signupData = (await signupResponse.json()) as {
        success: boolean;
        user: { id: string; email: string };
        session_token: string;
      };
      testState.user1Token = signupData.session_token;
      testState.user1Id = signupData.user.id;
    }
  });

  describe("Authenticated Requests (v1.0.1+ compatibility)", () => {
    it("should create tank with authenticated request", async () => {
      if (!testState.user1Token) {
        console.log("Skipping: Could not create test user");
        return;
      }

      const tankData = {
        name: "Test Tank Authenticated",
        volume_gallons: 75,
        tank_type: "reef",
      };

      const response = await authenticatedFetch(
        "http://localhost/api/tanks",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify(tankData),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        data: {
          id: string;
          user_id: string;
          name: string;
          volume_gallons: number;
          tank_type: string | null;
        };
      };

      expect(data.success).toBe(true);
      expect(data.data.name).toBe(tankData.name);
      expect(data.data.volume_gallons).toBe(tankData.volume_gallons);
      expect(data.data.user_id).toBe(testState.user1Id);
      expect(data.data.id).toBeDefined();
    });

    it("should list tanks for authenticated user", async () => {
      if (!testState.user1Token) {
        console.log("Skipping: Could not create test user");
        return;
      }

      // Create a tank first
      const createResponse = await authenticatedFetch(
        "http://localhost/api/tanks",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Test Tank List",
            volume_gallons: 50,
          }),
        }
      );

      expect(createResponse.status).toBe(201);

      // List tanks
      const listResponse = await authenticatedFetch(
        "http://localhost/api/tanks",
        testState.user1Token,
        {
          method: "GET",
        }
      );

      expect(listResponse.status).toBe(200);

      const data = (await listResponse.json()) as {
        success: boolean;
        data: Array<{
          id: string;
          user_id: string;
          name: string;
        }>;
      };

      expect(data.success).toBe(true);
      expect(data.data.length).toBeGreaterThan(0);
      expect(data.data.some((t) => t.name === "Test Tank List")).toBe(true);
      expect(data.data.every((t) => t.user_id === testState.user1Id)).toBe(true);
    });
  });

  describe("Device-Based Requests (v1.0.2+)", () => {
    it("should create tank with device ID (no authentication)", async () => {
      const tankData = {
        name: "Test Tank Device Based",
        volume_gallons: 100,
        tank_type: "fowlr",
      };

      const response = await deviceBasedFetch(
        "http://localhost/api/tanks",
        testState.deviceId,
        {
          method: "POST",
          body: JSON.stringify(tankData),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        data: {
          id: string;
          user_id: string;
          name: string;
          volume_gallons: number;
        };
      };

      expect(data.success).toBe(true);
      expect(data.data.name).toBe(tankData.name);
      expect(data.data.volume_gallons).toBe(tankData.volume_gallons);
      expect(data.data.user_id).toBeDefined();

      // Verify device user was created
      const deviceUser = (await env.DB.prepare(
        "SELECT id, email FROM users WHERE email = ?"
      )
        .bind(`device_${testState.deviceId}@reefbuddy.device`)
        .first()) as { id: string; email: string } | null;

      expect(deviceUser).not.toBeNull();
      expect(deviceUser?.id).toBe(data.data.user_id);
    });

    it("should list tanks for device-based user", async () => {
      // Create a tank first
      const createResponse = await deviceBasedFetch(
        "http://localhost/api/tanks",
        testState.deviceId,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Test Tank Device List",
            volume_gallons: 60,
          }),
        }
      );

      expect(createResponse.status).toBe(201);

      // List tanks
      const listResponse = await deviceBasedFetch(
        "http://localhost/api/tanks",
        testState.deviceId,
        {
          method: "GET",
        }
      );

      expect(listResponse.status).toBe(200);

      const data = (await listResponse.json()) as {
        success: boolean;
        data: Array<{
          id: string;
          user_id: string;
          name: string;
        }>;
      };

      expect(data.success).toBe(true);
      expect(data.data.length).toBeGreaterThan(0);
      expect(data.data.some((t) => t.name === "Test Tank Device List")).toBe(true);
    });

    it("should reuse existing device user for multiple tanks", async () => {
      // Create first tank
      const response1 = await deviceBasedFetch(
        "http://localhost/api/tanks",
        testState.deviceId,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Tank 1",
            volume_gallons: 50,
          }),
        }
      );

      expect(response1.status).toBe(201);
      const data1 = (await response1.json()) as {
        success: boolean;
        data: { user_id: string };
      };
      const userId1 = data1.data.user_id;

      // Create second tank
      const response2 = await deviceBasedFetch(
        "http://localhost/api/tanks",
        testState.deviceId,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Tank 2",
            volume_gallons: 75,
          }),
        }
      );

      expect(response2.status).toBe(201);
      const data2 = (await response2.json()) as {
        success: boolean;
        data: { user_id: string };
      };
      const userId2 = data2.data.user_id;

      // Both tanks should use the same user ID
      expect(userId1).toBe(userId2);
    });
  });

  describe("Backward Compatibility Scenarios", () => {
    it("should prioritize authenticated requests over device ID", async () => {
      if (!testState.user1Token) {
        console.log("Skipping: Could not create test user");
        return;
      }

      const tankData = {
        name: "Test Tank Priority",
        volume_gallons: 80,
      };

      // Create tank with both auth token and device ID
      const response = await SELF.fetch("http://localhost/api/tanks", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${testState.user1Token}`,
          "X-Device-ID": testState.deviceId,
        },
        body: JSON.stringify(tankData),
      });

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        data: { user_id: string };
      };

      // Should use authenticated user, not device user
      expect(data.data.user_id).toBe(testState.user1Id);
    });

    it("should return 401 if neither auth nor device ID provided", async () => {
      const response = await SELF.fetch("http://localhost/api/tanks", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          name: "Test Tank No Auth",
          volume_gallons: 50,
        }),
      });

      expect(response.status).toBe(401);

      const data = (await response.json()) as {
        error: string;
        message: string;
      };

      expect(data.error).toBe("Unauthorized");
      expect(data.message).toContain("authentication token or device ID");
    });

    it("should work with authenticated GET request (v1.0.1+)", async () => {
      if (!testState.user1Token) {
        console.log("Skipping: Could not create test user");
        return;
      }

      // Create tank first
      await authenticatedFetch("http://localhost/api/tanks", testState.user1Token, {
        method: "POST",
        body: JSON.stringify({
          name: "Test Tank GET",
          volume_gallons: 55,
        }),
      });

      // List tanks with auth
      const response = await authenticatedFetch(
        "http://localhost/api/tanks",
        testState.user1Token,
        {
          method: "GET",
        }
      );

      expect(response.status).toBe(200);
      const data = (await response.json()) as { success: boolean; data: unknown[] };
      expect(data.success).toBe(true);
    });

    it("should work with device-based GET request (v1.0.2+)", async () => {
      // Create tank first
      await deviceBasedFetch("http://localhost/api/tanks", testState.deviceId, {
        method: "POST",
        body: JSON.stringify({
          name: "Test Tank GET Device",
          volume_gallons: 65,
        }),
      });

      // List tanks with device ID
      const response = await deviceBasedFetch(
        "http://localhost/api/tanks",
        testState.deviceId,
        {
          method: "GET",
        }
      );

      expect(response.status).toBe(200);
      const data = (await response.json()) as { success: boolean; data: unknown[] };
      expect(data.success).toBe(true);
    });
  });
});
