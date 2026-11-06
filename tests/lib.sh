#!/usr/bin/env bash
# Shared helpers for the test scripts. HERMETIC BY CONSTRUCTION: a test sources this file, calls `sandbox`, builds its OWN world in $T (repository, lists, baselines,
# approvals) and ends with `finish NAME`. It never reads this repository's real approvals, lists, baselines, configuration or tags (tests/lint.sh refuses a test that names them).
set -euo pipefail
export LC_ALL=C GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)   # the code under test (never its data)
T=; CASES=0
sandbox() {   # a private world: $T, with its own TMPDIR, removed when the test ends; no enclosing repository can be found from it
  T=$(mktemp -d "${TMPDIR:-/tmp}/gates-test.XXXXXX"); mkdir -p "$T/tmp"; export TMPDIR=$T/tmp GIT_CEILING_DIRECTORIES=$(dirname "$T")
  trap 'rm -rf "$T"' EXIT
}
newrepo() {   # newrepo DIR: a scratch repository on branch main with one commit
  git init -q -b main "$1"; git -C "$1" config commit.gpgsign false
  ( cd "$1" && echo seed > seed.txt && git add -A && git commit -qm "chore: seed" )
}
ok() { CASES=$((CASES + 1)); }   # a case that was evaluated and held
must_fail() {   # must_fail DESC CMD...: the command has to FAIL and say why (output); not run, refused or empty output is a failure of the test
  local d=$1 out rc=0; shift
  out=$("$@" 2>&1) || rc=$?
  [ "$rc" != 0 ] || { echo "FAIL $d: it did not fail (the check cannot fail)" >&2; exit 1; }
  case $rc in 124|126|127) echo "FAIL $d: refused or missing (exit $rc): $out" >&2; exit 1;; esac
  [ -n "$out" ] || { echo "FAIL $d: it failed without saying why" >&2; exit 1; }
  ok
}
finish() { [ "$CASES" -gt 0 ] || { echo "FAIL $1: no case ran" >&2; exit 1; }; echo "ran: $1: $CASES cases"; }
