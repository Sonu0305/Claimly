#!/usr/bin/env bash
# ==============================================================================
# Claimly Vercel Remote Build Script
# Automates Flutter SDK provisioning and Flutter Web release compilation
# on Vercel's Amazon Linux / Ubuntu serverless build containers.
# ==============================================================================
set -euo pipefail

echo "============================================================"
echo " Claimly — Vercel CI/CD Build Engine"
echo "============================================================"

# 1. Determine or provision Flutter SDK
FLUTTER_DIR="${HOME}/flutter"
FLUTTER_VERSION="3.38.9"

if command -v flutter &>/dev/null; then
  echo "✓ Found system Flutter SDK in PATH: $(which flutter)"
elif [ -d "$FLUTTER_DIR/bin" ]; then
  echo "✓ Found cached Flutter SDK in $FLUTTER_DIR"
  export PATH="$FLUTTER_DIR/bin:$PATH"
else
  echo "==> Downloading Flutter SDK v${FLUTTER_VERSION}..."
  git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  export PATH="$FLUTTER_DIR/bin:$PATH"
fi

echo "==> Verifying Flutter environment..."
flutter --version

flutter config --no-analytics
flutter config --enable-web

# 2. Get dependencies
echo "==> Fetching Flutter dependencies..."
flutter pub get

# 3. Compile Flutter Web release with Supabase environment variables injected
SUPABASE_URL="${SUPABASE_URL:-https://kvxfkfgzsapvvswjcmzj.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2eGZrZmd6c2FwdnZzd2pjbXpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ0MTA0MjIsImV4cCI6MjEwOTk4NjQyMn0.aONMvkR-_3u5XP8OaJJgpaihqjrwPGqcfy9ibOJbd7o}"

echo "==> Compiling Web Release bundle..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "============================================================"
echo "✓ Claimly Web Build Successful! (Artifacts in build/web)"
echo "============================================================"
