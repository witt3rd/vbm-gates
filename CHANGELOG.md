# Changelog

Each release has a section; an interface change (a `gates.conf` key, an exit code, a hook name, an attack variable) is listed, additive ones as minor releases, anything else as a major one.

## 0.1.0 (candidate)

First release. The language-neutral gate set, vendored by a pinned signed tag:

- **core/**: `ran-evidence.sh`, `lib-ran.sh`, `run-tests-parallel.sh`; `lint-pipefail.sh`, `lint-workflows.py`, `lint-git-hermetic.sh`, `git-hermetic.sh`; `protected-set.sh` (exact paths, directories, patterns, `--superset`);
  `gate-diff-improving.sh` (the judge, tables from `scripts/gates.conf`, approvals recomputed by the judge); `relabel-attacks.sh` (the shared and the repository's own attacks as one suite); `gates-conf.sh` (the reader).
- **hooks/**: `land.d-stub` (installed as `scripts/land.d/post-rebase`, `post-tier1`, `prepare`), `post-rebase`, `post-tier1`, `prepare`: they run main's copy of the judge, never the proposal's.
- **lean/**: `AxiomGate.lean` (module roots from `GATES_AXIOM_ROOTS`), `axiom-gate.sh`, `lean-scan.sh`, `check-zero-warning.sh`.
- **attacks/**: 37 shared attack bodies and `lib.sh`; variables `G`, `TIER1`, `PLIST` and the `ATK_NAME=value` pairs of `GATES_ATTACK_VARS`.
- **KEYS** (the keys of `scripts/gates.conf`; an unknown key fails): `GATES_TIER1`, `GATES_STRICT`, `GATES_LISTS`, `GATES_SOURCE`, `GATES_SOURCE_DIRS`, `GATES_APPROVABLE`, `GATES_RULES_FILE`, `GATES_PROTECTED_LIST`,
  `GATES_WARM_DIRS`, `GATES_ATTACK_VARS`, `GATES_SCAN_DIRS`, `GATES_SPEC_ROOTS`, `GATES_AXIOM_ROOTS`.
- Exit codes: the judge and the hooks use 0 (pass), 1 (a gate fails: for the judge, a FAIL verdict), 2 (cannot decide: a bad conf, an unknown revision, a hung git), 12 (a hook refuses the landing).
