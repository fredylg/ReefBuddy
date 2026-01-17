#!/bin/bash
# Test script to validate JWS from Xcode logs against the debug endpoint
# Usage: ./test-jws-validation.sh "JWS_STRING_FROM_XCODE_LOGS"

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 \"JWS_STRING_FROM_XCODE_LOGS\""
    echo ""
    echo "Example:"
    echo "  $0 \"eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0cmFuc2FjdGlvbklkIjoiQUJDMTIzIiwicHJvZHVjdElkIjoiY29tLnJlZWZidWRkeS5jcmVkaXRzNSIsImJ1bmRsZUlkIjoiYXUuY29tLmFldGhlcnMucmVlZmJ1ZGR5In0.signature\""
    echo ""
    echo "To get the JWS string:"
    echo "1. Run the iOS app and attempt an IAP purchase"
    echo "2. Check Xcode logs for the line: 🔐 JWS Representation: ..."
    echo "3. Copy the JWS string and paste it as the argument"
    exit 1
fi

JWS="$1"
BASE_URL="${2:-https://reefbuddy.fredylg.workers.dev}"

echo "🔍 Testing JWS Validation"
echo "========================="
echo ""
echo "🌐 Testing against: $BASE_URL"
echo "🔐 JWS Length: ${#JWS} characters"
echo ""

# Test the JWS against debug endpoint
echo "Testing JWS parsing and validation..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"jwsRepresentation\": \"$JWS\",
    \"productId\": \"com.reefbuddy.credits5\",
    \"deviceId\": \"test-device-123\"
  }" \
  "${BASE_URL}/debug/jws-test")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "Response Status: $HTTP_STATUS"
echo "Response Body:"
echo "$BODY"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ JWS validation successful!"
    echo ""
    echo "The JWS payload is valid. The issue is likely in the purchase flow logic."
else
    echo "❌ JWS validation failed!"
    echo ""
    echo "Check the response above for the specific validation error."
fi