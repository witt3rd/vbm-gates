#!/usr/bin/env bash
# The axiom gate (lean/AxiomGate.lean) with its module roots from gates.conf (GATES_AXIOM_ROOTS): every constant of the library's modules may depend only on propext, Classical.choice and Quot.sound.
#   lean/axiom-gate.sh [--selftest]    run in the repository, under the toolchain (mise exec -- ..., or lake on PATH). --selftest adds the negative self-test and the differential test against Lean's own
#                                      collectAxioms (AXIOM_DIFF_FULL=1: every constant, not a sample). Prints `ran: axiom-gate: N cases` (N = constants checked); a gate that checked none FAILS.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); . "$here/../core/gates-conf.sh"
gates_load || { echo "axiom-gate: gates.conf cannot be read (above): cannot decide" >&2; exit 2; }
[ -n "$GATES_AXIOM_ROOTS" ] || { echo "axiom-gate: GATES_AXIOM_ROOTS is empty: no library to check (set it, or do not run this gate)" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"
export AXIOM_ROOTS=$GATES_AXIOM_ROOTS
"$here/../core/ran-evidence.sh" gate axiom-gate 'axiom gate: ([0-9]+) constants checked' lake env lean --run "$here/AxiomGate.lean" "$@"
