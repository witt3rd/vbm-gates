#!/usr/bin/env bash
# core/run-tests-parallel.sh runs scripts concurrently, in separate TMPDIRs, and can fail: a failing script, a missing script, a script the runner silently skipped, a script listed twice and an
# empty list each fail the run and name the script; the failing script's log is printed; a clean run passes. Hermetic: every fixture is built in the test's own sandbox.
. "$(dirname "$0")/lib.sh"; sandbox
unset TEST_JOBS   # a caller may cap the parallelism; this test is about running in parallel
run=$ROOT/core/run-tests-parallel.sh
mk() { printf '#!/usr/bin/env bash\n%s\necho "ran: %s: 1 cases"\n' "$2" "$1" > "$T/$1.sh"; }   # a passing fixture carries its ran-evidence line
# two scripts that each wait for the OTHER's marker can only finish when they run at the same time (no timing involved; a serial run times out and fails)
mk ping 'touch "$0.up"; for i in $(seq 100); do [ -e "'"$T"'/pong.sh.up" ] && break; sleep 0.1; done; [ -e "'"$T"'/pong.sh.up" ] || { echo "never saw pong" >&2; exit 1; }'
mk pong 'touch "$0.up"; for i in $(seq 100); do [ -e "'"$T"'/ping.sh.up" ] && break; sleep 0.1; done; [ -e "'"$T"'/ping.sh.up" ] || { echo "never saw ping" >&2; exit 1; }'
mk tmpd 'd=$(mktemp -d); case "$d" in "$TMPDIR"/*) ;; *) echo "mktemp left TMPDIR: $d" >&2; exit 9;; esac'   # its mktemp lands in its own TMPDIR
mk bad 'echo boom-from-bad >&2; exit 3'
mk skipme 'echo never-runs'
# an xargs that silently drops the script named skipme (a runner that loses a script): the runner must notice there is no result for it
mkdir "$T/bin"; real=$(command -v xargs)
printf '#!/usr/bin/env bash\ntr "\\0" "\\n" | grep -v skipme | tr "\\n" "\\0" | %s "$@"\n' "$real" > "$T/bin/xargs"; chmod +x "$T/bin/xargs"
# 1. a clean run, in parallel, each in its own TMPDIR, reported
"$run" "$T/ping.sh" "$T/pong.sh" "$T/tmpd.sh" > "$T/out" 2>&1 && ok || { echo "FAIL: a clean run failed: $(cat "$T/out")" >&2; exit 1; }
grep -q 'ok   .*ping.sh' "$T/out" && grep -q '3 scripts passed' "$T/out" && grep -q '^ran: tests: 3 cases' "$T/out" && ok || { echo "FAIL: the clean run did not report all three: $(cat "$T/out")" >&2; exit 1; }
# 2. a failing script fails the run, is named, and its log is printed; the others still ran
must_fail "failing script" "$run" "$T/tmpd.sh" "$T/bad.sh"
grep -q 'FAIL .*bad.sh: exit 3' <<<"$MUST_FAIL_ERR" && grep -q 'boom-from-bad' <<<"$MUST_FAIL_ERR" && grep -q 'ok   .*tmpd.sh' <<<"$MUST_FAIL_ERR" && ok || { echo "FAIL: not reported with its log: $MUST_FAIL_ERR" >&2; exit 1; }
# 3. a missing script, 4. a silently skipped script
must_fail "missing script" "$run" "$T/tmpd.sh" "$T/nothere.sh"; grep -q 'FAIL .*nothere.sh: no such script' <<<"$MUST_FAIL_ERR" && ok || { echo "FAIL: missing script not named: $MUST_FAIL_ERR" >&2; exit 1; }
must_fail "silently skipped script" env PATH="$T/bin:$PATH" "$run" "$T/tmpd.sh" "$T/skipme.sh"; grep -q 'FAIL .*skipme.sh: no result' <<<"$MUST_FAIL_ERR" && ok || { echo "FAIL: skipped script not reported: $MUST_FAIL_ERR" >&2; exit 1; }
# 5. a duplicate and an empty list are refused
must_fail "a script listed twice" "$run" "$T/tmpd.sh" "$T/tmpd.sh"
must_fail "an empty list" "$run"
finish run_parallel
