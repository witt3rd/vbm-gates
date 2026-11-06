#!/usr/bin/env bash
# The shared negative test of ran-evidence: a refused tool, a missing one, a timeout, a silent exit 0, a zero count and a SKIPPED line each FAIL, and one clean case passes (the control of each).
# Hermetic: every log, map and fixture is built in the test's own sandbox.
. "$(dirname "$0")/lib.sh"; sandbox
ev=$ROOT/core/ran-evidence.sh; lib=$ROOT/core/lib-ran.sh; run=$ROOT/core/run-tests-parallel.sh
mklog() { printf '%b' "$2" > "$T/$1.log"; }
chk() { "$ev" check "$1" "$T/$1.log" 2>&1; }   # chk NAME: the reader on $T/NAME.log (what it said goes to stdout)
# 1. the reader: check
mklog good 'hello\nran: x: 7 cases\n'; chk good >/dev/null && ok || { echo "FAIL: check rejected a log with evidence" >&2; exit 1; }
mklog none 'hello\nok\n'; must_fail "no ran line" chk none; grep -q 'no .ran: NAME: N cases. line' <<<"$MUST_FAIL_ERR" || { echo "FAIL: check did not say why: $MUST_FAIL_ERR" >&2; exit 1; }
mklog zero 'ran: x: 0 cases\n'; must_fail "zero cases" chk zero
mklog skip 'x: SKIPPED: a tool was not found\nran: x: 3 cases\n'; must_fail "a SKIPPED check" chk skip
mklog skipall 'x: SKIPPED: a tool was not found\n'; must_fail "a wholly skipped script" chk skipall
out=$(VBM_ALLOW_SKIP=1 chk skipall) && grep -q 'NOT RUN' <<<"$out" && ok || { echo "FAIL: VBM_ALLOW_SKIP=1 did not allow, loudly, a wholly skipped script" >&2; exit 1; }
mklog garbled 'ran: x: many cases\nran:x: 3 cases\n'; must_fail "malformed evidence line" chk garbled
# 2. the gate wrapper: gate NAME REGEX CMD...
refuse() { echo "refused by a guard: run this elsewhere." >&2; exit 126; }; export -f refuse
must_fail "gate: command refused by a guard" "$ev" gate g 'n=([0-9]+)' bash -c refuse
must_fail "gate: exit 0 and no count (the vacuous pass)" "$ev" gate g 'n=([0-9]+)' true
must_fail "gate: a count of zero" "$ev" gate g 'n=([0-9]+)' echo n=0
[ "$("$ev" gate g 'n=([0-9]+)' echo n=5 2>&1 | tail -n1)" = "ran: g: 5 cases" ] && ok || { echo "FAIL: gate did not print the evidence line for a command that ran" >&2; exit 1; }
# 3. check-dir: the gate logs of a directory against a map of `NAME REGEX`
mkdir "$T/cd"; printf 'a ^ledger: [0-9]+ proved of ([0-9]+)$\n' > "$T/cd.map"; printf 'ledger: 3 proved of 9\n' > "$T/cd/a.log"; printf 'hi\nran: b: 2 cases\n' > "$T/cd/b.log"
"$ev" check-dir "$T/cd" "$T/cd.map" >"$T/o" 2>&1 && grep -qx 'ran: a: 9 cases' "$T/o" && ok || { echo "FAIL: check-dir rejected logs that carry evidence: $(cat "$T/o")" >&2; exit 1; }
printf 'nothing to see\n' > "$T/cd/c.log"; must_fail "check-dir: a log with no evidence" "$ev" check-dir "$T/cd" "$T/cd.map"; rm "$T/cd/c.log"
printf 'ledger: 3 proved of 0\n' > "$T/cd/a.log"; must_fail "check-dir: a zero count" "$ev" check-dir "$T/cd" "$T/cd.map"
: > "$T/cd/a.log"; must_fail "check-dir: an empty (refused) log" "$ev" check-dir "$T/cd" "$T/cd.map"
# 4. must_fail itself (core/lib-ran.sh): the expected failure must be a real one; a refusal, a missing tool and a timeout are not
mf() {  # mf DESC EXPECT(0|1) BODY: BODY runs under must_fail in its own shell; EXPECT 1 = the self-test itself must be FAILED by it
  local want=$2 rc=0
  printf '#!/usr/bin/env bash\nset -euo pipefail\n. %s\nmust_fail probe bash -c %q\nran_done probe\n' "$lib" "$3" > "$T/mf.sh"
  TMPDIR=$T bash "$T/mf.sh" >"$T/mf.out" 2>"$T/mf.err" || rc=$?
  if [ "$want" = 1 ]; then { [ "$rc" != 0 ] && ! grep -q '^ran: probe' "$T/mf.out"; } && ok || { echo "FAIL must_fail ($1): passed (rc=$rc) where it must not count: $(cat "$T/mf.err")" >&2; exit 1; }
  else { [ "$rc" = 0 ] && grep -q '^ran: probe: 1 cases' "$T/mf.out"; } && ok || { echo "FAIL must_fail ($1): a real failure with a reason was not accepted (rc=$rc): $(cat "$T/mf.err")" >&2; exit 1; }; fi
}
mf "a real failure that says why" 0 'echo "the check failed: bad row" >&2; exit 1'
mf "the command succeeded" 1 'exit 0'
mf "silent failure" 1 'exit 1'
mf "refused by a guard (exit 126)" 1 'echo "heavy: run this elsewhere." >&2; exit 126'
mf "a refusal that exits 1 with the guard message" 1 'echo "heavy: run this elsewhere" >&2; exit 1'
mf "command not found (exit 127)" 1 'echo "no such tool" >&2; exit 127'
mf "a timeout (exit 124)" 1 'echo "timed out" >&2; exit 124'
must_fail "ran_done with no case" env TMPDIR="$T" bash -c ". '$lib'; ran_done empty"
# 5. the runner fails a script that exits 0 without evidence, with zero cases, or that SKIPS; it passes one with evidence
mk() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$T/$1.sh"; }
mk evok 'echo "ran: evok: 2 cases"'; mk evnone 'echo fine'; mk evzero 'echo "ran: evzero: 0 cases"'; mk evskip 'echo "x: SKIPPED: no tool"; echo "ran: evskip: 1 cases"'
"$run" "$T/evok.sh" >"$T/r.out" 2>&1 && grep -q '^ran: tests: 2 cases' "$T/r.out" && ok || { echo "FAIL: the runner rejected a script with evidence: $(cat "$T/r.out")" >&2; exit 1; }
for s in evnone evzero evskip; do
  must_fail "runner: $s" "$run" "$T/evok.sh" "$T/$s.sh"; grep -q "FAIL .*$s.sh: exit 0 but no ran-evidence" <<<"$MUST_FAIL_ERR" || { echo "FAIL: the runner did not name $s: $MUST_FAIL_ERR" >&2; exit 1; }
done
finish ran_evidence
