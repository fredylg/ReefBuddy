# ReefBuddy Test Suite

**Owner:** @tester-agent (Quality Assurance Lead)

This directory contains all automated tests for the ReefBuddy backend API.

## Test Structure

```
tests/
  api.test.ts       # API endpoint tests (measurements, validation, limits)
  README.md         # This file
```

## Running Tests

### Run All Tests
```bash
npm test
```

### Run Tests in Watch Mode (Development)
```bash
npm run test:watch
```

### Run Tests with Coverage
```bash
npx vitest run --coverage
```

## Test Categories

### 1. POST /measurements Tests
- **Input Validation:** Validates Zod schema enforcement for measurement data
- **Response Format:** Verifies correct HTTP status codes and JSON responses
- **Database Persistence:** Confirms data is stored correctly in D1

### 2. Free Tier Limit Tests
- **Usage Tracking:** Validates KV-based measurement counting
- **Limit Enforcement:** Confirms 3/month limit for free users
- **Premium Bypass:** Verifies unlimited access for subscribers

### 3. Security Tests
- **Rate Limiting:** IP-based request throttling
- **Input Sanitization:** SQL injection and XSS prevention

## Test Configuration

Tests are configured in `vitest.config.ts` at the project root.

### Key Settings:
- **Pool:** `@cloudflare/vitest-pool-workers` for Workers environment
- **Bindings:** Miniflare provides mock D1 and KV namespaces
- **Environment Variables:** Test-specific values are injected

## Writing New Tests

### Test File Naming
All test files should end with `.test.ts`:
```
tests/feature-name.test.ts
```

### Test Structure Template
```typescript
import { describe, it, expect } from "vitest";

describe("Feature Name", () => {
  describe("Sub-feature", () => {
    it("should do something specific", async () => {
      // Arrange
      const input = { /* test data */ };

      // Act
      const result = await someFunction(input);

      // Assert
      expect(result).toBeDefined();
    });
  });
});
```

### Using Placeholder Tests
When the implementation is not yet ready, use `it.todo()`:
```typescript
it.todo("should implement this feature");
```

## Definition of Done

Per CLAUDE.md, a task is not complete until:
1. Developer implements the feature
2. **@tester-agent** creates and runs automated tests
3. **@tester-agent** confirms success (or reverts to "In Progress" with error logs)

## Environment Variables

Tests use the following environment bindings:
- `DB` - D1 database (mocked via miniflare)
- `REEF_KV` - KV namespace for session/limit tracking
- `FREE_TIER_LIMIT` - Set to "3" for testing
- `ENVIRONMENT` - Set to "test"

## Troubleshooting

### Tests fail with "Cannot find module"
Run `npm install` to ensure all dependencies are installed.

### D1/KV binding errors
Verify `vitest.config.ts` has correct miniflare bindings configured.

### Timeout errors
Workers tests may need longer timeouts. Add to specific tests:
```typescript
it("slow test", async () => {
  // ...
}, 10000); // 10 second timeout
```
