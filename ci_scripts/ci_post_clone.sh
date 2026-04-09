#!/bin/sh
set -e

CONFIG_DIR="$CI_WORKSPACE/Spendrift/Configuration"

cat > "$CONFIG_DIR/DevSecrets.xcconfig" <<EOF
OPENAI_API_KEY = $OPENAI_API_KEY_DEV
EOF

cat > "$CONFIG_DIR/ProdSecrets.xcconfig" <<EOF
OPENAI_API_KEY = $OPENAI_API_KEY_PROD
EOF

echo "✓ Secrets xcconfig files generated"
