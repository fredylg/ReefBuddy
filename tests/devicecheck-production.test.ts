/**
 * DeviceCheck Production Environment Tests
 * Tests the actual production deployment at https://reefbuddy.fredylg.workers.dev
 * 
 * WARNING: These tests make real HTTP requests to production
 * They will consume credits and may affect production data
 */

import { describe, it, expect } from "vitest";

const PRODUCTION_URL = "https://reefbuddy.fredylg.workers.dev";

// =============================================================================
// TEST DATA
// =============================================================================

const validWaterParameters = {
  salinity: 1.025,
  temperature: 78,
  ph: 8.2,
  alkalinity: 8.5,
  calcium: 420,
  magnesium: 1350,
  nitrate: 5,
  phosphate: 0.03,
  ammonia: 0,
};

// Mock DeviceCheck token (base64 encoded, but invalid for actual validation)
const mockDeviceToken = "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";

function generateUUID(): string {
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === "x" ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

async function postAnalyze(body: Record<string, unknown>): Promise<Response> {
  return fetch(`${PRODUCTION_URL}/analyze`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

// =============================================================================
// TEST SUITES
// =============================================================================

describe("DeviceCheck Production Security Tests", () => {
  describe("Production Environment - DeviceCheck Required", () => {
    it("should reject requests without DeviceCheck token", async () => {
      const requestBody = {
        deviceId: `TEST-PROD-${Date.now()}`,
        tankId: generateUUID(),
        parameters: validWaterParameters,
        tankVolume: 75,
        temperatureUnit: "F",
        isDevelopment: false,
        // No deviceToken provided
      };

      const response = await postAnalyze(requestBody);
      const data = await response.json() as { error: string; code: string; message: string };

      console.log(`Status: ${response.status}`);
      console.log(`Response:`, JSON.stringify(data, null, 2));

      expect(response.status).toBe(403);
      expect(data.error).toBe("Device verification required");
      expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
      expect(data.message).toContain("update to the latest app version");
    }, 30000);

    it("should reject requests with invalid DeviceCheck token", async () => {
      const requestBody = {
        deviceId: `TEST-PROD-INVALID-${Date.now()}`,
        tankId: generateUUID(),
        parameters: validWaterParameters,
        tankVolume: 75,
        temperatureUnit: "F",
        isDevelopment: false,
        deviceToken: "invalid_token_format_not_base64",
      };

      const response = await postAnalyze(requestBody);
      const data = await response.json() as { error: string; code?: string };

      console.log(`Status: ${response.status}`);
      console.log(`Response:`, JSON.stringify(data, null, 2));

      // Should fail validation (either 403 from DeviceCheck validation or 503 from JWT generation)
      expect([403, 503]).toContain(response.status);
      if (response.status === 403) {
        expect(data.code).toBe("DEVICE_CHECK_FAILED");
      }
    }, 30000);

    it("should reject requests with mock DeviceCheck token (invalid for Apple)", async () => {
      const requestBody = {
        deviceId: `TEST-PROD-MOCK-${Date.now()}`,
        tankId: generateUUID(),
        parameters: validWaterParameters,
        tankVolume: 75,
        temperatureUnit: "F",
        isDevelopment: false,
        deviceToken: mockDeviceToken,
      };

      const response = await postAnalyze(requestBody);
      const data = await response.json() as { error: string; code?: string };

      console.log(`Status: ${response.status}`);
      console.log(`Response:`, JSON.stringify(data, null, 2));

      // Should fail DeviceCheck validation (403) or service error (503)
      expect([403, 503]).toContain(response.status);
    }, 30000);
  });

  describe("Security: Prevent Exploitation", () => {
    it("should prevent abuse by rejecting multiple requests without tokens", async () => {
      const deviceIds = [
        `ABUSE-PROD-001-${Date.now()}`,
        `ABUSE-PROD-002-${Date.now()}`,
        `ABUSE-PROD-003-${Date.now()}`,
      ];

      for (const deviceId of deviceIds) {
        const requestBody = {
          deviceId,
          tankId: generateUUID(),
          parameters: validWaterParameters,
          tankVolume: 75,
          temperatureUnit: "F",
          isDevelopment: false,
          // No deviceToken - should be rejected
        };

        const response = await postAnalyze(requestBody);
        const data = await response.json() as { error: string; code: string };

        console.log(`Device ${deviceId}: Status ${response.status}, Code: ${data.code}`);

        expect(response.status).toBe(403);
        expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
      }
    }, 60000);

    it("should enforce DeviceCheck even with valid request structure", async () => {
      const requestBody = {
        deviceId: `TEST-PROD-STRUCTURE-${Date.now()}`,
        tankId: generateUUID(),
        parameters: validWaterParameters,
        tankVolume: 75,
        temperatureUnit: "F",
        isDevelopment: false,
        // Valid structure but missing deviceToken
      };

      const response = await postAnalyze(requestBody);
      const data = await response.json() as { error: string; code: string };

      console.log(`Status: ${response.status}`);
      console.log(`Response:`, JSON.stringify(data, null, 2));

      expect(response.status).toBe(403);
      expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
    }, 30000);
  });

  describe("Production Configuration Check", () => {
    it("should verify production environment is set correctly", async () => {
      // Make a request without token to check if production mode is active
      const requestBody = {
        deviceId: `TEST-PROD-CONFIG-${Date.now()}`,
        tankId: generateUUID(),
        parameters: validWaterParameters,
        tankVolume: 75,
        temperatureUnit: "F",
        isDevelopment: false,
      };

      const response = await postAnalyze(requestBody);
      const data = await response.json() as { error: string; code: string; message: string };

      console.log(`Status: ${response.status}`);
      console.log(`Response:`, JSON.stringify(data, null, 2));

      // If production is configured correctly:
      // - Should require DeviceCheck (403 DEVICE_CHECK_REQUIRED) OR
      // - Should reject if DeviceCheck not configured (503 DEVICE_CHECK_MISCONFIGURED)
      expect([403, 503]).toContain(response.status);
      
      if (response.status === 403) {
        expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
        console.log("✅ Production is configured and requires DeviceCheck");
      } else if (response.status === 503) {
        expect(data.code).toBe("DEVICE_CHECK_MISCONFIGURED");
        console.log("⚠️  Production requires DeviceCheck but it's not configured");
      }
    }, 30000);
  });
});
