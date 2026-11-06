#!/usr/bin/env bash
# Lint: a script that creates a scratch git repository or remote (`git init`, `git clone`, `git worktree add` of one) must be hermetic: it must source git-hermetic.sh
# BEFORE the first such line (no ambient identity, config, default branch, hooksPath or enclosing GIT_DIR; a scratch base is a tree snapshot, not a push of history). The
# CI runner has no user.name, a shallow checkout and its own default branch; a scratch repo that leans on the developer's config goes green here and red there (Tier 2 acceptance
# leg, "failed to push some refs ... shallow update not allowed"). A line that needs the exception says `# git-hermetic-ok` (and why).
# Usage: lint-git-hermetic.sh [--files F...]   (run in the repository)
export LC_ALL=C
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"   # the consumer's repository (a vendored copy lives in scripts/gates/core)
self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
re_make='(^|[|;&{(]|\$\()[[:space:]]*git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--[a-z-]+(=[^[:space:]]+)?))*[[:space:]]+(init|clone)([[:space:]]|$)'
re_src='^[[:space:]]*(\.|source)[[:space:]]+[^#]*git-hermetic\.sh'
# scan FILE...: print file:line:text for every repo-creating line not preceded by the hermetic source line
scan() {
  local f
  for f in "$@"; do
    RE_MAKE=$re_make RE_SRC=$re_src awk -v F="$f" '
      BEGIN { make = ENVIRON["RE_MAKE"]; src = ENVIRON["RE_SRC"]; ok = 0 }
      /^[[:space:]]*#/ { next }
      $0 ~ src { ok = 1; next }
      /# git-hermetic-ok/ { next }
      $0 ~ make && !ok { printf "%s:%d: git init/clone before sourcing git-hermetic.sh: %s\n", F, NR, $0 }' "$f"
  done
}
if [ "${1:-}" = --files ]; then shift; hits=$(scan "$@"); [ -z "$hits" ] || { echo "$hits" >&2; exit 1; }; exit 0; fi
# negative self-test: each known-bad script is flagged (also through the exit status of the real entry point), each good one passes
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mk() { printf '%s\n' "$@" > "$t/s.sh"; }
for bad in 'git init -q "$T/r"' 'git init -q --bare -b main "$T/remote.git"' 'git clone -q "$T/remote.git" "$T/work"' 'git -C "$T/wt" init -q' 'x=$(git clone -q a b)' \
           'a && git clone --depth 1 file://x y' 'git -c user.name=t clone a b' 'cd x; git init'; do
  mk "$bad"; [ -n "$(scan "$t/s.sh")" ] || { echo "lint-git-hermetic: self-test: did not flag: $bad" >&2; exit 1; }
  if "$self" --files "$t/s.sh" 2>/dev/null; then echo "lint-git-hermetic: self-test: exit 0 on: $bad" >&2; exit 1; fi
done
mk 'git init -q r' '. scripts/git-hermetic.sh'; [ -n "$(scan "$t/s.sh")" ] || { echo "lint-git-hermetic: self-test: sourcing AFTER the first git init passed" >&2; exit 1; }
mk '# . scripts/git-hermetic.sh' 'git init -q r';  [ -n "$(scan "$t/s.sh")" ] || { echo "lint-git-hermetic: self-test: a commented-out source passed" >&2; exit 1; }
for ok in 'git status' 'git ls-files' 'git init -q r # git-hermetic-ok: not a scratch repo' 'echo "git init later"' 'git commit -m "clone"' 'git rev-parse HEAD'; do
  mk "$ok"; [ -z "$(scan "$t/s.sh")" ] || { echo "lint-git-hermetic: self-test: flagged a good line: $ok" >&2; exit 1; }
done
for src in '. scripts/git-hermetic.sh' 'source scripts/git-hermetic.sh' '. "$here/scripts/git-hermetic.sh"' '. "$(dirname "$0")/git-hermetic.sh"'; do
  mk 'cd x' "$src   # why" 'git init -q r' 'git clone -q r c'; [ -z "$(scan "$t/s.sh")" ] || { echo "lint-git-hermetic: self-test: flagged after sourcing: $src" >&2; exit 1; }
done
# every tracked shell file (by name or #! line) except the vendored packages and the helper and lint themselves
files=$(git ls-files | grep -vE '^scripts/(land|gates)/|(^|/)(lint-)?git-hermetic\.sh$' | while IFS= read -r f; do case $f in *.sh) echo "$f";; *) [ -f "$f" ] && head -n1 "$f" | grep -E '^#!.*(bash|/sh)' >/dev/null && echo "$f"; esac; done || true)
# shellcheck disable=SC2086
hits=$(scan $files)
[ -z "$hits" ] || { echo "lint-git-hermetic: a scratch git repo that is not hermetic (add '. <path>/git-hermetic.sh' before it, or say # git-hermetic-ok):" >&2; echo "$hits" >&2; exit 1; }
echo "lint-git-hermetic: ok"
