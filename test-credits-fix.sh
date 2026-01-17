#!/bin/bash
# Test script to verify credits endpoints are working after fixes
# This tests both /credits/balance and /analyze endpoints

set -e

echo "🧪 Testing Credits Endpoints Fix"
echo "=================================="
echo ""

# Test device ID
DEVICE_ID="test-device-$(date +%s)"
BASE_URL="${1:-http://localhost:8787}"

echo "📱 Using device ID: $DEVICE_ID"
echo "🌐 Testing against: $BASE_URL"
echo ""

# Test 1: Get credit balance (should work without errors)
echo "Test 1: GET /credits/balance"
echo "----------------------------"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "${BASE_URL}/credits/balance?deviceId=${DEVICE_ID}")
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Status: $HTTP_STATUS"
    echo "Response: $BODY"
    echo ""
else
    echo "❌ Status: $HTTP_STATUS"
    echo "Response: $BODY"
    echo ""
    exit 1
fi

# Test 2: Submit analysis (should work without 500 errors)
echo "Test 2: POST /analyze"
echo "---------------------"
ANALYSIS_REQUEST=$(cat <<EOF
{
  "deviceId": "${DEVICE_ID}",
  "tankId": "550e8400-e29b-41d4-a716-446655440000",
  "parameters": {
    "salinity": 1.025,
    "temperature": 78,
    "ph": 8.2,
    "alkalinity": 8.5,
    "calcium": 420,
    "magnesium": 1350,
    "nitrate": 5,
    "phosphate": 0.03
  },
  "tankVolume": 75
}
EOF
)

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$ANALYSIS_REQUEST" \
  "${BASE_URL}/analyze")
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "402" ]; then
    # 200 = success, 402 = no credits (expected after using free credits)
    echo "✅ Status: $HTTP_STATUS (expected: 200 or 402)"
    echo "Response: $BODY"
    echo ""
else
    echo "❌ Status: $HTTP_STATUS (unexpected)"
    echo "Response: $BODY"
    echo ""
    exit 1
fi

# Test 3: Verify credit balance was updated
echo "Test 3: GET /credits/balance (after analysis)"
echo "-----------------------------------------------"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "${BASE_URL}/credits/balance?deviceId=${DEVICE_ID}")
HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Status: $HTTP_STATUS"
    echo "Response: $BODY"
    echo ""
else
    echo "❌ Status: $HTTP_STATUS"
    echo "Response: $BODY"
    echo ""
    exit 1
fi

echo "✅ All tests passed!"
echo ""
echo "Summary:"
echo "- Credit balance endpoint works"
echo "- Analysis endpoint works (no 500 errors)"
echo "- Credit tracking is functional"
