#!/bin/bash
# Count rows in each database table

echo "=== Database Table Counts ==="
echo ""

echo "users:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM users;" | grep -A 1 '"count"'

echo "tanks:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM tanks;" | grep -A 1 '"count"'

echo "livestock:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM livestock;" | grep -A 1 '"count"'

echo "livestock_logs:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM livestock_logs;" | grep -A 1 '"count"'

echo "measurements:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM measurements;" | grep -A 1 '"count"'

echo "device_credits:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM device_credits;" | grep -A 1 '"count"'

echo "purchase_history:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM purchase_history;" | grep -A 1 '"count"'

echo "push_tokens:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM push_tokens;" | grep -A 1 '"count"'

echo "notification_settings:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM notification_settings;" | grep -A 1 '"count"'

echo "notification_history:"
npx wrangler d1 execute reef-db --local --command "SELECT COUNT(*) as count FROM notification_history;" | grep -A 1 '"count"'

echo ""
echo "=== Done ==="
