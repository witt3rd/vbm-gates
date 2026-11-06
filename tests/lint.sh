#!/usr/bin/env bash
# Repository lints: every shell file parses; scripts are executable; no internal name or local path anywhere (the repository is public); a workflow is hosted-only, read-only
# and never runs a fork's code with secrets; a test never reads this repository's real state. tests/test_harness.sh shows each lint able to fail.
set -euo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"; bad=0
fail() { echo "lint: $*" >&2; bad=1; }
files=$(git ls-files 2>/dev/null | grep -v '^scripts/land/' || true)
for f in $files; do
  [ -f "$f" ] || continue
  sb=0; [ "$(head -c2 "$f")" = '#!' ] && sb=1
  case $f in *.sh) bash -n "$f" || fail "$f does not parse";; esac
  # the mode follows the content (a vendored package keeps it that way): a file is executable iff it starts with #!
  case $f in core/*|hooks/*|bin/*|lean/*|attacks/*|tests/*|scripts/land-direct) if [ -x "$f" ]; then [ "$sb" = 1 ] || fail "$f is executable but has no #! line"; else [ "$sb" = 0 ] || fail "$f has a #! line but is not executable"; fi;; esac
done
# names that must never appear (internal projects, hosts, people, local paths); the vendored copy is linted upstream
deny='(first''mate|rog''er|mcfee''ly|sp''ire|ja''nus|/hom''e/|c''aptain|\bk''ing\b|\bpr''ince\b|fle''et|\blu''ng\b)'
for f in $files; do
  [ -f "$f" ] && [ "$f" != LICENSE ] || continue
  hits=$(grep -nEi -- "$deny" "$f" || true)
  [ -z "$hits" ] || fail "$f names something internal: $(echo "$hits" | tr '\n' ' ' | cut -c1-200)"
done
# PUBLIC, NEVER SELF-HOSTED: no workflow names a self-hosted runner or pull_request_target, every workflow declares a read-only token, and the repository says it is public
[ "$(cat .github/visibility 2>/dev/null)" = public ] || fail ".github/visibility must say exactly public"
for w in .github/workflows/*.yml; do
  [ -f "$w" ] || continue
  ! grep -qE '^[^#]*(self-hosted|pull_request_target)' "$w" || fail "$w names self-hosted or pull_request_target: hosted runners only, never a fork's code with secrets"
  grep -qE '^permissions:' "$w" || fail "$w declares no top-level permissions (contents: read)"
  ! grep -qE '^[[:space:]]*(contents|actions|packages|pull-requests|id-token): *write' "$w" || fail "$w asks for a write permission"
done
# a test builds its OWN world: it never reads the real repository's approvals, lists, baselines, configuration or tags (a test that did failed the first real approval)
hits=$(grep -nE '(\$\{?(ROOT|root|here)\}?|\.\./)[^ "]*(approvals|protected-paths|baseline|gates\.conf|land\.conf|signers)|git +-C +"?\$\{?(ROOT|root)\}?"? +(tag|log|show|describe|rev-parse|ls-files|cat-file|for-each-ref|diff)|(cat|grep|sed|head|tail|wc|source|\.) +[^|;&]*(^| |")scripts/[a-z.-]*(approvals|protected-paths|gates\.conf)' tests/lib.sh tests/test_*.sh tests/lean/test_*.sh 2>/dev/null || true)
[ -z "$hits" ] || fail "a test reads the real repository's approvals, lists, baselines, config or tags (build a scratch world): $(echo "$hits" | sed -n 1,2p | tr '\n' ' ' | cut -c1-200)"
# a test never looks at the machine-wide tmp dir: it lists, finds or removes only under its own sandbox ($T, whose TMPDIR tests/lib.sh sets)
hits=$(grep -nE '(ls|find|rm|cat|grep)[^|;&]*(\$\{?TMPDIR:-/tmp\}?|[ "'"'"'=]/tmp)[^|;& ]*\*' tests/test_*.sh 2>/dev/null || true)
[ -z "$hits" ] || fail "a test reads the shared tmp dir (use its own sandbox, \$T): $(echo "$hits" | sed -n 1,2p | tr '\n' ' ' | cut -c1-200)"
exit "$bad"
