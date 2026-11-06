#!/usr/bin/env bash
# core/lint-workflows.py passes a valid workflow and FAILS on: `with:` under a `run:` step, a step with both/neither of uses/run, no jobs, a job with no steps, broken YAML, no trigger, a self-hosted
# runner unless .github/visibility says private (also behind an expression), the pull_request_target trigger, a secret other than GITHUB_TOKEN. Hermetic: every workflow and the visibility file
# are built in the test's own sandbox (the repository's own workflows are checked by tests/run.sh, a separate named check, not here).
. "$(dirname "$0")/lib.sh"; sandbox
lint=$ROOT/core/lint-workflows.py
export LINT_VISIBILITY_FILE=$T/visibility   # absent = public: self-hosted must be refused
neg() { # neg <name> <yaml>: the linter must reject it AND say why (a python that was refused, a crash or silence is not a rejection of this shape)
  printf '%s\n' "$2" > "$T/$1.yml"
  must_fail "workflow $1" "$lint" "$T/$1.yml"
  ! grep -qE 'Traceback' <<<"$MUST_FAIL_ERR" || { echo "FAIL: '$1' crashed the linter instead of being rejected: $MUST_FAIL_ERR" >&2; exit 1; }
}
head='name: x
on: push'
ok_wf="$head
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - run: true"
printf "%s\n" "$ok_wf" > "$T/ok.yml"; "$lint" "$T/ok.yml" >/dev/null && ok || { echo "test_lint_workflows: a valid workflow was rejected" >&2; exit 1; }
neg with-under-run "$head
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: true
        with:
          fetch-depth: 0"
neg inserted-step "$head
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - name: free disk
        run: true
        with:
          fetch-depth: 0"
neg both "$head
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - uses: x/y@v1
        run: true"
neg neither "$head
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - name: nothing"
neg no-jobs "$head
jobs: {}"
neg no-jobs-key "$head"
neg no-steps "$head
jobs:
  a:
    runs-on: ubuntu-latest"
neg no-trigger "name: x
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: true"
neg broken-yaml "$head
jobs:
  a: [unclosed"
neg self-hosted "$head
jobs:
  a:
    runs-on: [self-hosted, linux]
    steps:
      - run: true"
printf 'private\n' > "$T/vis-private"; printf '%s\n' "$head
jobs:
  a:
    runs-on: [self-hosted]
    steps:
      - run: true" > "$T/sh.yml"
LINT_VISIBILITY_FILE=$T/vis-private "$lint" "$T/sh.yml" >/dev/null && ok || { echo "FAIL: self-hosted refused while visibility says private" >&2; exit 1; }
printf 'public\n' > "$T/visibility"; must_fail "self-hosted while visibility says public" "$lint" "$T/sh.yml"; rm "$T/visibility"
neg self-hosted-expression "$head
jobs:
  a:
    runs-on: \${{ inputs.x && 'ubuntu-latest' || fromJSON('[\"self-hosted\"]') }}
    steps:
      - run: true"
neg pull-request-target "name: x
on: pull_request_target
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: true"
neg secret-use "$head
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - run: echo \${{ secrets.DEPLOY_KEY }}"
finish lint_workflows
