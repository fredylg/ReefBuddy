/**
 * DeviceCheck Security Tests
 * Tests the security implementation of DeviceCheck validation
 * 
 * Tests:
 * - Production environment requires DeviceCheck configuration
 * - Requests without DeviceCheck tokens are rejected
 * - Invalid DeviceCheck tokens are rejected
 * - Development environment allows bypass
 */

import { describe, it, expect, beforeEach } from "vitest";
import {
  env,
  createExecutionContext,
  waitOnExecutionContext,
  SELF,
} from "cloudflare:test";
import worker from "../src/index";

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

const validAnalysisRequest = {
  deviceId: "TEST-DEVICE-SECURITY-001",
  tankId: "550e8400-e29b-41d4-a716-446655440000",
  parameters: validWaterParameters,
  tankVolume: 75,
  temperatureUnit: "F" as const,
};

// Mock DeviceCheck token (base64 encoded, but invalid for actual validation)
const mockDeviceToken = "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";

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

async function postAnalyze(
  body: Record<string, unknown>,
  customEnv?: typeof env
): Promise<Response> {
  const testEnv = customEnv || env;
  const ctx = createExecutionContext();
  
  const request = new Request("http://localhost/analyze", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  const response = await worker.fetch(request, testEnv, ctx);
  await waitOnExecutionContext(ctx);
  return response;
}

// =============================================================================
// TEST SUITES
// =============================================================================

describe("DeviceCheck Security Tests", () => {
  describe("Production Environment - DeviceCheck Required", () => {
    it("should reject requests without DeviceCheck token when DeviceCheck is configured", async () => {
      // Create environment with DeviceCheck configured
      const prodEnv = {
        ...env,
        ENVIRONMENT: "production",
        APPLE_KEY_ID: "TEST_KEY_ID",
        APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nTEST_KEY\n-----END PRIVATE KEY-----",
        APPLE_TEAM_ID: "TEST_TEAM_ID",
      };

      const requestBody = {
        ...validAnalysisRequest,
        // No deviceToken provided
      };

      const response = await postAnalyze(requestBody, prodEnv);
      const data = await response.json() as { error: string; code: string; message: string };

      expect(response.status).toBe(403);
      expect(data.error).toBe("Device verification required");
      expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
      expect(data.message).toContain("update to the latest app version");
    });

    it("should reject requests with invalid DeviceCheck token", async () => {
      const prodEnv = {
        ...env,
        ENVIRONMENT: "production",
        APPLE_KEY_ID: "TEST_KEY_ID",
        APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nTEST_KEY\n-----END PRIVATE KEY-----",
        APPLE_TEAM_ID: "TEST_TEAM_ID",
      };

      const requestBody = {
        ...validAnalysisRequest,
        deviceToken: "invalid_token_format",
        isDevelopment: false,
      };

      const response = await postAnalyze(requestBody, prodEnv);
      const data = await response.json() as { error: string; code: string };

      // Should fail validation (either 403 from DeviceCheck validation or 503 from JWT generation)
      expect([403, 503]).toContain(response.status);
      if (response.status === 403) {
        expect(data.code).toBe("DEVICE_CHECK_FAILED");
      }
    });

    it("should reject requests in production when DeviceCheck is not configured", async () => {
      // Production environment but DeviceCheck NOT configured
      const prodEnv = {
        ...env,
        ENVIRONMENT: "production",
        // No APPLE_* secrets
      };

      const requestBody = {
        ...validAnalysisRequest,
        deviceToken: mockDeviceToken,
        isDevelopment: false,
      };

      const response = await postAnalyze(requestBody, prodEnv);
      const data = await response.json() as { error: string; code: string; message: string };

      expect(response.status).toBe(503);
      expect(data.error).toBe("Service configuration error");
      expect(data.code).toBe("DEVICE_CHECK_MISCONFIGURED");
      expect(data.message).toContain("not properly configured");
    });
  });

  describe("Development Environment - DeviceCheck Optional", () => {
    it("should allow requests without DeviceCheck token in development", async () => {
      const devEnv = {
        ...env,
        ENVIRONMENT: "development",
        // No DeviceCheck configured
      };

      const requestBody = {
        ...validAnalysisRequest,
        // No deviceToken
      };

      const response = await postAnalyze(requestBody, devEnv);
      
      // Should either succeed (if credits available) or fail with credit error (402)
      // But should NOT fail with DeviceCheck error
      expect([200, 402]).toContain(response.status);
      
      if (response.status !== 200) {
        const data = await response.json() as { error: string; code: string };
        expect(data.code).not.toBe("DEVICE_CHECK_REQUIRED");
        expect(data.code).not.toBe("DEVICE_CHECK_MISCONFIGURED");
      }
    });

    it("should allow requests with DeviceCheck token in development", async () => {
      const devEnv = {
        ...env,
        ENVIRONMENT: "development",
      };

      const requestBody = {
        ...validAnalysisRequest,
        deviceToken: mockDeviceToken,
        isDevelopment: true,
      };

      const response = await postAnalyze(requestBody, devEnv);
      
      // Should either succeed or fail with credit error, not DeviceCheck error
      expect([200, 402]).toContain(response.status);
    });
  });

  describe("DeviceCheck Configuration Detection", () => {
    it("should detect when DeviceCheck is configured", async () => {
      const configuredEnv = {
        ...env,
        APPLE_KEY_ID: "TEST_KEY_ID",
        APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nTEST_KEY\n-----END PRIVATE KEY-----",
        APPLE_TEAM_ID: "TEST_TEAM_ID",
      };

      const requestBody = {
        ...validAnalysisRequest,
        // No deviceToken
      };

      const response = await postAnalyze(requestBody, configuredEnv);
      const data = await response.json() as { error: string; code: string };

      // Should require DeviceCheck token
      expect(response.status).toBe(403);
      expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
    });

    it("should allow bypass when DeviceCheck is not configured in development", async () => {
      const unconfiguredDevEnv = {
        ...env,
        ENVIRONMENT: "development",
        // No APPLE_* secrets
      };

      const requestBody = {
        ...validAnalysisRequest,
        // No deviceToken
      };

      const response = await postAnalyze(requestBody, unconfiguredDevEnv);
      
      // Should not fail with DeviceCheck error
      expect([200, 402]).toContain(response.status);
    });
  });

  describe("Security: Prevent Exploitation", () => {
    it("should prevent abuse by rejecting requests without tokens in production", async () => {
      const prodEnv = {
        ...env,
        ENVIRONMENT: "production",
        APPLE_KEY_ID: "TEST_KEY_ID",
        APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nTEST_KEY\n-----END PRIVATE KEY-----",
        APPLE_TEAM_ID: "TEST_TEAM_ID",
      };

      // Multiple requests with different deviceIds (simulating abuse)
      const deviceIds = ["ABUSE-001", "ABUSE-002", "ABUSE-003"];
      
      for (const deviceId of deviceIds) {
        const requestBody = {
          ...validAnalysisRequest,
          deviceId,
          // No deviceToken - should be rejected
        };

        const response = await postAnalyze(requestBody, prodEnv);
        const data = await response.json() as { error: string; code: string };

        expect(response.status).toBe(403);
        expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
      }
    });

    it("should enforce DeviceCheck even with valid request structure", async () => {
      const prodEnv = {
        ...env,
        ENVIRONMENT: "production",
        APPLE_KEY_ID: "TEST_KEY_ID",
        APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nTEST_KEY\n-----END PRIVATE KEY-----",
        APPLE_TEAM_ID: "TEST_TEAM_ID",
      };

      const requestBody = {
        ...validAnalysisRequest,
        // Valid structure but missing deviceToken
      };

      const response = await postAnalyze(requestBody, prodEnv);
      const data = await response.json() as { error: string; code: string };

      expect(response.status).toBe(403);
      expect(data.code).toBe("DEVICE_CHECK_REQUIRED");
    });
  });
});
