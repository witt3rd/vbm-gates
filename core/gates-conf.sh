# Sourced, never run. The reader of scripts/gates.conf, the one lever of a repository that vendors this package (the same reader the checks use, so reader and check cannot disagree).
#   gates_load [CONF]   sets the GATES_* variables from CONF (default: the repository's scripts/gates.conf; the judge passes main's copy). An absent file means the defaults. Returns 2 with one line
#                       on stderr for an unknown key (vbm-land's pkgconf_load against KEYS), a line that is not GATES_KEY=value, or a value of the wrong shape.
# Two layouts, told apart by PIN: a vendored copy (scripts/gates/{core,KEYS,PIN}, vbm-land under scripts/land/) and the source repository itself (core/, KEYS, scripts/gates.conf, scripts/land/).
_gc_home=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [ -e "$_gc_home/PIN" ]; then GATES_SCRIPTS=$(cd "$_gc_home/.." && pwd); else GATES_SCRIPTS=$_gc_home/scripts; fi
GATES_HOME=$_gc_home; GATES_KEYS=$_gc_home/KEYS
. "$GATES_SCRIPTS/land/lib/pkg.sh"
_gc_path_ok() { [[ "$1" =~ ^[A-Za-z0-9_@+.][A-Za-z0-9_./@+-]*$ && "/$1/" != *"/../"* && "/$1/" != *"/./"* && "$1" != *//* ]]; }   # a plain relative path (a trailing / is a directory)
gates_load() {
  local conf=${1:-$GATES_SCRIPTS/gates.conf} k v p
  GATES_TIER1=scripts/tier1.sh GATES_PROTECTED_LIST=scripts/protected-paths.txt GATES_STRICT= GATES_LISTS= GATES_SOURCE= GATES_SOURCE_DIRS= GATES_APPROVABLE= GATES_RULES_FILE= GATES_WARM_DIRS= GATES_ATTACK_VARS= GATES_SCAN_DIRS= GATES_SPEC_ROOTS= GATES_AXIOM_ROOTS=
  pkgconf_load gates "$conf" "$GATES_KEYS" || return 2
  for k in GATES_TIER1 GATES_PROTECTED_LIST GATES_RULES_FILE; do v=${!k}; { [ -z "$v" ] && [ "$k" = GATES_RULES_FILE ]; } || { _gc_path_ok "$v" && [[ "$v" != */ ]]; } || { echo "gates.conf: $k must be one plain repository path (is '$v')" >&2; return 2; }; done
  for k in GATES_STRICT GATES_LISTS GATES_SOURCE GATES_SOURCE_DIRS GATES_APPROVABLE GATES_WARM_DIRS GATES_SCAN_DIRS GATES_SPEC_ROOTS; do
    for p in ${!k}; do _gc_path_ok "$p" || { echo "gates.conf: $k holds '$p', which is not a plain repository path" >&2; return 2; }; done
  done
  for p in $GATES_SOURCE_DIRS; do [[ "$p" == */ ]] || { echo "gates.conf: GATES_SOURCE_DIRS entry '$p' must end in /" >&2; return 2; }; done
  for p in $GATES_ATTACK_VARS; do [[ "$p" =~ ^ATK_[A-Z0-9_]+=[A-Za-z0-9_./@:+,-]*$ ]] || { echo "gates.conf: GATES_ATTACK_VARS holds '$p', which is not ATK_NAME=plain-value" >&2; return 2; }; done
  for p in $GATES_AXIOM_ROOTS; do [[ "$p" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "gates.conf: GATES_AXIOM_ROOTS holds '$p', which is not a module root name" >&2; return 2; }; done
  for p in $GATES_WARM_DIRS; do [[ "$p" != */ ]] || { echo "gates.conf: GATES_WARM_DIRS entry '$p' must not end in /" >&2; return 2; }; done
  return 0
}
