# (sourced, never run: no #! line, so no executable bit)
# Shared helpers for the test scripts. HERMETIC BY CONSTRUCTION: a test sources this file, calls `sandbox`, builds its OWN world in $T (repository, lists, baselines,
# approvals) and ends with `finish NAME`. It never reads this repository's real approvals, lists, baselines, configuration or tags (tests/lint.sh refuses a test that names them).
set -euo pipefail
export LC_ALL=C
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)   # the code under test (never its data)
. "$ROOT/core/git-hermetic.sh"   # no ambient git configuration, identity, default branch or hooks in any scratch repository
T=
sandbox() {   # a private world: $T, with its own TMPDIR, removed when the test ends; no enclosing repository can be found from it
  T=$(mktemp -d "${TMPDIR:-/tmp}/gates-test.XXXXXX"); mkdir -p "$T/tmp"; export TMPDIR=$T/tmp GIT_CEILING_DIRECTORIES=$(dirname "$T")
  trap 'rm -rf "$T"' EXIT
}
newrepo() {   # newrepo DIR: a scratch repository on branch main with one commit
  git init -q -b main "$1"; git -C "$1" config commit.gpgsign false
  ( cd "$1" && echo seed > seed.txt && git add -A && git commit -qm "chore: seed" )
}
. "$ROOT/core/lib-ran.sh"   # ran-evidence: ran_case, ran_done and must_fail (a refused, missing, timed-out or silent command is not a passing negative test)
ok() { ran_case; }   # a case that was evaluated and held
finish() { ran_done "$1"; }   # prints `ran: NAME: N cases`; fails when no case ran
gdi_world() {   # gdi_world [APPROVABLE...]: the synthetic world of the judge's tests: a scratch repository $T/w (cwd; its base commit in $base) with its own baseline, rules, lists, tier1 script, strict file and sources, and $T/gates.conf
  local W=$T/w; cd "$T"; rm -rf "$W"; newrepo "$W"; cd "$W"; mkdir -p scripts/attacks b docs
  printf 'GATES_TIER1=t1.sh\nGATES_STRICT=pin.txt\nGATES_LISTS=lists.txt scripts/plist.txt\nGATES_SOURCE=gate.sh\nGATES_SOURCE_DIRS=scripts/attacks/\nGATES_PROTECTED_LIST=scripts/plist.txt\nGATES_RULES_FILE=rules.txt\nGATES_APPROVABLE=%s\n' "$*" > "$T/gates.conf"
  printf '# FILE | KEY-REGEX | FIELDS | removable|fixed [| approvable]\nb/ledger.txt | proved | f0=up | fixed\nb/ledger.txt | open | f0=down | fixed\nb/ledger.txt | share | f0=ratio,f1=ratio | fixed | approvable\nb/ledger.txt | Mod.* | f0=down | removable\n' > rules.txt
  printf 'proved 5\nopen 3\nshare 2 3\nModA 4\n' > b/ledger.txt; printf '#!/usr/bin/env bash\nset -e\necho a\n' > t1.sh; printf 'v1\n' > pin.txt; printf 'x\n' > lists.txt; printf 'a/\nb.txt\n' > scripts/plist.txt
  printf 'g\n' > gate.sh; printf 'a\n' > scripts/attacks/01.sh; echo d > docs/a.md; git add -A; git commit -qm base; base=$(git rev-parse HEAD)
}
LANDLIB=$ROOT/scripts/land/lib   # vbm-land's library of the vendored lander (code under test, not data): ga_hash, the hash an approval binds
