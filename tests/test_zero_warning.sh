#!/usr/bin/env bash
# lean/check-zero-warning.sh must FAIL when it cannot do its job and pass only when it ran: with the compiler REFUSED by a guard, crashing, unable to fail, failing a clean file, or the lakefile not setting
# warningAsError. A stub `lake` (first on PATH, in the test's sandbox) plays each of them against a scratch repository; the control, a stub that behaves, passes with its evidence line.
. "$(dirname "$0")/lib.sh"; . "$ROOT/core/git-hermetic.sh"; sandbox
zw=$ROOT/lean/check-zero-warning.sh
newrepo "$T/w"; printf 'package x\nlean_lib X where\n  leanOptions := #[⟨`weak.warningAsError, true⟩]\n' > "$T/w/lakefile.lean"; mkdir "$T/bin"
stub() { printf '#!/usr/bin/env bash\nf=${@: -1}\n%s\n' "$1" > "$T/bin/lake"; chmod +x "$T/bin/lake"; }
zwrun() { ( cd "$T/w" && PATH="$T/bin:$PATH" "$zw" ) 2>&1; }
stub 'if grep -q "let y" "$f"; then echo "error: Variable name \`y\` is not explicitly referenced." >&2; exit 1; fi; exit 0'
out=$(zwrun) && grep -q '^ran: zero-warning: 3 cases' <<<"$out" && ok || { echo "FAIL: the control (a compiler that behaves) did not pass: $out" >&2; exit 1; }
stub 'echo "guard: run this elsewhere." >&2; exit 126'; must_fail "compiler refused by a guard (the original defect)" zwrun
stub 'echo "segmentation fault" >&2; exit 139'; must_fail "compiler crashing" zwrun
stub 'exit 0'; must_fail "a compiler that cannot fail" zwrun
stub 'echo "error: something else" >&2; exit 1'; must_fail "a compiler that fails a clean file and a warning for another reason" zwrun
stub 'if grep -q "let y" "$f"; then echo "error: Variable name \`y\` is not explicitly referenced." >&2; exit 1; fi; exit 0'
printf 'package x\n' > "$T/w/lakefile.lean"; must_fail "lakefile without warningAsError" zwrun
finish zero_warning
