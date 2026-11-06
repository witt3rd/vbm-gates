#!/usr/bin/env bash
# core/protected-set.sh can fail. A SYNTHETIC list (built here: an exact path, a directory, a glob, an optional ? entry, comments) in a scratch repository: a change that modifies, deletes, renames out of or
# adds into any kind of entry exits 1 naming the path; a docs-only and an empty change pass; a change that loosens the list is still judged by the base's list; an empty list, a missing list and an unknown revision
# fail closed; --list reads another path; --superset names a dropped or narrowed entry. The repository's real list is never read (a separate check in the consumer covers it).
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
gate=$ROOT/core/protected-set.sh
fail() { echo "FAIL protected-set: $*" >&2; exit 1; }
printf '# a synthetic list\nsrc/exact.sh\ndeny/   # a directory\ngates/*Gate.lean   # a pattern: a NEW file that fits it is protected\n?later/\nlists/protected.txt\n' > "$T/list"
newrepo "$T/r"; cd "$T/r"; mkdir -p src deny gates docs lists; cp "$T/list" lists/protected.txt
echo b > src/exact.sh; echo b > deny/a.txt; echo b > gates/AxiomGate.lean; echo b > docs/a.md; echo b > src/other.sh; echo b > gates/notes.md
git add -A; git commit -qm base; base=$(git rev-parse HEAD)
check() {   # check NAME EXPECT(pass|PATH): the working tree is the candidate head; it is reset afterwards
  git add -A; git commit -qm "$1" --allow-empty; local rc=0 out; out=$("$gate" --list lists/protected.txt "$base" HEAD 2>/dev/null) || rc=$?
  if [ "$2" = pass ]; then [ "$rc" = 0 ] && ok || fail "$1: a clean change was refused ($out)"
  else [ "$rc" = 1 ] && grep -qxF "$2" <<<"$out" && ok || fail "$1: expected exit 1 naming '$2', got rc=$rc: $out"; fi
  git reset -q --hard "$base"
}
check "empty change" pass
echo more >> docs/a.md; echo n > docs/new.md; check "docs only" pass
echo x > src/other.sh; echo x > gates/notes.md; echo x > somefile; check "near misses (not on the list, not matching the pattern)" pass
echo x >> src/exact.sh; check "modify an exact entry" src/exact.sh
git rm -qf src/exact.sh; check "delete an exact entry" src/exact.sh
git mv src/exact.sh docs/moved; check "rename out of an exact entry" src/exact.sh
echo x >> deny/a.txt; check "modify inside a directory entry" deny/a.txt
echo n > deny/new.txt; check "add inside a directory entry" deny/new.txt
git mv docs/a.md deny/renamed-in; check "rename into a directory entry" deny/renamed-in
echo x >> gates/AxiomGate.lean; check "modify a file matching the glob" gates/AxiomGate.lean
echo n > gates/NewGate.lean; check "a NEW file that fits the glob, no edit of the list" gates/NewGate.lean
mkdir -p gates/deep; echo n > gates/deep/XGate.lean; check "the glob star crosses a slash" gates/deep/XGate.lean
mkdir later; echo n > later/f; check "an optional (?) entry that now exists" later/f
echo x >> lists/protected.txt; check "the list itself" lists/protected.txt
# loosening the list does not help: the list as of the base judges the change, and the list's own edit is reported
grep -v '^src/exact.sh' lists/protected.txt > l.tmp; mv l.tmp lists/protected.txt; echo x >> src/exact.sh
git add -A; git commit -qm loosen; rc=0; out=$("$gate" --list lists/protected.txt "$base" HEAD 2>/dev/null) || rc=$?
[ "$rc" = 1 ] && grep -qxF src/exact.sh <<<"$out" && grep -qxF lists/protected.txt <<<"$out" && ok || fail "a loosened list was not judged by the base list (rc=$rc: $out)"; git reset -q --hard "$base"
# fail closed: an empty list, a missing list, an unknown revision
git mv lists/protected.txt lists/empty.txt && : > lists/empty.txt && git add -A && git commit -qm empty && eb=$(git rev-parse HEAD)
rc=0; "$gate" --list lists/empty.txt "$eb" "$eb" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "an empty list did not fail closed (rc=$rc)"
rc=0; "$gate" --list lists/nothing.txt "$base" "$base" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "a missing list did not fail closed (rc=$rc)"
rc=0; "$gate" --list lists/empty.txt "$eb" nosuchrev >/dev/null 2>&1 || rc=$?; [ "$rc" != 0 ] && ok || fail "an unknown revision passed"
git reset -q --hard "$base"
# no copy of the list at the base: the working-tree copy at the same path is used (the commit that introduces the gate)
git rm -q --cached lists/protected.txt; git commit -qm nolist; nb=$(git rev-parse HEAD); echo x >> src/exact.sh; git add -A; git commit -qm edit
out=$("$gate" --list lists/protected.txt "$nb" HEAD 2>/dev/null) || true; grep -qxF src/exact.sh <<<"$out" && ok || fail "the working-tree list was not used when the base has none ($out)"
git reset -q --hard "$base"
# --superset: the list may only grow
sup() { "$gate" --superset "$T/old.lst" "$T/new.lst"; }
printf 'a/\nb.txt\nlib/*Gate.lean\n' > "$T/old.lst"
printf 'a/\nb.txt\nlib/*Gate.lean\nc/\n' > "$T/new.lst"; sup >/dev/null && ok || fail "--superset: a grown list was refused"
printf 'a/\nlib/*Gate.lean\n' > "$T/new.lst"; must_fail "--superset: a dropped entry" sup; [ "$MUST_FAIL_ERR" = b.txt ] || fail "--superset: the dropped entry was not named ($MUST_FAIL_ERR)"
printf 'a/x.txt\nb.txt\nlib/*Gate.lean\n' > "$T/new.lst"; must_fail "--superset: a narrowed directory" sup; [ "$MUST_FAIL_ERR" = a/ ] || fail "--superset: the narrowed entry was not named ($MUST_FAIL_ERR)"
printf 'a/\nb.txt\nlib/AxiomGate.lean\n' > "$T/new.lst"; must_fail "--superset: a pattern narrowed to one file" sup; [ "$MUST_FAIL_ERR" = 'lib/*Gate.lean' ] || fail "--superset: the narrowed pattern was not named ($MUST_FAIL_ERR)"
printf 'a/\nb.txt\nlib/*\n' > "$T/new.lst"; sup >/dev/null && ok || fail "--superset: a wider pattern was refused"
printf '#\n' > "$T/new.lst"; must_fail "--superset: an empty new list" sup
printf "#\n" > "$T/old.lst"; printf "#\n" > "$T/new.lst"; must_fail "--superset: both lists empty" sup
printf 'a/x.txt\n' > "$T/old.lst"; printf 'a/\n' > "$T/new.lst"; sup >/dev/null && ok || fail "--superset: a directory above a file entry was refused"
finish protected_set
