ATK_DESC="an approval whose hash is the hash of another diff must relax nothing (the judge recomputes the hash itself)"
ATK_GATES=('l=$(mktemp); h=$(. scripts/land/lib/approvals.sh; ga_hash . "$ATK_BASE" HEAD "$TIER1"); printf "%s %s\n" "$TIER1" "$(printf x | sha256sum | cut -d\  -f1)" > "$l"; LAND_GATE_APPROVED_FILE=$l $G/core/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD; rc=$?; rm -f "$l"; exit $rc'); ATK_GATE_FILES=("$G/core/gate-diff-improving.sh")
atk_na() { ( . "$G/core/gates-conf.sh"; gates_load; case " $GATES_APPROVABLE " in *" $TIER1 "*) exit 1;; *) exit 0;; esac ); }   # n/a unless the repository makes its tier1 script approvable
atk_apply() { n=$(awk '$0 !~ /^[[:space:]]*(#|$)/ {n = NR} END {print n}' "$TIER1"); sed -i "${n}s|\$| # edited|" "$TIER1"; }
