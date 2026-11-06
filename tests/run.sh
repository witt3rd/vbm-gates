#!/usr/bin/env bash
# Tier 1 of this repository: the lints, the vendored lander's drift check, then every tests/test_*.sh through the parallel runner (each in its own TMPDIR and scratch world;
# a script that exits 0 without ran-evidence fails). Run from anywhere.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); cd "$here/.."
tests/lint.sh; scripts/land/bin/land-check
core/run-tests-parallel.sh tests/test_*.sh
