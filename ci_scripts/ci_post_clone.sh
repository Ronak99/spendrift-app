#!/bin/sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/Spendrift/Configuration"
mkdir -p "$CONFIG_DIR"

# *.xcconfig is gitignored, so this file is the ONLY source of Release build
# settings on Xcode Cloud. Every SPENDRIFT_* key referenced by Spendrift/Info.plist
# must be written here — a missing key silently resolves to an empty string and the
# matching feature no-ops in TestFlight while still working from a local checkout.
cat > "$CONFIG_DIR/ProdSecrets.xcconfig" <<EOF
SPENDRIFT_BACKEND_BASE_URL = $SPENDRIFT_BACKEND_BASE_URL
SPENDRIFT_BACKEND_CLIENT_TOKEN = $SPENDRIFT_BACKEND_CLIENT_TOKEN
SPENDRIFT_POSTHOG_API_KEY = $SPENDRIFT_POSTHOG_API_KEY
SPENDRIFT_SENTRY_DSN = $SPENDRIFT_SENTRY_DSN
SPENDRIFT_ONESIGNAL_APP_ID = $SPENDRIFT_ONESIGNAL_APP_ID
EOF

MISSING=""
for KEY in SPENDRIFT_BACKEND_BASE_URL SPENDRIFT_BACKEND_CLIENT_TOKEN \
           SPENDRIFT_POSTHOG_API_KEY SPENDRIFT_SENTRY_DSN SPENDRIFT_ONESIGNAL_APP_ID; do
  eval "VALUE=\$$KEY"
  if [ -z "$VALUE" ]; then
    MISSING="$MISSING $KEY"
  fi
done

if [ -n "$MISSING" ]; then
  echo "error: missing Xcode Cloud environment variables:$MISSING" >&2
  echo "error: add them under the workflow's Environment settings before archiving." >&2
  exit 1
fi

echo "Secrets xcconfig files generated"
