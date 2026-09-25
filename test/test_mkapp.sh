#!/usr/bin/env bash
# tools/mkapp.sh wraps a binary as a .app that macOS recognises: the bundle
# has the structure Finder expects, its signature verifies, and the program
# inside sees its own identity through mac.bundle.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/macae-mkapp-XXXXXX")"
fail=0
check() { if [ "$2" = "$3" ]; then echo "  PASS: $1"; else echo "  FAIL: $1 — got '$2', want '$3'"; fail=1; fi; }

cd "$HERE"
if ! AETHER_LIB_DIR="$ROOT" ae build mkapp_probe.ae -o "$work/probe" > "$work/build.log" 2>&1; then
    echo "  FAIL: building the probe"; tail -10 "$work/build.log"; exit 1
fi
app="$("$ROOT/tools/mkapp.sh" "$work/probe" Probe org.macae.probe "$work" "" 2.5)"
check "the bundle is where mkapp said" "$([ -d "$app" ] && echo yes)" "yes"
check "the executable is inside" "$([ -x "$app/Contents/MacOS/Probe" ] && echo yes)" "yes"
check "Info.plist parses" "$(plutil -lint -s "$app/Contents/Info.plist" >/dev/null 2>&1 && echo ok)" "ok"
check "the identifier is in the plist" "$(defaults read "$app/Contents/Info.plist" CFBundleIdentifier 2>/dev/null)" "org.macae.probe"
check "the signature verifies" "$(codesign --verify --deep "$app" >/dev/null 2>&1 && echo ok)" "ok"
out="$("$app/Contents/MacOS/Probe" 2>/dev/null)"
check "the program knows it is bundled" "$(printf '%s\n' "$out" | grep '^bundled=')" "bundled=1"
check "and its identifier" "$(printf '%s\n' "$out" | grep '^id=')" "id=org.macae.probe"
check "and its name" "$(printf '%s\n' "$out" | grep '^name=')" "name=Probe"
check "and its version" "$(printf '%s\n' "$out" | grep '^version=')" "version=2.5"
check "and any Info.plist key" "$(printf '%s\n' "$out" | grep '^min=')" "min=11.0"
bare="$("$work/probe" 2>/dev/null | grep '^bundled=')"
check "the same binary bare is not bundled" "$bare" "bundled=0"
rm -rf "$work"
exit $fail
