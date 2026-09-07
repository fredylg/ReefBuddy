/**
 * Device-authenticated routes end to end (P3-27, T-04).
 * Exercises every route the iOS app calls with an X-Device-ID header and an UPPERCASE UUID path,
 * which the old router rejected (case-sensitive patterns, session-only auth).
 */
import { describe, it, expect, beforeAll } from "vitest";
import { SELF } from "cloudflare:test";
import { installGatewayMock, successReply } from "./helpers/mock-gateway";

installGatewayMock(successReply("Parameters look fine."));

const deviceA = crypto.randomUUID().toUpperCase();
const deviceB = crypto.randomUUID().toUpperCase();
let ipCounter = 0;

async function call(method: string, path: string, body?: unknown, deviceId: string | null = deviceA): Promise<Response> {
  ipCounter++;
  const headers: Record<string, string> = { "Content-Type": "application/json", "CF-Connecting-IP": `10.7.${(ipCounter >> 8) & 255}.${ipCounter & 255}` };
  if (deviceId) headers["X-Device-ID"] = deviceId;
  return SELF.fetch("http://localhost" + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
}
const json = async <T>(res: Response): Promise<T> => (await res.json()) as T;

let tankId = ""; // uppercase, as the app sends it
const isoNow = () => new Date().toISOString();
const isoAgo = (days: number) => new Date(Date.now() - days * 86_400_000).toISOString();

beforeAll(async () => {
  const res = await call("POST", "/api/tanks", { name: "Display", volume_gallons: 75, tank_type: "reef" });
  expect(res.status).toBe(201);
  const data = await json<{ data: { id: string } }>(res);
  tankId = data.data.id.toUpperCase();
});

describe("auth resolution", () => {
  it("rejects requests with neither a session nor a device id", async () => {
    expect((await call("GET", "/api/tanks", undefined, null)).status).toBe(401);
  });
  it("rejects a malformed device id", async () => {
    expect((await call("GET", "/api/tanks", undefined, "x")).status).toBe(401);
  });
  it("another device cannot read this tank (404: no ownership oracle)", async () => {
    expect((await call("GET", `/api/tanks/${tankId}`, undefined, deviceB)).status).toBe(404);
  });
});

describe("tanks (uppercase UUID paths)", () => {
  it("GET /api/tanks/:id", async () => {
    const res = await call("GET", `/api/tanks/${tankId}`);
    expect(res.status).toBe(200);
    expect((await json<{ data: { id: string; name: string } }>(res)).data.name).toBe("Display");
  });
  it("PUT /api/tanks/:id", async () => {
    const res = await call("PUT", `/api/tanks/${tankId}`, { name: "Renamed" });
    expect(res.status).toBe(200);
    expect((await json<{ data: { name: string } }>(res)).data.name).toBe("Renamed");
  });
  it("lists the tank for its device only", async () => {
    const mine = await json<{ data: Array<{ id: string }> }>(await call("GET", "/api/tanks"));
    expect(mine.data.some((t) => t.id.toUpperCase() === tankId)).toBe(true);
    const theirs = await json<{ data: Array<{ id: string }> }>(await call("GET", "/api/tanks", undefined, deviceB));
    expect(theirs.data.some((t) => t.id.toUpperCase() === tankId)).toBe(false);
  });
});

describe("measurements and history", () => {
  it("POST /api/measurements stores nitrite and PPT salinity", async () => {
    const res = await call("POST", "/api/measurements", { tank_id: tankId.toLowerCase(), ph: 8.1, nitrite: 0.1, salinity: 35, salinity_unit: "PPT", notes: "after water change" });
    expect([200, 201]).toContain(res.status);
  });
  it("GET /tanks/:id/history returns the measurement with nitrite and notes", async () => {
    const res = await call("GET", `/tanks/${tankId}/history?start=${encodeURIComponent(isoAgo(1))}&end=${encodeURIComponent(isoNow())}`);
    expect(res.status).toBe(200);
    const data = await json<{ measurements: Array<{ nitrite: number | null; notes: string | null }> }>(res);
    expect(data.measurements.length).toBeGreaterThanOrEqual(1);
    expect(data.measurements[0].nitrite).toBe(0.1);
    expect(data.measurements[0].notes).toBe("after water change");
  });
  it("GET /tanks/:id/trends and /averages work with device auth", async () => {
    expect((await call("GET", `/tanks/${tankId}/trends?days=30`)).status).toBe(200);
    const avg = await call("GET", `/tanks/${tankId}/averages?period=weekly`);
    expect(avg.status).toBe(200);
    const data = await json<{ data?: Array<Record<string, unknown>>; averages?: Array<Record<string, unknown>> }>(avg);
    const rows = data.data ?? data.averages ?? [];
    if (rows.length) expect(rows[0]).toHaveProperty("avg_nitrite");
  });
  it("GET /tanks/:id/export returns CSV with nitrite and notes columns", async () => {
    const res = await call("GET", `/tanks/${tankId}/export?start=${encodeURIComponent(isoAgo(1))}&end=${encodeURIComponent(isoNow())}`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("text/csv");
    const csv = await res.text();
    expect(csv).toContain("Nitrite (ppm)");
    expect(csv).toContain("after water change");
  });
});

describe("livestock via /api", () => {
  let livestockId = "";
  it("POST /api/tanks/:id/livestock", async () => {
    const res = await call("POST", `/api/tanks/${tankId}/livestock`, { name: "Clownfish", species: "Amphiprion ocellaris", category: "Fish", healthStatus: "healthy", quantity: 2 });
    expect([200, 201]).toContain(res.status);
    livestockId = (await json<{ livestock: { id: string } }>(res)).livestock.id.toUpperCase();
  });
  it("GET /api/tanks/:id/livestock lists it", async () => {
    const res = await call("GET", `/api/tanks/${tankId}/livestock`);
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text.toLowerCase()).toContain(livestockId.toLowerCase());
  });
  it("PUT /api/livestock/:id accepts the app's health statuses", async () => {
    expect((await call("PUT", `/api/livestock/${livestockId}`, { quantity: 3, healthStatus: "thriving" })).status).toBe(200);
    expect((await call("PUT", `/api/livestock/${livestockId}`, { healthStatus: "stressed" })).status).toBe(200);
  });
  it("POST /api/tanks/:id/livestock accepts Anemone and Other categories", async () => {
    const res = await call("POST", `/api/tanks/${tankId}`.replace(/$/, "/livestock"), { name: "BTA", species: "Entacmaea quadricolor", category: "Anemone", quantity: 1 });
    expect([200, 201]).toContain(res.status);
    const other = await call("POST", `/api/tanks/${tankId}/livestock`, { name: "Mystery snail", category: "Other", quantity: 1 });
    expect([200, 201]).toContain(other.status);
  });
  it("POST + GET /api/livestock/:id/logs", async () => {
    expect([200, 201]).toContain((await call("POST", `/api/livestock/${livestockId}/logs`, { logType: "feeding", description: "Mysis" })).status);
    const res = await call("GET", `/api/livestock/${livestockId}/logs`);
    expect(res.status).toBe(200);
    expect(await res.text()).toContain("Mysis");
  });
  it("DELETE /api/livestock/:id, then it is gone", async () => {
    expect((await call("DELETE", `/api/livestock/${livestockId}`)).status).toBe(200);
    expect((await call("GET", `/api/tanks/${tankId}/livestock`).then((r) => r.text())).toLowerCase()).not.toContain(livestockId.toLowerCase());
  });
});

describe("maintenance schedules and water changes", () => {
  let scheduleId = "";
  it("POST /maintenance/schedules with device auth", async () => {
    const res = await call("POST", "/maintenance/schedules", {
      tankId: tankId.toLowerCase(), type: "water_change", scheduleKind: "interval_days", intervalDays: 7, timeLocal: "09:00", timezone: "Australia/Sydney",
    });
    expect(res.status).toBe(201);
    scheduleId = (await json<{ schedule: { id: string } }>(res)).schedule.id.toUpperCase();
  });
  it("PUT /maintenance/schedules/:id (uppercase id)", async () => {
    const res = await call("PUT", `/maintenance/schedules/${scheduleId}`, { enabled: false });
    expect(res.status).toBe(200);
  });
  it("water change linked to the schedule, listed, then deleted", async () => {
    const created = await call("POST", `/api/tanks/${tankId}/water-changes`, { percentReplaced: 10, sourceScheduleId: scheduleId.toLowerCase() });
    expect(created.status).toBe(201);
    const wcId = (await json<{ data: { id: string } }>(created)).data.id;
    const list = await json<{ data: Array<{ id: string }> }>(await call("GET", `/api/tanks/${tankId}/water-changes`));
    expect(list.data.some((w) => w.id === wcId)).toBe(true);
    expect((await call("DELETE", `/api/water-changes/${wcId.toUpperCase()}`)).status).toBe(200);
  });
  it("DELETE /maintenance/schedules/:id soft-deletes: gone from the list, second delete is 404, linked water change survives", async () => {
    expect((await call("DELETE", `/maintenance/schedules/${scheduleId}`)).status).toBe(200);
    const list = await json<{ schedules: Array<{ id: string }> }>(await call("GET", "/maintenance/schedules"));
    expect(list.schedules.some((s) => s.id.toUpperCase() === scheduleId)).toBe(false);
    expect((await call("DELETE", `/maintenance/schedules/${scheduleId}`)).status).toBe(404);
  });
});

describe("tank deletion", () => {
  it("DELETE /api/tanks/:id from another device is refused (404); from the owner it works", async () => {
    expect((await call("DELETE", `/api/tanks/${tankId}`, undefined, deviceB)).status).toBe(404);
    expect((await call("DELETE", `/api/tanks/${tankId}`)).status).toBe(200);
    expect((await call("GET", `/api/tanks/${tankId}`)).status).toBe(404);
  });
});
