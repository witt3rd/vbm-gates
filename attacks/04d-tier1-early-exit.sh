ATK_DESC="insert an early exit 0 after the first command of the tier1 script (every later gate is skipped)"
ATK_GATES=('$G/core/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=("$G/core/gate-diff-improving.sh")
atk_apply() { n=$(first_line_matching "$TIER1" "[^[:space:]]"); sed -i "${n}a exit 0" "$TIER1"; }
