# Release Process

A release is a signed, notarised `Clickity.dmg` and an `appcast.xml` that Sparkle reads, both on a
GitHub release in `rezaulhreza/clickity`. Releases are made on a Mac with two scripts, not by CI.

- The download link is `https://github.com/rezaulhreza/clickity/releases/latest/download/Clickity.dmg`.
- Installed copies check `https://github.com/rezaulhreza/clickity/releases/latest/download/appcast.xml`
  (`SUFeedURL` in `Clickity/Info.plist`).

Both links follow the release marked "latest", so a new release moves them. Nothing else hosts files.

## Set up once

1. Install a **Developer ID Application** certificate (Xcode → Settings → Accounts → Manage
   Certificates). Check it with `security find-identity -v -p codesigning`.
2. Save the notarisation login in the Keychain. The scripts use the profile `brah-notary` by default,
   since a profile belongs to the Apple account, not to one app. On a new Mac, make it (you type the
   app-specific password yourself):

   ```sh
   xcrun notarytool store-credentials brah-notary --apple-id YOU@EXAMPLE.COM --team-id TEAMID
   ```

3. Run `scripts/release.sh 1.0.0 --dry-run` once, so Sparkle's tools are on disk. Then make
   Clickity's update signing key. It is its own Keychain account, `clickity`, apart from other
   apps' keys:

   ```sh
   ~/Library/Caches/clickity-release/dd/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account clickity
   ```

   Back up the private key outside the repository. Without it, no installed Clickity accepts your
   updates:

   ```sh
   ~/Library/Caches/clickity-release/dd/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account clickity -x ~/clickity-sparkle-private.key
   ```

The scripts read optional overrides from `~/.config/clickity/release.env`: `CLICKITY_SIGN_IDENTITY`,
`CLICKITY_NOTARY_PROFILE` and `CLICKITY_SPARKLE_ACCOUNT`.

## Make a release

1. Add a `## 1.0.1` section to `CHANGELOG.md` that says what changed, in plain words for the people
   who use Clickity. It goes into the update window and onto the GitHub release.
2. Commit everything. The script refuses uncommitted app changes, so the release matches a commit.
3. Run the tests (the `test` command in `CLAUDE.md`), with Clickity quit.
4. Try the build without notarisation:

   ```sh
   scripts/release.sh 1.0.1 --dry-run
   ```

5. Make the release. It builds for Apple silicon and Intel, signs, notarises, staples and writes the
   appcast into `~/Library/Caches/clickity-release/v1.0.1/`:

   ```sh
   scripts/release.sh 1.0.1
   ```

6. Publish it. This pushes, tags `v1.0.1` on the commit that was built and makes the GitHub release:

   ```sh
   scripts/publish.sh 1.0.1
   ```

## Versions and builds

- The version (`1.0.1`) is what people see. The build number is the commit count of `HEAD`, so it
  always grows on `main`. Sparkle compares build numbers, so release from `main` only.
- The update key goes into `Info.plist` for the release build only, and `git checkout` puts the
  placeholder back. Builds from `scripts/install.sh` keep the placeholder, so they never update
  themselves and Settings says so.
- The appcast lists only the newest build. GitHub's `latest` link always serves the newest appcast, so
  older entries are not needed.

## Download counts

```sh
gh release view v1.0.0 --repo rezaulhreza/clickity --json assets --jq '.assets[] | "\(.name) \(.downloadCount)"'
```

## Not yet verified

- No update has been installed through Sparkle yet. After the first two releases, install the older
  one and check that it offers the newer.
