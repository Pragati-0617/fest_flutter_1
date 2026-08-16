#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export FLUTTER_VERSION="${FLUTTER_VERSION:-3.12.2}"
export FLUTTER_HOME="${FLUTTER_HOME:-$PWD/.flutter-sdk}"
export PATH="$FLUTTER_HOME/bin:$PATH"

if [ ! -d "$FLUTTER_HOME/bin" ]; then
  echo "Installing Flutter ${FLUTTER_VERSION}..."
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.tar.xz
  rm -rf "$FLUTTER_HOME"
  mkdir -p "$FLUTTER_HOME"
  tar -xf /tmp/flutter.tar.xz -C /tmp
  mv /tmp/flutter "$FLUTTER_HOME"
fi

flutter --version
flutter config --enable-web
flutter clean
flutter pub get

if [ -n "${SUPABASE_URL:-}" ] || [ -n "${SUPABASE_KEY:-}" ]; then
  printf 'SUPABASE_URL=%s\nSUPABASE_KEY=%s\n' "${SUPABASE_URL:-}" "${SUPABASE_KEY:-}" > .env
fi

flutter build web --release --base-href /
