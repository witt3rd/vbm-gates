ATK_DESC="neuter lean/AxiomGate.lean (a gate that checks nothing): its Lean-leg test tests/lean/test_axiom_gate.sh must FAIL (a gate whose self-test cannot fail)"; ATK_LEAN=1
ATK_GATES=('o=$($G/tests/lean/test_axiom_gate.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/lean/test_axiom_gate.sh")
atk_apply() { neuter "$G/lean/AxiomGate.lean"; }
