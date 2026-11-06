#!/usr/bin/env bash
# Each lint of tests/lint.sh is shown able to FAIL: a scratch repository that holds one violation (and a clean control that passes). Hermetic: the lint under test is copied into the scratch world.
. "$(dirname "$0")/lib.sh"; sandbox
CLEAN_CI=$'name: ci\non:\n  push:\n    branches: [main]\npermissions:\n  contents: read\njobs:\n  t:\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n'
world() {   # world DIR: a scratch repository that passes every lint
  rm -rf "$1"; mkdir -p "$1/tests" "$1/.github/workflows"; cp "$ROOT/tests/lint.sh" "$1/tests/lint.sh"; printf 'public\n' > "$1/.github/visibility"
  printf '%s' "$CLEAN_CI" > "$1/.github/workflows/ci.yml"; printf '#!/usr/bin/env bash\necho hi\n' > "$1/tests/test_a.sh"; chmod +x "$1/tests/test_a.sh" "$1/tests/lint.sh"
  git init -q -b main "$1"
}
lint() { ( cd "$1" && git add -A && tests/lint.sh ); }
W=$T/w
world "$W"; lint "$W" >/dev/null 2>&1 || { echo "FAIL control: the clean world does not pass the lint" >&2; exit 1; }; ok
world "$W"; printf '#!/usr/bin/env bash\nif then\n' > "$W/tests/test_a.sh"; must_fail "unparsable script" lint "$W"
world "$W"; chmod -x "$W/tests/test_a.sh"; must_fail "script not executable" lint "$W"
world "$W"; printf 'echo hi\n' > "$W/tests/test_a.sh"; must_fail "executable without a #! line" lint "$W"
world "$W"; printf 'see /%s/x\n' "home" > "$W/notes.md"; must_fail "local path" lint "$W"
world "$W"; printf 'the %s\n' "cap""tain" > "$W/notes.md"; must_fail "internal name" lint "$W"
world "$W"; sed -i 's/ubuntu-latest/self-hosted/' "$W/.github/workflows/ci.yml"; must_fail "self-hosted runner" lint "$W"
world "$W"; sed -i 's/  push:/  pull_request_target:\n  push:/' "$W/.github/workflows/ci.yml"; must_fail "pull_request_target" lint "$W"
world "$W"; printf 'private\n' > "$W/.github/visibility"; must_fail "visibility not public" lint "$W"
world "$W"; rm "$W/.github/visibility"; must_fail "visibility missing" lint "$W"
world "$W"; sed -i '/^permissions:/,/contents: read/d' "$W/.github/workflows/ci.yml"; must_fail "no permissions" lint "$W"
world "$W"; sed -i 's/contents: read/contents: write/' "$W/.github/workflows/ci.yml"; must_fail "write permission" lint "$W"
world "$W"; printf '#!/usr/bin/env bash\ncat "$RO''OT/scripts/gate-edit-approvals.txt"\n' > "$W/tests/test_a.sh"; must_fail "test reads real approvals" lint "$W"
world "$W"; printf '#!/usr/bin/env bash\ngit -C "$RO''OT" tag\n' > "$W/tests/test_a.sh"; must_fail "test reads real tags" lint "$W"
world "$W"; printf '#!/usr/bin/env bash\nls /t''mp/x*\n' > "$W/tests/test_a.sh"; must_fail "test lists the shared tmp dir" lint "$W"
finish harness
