#!/usr/bin/env bash
# Run every .asm in the hang-suite under a wall-clock timeout and
# report what each one does. This is how a caller would test a
# tool-integration's resilience against malicious/buggy inputs.
#
# Usage: ./run.sh [timeout_seconds] [fasmg_path]
# Default: 5s timeout, ../../fasmg.exe.

set -u

TIMEOUT_S="${1:-5}"
FASMG_DEFAULT="$(cd "$(dirname "$0")/../.." && pwd)/fasmg.exe"
FASMG="${2:-$FASMG_DEFAULT}"

if [[ ! -x "$FASMG" ]]; then
    echo "fasmg binary not found at: $FASMG" >&2
    exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

printf "%-42s %-10s %7s %12s  %s\n" "test" "outcome" "time(s)" "outsize" "last-line"
printf "%-42s %-10s %7s %12s  %s\n" "----" "-------" "-------" "-------" "---------"

run_one() {
    local src="$1"
    local rel="${src#$HERE/}"
    local outfile="$TMP/$(basename "$src").out"
    local logfile="$TMP/$(basename "$src").log"

    local t0=$(date +%s.%N 2>/dev/null || date +%s)
    timeout --kill-after=2 "$TIMEOUT_S" "$FASMG" "$src" "$outfile" >"$logfile" 2>&1
    local rc=$?
    local t1=$(date +%s.%N 2>/dev/null || date +%s)

    local elapsed
    elapsed=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.2f", b-a}')

    local outsize="-"
    [[ -f "$outfile" ]] && outsize=$(wc -c <"$outfile" | tr -d ' ')

    local outcome
    case $rc in
        0)    outcome="OK" ;;
        124)  outcome="TIMEOUT" ;;
        137)  outcome="KILLED" ;;
        1|2|3) outcome="ERROR-$rc" ;;
        *)    outcome="RC-$rc" ;;
    esac

    local last
    last=$(tail -n 1 "$logfile" 2>/dev/null | tr -d '\r')
    [[ -z "$last" ]] && last="(no output)"

    printf "%-42s %-10s %7s %12s  %s\n" "$rel" "$outcome" "$elapsed" "$outsize" "$last"
}

# Process each .asm, skipping companion files (b.asm in include-cycle).
find "$HERE" -name '*.asm' -type f \
  | grep -v '/include-cycle/b\.asm$' \
  | sort \
  | while read -r src; do
        run_one "$src"
    done
