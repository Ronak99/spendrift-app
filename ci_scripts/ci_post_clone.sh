#!/bin/sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/Spendrift/Configuration"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/DevSecrets.xcconfig" <<EOF
OPENAI_API_KEY = $OPENAI_API_KEY_DEV
EOF

cat > "$CONFIG_DIR/ProdSecrets.xcconfig" <<EOF
OPENAI_API_KEY = $OPENAI_API_KEY_PROD
EOF

echo "Secrets xcconfig files generated"