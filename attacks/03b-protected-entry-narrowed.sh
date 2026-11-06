ATK_DESC="narrow the first entry of the protected list (a directory to one file, anything else to a different path)"
ATK_GATES=('$G/core/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=("$G/core/gate-diff-improving.sh")
atk_apply() { n=$(first_line_matching "$PLIST" "[^[:space:]]"); sed -i "${n}{s|/\$|/narrowed.txt|;t;s|\$|.narrowed|}" "$PLIST"; }
