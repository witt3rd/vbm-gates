#!/usr/bin/env bash
# bin/gates-manifest and bin/gates-release. A scratch repository with the two tools and a few payload and non-payload files, and a scratch ssh key and signers file made here (the real release key and
# signers are never read). The manifest lists exactly the payload, sorted, with the right hashes, and --check fails on a stale, edited, added, removed or hand-edited state; a release refuses a dirty tree, a HEAD
# that is not origin/main, a stale manifest, a key not in the signers file, an existing tag and a bad VERSION, and otherwise makes a signed tag that verifies and records the manifest hash.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL manifest-release: $*" >&2; exit 1; }
ssh-keygen -q -t ed25519 -N '' -C t -f "$T/key" && ssh-keygen -q -t ed25519 -N '' -C o -f "$T/other"
world() {   # world: a scratch "origin" and a clone with the tools, a payload, files outside it, a signers file listing $T/key, a fresh manifest, pushed
  cd "$T"; rm -rf origin.git w; git init -q --bare -b main origin.git; git clone -q origin.git w 2>/dev/null; cd w; git config commit.gpgsign false
  mkdir -p bin core hooks lean attacks tests/lean scripts; cp "$ROOT/bin/gates-manifest" "$ROOT/bin/gates-release" bin/; for b in tier1-core gates-selftest gates-check-config; do printf '#!/usr/bin/env bash\necho %s\n' "$b" > "bin/$b"; done
  echo 0.1.0 > VERSION; echo GATES_A > KEYS; printf '#!/usr/bin/env bash\necho c\n' > core/a.sh; echo h > hooks/h; echo l > lean/l.lean; echo x > attacks/01.sh; echo t > tests/lib.sh; echo t > tests/test_a.sh; echo t > tests/lean/test_l.sh
  echo n > tests/lint.sh; echo n > tests/run.sh; echo n > tests/test_harness.sh; echo n > tests/test_shared_attacks.sh; echo n > README.md; echo n > scripts/other.txt
  printf 'vbm-gates-release namespaces="git" %s\n' "$(cut -d' ' -f1-2 "$T/key.pub")" > scripts/gates.signers
  git add -A; git commit -qm c; bin/gates-manifest >/dev/null; git add -A; git commit -qm manifest; git push -q origin HEAD:main 2>/dev/null; git fetch -q origin
}
world
listed=$(awk '{print $2}' MANIFEST.sha256 | tr '\n' ' ')
[ "$listed" = "KEYS VERSION attacks/01.sh core/a.sh hooks/h lean/l.lean tests/lean/test_l.sh tests/lib.sh tests/test_a.sh " ] && [ "$(bin/gates-manifest --list | tr '\n' ' ')" = "$listed" ] && ok || fail "the manifest lists the wrong files: $listed"
[ "$(grep ' core/a.sh$' MANIFEST.sha256 | cut -d' ' -f1)" = "$(sha256sum < core/a.sh | cut -d' ' -f1)" ] && ok || fail "a hash in the manifest is wrong"
bin/gates-manifest --check >/dev/null && ok || fail "a fresh manifest fails --check"
chk() { bin/gates-manifest --check 2>&1; }
echo more >> core/a.sh; must_fail "a payload file edited" chk; git checkout -q core/a.sh
echo n > core/new.sh; git add core/new.sh; must_fail "a payload file added" chk; git rm -qf core/new.sh
git rm -q hooks/h; must_fail "a payload file removed" chk; git reset -q --hard HEAD
echo 'x' >> README.md; chk >/dev/null && ok || fail "a file outside the payload made the manifest stale"; git checkout -q README.md
echo 0000 > MANIFEST.sha256; must_fail "a hand-edited manifest" chk; git checkout -q MANIFEST.sha256
rc=0; bin/gates-manifest --bad >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && ok || fail "an unknown option did not exit 2"
# the release
rel() { LAND_SIGNING_KEY=$1 bin/gates-release 2>&1; }
out=$(rel "$T/key") && grep -q 'signed tag v0.1.0' <<<"$out" && ok || fail "a clean release did not make its tag: $out"
git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile=scripts/gates.signers verify-tag v0.1.0 >/dev/null 2>&1 && ok || fail "the tag does not verify against the signers file"
[ "$(git tag -l --format='%(contents)' v0.1.0 | sed -n 's/^manifest_sha256=//p')" = "$(sha256sum < MANIFEST.sha256 | cut -d' ' -f1)" ] && ok || fail "the tag does not record the manifest hash"
must_fail "a tag that already exists" rel "$T/key"; grep -q 'already exists' <<<"$MUST_FAIL_ERR" || fail "the existing tag was not named: $MUST_FAIL_ERR"; git tag -d v0.1.0 >/dev/null
must_fail "a key that is not in the signers file" rel "$T/other"; grep -q 'not listed in scripts/gates.signers' <<<"$MUST_FAIL_ERR" || fail "an unlisted key was not named: $MUST_FAIL_ERR"
echo dirty >> README.md; must_fail "a dirty tree" rel "$T/key"; grep -q "not clean" <<<"$MUST_FAIL_ERR" || fail "a dirty tree was not named: $MUST_FAIL_ERR"; git checkout -q README.md
echo 0.1 > VERSION; bin/gates-manifest >/dev/null; git commit -qam v; git push -q origin HEAD:main; git fetch -q origin; must_fail "a VERSION that is not X.Y.Z" rel "$T/key"; grep -q "not a plain X.Y.Z" <<<"$MUST_FAIL_ERR" || fail "a bad VERSION was not named: $MUST_FAIL_ERR"; echo 0.1.0 > VERSION; bin/gates-manifest >/dev/null; git commit -qam v; git push -q origin HEAD:main; git fetch -q origin
echo e >> core/a.sh; git commit -qam stale; git push -q origin HEAD:main; must_fail "a stale manifest" rel "$T/key"; grep -q 'stale' <<<"$MUST_FAIL_ERR" || fail "a stale manifest was not named: $MUST_FAIL_ERR"
bin/gates-manifest >/dev/null; git commit -qam regen; must_fail "a HEAD that is not origin/main" rel "$T/key"; grep -q 'not origin/main' <<<"$MUST_FAIL_ERR" || fail "an unpushed HEAD was not named: $MUST_FAIL_ERR"
git push -q origin HEAD:main; git fetch -q origin; rel "$T/key" >/dev/null && ok || fail "a release after pushing did not work"
finish manifest_release
