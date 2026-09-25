# macae — macOS for Aether

Mac-only capabilities for [Aether](https://github.com/aether-lang-dev/aether)
programs: the things a Mac app needs that no cross-platform toolkit gives it.
Thirteen modules, each a thin Aether wrapper over a C or Objective-C file that
calls Apple's frameworks directly. Every module has a `std.spec` suite.

It builds on any Mac with Xcode or the Command Line Tools installed, and only
there: see *Apple's terms* below for why that is the line, and why nothing here
crosses it.

```aether
import mac.fsevents
import mac.volume
import mac.trash

w, err = fsevents.open("/Users/me/Documents", 0.5)      // what changed, as it changes
if volume.read("/") == 1 { free = volume.important() }  // Finder's number, purgeable included
where, err = trash.item("/Users/me/Downloads/old.dmg")  // "Put Back" works
```

## Modules

| Module | What it gives you | Apple API | Tier |
|---|---|---|---|
| `mac.attrlist` | a whole directory in one pass: names, kinds, file ids, link counts, allocated sizes | `getattrlistbulk(2)` | C |
| `mac.fsevents` | what changed under a tree, polled from a buffer; replay since a saved event id | FSEvents (CoreServices) | C |
| `mac.volume` | capacity as Finder counts it (purgeable space), volume identity and flags, mounted volumes | `NSURL` volume keys, `NSFileManager` | ObjC |
| `mac.trash` | move to the Trash the way Finder does | `NSFileManager trashItemAtURL:` | ObjC |
| `mac.workspace` | open, reveal in Finder, open with; which app would open a file/URL; running apps | `NSWorkspace` | ObjC |
| `mac.quicklook` | a PNG thumbnail of any previewable file; the Quick Look panel inside an app | QuickLookThumbnailing, Quartz | ObjC |
| `mac.defaults` | settings in `~/Library/Preferences/<suite>.plist` | `NSUserDefaults` | ObjC |
| `mac.keychain` | a secret in the login keychain | Security (`SecItem*`) | C |
| `mac.bundle` | the .app this process lives in; any .app's identity | `NSBundle` | ObjC |
| `mac.fda` | is Full Disk Access granted (a probe), and the Settings pane that grants it | TCC-guarded reads | C |
| `mac.power` | keep the Mac (or its display) awake; AC/battery, charge level | IOKit `IOPMAssertion*`, `IOPS*` | C |
| `mac.iopolicy` | throttle this process's disk I/O so foreground apps keep theirs | `setiopolicy_np(3)` | C |
| `mac.sysinfo` | model, OS version, CPU, memory, Apple silicon or Intel, Rosetta | `sysctl(3)` | C |

Plus `tools/mkapp.sh`, which wraps an Aether binary as a `.app` bundle
(Info.plist, icon, ad-hoc code signature) so that `mac.bundle` and Finder
recognise it.

Each module has `available()`. It is 1 for the platform; the modules whose
answer depends on the *session* say so specifically: `workspace.interactive()`
is 0 under `MACAE_HEADLESS` / `AETHER_UI_HEADLESS` (nothing launches),
`keychain.available()` probes by writing (0 in ssh and some CI sessions, where
writes are refused), `quicklook.preview_available()` needs a running
application. Where a value is not what was asked for, the getter says which:
`volume.important()` falls back to `available_bytes()` on a volume that
reports no purgeable figure, and `volume.reports_purgeable()` is 0 there.

## Using it

Put this repo's root on the module path and import `mac.<module>`:

```sh
AETHER_LIB_DIR=/path/to/macae ae run app.ae         # or: aetherc --lib /path/to/macae
```

Under `aeb`, `lib("/path/to/macae")` in the `.build.ae`. Each module names its
own C/ObjC file with `@source` and its frameworks with `@link`, so importing a
module is all a program does; nothing is configured per program.

The `@link` lines use the single-token spelling `-Wl,-framework,Foundation`
rather than `-framework Foundation`, because Aether 0.716 separates the two
tokens when several modules link frameworks (reported to aether as a
follow-up). Both mean the same thing to clang.

## Tests

```sh
test/run_tests.sh              # every suite; test/run_tests.sh fsevents trash for some
./ci.sh                        # the same, as CI runs it
```

Fourteen suites: one per module, plus a shell test that builds a program,
wraps it with `tools/mkapp.sh`, verifies the signature and runs it to see that
it knows its own bundle identity. The runner sets `MACAE_HEADLESS`, so no suite
opens Finder or System Settings; the workspace and fda suites assert that
refusal. The trash and keychain suites create and remove their own items. On a
Mac where the keychain refuses writes, that suite skips and says why.

Last run (macOS 26, Apple silicon VM, Aether 0.716 + its `wip/opendisk-port-fixes`
branch): 13 suites green, keychain skipped ("no usable keychain in this
session").

## Apple's terms, and why the repo looks the way it does

- **Nothing of Apple's is here.** The SDK headers (`AppKit/AppKit.h`,
  `sys/attr.h`, …) and the framework link stubs come from Xcode or the Command
  Line Tools on the building Mac. Apple's Xcode and Apple SDKs Agreement lets
  you use them there, to build software for Apple platforms, and does not let
  you redistribute them. So they are not committed, and this repo cannot be
  cross-compiled from Linux: a Zig or osxcross toolchain would need the SDK
  copied over, which is the thing the agreement forbids. (Zig's Darwin target
  ships only the open-source libc/kernel headers, which is why it can build
  POSIX-only Mac binaries and nothing that touches a framework.)
- **What you build with it is yours.** A binary that links Apple's frameworks
  loads them from the user's Mac at run time, like every Mac app. Ad-hoc
  signing (`tools/mkapp.sh` does it) is enough to run locally on Apple
  silicon. Distributing outside the App Store needs a Developer ID
  certificate and notarization, which need a paid developer account; that is
  Apple's gate on distribution, not on this code.
- **Two APIs here read protected data**, and both go through the user:
  `mac.fda` only probes whether Full Disk Access was granted in System
  Settings; `mac.keychain` stores items the way any app does, and another app
  reading them prompts the user.

## Not here (yet)

- **Notifications** (`UNUserNotificationCenter`) need a bundled app with an
  identifier; with `tools/mkapp.sh` that is now possible, so it is the natural
  next module.
- **Objective-C without the SDK.** aether's `contrib.metal` reaches Metal by
  `dlopen`-ing the frameworks and messaging classes through the Objective-C
  runtime, whose header is open source. That builds anywhere, at the cost of
  hand-written, unchecked `objc_msgSend` casts. This repo takes the other
  route: real Objective-C, compiled by Apple's clang, checked against the real
  headers. A module could be redone the other way if cross-compiling it
  mattered more than reading it.
- **Swift-only frameworks** (SwiftUI, Observation) have no C ABI; nothing here
  can reach them.
