#!/usr/bin/env bash
# The lander hooks run from MAIN's copy through the stub. A scratch repository carries this package's code (core/, hooks/, KEYS, the lander's library) with a synthetic gates.conf; a landing is simulated with the
# environment the lander gives a hook. post-rebase passes an improving change and refuses (12) a weakened tier1 script, an unreadable gates.conf and an unknown key; it prints when the protected set is touched;
# a proposal that rewrites the hook (or the judge) itself still meets main's. prepare copies the warm directories. Both layouts: the package's own repository and a vendored scripts/gates copy.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL hooks: $*" >&2; exit 1; }
world() {   # world LAYOUT(own|vendored): the base repository (the package's code plus a synthetic conf), a land.d with the stub under each hook name; sets $base
  cd "$T"; rm -rf w; newrepo w; cd w; mkdir -p scripts/land scripts/land.d b
  cp -r "$LANDLIB" scripts/land/lib   # the lander's library: ga_hash, pkgconf_load
  if [ "$1" = own ]; then P=.; cp -r "$ROOT/core" "$ROOT/hooks" "$ROOT/KEYS" .; else P=scripts/gates; mkdir -p scripts/gates; cp -r "$ROOT/core" "$ROOT/hooks" "$ROOT/KEYS" scripts/gates/; printf 'version=v0\n' > scripts/gates/PIN; fi
  printf 'GATES_TIER1=t1.sh\nGATES_LISTS=scripts/plist.txt\nGATES_PROTECTED_LIST=scripts/plist.txt\nGATES_APPROVABLE=t1.sh\nGATES_WARM_DIRS=cache\n' > scripts/gates.conf
  printf 'prot/\nscripts/plist.txt\n' > scripts/plist.txt; printf '#!/usr/bin/env bash\nset -e\necho a\n' > t1.sh; mkdir prot docs; echo p > prot/f; echo d > docs/a.md
  for h in post-rebase prepare; do cp "$ROOT/hooks/land.d-stub" "scripts/land.d/$h"; done; chmod +x scripts/land.d/*
  git add -A; git commit -qm base; base=$(git rev-parse HEAD)
}
land() {   # land HOOK: commit the working tree as the head and run the hook as the lander does (cwd = the proposed tree, base's objects in LAND_TOP); sets HRC, HOUT
  git add -A; git commit -qm head --allow-empty; mkdir -p "$T/state"
  HOUT=$(LAND_TOP=$T/w LAND_BASE_REF=$base LAND_STATE_DIR=$T/state LAND_GATE_APPROVED_FILE= scripts/land.d/"$1" 2>&1) && HRC=0 || HRC=$?
}
for layout in own vendored; do
  world $layout
  echo e >> docs/a.md; printf 'echo b\n' >> t1.sh; land post-rebase; [ "$HRC" = 0 ] && grep -q 'none touched' <<<"$HOUT" && ok || fail "$layout: an improving change was refused ($HRC): $HOUT"; git reset -q --hard "$base"
  echo e >> prot/f; land post-rebase; [ "$HRC" = 0 ] && grep -q 'TOUCHED (prot/f)' <<<"$HOUT" && ok || fail "$layout: the protected set was not reported ($HRC): $HOUT"; git reset -q --hard "$base"
  echo 'x/' >> scripts/plist.txt; land post-rebase; [ "$HRC" = 0 ] && ok || fail "$layout: a list that grows was refused: the suite judges lists ($HRC): $HOUT"; git reset -q --hard "$base"
  printf 'scripts/plist.txt\n' > scripts/plist.txt; land post-rebase; [ "$HRC" = 12 ] && grep -q 'drops protection' <<<"$HOUT" && ok || fail "$layout: a protected list that drops an entry was not refused ($HRC): $HOUT"; git reset -q --hard "$base"
  printf 'echo b || true\n' >> t1.sh; land post-rebase; [ "$HRC" = 12 ] && grep -q 'not purely improving' <<<"$HOUT" && ok || fail "$layout: a masked tier1 line was not refused with 12 ($HRC): $HOUT"; git reset -q --hard "$base"
  sed -i 's/^echo a$/echo b/' t1.sh; land post-rebase; [ "$HRC" = 12 ] && ok || fail "$layout: a changed tier1 line without approval was not refused ($HRC): $HOUT"; git reset -q --hard "$base"
  # the proposal rewrites the hook and the judge to pass everything AND weakens tier1: main's copy still judges it
  printf '#!/usr/bin/env bash\nexit 0\n' > $P/hooks/post-rebase; printf '#!/usr/bin/env bash\nexit 0\n' > $P/core/gate-diff-improving.sh; printf 'echo b || true\n' >> t1.sh; land post-rebase
  [ "$HRC" = 12 ] && ok || fail "$layout: a proposal that rewrites the judge weakened the judge that judges it ($HRC): $HOUT"; git reset -q --hard "$base"
  # a proposal that makes gates.conf unreadable or adds an unknown key does not change the conf the judge reads (main's)
  printf 'GATES_TIER1=t1.sh\nGATES_TIER=x\n' > scripts/gates.conf; printf 'echo b || true\n' >> t1.sh; land post-rebase; [ "$HRC" = 12 ] && ok || fail "$layout: a proposed gates.conf loosened the rules it is judged by ($HRC): $HOUT"; git reset -q --hard "$base"
  # main's own conf is unreadable (an unknown key at the base): cannot decide, refused
  printf 'GATES_TIER=x\n' > scripts/gates.conf; git add -A; git commit -qm badconf; base=$(git rev-parse HEAD); echo e >> docs/a.md; land post-rebase; [ "$HRC" = 12 ] && grep -q 'cannot decide' <<<"$HOUT" && ok || fail "$layout: an unreadable base conf did not refuse with a reason ($HRC): $HOUT"
  # prepare: the warm directory of the primary worktree is copied into the scratch worktree
  world $layout; mkdir -p cache/sub; echo built > cache/sub/o; rm -rf "$T/scratch"; git worktree add -q "$T/scratch" HEAD
  ( cd "$T/scratch" && LAND_TOP=$T/w LAND_BASE_REF=$base LAND_STATE_DIR=$T/state scripts/land.d/prepare ) >/dev/null 2>&1; [ "$(cat "$T/scratch/cache/sub/o" 2>/dev/null)" = built ] && ok || fail "$layout: prepare did not copy the warm directory"
done
finish hooks
