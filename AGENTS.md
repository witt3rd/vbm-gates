# AGENTS.md: vbm-gates

The language-neutral **gate set** that every VBM (verified bare metal) repository vendors by a pinned, signed tag: ran-evidence, the parallel test runner, lints, the protected set, the relabel-attack runner with the shared attack bodies, the lander hooks, the gate-diff judge (its tables live in `gates.conf`; an unknown key fails) and the axiom gate (module roots from configuration). **Public from day one**: no private name, host or path anywhere (`tests/lint.sh` fails Tier 1). `README.md` is the public face (plain words, for outside readers); this file is the agent file.

## Status
Release candidate 0.1.0 (`VERSION`); `git log` says what has landed. Nothing here is a release until a signed tag `vX.Y.Z` exists (`bin/gates-release`), and a tag is made only on the owner's word. `MANIFEST.sha256` is generated (the lander regenerates it on every landing): never edit it by hand.

## Hard rules
- **A bug here is a bug everywhere.** Every consumer vendors these files, so a mistake reaches every repository at once. The defence is the signed tag plus each consumer's own Tier 1 and attack suite. Take the union of the best parts of the copies this set replaces, never the lowest common denominator, and give each merged feature an attack.
- **Tests are hermetic by construction.** Every test builds its own scratch world: its own repository, approvals, lists, baselines, config and `TMPDIR` (`tests/lib.sh`). A test never reads this repository's real approvals, protected list, baselines, config or tags (`tests/lint.sh` fails one that names them, and `tests/test_harness.sh` shows each lint able to fail). An engine test uses synthetic lists and baselines. A check that must read a consumer's real state is a separate, honestly named check (`bin/gates-check-config`) that runs in the consumer.
- **Ran-evidence.** A test or gate that runs zero cases fails: every test script ends with `ran: NAME: N cases` (N > 0). A refused tool, a `SKIPPED` line or an early exit is never a pass. Every gate has a negative self-test that must be shown able to fail.
- **Nothing runs after the push.** Everything runs before it, once, on the tree rebased onto main (Tier 1). If main is ever red, whoever sees it reverts the offending commit with `git revert` and the author fixes forward in a new worktree. The repository is public: no runner is registered for it, and no secret is in it.
- **Public-ready, always.** No private name, host, path, number or e-mail address anywhere; write generic.
- **No local patches downstream.** A consumer overrides nothing: variation is `scripts/gates.conf` with known keys only. A missing feature is a new release here.
- **One approval rule: the judge recomputes the hash.** A removed or changed line of an append-only gate file is accepted only on an exact-diff approval already on main, and the judge recomputes that diff's hash itself instead of trusting the lander.
- **Small diffs:** at most 150 production lines (`core/ hooks/ lean/ attacks/ bin/ tests/`) per landing; a `Diff-Budget:` trailer waives it with a decomposition note. At most 45 minutes without a passing build: abort and decompose. Conventional Commits.
- **Gate-defining files need the owner's say-so.** The lander, its configuration and the hooks are in the protected set (`scripts/protected-paths.txt`), and every gate source is judged by the diff judge and the attack suite (`scripts/gates.conf`). Do not land a gate-defining change on any word but an explicit land decision.
- **No secrets in the repository.** No network call from a test or a gate.

## Landing (direct to main, no PRs)
- Work in a worktree off a fresh origin/main. Diff ≤150 production lines, ≤45 min without a passing build; over either, stop and write a decomposition plan.
- Commit locally with Conventional Commits. Land only with `scripts/land-direct`; never push main yourself, never force-push it, never open a PR.
- New behaviour lands behind a flag that defaults OFF. Interface changes: add beside the old, migrate callers, delete at zero references.
- Everything runs before the push, once (Tier 1 on the rebased tree); nothing runs after it. If main is ever red, whoever sees it reverts the offending commit with `git revert` and lands the revert; the author fixes forward in a new worktree. A landing must not add a failure.
- `scripts/land/` and `scripts/land-direct` are a pinned copy of vbm-land: never edit them (`scripts/land/bin/land-check` fails the gate). Change the tool upstream, then `scripts/land/bin/land-update <tag>`.
- Decide anything reversible and log it. Escalate only money, data loss, secrets, publishing, or harm to a third party; say so in one line and stop.

## Principles (the VBM + HVTBD family)
- Everything runs before the push, once, on the commit rebased onto main. Nothing runs after the push.
- Proofs, not tests. A test exists only for what the proofs do not cover (the boundary), never for the development tooling.
- A failure is a root-cause question, never a reason to add a check, gate, script or document. Nothing is added to the process without deleting something.
- The worker owns its change: when the lander refuses it, the worker fixes it and lands again until it converges.

## Layout
`core/` language-neutral gates · `hooks/` what a consumer's `scripts/land.d/` stubs run · `lean/` the Lean gates · `attacks/` the shared attack bodies · `bin/` manifest, release and consumer checks · `tests/` hermetic tests and `tests/lint.sh` · `scripts/` this repository's own configuration, hooks and the pinned lander (`gates.conf` is its own gate tables). `docs/signing.md` the release key.
