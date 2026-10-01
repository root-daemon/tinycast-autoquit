# Signing

This fork uses one reusable **Tinycast Self-Signed** certificate for local and CI release builds.
The updater accepts a sealed app only when its leaf certificate exactly matches the running app.
It does not trust the upstream developer’s team. Certificate replacement requires a manual install.
Self-signing is for this personal fork; these releases are not Apple-notarized.

## Local identity and backup

The identity is installed in a dedicated keychain:

```text
~/.config/tinycast-signing/tinycast.keychain-db
```

The same private directory holds `identity.p12` (encrypted certificate/private-key backup),
`identity-password`, `keychain-password` and the public `certificate.pem`. The directory is mode 700
and credential files are mode 600. Keep a secure backup of this directory; never commit its files.

The keychain is on the user’s search list. If it has locked, unlock it before a local signed build:

```sh
security unlock-keychain -p "$(cat ~/.config/tinycast-signing/keychain-password)" \
  ~/.config/tinycast-signing/tinycast.keychain-db
```

`security find-identity -p codesigning` lists the certificate. Self-signing can report
`CSSMERR_TP_NOT_TRUSTED`; the release workflow selects the matching identity’s fingerprint explicitly
and verifies the resulting sealed code instead of requiring an Apple trust chain.

## GitHub Actions

The fork’s repository holds two Actions secrets:

- `SIGNING_P12_BASE64`: base64 of the encrypted `identity.p12`.
- `SIGNING_P12_PASSWORD`: its encryption password.

CI imports that exact identity into an ephemeral keychain, grants codesign access, and signs the app
and clipboard helper with its fingerprint. It never creates a replacement certificate. Repository
secrets are not available to untrusted pull-request jobs; Release is manually dispatched.

## First install

The earlier local builds were ad-hoc signed. They have no certificate for the updater to compare,
so install the first consistently signed release manually. Quit all Tinycast copies, replace
`/Applications/Tinycast.app`, and grant Accessibility again. Later builds signed with the same
certificate preserve the signing identity, though macOS permissions remain under the user’s control.

## Public distribution

For public distribution, obtain your own Apple Developer ID Application certificate and add
notarization. Update the fork’s trust policy deliberately before changing the signing identity.
The upstream Developer ID team is not trusted by this fork.

## Hardened runtime

**Release only**, on both targets: `ENABLE_HARDENED_RUNTIME: YES`, which notarization requires. Debug
must stay without it — hardened runtime turns on library validation, and Xcode's
`Tinycast Dev.debug.dylib` is refused at launch because a self-signed identity carries no Team ID for
the loader to match. The flag is not part of the designated requirement, so turning it on costs no
Accessibility grant. Each entitlement in `Tinycast/Tinycast.entitlements` earns its place:

| Entitlement | Without it |
| --- | --- |
| `com.apple.security.cs.allow-jit` | JavaScriptCore cannot JIT, and every extension command runs on the interpreter |
| `com.apple.security.automation.apple-events` | Every Apple event is refused with `-1743` and no prompt — Get Info, the Finder selection an extension reads, and the System Events–driven system actions all die silently |
| `com.apple.security.device.camera` | The camera prompt never appears and access resolves as denied |
| `com.apple.security.personal-information.calendars` | `requestFullAccessToEvents()` returns `false` in milliseconds with no dialog, and Tinycast never appears under System Settings › Calendars |

**A usage string is not enough under the hardened runtime.** `tccd` checks the matching entitlement
*before* it prompts, and without it logs "requires entitlement … but it is missing" and denies on the
spot — no dialog, no error, status still `.notDetermined`. A grant saved before the hardened runtime
arrived keeps working, since `tccd` does not re-check it, which is why this surfaces only on fresh
installs. Adding a protected resource therefore means adding its usage string *and* its entitlement.

`RESOURCE_ENTITLEMENTS` in `Scripts/verify-signature.sh` maps every protected resource's usage string
to its entitlement, including resources Tinycast does not use. That grants nothing — only
`Tinycast.entitlements` does, and a row whose usage string `Info.plist` doesn't declare is skipped. It
is there so a future feature that adds the usage string but forgets the entitlement fails the release
instead of shipping a prompt that can never appear.

Nothing else is needed: the only `dlopen` is Apple's own IOBluetooth, so library validation is left
on, and `node`, `ray` and shell commands are separate processes it never reaches. Bluetooth has no
hardened-runtime entitlement.

`./Scripts/verify-signature.sh <path-to-.app>` asserts all of this — the runtime flag on the app *and*
on `Contents/Helpers/ClipboardTextHelper`, an intact nested seal, no `get-task-allow`, and an
entitlement for every usage string `Info.plist` declares. Both release jobs run it before packaging:
a nested binary missing the runtime flag is the most common notarization rejection, and a usage string
missing its entitlement ships a permission that can never be granted.
