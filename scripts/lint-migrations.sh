#!/bin/bash
# Soft-delete guard (review item M-04): hard deletes of user data are not allowed in migrations or
# application code. Allowed: push_tokens (device tokens), and the scratch-table shuffle in 0016.
set -u
cd "$(dirname "$0")/.."
violations=$(grep -rn --include="*.sql" --include="*.ts" "DELETE FROM" migrations src \
  | grep -v "migrations/0016_livestock_enum_extension.sql" \
  | grep -v "DELETE FROM push_tokens" || true)
if [ -n "$violations" ]; then
  echo "❌ Hard DELETE found (soft-delete only, see migrations/README.md):"
  echo "$violations"
  exit 1
fi
echo "✅ lint:migrations — no hard deletes outside the allow-list"
