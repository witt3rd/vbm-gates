# vbm-gates

**The shared gate set of the VBM repositories.** A VBM ("verified bare metal") repository decides what may land by machines, not by a reviewer's mood: a fast set of checks (its "gates") that every change must pass. Each repository used to carry its own hand copy of those gates, and the copies drifted apart. `vbm-gates` is the one copy, and every repository takes it by a **pinned, signed release**.

> **Status: pre-release.** The set is being built in small slices and nothing is tagged yet. Do not vendor it before the first signed tag `v0.1.0`.

## What is in it

Plain shell, python and Lean 4, nothing language-specific except the axiom gate:

* **ran-evidence** and the **parallel test runner**: a test or a gate that ran zero cases fails. A refused tool, a skipped check or an early exit is never a pass.
* **lints**: a producer piped into an early-exiting consumer (a flaky pattern under `pipefail`), workflow files that are valid and public-safe (hosted runners only), a hermetic `git` for scratch repositories, a zero-warning build check.
* **the protected set**: a list of paths that wait for the owner. Exact paths, directories and patterns; an empty or unreadable list refuses everything.
* **the gate-diff judge**: decides whether an edit to a gate is allowed. A baseline may only improve, a list may only grow, the Tier 1 script may only gain plain steps, and a removed or changed line needs an exact-diff approval. Its tables are in `scripts/gates.conf`, and **an unknown key fails**, so a typo cannot switch a gate off. The judge recomputes the approval's hash itself.
* **the relabel-attack runner** and the **shared attack bodies**: every known way to satisfy a gate by relabelling it is a small attack, applied to the proposed tree, which the proposed gates must still refuse. With a gate stubbed out so it cannot fail, the suite must itself fail.
* **the lander hooks**: the files a repository's `scripts/land.d/` runs, so the judge and the attack suite run at the right moment of a landing.
* **AxiomGate** (Lean): every constant of a library depends only on the standard axioms, with the module roots taken from configuration.

## How a repository uses it

A repository vendors a pinned copy into `scripts/gates/` with the landing tool [vbm-land](https://github.com/witt3rd/vbm-land) (`land-update --pkg gates`): the files are hashed against a manifest, the manifest against a **signed release tag**, and the tag against the signers file the repository itself holds. A drift check in the repository's own Tier 1 fails on any difference from the pin. The repository **overrides nothing**: its only lever is `scripts/gates.conf` with the keys listed in `KEYS`. A missing feature is a new release here.

## How it is checked

The tests are hermetic: every test builds its own scratch repository, lists, baselines and approvals, and never reads the repository's real ones; a lint fails a test that does. Anything that must read a consumer's real state is a separate, named check that runs in the consumer. CI runs on GitHub-hosted runners only, with a read-only token.

## Honest limits

* **A bug here reaches every repository at once.** The defence is the signed tag, each consumer's own Tier 1 and attack suite, and a rule that this repository's own gate sources are judged by its own judge.
* The gates stop mistakes, not adversaries with write access.
* Linux only for now. Lean builds are needed only for the axiom gate.

## Contributing, security, licence

[CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · Apache-2.0, see [LICENSE](LICENSE).
