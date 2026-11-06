ATK_DESC="neuter core/protected-set.sh (a stub that always succeeds): its self-test tests/test_protected_set.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_protected_set.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_protected_set.sh")
atk_apply() { neuter "$G/core/protected-set.sh"; }
