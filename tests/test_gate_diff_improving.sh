#!/usr/bin/env bash
# core/gate-diff-improving.sh judges a gate-file diff from the tables of a SYNTHETIC gates.conf and rules file built here (a scratch repository with its own baselines, lists, tier1 script and sources):
# a numeric baseline moves only in its improving direction (unknown key, unknown field, a fixed key removed, a baseline appearing or disappearing FAIL); the tier1 script only gains plain steps (a removed or
# changed line, `|| true`, `!`, `&`, `trap`, a joined line FAIL; a guard passes); STRICT files only gain lines; lists and gate source are owner-only, or suite-judged with --suite-judged; the protected list
# may only grow; --touched names the gate files; a bad conf or an unknown revision cannot decide (exit 2). The repository's own baselines and lists are never read.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
gdi=$ROOT/core/gate-diff-improving.sh
fail() { echo "FAIL gate-diff-improving: $*" >&2; exit 1; }
gdi_world; W=$T/w
judge() {   # judge NAME [flags]: the working tree is the head; sets JRC and JOUT, resets the tree
  git add -A; git commit -qm "$1" --allow-empty; local rc=0; JOUT=$("$gdi" --conf "$T/gates.conf" "${@:2}" "$base" HEAD 2>&1) || rc=$?; JRC=$rc; git reset -q --hard "$base"
}
verdict() { local n=$1 want=$2; judge "$n" "${@:3}"; case $want in PASS) [ "$JRC" = 0 ] && ok || fail "$n: expected PASS, got $JRC: $JOUT";; FAIL) [ "$JRC" = 1 ] && ok || fail "$n: expected FAIL, got $JRC: $JOUT";; esac; }
failsay() { local n=$1 words=$2; verdict "$n" FAIL "${@:3}"; grep -q "$words" <<<"$JOUT" || fail "$n: the verdict does not say '$words': $JOUT"; }   # failsay NAME WORDS [flags]
echo e >> docs/a.md; verdict "no gate file changed" PASS
# numeric baselines
sed -i 's/proved 5/proved 6/' b/ledger.txt; verdict "proved rises" PASS
sed -i 's/proved 5/proved 4/' b/ledger.txt; failsay "proved falls" "wrong way"
sed -i 's/open 3/open 4/' b/ledger.txt; failsay "open rises" "wrong way"
sed -i 's/share 2 3/share 3 4/' b/ledger.txt; verdict "the share ratio rises (2/3 to 3/4)" PASS
sed -i 's/share 2 3/share 4 7/' b/ledger.txt; failsay "the share ratio falls (2/3 to 4/7)" "fell"
printf 'brand 1\n' >> b/ledger.txt; failsay "an unknown key" "unknown key"
sed -i '/^proved/d' b/ledger.txt; failsay "a fixed key removed" "removed"
sed -i '/^ModA/d' b/ledger.txt; verdict "a removable key removed" PASS
sed -i 's/ModA 4/ModA 5/' b/ledger.txt; failsay "a down-only key rises" "wrong way"
sed -i 's/ModA 4/ModA 3 9/' b/ledger.txt; failsay "an unknown field" "unknown field"
git rm -q b/ledger.txt; failsay "a baseline disappears" "disappears"
# the tier1 script: only plain steps are gained
add() { printf '%s\n' "$1" >> t1.sh; }
add 'echo b'; verdict "a plain step" PASS
add '[ -f x ] || { echo "no x" >&2; exit 1; }'; verdict "a guard" PASS
sed -i 's/^set -e$/set +e/' t1.sh; failsay "a changed line" "removed/changed"
sed -i '/^echo a$/d' t1.sh; failsay "a removed line" "removed/changed"
for bad in 'cmd || true' 'cmd || :' '! cmd' 'cmd &' 'trap "exit 0" EXIT' 'set +e' 'exit 0' 'if false; then cmd; fi' 'x=$(cmd)' 'cmd && other' 'cmd; other'; do git reset -q --hard "$base"; add "$bad"; verdict "a masking line: $bad" FAIL; done
git reset -q --hard "$base"; printf 'cmd \\\n' >> t1.sh; printf 'echo tail\n' >> t1.sh; verdict "a continued line" FAIL
# STRICT files, lists, gate source
echo v2 >> pin.txt; verdict "a strict file gains a line" PASS
sed -i 's/v1/v9/' pin.txt; failsay "a strict file changes a line" "removed/changed"
echo y >> lists.txt; failsay "a list changes" "waits for the owner"
echo y >> gate.sh; failsay "gate source changes" "waits for the owner"
echo y > scripts/attacks/02.sh; failsay "a file in a gate source directory" "waits for the owner"
echo y >> lists.txt; echo y >> gate.sh; echo y > scripts/attacks/02.sh; verdict "lists and sources are judged by the suite" PASS --suite-judged
# the protected list may only grow (suite-judged)
printf 'c/\n' >> scripts/plist.txt; verdict "the protected list grows" PASS --suite-judged
printf 'a/\n' > scripts/plist.txt; failsay "the protected list drops an entry" "drops protection.*b.txt" --suite-judged
# --touched
echo y >> gate.sh; echo e >> docs/a.md; add 'echo c'; sed -i 's/proved 5/proved 6/' b/ledger.txt; judge "touched" --touched; [ "$JRC" = 0 ] && [ "$(sort <<<"$JOUT" | tr '\n' ' ')" = "b/ledger.txt gate.sh t1.sh " ] && ok || fail "--touched printed: $JOUT"
# cannot decide: a bad conf, a conf with an unknown key, a missing rules file, a malformed rule, an unknown revision
git reset -q --hard "$base"; echo e >> docs/a.md; git add -A; git commit -qm x
printf 'GATES_TIER1=t1.sh\nGATES_TIER=x\n' > "$T/bad.conf"; rc=0; "$gdi" --conf "$T/bad.conf" "$base" HEAD >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "an unknown conf key did not exit 2 (rc=$rc)"
sed 's/rules.txt/missing.txt/' "$T/gates.conf" > "$T/c2.conf"; rc=0; "$gdi" --conf "$T/c2.conf" "$base" HEAD >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "a missing rules file did not exit 2 (rc=$rc)"
git reset -q --hard "$base"; echo 'b/ledger.txt | proved | f0=sideways | fixed' >> rules.txt; git add -A; git commit -qm badrule2; nb=$(git rev-parse HEAD); echo e >> docs/a.md; git add -A; git commit -qm x; rc=0; "$gdi" --conf "$T/gates.conf" "$nb" HEAD >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "a malformed rule did not exit 2 (rc=$rc)"
rc=0; "$gdi" --conf "$T/gates.conf" "$base" nosuchrev >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "an unknown revision did not exit 2 (rc=$rc)"
# a line added right after a line that ends in a continuation joins onto it (the pair runs as one command)
git reset -q --hard "$base"; printf 'cmd \\\n' >> t1.sh; git add -A; git commit -qm cont; b2=$(git rev-parse HEAD); sv=$base; base=$b2; printf 'echo tail\n' >> t1.sh; failsay "a line joined onto the one above" "joins onto"; base=$sv; git reset -q --hard "$base"
# a rule whose last column is neither removable nor fixed cannot be decided
git reset -q --hard "$base"; sed -i 's/| fixed$/| sometimes/' rules.txt; git add -A; git commit -qm sometimes; nb=$(git rev-parse HEAD); echo e >> docs/a.md; git add -A; git commit -qm x; rc=0; "$gdi" --conf "$T/gates.conf" "$nb" HEAD >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "a rule with a bad last column did not exit 2 (rc=$rc)"; git reset -q --hard "$base"
# the judge is bounded: a git that hangs ends in exit 2 "cannot decide", never an unbounded wait
mkdir "$T/slow"; printf '#!/usr/bin/env bash\ncase "$1" in diff) sleep 20;; esac\nexec %s "$@"\n' "$(command -v git)" > "$T/slow/git"; chmod +x "$T/slow/git"
echo e >> docs/a.md; git add -A; git commit -qm slow; rc=0; out=$(PATH="$T/slow:$PATH" GDI_TIMEOUT=1 "$gdi" --conf "$T/gates.conf" "$base" HEAD 2>&1) || rc=$?; [ "$rc" = 2 ] && grep -q 'cannot decide' <<<"$out" && ok || fail "a hanging git did not end in exit 2 (rc=$rc: $out)"; git reset -q --hard "$base"
finish gate_diff_improving
