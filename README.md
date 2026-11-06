# vbm-gates

**The shared gate set of the VBM repositories.** A VBM ("verified bare metal") repository decides what may land by machines, not by a reviewer's mood: a fast set of checks (its "gates") that every change must pass. Each repository used to carry its own hand copy of those gates, and the copies drifted apart. `vbm-gates` is the one copy, and every repository takes it by a **pinned, signed release**.

> **Status: release candidate 0.1.0.** The set is complete and its own tests, attacks and acceptance run are green; the first signed tag `v0.1.0` is made by the maintainer, and a repository should vendor only a signed tag.

## What is in it

Plain shell, python and Lean 4; nothing language-specific except the Lean gates:

* **ran-evidence** and the **parallel test runner** (`core/`): a test or a gate that ran zero cases fails. A refused tool, a skipped check or an early exit is never a pass.
* **lints** (`core/`): a producer piped into an early-exiting consumer (a flaky pattern under `pipefail`), workflow files that are valid and public-safe (hosted runners only, no secret), a scratch `git` repository that is not hermetic, and a hermetic `git` helper for tests.
* **the protected set** (`core/protected-set.sh`): a list of paths that wait for the owner. Exact paths, directories and patterns; an empty or unreadable list refuses everything; the list as of the base judges a change, so a change cannot loosen the list it is judged by.
* **the gate-diff judge** (`core/gate-diff-improving.sh`): decides whether an edit to a gate is allowed. A baseline may only improve, a list may only grow, the Tier 1 script may only gain plain steps (a masked step such as `|| true`, `!`, `&` or `trap` fails), and a removed or changed line needs an exact-diff approval, whose hash **the judge recomputes itself**. An approval never excuses a masked line added in the same edit. Its tables are in `scripts/gates.conf`, and **an unknown key fails**, so a typo cannot switch a gate off.
* **the relabel-attack runner and the shared attacks** (`core/relabel-attacks.sh`, `attacks/`): every known way to satisfy a gate by relabelling it is a small attack, applied to the proposed tree, which the proposed gates must still refuse. With a gate stubbed out so it cannot fail, the suite must itself fail. A repository adds attacks of its own wiring beside the shared ones.
* **the lander hooks** (`hooks/`): the files a repository's `scripts/land.d/` runs, so the judge and the attack suite run at the right moment of a landing, from the **main** branch's copy: a proposed change cannot weaken the check that judges it.
* **the Lean gates** (`lean/`): the axiom gate (every constant depends only on the three standard axioms; one shared walk checked against Lean's own, module roots from configuration), the forbidden-construct and Init-only-import scans, and the zero-warning check.
* **commands** (`bin/`): `tier1-core` (the generic head of a Tier 1), `gates-selftest` (the package's own tests, run where it is vendored), `gates-check-config` (the checks that read a repository's real configuration, kept apart from the hermetic tests).

## How a repository uses it

A repository vendors a pinned copy into `scripts/gates/` with the landing tool [vbm-land](https://github.com/witt3rd/vbm-land) 0.5 or later: `scripts/land/bin/land-update --pkg gates --source witt3rd/vbm-gates --signers FILE vX.Y.Z`. The files are hashed against a manifest, the manifest against a **signed release tag**, and the tag against the signers file the repository itself holds ([docs/signing.md](docs/signing.md) has the key and its fingerprint). This is the one update flow for every pinned package: the landing tool itself, this gate set and, when it exists, the shared runtime (vbm-rt) are each pinned on their own by signed tag; there is no bundle and no combined installer. A drift check in the repository's own Tier 1 fails on any difference from the pin. The repository **overrides nothing**: its only lever is `scripts/gates.conf` with the keys listed in `KEYS`. A missing feature is a new release here.

## How it is checked

The tests are hermetic: every test builds its own scratch repository, lists, baselines and approvals, and never reads the repository's real ones; a lint fails a test that does. Anything that must read a consumer's real state is a separate, named check (`bin/gates-check-config`) that runs in the consumer. The tests also run in the vendored layout (`tests/test_vendored_layout.sh` builds a consumer and runs the payload in it), and `tests/acceptance.sh` runs one real approval end to end on the real tree before a release. CI runs on GitHub-hosted runners only, with a read-only token.

## Honest limits

* **A bug here reaches every repository at once.** The defence is the signed tag, each consumer's own Tier 1 and attack suite, and a rule that this repository's own gate sources are judged by its own judge.
* The gates stop mistakes, not adversaries with write access.
* Linux only for now. A Lean toolchain is needed only for the axiom gate and the attacks that use it: a second CI job runs them, and a box without one fails the Lean leg rather than skipping it silently.

## Contributing, security, licence

[CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · Apache-2.0, see [LICENSE](LICENSE).
