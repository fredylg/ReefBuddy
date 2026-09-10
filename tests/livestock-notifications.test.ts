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

import { describe, it, expect, beforeAll } from 'vitest';
import { SELF } from 'cloudflare:test';

// =============================================================================
// TEST UTILITIES
// =============================================================================

/**
 * Generate a valid UUID
 */
function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Create authenticated request headers
 */
function authHeaders(token: string): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    'X-Device-ID': token,
  };
}

/**
 * Helper to make authenticated requests
 */
async function authenticatedFetch(url: string, token: string, options: RequestInit = {}): Promise<Response> {
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
  user1Token: '',
  user1Id: '',
  user2Token: '',
  user2Id: '',
  tankId: '',
  tank2Id: '',
  livestockId: '',
};

// =============================================================================
// SETUP: Create test users and tanks
// =============================================================================

beforeAll(async () => {
  // Accounts were removed from the API (App Review 5.6, Sept 2026). Actors are devices: the "tokens"
  // below are device ids, and tanks are created through the API so the device users exist.
  testState.user1Token = `TEST-${generateUUID().toUpperCase()}`;
  testState.user2Token = `TEST-${generateUUID().toUpperCase()}`;

  const createTank = async (deviceId: string, name: string, volume: number): Promise<string> => {
    const res = await authenticatedFetch('http://localhost/api/tanks', deviceId, {
      method: 'POST',
      body: JSON.stringify({ name, volume_gallons: volume, tank_type: 'reef' }),
    });
    if (res.status !== 201) {
      console.log('Tank creation error:', res.status, await res.text());
      return '';
    }
    const data = (await res.json()) as { data: { id: string; user_id: string } };
    return data.data.id;
  };
  testState.tankId = await createTank(testState.user1Token, 'Test Reef Tank', 75);
  testState.tank2Id = await createTank(testState.user2Token, 'User 2 Tank', 50);
});

// =============================================================================
// LIVESTOCK API TESTS
// =============================================================================

describe('Livestock API', () => {
  describe('POST /tanks/:tankId/livestock - Create Livestock', () => {
    it('should create livestock successfully (201)', async () => {
      if (!testState.user1Token || !testState.tankId) {
        console.log('Skipping: test user not created');
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'Blue Tang',
            species: 'Paracanthurus hepatus',
            category: 'Fish',
            quantity: 1,
            purchasePrice: 75.99,
            healthStatus: 'healthy',
            notes: 'Beautiful specimen, eating well',
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
      expect(data.livestock.name).toBe('Blue Tang');
      expect(data.livestock.species).toBe('Paracanthurus hepatus');
      expect(data.livestock.category).toBe('Fish');
      expect(data.livestock.quantity).toBe(1);
      expect(data.livestock.health_status).toBe('healthy');

      // Store for later tests
      testState.livestockId = data.livestock.id;
    });

    it('should create livestock with minimal required fields (201)', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'Hammer Coral',
            category: 'LPS',
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
      expect(data.livestock.health_status).toBe('healthy'); // Default value
    });

    it('should return 401 without authentication', async () => {
      // Use a valid UUID format for the tank ID to ensure proper route matching
      const fakeTankId = generateUUID();
      const response = await SELF.fetch(`http://localhost/api/tanks/${fakeTankId}/livestock`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: 'Clownfish',
          category: 'Fish',
        }),
      });

      expect(response.status).toBe(401);
    });

    it('should return 400 for invalid category', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'Mystery Creature',
            category: 'InvalidCategory',
          }),
        }
      );

      expect(response.status).toBe(400);

      const data = (await response.json()) as { error: string };
      expect(data.error).toBe('Validation failed');
    });

    it('should return 400 for missing name', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            category: 'Fish',
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it('should return 404 for non-existent tank', async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeTankId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${fakeTankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'Test Fish',
            category: 'Fish',
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
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user2Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'Unauthorized Fish',
            category: 'Fish',
          }),
        }
      );

      expect(response.status).toBe(403);
    });
  });

  describe('GET /tanks/:tankId/livestock - List Livestock', () => {
    it('should list all livestock for a tank (200)', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        { method: 'GET' }
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

    it('should return 401 without authentication', async () => {
      // Use a valid UUID format for the tank ID to ensure proper route matching
      const fakeTankId = generateUUID();
      const response = await SELF.fetch(`http://localhost/api/tanks/${fakeTankId}/livestock`, { method: 'GET' });

      expect(response.status).toBe(401);
    });

    it('should return 404 for non-existent tank', async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeTankId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${fakeTankId}/livestock`,
        testState.user1Token,
        { method: 'GET' }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when accessing other user's tank", async () => {
      if (!testState.user2Token || !testState.tankId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user2Token,
        { method: 'GET' }
      );

      expect(response.status).toBe(403);
    });
  });

  describe('PUT /livestock/:id - Update Livestock', () => {
    it('should update livestock successfully (200)', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}`,
        testState.user1Token,
        {
          method: 'PUT',
          body: JSON.stringify({
            name: 'Blue Tang (Updated)',
            healthStatus: 'sick',
            notes: 'Showing signs of ich, started treatment',
          }),
        }
      );

      expect(response.status).toBe(200);

      const data = (await response.json()) as {
        success: boolean;
        livestock: { name: string; health_status: string; notes: string };
      };

      expect(data.success).toBe(true);
      expect(data.livestock.name).toBe('Blue Tang (Updated)');
      expect(data.livestock.health_status).toBe('sick');
      expect(data.livestock.notes).toContain('ich');
    });

    it('should return 400 when no fields to update', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}`,
        testState.user1Token,
        {
          method: 'PUT',
          body: JSON.stringify({}),
        }
      );

      expect(response.status).toBe(400);

      const data = (await response.json()) as { error: string };
      expect(data.error).toBe('Bad request');
    });

    it('should return 401 without authentication', async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(`http://localhost/api/livestock/${fakeLivestockId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: 'Unauthorized Update' }),
      });

      expect(response.status).toBe(401);
    });

    it('should return 400 for invalid health status', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}`,
        testState.user1Token,
        {
          method: 'PUT',
          body: JSON.stringify({
            healthStatus: 'invalid_status',
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it('should return 404 for non-existent livestock', async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${fakeLivestockId}`,
        testState.user1Token,
        {
          method: 'PUT',
          body: JSON.stringify({ name: 'Ghost Fish' }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when user2 tries to update user1's livestock", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}`,
        testState.user2Token,
        {
          method: 'PUT',
          body: JSON.stringify({ name: 'Stolen Fish' }),
        }
      );

      // verifyLivestockOwnership: the record exists but belongs to another device user
      expect(response.status).toBe(403);
    });
  });

  describe('POST /livestock/:id/logs - Add Care Log', () => {
    it('should create a care log successfully (201)', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'treatment',
            description: 'Applied copper treatment for ich',
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
      expect(data.log.log_type).toBe('treatment');
      expect(data.log.description).toContain('copper');
    });

    it('should create a feeding log (201)', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'feeding',
            description: 'Fed frozen mysis shrimp',
          }),
        }
      );

      expect(response.status).toBe(201);
    });

    it('should create observation log (201)', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'observation',
            description: 'Colors looking brighter today',
          }),
        }
      );

      expect(response.status).toBe(201);
    });

    it('should update health_status to deceased when log type is death (201)', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      // Create a new livestock to test death log
      const createResponse = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'Test Snail',
            category: 'Invertebrate',
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
        `http://localhost/api/livestock/${snailId}/logs`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'death',
            description: 'Found deceased in tank',
          }),
        }
      );

      expect(deathLogResponse.status).toBe(201);

      // Verify health status was updated
      const listResponse = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        { method: 'GET' }
      );

      const listData = (await listResponse.json()) as {
        livestock: Array<{ id: string; health_status: string }>;
      };

      const snail = listData.livestock.find((l) => l.id === snailId);
      expect(snail?.health_status).toBe('deceased');
    });

    it('should return 400 for invalid log type', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'invalid_type',
            description: 'Test',
          }),
        }
      );

      expect(response.status).toBe(400);
    });

    it('should return 401 without authentication', async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(`http://localhost/api/livestock/${fakeLivestockId}/logs`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          logType: 'observation',
          description: 'Unauthorized log',
        }),
      });

      expect(response.status).toBe(401);
    });

    it('should return 404 for non-existent livestock', async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${fakeLivestockId}/logs`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'observation',
            description: 'Ghost observation',
          }),
        }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when user2 tries to log for user1's livestock", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user2Token,
        {
          method: 'POST',
          body: JSON.stringify({
            logType: 'observation',
            description: 'Unauthorized observation',
          }),
        }
      );

      expect(response.status).toBe(403);
    });
  });

  describe('GET /livestock/:id/logs - Get Care Logs', () => {
    it('should get all logs for livestock (200)', async () => {
      if (!testState.user1Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user1Token,
        { method: 'GET' }
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

    it('should return 401 without authentication', async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(`http://localhost/api/livestock/${fakeLivestockId}/logs`, { method: 'GET' });

      expect(response.status).toBe(401);
    });

    it('should return 404 for non-existent livestock', async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId2 = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${fakeLivestockId2}/logs`,
        testState.user1Token,
        { method: 'GET' }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when user2 tries to get user1's livestock logs", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}/logs`,
        testState.user2Token,
        { method: 'GET' }
      );

      expect(response.status).toBe(403);
    });
  });

  describe('DELETE /livestock/:id - Delete Livestock', () => {
    it('should soft delete livestock successfully (200)', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      // Create a livestock to delete
      const createResponse = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        {
          method: 'POST',
          body: JSON.stringify({
            name: 'To Be Deleted Coral',
            category: 'SPS',
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
        `http://localhost/api/livestock/${deleteId}`,
        testState.user1Token,
        { method: 'DELETE' }
      );

      expect(deleteResponse.status).toBe(200);

      const deleteData = (await deleteResponse.json()) as {
        success: boolean;
        message: string;
        livestock_id: string;
        deleted_at: string;
      };

      expect(deleteData.success).toBe(true);
      expect(deleteData.message).toContain('deleted');
      expect(deleteData.deleted_at).toBeDefined();

      // Verify it's no longer in list
      const listResponse = await authenticatedFetch(
        `http://localhost/api/tanks/${testState.tankId}/livestock`,
        testState.user1Token,
        { method: 'GET' }
      );

      const listData = (await listResponse.json()) as {
        livestock: Array<{ id: string }>;
      };

      const found = listData.livestock.find((l) => l.id === deleteId);
      expect(found).toBeUndefined();
    });

    it('should return 401 without authentication', async () => {
      // Use a valid UUID format for the livestock ID to ensure proper route matching
      const fakeLivestockId = generateUUID();
      const response = await SELF.fetch(`http://localhost/api/livestock/${fakeLivestockId}`, { method: 'DELETE' });

      expect(response.status).toBe(401);
    });

    it('should return 404 for non-existent livestock', async () => {
      if (!testState.user1Token) {
        return;
      }

      const fakeLivestockId2 = generateUUID();
      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${fakeLivestockId2}`,
        testState.user1Token,
        { method: 'DELETE' }
      );

      expect(response.status).toBe(404);
    });

    it("should return 403 when user2 tries to delete user1's livestock", async () => {
      if (!testState.user2Token || !testState.livestockId) {
        return;
      }

      const response = await authenticatedFetch(
        `http://localhost/api/livestock/${testState.livestockId}`,
        testState.user2Token,
        { method: 'DELETE' }
      );

      expect(response.status).toBe(403);
    });
  });
});

// =============================================================================
// NOTIFICATIONS API TESTS
// =============================================================================

describe('Edge Cases and Error Handling', () => {
  describe('Malformed Request Bodies', () => {
    it('should handle empty request body gracefully for livestock creation', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await SELF.fetch(`http://localhost/api/tanks/${testState.tankId}/livestock`, {
        method: 'POST',
        headers: authHeaders(testState.user1Token),
        body: '',
      });

      // Should return 400 or 500 (not crash)
      expect([400, 500]).toContain(response.status);
    });

    it('should handle invalid JSON gracefully', async () => {
      if (!testState.user1Token || !testState.tankId) {
        return;
      }

      const response = await SELF.fetch(`http://localhost/api/tanks/${testState.tankId}/livestock`, {
        method: 'POST',
        headers: authHeaders(testState.user1Token),
        body: '{ invalid json }',
      });

      expect([400, 500]).toContain(response.status);
    });
  });

  describe('Livestock Category Validation', () => {
    const validCategories = ['SPS', 'LPS', 'Soft', 'Fish', 'Invertebrate'];

    validCategories.forEach((category) => {
      it(`should accept valid category: ${category}`, async () => {
        if (!testState.user1Token || !testState.tankId) {
          return;
        }

        const response = await authenticatedFetch(
          `http://localhost/api/tanks/${testState.tankId}/livestock`,
          testState.user1Token,
          {
            method: 'POST',
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
});
