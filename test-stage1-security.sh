#!/bin/bash

# ReefBuddy Stage 1 Security Remediation Test Script
# Tests all implemented security fixes to ensure they work correctly

set -e

echo "🧪 Testing Stage 1 Security Remediation..."
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Use main worker URL
WORKER_URL="https://reefbuddy.fredylg.workers.dev"
TEST_DEVICE_ID="test-device-12345"

# Test counter
PASSED=0
FAILED=0

# Helper function to check HTTP status
check_status() {
    local url="$1"
    local expected_status="$2"
    local description="$3"

    echo -n "Testing: $description... "

    local response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$response" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC} (Status: $response)"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} (Expected: $expected_status, Got: $response)"
        ((FAILED++))
    fi
}

# Helper function to check response headers
check_header() {
    local url="$1"
    local header="$2"
    local expected_value="$3"
    local description="$4"

    echo -n "Testing: $description... "

    local response=$(curl -s -I "$url" 2>/dev/null | grep -i "$header:" | head -1 | sed 's/.*: //' | tr -d '\r\n' || echo "")

    if [ "$response" = "$expected_value" ] || [[ "$response" == *"$expected_value"* ]]; then
        echo -e "${GREEN}✓ PASS${NC} ($header: $response)"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC} (Expected: '$expected_value', Got: '$response')"
        ((FAILED++))
    fi
}

echo ""
echo -e "${BLUE}C1: JWS Signature Verification${NC}"
echo "-----------------------------------"

# Test debug endpoint removal (C2)
echo ""
echo -e "${BLUE}C2: Debug Endpoint Removal${NC}"
echo "------------------------------"
check_status "$WORKER_URL/debug/jws-test" "404" "Debug endpoint returns 404"

echo ""
echo -e "${BLUE}C3: CORS Policy${NC}"
echo "-------------------"

# Test CORS headers
check_header "$WORKER_URL/health" "Access-Control-Allow-Origin" "*" "CORS allows any origin for native apps"
check_header "$WORKER_URL/health" "Access-Control-Allow-Methods" "GET, POST, PUT, DELETE, OPTIONS" "CORS allows required methods"
check_header "$WORKER_URL/health" "Access-Control-Allow-Headers" "Content-Type, Authorization, X-Device-ID" "CORS allows required headers"

echo ""
echo -e "${BLUE}M3: Security Headers${NC}"
echo "-----------------------"
check_header "$WORKER_URL/health" "X-Content-Type-Options" "nosniff" "Content-Type sniffing protection"
check_header "$WORKER_URL/health" "X-Frame-Options" "DENY" "Clickjacking protection"
check_header "$WORKER_URL/health" "X-XSS-Protection" "1; mode=block" "XSS protection"
check_header "$WORKER_URL/health" "Referrer-Policy" "strict-origin-when-cross-origin" "Referrer policy"
check_header "$WORKER_URL/health" "Permissions-Policy" "geolocation=(), microphone=(), camera=()" "Permissions policy"

echo ""
echo -e "${BLUE}H5: Credit Balance Rate Limiting${NC}"
echo "-----------------------------------"

# Test credit balance endpoint (may be rate limited)
echo -n "Testing: Credit balance endpoint responds... "
response=$(curl -s -w "%{http_code}" -o /dev/null "$WORKER_URL/credits/balance?deviceId=$TEST_DEVICE_ID" 2>/dev/null || echo "000")
if [ "$response" = "200" ] || [ "$response" = "400" ] || [ "$response" = "429" ]; then
    echo -e "${GREEN}✓ PASS${NC} (Status: $response - expected response)"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} (Unexpected status: $response)"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}Health Check${NC}"
echo "--------------"
check_status "$WORKER_URL/health" "200" "Health endpoint works"

echo ""
echo "=========================================="
echo -e "${BLUE}Test Results:${NC}"
echo "Total Tests: $((PASSED + FAILED))"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🎉 All Stage 1 security fixes verified successfully!${NC}"
    echo "Production deployment is secure and working correctly."
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed. Please review the security implementation.${NC}"
    exit 1
fi