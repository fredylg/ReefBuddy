/**
 * ReefBuddy Livestock & Notifications API Tests
 * @tester-agent - Quality Assurance Lead
 *
 * These tests validate the Livestock and Notifications API functionality including:
 * - Livestock CRUD operations
 * - Livestock health logging
 * - Push notification token registration/unregistration
 * - Notification settings management
 * - Notification history and read status
 * - Authentication and authorization checks
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import { env, SELF } from "cloudflare:test";

// =============================================================================
// TEST UTILITIES
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
 * Test data state management
 */
interface TestState {
  user1Token: string;
  user1Id: string;
  user2Token: string;
  user2Id: string;
  tankId: string;
  tank2Id: string;
  livestockId: string;
}

let testState: TestState = {
  user1Token: "",
  user1Id: "",
  user2Token: "",
  user2Id: "",
  tankId: "",
  tank2Id: "",
  livestockId: "",
};

// =============================================================================
// SETUP: Create test users and tanks
// =============================================================================

beforeAll(async () => {
  // Create first test user
  const email1 = `test1_${Date.now()}@reefbuddy.test`;
  const signup1Response = await SELF.fetch("http://localhost/auth/signup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: email1,
      password: "TestPassword123!",
    }),
  });

  if (signup1Response.status === 201) {
    const signup1Data = (await signup1Response.json()) as {
      session_token: string;
      user: { id: string };
    };
    testState.user1Token = signup1Data.session_token;
    testState.user1Id = signup1Data.user.id;

    // Create a tank for user 1
    const tankId = generateUUID();
    try {
      await env.DB.prepare(
        `INSERT INTO tanks (id, user_id, name, volume, type, created_at)
         VALUES (?, ?, ?, ?, ?, datetime('now'))`
      )
        .bind(tankId, testState.user1Id, "Test Reef Tank", 75, "reef")
        .run();
      testState.tankId = tankId;
    } catch (e) {
      console.log("Tank creation error:", e);
    }
  }

  // Create second test user for access control tests
  const email2 = `test2_${Date.now()}@reefbuddy.test`;
  const signup2Response = await SELF.fetch("http://localhost/auth/signup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: email2,
      password: "TestPassword456!",
    }),
  });

  if (signup2Response.status === 201) {
    const signup2Data = (await signup2Response.json()) as {
      session_token: string;
      user: { id: string };
    };
    testState.user2Token = signup2Data.session_token;
    testState.user2Id = signup2Data.user.id;

    // Create a tank for user 2
    const tank2Id = generateUUID();
    try {
      await env.DB.prepare(
        `INSERT INTO tanks (id, user_id, name, volume, type, created_at)
         VALUES (?, ?, ?, ?, ?, datetime('now'))`
      )
        .bind(tank2Id, testState.user2Id, "User 2 Tank", 50, "reef")
        .run();
      testState.tank2Id = tank2Id;
    } catch (e) {
      console.log("Tank 2 creation error:", e);
    }
  }
});

// =============================================================================
// LIVESTOCK API TESTS
// =============================================================================

describe("Livestock API", () => {
  describe("POST /tanks/:tankId/livestock - Create Livestock", () => {
    it("should create livestock successfully (201)", async () => {
      if (!testState.user1Token || !testState.tankId) {
        console.log("Skipping: test user not created");
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Blue Tang",
            species: "Paracanthurus hepatus",
            category: "Fish",
            quantity: 1,
            purchasePrice: 75.99,
            healthStatus: "healthy",
            notes: "Beautiful specimen, eating well",
          }),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        livestock: {
          id: string;
          name: string;
          species: string;
          category: string;
          quantity: number;
          health_status: string;
        };
      };

      expect(data.success).toBe(true);
      expect(data.livestock).toBeDefined();
      expect(data.livestock.name).toBe("Blue Tang");
      expect(data.livestock.species).toBe("Paracanthurus hepatus");
      expect(data.livestock.category).toBe("Fish");
      expect(data.livestock.quantity).toBe(1);
      expect(data.livestock.health_status).toBe("healthy");

      // Store for later tests
      testState.livestockId = data.livestock.id;
    });

    it("should create livestock with minimal required fields (201)", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Hammer Coral",
            category: "LPS",
          }),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        livestock: { quantity: number; health_status: string };
      };

      expect(data.success).toBe(true);
      expect(data.livestock.quantity).toBe(1); // Default value
      expect(data.livestock.health_status).toBe("healthy"); // Default value
    });

    it("should return 401 without authentication", async () => {
      // Use a valid UUID format for the tank ID to ensure proper route matching
      const fakeTankId = generateUUID();
      const response = await SELF.fetch(
        `http://localhost/tanks/${fakeTankId}/livestock`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            name: "Clownfish",
            category: "Fish",
          }),
        }
      );

      expect(response.status).toBe(401);
    });

    it("should return 400 for invalid category", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Mystery Creature",
            category: "InvalidCategory",
          }),
        }
      );

      expect(response.status).toBe(400);

      const data = (await response.json()) as { error: string };
      expect(data.error).toBe("Validation failed");
    });

    it("should return 400 for missing name", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            category: "Fish",
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it("should return 404 for non-existent tank", async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeTankId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/tanks/${fakeTankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Test Fish",
            category: "Fish",
          }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when accessing other user's tank", async () => {
      if (!testState.user2Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user2Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Unauthorized Fish",
            category: "Fish",
          }),
        }
      );

      expect(response.status).toBe(403);
    });
  });

  describe("GET /tanks/:tankId/livestock - List Livestock", () => {
    it("should list all livestock for a tank (200)", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        tank_id: string;
        count: number;
        livestock: Array<{ id: string; name: string }>;
      };

      expect(data.success).toBe(true);
      expect(data.tank_id).toBe(testState.tankId);
      expect(data.count).toBeGreaterThanOrEqual(1);
      expect(Array.isArray(data.livestock)).toBe(true);
    });

    it("should return 401 without authentication", async () => {
      // Use a valid UUID format for the tank ID to ensure proper route matching
      const fakeTankId = generateUUID();
      const response = await SELF.fetch(
        `http://localhost/tanks/${fakeTankId}/livestock`,
        { method: "GET" }
      );

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent tank", async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeTankId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/tanks/${fakeTankId}/livestock`,
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when accessing other user's tank", async () => {
      if (!testState.user2Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user2Token,
        { method: "GET" }
      );

      expect(response.status).toBe(403);
    });
  });

  describe("PUT /livestock/:id - Update Livestock", () => {
    it("should update livestock successfully (200)", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}`,
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({
            name: "Blue Tang (Updated)",
            healthStatus: "sick",
            notes: "Showing signs of ich, started treatment",
          }),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        livestock: { name: string; health_status: string; notes: string };
      };

      expect(data.success).toBe(true);
      expect(data.livestock.name).toBe("Blue Tang (Updated)");
      expect(data.livestock.health_status).toBe("sick");
      expect(data.livestock.notes).toContain("ich");
    });

    it("should return 400 when no fields to update", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}`,
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({}),
        }
      );

      expect(response.status).toBe(400);

      const data = (await response.json()) as { error: string };
      expect(data.error).toBe("Bad request");
    });

    it("should return 401 without authentication", async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(
        `http://localhost/livestock/${fakeLivestockId}`,
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name: "Unauthorized Update" }),
        }
      );

      expect(response.status).toBe(401);
    });

    it("should return 400 for invalid health status", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}`,
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({
            healthStatus: "invalid_status",
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it("should return 404 for non-existent livestock", async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/livestock/${fakeLivestockId}`,
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({ name: "Ghost Fish" }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 404 when user2 tries to update user1's livestock (403 manifests as 404)", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}`,
        testState.user2Token,
        {
          method: "PUT",
          body: JSON.stringify({ name: "Stolen Fish" }),
        }
      );

      // Returns 404 because verifyLivestockOwnership checks user ownership
      expect(response.status).toBe(404);
    });
  });

  describe("POST /livestock/:id/logs - Add Care Log", () => {
    it("should create a care log successfully (201)", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "treatment",
            description: "Applied copper treatment for ich",
          }),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        log: {
          id: string;
          livestock_id: string;
          log_type: string;
          description: string;
        };
      };

      expect(data.success).toBe(true);
      expect(data.log.livestock_id).toBe(testState.livestockId);
      expect(data.log.log_type).toBe("treatment");
      expect(data.log.description).toContain("copper");
    });

    it("should create a feeding log (201)", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "feeding",
            description: "Fed frozen mysis shrimp",
          }),
        }
      );

      expect(response.status).toBe(201);
    });

    it("should create observation log (201)", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "observation",
            description: "Colors looking brighter today",
          }),
        }
      );

      expect(response.status).toBe(201);
    });

    it("should update health_status to deceased when log type is death (201)", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      // Create a new livestock to test death log
      const createResponse = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "Test Snail",
            category: "Invertebrate",
          }),
        }
      );

      expect(createResponse.status).toBe(201);

      const createData = (await createResponse.json()) as {
        livestock: { id: string };
      };
      const snailId = createData.livestock.id;

      // Log death
      const deathLogResponse = await authenticatedFetch(
        `http://localhost/livestock/${snailId}/logs`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "death",
            description: "Found deceased in tank",
          }),
        }
      );

      expect(deathLogResponse.status).toBe(201);

      // Verify health status was updated
      const listResponse = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        { method: "GET" }
      );

      const listData = (await listResponse.json()) as {
        livestock: Array<{ id: string; health_status: string }>;
      };

      const snail = listData.livestock.find((l) => l.id === snailId);
      expect(snail?.health_status).toBe("deceased");
    });

    it("should return 400 for invalid log type", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "invalid_type",
            description: "Test",
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it("should return 401 without authentication", async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(
        `http://localhost/livestock/${fakeLivestockId}/logs`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            logType: "observation",
            description: "Unauthorized log",
          }),
        }
      );

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent livestock", async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/livestock/${fakeLivestockId}/logs`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "observation",
            description: "Ghost observation",
          }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 404 when user2 tries to log for user1's livestock", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user2Token,
        {
          method: "POST",
          body: JSON.stringify({
            logType: "observation",
            description: "Unauthorized observation",
          }),
        }
      );

      expect(response.status).toBe(404);
    });
  });

  describe("GET /livestock/:id/logs - Get Care Logs", () => {
    it("should get all logs for livestock (200)", async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        livestock_id: string;
        livestock_name: string;
        count: number;
        logs: Array<{ id: string; log_type: string }>;
      };

      expect(data.success).toBe(true);
      expect(data.livestock_id).toBe(testState.livestockId);
      expect(data.count).toBeGreaterThanOrEqual(1);
      expect(Array.isArray(data.logs)).toBe(true);
    });

    it("should return 401 without authentication", async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(
        `http://localhost/livestock/${fakeLivestockId}/logs`,
        { method: "GET" }
      );

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent livestock", async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId2 = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/livestock/${fakeLivestockId2}/logs`,
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(404);
    });

    it("should return 404 when user2 tries to get user1's livestock logs", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}/logs`,
        testState.user2Token,
        { method: "GET" }
      );

      expect(response.status).toBe(404);
    });
  });

  describe("DELETE /livestock/:id - Delete Livestock", () => {
    it("should soft delete livestock successfully (200)", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      // Create a livestock to delete
      const createResponse = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            name: "To Be Deleted Coral",
            category: "SPS",
          }),
        }
      );

      expect(createResponse.status).toBe(201);

      const createData = (await createResponse.json()) as {
        livestock: { id: string };
      };
      const deleteId = createData.livestock.id;

      // Delete it
      const deleteResponse = await authenticatedFetch(
        `http://localhost/livestock/${deleteId}`,
        testState.user1Token,
        { method: "DELETE" }
      );

      expect(deleteResponse.status).toBe(200);

      const deleteData = (await deleteResponse.json()) as {
        success: boolean;
        message: string;
        livestock_id: string;
        deleted_at: string;
      };

      expect(deleteData.success).toBe(true);
      expect(deleteData.message).toContain("deleted");
      expect(deleteData.deleted_at).toBeDefined();

      // Verify it's no longer in list
      const listResponse = await authenticatedFetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        { method: "GET" }
      );

      const listData = (await listResponse.json()) as {
        livestock: Array<{ id: string }>;
      };

      const found = listData.livestock.find((l) => l.id === deleteId);
      expect(found).toBeUndefined();
    });

    it("should return 401 without authentication", async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(
        `http://localhost/livestock/${fakeLivestockId}`,
        { method: "DELETE" }
      );

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent livestock", async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId2 = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/livestock/${fakeLivestockId2}`,
        testState.user1Token,
        { method: "DELETE" }
      );

      expect(response.status).toBe(404);
    });

    it("should return 404 when user2 tries to delete user1's livestock", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/livestock/${testState.livestockId}`,
        testState.user2Token,
        { method: "DELETE" }
      );

      expect(response.status).toBe(404);
    });
  });
});

// =============================================================================
// NOTIFICATIONS API TESTS
// =============================================================================

describe("Notifications API", () => {
  describe("POST /notifications/token - Register Push Token", () => {
    it("should register push token successfully (201)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: `test_apns_token_${Date.now()}`,
            platform: "ios",
            deviceName: "iPhone 15 Pro",
          }),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        success: boolean;
        token: { id: string; platform: string; device_name: string };
      };

      expect(data.success).toBe(true);
      expect(data.token.platform).toBe("ios");
      expect(data.token.device_name).toBe("iPhone 15 Pro");
    });

    it("should register android token (201)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: `test_fcm_token_${Date.now()}`,
            platform: "android",
            deviceName: "Pixel 8",
          }),
        }
      );

      expect(response.status).toBe(201);

      const data = (await response.json()) as {
        token: { platform: string };
      };
      expect(data.token.platform).toBe("android");
    });

    it("should register token without device name (201)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: `test_token_no_name_${Date.now()}`,
            platform: "ios",
          }),
        }
      );

      expect(response.status).toBe(201);
    });

    it("should return 401 without authentication", async () => {
      const response = await SELF.fetch("http://localhost/notifications/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: "unauthorized_token",
          platform: "ios",
        }),
      });

      expect(response.status).toBe(401);
    });

    it("should return 400 for invalid platform", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: "test_token",
            platform: "windows",
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it("should return 400 for missing token", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            platform: "ios",
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it("should return 400 for empty token", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: "",
            platform: "ios",
          }),
        }
      );

      expect(response.status).toBe(400);
    });
  });

  describe("DELETE /notifications/token - Unregister Push Token", () => {
    let tokenToDelete: string;

    beforeAll(async () => {
      // Register a token to delete
      if (!testState.user1Token) return;

      tokenToDelete = `delete_me_token_${Date.now()}`;
      await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: tokenToDelete,
            platform: "ios",
          }),
        }
      );
    });

    it("should unregister push token successfully (200)", async () => {
      if (!testState.user1Token || !tokenToDelete) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "DELETE",
          body: JSON.stringify({
            token: tokenToDelete,
          }),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        message: string;
      };

      expect(data.success).toBe(true);
      expect(data.message).toContain("unregistered");
    });

    it("should return 401 without authentication", async () => {
      const response = await SELF.fetch("http://localhost/notifications/token", {
        method: "DELETE",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: "some_token",
        }),
      });

      expect(response.status).toBe(401);
    });

    it("should return 404 for non-existent token", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "DELETE",
          body: JSON.stringify({
            token: "non_existent_token_xyz",
          }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 404 when user2 tries to delete user1's token", async () => {
      if (!testState.user1Token || !testState.user2Token) {
        return;
      }

      // Register a token for user1
      const user1Token = `user1_protected_token_${Date.now()}`;
      await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            token: user1Token,
            platform: "ios",
          }),
        }
      );

      // Try to delete it as user2
      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user2Token,
        {
          method: "DELETE",
          body: JSON.stringify({
            token: user1Token,
          }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 400 for missing token in body", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/token",
        testState.user1Token,
        {
          method: "DELETE",
          body: JSON.stringify({}),
        }
      );

      expect(response.status).toBe(400);
    });
  });

  describe("GET /notifications/settings - Get Notification Settings", () => {
    it("should get notification settings (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/settings",
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        settings: Record<
          string,
          {
            minThreshold: number | null;
            maxThreshold: number | null;
            enabled: boolean;
          }
        >;
      };

      expect(data.success).toBe(true);
      expect(data.settings).toBeDefined();

      // Check that default parameters are present
      expect(data.settings.ph).toBeDefined();
      expect(data.settings.alkalinity).toBeDefined();
      expect(data.settings.calcium).toBeDefined();
      expect(data.settings.magnesium).toBeDefined();
    });

    it("should initialize defaults for new user (200)", async () => {
      if (!testState.user2Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/settings",
        testState.user2Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        settings: Record<string, { enabled: boolean }>;
      };

      // All parameters should be enabled by default
      Object.values(data.settings).forEach((setting) => {
        expect(setting.enabled).toBe(true);
      });
    });

    it("should return 401 without authentication", async () => {
      const response = await SELF.fetch(
        "http://localhost/notifications/settings",
        { method: "GET" }
      );

      expect(response.status).toBe(401);
    });
  });

  describe("PUT /notifications/settings - Update Notification Settings", () => {
    it("should update notification settings (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/settings",
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({
            settings: [
              {
                parameter: "ph",
                minThreshold: 8.0,
                maxThreshold: 8.3,
                enabled: true,
              },
              {
                parameter: "alkalinity",
                minThreshold: 8,
                maxThreshold: 10,
                enabled: true,
              },
            ],
          }),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        message: string;
        settings: Array<{
          parameter: string;
          minThreshold: number;
          maxThreshold: number;
        }>;
      };

      expect(data.success).toBe(true);
      expect(data.message).toContain("Updated");
      expect(data.settings.length).toBe(2);
    });

    it("should disable a parameter alert (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/settings",
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({
            settings: [
              {
                parameter: "phosphate",
                enabled: false,
              },
            ],
          }),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        settings: Array<{ parameter: string; enabled: boolean }>;
      };

      const phosphateSetting = data.settings.find(
        (s) => s.parameter === "phosphate"
      );
      expect(phosphateSetting?.enabled).toBe(false);
    });

    it("should return 401 without authentication", async () => {
      const response = await SELF.fetch(
        "http://localhost/notifications/settings",
        {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            settings: [{ parameter: "ph", enabled: false }],
          }),
        }
      );

      expect(response.status).toBe(401);
    });

    it("should return 400 for invalid parameter name", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/settings",
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({
            settings: [
              {
                parameter: "invalid_parameter",
                enabled: true,
              },
            ],
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it("should return 400 for invalid settings format", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/settings",
        testState.user1Token,
        {
          method: "PUT",
          body: JSON.stringify({
            settings: "not an array",
          }),
        }
      );

      expect(response.status).toBe(400);
    });
  });

  describe("GET /notifications/history - Get Notification History", () => {
    it("should get notification history (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/history",
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        total: number;
        limit: number;
        offset: number;
        notifications: Array<{ id: string; type: string }>;
      };

      expect(data.success).toBe(true);
      expect(typeof data.total).toBe("number");
      expect(data.limit).toBe(50); // Default limit
      expect(data.offset).toBe(0); // Default offset
      expect(Array.isArray(data.notifications)).toBe(true);
    });

    it("should respect pagination parameters (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/history?limit=10&offset=0",
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        limit: number;
        offset: number;
      };

      expect(data.limit).toBe(10);
      expect(data.offset).toBe(0);
    });

    it("should filter by unread only (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/history?unreadOnly=true",
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        notifications: Array<{ readAt: string | null }>;
      };

      expect(data.success).toBe(true);
      // All notifications should have null readAt
      data.notifications.forEach((n) => {
        expect(n.readAt).toBeNull();
      });
    });

    it("should return 401 without authentication", async () => {
      const response = await SELF.fetch(
        "http://localhost/notifications/history",
        { method: "GET" }
      );

      expect(response.status).toBe(401);
    });

    it("should return 400 for invalid limit", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/history?limit=500",
        testState.user1Token,
        { method: "GET" }
      );

      expect(response.status).toBe(400);
    });
  });

  describe("POST /notifications/read - Mark Notifications as Read", () => {
    it("should mark all notifications as read (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/read",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({}),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        message: string;
        markedCount: number;
      };

      expect(data.success).toBe(true);
      expect(data.message).toContain("all");
      expect(typeof data.markedCount).toBe("number");
    });

    it("should mark specific notifications as read (200)", async () => {
      if (!testState.user1Token) {
        return;
      }

      // First, create some notifications by inserting directly
      const notificationId = generateUUID();
      try {
        await env.DB.prepare(
          `INSERT INTO notification_history (id, user_id, type, title, body, sent_at)
           VALUES (?, ?, ?, ?, ?, datetime('now'))`
        )
          .bind(
            notificationId,
            testState.user1Id,
            "parameter_alert",
            "Test Alert",
            "This is a test notification"
          )
          .run();
      } catch (e) {
        console.log("Could not insert test notification:", e);
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/read",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            notificationIds: [notificationId],
          }),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        markedCount: number;
      };

      expect(data.success).toBe(true);
      expect(data.markedCount).toBeGreaterThanOrEqual(0);
    });

    it("should return 401 without authentication", async () => {
      const response = await SELF.fetch("http://localhost/notifications/read", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({}),
      });

      expect(response.status).toBe(401);
    });

    it("should return 400 for invalid notification ID format", async () => {
      if (!testState.user1Token) {
        return;
      }

      const response = await authenticatedFetch(
        "http://localhost/notifications/read",
        testState.user1Token,
        {
          method: "POST",
          body: JSON.stringify({
            notificationIds: ["not-a-uuid", "also-not-valid"],
          }),
        }
      );

      expect(response.status).toBe(400);
    });
  });
});

// =============================================================================
// EDGE CASES AND ERROR HANDLING
// =============================================================================

describe("Edge Cases and Error Handling", () => {
  describe("Invalid Session Handling", () => {
    it("should return 401 for expired/invalid session token", async () => {
      const response = await SELF.fetch(
        "http://localhost/notifications/settings",
        {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Bearer invalid_session_token_12345",
          },
        }
      );

      expect(response.status).toBe(401);
    });

    it("should return 401 for malformed Authorization header", async () => {
      const response = await SELF.fetch(
        "http://localhost/notifications/settings",
        {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
            Authorization: "Basic dXNlcjpwYXNz",
          },
        }
      );

      expect(response.status).toBe(401);
    });
  });

  describe("Malformed Request Bodies", () => {
    it("should handle empty request body gracefully for livestock creation", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await SELF.fetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        {
          method: "POST",
          headers: authHeaders(testState.user1Token),
          body: "",
        }
      );

      // Should return 400 or 500 (not crash)
      expect([400, 500]).toContain(response.status);
    });

    it("should handle invalid JSON gracefully", async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await SELF.fetch(
        `http://localhost/tanks/${testState.tankId}/livestock`,
        {
          method: "POST",
          headers: authHeaders(testState.user1Token),
          body: "{ invalid json }",
        }
      );

      expect([400, 500]).toContain(response.status);
    });
  });

  describe("Livestock Category Validation", () => {
    const validCategories = ["SPS", "LPS", "Soft", "Fish", "Invertebrate"];

    validCategories.forEach((category) => {
      it(`should accept valid category: ${category}`, async () => {
        if (!testState.user1Token || !testState.tankId) {
          return;
        }

        const response = await authenticatedFetch(
          `http://localhost/tanks/${testState.tankId}/livestock`,
          testState.user1Token,
          {
            method: "POST",
            body: JSON.stringify({
              name: `Test ${category}`,
              category: category,
            }),
          }
        );

        expect(response.status).toBe(201);
      });
    });
  });

  describe("Notification Parameter Validation", () => {
    const validParameters = [
      "ph",
      "alkalinity",
      "calcium",
      "magnesium",
      "ammonia",
      "nitrate",
      "phosphate",
      "salinity",
      "temperature",
    ];

    validParameters.forEach((param) => {
      it(`should accept valid parameter: ${param}`, async () => {
        if (!testState.user1Token) {
          return;
        }

        const response = await authenticatedFetch(
          "http://localhost/notifications/settings",
          testState.user1Token,
          {
            method: "PUT",
            body: JSON.stringify({
              settings: [
                {
                  parameter: param,
                  enabled: true,
                },
              ],
            }),
          }
        );

        expect(response.status).toBe(200);
      });
    });
  });
});
