#!/usr/bin/env bash
# core/git-hermetic.sh. (1) the CI failure, reproduced: pushing HEAD of a SHALLOW clone to a local bare repository is refused; git_snapshot_repo works from the same shallow clone and carries the same tree.
# (2) hermetic: against a hostile ambient configuration (default branch trunk, signing on, a hooksPath whose hook fails, an enclosing GIT_DIR) a scratch repository still gets branch main, a commit and
# no hook runs, with and without any ambient identity. Everything happens in the test's own sandbox.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL git-hermetic: $*" >&2; exit 1; }
# --- (1) a shallow source: two commits, cloned with --depth 1 (what actions/checkout does by default) ---
git init -q "$T/full" && git -C "$T/full" commit -q --allow-empty -m one && echo x > "$T/full/f" && git -C "$T/full" add f && git -C "$T/full" commit -q -m two
git clone -q --depth 1 "file://$T/full" "$T/shallow"
[ "$(git -C "$T/shallow" rev-parse --is-shallow-repository)" = true ] && ok || fail "the fixture is not shallow"
git init -q --bare "$T/old.git"
must_fail "a push from a shallow clone" git -C "$T/shallow" push "$T/old.git" HEAD:refs/heads/main
grep -q 'shallow update not allowed' <<<"$MUST_FAIL_ERR" || fail "the shallow push failed for another reason: $MUST_FAIL_ERR"
( cd "$T/shallow" && git_snapshot_repo HEAD "$T/snap.git" ) && ok || fail "git_snapshot_repo failed from a shallow clone"
[ "$(git -C "$T/snap.git" rev-parse 'main^{tree}')" = "$(git -C "$T/shallow" rev-parse 'HEAD^{tree}')" ] && ok || fail "the snapshot's tree is not HEAD's"
[ "$(git -C "$T/snap.git" rev-list --count main)" = 1 ] && ok || fail "the snapshot is not one root commit"
git clone -q "$T/snap.git" "$T/c" && [ "$(git -C "$T/c" branch --show-current)" = main ] && ok || fail "a clone of the snapshot is not on main"
# --- (2) hostile ambient configuration, then a clean one with no identity at all ---
mkdir -p "$T/amb/hooks"
printf '#!/bin/sh\necho hook ran > "%s/hook.ran"; exit 1\n' "$T" > "$T/amb/hooks/pre-commit"; chmod +x "$T/amb/hooks/pre-commit"
printf '[init]\n\tdefaultBranch = trunk\n[commit]\n\tgpgsign = true\n[core]\n\thooksPath = %s/amb/hooks\n[user]\n\tuseConfigOnly = true\n' "$T" > "$T/amb/.gitconfig"
probe='. "$HERMETIC"; r=$TMP/r; git init -q "$r" && git -C "$r" commit -q --allow-empty -m x && [ "$(git -C "$r" branch --show-current)" = main ] && git clone -q "$r" "$r.clone" && git -C "$r.clone" commit -q --allow-empty -m y'   # git-hermetic-ok
for ambient in hostile bare; do
  mkdir -p "$T/$ambient.tmp"
  if [ "$ambient" = hostile ]; then h=$T/amb; else h=$T/bare-amb; mkdir -p "$h"; fi
  env -i PATH="$PATH" HOME="$h" TMP="$T/$ambient.tmp" HERMETIC="$ROOT/core/git-hermetic.sh" GIT_DIR=/nonexistent GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="$T/amb/hooks" \
    bash -c "$probe" && ok || fail "a scratch repository could not be made and committed under the $ambient ambient configuration"
done
[ ! -e "$T/hook.ran" ] && ok || fail "an ambient hook ran in a scratch repository"
finish git_hermetic
