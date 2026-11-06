ATK_DESC="neuter lean/lean-scan.sh (a stub that always succeeds): its self-test tests/test_lean_scan.sh must FAIL (a gate whose self-test cannot fail)"
ATK_GATES=('o=$($G/tests/test_lean_scan.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_lean_scan.sh")
atk_apply() { neuter "$G/lean/lean-scan.sh"; }
