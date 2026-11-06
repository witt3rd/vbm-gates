#!/usr/bin/env bash
# lean/lean-scan.sh: roots come from gates.conf; it passes a clean library and FAILS on a forbidden construct (each word, in a nested file and in an umbrella file), on an import outside Init and the
# module's own root (Std, Lean, another root, prelude, a prefix-alike root), while a `-- tier1-allow` comment and a proofs-root import of Lean pass; an empty GATES_SCAN_DIRS or an unreadable conf cannot
# decide (exit 2). Hermetic: the package's code and a synthetic Lean source tree and conf are built in the sandbox.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL lean-scan: $*" >&2; exit 1; }
world() {   # world: a scratch repository with the package's code, a spec root (Lib) and a proofs root (LibProofs)
  cd "$T"; rm -rf w; newrepo w; cd w; mkdir -p scripts/land Lib LibProofs
  cp -r "$ROOT/core" "$ROOT/lean" "$ROOT/KEYS" .; cp -r "$LANDLIB" scripts/land/lib
  printf 'GATES_SCAN_DIRS=Lib LibProofs\nGATES_SPEC_ROOTS=Lib\n' > scripts/gates.conf
  printf 'import Lib.State\n' > Lib.lean; printf 'def f (x : Nat) : Nat := x\n' > Lib/State.lean; printf 'import Lib.State\nimport Lean\ntheorem t : True := trivial\n' > LibProofs/P.lean
  git add -A; git commit -qm world
}
scan() { git add -A; lean/lean-scan.sh 2>&1; }
world; out=$(scan) && grep -q '^ran: lean-scan: ' <<<"$out" && ok || fail "the clean library does not pass: $out"
for w in sorry admit axiom unsafe implemented_by csimp; do world; printf 'theorem u : True := by %s\n' "$w" > Lib/Bad.lean; must_fail "forbidden $w in a nested file" scan; grep -q 'Lib/Bad.lean' <<<"$MUST_FAIL_ERR" || fail "the hit does not name the file: $MUST_FAIL_ERR"; done
world; printf 'theorem u : True := by sorry\n' > Lib.lean; must_fail "forbidden word in the umbrella file" scan
world; printf 'theorem u : True := by sorry\n' > LibProofs/Q.lean; must_fail "forbidden word in the proofs root" scan
world; printf -- '-- a comment that says sorry -- tier1-allow\n' > Lib/Note.lean; scan >/dev/null && ok || fail "the tier1-allow marker was not honoured"
for imp in 'import Std.Data.HashMap' 'import Lean' 'import LibProofs.P' 'prelude' 'public import Lean.Data.Json' 'import LibX'; do world; printf '%s\n' "$imp" > Lib/Imp.lean; must_fail "spec module imports: $imp" scan; done
world; printf 'import Lib.State\nimport Lib.Other\n' > Lib/Ok.lean; scan >/dev/null && ok || fail "an import of the library's own root was refused"
world; : > scripts/gates.conf; printf 'GATES_SPEC_ROOTS=Lib\n' > scripts/gates.conf; rc=0; scan >/dev/null || rc=$?; [ "$rc" = 2 ] && ok || fail "an empty GATES_SCAN_DIRS did not exit 2 (rc=$rc)"
world; printf 'GATES_SCAN_DIR=Lib\n' > scripts/gates.conf; rc=0; scan >/dev/null || rc=$?; [ "$rc" = 2 ] && ok || fail "an unknown key did not exit 2 (rc=$rc)"
finish lean_scan
