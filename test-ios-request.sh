#!/bin/bash
# Test script that mimics exactly what the iOS app sends

JWS="eyJ4NWMiOlsiTUlJQnl6Q0NBWEdnQXdJQkFnSUJBVEFLQmdncWhrak9QUVFEQWpCSU1TSXdJQVlEVlFRREV4bFRkRzl5WlV0cGRDQlVaWE4wYVc1bklHbHVJRmhqYjJSbE1TSXdJQVlEVlFRS0V4bFRkRzl5WlV0cGRDQlVaWE4wYVc1bklHbHVJRmhqYjJSbE1CNFhEVEkyTURFeE56SXlNREl4TkZvWERUSTNNREV4TnpJeU1ESXhORm93U0RFaU1DQUdBMVVFQXhNWlUzUnZjbVZMYVhRZ1ZHVnpkR2x1WnlCcGJpQllZMjlrWlRFaU1DQUdBMVVFQ2hNWlUzUnZjbVZMYVhRZ1ZHVnpkR2x1WnlCcGJpQllZMjlrWlRCWk1CTUdCeXFHU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkcyRE16ZUJKb3pJVXpVekFqZnhIaXQySExcL3FybjlvXC9kN2lcL1NmTjNRYTNMK2tSV3RXY2xRWXhPbkREbEZjc2xJSThKaDgzdEJTRVBCTjlOb3dxanphalREQktNQklHQTFVZEV3RUJcL3dRSU1BWUJBZjhDQVFBd0pBWURWUjBSQkIwd0c0RVpVM1J2Y21WTGFYUWdWR1Z6ZEdsdVp5QnBiaUJZWTI5a1pUQU9CZ05WSFE4QkFmOEVCQU1DQjRBd0NnWUlLb1pJemowRUF3SURTQUF3UlFJaEFQdmM3SFZIMDJoQklVdjV6QWZqXC9ERGViTE0rZ2FLeVdhUGtFSm5mc0hHUUFpQkhvNW9naVh0QnRoT0UwRXFDQ3htQk5JeEtINE91TnhOREpZMVhMYUIwdEE9PSJdLCJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IkFwcGxlX1hjb2RlX0tleSJ9.eyJwcm9kdWN0SWQiOiJjb20ucmVlZmJ1ZGR5LmNyZWRpdHM1IiwiZGV2aWNlVmVyaWZpY2F0aW9uTm9uY2UiOiJiYWQ4ODFjNy0zOTVmLTQ4ZDMtYWVjMy1lODBlMDllYTFiNTciLCJ0eXBlIjoiQ29uc3VtYWJsZSIsInB1cmNoYXNlRGF0ZSI6MTc2ODY4OTI0MDQwNywicXVhbnRpdHkiOjEsInNpZ25lZERhdGUiOjE3Njg2ODkyNDA0MDgsIm9yaWdpbmFsUHVyY2hhc2VEYXRlIjoxNzY4Njg5MjQwNDA3LCJwcmljZSI6MCwiZW52aXJvbm1lbnQiOiJYY29kZSIsInRyYW5zYWN0aW9uUmVhc29uIjoiUFVSQ0hBU0UiLCJzdG9yZWZyb250SWQiOiIxNDM0NDEiLCJvcmlnaW5hbFRyYW5zYWN0aW9uSWQiOiIwIiwidHJhbnNhY3Rpb25JZCI6IjAiLCJkZXZpY2VWZXJpZmljYXRpb24iOiIwd3VHdmpGU2RHQ3d4N3VGd2Vja3ptYUpvZ0hcL2hKMUpHWlluVkhVS3FUXC9sdWVmNzVRYmI2MTFzUnIySGMzQ2wiLCJidW5kbGVJZCI6ImF1LmNvbS5hZXRoZXJzLnJlZWZidWRkeSIsImN1cnJlbmN5IjoiVVNEIiwiYXBwVHJhbnNhY3Rpb25JZCI6IjAiLCJpbkFwcE93bmVyc2hpcFR5cGUiOiJQVVJDSEFTRUQiLCJzdG9yZWZyb250IjoiVVNBIn0.w_B6f2TPbXL2rWxUt2awfhI3Ylr-esaajKipIRwpqFnFOhfVGf3Mg-nhRpaUsf-bVklE1Mg3YLBHX5S91BmPTg"

BASE_URL="${1:-https://reefbuddy.fredylg.workers.dev}"

echo "🧪 Testing iOS-style request"
echo "============================"
echo ""

# This mimics exactly what the iOS app sends
REQUEST_BODY=$(cat <<EOF
{
  "deviceId": "test-device-ios",
  "jwsRepresentation": "$JWS",
  "transactionId": "12AAA953-EC36-4E9E-A950-B6396D8384AC",
  "originalTransactionId": "0",
  "productId": "com.reefbuddy.credits5"
}
EOF
)

echo "📤 Sending iOS-style request..."
echo "Request body:"
echo "$REQUEST_BODY"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "User-Agent: ReefBuddy/1.0 (iOS)" \
  -d "$REQUEST_BODY" \
  "${BASE_URL}/credits/purchase")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

echo "📥 Response Status: $HTTP_STATUS"
echo "📥 Response Body:"
echo "$BODY"
echo ""

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ SUCCESS: Purchase completed!"
elif [ "$HTTP_STATUS" = "400" ]; then
    echo "❌ FAILED: Bad Request - check response for details"
elif [ "$HTTP_STATUS" = "409" ]; then
    echo "⚠️ DUPLICATE: Transaction already processed"
else
    echo "❓ UNEXPECTED: Status $HTTP_STATUS"
fi