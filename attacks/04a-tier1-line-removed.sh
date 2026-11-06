ATK_DESC="delete the last command line of the tier1 script (a step that ran is gone)"
ATK_GATES=('$G/core/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=("$G/core/gate-diff-improving.sh")
atk_apply() { n=$(awk '$0 !~ /^[[:space:]]*(#|$)/ {n = NR} END {print n}' "$TIER1"); sed -i "${n}d" "$TIER1"; }
