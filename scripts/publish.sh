#!/bin/zsh
# Publish a release made by scripts/release.sh: tag the commit it was built from, then put
# Clickity.dmg and appcast.xml on a GitHub release. The release becomes "latest", so the download
# link and every installed Clickity's update check move to it.
#
#   scripts/publish.sh 1.0.0
set -euo pipefail
cd "${0:A:h}/.."

version=${1:?Usage: scripts/publish.sh VERSION}
out=${CLICKITY_RELEASES:-$HOME/Library/Caches/clickity-release/v$version}
repo=rezaulhreza/clickity

for file in Clickity.dmg appcast.xml notes.md commit; do
  [[ -f $out/$file ]] || { echo "✗ $out/$file is missing. Run scripts/release.sh $version first."; exit 1; }
done
xcrun stapler validate "$out/Clickity.dmg" >/dev/null || { echo "✗ The DMG isn't notarised."; exit 1; }

# The appcast must name this version, or Sparkle would offer the wrong one
grep -q "<sparkle:shortVersionString>$version</sparkle:shortVersionString>" "$out/appcast.xml" ||
  { echo "✗ appcast.xml isn't for $version."; exit 1; }

# Tag the commit the DMG was built from, which must be on GitHub
commit=$(<"$out/commit")
git push -q origin HEAD
git branch -r --contains "$commit" | grep -q "origin/" || { echo "✗ $commit isn't pushed to GitHub."; exit 1; }
gh release create "v$version" "$out/Clickity.dmg" "$out/appcast.xml" \
  --repo "$repo" --target "$commit" --title "Clickity $version" --notes-file "$out/notes.md" --latest
echo "✓ Published https://github.com/$repo/releases/tag/v$version"
