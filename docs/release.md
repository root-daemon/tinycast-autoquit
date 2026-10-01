# Release

This fork publishes through `.github/workflows/release.yml` to
`root-daemon/tinycast-autoquit`. It never modifies the upstream Homebrew tap or announces to Discord.
Signing setup and the first manual installation are covered in [signing.md](signing.md).

## Publish a release

Merge the approved changes into `main`, then open **Actions → Release → Run workflow**. Choose
`main`, `stable` or `beta`, and a base version such as `0.11.5`. The CLI equivalent is:

```sh
gh workflow run release.yml --repo root-daemon/tinycast-autoquit --ref main \
  -f channel=stable -f version=0.11.5
```

Stable tags are `vMAJOR.MINOR.PATCH`; beta tags add `-beta.<run-number>` and are prereleases.
A tag must not already exist. Publishing targets the workflow’s exact commit; open feature branches
are not included unless merged first. Each version/channel has a concurrency group and is never
cancelled halfway through a release.

## Validation and artifacts

The validation job runs all standalone harnesses, an unsigned Debug build, lint and pure-model checks.
It runs tests before building, with two workers to avoid starving timed process fixtures.
Both release builds wait for validation and use the same stored signing certificate:

- Apple silicon: `Tinycast-<version>.dmg` and `.zip`.
- Universal: `Tinycast-Universal-<version>.dmg` and `.zip`, with arm64 and x86_64 in both binaries.

The app and helper seals, hardened runtime, entitlements and architectures are verified. The DMG
checksum is verified; each ZIP is extracted and its app verified. The publishing job waits for both
builds, downloads all four assets, writes `SHA256SUMS`, and creates one GitHub Release with all assets
attached. A failed build therefore publishes nothing. Failed publication can leave a GitHub draft;
inspect the run and release before retrying an existing tag.

Release notes are derived from merged PRs in this fork. Install instructions go below
`<!-- tinycast:install -->`, which the app excludes from its update window. Direct-download
instructions point to this fork, with no upstream Homebrew install command.

## Updating an installed app

The in-app updater reads this fork’s GitHub Releases and requires a ZIP, a newer matching-channel
version, the same bundle ID, and the running app’s exact signing certificate. It preserves
preferences and Application Support data. A DMG alone cannot be installed by the updater.

The first consistently signed release must be installed manually over the earlier ad-hoc build.
Quit Tinycast before replacing it in Applications, and re-grant permissions as needed. A downloaded
self-signed build may need its quarantine removed once as described on the release page. Debug stays
`Tinycast Dev.app` / `com.tinycast.app.dev` and never self-updates.

## Local packaging

With the signing keychain unlocked:

```sh
./Scripts/build-dmg.sh 0.11.5
```

The release workflow is the authoritative path for publishing both architectures and the updater ZIP.
Local signing must use the same identity. Never generate a fresh certificate for each release.
