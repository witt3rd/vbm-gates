#!/usr/bin/env bash
# core/lint-git-hermetic.sh flags a tracked script that makes a scratch git repository before sourcing the hermetic helper, honours `# git-hermetic-ok`, finds scripts by name or #! line and skips the
# vendored packages. Hermetic: every scratch repository is built in the test's own sandbox. (The lint's own shape table runs on every call and is checked by its exit status here.)
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
lint=$ROOT/core/lint-git-hermetic.sh
world() { rm -rf "$T/w"; newrepo "$T/w"; printf '#!/usr/bin/env bash\n. "$(dirname "$0")/core/git-hermetic.sh"\ngit init -q r\n' > "$T/w/a.sh"; }
run() { ( cd "$T/w" && git add -A && "$lint" ) 2>&1; }
world; run >/dev/null && ok || { echo "FAIL: a script that sources the helper first does not pass" >&2; exit 1; }
world; printf '#!/usr/bin/env bash\ngit init -q r\n' > "$T/w/a.sh"; must_fail "init with no helper" run; grep -q 'a.sh:2' <<<"$MUST_FAIL_ERR" || { echo "FAIL: the hit does not name file and line: $MUST_FAIL_ERR" >&2; exit 1; }
world; printf '#!/usr/bin/env bash\ngit clone -q a b\n. core/git-hermetic.sh\n' > "$T/w/a.sh"; must_fail "clone before sourcing" run
world; printf '#!/usr/bin/env bash\ngit init -q r # git-hermetic-ok: not a scratch repo\n' > "$T/w/a.sh"; run >/dev/null && ok || { echo "FAIL: the exception was not honoured" >&2; exit 1; }
world; printf '#!/usr/bin/env bash\ngit init -q r\n' > "$T/w/tool"; chmod +x "$T/w/tool"; rm "$T/w/a.sh"; must_fail "a script with no .sh name, found by its #! line" run
world; mkdir -p "$T/w/scripts/gates"; printf 'git init -q r\n' > "$T/w/scripts/gates/v.sh"; run >/dev/null && ok || { echo "FAIL: a vendored package was scanned" >&2; exit 1; }
finish lint_git_hermetic
