---
title: What works
description: What Tinycast supports from the Raycast API, how well it works in practice, and the known gaps.
---

## How well it works

We tested Tinycast against the 37 extensions installed in Raycast on the development Mac:

**32 of 37 extensions, and 114 of 147 view commands, open and render.**

These numbers come from that test. It was run before sign-in support was added, so extensions that
need sign-in weren't counted. The numbers should go up.

## Supported

**Components.** `List` and `Grid` with sections, empty views, item details and search bar dropdowns.
`Detail` with `Metadata`. `Form` with every field type: text, password, text area, checkbox,
dropdown, tag picker, date picker, file picker, separator and description. `ActionPanel` with
sections and submenus, and `Action` with all its built-in variants. Older names still used by
published extensions also work.

**APIs.** `Clipboard`, `LocalStorage`, `Cache`, `environment`, `getPreferenceValues`, `showToast`,
`showHUD`, `confirmAlert`, `closeMainWindow`, `popToRoot`, `clearSearchBar`, `open`, `trash`,
`showInFinder`, `getApplications`, `getDefaultApplication`, `getFrontmostApplication`,
`getSelectedText`, `getSelectedFinderItems`, `launchCommand`, `updateCommandMetadata`,
`openExtensionPreferences`, `useNavigation`, `OAuth`, `Icon`, `Color`, `Image.Mask`,
`Keyboard.Shortcut.Common`, `LaunchType`.

**Signing in with OAuth.** `OAuth.PKCEClient` works with all three of Raycast's redirect methods.
Tokens are stored in your login Keychain, separately for each extension, and removed when you
uninstall it.

To receive the redirect, Tinycast registers the `raycast://` link type. If Raycast is also
installed, macOS decides which app receives those links. A sign-in that never returns times out
after five minutes.

**Node built-ins.** `path`, `fs` and `fs/promises`, `os`, `child_process`, `crypto`, `zlib`,
`http` and `https`, `stream`, `util`, `events`, `buffer`, `url`, `querystring`, `punycode`,
`assert`, `string_decoder` and `timers`. Other built-ins load without errors and only fail when
they're actually used.

`http` and `https` requests use the same code as `fetch`, so libraries like axios and node-fetch
work. HTTP over a Unix socket works too, which is how Docker's extension reaches its daemon. Streams
are fully implemented, so pipelines like `fetch` → file work from start to finish.
`child_process.spawn` streams the command's output as it runs.

**WebSockets.** The `WebSocket` global and the bundled `ws` package both connect, so extensions like
Home Assistant get live updates. Names ending in `.local`, like `homeassistant.local`, resolve
through macOS.

**Bundled packages.** Extensions that ship their own `node_modules` load those packages, and
`createRequire`, WebAssembly and `SharedArrayBuffer` work.

**Bundled Swift helpers**, like Color Picker's, run normally.

**Command modes.** `view` commands appear in the palette. `no-view` commands run in the background
with the palette closed. A `no-view` command with an `interval` can refresh on a schedule; see
[Background refresh](/docs/extensions/customising#background-refresh). `menu-bar` commands show
native menu items and refresh on their manifest interval, without keeping JavaScript in memory
between runs; see [Menu bar commands](/docs/extensions#menu-bar-commands).

**`raycast://` links** are handled inside Tinycast. Tinycast registers this link type; if Raycast is
also installed, macOS decides which app receives those links. A link to an installed extension command
runs that command, whether it comes from another app, the browser or an extension, with its `arguments`,
`fallbackText`, `launchType` and `context` applied. `tinycast://` links work the same way. A Raycast Store
**Install** link opens [Search extensions](/docs/extensions/installing#search-extensions) on that
extension. Any other link reopens the palette, since passing it on would open Raycast itself.

## Not supported yet

| Gap                                              | Why                                                                                       |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| **Raycast's sign-in proxy**                      | Providers that need `oauth.raycast.com` to exchange tokens still fail                     |
| **`AI`, `BrowserExtension`, `WindowManagement`** | These are Raycast services with no local equivalent. Using one fails with a clear message |
| **A WebSocket to a server macOS doesn't trust**  | Certificate checks can't be turned off, so the connection fails                           |
| **Canceling a `fetch` in progress**              | The caller gets its `AbortError`, but the request still finishes in the background        |
| **Writing to a running `child_process.spawn`**   | Input is sent once, when the command starts. Later writes are dropped                     |
| **Streaming HTTP**                               | Responses arrive all at once, so server-sent events and download progress don't work      |
| **`net` and `tls`**                              | Load without errors, but fail when used                                                   |
| **AI tools (`tools/`)**                          | Not shown                                                                                 |

**If an extension needs something that's missing, it tells you when you run it** instead of failing
silently or showing a broken screen.
