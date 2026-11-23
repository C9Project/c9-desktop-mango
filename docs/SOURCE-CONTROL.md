# C9 source control

Project account: https://github.com/C9Project

Configured remote: https://github.com/C9Project/c9-desktop-mango

The intended repository visibility is private. Creating and pushing the remote
requires authentication as C9Project; configuring a local remote alone does not
create the GitHub repository.

Maintainer and project Git identity: `C9Project <c9_project@proton.me>`.
Git identity is configured for this checkout, without changing the user's
global name or email. GitHub authentication is separate from commit identity.

The local checkout is
`F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z`.
Git needs an exact `safe.directory` entry for this folder because F: does not
record filesystem ownership. Do not replace that entry with a wildcard.

## Recorded baseline

The `baseline-20261122` tag identifies the verified source imported before
the contact change. Its source manifest is
`5f86459dc50404a53937cc30b09216719da2f801dd881f737349220e38b6f06d`,
matching the retained automation source archive and server deployment.
It records the old source honestly; it is not a newly built package release.

`.gitattributes` preserves exact source bytes across platforms so checkout
does not invalidate `MANIFEST.sha256` or introduce Windows line endings into
FreeBSD shell scripts. Save edited shell scripts with LF line endings.
The archive helper includes the explicit build-source inventory; Git's own
metadata and root `.gitignore`/`.gitattributes` are not build payloads.

## Change workflow

1. Start a branch from `main` for a change, such as `change/desktop-defaults`.
2. Make the change and review `git diff`. For packaged contents, follow the
   coordinated C9 version procedure in [Customize and rebuild](CUSTOMIZE-AND-REBUILD.md).
3. Run the relevant checks. Regenerate the source manifest and a **new** source
   archive with `scripts/prepare-source.ps1`; keep the archive outside Git.
4. Commit the source and manifest, push the branch, and review its pull request.
   Merge the reviewed change into `main`.
5. Deploy the chosen revision to the server using the documented source archive
   workflow, then run [Automated rebuild](AUTOMATED-REBUILD.md).
6. After the real build and verification pass, record the exact source commit,
   build ID, kernel-origin ID and ISO checksum in the release notes. A source
   commit or GitHub push alone does not start or validate a Poudriere build.

Keep private keys, passwords, ISOs, binary packages, VM disks, caches, logs and
backups outside source Git. `.gitignore` excludes common generated files and
credential filenames; still review staged files before committing.

The maintainer-only change on 23 November leaves `DISTVERSION=0.2.0` unchanged.
Existing signed packages and ISOs keep their original metadata, and incremental
builds may reuse those packages. A later release can incorporate the new contact
in package metadata using the normal coordinated version procedure.
