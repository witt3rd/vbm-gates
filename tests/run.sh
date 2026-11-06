#!/usr/bin/env bash
# Tier 1 of this repository: the lints, the vendored lander's drift check, then every tests/test_*.sh in parallel (each in its own scratch world). Run from anywhere.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); out=$(mktemp -d "${TMPDIR:-/tmp}/gates-run.XXXXXX")
pids=(); trap 'for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$out"' EXIT
"$here/lint.sh"; "$here/../scripts/land/bin/land-check"
names=(); for t in "$here"/test_*.sh; do n=$(basename "$t"); names+=("$n"); timeout --kill-after=10 300 "$t" >"$out/$n.log" 2>&1 & pids+=($!); done
fails=0; cases=0
for i in "${!pids[@]}"; do   # ran-evidence: a script that exits 0 must have printed `ran: NAME: N cases` (N > 0) and no SKIPPED line
  n=${names[$i]}; rc=0; wait "${pids[$i]}" || rc=$?   # read the log only after the job ended
  c=$(sed -nE 's/^ran: [A-Za-z0-9_.-]+: ([0-9]+) cases$/\1/p' "$out/$n.log" | awk '{t += $1} END {print t + 0}')
  if [ "$rc" = 0 ] && ! grep -qE '(^|[^A-Za-z])SKIPPED' "$out/$n.log" && [ "$c" -gt 0 ]; then echo "ok    $n: $c cases"; cases=$((cases + c))
  else fails=$((fails + 1)); echo "FAILED $n" >&2; tail -30 "$out/$n.log" >&2; fi
done
[ "$fails" = 0 ] || { echo "tests/run.sh: $fails test script(s) failed" >&2; exit 1; }
echo "tests/run.sh: all test scripts passed"; echo "ran: tests: $cases cases"
