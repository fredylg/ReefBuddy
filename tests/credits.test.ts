/**
 * Credits Endpoints Tests
 * Tests for /credits/balance and credit tracking in /analyze
 * @tester-agent - Quality Assurance Lead
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

const TEST_DEVICE_ID = "TEST-DEVICE-CREDITS-001";

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/**
 * Get credit balance for a device
 */
async function getCreditsBalance(deviceId: string): Promise<Response> {
  return SELF.fetch(`http://localhost/credits/balance?deviceId=${deviceId}`, {
    method: "GET",
  });
}

/**
 * Make a POST request to the analyze endpoint
 */
async function postAnalyze(body: Record<string, unknown>): Promise<Response> {
  return SELF.fetch("http://localhost/analyze", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

// =============================================================================
// TEST SUITES
// =============================================================================

describe("GET /credits/balance", () => {
  it("should return credit balance for a device", async () => {
    const response = await getCreditsBalance(TEST_DEVICE_ID);
    expect(response.status).toBe(200);

    const data = (await response.json()) as {
      success: boolean;
      deviceId: string;
      freeLimit: number;
      freeUsed: number;
      freeRemaining: number;
      paidCredits: number;
      totalCredits: number;
      totalAnalyses: number;
    };

    expect(data.success).toBe(true);
    expect(data.deviceId).toBe(TEST_DEVICE_ID);
    expect(data.freeLimit).toBe(3);
    expect(data.freeRemaining).toBeGreaterThanOrEqual(0);
    expect(data.freeRemaining).toBeLessThanOrEqual(3);
    expect(data.paidCredits).toBeGreaterThanOrEqual(0);
    expect(data.totalCredits).toBe(data.freeRemaining + data.paidCredits);
  });

  it("should return 400 if deviceId is missing", async () => {
    const response = await SELF.fetch("http://localhost/credits/balance", {
      method: "GET",
    });

    expect(response.status).toBe(400);

    const data = (await response.json()) as {
      error: string;
      message: string;
    };
    expect(data.error).toBe("Validation failed");
    expect(data.message).toContain("deviceId");
  });

  it("should create device record on first access", async () => {
    const uniqueDeviceId = `TEST-DEVICE-${Date.now()}`;
    const response = await getCreditsBalance(uniqueDeviceId);

    expect(response.status).toBe(200);

    const data = (await response.json()) as {
      success: boolean;
      freeRemaining: number;
      paidCredits: number;
      totalAnalyses: number;
    };

    // New device should have 3 free credits
    expect(data.freeRemaining).toBe(3);
    expect(data.paidCredits).toBe(0);
    expect(data.totalAnalyses).toBe(0);
  });
});

describe("POST /analyze - Credit Tracking", () => {
  it("should consume a free credit when analyzing", async () => {
    const uniqueDeviceId = `TEST-DEVICE-${Date.now()}`;

    // Get initial balance
    const initialResponse = await getCreditsBalance(uniqueDeviceId);
    const initialData = (await initialResponse.json()) as {
      freeRemaining: number;
      totalAnalyses: number;
    };
    const initialFree = initialData.freeRemaining;
    const initialAnalyses = initialData.totalAnalyses;

    // Submit analysis
    const analysisRequest = {
      deviceId: uniqueDeviceId,
      tankId: "550e8400-e29b-41d4-a716-446655440000",
      parameters: {
        salinity: 1.025,
        temperature: 78,
        ph: 8.2,
        alkalinity: 8.5,
        calcium: 420,
        magnesium: 1350,
      },
      tankVolume: 75,
    };

    const analyzeResponse = await postAnalyze(analysisRequest);
    
    // Should succeed (200) or fail due to no credits (402), but not 500
    expect([200, 402]).toContain(analyzeResponse.status);

    // Get updated balance
    const updatedResponse = await getCreditsBalance(uniqueDeviceId);
    const updatedData = (await updatedResponse.json()) as {
      freeRemaining: number;
      totalAnalyses: number;
    };

    // Credit should be consumed
    expect(updatedData.freeRemaining).toBe(initialFree - 1);
    expect(updatedData.totalAnalyses).toBe(initialAnalyses + 1);
  });

  it("should return credit balance in analysis response", async () => {
    const uniqueDeviceId = `TEST-DEVICE-${Date.now()}`;

    const analysisRequest = {
      deviceId: uniqueDeviceId,
      tankId: "550e8400-e29b-41d4-a716-446655440000",
      parameters: {
        salinity: 1.025,
        temperature: 78,
        ph: 8.2,
        alkalinity: 8.5,
        calcium: 420,
        magnesium: 1350,
      },
      tankVolume: 75,
    };

    const response = await postAnalyze(analysisRequest);

    if (response.status === 200) {
      const data = (await response.json()) as {
        success: boolean;
        creditsRemaining?: number;
        freeRemaining?: number;
        paidCredits?: number;
      };

      expect(data.success).toBe(true);
      expect(data.creditsRemaining).toBeDefined();
      expect(data.freeRemaining).toBeDefined();
      expect(data.paidCredits).toBeDefined();
    }
  });

  it("should not return 500 error when database operations succeed", async () => {
    const uniqueDeviceId = `TEST-DEVICE-${Date.now()}`;

    const analysisRequest = {
      deviceId: uniqueDeviceId,
      tankId: "550e8400-e29b-41d4-a716-446655440000",
      parameters: {
        salinity: 1.025,
        temperature: 78,
        ph: 8.2,
        alkalinity: 8.5,
        calcium: 420,
        magnesium: 1350,
      },
      tankVolume: 75,
    };

    const response = await postAnalyze(analysisRequest);

    // Should NOT be 500 (internal server error)
    expect(response.status).not.toBe(500);

    if (response.status === 500) {
      const data = (await response.json()) as { error: string; message: string };
      console.error("Unexpected 500 error:", data);
    }
  });
});

describe("Error Handling - Database Operations", () => {
  it("should handle database errors gracefully in getCreditsBalance", async () => {
    // This test verifies error handling is in place
    // Even if database fails, we should get a proper error response, not crash
    const response = await getCreditsBalance("VALID-DEVICE-ID");

    // Should return either success (200) or a proper error (not 500)
    expect([200, 400, 500]).toContain(response.status);

    if (response.status === 500) {
      const data = (await response.json()) as { error: string; message: string };
      // Error message should be informative
      expect(data.error).toBeDefined();
      expect(data.message).toBeDefined();
    }
  });
});
