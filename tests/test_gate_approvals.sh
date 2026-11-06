#!/usr/bin/env bash
# The one approval rule: THE JUDGE RECOMPUTES THE HASH. A landing that consumes an exact-diff approval ($LAND_GATE_APPROVED_FILE: `FILE HASH` per line) relaxes only the removed and changed lines of an
# approvable file (and the wrong-way move of an `approvable` baseline row), and only when the hash is also what the judge computes for the diff it is judging. Every attack on it is refused: a hash over
# another diff, an approval naming another file, a file that is not approvable, an empty, missing or unreadable list, an approval that carries a masked added line, a list or source file, a row that is not
# approvable, a mixed move. Hermetic: the world, the approvals list and the hashes are built here with the lander's own ga_hash.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
gdi=$ROOT/core/gate-diff-improving.sh
fail() { echo "FAIL gate-approvals: $*" >&2; exit 1; }
hash() { ( . "$LANDLIB/approvals.sh"; ga_hash . "$base" HEAD "$@" ); }   # the hash of the working tree's diff of FILE against the base (committed first)
# prep NAME APPROVAL-LINES...: commit the working tree as the head, write the approvals list, run the judge; sets JRC and JOUT; resets the tree
run() { local n=$1 list=$2; shift 2; git add -A; git commit -qm "$n" --allow-empty; JOUT=$(LAND_GATE_APPROVED_FILE=$list "$gdi" --conf "$T/gates.conf" "$base" HEAD 2>&1) && JRC=0 || JRC=$?; }
want() { [ "$JRC" = "$1" ] && ok || fail "$2: expected exit $1, got $JRC: $JOUT"; }
gdi_world t1.sh pin.txt b/ledger.txt
# an edit of the tier1 script: a changed line (echo a -> echo a2)
edit_t1() { sed -i 's/^echo a$/echo a2/' t1.sh; }
edit_t1; git add -A; git commit -qm e; h=$(hash t1.sh); git reset -q --hard "$base"; edit_t1
printf 't1.sh %s\n' "$h" > "$T/ok.list"; run "an approved changed line" "$T/ok.list"; want 0 "a correct approval"; grep -q 'recomputed' <<<"$JOUT" || fail "the verdict does not say it recomputed: $JOUT"; git reset -q --hard "$base"
edit_t1; run "no list" ""; want 1 "no approvals list at all"; git reset -q --hard "$base"
edit_t1; run "missing list" "$T/nothing.list"; want 1 "a missing list"; git reset -q --hard "$base"
: > "$T/empty.list"; edit_t1; run "empty list" "$T/empty.list"; want 1 "an empty list"; git reset -q --hard "$base"
printf 't1.sh %s\n' "$(printf 'x' | sha256sum | cut -c1-64)" > "$T/wrong.list"; edit_t1; run "hash over another diff" "$T/wrong.list"; want 1 "a hash that is not the diff's"; git reset -q --hard "$base"
printf 'pin.txt %s\n' "$h" > "$T/other.list"; edit_t1; run "approval names another file" "$T/other.list"; want 1 "an approval naming another file"; git reset -q --hard "$base"
printf 't1.sh %s\n' "$h" > "$T/ok2.list"
edit_t1; echo 'echo b || true' >> t1.sh; git add -A; git commit -qm e; hm=$(hash t1.sh); git reset -q --hard "$base"   # an approval of EXACTLY the diff that carries a masked added line: the removed line is relaxed, the added one is still judged
edit_t1; echo 'echo b || true' >> t1.sh; printf 't1.sh %s\n' "$hm" > "$T/masked.list"; run "approved edit with a masked added line" "$T/masked.list"; want 1 "a masked line carried by an approved edit"; grep -q 'weakening' <<<"$JOUT" || fail "the masked line is not named: $JOUT"; git reset -q --hard "$base"
edit_t1; echo 'echo b' >> t1.sh; run "approved edit plus a different plain step" "$T/ok2.list"; want 1 "a diff that is not the approved one (a step added)"; git reset -q --hard "$base"
# the hash is bound to the file as it was: the same edit one commit later still matches only if the diff is identical
edit_t1; git add -A; git commit -qm e2; b1=$(git rev-parse HEAD); printf 'echo c\n' >> t1.sh; run "a later commit changes the diff" "$T/ok2.list"; want 1 "an approval for the earlier diff"; git reset -q --hard "$base"
# not approvable: a gate source file, a list, a baseline row that is not approvable, a file outside GATES_APPROVABLE
echo y >> gate.sh; git add -A; git commit -qm e; hs=$(hash gate.sh); git reset -q --hard "$base"; echo y >> gate.sh; printf 'gate.sh %s\n' "$hs" > "$T/src.list"; run "gate source with its approval" "$T/src.list"; want 1 "an approved gate source file"; git reset -q --hard "$base"
echo y >> lists.txt; git add -A; git commit -qm e; hl=$(hash lists.txt); git reset -q --hard "$base"; echo y >> lists.txt; printf 'lists.txt %s\n' "$hl" > "$T/l.list"; run "list with its approval" "$T/l.list"; want 1 "an approved list"; git reset -q --hard "$base"
sed -i 's/open 3/open 4/' b/ledger.txt; git add -A; git commit -qm e; hb=$(hash b/ledger.txt); git reset -q --hard "$base"; sed -i 's/open 3/open 4/' b/ledger.txt; printf 'b/ledger.txt %s\n' "$hb" > "$T/b.list"; run "a row that is not approvable" "$T/b.list"; want 1 "an approved rise of a row that is not approvable"; git reset -q --hard "$base"
# an approvable baseline row (the share fell 2/3 -> 1/2) is approved; the same with another row moving the wrong way is not
sed -i 's/share 2 3/share 1 2/' b/ledger.txt; git add -A; git commit -qm e; hb=$(hash b/ledger.txt); git reset -q --hard "$base"; sed -i 's/share 2 3/share 1 2/' b/ledger.txt; printf 'b/ledger.txt %s\n' "$hb" > "$T/b.list"; run "approvable share fall" "$T/b.list"; want 0 "an approved fall of an approvable row"; git reset -q --hard "$base"
sed -i 's/share 2 3/share 1 2/; s/open 3/open 4/' b/ledger.txt; git add -A; git commit -qm e; hb=$(hash b/ledger.txt); git reset -q --hard "$base"; sed -i 's/share 2 3/share 1 2/; s/open 3/open 4/' b/ledger.txt; printf 'b/ledger.txt %s\n' "$hb" > "$T/b.list"; run "a mixed move" "$T/b.list"; want 1 "an approval that also covers a row that is not approvable"; git reset -q --hard "$base"
printf 'brand 1\n' >> b/ledger.txt; sed -i 's/share 2 3/share 1 2/' b/ledger.txt; git add -A; git commit -qm e; hb=$(hash b/ledger.txt); git reset -q --hard "$base"; printf 'brand 1\n' >> b/ledger.txt; sed -i 's/share 2 3/share 1 2/' b/ledger.txt; printf 'b/ledger.txt %s\n' "$hb" > "$T/b.list"; run "an unknown key beside the approved row" "$T/b.list"; want 1 "an approval that also covers an unknown key"; git reset -q --hard "$base"
# the same approval with the file NOT approvable in the conf: nothing is relaxed
gdi_world t1.sh; edit_t1; git add -A; git commit -qm e; h=$(hash t1.sh); git reset -q --hard "$base"; edit_t1; printf 't1.sh %s\n' "$h" > "$T/ok.list"; sed -i 's/^GATES_APPROVABLE=.*/GATES_APPROVABLE=pin.txt/' "$T/gates.conf"; run "tier1 not approvable" "$T/ok.list"; want 1 "an approval for a file the conf does not make approvable"
finish gate_approvals
