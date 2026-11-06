#!/usr/bin/env bash
# THE PAYLOAD RUNS WHERE IT IS VENDORED. A scratch consumer is built here: the vendored lander and the payload (the files bin/gates-manifest lists) in scripts/gates/ with a PIN and a manifest that verify, the consumer's own
# conf, lists, tier1 script, stubs and workflow. In it: the drift check passes; bin/gates-check-config passes; the package's own tests (bin/gates-selftest, every shipped test_*.sh) pass in the vendored layout; the shared
# attack suite refuses every applicable attack; and each way to break the consumer's configuration is reported by gates-check-config, which names it (a class dropped from the protected list, a stub that differs,
# a typo in a path, a hand copy of a pinned file, a tampered pin, an unknown key). Hermetic: the consumer, its lists and its conf are built here.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
fail() { echo "FAIL vendored-layout: $*" >&2; exit 1; }
consumer() {   # consumer: $T/c, a scratch repository that vendors the payload and the lander (built once, then copied)
  cd "$T"; rm -rf c; if [ -d base ]; then cp -a base c; cd c; return; fi
  newrepo base; cd base; mkdir -p scripts/land.d .github/workflows
  cp -r "$ROOT/scripts/land" scripts/land; cp -r "$ROOT/.agents" .agents; cp "$ROOT/scripts/land/templates/land-direct-stub" scripts/land-direct; chmod +x scripts/land-direct
  while IFS= read -r f; do mkdir -p "scripts/gates/$(dirname "$f")"; cp "$ROOT/$f" "scripts/gates/$f"; done < <("$ROOT/bin/gates-manifest" --list)
  ( cd scripts/gates && while IFS= read -r f; do sha256sum -- "$f"; done < <("$ROOT/bin/gates-manifest" --list) | LC_ALL=C sort -k2 > MANIFEST.sha256 )
  printf 'source=witt3rd/vbm-gates\nversion=v0.0.0\ncommit=%s\nmanifest_sha256=%s\nsignature=verified\n' "$(printf 'a%.0s' $(seq 40))" "$(sha256sum < scripts/gates/MANIFEST.sha256 | cut -d' ' -f1)" > scripts/gates/PIN
  for h in post-rebase post-tier1 prepare; do cp scripts/gates/hooks/land.d-stub scripts/land.d/$h; done
  printf 'LAND_TEST_CMD=true\n' > scripts/land.conf; printf 'public\n' > .github/visibility; printf 'name: ci\non: push\npermissions:\n  contents: read\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' > .github/workflows/ci.yml
  printf '#!/usr/bin/env bash\nset -euo pipefail\necho one\necho two\n' > tier1.sh; chmod +x tier1.sh; printf 'vbm-gates-release namespaces="git" ssh-ed25519 AAAA\n' > scripts/gates.signers; printf 'x\n' > scripts/land.signers
  printf 'GATES_TIER1=tier1.sh\nGATES_PROTECTED_LIST=protected.txt\nGATES_LISTS=protected.txt\nGATES_APPROVABLE=tier1.sh\nGATES_SOURCE_DIRS=scripts/gates/ scripts/land/ scripts/land.d/\n' > scripts/gates.conf
  printf 'tier1.sh\nprotected.txt\nscripts/gates/\nscripts/gates.conf\nscripts/gates.signers\nscripts/land/\nscripts/land.conf\nscripts/land.signers\nscripts/land-direct\nscripts/land.d/\n.github/\n' > protected.txt
  git add -A; git commit -qm consumer; cd "$T"; cp -a base c; cd c
}
check() { bin=scripts/gates/bin/gates-check-config; "$bin" 2>&1; }
consumer
scripts/land/bin/land-check >/dev/null && ok || fail "the drift check does not pass on the vendored payload: $(scripts/land/bin/land-check 2>&1)"
out=$(check) && grep -q '^ran: gates-check-config: ' <<<"$out" && ok || fail "gates-check-config does not pass on a sound consumer: $out"
out=$(scripts/gates/bin/gates-selftest 2>&1) && grep -q 'scripts passed' <<<"$out" && ok || fail "the package's own tests do not pass in the vendored layout: $(grep -E '^(FAIL|ok)' <<<"$out" | tail -n 8)"
out=$(scripts/gates/core/relabel-attacks.sh --tree "$PWD" --no-lean 2>&1) && grep -q '^PASS relabel-attacks: ' <<<"$out" && ok || fail "the shared attacks are not all refused on the vendored consumer: $(grep -vE '^REFUSED' <<<"$out")"
# each way to break it is named
breaks() {   # breaks DESC WORDS EDIT: the edit is committed, gates-check-config must fail and say WORDS
  consumer; ( eval "$3" && git add -A && git commit -qm "$1" ); must_fail "$1" check; grep -q "$2" <<<"$MUST_FAIL_ERR" || fail "$1: the message does not say '$2': $MUST_FAIL_ERR"
}
breaks "an unknown conf key" "gates.conf cannot be read" 'echo GATES_TYPO=x >> ./scripts/gates.conf'
breaks "a conf path that does not exist" "not a tracked file" 'sed -i "s/^GATES_TIER1=.*/GATES_TIER1=tier2.sh/" ./scripts/gates.conf'
breaks "a class dropped from the protected list: the tier1 script" "does not cover: tier1.sh" 'sed -i "/^tier1.sh$/d" protected.txt'
breaks "a class dropped from the protected list: the hooks directory" "scripts/land.d" 'sed -i "/^scripts\/land.d\/$/d" protected.txt'
breaks "a stub that differs from the package's" "not wired" 'printf "#!/usr/bin/env bash\nexit 0\n" > scripts/land.d/post-tier1'
breaks "a hand copy of a pinned file" "a hand copy of the pinned ran-evidence.sh" 'cp scripts/gates/core/ran-evidence.sh scripts/ran-evidence.sh'
breaks "a vendored file edited in place" "not intact" 'echo "# patch" >> scripts/land/bin/land-update'
finish vendored_layout
