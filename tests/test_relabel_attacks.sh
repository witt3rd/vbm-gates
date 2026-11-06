#!/usr/bin/env bash
# core/relabel-attacks.sh judges a gate change by mechanical attacks, and it can FAIL. A SYNTHETIC fixture (the package's code in a scratch repository with its own gates, attacks and conf, built here):
# every attack is REFUSED by the tree's gates (exit 0); with the gate an attack relies on replaced by a stub that cannot fail (--sabotage) the suite FAILS; a gate that fails on the unattacked tree is BROKEN
# (the control), an attack that changes nothing or cannot be applied is BROKEN, an attack no gate refuses is PASSED (exit 1), an attack missing from the tree (shared or the repository's own) is MISSING; the
# shared and the repository's own attacks are one suite; the runner exports G, TIER1, PLIST and GATES_ATTACK_VARS; a bad conf cannot decide (exit 2); --check-wired refuses a stub or hook that no longer runs it.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL relabel-attacks: $*" >&2; exit 1; }
fixture() {   # fixture DIR: the package's code, the lander's library, synthetic gates, attacks and conf; committed
  local d=$1; rm -rf "$d"; newrepo "$d"; cd "$d"; mkdir -p scripts/land scripts/land.d scripts/attacks attacks
  cp -r "$ROOT/core" "$ROOT/hooks" "$ROOT/KEYS" .; cp "$ROOT/attacks/lib.sh" attacks/lib.sh; cp -r "$LANDLIB" scripts/land/lib
  printf '#!/usr/bin/env bash\nexit 0\n' > scripts/land/bin-land-direct; mkdir -p scripts/land/bin; mv scripts/land/bin-land-direct scripts/land/bin/land-direct; chmod +x scripts/land/bin/land-direct
  printf '#!/usr/bin/env bash\nexec "$(dirname "$0")/land/bin/land-direct" "$@"\n' > scripts/land-direct; chmod +x scripts/land-direct
  for h in post-rebase post-tier1 prepare; do cp hooks/land.d-stub scripts/land.d/$h; done
  printf 'GATES_TIER1=t1.sh\nGATES_PROTECTED_LIST=plist.txt\nGATES_ATTACK_VARS=ATK_X=7\n' > scripts/gates.conf
  printf 'keep\nother\n' > data.txt; printf '#!/usr/bin/env bash\nset -e\necho a\n' > t1.sh; printf 'a/\n' > plist.txt
  printf '#!/usr/bin/env bash\ngrep -qx keep data.txt || { echo "g1: keep is gone" >&2; exit 1; }\n' > g1.sh
  printf '#!/usr/bin/env bash\n! grep -q "|| true" t1.sh || { echo "g2: a masked step" >&2; exit 1; }\n' > g2.sh; chmod +x g1.sh g2.sh
  printf 'ATK_DESC="drop the keep line"\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh); ATK_EXPECT="keep is gone"\natk_apply() { sed -i "/^keep$/d" data.txt; }\n' > attacks/01-drop.sh
  printf 'ATK_DESC="mask a step of the tier1 script"\nATK_GATES=(./g2.sh); ATK_GATE_FILES=(g2.sh)\natk_apply() { add_before_end "$TIER1" "echo b || true"; }\n' > attacks/02-mask.sh
  printf '#!/usr/bin/env bash\n! grep -qx ". t1.sh plist.txt 7" vars.txt || { echo "gv: the variables arrived" >&2; exit 1; }\n' > gv.sh; chmod +x gv.sh
  printf 'ATK_DESC="the runner exports its variables"\nATK_GATES=(./gv.sh); ATK_GATE_FILES=(gv.sh)\natk_apply() { echo "$G $TIER1 $PLIST $ATK_X" > vars.txt; }\n' > attacks/03-vars.sh
  git add -A; git commit -qm fixture
}
run() { ( cd "$W" && "$W/core/relabel-attacks.sh" --tree "$W" "$@" ) 2>&1; }   # run ARGS: the runner of the fixture on the fixture
W=$T/w; fixture "$W"
out=$(run) && grep -q '^PASS relabel-attacks: 3 of 3' <<<"$out" && [ "$(grep -c '^REFUSED' <<<"$out")" = 3 ] && ok || fail "the clean fixture is not refused by its gates: $out"
[ "$(run --list | tr '\n' ' ')" = "01-drop 02-mask 03-vars " ] && ok || fail "--list is wrong"
must_fail "sabotage: every gate stubbed, the suite must fail" run --sabotage; grep -q '^FAIL' <<<"$MUST_FAIL_ERR" && ! grep -q '^REFUSED' <<<"$MUST_FAIL_ERR" || fail "sabotage did not fail the suite: $MUST_FAIL_ERR"
# the control and the verdicts
printf '#!/usr/bin/env bash\nexit 1\n' > g1.sh; git commit -qam "g1 always fails"
must_fail "a gate that fails on the unattacked tree" run --only 01-drop; grep -q 'BROKEN  01-drop: the gate fails on the unattacked tree' <<<"$MUST_FAIL_ERR" || fail "the control did not say BROKEN: $MUST_FAIL_ERR"
fixture "$W"; printf '#!/usr/bin/env bash\nexit 0\n' > g2.sh; git commit -qam "g2 cannot fail"
must_fail "an attack no gate refuses" run --only 02-mask; grep -q '^PASSED  02-mask' <<<"$MUST_FAIL_ERR" || fail "an unrefused attack was not PASSED: $MUST_FAIL_ERR"
fixture "$W"; printf 'ATK_DESC="x"\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh)\natk_apply() { :; }\n' > attacks/04-nothing.sh; printf 'ATK_DESC="x"\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh)\natk_apply() { false; }\n' > attacks/05-fails.sh; git add -A; git commit -qm more
must_fail "an attack that changes nothing" run --only 04-nothing; grep -q 'BROKEN  04-nothing: the attack changed nothing' <<<"$MUST_FAIL_ERR" || fail "a no-op attack was not BROKEN: $MUST_FAIL_ERR"
must_fail "an attack that cannot be applied" run --only 05-fails; grep -q 'BROKEN  05-fails: the attack could not be applied' <<<"$MUST_FAIL_ERR" || fail "an inapplicable attack was not BROKEN: $MUST_FAIL_ERR"
fixture "$W"; printf 'ATK_DESC="x"\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh); ATK_EXPECT="nothing like this"\natk_apply() { sed -i "/^keep$/d" data.txt; }\n' > attacks/06-expect.sh; git add -A; git commit -qm expect
must_fail "a gate that fails for another reason than the expected one" run --only 06-expect; grep -q 'not for the expected reason' <<<"$MUST_FAIL_ERR" && grep -q '^PASSED  06-expect' <<<"$MUST_FAIL_ERR" || fail "an unexpected reason was accepted: $MUST_FAIL_ERR"
fixture "$W"; printf 'ATK_DESC="x"; ATK_LEAN=1\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh)\natk_apply() { sed -i "/^keep$/d" data.txt; }\n' > attacks/07-lean.sh; git add -A; git commit -qm lean
out=$(run --no-lean --only 07-lean) || true; grep -q 'skip    07-lean' <<<"$out" && ok || fail "--no-lean did not skip a Lean attack: $out"
# an attack that does not apply to this tree (atk_na) is reported n/a and not counted
fixture "$W"; printf 'ATK_DESC="x"\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh)\natk_na() { true; }\natk_apply() { false; }\n' > attacks/08-na.sh; git add -A; git commit -qm na
out=$(run) && grep -q 'n/a     08-na' <<<"$out" && grep -q '^PASS relabel-attacks: 3 of 3' <<<"$out" && ok || fail "a not-applicable attack was run or counted: $out"
# dropped attacks: the shared ones, and the repository's own; and the two sets are one suite
fixture "$W"; printf 'ATK_DESC="own"\nATK_GATES=(./g1.sh); ATK_GATE_FILES=(g1.sh)\natk_apply() { sed -i "/^keep$/d" data.txt; }\n' > scripts/attacks/10-own.sh; git add -A; git commit -qm own
[ "$(run --list | tr '\n' ' ')" = "01-drop 02-mask 03-vars 10-own " ] && ok || fail "the repository's own attack is not in the suite"
out=$(run) && grep -q '^PASS relabel-attacks: 4 of 4' <<<"$out" && ok || fail "the shared and own attacks are not one suite: $out"
rm -rf "$T/t2"; git clone -q "$W" "$T/t2"; git -C "$T/t2" rm -q attacks/02-mask.sh; git -C "$T/t2" commit -qm "a shared attack dropped"
must_fail "a shared attack dropped from the proposed tree" run --tree "$T/t2"; grep -q '^MISSING.* 02-mask.sh' <<<"$MUST_FAIL_ERR" || fail "a dropped shared attack was not MISSING: $MUST_FAIL_ERR"
rm -rf "$T/t3"; git clone -q "$W" "$T/t3"; git -C "$T/t3" rm -q scripts/attacks/10-own.sh; git -C "$T/t3" commit -qm "an own attack dropped"
must_fail "an own attack dropped from the proposed tree" run --tree "$T/t3"; grep -q '^MISSING.* 10-own.sh' <<<"$MUST_FAIL_ERR" || fail "a dropped own attack was not MISSING: $MUST_FAIL_ERR"
cp attacks/01-drop.sh scripts/attacks/01-drop.sh; git add -A; git commit -qm dup; rc=0; run --list >/dev/null || rc=$?; [ "$rc" = 2 ] && ok || fail "an id in both sets did not exit 2 (rc=$rc)"
# the conf: a bad GATES_ATTACK_VARS cannot decide
fixture "$W"; sed -i 's/ATK_X=7/lower=7/' "$W/scripts/gates.conf"; git commit -qam badvars; rc=0; run --list >/dev/null || rc=$?; [ "$rc" = 2 ] && ok || fail "a bad GATES_ATTACK_VARS did not exit 2 (rc=$rc)"
# --check-wired
fixture "$W"; run --check-wired >/dev/null && ok || fail "the wired fixture is not wired: $(run --check-wired)"
wired_fails() {   # wired_fails DESC EDIT-COMMAND: the edit unwires the fixture; --check-wired must refuse and say why
  fixture "$W"; ( cd "$W" && eval "$2" && git add -A && git commit -qm "$1" ); must_fail "$1" run --check-wired
}
wired_fails "a post-tier1 stub that differs from the package's" 'printf "#!/usr/bin/env bash\nexit 0\n" > scripts/land.d/post-tier1'
wired_fails "a post-rebase stub made non-executable" 'chmod -x scripts/land.d/post-rebase'
wired_fails "a post-tier1 hook that no longer calls the suite" 'sed -i "/relabel-attacks/d" hooks/post-tier1'
wired_fails "a post-rebase hook that no longer calls the diff judge" 'sed -i "/gate-diff-improving/d" hooks/post-rebase'
wired_fails "an entry script that does not run the pinned lander" 'printf "#!/usr/bin/env bash\nexit 0\n" > scripts/land-direct'
fixture "$W"; ( cd "$W" && rm scripts/land.d/prepare && git add -A && git commit -qm noprep ); run --check-wired >/dev/null && ok || fail "an absent optional prepare stub was refused"
finish relabel_attacks
