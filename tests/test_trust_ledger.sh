#!/usr/bin/env bash
# core/trust-ledger.sh must fail when a boundary of the tree has no entry, when an entry covers nothing the tree requires, when an entry is incomplete, and when the ledger is missing; pass (with its evidence line) on a
# complete ledger; and be a no-op while off. Each case runs against a scratch repository built here, with its own ledger (the required set comes from the tree, so the repository's real ledger is never read).
. "$(dirname "$0")/lib.sh"; sandbox
tl=$ROOT/core/trust-ledger.sh
world() {   # a repository with one C file, a Lean pin, one script naming git, and a complete ledger
  cd "$T"; rm -rf w; newrepo w; cd w; mkdir -p runtime scripts docs; printf 'int f(void){return 0;}\n' > runtime/rt.c; echo leanprover/lean4:v4.0.0 > lean-toolchain
  printf '#!/usr/bin/env bash\ngit status\n' > scripts/x.sh; printf 'GATES_TRUST_LEDGER=docs/trust-ledger.md\n' > scripts/gates.conf; echo t > scripts/t.sh
  entry() { printf '### %s. %s\n- **What:** something outside our control that runs\n- **Enters:** runtime/rt.c is compiled into the module\n- **Assumes:** no written contract for it\n- **Test:** scripts/t.sh runs it\n- **Owner:** the maintainer\n- **Plan:** accept because nothing replaces it yet\n- **Covers:** %s\n\n' "$1" "$2" "$3"; }
  { printf '# Trust ledger\n\n'; entry T01 the-c-file '`file:runtime/rt.c`'; entry T02 the-pin '`file:lean-toolchain` `lean-compiler` `lean-runtime` `clang-lld`'; entry T03 tools '`tool:python3` `tool:git`'; } > docs/trust-ledger.md
  git add -A; git commit -qm world
}
run() { ( cd "$T/w" && "$tl" --conf scripts/gates.conf ) 2>&1; }
world; out=$(run) && grep -q '^trust ledger: 3 entries' <<<"$out" && ok || { echo "FAIL: the control (a complete ledger) did not pass: $out" >&2; exit 1; }
world; sed -i '/^- \*\*Covers:\*\* `tool:python3`/s/ `tool:git`//' docs/trust-ledger.md; must_fail "a tool the scripts run with no entry" run
world; printf 'int g(void){return 1;}\n' > runtime/new.c; must_fail "a new C file with no entry" run
world; sed -i 's#^- \*\*Covers:\*\* `file:runtime/rt.c`#- **Covers:** `file:runtime/rt.c` `file:runtime/gone.c`#' docs/trust-ledger.md; must_fail "an entry covering a file the tree does not have" run
world; sed -i '0,/^- \*\*Plan:\*\*.*/s//- **Plan:** /' docs/trust-ledger.md; must_fail "an entry with no plan" run
world; sed -i 's#scripts/t.sh runs it#scripts/gone.sh runs it#' docs/trust-ledger.md; must_fail "an entry citing a test file that does not exist" run
world; rm docs/trust-ledger.md; must_fail "a missing ledger" run
world; printf 'GATES_TRUST_LEDGER=docs/trust-ledger.md\nGATES_TRUST_EXTRA=scripts/extra.sh\n' > scripts/gates.conf; printf '#!/usr/bin/env bash\necho module:Foo\n' > scripts/extra.sh; chmod +x scripts/extra.sh; must_fail "a key from the repository's extra derivation with no entry" run
world; : > scripts/gates.conf; out=$(run) && grep -q '^trust ledger: off' <<<"$out" && ok || { echo "FAIL: off was not a no-op: $out" >&2; exit 1; }
finish trust_ledger
