# Contributing

Thank you for looking. A short, honest note about how this repository works.

## Who lands changes

**Only the owner lands changes on `main`.** The repository lands directly, with its own lander (`scripts/land-direct`, the vendored vbm-land): no pull request is ever merged in the GitHub sense. That is the tool's model, not a lack of interest in your work.

**Outside contributions are welcome**: open an issue, or a pull request from a fork. The owner reads it, and if the change is accepted it lands through the lander as a commit (your authorship is kept where the change is applied as is). A pull request is therefore a proposal, and may be closed with the change landed separately.

## Pull requests and CI

- CI runs only on a push to `main` and on manual dispatch, on GitHub-hosted runners with a read-only token. It does not run on pull requests, and it must never run on a self-hosted runner for a pull request from a fork. `tests/lint.sh` refuses a workflow that names `self-hosted`.
- Run the checks yourself: `tests/run.sh` (the lints, then every `tests/test_*.sh`). Needs bash 4+, git 2.30+, `timeout`, `jq`, `python3`.

## What a good change looks like

- Small: at most about 150 changed lines of gate code, one idea per commit. Conventional Commits subjects (`feat(core): ...`, `fix(judge): ...`, `docs: ...`, `test: ...`).
- A test for the behaviour, and for a gate a negative test: the gate must be shown able to fail. Tests are hermetic: each builds its own scratch repository, lists and approvals and never reads this repository's real ones.
- Everything that defines a gate is judged by the owner and mechanically before it lands, so expect more discussion there.
- An interface change (a `gates.conf` key, an exit code, a hook name) needs a CHANGELOG line, and is a minor release if additive and a major one otherwise.
- No private names, hosts or local paths anywhere (`tests/lint.sh` refuses them).
- Releases are made only by the maintainer, signed with the release key. Do not edit `MANIFEST.sha256` by hand.

## Licence

By submitting a contribution you agree that it is licensed under the Apache License 2.0, as the rest of the project (section 5 of the licence).

## Security

Report vulnerabilities privately: [SECURITY.md](SECURITY.md).
