ATK_DESC="neuter core/lint-pipefail.sh (a stub that always succeeds): its self-test tests/test_lint_pipefail.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_lint_pipefail.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_lint_pipefail.sh")
atk_apply() { neuter "$G/core/lint-pipefail.sh"; }
