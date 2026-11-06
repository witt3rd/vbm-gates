#!/usr/bin/env bash
# The protected-set gate: does the change <base>..<head> touch a path that waits for the owner?
#   protected-set.sh [--list PATH] <base> <head>     exit 0: touches none; exit 1: prints each touched protected path; exit 2: cannot decide (fails closed)
# The list is PATH (repository-relative, default scripts/protected-paths.txt) as of <base> (the head cannot loosen the list it is judged by; the list file is itself listed, so a change to it
# is reported too). Without a copy at <base> (the commit that introduces the gate) the working-tree copy at the same path is used. Run it in the repository.
# The diff is taken from the merge base, with renames split into a deletion and an addition, so moving a file out of (or into) the set is reported.
# PROTECTED_PATHS_FILE overrides the list (self-test only).
# An entry may be a NAME PATTERN (a shell glob: `scripts/*Gate.lean`, `scripts/lint-*`; `*` also crosses `/`): a new file that fits the pattern is protected with no edit
# of the list (the list is a shared edit point otherwise). Entries are matched by `matches` below: exactly, as a directory prefix, or as a glob.
#   protected-set.sh --superset <old-list-file> <new-list-file>   exit 0: every entry of the old list is still protected by the new one (an exact path, a
#                      directory or a pattern is covered by an equal entry, a directory above it or a pattern matching it); exit 1: prints the dropped entries.
set -euo pipefail
matches() {  # matches PATH ENTRY
  local p=$1 e=$2
  [ "$p" = "$e" ] && return 0
  [ "${e: -1}" = "/" ] && [ "${p#"$e"}" != "$p" ] && return 0
  case $e in *[*?[]*) case $p in $e) return 0;; esac;; esac   # shell glob; $e unquoted on purpose
  return 1
}
read_entries() {  # read_entries FILE: one entry per line, "#" comments, leading "?" dropped
  local l; while IFS= read -r l || [ -n "$l" ]; do l=${l%%#*}; l=${l//[[:space:]]/}; l=${l#\?}; [ -n "$l" ] && echo "$l"; done < "$1"
}
if [ "${1:-}" = --superset ]; then
  old=${2:?usage: protected-set.sh --superset <old> <new>}; new=${3:?usage: protected-set.sh --superset <old> <new>}
  mapfile -t ne < <(read_entries "$new"); [ "${#ne[@]}" -gt 0 ] || { echo "protected-set: the new list is empty" >&2; exit 1; }
  dropped=0
  while IFS= read -r o; do
    ok=0; for e in "${ne[@]}"; do matches "$o" "$e" && { ok=1; break; }; done
    [ "$ok" = 1 ] || { echo "$o"; dropped=1; }
  done < <(read_entries "$old")
  exit "$dropped"
fi
listpath=scripts/protected-paths.txt
if [ "${1:-}" = --list ]; then listpath=${2:?usage: protected-set.sh --list PATH <base> <head>}; shift 2; fi
base=${1:?usage: protected-set.sh [--list PATH] <base> <head>}; head=${2:?usage: protected-set.sh [--list PATH] <base> <head>}
top=$(git rev-parse --show-toplevel) || { echo "protected-set: not inside a git repository" >&2; exit 2; }
mb=$(git merge-base "$base" "$head") || { echo "protected-set: no merge base for $base $head" >&2; exit 2; }
if [ -n "${PROTECTED_PATHS_FILE:-}" ]; then list=$(cat "$PROTECTED_PATHS_FILE")
elif list=$(git show "$base:$listpath" 2>/dev/null); then :
else list=$(cat "$top/$listpath") || { echo "protected-set: no list at $listpath on $base or in the working tree" >&2; exit 2; }; fi
entries=(); while IFS= read -r l; do l=${l%%#*}; l=${l//[[:space:]]/}; l=${l#\?}; [ -n "$l" ] && entries+=("$l"); done <<<"$list"
[ "${#entries[@]}" -gt 0 ] || { echo "protected-set: the protected list is empty (refusing to pass everything)" >&2; exit 2; }
hit=0
while IFS= read -r -d '' p; do
  for e in "${entries[@]}"; do
    if matches "$p" "$e"; then echo "$p"; hit=1; break; fi
  done
done < <(git diff --name-only --no-renames -z "$mb" "$head")
[ "$hit" = 0 ] || { echo "protected-set: the change touches the protected set ($listpath): it waits for the owner" >&2; exit 1; }
