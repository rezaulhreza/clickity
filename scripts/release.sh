#!/bin/zsh
# Make a release: a signed, notarised Clickity.dmg and the appcast.xml that Sparkle reads.
#
#   scripts/release.sh 1.0.0            a real release
#   scripts/release.sh 1.0.0 --dry-run  build and make the DMG only: no notarisation, no appcast
#
# Then publish it with scripts/publish.sh 1.0.0. Setup and steps: docs/RELEASE.md.
#
# Settings, read from ~/.config/clickity/release.env when it exists (a value set in the shell wins):
#   CLICKITY_SIGN_IDENTITY    "Developer ID Application: Your Name (TEAMID)"; found in the keychain when unset
#   CLICKITY_NOTARY_PROFILE   the profile from `xcrun notarytool store-credentials`; default brah-notary
#   CLICKITY_SPARKLE_ACCOUNT  the Keychain account of the Sparkle key from generate_keys; default clickity
set -euo pipefail
cd "${0:A:h}/.."

settings=${CLICKITY_RELEASE_ENV:-$HOME/.config/clickity/release.env}
[[ -f $settings ]] && source "$settings"

version=${1:?Usage: scripts/release.sh VERSION [--dry-run]}
dry=${2:-}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ VERSION must look like 1.0.0"; exit 1; }

notary=${CLICKITY_NOTARY_PROFILE:-brah-notary}
account=${CLICKITY_SPARKLE_ACCOUNT:-clickity}
derived=${CLICKITY_DERIVED:-$HOME/Library/Caches/clickity-release/dd}
out=${CLICKITY_RELEASES:-$HOME/Library/Caches/clickity-release/v$version}
sparkle=$derived/SourcePackages/artifacts/sparkle/Sparkle/bin
repo=rezaulhreza/clickity

if [[ -z ${CLICKITY_SIGN_IDENTITY:-} ]]; then
  CLICKITY_SIGN_IDENTITY=$(security find-identity -v -p codesigning | sed -nE 's/.*"(Developer ID Application: [^"]+)".*/\1/p' | head -1)
fi
[[ $CLICKITY_SIGN_IDENTITY == "Developer ID Application:"* ]] ||
  { echo "✗ A release needs a Developer ID Application certificate. Set CLICKITY_SIGN_IDENTITY."; exit 1; }
team=$(sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p' <<< "$CLICKITY_SIGN_IDENTITY")

# The version's notes come first: no release goes out without them
notes=$(awk -v v="## $version" '$0 == v {on=1; next} /^## / && on {exit} on' CHANGELOG.md | sed '/./,$!d')
[[ -n $notes ]] || { echo "✗ CHANGELOG.md has no '## $version' section."; exit 1; }

# Each build needs a higher number than the last for Sparkle: the commit count only grows on main
build=$(git rev-list --count HEAD)
[[ -z $(git status --porcelain -- Clickity Clickity.xcodeproj) ]] || { echo "✗ Commit the app's changes first."; exit 1; }

# The update key goes into the release build only, so local builds never update themselves
plist=Clickity/Info.plist
restore() { git checkout -q -- "$plist"; }
trap restore EXIT
if [[ $dry != --dry-run ]]; then
  [[ -x $sparkle/generate_keys ]] || xcodebuild -resolvePackageDependencies -scheme Clickity -derivedDataPath "$derived" -quiet
  key=$("$sparkle/generate_keys" --account "$account" -p 2>/dev/null) ||
    { echo "✗ No Sparkle key in the Keychain for account '$account'. See docs/RELEASE.md."; exit 1; }
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $key" "$plist"
fi
/usr/libexec/PlistBuddy -c "Add :GitSHA string $(git rev-parse --short HEAD)" "$plist"

echo "→ Building Clickity $version ($build) for Apple silicon and Intel, signed by $CLICKITY_SIGN_IDENTITY"
xcodebuild -scheme Clickity -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived" \
  CODE_SIGN_IDENTITY="$CLICKITY_SIGN_IDENTITY" DEVELOPMENT_TEAM="$team" \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" OTHER_CODE_SIGN_FLAGS="--timestamp" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  build -quiet
restore
trap - EXIT

app=$derived/Build/Products/Release/Clickity.app

# Xcode re-signs Sparkle.framework but not the helpers inside it, which keep Sparkle's own signature
# without a secure timestamp, and notarisation refuses them. Sign them inside out, as Sparkle's
# documentation says, then the app again with only its own entitlements (no get-task-allow).
sign() { codesign --force --timestamp --options runtime --sign "$CLICKITY_SIGN_IDENTITY" "$@"; }
sparkle_framework=$app/Contents/Frameworks/Sparkle.framework/Versions/B
sign "$sparkle_framework/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$sparkle_framework/XPCServices/Downloader.xpc"
sign "$sparkle_framework/Autoupdate"
sign "$sparkle_framework/Updater.app"
sign "$app/Contents/Frameworks/Sparkle.framework"
sign --entitlements Clickity/Clickity.entitlements "$app"
codesign --verify --deep --strict "$app"
codesign -d --entitlements - --xml "$app" 2>/dev/null | grep -q get-task-allow &&
  { echo "✗ The app still asks for get-task-allow, which notarisation refuses."; exit 1; }

rm -rf "$out"
mkdir -p "$out"
dmg=$out/Clickity.dmg
stage=$(mktemp -d)
ditto "$app" "$stage/Clickity.app"
ln -s /Applications "$stage/Applications"
echo "→ Making $dmg"
hdiutil create -volname Clickity -srcfolder "$stage" -ov -format UDZO "$dmg" >/dev/null
rm -rf "$stage"
codesign --force --timestamp --sign "$CLICKITY_SIGN_IDENTITY" "$dmg"

if [[ $dry == --dry-run ]]; then
  git rev-parse HEAD > "$out/commit"
  echo "✓ Dry run: made $dmg. It is not notarised, has no update key and no appcast."
  exit 0
fi

echo "→ Notarising (usually 2 to 10 minutes)"
xcrun notarytool submit "$dmg" --keychain-profile "$notary" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"

# A .md file named like the DMG is the build's release notes, which the update window shows.
# The appcast lists this build only: GitHub's latest/download link always serves the newest one.
print -r -- "$notes" > "$out/Clickity.md"
"$sparkle/generate_appcast" "$out" --account "$account" --embed-release-notes \
  --download-url-prefix "https://github.com/$repo/releases/download/v$version/"
rm "$out/Clickity.md"
print -r -- "$notes" > "$out/notes.md"
git rev-parse HEAD > "$out/commit"
echo "✓ Made $dmg and $out/appcast.xml. Publish them with: scripts/publish.sh $version"
