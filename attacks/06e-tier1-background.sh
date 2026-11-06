ATK_DESC="add a masked or unchecked step to the tier1 script: gate-check &"
ATK_GATES=('$G/core/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=("$G/core/gate-diff-improving.sh")
atk_apply() { add_before_end "$TIER1" 'gate-check &'; }
