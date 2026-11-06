ATK_DESC="neuter lean/check-zero-warning.sh (the original defect in another form: a check that cannot fail) (a stub that always succeeds): its self-test tests/test_zero_warning.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_zero_warning.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_zero_warning.sh")
atk_apply() { neuter "$G/lean/check-zero-warning.sh"; }
