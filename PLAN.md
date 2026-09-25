# PLAN.md — note to self for a Claude session started in this repo

Claude Code's memory is keyed by the directory it starts in. Everything
learned so far was learned in `../aether-ui`, so a session started here
begins with nothing. Read this, then `../scm/NOTES.md` (the rollup for every
repo in `~/scm`), then `README.md`. Keep this file current.

## What this repo is, in one breath

Mac-only capabilities for Aether programs: 13 modules under `mac/`, each an
Aether wrapper (`module.ae`) over one C or Objective-C file that calls
Apple's frameworks, imported as `import mac.<name>` with the repo root on the
module path. Fourteen `std.spec`/shell suites in `test/`; `./ci.sh` links all
modules into one program then runs the suites. `tools/mkapp.sh` wraps a
binary as a signed `.app`. State on 2026-09-25: one commit on `main`, **no
remote**, `./ci.sh` green (keychain suite skips, see below).

## The machine you are on

- A Tart macOS VM (`VirtualMac2,1`, macOS 26) reached over ssh; `sudo` is
  passwordless. Xcode 27 provides the SDK; that is why this repo can build at
  all, and why it must never contain Apple's headers (README, "Apple's terms").
- **Your shell is a Background launchd session unless someone is logged in
  at the console.** AppKit code started from it has no window server, and the
  login keychain refuses writes (-25308). Check with `launchctl managername`
  (want `Aqua`) and `stat -f %Su /dev/console` (root = nobody logged in).
  Run GUI-dependent things through `~/bin/in-gui.sh <cmd>`; it exits 97
  until a console login exists (auto-login for `admin` is configured; a
  reboot should give one). This is why the keychain suite skips here and why
  `workspace.open_*`, `workspace.reveal` and `quicklook.preview` have never
  actually run.

## Toolchain

```sh
export PATH=/Users/admin/scm/aether/build:/Users/admin/scm/aeb:$PATH
export AETHER_CACHE_DIR=/some/writable/scratch   # only if ~/.aether/cache is refused
test/run_tests.sh            # or ./ci.sh
```

`ae` is built in `../aether/build` from `main`. This repo needs Aether
≥ 0.717.0: `test_attrlist.ae` uses `fs.hard_link`, added there, and the
modules build with 0.716 otherwise. (Before 0.717 the run cache was not
keyed on the compiler; it is now, so a rebuilt `aetherc` is picked up.)

## Things that are the way they are for a reason

- `@link("-Wl,-framework,X")`, not `-framework X`: Aether 0.716 separates the
  two tokens when several modules link frameworks (recorded as follow-up D
  in `../scm/NOTES.md`; not yet filed upstream). Keep the single-token
  spelling until that is fixed.
- C symbols are prefixed `macae_<module>_` so any set of modules links into
  one program without collisions. Strings cross to Aether as `strdup`'d
  `@heap` returns; `""` means absent. Multi-value results use the split
  try/get pattern (`volume.read` then getters), like `std.fs`'s stat.
- `volume.important()` is the EFFECTIVE number: where a volume reports no
  "for important usage" figure (this VM's volumes do not), it falls back to
  `available_bytes()` and `reports_purgeable()` is 0. Report the effective
  state, never the requested one — aether-ui's AGENTS.md rule, kept here.
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

1. **Push.** Create the GitHub repo (owner/name is Paul's call; `gh` is not
   logged in on this VM) and push `main`. Until then this work exists only
   on this VM's disk.
2. **Run the GUI-only paths** once a console session exists: the keychain
   suite for real, `workspace.open_path/reveal/open_with` (they will open
   Finder — fine inside the VM), `quicklook.preview` from inside an
   aether-ui app (it needs an NSApplication; `preview_available()` says so).
3. **Notifications module** (`mac.notify`): `UNUserNotificationCenter` needs
   a bundled app with an identifier, which `tools/mkapp.sh` now provides, so
   the test can build a probe app the way `test_mkapp.sh` does.
4. **Use it from OpenDisk-ae** (`../OpenDisk-ae`): the port dropped exactly
   what these modules give back — `attrlist` for the scan, `fsevents` for
   incremental rescans, `volume` for purgeable space, `trash`, `workspace`
   for reveal/open, `quicklook` for the Space-bar preview, `fda` for the
   Full Disk Access prompt. Gate them so the app still builds on Linux and
   Windows: aeb `.build.ae` per-OS `lib()`, and an Aether-side seam.
5. Candidates after that: `mac.appearance` (already in aether-ui), Sparkle
   updates (needs the framework bundled in the .app), Launch Services
   registration, login items (`SMAppService`).

## Where the other history is

- `../scm/NOTES.md` — every repo's branch, unpushed commits, dependencies,
  the VM and GitHub unknowns.
- Aether 0.717.0's changelog — the compiler fixes this repo depends on; the
  unfiled follow-ups (the `-framework` one included) are in `../scm/NOTES.md`.
- `/Users/admin/.claude/projects/-Users-admin-scm-aether-ui/memory/` — the
  memory of the session that built this; not loaded here, but readable.
