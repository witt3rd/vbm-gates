#!/usr/bin/env bash
# The shared attack bodies (attacks/) against a SYNTHETIC consumer: the package's own gates and attacks in a scratch repository with its own tier1 script, protected list, conf and the lander's pinned copy.
# On that tree the real suite must REFUSE every attack that applies (exit 0), and with each attack's gate stubbed out (--sabotage) it must FAIL with no attack REFUSED (PASSED, or BROKEN where the control wants the gate's ran-evidence): an attack is only a proof if
# its gate can fail. Hermetic: nothing of the repository's real lists, tier1 script or conf is read; the tree is built here.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL shared-attacks: $*" >&2; exit 1; }
W=$T/w; newrepo "$W"; cd "$W"; mkdir -p scripts/land.d tests
cp -r "$ROOT/core" "$ROOT/hooks" "$ROOT/attacks" "$ROOT/lean" "$ROOT/KEYS" .; cp -r "$ROOT/scripts/land" scripts/land; cp -r "$ROOT/.agents" .agents
cp "$ROOT"/tests/lib.sh tests/; for t in "$ROOT"/tests/test_*.sh; do case $t in */test_harness.sh|*/test_shared_attacks.sh|*/test_relabel_attacks.sh|*/test_hooks.sh) ;; *) cp "$t" tests/;; esac; done
for h in post-rebase post-tier1 prepare; do cp hooks/land.d-stub scripts/land.d/$h; done
cp scripts/land/templates/land-direct-stub scripts/land-direct 2>/dev/null || printf '#!/usr/bin/env bash\nexec "$(dirname "$0")/land/bin/land-direct" "$@"\n' > scripts/land-direct; chmod +x scripts/land-direct
printf 'LAND_TEST_CMD=true\n' > scripts/land.conf
printf 'GATES_TIER1=t1.sh\nGATES_PROTECTED_LIST=plist.txt\nGATES_LISTS=plist.txt\nGATES_APPROVABLE=t1.sh\nGATES_SOURCE_DIRS=core/ hooks/ attacks/\n' > scripts/gates.conf
printf '#!/usr/bin/env bash\nset -euo pipefail\necho one\necho two\necho "ran: t1: 1 cases"\n' > t1.sh; chmod +x t1.sh; printf 'core/\nhooks/\nt1.sh\n' > plist.txt
git add -A; git commit -qm fixture
ids=$(core/relabel-attacks.sh --list | wc -l); [ "$ids" -ge 36 ] && ok || fail "the shared set lists only $ids attacks"
out=$(core/relabel-attacks.sh --tree "$W" --no-lean 2>&1) || fail "the shared attacks are not all refused on the synthetic tree: $(grep -vE '^REFUSED' <<<"$out")"
n=$(grep -c '^REFUSED' <<<"$out"); [ "$n" -ge 36 ] && grep -q 'n/a     08f-pinned-gates-edited' <<<"$out" && grep -q "^PASS relabel-attacks: $n of $n" <<<"$out" && ok || fail "unexpected suite output: $out"
sab=$(core/relabel-attacks.sh --tree "$W" --no-lean --sabotage 2>&1) && fail "sabotage did not fail the suite"
# a stubbed self-test is either not refused (PASSED) or caught by the control, which wants the test's ran-evidence line (BROKEN): never REFUSED, and the suite fails
! grep -q '^REFUSED' <<<"$sab" && [ "$(grep -cE '^(PASSED|BROKEN)' <<<"$sab")" = "$n" ] && grep -q '^FAIL relabel-attacks' <<<"$sab" && ok || fail "with every gate stubbed some attack was still refused: $(grep -vE '^(PASSED|BROKEN)' <<<"$sab")"
finish shared_attacks
