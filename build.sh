#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export FLUTTER_HOME="${FLUTTER_HOME:-$PWD/.flutter-sdk}"
export PATH="$FLUTTER_HOME/bin:$PATH"

if [ ! -d "$FLUTTER_HOME/bin" ]; then
  echo "Installing Flutter stable channel..."
  rm -rf "$FLUTTER_HOME"
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

flutter --version
flutter config --enable-web
flutter clean
flutter pub get

if [ -n "${SUPABASE_URL:-}" ] || [ -n "${SUPABASE_KEY:-}" ]; then
  printf 'SUPABASE_URL=%s\nSUPABASE_KEY=%s\n' "${SUPABASE_URL:-}" "${SUPABASE_KEY:-}" > .env
fi

flutter build web --release \
  --base-href / \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_KEY="${SUPABASE_KEY:-}"
