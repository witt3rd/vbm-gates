#!/usr/bin/env bash
# Tier 1 of this repository: the lints, the vendored lander's drift check, the shared lints on the real tree, then every tests/test_*.sh through the parallel runner (each in its own TMPDIR and scratch world;
# a script that exits 0 without ran-evidence fails). Run from anywhere.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); cd "$here/.."
tests/lint.sh; scripts/land/bin/land-check
core/lint-pipefail.sh; core/lint-workflows.py   # the gates run on THIS repository's real tree here (their own tests use scratch worlds)
core/run-tests-parallel.sh tests/test_*.sh
