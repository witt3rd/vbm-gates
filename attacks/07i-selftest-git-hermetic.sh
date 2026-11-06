ATK_DESC="neuter core/git-hermetic.sh (a sourced library that exits: the self-tests that source it end with success, which is not a pass) (a stub that always succeeds): its self-test tests/test_git_hermetic.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_git_hermetic.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_git_hermetic.sh")
atk_apply() { neuter "$G/core/git-hermetic.sh"; }
