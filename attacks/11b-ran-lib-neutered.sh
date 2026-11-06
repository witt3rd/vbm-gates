ATK_DESC="neuter core/lib-ran.sh (a sourced library that exits ends every test with success, evidence or not) (a stub that always succeeds): its self-test tests/test_ran_evidence.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_ran_evidence.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_ran_evidence.sh")
atk_apply() { neuter "$G/core/lib-ran.sh"; }
