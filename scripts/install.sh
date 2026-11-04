#!/bin/zsh
# Build a Release Clickity and install it as /Applications/Clickity.app, then launch it.
# Usage: scripts/install.sh
# Overrides: IDENTITY="Apple Development" TEAM=<id> DEST=/Applications
set -euo pipefail
cd "${0:A:h}/.."

DEST=${DEST:-/Applications}
DERIVED=${DERIVED:-$HOME/Library/Caches/clickity-build}
BUNDLE_ID=com.rezaulhreza.Clickity

# macOS ties Screen Recording to the signature. An ad-hoc build loses it on every rebuild, so sign
# with a real certificate: "Apple Development" if present, else "Developer ID Application".
if [[ -z "${IDENTITY:-}" ]]; then
  for candidate in "Apple Development" "Developer ID Application"; do
    if security find-identity -v -p codesigning | grep -q "\"$candidate"; then
      IDENTITY=$candidate
      break
    fi
  done
fi
if [[ -z "${IDENTITY:-}" ]]; then
  echo "✗ No signing certificate found. In Xcode: Settings → Accounts → Manage Certificates → + Apple Development."
  exit 1
fi
if [[ -z "${TEAM:-}" ]]; then
  TEAM=$(security find-identity -v -p codesigning | grep "\"$IDENTITY" | head -1 | sed -E 's/.*\(([A-Z0-9]{10})\)".*/\1/')
fi
echo "→ Signing with \"$IDENTITY\" (team $TEAM)"

echo "→ Building Release (first build takes about a minute)"
xcodebuild -scheme Clickity -configuration Release -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" \
  build -quiet

BUILT="$DERIVED/Build/Products/Release/Clickity.app"
codesign --verify --deep --strict "$BUILT"

if pgrep -x Clickity >/dev/null; then
  echo "→ Quitting the running Clickity"
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
  for _ in {1..50}; do pgrep -x Clickity >/dev/null || break; sleep 0.1; done
  pkill -x Clickity 2>/dev/null || true
fi

echo "→ Installing to $DEST/Clickity.app"
rm -rf "$DEST/Clickity.app"
ditto "$BUILT" "$DEST/Clickity.app"

open "$DEST/Clickity.app"
echo "✓ Clickity is in the menu bar. First launch only: allow Screen Recording, then quit and reopen Clickity."
