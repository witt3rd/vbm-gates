ATK_DESC="neuter core/gate-diff-improving.sh (a stub that always succeeds): its self-test tests/test_gate_diff_improving.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_gate_diff_improving.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_gate_diff_improving.sh")
atk_apply() { neuter "$G/core/gate-diff-improving.sh"; }
