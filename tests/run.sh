#!/usr/bin/env bash
# Tier 1 of this repository: the lints, the vendored lander's drift check, the shared lints on the real tree, then every tests/test_*.sh through the parallel runner (each in its own TMPDIR and scratch world;
# a script that exits 0 without ran-evidence fails). Run from anywhere.
set -euo pipefail
export LC_ALL=C
here=$(cd "$(dirname "$0")" && pwd); cd "$here/.."
tests/lint.sh; scripts/land/bin/land-check
core/lint-pipefail.sh; core/lint-workflows.py; core/lint-git-hermetic.sh   # the gates run on THIS repository's real tree here (their own tests use scratch worlds)
core/relabel-attacks.sh --tree "$PWD" | tail -n 3   # every shared attack must be refused by this tree's own gates
bin/gates-check-config   # the checks that read THIS repository's real conf, lists, stubs and pin (the package's tests use scratch worlds)
bin/gates-manifest --check   # the manifest of what a consumer vendors is current (the lander regenerates it on every landing)
core/run-tests-parallel.sh tests/test_*.sh
