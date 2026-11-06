#!/usr/bin/env bash
# lean/axiom-gate.sh with a real Lean toolchain (the Lean leg: tests/run-lean.sh; hosted CI's second job, or a box with the pinned toolchain). A scratch lake project built in the sandbox (own lakefile, a
# library Fx, a proofs library FxProofs, a library FxOther): the clean library passes and its --selftest (the shared walk against Lean's collectAxioms on real and planted constants; four broken walks are caught)
# passes; a non-standard axiom under a configured root FAILS and is named; the same axiom under a root that is not configured is not checked; no roots, an unreadable conf and a stubbed gate cannot pass.
. "$(dirname "$0")/../lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL axiom-gate: $*" >&2; exit 1; }
command -v lake >/dev/null 2>&1 && lake --version >/dev/null 2>&1 || { echo "FAIL axiom-gate: no usable lake on PATH: this is the Lean leg (a box without the toolchain must not report it as passed)" >&2; exit 1; }
world() {   # world: the package's code and a lake project with three libraries, built
  cd "$T"; rm -rf w; newrepo w; cd w; mkdir -p scripts/land Fx FxProofs FxOther
  cp -r "$ROOT/core" "$ROOT/lean" "$ROOT/KEYS" .; cp -r "$LANDLIB" scripts/land/lib
  printf 'import Lake\nopen Lake DSL\npackage fx\nlean_lib Fx where\n  globs := #[.andSubmodules `Fx]\nlean_lib FxProofs where\n  globs := #[.andSubmodules `FxProofs]\nlean_lib FxOther where\n  globs := #[.andSubmodules `FxOther]\n' > lakefile.lean
  printf 'import Fx.A\n' > Fx.lean; printf 'def f (x : Nat) : Nat := x + 1\n' > Fx/A.lean
  printf 'import Fx\nimport FxProofs.B\n' > FxProofs.lean; printf 'import Fx.A\ntheorem t (p : Prop) : p ∨ ¬p := Classical.em p\ntheorem u : f 1 = 2 := rfl\n' > FxProofs/B.lean
  printf 'import FxOther.C\n' > FxOther.lean; printf 'def g : Nat := 0\n' > FxOther/C.lean
  printf 'GATES_AXIOM_ROOTS=Fx FxProofs\n' > scripts/gates.conf
}
build() { local o; o=$(lake build Fx FxProofs FxOther 2>&1) || fail "the fixture library does not build: $(tail -n 5 <<<"$o")"; }
gate() { lean/axiom-gate.sh "$@" 2>&1; }
world; build; out=$(gate --selftest) && grep -q '^ran: axiom-gate: [1-9][0-9]* cases' <<<"$out" && grep -q 'differential test ok' <<<"$out" && grep -q 'negative self-test ok' <<<"$out" && ok || fail "the clean library did not pass with its self-tests: $out"
# a non-standard axiom under a configured root is named; under a root that is not configured it is not checked
printf 'import Fx\naxiom badAx : False\ntheorem usesBad : 1 = 2 := badAx.elim\n' > FxProofs/Bad.lean; printf 'import Fx\nimport FxProofs.B\nimport FxProofs.Bad\n' > FxProofs.lean
lake build FxProofs >/dev/null 2>&1 || fail "the bad fixture does not build"; must_fail "a non-standard axiom under a configured root" gate; grep -q 'badAx' <<<"$MUST_FAIL_ERR" || fail "the offender is not named: $MUST_FAIL_ERR"
printf 'GATES_AXIOM_ROOTS=Fx\n' > scripts/gates.conf; gate >/dev/null && ok || fail "an axiom under a root that is not configured was checked"
printf 'axiom otherAx : False\ntheorem o : 1 = 2 := otherAx.elim\n' >> FxOther/C.lean; printf 'GATES_AXIOM_ROOTS=Fx FxOther\n' > scripts/gates.conf; lake build FxOther >/dev/null 2>&1; must_fail "the same shape under another configured root" gate; grep -q 'otherAx' <<<"$MUST_FAIL_ERR" || fail "the second root's offender is not named: $MUST_FAIL_ERR"
# cannot decide
printf 'GATES_AXIOM_ROOT=Fx\n' > scripts/gates.conf; rc=0; gate >/dev/null || rc=$?; [ "$rc" = 2 ] && ok || fail "an unknown key did not exit 2 (rc=$rc)"
: > scripts/gates.conf; rc=0; gate >/dev/null || rc=$?; [ "$rc" = 2 ] && ok || fail "an empty root list did not exit 2 (rc=$rc)"
printf 'GATES_AXIOM_ROOTS=NoSuchLib\n' > scripts/gates.conf; must_fail "a root that cannot be imported" gate
# a stubbed gate prints no count: it cannot pass
printf 'GATES_AXIOM_ROOTS=Fx\n' > scripts/gates.conf; printf 'def main : IO UInt32 := pure 0\n' > lean/AxiomGate.lean; must_fail "a stub that always succeeds" gate; grep -q 'no line matching' <<<"$MUST_FAIL_ERR" || fail "a stubbed gate was not refused for its missing count: $MUST_FAIL_ERR"
finish axiom_gate
