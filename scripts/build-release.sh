#!/usr/bin/env bash
#
# Builds a distributable release artifact.
#
#   ./scripts/build-release.sh              # APK, for a tester or Firebase
#   ./scripts/build-release.sh --aab        # App Bundle, for Play
#   ./scripts/build-release.sh --skip-checks
#   ./scripts/build-release.sh --no-bump    # rebuild without a new versionCode
#
# Swaps in .env.prod, bumps the versionCode, builds, and puts .env.dev back —
# including if the build fails, so you never end up developing against the
# production config by accident.

set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_AAB=false
SKIP_CHECKS=false
BUMP=true
for arg in "$@"; do
  case "$arg" in
    --aab)         BUILD_AAB=true ;;
    --skip-checks) SKIP_CHECKS=true ;;
    --no-bump)     BUMP=false ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "" >&2; echo "ERROR: $*" >&2; exit 1; }

# ── preflight ───────────────────────────────────────────────────────────────
# These two checks exist because both failures are silent: you get a working
# APK that is quietly wrong, and only find out when it reaches a device.

[ -f android/key.properties ] || die \
  "android/key.properties is missing, so this would be signed with the DEBUG
  key. A tester could not then install any future update without uninstalling
  first. Copy android/key.properties.example and fill it in."

[ -f .env.prod ] || die ".env.prod is missing. Copy .env.example and fill it in."

rc_key="$(grep -E '^REVENUECAT_ANDROID_API_KEY=' .env.prod | cut -d= -f2- || true)"
case "$rc_key" in
  test_*) die "\
  .env.prod holds a RevenueCat Test Store key. That key bypasses the real
  stores, so shipping it lets anyone mint credits for free. Use the goog_ key." ;;
  "")     echo "NOTE: no RevenueCat key in .env.prod — purchases will be disabled
      in this build. Fine for an early tester build; not for release." ;;
esac

# ── checks ──────────────────────────────────────────────────────────────────

if [ "$SKIP_CHECKS" = false ]; then
  echo "==> flutter analyze"
  flutter analyze --no-fatal-infos
  echo "==> flutter test"
  flutter test
fi

# ── version ─────────────────────────────────────────────────────────────────
# Android refuses to install an update whose versionCode is not higher than the
# installed one, so every artifact that leaves this machine needs a new number.

version_line="$(grep -E '^version:' pubspec.yaml)"
current_code="${version_line##*+}"

if [ "$BUMP" = true ]; then
  next_code=$((current_code + 1))
  sed -i -E "s/^(version: [0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+/\1+${next_code}/" pubspec.yaml
  echo "==> versionCode ${current_code} -> ${next_code}"
else
  next_code="$current_code"
  echo "==> versionCode ${next_code} (unchanged)"
fi

# ── build ───────────────────────────────────────────────────────────────────
# Restore the dev config no matter how this exits.

restore_env() {
  if [ -f .env.dev ]; then
    cp .env.dev .env
    echo "==> restored .env from .env.dev"
  fi
}
trap restore_env EXIT

cp .env.prod .env
echo "==> using .env.prod"

if [ "$BUILD_AAB" = true ]; then
  flutter build appbundle --release
  artifact="build/app/outputs/bundle/release/app-release.aab"
else
  flutter build apk --release
  artifact="build/app/outputs/flutter-apk/app-release.apk"
fi

# ── report ──────────────────────────────────────────────────────────────────

size="$(du -h "$artifact" | cut -f1)"
echo ""
echo "  built   $artifact  ($size)"
echo "  version $(grep -E '^version:' pubspec.yaml | cut -d' ' -f2)"
echo ""
# keytool cannot read this: Flutter signs with APK Signature Scheme v2/v3, which
# has no v1 JAR signature for keytool to parse. apksigner is the right tool.
# A debug-signed build shows "CN=Android Debug, O=Android, C=US".
if [ "$BUILD_AAB" = false ]; then
  apksigner="$(ls -d "$HOME"/AppData/Local/Android/Sdk/build-tools/*/apksigner.bat 2>/dev/null | tail -1 || true)"
  if [ -n "$apksigner" ]; then
    echo "  Signed by:"
    "$apksigner" verify --print-certs "$artifact" 2>/dev/null \
      | grep -E "certificate DN|SHA-1 digest" | sed 's/^/    /'
    echo ""
  fi
fi
