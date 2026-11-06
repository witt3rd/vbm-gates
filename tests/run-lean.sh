#!/usr/bin/env bash
# The Lean leg of Tier 1: the tests that need a Lean toolchain (tests/lean/test_*.sh), through the parallel runner. Run under the toolchain (mise exec -- tests/run-lean.sh, or on hosted CI's second job).
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
core/run-tests-parallel.sh tests/lean/test_*.sh
