#!/bin/sh
set -e

if [ "$CI_XCODEBUILD_ACTION" != "archive" ]; then
  echo "Skipping Sentry dSYM upload for non-archive build"
  exit 0
fi

if [ -z "$SENTRY_AUTH_TOKEN" ] || [ -z "$SPENDRIFT_SENTRY_DSN" ]; then
  echo "Sentry dSYM upload skipped: SENTRY_AUTH_TOKEN or SPENDRIFT_SENTRY_DSN not set"
  exit 0
fi

if [ -z "$CI_ARCHIVE_PATH" ]; then
  echo "Sentry dSYM upload skipped: CI_ARCHIVE_PATH not set"
  exit 0
fi

if ! command -v sentry-cli >/dev/null 2>&1; then
  curl -sL https://sentry.io/get-cli/ | bash
fi

SENTRY_ORG="${SENTRY_ORG:-}"
SENTRY_PROJECT="${SENTRY_PROJECT:-}"

if [ -z "$SENTRY_ORG" ] || [ -z "$SENTRY_PROJECT" ]; then
  echo "Sentry dSYM upload skipped: SENTRY_ORG or SENTRY_PROJECT not set"
  exit 0
fi

export SENTRY_AUTH_TOKEN
export SENTRY_ORG
export SENTRY_PROJECT

DSYM_PATH="$CI_ARCHIVE_PATH/dSYMs"
if [ ! -d "$DSYM_PATH" ]; then
  echo "Sentry dSYM upload skipped: no dSYMs at $DSYM_PATH"
  exit 0
fi

echo "Uploading dSYMs from $DSYM_PATH to Sentry ($SENTRY_ORG/$SENTRY_PROJECT)"
sentry-cli debug-files upload --include-sources "$DSYM_PATH"
