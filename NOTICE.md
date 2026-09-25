# NOTICE — what is, and is not, in this repository

This repository contains only work Paul Hammant and collaborators wrote, under
the MIT licence in `LICENSE`. It contains nothing of Apple's. This file
records what was checked before the first push to GitHub, how, and the rule
that keeps it true.

## The concern

The modules under `mac/` call Apple's frameworks (Foundation, AppKit,
CoreServices, Security, IOKit, Quartz, QuickLookThumbnailing, ImageIO) and
Apple's libSystem (`getattrlistbulk`, `setiopolicy_np`, `sysctl`). Apple's
Xcode and Apple SDKs Agreement permits using the SDK on a Mac to build
software for Apple platforms; it does not permit redistributing the SDK, its
headers, its link stubs, or its sample code. A repository like this one could
easily end up with a header copied in "to make it build on Linux", a struct
layout re-typed from `sys/attr.h`, or a snippet lifted from a man page or a
WWDC sample. None of that is acceptable here.

## What was audited (2026-09-25, before the first push)

Every file in the tree, by hand and by tooling:

| Check | Result |
|---|---|
| Files by type (`file` over `git ls-files`) | 48 files; all plain text (Aether, C, Objective-C, shell, Markdown). No binaries. |
| Vendored SDK material (`*.h`, `*.tbd`, `*.framework`, `*.dylib`, `*.a`, `*.icns`, `*.plist`, `*.png`) | None tracked. |
| Copyright and licence strings (`copyright`, `Apple Inc`, `APSL`, `sample code`, `WWDC`, `developer.apple`) | Only our own `LICENSE`. |
| How Apple symbols are reached | Exclusively through `#include` / `#import` of SDK headers resolved on the building Mac at compile time. |
| Struct layouts, constants, enums re-typed from Apple headers | None. `attrlist.c` uses `attribute_set_t`, `attrreference_t`, `ATTR_*`, `VREG`/`VDIR`/`VLNK` by name from `<sys/attr.h>` / `<sys/vnode.h>`; `iopolicy.c` uses `IOPOL_*` from `<sys/resource.h>`; `fsevents.c` uses `kFSEventStream*` from CoreServices; and so on. |
| Code copied from Apple documentation or samples | None found. `attrlist.c`'s buffer walk is written from scratch (memcpy-per-field over `ATTR_CMN_RETURNED_ATTRS`), not the man page's example. The `Info.plist` written by `tools/mkapp.sh` is our own template; the DTD URL in it is a public identifier, not content. |
| Apple-owned paths and identifiers as string literals (`com.apple.TimeMachine.plist`, `~/Library/Safari`, `hw.model`) | Present in `fda.c` and `sysinfo.c`. These are names of things on the user's Mac, used to probe them; they are not copyrightable content. |

## What each Apple-facing file uses, and from where

| File | SDK headers included | Nothing else of Apple's |
|---|---|---|
| `mac/attrlist/attrlist.c` | `sys/attr.h`, `sys/vnode.h`, `sys/stat.h` | ✓ |
| `mac/fsevents/fsevents.c` | `CoreServices/CoreServices.h`, `dispatch/dispatch.h` | ✓ |
| `mac/volume/volume.m` | `Foundation/Foundation.h` | ✓ |
| `mac/trash/trash.m` | `Foundation/Foundation.h` | ✓ |
| `mac/workspace/workspace.m` | `AppKit/AppKit.h` | ✓ |
| `mac/quicklook/quicklook.m` | `AppKit`, `Quartz`, `QuickLookThumbnailing`, `ImageIO` | ✓ |
| `mac/defaults/defaults.m` | `Foundation/Foundation.h` | ✓ |
| `mac/keychain/keychain.c` | `Security/Security.h` | ✓ |
| `mac/bundle/bundle.m` | `Foundation/Foundation.h` | ✓ |
| `mac/fda/fda.c` | POSIX only (`dirent.h`, `fcntl.h`, `sys/stat.h`) | ✓ |
| `mac/power/power.c` | `IOKit/pwr_mgt/IOPMLib.h`, `IOKit/ps/IOPowerSources.h`, `IOKit/ps/IOPSKeys.h` | ✓ |
| `mac/iopolicy/iopolicy.c` | `sys/resource.h` | ✓ |
| `mac/sysinfo/sysinfo.c` | `sys/sysctl.h` | ✓ |

## Consequences we accept

- This repository builds only on a Mac with Xcode or the Command Line Tools.
  It is not cross-compiled from Linux, because doing so would mean copying
  the SDK to a non-Apple machine.
- CI runs on GitHub's macOS runners, which carry Apple's SDK under Apple's
  own terms.
- Binaries built from this code link Apple's frameworks at run time from the
  user's Mac, like every Mac application. Nothing of Apple's is bundled into
  them by `tools/mkapp.sh` either: the `.app` it makes contains the binary,
  our `Info.plist`, `PkgInfo`, and an icon only if the caller supplies one.

## The rule going forward

Do not commit anything from `/Applications/Xcode.app`, the Command Line
Tools, `/System/Library`, Apple's developer documentation, or Apple sample
projects. Do not re-type Apple header definitions into this tree. If a
module cannot be written by including the SDK header and calling the API,
it does not belong here. `AGENTS.md` repeats this for anyone (or any agent)
working in the repo.
