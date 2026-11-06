# Signing vbm-gates releases

A release is an annotated tag `vX.Y.Z` signed with an ssh key (no gpg), whose message records `manifest_sha256=<hash of MANIFEST.sha256>`. `bin/gates-release` makes it, and verifies it against `scripts/gates.signers` before it leaves the machine.
`MANIFEST.sha256` lists every file a repository vendors into `scripts/gates/`; the signature therefore covers all of them.

## The release key

- Principal: `vbm-gates-release`; algorithm ed25519.
- **Fingerprint: `SHA256:+jAjhPWRPGVCFEtRLfKv11xxppyqCUzDhjtnh5/9xKk`** (the same maintainer key that signs vbm-land releases, listed under its own principal in each package's signers file; a consumer decides whether to trust each).
- The public key is `scripts/gates.signers`. Check the fingerprint out of band before you trust the file: `ssh-keygen -lf <(cut -d' ' -f3- scripts/gates.signers | tail -n 1)`.
- The private half lives only on the maintainer's machine; it is not registered anywhere (not on GitHub): verification is local, against the signers file.

## Trusting it in a consumer

First install, with the vendoring tool [vbm-land](https://github.com/witt3rd/vbm-land):
`scripts/land/bin/land-update --pkg gates --source witt3rd/vbm-gates --signers scripts/gates.signers vX.Y.Z` (the file taken from a source you trust, fingerprint checked as above). It becomes the consumer's own `scripts/gates.signers`;
from then on every update must verify against it. A package with no signers file is refused, never "unverified".

## Verifying a tag by hand (from a fresh clone)

```
git clone https://github.com/witt3rd/vbm-gates fresh && cd fresh
git -c gpg.format=ssh -c gpg.ssh.allowedSignersFile=scripts/gates.signers verify-tag vX.Y.Z
```

## Rotation

A rotation is a **new line** in `scripts/gates.signers`; the old line stays so old tags still verify. Releases after the rotation are signed with the new key. Consumers review the change to their own file.
