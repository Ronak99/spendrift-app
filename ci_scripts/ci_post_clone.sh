#!/bin/sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/Spendrift/Configuration"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/ProdSecrets.xcconfig" <<EOF
SPENDRIFT_BACKEND_BASE_URL = $SPENDRIFT_BACKEND_BASE_URL
SPENDRIFT_BACKEND_CLIENT_TOKEN = $SPENDRIFT_BACKEND_CLIENT_TOKEN
EOF

echo "Secrets xcconfig files generated"