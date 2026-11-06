#!/usr/bin/env bash
# core/lint-pipefail.sh flags a producer piped into an early-exiting consumer (the SIGPIPE flake under pipefail), honours `# pipefail-ok`, reads tracked shell files by name or #! line and skips the
# vendored packages. Hermetic: every scratch repository is built in the test's own sandbox; the lint runs in it from the sandbox's working directory.
. "$(dirname "$0")/lib.sh"; sandbox
lint=$ROOT/core/lint-pipefail.sh
world() {   # world: a scratch repository with one clean script
  rm -rf "$T/w"; newrepo "$T/w"; printf '#!/usr/bin/env bash\nset -euo pipefail\necho hi\n' > "$T/w/a.sh"
}
run() { ( cd "$T/w" && git add -A && "$lint" ) 2>&1; }
# the shapes are assembled so that this test file does not itself contain them
P='|'; bad1="x $P gre""p -q foo"; bad2="x $P he""ad -1"; bad3="x $P gre""p -m1 y"
world; run >/dev/null && ok || { echo "FAIL: the clean world does not pass" >&2; exit 1; }
for b in "$bad1" "$bad2" "$bad3"; do world; printf '%s\n' "$b" >> "$T/w/a.sh"; must_fail "flags: $b" run; grep -q 'a.sh:' <<<"$MUST_FAIL_ERR" || { echo "FAIL: the hit does not name the file: $MUST_FAIL_ERR" >&2; exit 1; }; done
world; printf '%s # pipefail-ok\n' "$bad2" >> "$T/w/a.sh"; run >/dev/null && ok || { echo "FAIL: the pipefail-ok exception was not honoured" >&2; exit 1; }
world; printf '#!/usr/bin/env bash\n%s\n' "$bad1" > "$T/w/tool"; chmod +x "$T/w/tool"; must_fail "a tracked script with no .sh name, found by its #! line" run
world; printf 'not a script: %s\n' "$bad1" > "$T/w/notes.txt"; run >/dev/null && ok || { echo "FAIL: a non-script file was scanned" >&2; exit 1; }
world; mkdir -p "$T/w/scripts/gates" "$T/w/scripts/land"; printf '%s\n' "$bad1" > "$T/w/scripts/gates/v.sh"; printf '%s\n' "$bad1" > "$T/w/scripts/land/v.sh"; run >/dev/null && ok || { echo "FAIL: a vendored package was scanned (it is checked upstream)" >&2; exit 1; }
finish lint_pipefail
