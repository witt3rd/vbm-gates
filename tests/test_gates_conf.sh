#!/usr/bin/env bash
# core/gates-conf.sh: defaults without a file; every key of KEYS is read; an unknown key, a line that is not GATES_KEY=value, a value of the wrong shape (a path with .., an absolute path, a directory
# entry without /, a directory where one file is wanted) each fail with a line that says why; a quoted value works; nothing in a value is expanded or run. Hermetic: every conf is built in the sandbox.
. "$(dirname "$0")/lib.sh"; sandbox
load() { ( . "$ROOT/core/gates-conf.sh"; gates_load "$1" ) 2>&1; }       # load CONF: exit status and what it said
get() { ( . "$ROOT/core/gates-conf.sh"; gates_load "$1" && printf '%s' "${!2}" ); }   # get CONF VAR
conf() { printf '%s\n' "$2" > "$T/$1.conf"; }
fail() { echo "FAIL gates-conf: $*" >&2; exit 1; }
# defaults: no file at all, and an empty one
[ "$(get "$T/none.conf" GATES_TIER1)" = scripts/tier1.sh ] && [ "$(get "$T/none.conf" GATES_PROTECTED_LIST)" = scripts/protected-paths.txt ] && ok || fail "the defaults are wrong"
conf empty '# nothing but a comment'; load "$T/empty.conf" >/dev/null && [ -z "$(get "$T/empty.conf" GATES_LISTS)" ] && ok || fail "an empty conf did not give the defaults"
# every key of KEYS is accepted (the reader and KEYS cannot disagree): one line per key, each with a valid value
: > "$T/all.conf"; n=0
while read -r k; do
  case $k in GATES_SOURCE_DIRS) v="a/ b/c/";; GATES_RULES_FILE|GATES_TIER1|GATES_PROTECTED_LIST) v=x/y.txt;; *) v='x/a.sh y.txt';; esac
  printf '%s=%s\n' "$k" "$v" >> "$T/all.conf"; n=$((n + 1))
done < <(sed 's/#.*//' "$ROOT/KEYS" | tr -s '[:space:]' '\n' | sed '/^$/d')
[ "$n" -gt 0 ] && load "$T/all.conf" >/dev/null && ok || fail "a key of KEYS is not accepted by the reader ($(load "$T/all.conf"))"
# values
conf v1 'GATES_LISTS="a/x.txt b/y.txt"   '; [ "$(get "$T/v1.conf" GATES_LISTS)" = 'a/x.txt b/y.txt' ] && ok || fail "a quoted, space-separated value was not read"
conf v2 'GATES_LISTS=$(touch /should-not-exist-x)'; must_fail "a command substitution in a value" load "$T/v2.conf"
conf v3 'GATES_TIER1=scripts/a.sh'; [ "$(get "$T/v3.conf" GATES_TIER1)" = scripts/a.sh ] && ok || fail "GATES_TIER1 was not read"
# refusals, each with a reason on stderr
refuse() { conf "$1" "$3"; must_fail "$2" load "$T/$1.conf"; grep -q "$4" <<<"$MUST_FAIL_ERR" || fail "$2: the message does not say why: $MUST_FAIL_ERR"; }
refuse r1 "an unknown key" 'GATES_TIER_ONE=x' 'unknown key GATES_TIER_ONE'
refuse r2 "a typo of a known key" 'GATES_LIST=a/b' 'unknown key'
refuse r3 "a line that is not GATES_KEY=value" 'tier1 = x' 'not a GATES_KEY=value line'
refuse r4 "a key of another package" 'LAND_BASE=main' 'not a GATES_KEY=value line'
refuse r5 "a path with .." 'GATES_LISTS=a/../b' 'not a plain repository path'
refuse r6 "an absolute path" 'GATES_SOURCE=/etc/passwd' 'not a plain repository path'
refuse r7 "a source dir without a trailing /" 'GATES_SOURCE_DIRS=scripts/attacks' 'must end in /'
refuse r8 "a directory where one file is wanted" 'GATES_TIER1=scripts/' 'one plain repository path'
refuse r9 "a list in a single-path key" 'GATES_PROTECTED_LIST=a.txt b.txt' 'one plain repository path'
conf r11 'GATES_WARM_DIRS=.lake build'; [ "$(get "$T/r11.conf" GATES_WARM_DIRS)" = '.lake build' ] && ok || fail "a dot directory is not accepted as a warm dir"
refuse r10 "a warm dir with a trailing /" 'GATES_WARM_DIRS=.lake/' 'must not end in /'
refuse r12 "a bare dot" 'GATES_LISTS=.' 'not a plain repository path'
[ ! -e /should-not-exist-x ] && ok || fail "a value was executed"
finish gates_conf
