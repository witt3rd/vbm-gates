ATK_DESC="add a masked or unchecked step to the tier1 script: if gate-check; then :; fi"
ATK_GATES=('$G/core/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=("$G/core/gate-diff-improving.sh")
atk_apply() { add_before_end "$TIER1" 'if gate-check; then :; fi'; }
