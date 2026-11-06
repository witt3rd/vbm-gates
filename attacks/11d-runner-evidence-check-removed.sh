ATK_DESC="remove the ran-evidence check from core/run-tests-parallel.sh (a test that exits 0 with no evidence passes again): its test must FAIL"
ATK_GATES=('o=$($G/tests/test_ran_evidence.sh 2>&1); rc=$?; tail -n3 <<<"$o"; [ $rc = 0 ] && grep -qE "^ran: [a-z_]+: [1-9][0-9]* cases$" <<<"$o"'); ATK_GATE_FILES=("$G/tests/test_ran_evidence.sh")
atk_apply() { sed -i 's|"\$ev" check "\$s"|true "$s"|' "$G/core/run-tests-parallel.sh"; }
