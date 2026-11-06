#!/usr/bin/env bash
# The Lean source scans, with their roots from gates.conf (run in the repository; prints `ran: lean-scan: N cases`):
#  1. FORBIDDEN CONSTRUCTS (sorry, admit, axiom, unsafe, implemented_by, csimp) anywhere under GATES_SCAN_DIRS (and the umbrella file <dir>.lean beside each). A comment may mention one only on a line marked `-- tier1-allow`.
#  2. THE IMPORT RULE: a module under a GATES_SPEC_ROOTS directory imports Init (implicitly) and modules of its OWN root only: no Std, no Lean, no other root, no `prelude`.
# Each scan has a negative self-test that runs every time (each forbidden word, the marker, each kind of bad import is flagged on a synthetic line): a scan that cannot fail would pass anything.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); . "$here/../core/lib-ran.sh"; . "$here/../core/gates-conf.sh"
gates_load || { echo "lean-scan: gates.conf cannot be read (above): cannot decide" >&2; exit 2; }
cd "$(git rev-parse --show-toplevel)"
[ -n "$GATES_SCAN_DIRS" ] || { echo "lean-scan: GATES_SCAN_DIRS is empty: nothing would be scanned (set it, or do not run this gate)" >&2; exit 2; }
sources() { local d; for d in "$@"; do find "$d" -name '*.lean' 2>/dev/null; ls "$d.lean" 2>/dev/null || true; done; }   # the files under each dir, and its umbrella
forbidden() { grep -HnE '\b(sorry|admit|axiom|unsafe|implemented_by|csimp)\b' "$@" | grep -v 'tier1-allow' || true; }
roots=$(printf '%s\n' $GATES_SPEC_ROOTS | paste -sd'|' -)
bad_imports() { grep -HnE '^[[:space:]]*((public|meta|private)[[:space:]]+)*(import|prelude)\b' "$@" | grep -vE ":[0-9]+:import ($roots)(\\.[A-Za-z0-9_]+)*[[:space:]]*\$" || true; }
st=$(mktemp "${TMPDIR:-/tmp}/lean-scan.XXXXXX"); trap 'rm -f "$st"' EXIT
fail() { echo "lean-scan: $*" >&2; exit 1; }
# negative self-tests: each forbidden word is flagged, the marker (and only it) lets a comment mention one
for w in sorry admit axiom unsafe implemented_by csimp; do echo "theorem t : True := by $w" > "$st"; [ -n "$(forbidden "$st")" ] && ran_case || fail "the forbidden-constructs scan does not flag '$w'"; done
echo "-- a comment that says sorry -- tier1-allow" > "$st"; [ -z "$(forbidden "$st")" ] && ran_case || fail "the tier1-allow marker is not honoured"
echo "-- a comment that says sorry" > "$st"; [ -n "$(forbidden "$st")" ] && ran_case || fail "an unmarked comment is not flagged"
# the real scan
# shellcheck disable=SC2046
bad=$(forbidden $(sources $GATES_SCAN_DIRS)); [ -z "$bad" ] || { echo "lean-scan: forbidden construct(s):" >&2; echo "$bad" >&2; exit 1; }; ran_case
if [ -n "$GATES_SPEC_ROOTS" ]; then
  first=${GATES_SPEC_ROOTS%% *}
  for imp in 'import Lean' 'import Std.Data.HashMap' 'import NotARoot.Proofs' 'prelude' 'public import Lean.Data.Json' "import ${first}X"; do
    printf '%s\n' "$imp" > "$st"; [ -n "$(bad_imports "$st")" ] && ran_case || fail "the import scan does not flag: $imp"
  done
  printf 'import %s.State\n' "$first" > "$st"; [ -z "$(bad_imports "$st")" ] && ran_case || fail "the import scan flags an import of the library's own root"
  # shellcheck disable=SC2046
  bad=$(bad_imports $(sources $GATES_SPEC_ROOTS)); [ -z "$bad" ] || { echo "lean-scan: a spec module may import only modules of its own root ($GATES_SPEC_ROOTS; Init is implicit):" >&2; echo "$bad" >&2; exit 1; }; ran_case
fi
ran_done lean-scan
