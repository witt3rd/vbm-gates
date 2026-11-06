# Security policy

## Reporting a vulnerability

Please report a vulnerability **privately**: on the repository page open **Security**, then **Report a vulnerability** (GitHub private vulnerability reporting). Do not open a public issue or pull request for it.

Include what you found, the release (`VERSION`, or the tag) and a way to reproduce it. You will get an acknowledgement within a few days; a fix is released as a patch release with a signed tag and a CHANGELOG entry that says what was fixed.

## Supported versions

The latest release only. The project is 0.x: older releases get no backports.

## What counts

This repository is a set of gates that other repositories trust to decide what may land, so the sensitive bugs are the ones that make a gate accept what it should refuse. In scope: a change that passes the diff judge, the protected-set check, the ran-evidence check or the attack runner when it should not; an approval that is accepted for a different diff, twice, or after it expired; a way to make a consumer accept an unsigned, wrongly signed or tampered release; a gate that can be made to run nothing and still pass; a leak of a secret through a log.

Out of scope: an attacker who already has write access to a repository that vendors these gates and wants to cheat (the gates stop mistakes, not adversaries), and the contents of a consumer's own configuration and lists.

## Release signatures

Releases are ssh-signed annotated tags. A consumer lists the signer's public key in its own `scripts/gates.signers`, taken from this repository out of band, and refuses any release that does not verify against it.
