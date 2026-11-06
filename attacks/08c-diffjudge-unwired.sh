ATK_DESC="remove the gate-diff judge's call from the post-rebase hook"
ATK_GATES=('$G/core/relabel-attacks.sh --check-wired'); ATK_GATE_FILES=("$G/core/relabel-attacks.sh")
atk_apply() { sed -i "/gate-diff-improving/d" "$G/hooks/post-rebase"; }
