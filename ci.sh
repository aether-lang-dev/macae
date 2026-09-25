#!/usr/bin/env bash
# ci.sh — macae's pipeline: every module compiles and links with every
# other in one program, then each suite runs. Needs a Mac with Xcode or the
# Command Line Tools and `ae` on PATH. Exit status: 0 only if all green.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
if [ "$(uname -s)" != "Darwin" ]; then
    echo "macae is Mac-only (needs Apple's SDK from Xcode / the Command Line Tools); nothing to run here."
    exit 0
fi
if ! xcrun --sdk macosx --show-sdk-path > /dev/null 2>&1; then
    echo "  FAIL: no macOS SDK — install Xcode or `xcode-select --install`"; exit 1
fi

echo "=== every module in one program ==="
work="$(mktemp -d "${TMPDIR:-/tmp}/macae-ci-XXXXXX")"
{
    for m in mac/*/; do echo "import mac.$(basename "$m")"; done
    echo 'main() { println("all modules linked") }'
} > "$work/all.ae"
if (cd "$work" && AETHER_LIB_DIR="$ROOT" ae run all.ae > "$work/all.log" 2>&1) && grep -q "all modules linked" "$work/all.log"; then
    echo "  OK   $(ls -d mac/*/ | wc -l | tr -d ' ') modules compile and link together"
else
    echo "  FAIL"; grep -a -E "error" "$work/all.log" | head -20 | sed 's/^/       /'
    rm -rf "$work"; exit 1
fi
rm -rf "$work"

echo "=== suites ==="
test/run_tests.sh
rc=$?
echo
if [ "$rc" -eq 0 ]; then echo "=== all green ==="; else echo "=== $rc suite(s) failed ==="; fi
exit $rc
