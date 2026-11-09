#!/usr/bin/env bash
# trust-ledger.sh [--conf FILE] [--count]: the trust-ledger gate. The repository's trust ledger (GATES_TRUST_LEDGER) names everything outside our direct control that the repository executes or depends on. The REQUIRED
# set is derived from the tree, never from the ledger: every C file under runtime/ and abi/, every hand-written binding loader, the build pins, every @[extern] symbol under GATES_TRUST_DIRS and
# abi/, what the Lean pin brings, the tools the repository's own scripts run, and whatever the repository's GATES_TRUST_EXTRA script prints (one key per line: closure modules, pinned libraries).
# A boundary with no entry FAILS; an entry covering nothing required FAILS (core/trust-ledger.py negative-self-tests itself on every run). Off (a no-op, exit 0) when GATES_TRUST_LEDGER is unset.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")/.." && pwd); cd "$(git rev-parse --show-toplevel)"
conf=; if [ "${1:-}" = --conf ]; then conf=$2; shift 2; fi   # the conf to read (the test passes its scratch one; default: the repository's scripts/gates.conf)
. "$here/core/gates-conf.sh"; gates_load $conf
[ -n "$GATES_TRUST_LEDGER" ] || { echo "trust ledger: off (GATES_TRUST_LEDGER is not set)"; exit 0; }
if [ "${1:-}" = --count ]; then grep -c '^### T[0-9]' "$GATES_TRUST_LEDGER"; exit 0; fi
req=$(mktemp); trap 'rm -f "$req"' EXIT
files() { git ls-files --cached --others --exclude-standard "$@"; }   # a file not yet added is still required
roots=scripts,docs,abi,runtime,bindings,vectors; dirs=abi
for d in $GATES_TRUST_DIRS; do roots="$roots,$d"; dirs="$dirs $d"; done
{
  { files 'runtime/*.c' 'abi/*.c' 'bindings/*/loader.*' lean-toolchain mise.toml lakefile.lean; } | sed 's/^/file:/'
  # shellcheck disable=SC2086
  grep -rhE '^[[:space:]]*@\[extern' $dirs --include='*.lean' 2>/dev/null | sed -E 's/.*@\[extern[^"]*"([^"]+)".*/extern:\1/; t; s/.*/extern:UNNAMED/' | sort -u || true
  [ -f lean-toolchain ] && printf '%s\n' lean-compiler lean-runtime clang-lld || true
  [ -z "$GATES_TRUST_EXTRA" ] || "$GATES_TRUST_EXTRA"
  echo tool:python3   # the checker itself
  for t in git mise wt flock lake leanc node cargo; do   # the vendored packages are pinned and checked upstream: not scanned
    files scripts lakefile.lean | grep -vE '^scripts/(land|gates)/|trust[-_]ledger' | xargs grep -lw -- "$t" >/dev/null 2>&1 && echo "tool:$t" || true; done
} | sort -u > "$req"
python3 "$here/core/trust-ledger.py" "$GATES_TRUST_LEDGER" "$req" "$roots"
