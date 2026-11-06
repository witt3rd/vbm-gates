#!/usr/bin/env bash
# Tier 1 of this repository: the drift check of the pinned lander, then every tests/test_*.sh through the parallel runner (each in its own TMPDIR and scratch world). Run from anywhere.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); cd "$here/.."
scripts/land/bin/land-check
core/run-tests-parallel.sh tests/test_*.sh
