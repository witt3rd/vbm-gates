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
