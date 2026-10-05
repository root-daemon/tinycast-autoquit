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
A fast version check gates validation and the Release build, which then run concurrently.
The app and clipboard helper are ARM64-only in both Debug and Release, set in `project.yml`.
One macOS runner compiles and signs the Release app, then packages that same bundle:

- Apple silicon: `Tinycast-<version>.dmg` and `.zip`. Intel is not supported.

The app and helper seals, hardened runtime, entitlements and ARM64 architecture are verified. The DMG
checksum is verified; each ZIP is extracted and its app verified. The publishing job waits for
validation and signed packaging, downloads both assets, writes `SHA256SUMS`, and creates one
GitHub Release with all assets attached. Failed validation, compilation or packaging publishes nothing.
Compilation can consume runner time even if validation fails. Failed publication can leave a GitHub
draft; inspect the run and release before retrying an existing tag.

The Debug and Release steps print Xcode's build timing summary. The baseline
[0.11.7 run](https://github.com/root-daemon/tinycast-autoquit/actions/runs/37016072988)
took 30m09s: harnesses 6m20s, Debug 4m04s, ARM Release 10m34s and universal Release 17m42s.
The ARM app's whole-module Swift compilation alone took about 9m18s; packaging each output took
about 22s. Parallel validation removes the roughly 11-minute pre-build wait. Dropping the universal
build removes its duplicate ARM compilation and Intel compilation entirely. Release optimization is
unchanged. The new end-to-end duration must be measured in CI, not inferred from these times.

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

The release workflow is the authoritative path for publishing the ARM64 app and the updater ZIP.
Local signing must use the same identity. Never generate a fresh certificate for each release.
