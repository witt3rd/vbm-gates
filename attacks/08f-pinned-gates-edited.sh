ATK_DESC="patch the pinned gate set in place (a local edit of its judge): the drift check must refuse (only where the gates are vendored)"
ATK_GATES=(scripts/land/bin/land-check); ATK_GATE_FILES=(scripts/land/bin/land-check)
atk_na() { [ "$G" = . ]; }   # not applicable in the package's own repository, where the gates are not a pin
atk_apply() { echo '# local patch' >> scripts/gates/core/gate-diff-improving.sh; }
