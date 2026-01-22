# AI Gateway Authentication Setup Guide

This guide walks you through enabling authentication for your Cloudflare AI Gateway to secure access and remove the "authentication disabled" warning.

## Why Enable Authentication?

- **Security**: Prevents unauthorized access to your AI Gateway
- **Log Protection**: Prevents log inflation from unauthorized requests
- **Best Practice**: Recommended by Cloudflare, especially when storing logs

## Prerequisites

- Cloudflare account with AI Gateway access
- Access to Cloudflare Dashboard
- Wrangler CLI installed and authenticated

## Step 1: Enable Authentication in Cloudflare Dashboard

1. **Navigate to AI Gateway**
   - Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
   - Navigate to **AI Gateway** → **Your Gateway** (`reefbuddy-ai-gateway`)

2. **Create Authentication Token**
   - Click on **Settings** for your gateway
   - Find the **Authentication** section
   - Click **Create authentication token**
   - Ensure the token has **"AI Gateway: Run"** permissions
   - **IMPORTANT**: Copy and save the token immediately - it won't be shown again!

3. **Enable Authenticated Gateway**
   - Toggle **"Authenticated Gateway"** to **ON**
   - The warning about authentication being disabled should disappear

## Step 2: Set the Token as a Worker Secret

1. **Set the secret** (replace `YOUR_TOKEN` with the token from Step 1):
   ```bash
   npx wrangler secret put CF_AI_GATEWAY_TOKEN
   ```
   - When prompted, paste your token and press Enter
   - The token will be securely encrypted and stored

2. **Verify the secret is set**:
   ```bash
   npx wrangler secret list
   ```
   - Should show `CF_AI_GATEWAY_TOKEN` in the list

3. **Deploy the worker** (if not already deployed):
   ```bash
   npx wrangler deploy
   ```

## Step 3: Verify Configuration

1. **Test the endpoint**:
   ```bash
   curl -X POST https://reefbuddy.fredylg.workers.dev/analyze \
     -H "Content-Type: application/json" \
     -d '{"deviceId":"test-device","tankId":"550e8400-e29b-41d4-a716-446655440000","parameters":{"ph":8.1},"tankVolume":55}'
   ```

2. **Check Cloudflare logs**:
   - Go to Workers & Pages → Monitoring → Logs
   - Look for successful AI Gateway requests (no 401 errors)
   - The 🔐 DEBUG messages should show `hasGatewayToken: true`

3. **Verify in AI Gateway Dashboard**:
   - The "authentication disabled" warning should be gone
   - Requests should show as authenticated

## Troubleshooting

### 401 Unauthorized Errors

**Symptom**: AI Gateway returns `401 - Unauthorized` with error code 2009

**Possible Causes**:
1. **Token not set**: Run `npx wrangler secret list` to verify
2. **Token invalid**: Regenerate token in Cloudflare Dashboard
3. **Token permissions wrong**: Ensure token has "AI Gateway: Run" permission
4. **Authentication not enabled**: Check that "Authenticated Gateway" toggle is ON

**Solution**:
```bash
# Delete old token
npx wrangler secret delete CF_AI_GATEWAY_TOKEN

# Regenerate token in Cloudflare Dashboard, then set new one
npx wrangler secret put CF_AI_GATEWAY_TOKEN

# Redeploy
npx wrangler deploy
```

### Token Format Issues

**Valid token format**: Should start with `CGAI...` (Cloudflare AI Gateway format)

**If token doesn't start with CGAI**:
- You may have copied the wrong value
- Regenerate the token in Cloudflare Dashboard
- Make sure you're copying the authentication token, not the API key

### Authentication Still Disabled Warning

**If warning persists after setup**:
1. Verify "Authenticated Gateway" is toggled ON in dashboard
2. Wait a few minutes for changes to propagate
3. Refresh the dashboard page
4. Check that the token has correct permissions

## Rollback Instructions

If you need to disable authentication temporarily:

1. **In Cloudflare Dashboard**:
   - Go to AI Gateway → Settings
   - Toggle **"Authenticated Gateway"** to **OFF**

2. **Remove the secret** (optional - worker will work without it):
   ```bash
   npx wrangler secret delete CF_AI_GATEWAY_TOKEN
   ```

3. **Redeploy**:
   ```bash
   npx wrangler deploy
   ```

**Note**: The code is backward compatible - it will work with or without the token. If authentication is disabled in the dashboard, requests will work without the header.

## Security Best Practices

1. **Never commit tokens**: Tokens are stored as secrets, never in code
2. **Rotate tokens regularly**: Regenerate tokens periodically for security
3. **Use least privilege**: Only grant "AI Gateway: Run" permission
4. **Monitor usage**: Check AI Gateway logs for suspicious activity

## Support

If you continue to experience issues:
- Check Cloudflare AI Gateway documentation: https://developers.cloudflare.com/ai-gateway/
- Review Cloudflare Worker logs for detailed error messages
- Verify all prerequisites are met
