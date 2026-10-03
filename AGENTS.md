# Notes to self (agent assisting on macae)

Short, opinionated, written for a future agent/LLM picking up mid-task.
Re-read at start of every session. Language-level questions (the compiler,
the standard library, Aether idioms) belong to
[aether's LLM.md](https://github.com/aether-lang-dev/aether/blob/main/LLM.md);
this file is only what is particular to this repo.

## What this repo is, in one breath

Mac-only capabilities for Aether programs: 13 modules under `mac/`, each an
Aether wrapper (`module.ae`) over one C or Objective-C file that calls
Apple's frameworks, imported as `import mac.<name>` with the repo root on the
module path. Fourteen `std.spec`/shell suites in `test/`; `./ci.sh` links all
modules into one program then runs the suites. `tools/mkapp.sh` wraps a
binary as an ad-hoc-signed `.app`. Needs Aether ≥ 0.766.0, the family-wide
floor (the code itself needs 0.717.0: `test_attrlist.ae` uses `fs.hard_link`).

## The one rule that is not negotiable

**Nothing of Apple's is committed here, ever.** Only our own MIT-licensed
work. Concretely:

- No SDK headers, framework stubs, `.tbd` files, or copies of anything from
  `/Applications/Xcode.app` or the Command Line Tools. Apple's SDK
  agreement lets a Mac use them to build; it does not let anyone
  redistribute them. Every `.c`/`.m` here reaches Apple's APIs only by
  `#include`/`#import` of headers that exist on the building Mac.
- No struct layouts, constants or enums re-typed out of Apple's headers.
  Use the header's names (`attribute_set_t`, `kFSEventStreamCreateFlag*`,
  `IOPOL_THROTTLE`) and let the compiler resolve them.
- No Apple sample code, man-page example code, WWDC snippets, icons, sounds,
  or default `.icns`/`.plist` files. The Info.plist `tools/mkapp.sh` writes
  is ours, from scratch.
- That is also why this repo builds only on a Mac and is not cross-compiled
  from Linux (README, "Apple's terms").

A reviewer asked whether the tree honoured this before the first push; it
did (audited 2026-09-25: no headers, no binaries, no Apple copyright
notices, every Apple symbol reached through an SDK include). Keep it so.

## Building and testing

```sh
# any Mac with Xcode or the Command Line Tools, and `ae` ≥ 0.717.0 on PATH
test/run_tests.sh            # every suite; test/run_tests.sh fsevents trash for some
./ci.sh                      # all modules linked into one program, then the suites
```

The suites run headless (`MACAE_HEADLESS=1`): nothing opens Finder, an app
or System Settings. Some behaviour depends on the SESSION, not the machine:

- An ssh or launchd session with no console login has no window server.
  AppKit code started from it cannot show anything, and the login keychain
  refuses writes (`-25308`, "user interaction is not allowed"). Check with
  `launchctl managername` (want `Aqua`) and `stat -f %Su /dev/console`
  (`root` = nobody logged in). This is why the keychain suite skips there,
  and why `workspace.open_*`, `workspace.reveal` and `quicklook.preview`
  have only been exercised for their refusal paths so far.
- GitHub's `macos-latest` runner is NOT such a session, it turns out: the
  first CI run (2026-09-25) passed all 14 suites, keychain included, in
  under a minute after a source build of the toolchain. Where the keychain
  suite skips is a headless VM reached over ssh.

## Things that are the way they are for a reason

- `@link("-Wl,-framework,X")`, not `-framework X`: Aether 0.717 separates
  the two tokens when several modules link frameworks. Keep the single-token
  spelling until that is fixed upstream (not yet filed).
- C symbols are prefixed `macae_<module>_` so any set of modules links into
  one program without collisions. Strings cross to Aether as `strdup`'d
  `@heap` returns; `""` means absent. Multi-value results use the split
  try/get pattern (`volume.read` then getters), like `std.fs`'s stat.
- `volume.important()` is the EFFECTIVE number: where a volume reports no
  "for important usage" figure (VMs' volumes often do not), it falls back
  to `available_bytes()` and `reports_purgeable()` is 0. Report the
  effective state, never the requested one.
- `keychain.available()` probes by WRITING an item and deleting it; a read
  probe said "available" in sessions where every write then failed.
- `quicklook.thumbnail()` refuses a missing file itself: the framework
  returns a generic icon for any path, which is not a thumbnail of the file.
- `attrlist.read()` follows a symlink given as the ROOT (`/etc`) but never
  follows entries; `test_attrlist` pins both.
- Objective-C is compiled without ARC (`@source` files get the build's plain
  cflags), so `.m` files use `@autoreleasepool`, `autorelease`, explicit
  `retain`/`release`. Keep it that way in new modules.
- Reserved words: `try` cannot be a function name (that is why it is
  `volume.read`). Don't name a C helper `dup` (unistd.h).

## What is next, in order

1. **Run the GUI-only paths** on a Mac with a console login: the keychain
   suite for real, `workspace.open_path/reveal/open_with` (they will open
   Finder), `quicklook.preview` from inside an aether-ui app (it needs an
   NSApplication; `preview_available()` says so).
2. **Notifications module** (`mac.notify`): `UNUserNotificationCenter` needs
   a bundled app with an identifier, which `tools/mkapp.sh` provides, so the
   test can build a probe app the way `test_mkapp.sh` does.
3. **Use it from OpenDisk-ae**: the port dropped exactly what these modules
   give back (`attrlist` for the scan, `fsevents` for incremental rescans,
   `volume` for purgeable space, `trash`, `workspace` for reveal/open,
   `quicklook` for the Space-bar preview, `fda` for the Full Disk Access
   prompt). Gate them so the app still builds on Linux and Windows: aeb
   `.build.ae` per-OS `lib()`, and an Aether-side seam.
4. Candidates after that: `mac.appearance` (already in aether-ui), Sparkle
   updates (needs the framework bundled in the .app), Launch Services
   registration, login items (`SMAppService`).
