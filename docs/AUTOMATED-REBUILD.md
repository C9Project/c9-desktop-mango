# Automated package and ISO rebuild

`scripts/c9-rebuild.sh` runs the existing C9 build on the Poudriere server:
source snapshot, input checks, configure, dependency plan, incremental package
build and verification, offline ISO assembly, and static ISO verification.
It stops at the first failed step and retains the inputs and logs.

## Start a complete rebuild

Connect and run these commands in the server shell:

```sh
ssh daniel@192.168.178.55
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas sh scripts/c9-rebuild.sh check
doas sh scripts/c9-rebuild.sh start
```

Save the printed run ID. `start` detaches from SSH; the server must stay on.
Its successful return means the job was launched, not that the build passed.
Use `run` instead of `start` to wait in a connected foreground session.
Both modes save their output to the run's console log. An optional
`--run-id c9rebuild-YYYYMMDDTHHMMSSZ` supplies your own **unused** ID.

`check` is read-only. It checks source inventory/shell syntax, idle jails,
and the prepared image inputs. The configure/plan stages also enforce the
pinned package-jail version, ports commit and approved resource policy.
The script does not update FreeBSD, ports or resource limits.

## Follow the run

After reconnecting, substitute the ID printed at startup:

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0
sh scripts/c9-rebuild.sh status RUN_ID
doas tail -n 40 /usr/local/c9/runs/RUN_ID/console.log
doas tail -n 60 /usr/local/c9/runs/RUN_ID/logs/packages.log
doas poudriere status
```

The [Poudriere dashboard](http://192.168.178.55/jail.html?mastername=c9151amd64-default-c9#top)
shows individual ports. The runner's `phase` identifies the current or failed
stage. Stage logs and their exit codes are in `logs/`. Require both
**state=complete and exit-status=0** before using the new ISO. A missing final
exit-status means the run is unfinished or was interrupted; a saved running
state alone does not prove a process survived a reboot or power loss.

Default output layout:

| Path | Contents |
| --- | --- |
| `/usr/local/c9/runs/RUN_ID/` | Status, progress, per-stage logs, source snapshot and build identities |
| `/usr/local/c9/releases/RUN_ID/C9MANGO020.iso` | New offline ISO |
| `/usr/local/c9/releases/RUN_ID/SHA256` and `SHA512` | ISO checksums |
| `/usr/local/c9/tests/iso-RUN_ID/` | Static verification evidence and cleanup result |

The actual release/evidence directories are also printed by `status`.
Copy a completed ISO to F: using `scp`, then compare its complete SHA-256
with the server's checksum before writing it with Rufus in DD mode.
Static verification does not replace installation or desktop acceptance tests.

## What is reused

- The existing `c9151amd64` jail, pinned `default` ports tree, distfiles,
  compiler cache and signing key.
- Compatible packages in `c9151amd64-default-c9`. The existing helper runs
  `poudriere bulk -t -r`; no clean-all flag is added. Missing, changed or
  invalidated ports and their necessary dependencies are built and tested.
- The prepared `c9image151amd64` image jail and its exact p6 base/kernel
  archives. Their hashes and versions are checked before package work and
  again before ISO assembly. The ISO still needs copying, assembly and hashing.

A normal run always uses a new package build ID, even if Poudriere finds
every package reusable. A new ID is not a request to recompile everything.
The historical kernel-origin ID remains separate from the new package ID.
Neither the old preparation record nor the old ISO is relabeled or overwritten.

The approved two builders, two compilation jobs, disk-backed work directories,
and existing Electron/VS Code exceptions remain in effect.

## Retry an ISO failure, or rebuild only the installer

If packages have already passed and that exact build is still the published
repository, skip package work explicitly:

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas sh scripts/c9-rebuild.sh start --reuse-build c9release-20261122T094945Z
```

That ID is the currently recorded successful release, not a permanent default.
After a newer build, replace it with the package-build-id from the successful
package run. Reuse mode still verifies the signed repository, package hashes
and install plan, then builds and verifies a **new** ISO. It refuses an old ID
when the repository has since changed. Use this mode only when packaged source,
versions, dependency selection and package options are unchanged.

For a failed package build, fix the reported cause and start a normal run
with a new ID. Completed compatible packages are reused. There is no automatic
retry loop, deletion of evidence, or resumption based solely on old stage markers.
After an interrupted server session, check `poudriere status` and the logs before
retrying; active C9 jails prevent the runner from changing inputs.

**Publication happens during Poudriere's package stage.** The server currently
permits repository publication even when some ports fail
(`COMMIT_PACKAGES_ON_FAILURE=yes`). The runner's checks do not make publication
transactional and do not roll it back if package verification or ISO creation
fails. Run client package upgrades only after explicit C9 verification succeeds.

## Adjust the build

Use [Customize and rebuild](CUSTOMIZE-AND-REBUILD.md) to edit and deploy the
project. Packaged content needs a new package identity: otherwise a successful
cache reuse can retain the old content. The current gate requires all C9 package
versions to equal `C9_VERSION`, so follow that guide's coordinated version change.
Review the release-specific package, version, ISO-label and dependency-count
expectations in `tests/verify-iso.sh` when changing the release or selection.
The runner does not rewrite those expectations automatically.

Edit `poudriere/rebuild.conf` for the default kernel record, saved distributions
and output roots. All directories must already exist, be owned by root, have no
group/world write permission, and use canonical absolute paths without symlinks
or spaces. Output roots must be separate. Optional per-run overrides are:

```sh
doas sh scripts/c9-rebuild.sh start \
    --kernel-record /usr/local/c9/image-inputs/RECORD \
    --payload /usr/local/c9/releases/RELEASE/inputs/distributions
```

The default paths point to the verified p6 inputs already on this server.
Keep those directories, the image jail and their proof files. Changing the
FreeBSD baseline requires deliberate jail/kernel/payload preparation first;
this runner does not create or update jails against a moving release target.
See the platform-change section of the customization guide.

## Source snapshots and concurrent work

At startup, the runner copies the project's explicit source inventory into
`runs/RUN_ID/source`, including hidden desktop templates, and generates a
manifest from those actual bytes. It detects changes during copying and checks
the snapshot again before every stage. Keep this retained snapshot unchanged.
You may edit the original checkout after the snapshot is complete for a later run.

A normal run registers `c9overlay` against its retained snapshot's `ports/`.
It leaves that registration in place so the inputs remain inspectable. The next
normal automated run switches it to its own snapshot. For a later manual build,
run `scripts/c9-build.sh configure` from your intended checkout first, while idle.
Do not remove a snapshot still used by the overlay or needed as build evidence.

One persistent lock serializes complete automated C9 pipelines. Its file remains
on disk after completion; existence does not mean it is locked. A concurrent
runner exits nonzero without running build stages. The lock does not coordinate
manual Poudriere commands: do not launch manual builds, update jails/ports, change
resource policy or switch the overlay while this pipeline is active.

## Test the orchestrator without building packages

The regression harness uses isolated root-owned fixtures, fake sibling build
helpers, and the real FreeBSD shell, daemon and locking primitives. It never
launches a production package or ISO build:

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas sh tests/test-rebuild.sh \
    /usr/local/c9/c9-desktop-mango-0.2.0/scripts/c9-rebuild.sh \
    /usr/local/c9/tests/rebuild-regression-UNIQUE
```

Keep the new evidence directory. The real-input `check` command supplements
these orchestration tests; a complete production rebuild has its own final
status and static ISO evidence.
