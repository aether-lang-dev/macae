#!/usr/bin/env bash
# run_tests.sh — every macae suite: the std.spec ones (test_<module>.ae,
# run with `ae run` so each module's @source C/ObjC is compiled in) and the
# shell one for tools/mkapp.sh.
#
#   test/run_tests.sh                 # all
#   test/run_tests.sh fsevents trash  # just these
#
# MACAE_HEADLESS is set so nothing launches Finder, an app or System
# Settings: the workspace/fda suites assert the refusal. Exit status: 0 only
# if every suite passed.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
export MACAE_HEADLESS=1
SUITES=(sysinfo iopolicy attrlist fsevents volume trash defaults workspace fda keychain power quicklook bundle mkapp)
[ $# -gt 0 ] && SUITES=("$@")

cd "$HERE"
fail=0
for s in "${SUITES[@]}"; do
    log="$(mktemp)"
    if [ "$s" = "mkapp" ]; then
        if ./test_mkapp.sh > "$log" 2>&1; then
            echo "  OK   mac.mkapp ($(grep -c 'PASS:' "$log") passing)"
        else
            echo "  FAIL mac.mkapp"; grep 'FAIL' "$log" | sed 's/^/       /'; fail=$((fail + 1))
        fi
        rm -f "$log"; continue
    fi
    if AETHER_LIB_DIR="$ROOT" ae run "test_${s}.ae" > "$log" 2>&1; then
        pass="$(grep -a -o '[0-9]* passing' "$log" | tail -1)"
        skipped="$(grep -a -c '⊘' "$log")"
        note=""; [ "$skipped" -gt 0 ] && note=", skipped: $(grep -a '⊘' "$log" | head -1 | sed -e 's/.*⊘ *//' -e 's/\x1b\[[0-9;]*m//g')"
        echo "  OK   mac.${s} (${pass:-no count}${note})"
    else
        echo "  FAIL mac.${s}"
        grep -a -v '^warning\|-->\|^ *[0-9]* |\|^ *|\|help:' "$log" | tail -25 | sed 's/^/       /'
        fail=$((fail + 1))
    fi
    rm -f "$log"
done
exit $fail
