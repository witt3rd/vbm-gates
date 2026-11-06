#!/usr/bin/env bash
# acceptance.sh [REV]: ONE REAL APPROVAL, END TO END, ON THE REAL TREE (not part of Tier 1: it runs Tier 1 once more). Before a release: in a scratch clone of this repository at REV (default HEAD) commit one real,
# well-formed approval record into each real approvals file the tree names (the gate-edit approvals file and, when it differs, the protected approvals file of scripts/land.conf), then run the real Tier 1
# (tests/run.sh: the lints, the shared attack suite on the tree, every hermetic test, the manifest and config checks) and, where lake is usable, the Lean leg. It must pass. A red here is a test that reads
# real state (the first real record on the tree made one fail before) or a defect of the mechanism: fix it first.
set -euo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd); rev=${1:-HEAD}
. "$root/core/git-hermetic.sh"   # no ambient git configuration in the scratch clone
T=$(mktemp -d "${TMPDIR:-/tmp}/gates-acceptance.XXXXXX"); trap 'rm -rf "$T"' EXIT
git clone -q "$root" "$T/c"; cd "$T/c"; git checkout -q "$(git -C "$root" rev-parse "$rev")"
git config user.name acceptance; git config user.email acceptance@example.invalid; git config commit.gpgsign false
conf() { sed -n "s/^$1=//p" scripts/land.conf | sed -n 1p; }
files=$(printf '%s\n' "$(conf LAND_APPROVALS)" "$(conf LAND_PROTECTED_APPROVALS)" | sed '/^$/d' | sort -u); [ -n "$files" ] || files=scripts/gate-edit-approvals.txt
for f in $files; do
  printf 'tests/run.sh | %s | acceptance: a real record on the real tree, never consumed | %s\n' "$(printf 'acceptance %s' "$f" | sha256sum | cut -d' ' -f1)" "$(date -u +%F)" >> "$f"
  echo "acceptance: a real approval record committed into $f"
done
git add -A; git commit -q -m "chore(approval): acceptance record"
tests/run.sh
if command -v lake >/dev/null 2>&1 && lake --version >/dev/null 2>&1; then tests/run-lean.sh; else echo "acceptance: NO usable lake on this host: the Lean leg was not run here (run it where the toolchain is)"; fi
echo "acceptance: ok at $(git rev-parse --short HEAD) (the candidate) with one real approval per real approvals file"
