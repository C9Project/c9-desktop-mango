# Reproduce the C9 build

For changing applications, desktop defaults, profiles or the installer, start
with [Customize and rebuild](CUSTOMIZE-AND-REBUILD.md). This document retains
the detailed input-restoration and original build records.
The [automated runner](AUTOMATED-REBUILD.md) repeats the existing server's
package-to-ISO pipeline while reusing compatible packages and verified image inputs.

**Current corrected ISO:** server build/static checks and the full F: checksum
passed for `c9-0.2.0-zfs-20261122T153649Z`. The verified ISO is at
`F:\C9\releases\c9-0.2.0-zfs-20261122T153649Z\C9MANGO020.iso`;
its SHA-256 is `19ff43a1a64f90edc3297aca45f76b40f107c762554a373eee0ee9d8fbeae0fe`.
The installer-only fix passed actual FreeBSD ZFS/UFS regressions; a fresh
replacement-ISO EFI/ZFS installation test has not run. See
[quick start](QUICKSTART.md) for the new artifact and [ZFS recovery](ZFS-INSTALL-RECOVERY.md)
for resuming a paused original-ISO installation. The original BIOS/EFI
installation results below used UFS.

This procedure uses the existing server at `192.168.178.55`, the `daniel`
SSH account, and passwordless `doas`. Complete the package stage before
building an ISO or attempting a VirtualBox installation.

## Original ISO and an ISO-only repeat

The package gate passed in `c9release-20261122T094945Z`. ISO run
`c9iso-20261122T104752Z` completed with exit 0 at approximately 11:10 UTC on
22 November 2026. Static verification passed at 11:15:09 UTC. The complete
local ISO copy was verified at 12:04:15 UTC. The initial BIOS installation
passed offline with the VirtualBox profile and Essential applications only:
445 packages were installed, and the installed system reached SDDM.
BIOS SDDM authentication/logout/reboot tests passed. EFI installation also
passed offline with Development and Office selected (542 packages), followed
by password rejection, nonroot login, logout and an actual software reboot.
Native Intel/Mango and package-upgrade validation remain outstanding.

| Artifact | Recorded value |
| --- | --- |
| Server ISO | `/usr/local/c9/releases/c9-0.2.0-20261122T104752Z/C9MANGO020.iso` |
| Size | 6,238,750,720 bytes |
| SHA-256 | `ead71c8b7e0c44032861305619e734690fea9600d6996ef5a69a3e345c8c3a2b` |
| Static verification evidence | `/usr/local/c9/tests/iso-20261122T104752Z-v3` |
| Completed image-jail preparation | `/usr/local/c9/image-inputs/c9-0.2.0-p6-20261122T094945Z` |

The complete verified local ISO is
`C:\Users\DPeyer\AppData\Local\C9VMTests\20261122T100429Z\release-20261122T104752Z\C9MANGO020.iso`.
Its 6,238,750,720-byte size and full SHA-256 match the server artifact above;
`copy-verification.json` beside it records verification at
`2026-11-22T12:04:15.8700865Z`. The original USB/exFAT destination failed during
transfer and is excluded from further work. The resumed NTFS copy is complete;
validation no longer depends on a partial-file checksum. See the
[recovery record](VALIDATION.md#local-storage-failure-and-recovery).

The initial BIOS guest evidence is under
`C:\Users\DPeyer\AppData\Local\C9VMTests\20261122T100429Z\bios-essential-initial\extracted`.
Its collector completed with zero failed checks at 12:35:18 UTC. It records
445 installed packages, the `virtualbox` profile, Essential without Development
or Office, and kernel/running-kernel/userland all reporting `15.1-RELEASE-p6`.
That initial snapshot was followed by separately observed SDDM authentication,
logout and reboot tests on both firmware variants. The complete results and
evidence locations are in [VALIDATION.md](VALIDATION.md).

The recovered local checkout is
`F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z`.
Use that checkout for the Windows source-archive commands below. Replacement
VMs are under the same task directory's `ntfs-vms`; the earlier USB-backed VMs
have never started and remain untouched.

On the existing server, reuse `c9image151amd64`, the verified repository and
saved payloads. No package rebuild or image-jail preparation is needed while
the published repository still belongs to the same verified build:

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas sh scripts/build-iso.sh \
  --build-id c9release-20261122T094945Z \
  --output "/usr/local/c9/releases/c9-0.2.0-repeat-$(date -u +%Y%m%dT%H%M%SZ)" \
  --payload /usr/local/c9/releases/c9-0.2.0-20261122T104752Z/inputs/distributions
```

The builder rechecks the completed package run, current published identity,
signatures, archive hashes, installation plan and exact p6 payload. Choose a
new output directory for every attempt. A changed repository requires its
matching verified build ID. Keep the released ISO and checksum: repeated
builds preserve the inputs but do not promise identical image bytes.
For restoration on another server or a new package release, follow the full
workflow below and [INSTALLER.md](INSTALLER.md).

## Recorded inputs

| Input | Value |
| --- | --- |
| C9 source version | 0.2.0 |
| Server source directory | `/usr/local/c9/c9-desktop-mango-0.2.0` |
| FreeBSD / architecture | 15.1-RELEASE-p6 / amd64 |
| Package ABI / OSVERSION | FreeBSD:15:amd64 / 1501000 |
| Package jail | `c9151amd64` |
| Existing complete ports tree | `default` |
| Ports commit | `e7bc56a5d30dc24ce2e7990926836699cbd34e55` |
| Overlay / build set | `c9overlay` / `c9` |
| Repository | `/usr/local/poudriere/data/packages/c9151amd64-default-c9` |
| Build resources | 2 builders, 2 compile jobs each, disk-backed work directories |

The machine's existing ports tree, compiler cache, distfiles, and repository
signing key are reused. Do not update the shared ports tree in the middle of
a build. [`installer/release.conf`](../installer/release.conf) records the
approved release inputs. The helper refuses a different revision rather than
silently building a different release.

The original 0.1.0 checkout is retained. Changing the `c9overlay` registration
to the new checkout must wait until its active build has stopped. The
configuration helper enforces this and saves the previous configuration.

## Build all packages

When copying a changed source tree from Windows, first prepare an archive. This
includes the hidden `.config` templates and updates `MANIFEST.sha256`:

```powershell
Set-Location -LiteralPath 'F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z'
.\scripts\prepare-source.ps1 -Output "$env:TEMP\c9-source-0.2.0.tar.gz"
scp "$env:TEMP\c9-source-0.2.0.tar.gz" daniel@192.168.178.55:/home/daniel/
```

Use a new source destination for a new release; retain the previous checkout
until its build has finished. On the server, extract the source archive into
that new root-owned directory, verify the archive hash against the local
output, and check each file against `MANIFEST.sha256`. Never replace files
under an overlay used by an active build.

Windows-created archives can carry permissive Unix mode bits. After extracting
the new checkout, make its ownership and source permissions explicit. These
commands apply only to the new C9 source directory:

```sh
doas chown -R root:wheel /usr/local/c9/c9-desktop-mango-0.2.0
doas find /usr/local/c9/c9-desktop-mango-0.2.0 -type d -exec chmod 0755 {} +
doas find /usr/local/c9/c9-desktop-mango-0.2.0 -type f -exec chmod 0644 {} +
```

The commands below invoke scripts through `sh`, so source files do not need
executable mode. Port installation rules set the installed programs' modes.

Connect and enter the deployed source directory:

```sh
ssh daniel@192.168.178.55
cd /usr/local/c9/c9-desktop-mango-0.2.0
```

Before `configure`, install the approved package-specific address-space policy.
Run this only while the C9 package jail is idle. Preserve any existing file
before replacement and refuse a symlink or another unexpected file type:

```sh
if jls -n name | awk '$0 ~ /name=c9151amd64(-|$)/ {found=1} END {exit !found}'; then
  echo 'Wait for the C9 package jail to become idle.' >&2
  exit 1
fi
limits_config=/usr/local/etc/poudriere.d/c9151amd64-default-c9-poudriere.conf
if doas test -L "$limits_config"; then
  echo 'Review the existing configuration symlink before replacement.' >&2
  exit 1
fi
if doas test -e "$limits_config"; then
  doas test -f "$limits_config" || exit 1
  limits_backup=$(doas mktemp -d /usr/local/c9/backups/package-limits.XXXXXX) || exit 1
  doas cp -p "$limits_config" "$limits_backup/" || exit 1
fi
doas install -m 0644 poudriere/c9-package-limits.conf.example /usr/local/etc/poudriere.d/c9151amd64-default-c9-poudriere.conf
```

The policy keeps the default virtual-address limit at 8 GiB and permits
2,048 GiB for Electron and 16 GiB for VS Code. Electron's V8 sandbox reserves
1,376 GiB before other process mappings; this is address space, not physical
RAM allocation. VS Code also receives its port's documented open-file limit
of 8,192; other packages retain 2,048. Two builders and two compile jobs per
package remain unchanged. The Electron exception was approved on 16 November
2026, and the VS Code exceptions on 22 November. Details and validation limits
are in [PORTS-PATCHES.md](PORTS-PATCHES.md).

```sh
doas sh scripts/c9-build.sh configure
doas sh scripts/c9-build.sh plan
```

The plan must resolve every origin in `poudriere/c9-release.list`. This includes
the desktop and workstation meta-ports, Essential, Development, Office,
configuration, artwork, and both selected hardware profiles. Development and
Office are built and bundled even though they are optional during installation.

Start a new named build in a persistent server process. Substitute a fresh
build ID if repeating this example:

```sh
build_id=c9release-$(date -u +%Y%m%dT%H%M%SZ)
doas install -d -m 0755 /usr/local/c9/runs/$build_id
doas daemon -f \
  -p /usr/local/c9/runs/$build_id/runner.pid \
  -o /usr/local/c9/runs/$build_id/console.log \
  /bin/sh /usr/local/c9/c9-desktop-mango-0.2.0/scripts/c9-build.sh build "$build_id"
echo "$build_id"
```

The helper invokes `poudriere bulk -t -r`: every package built in that run is
checked for packaging, installation/deinstallation, dependencies, and leftovers.
Previously completed packages can be reused. This does not run every upstream
application's unit-test suite or prove graphical behavior.

Check progress and the saved runner log:

```sh
doas poudriere status
doas tail -n 30 /usr/local/c9/runs/YOUR_BUILD_ID/console.log
```

The [Poudriere dashboard](http://192.168.178.55/) also reports progress. Full
logs are under
`/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/YOUR_BUILD_ID/`.
Each attempt records its input files, times, and Poudriere exit status under
`/usr/local/c9/runs/YOUR_BUILD_ID/attempt-TIMESTAMP/`.

After completion:

```sh
doas sh scripts/c9-build.sh verify YOUR_BUILD_ID
```

Verification requires a completed run, zero failed/skipped/ignored ports, and
a published repository from that exact build. It checks the signed catalog,
C9 package versions, an installation plan using an empty package database,
and archive digests for every offered runtime dependency. It does not install
the desktop on the build host. The image stage repeats these checks and verifies
the copied repository before including it in the ISO.

If a port fails, read its error log and fix the cause before starting a fresh
build ID. Reusing an ID with recorded failures can retain failed/skipped-port
exclusions; the helper refuses that. A deliberately interrupted run with no
failed/skipped/ignored ports can use its previous ID to continue and reuse
completed packages.

To stop for shutdown, send `TERM` to the Poudriere process recorded in that
run's log/process tree, then wait for its cleanup and confirm no C9 jails remain
with `jls`. Do not kill compiler processes individually or shut down while
Poudriere is cleaning up. The daemon PID file identifies the wrapper, so inspect
its child process before choosing the signal target.

## Build and test the ISO after packages pass

For the first image, prepare the dedicated kernel-bearing jail. This verifies
the retained p6 source against saved, signed FreeBSD update metadata and builds
the standard GENERIC kernel with two jobs in isolated directories. It requires
the complete successful package build before doing that work:

```sh
doas install -d -m 0755 /usr/local/c9/image-inputs
doas sh scripts/prepare-image-jail.sh \
  --build-id YOUR_VERIFIED_BUILD_ID \
  --output /usr/local/c9/image-inputs/c9-0.2.0-p6

doas sh scripts/build-iso.sh \
  --build-id YOUR_VERIFIED_BUILD_ID \
  --output /usr/local/c9/releases/c9-0.2.0-YOUR_RELEASE_NAME
```

Preparation creates the separate `c9image151amd64` image jail from the
verified p6 base and source-built GENERIC kernel. It never updates the
package jail. A fresh HTTP jail now updates to p7, and the historical official
p6 binary update contains a kernel labelled p5; neither meets the project's
exact p6 kernel checks. The ISO command requires the prepared jail, packages
its patched FreeBSD base, and embeds the signed package repository. Output
includes `C9MANGO020.iso`, checksums and saved inputs. Keep both preparation
and release inputs to reproduce the build after upstream servers advance.
For subsequent builds, reuse the prepared jail or restore its saved archive
as described in [INSTALLER.md](INSTALLER.md).

See [INSTALLER.md](INSTALLER.md) for restoration, image details, and installation
steps. The ISO uses bundled packages for installation and the signed server
repository for later updates. Essential is selected by default; Development
and Office remain installer choices. Authentication at SDDM is mandatory.

Only after the ISO exists, test a new disposable VirtualBox VM with networking
disconnected. Verify offline installation, installed packages, SDDM login,
failed-password handling, and reboot behavior. VirtualBox is limited to
installer/login validation; native Mango graphics must be checked on the Dell
Latitude 5591 with Intel UHD 630. Do not infer desktop graphics support from a
successful VM installation.

The tested VirtualBox guest has no `/dev/dri`. The pinned SDDM implementation
only lists Wayland sessions when that directory exists; C9 deliberately uses
an empty X11 session directory. Together these produce a blank Session list,
even though the C9 session files and executable launcher are installed
correctly. See the [pinned SDDM session model](https://github.com/sddm/sddm/blob/c2b97dd/src/greeter/SessionModel.cpp#L43).
A temporary X11 authentication-test session is restricted to disposable guests.
It can exercise password rejection, non-root login, logout and reboot without
changing the production packages or ISO. It does not validate Mango rendering.

The stock FreeBSD 15.1 interactive root-password form accepts at most 32
characters in each password field. Keep input within that form limit; it is
separate from the regular-account dialog and password storage capabilities.

## Resource and option policy

The existing `/usr/local/etc/poudriere.d/c9-poudriere.conf` contains:

```sh
PARALLEL_JOBS=2
PREPARE_PARALLEL_JOBS=2
USE_TMPFS=no
RESOLV_CONF=/etc/resolv.conf
ALLOW_MAKE_JOBS=yes
```

`configure` installs the contents of `poudriere/c9-release-make.conf.example`
into the most specific C9 make configuration. It retains two compile jobs and
disables Thunar's panel plugin. Electron uses async Yarn extraction at
concurrency two; VS Code's Go compiler receives `GOMAXPROCS=2` and a 6 GiB
soft collection target, both scoped to that port. The separately installed master-specific
policy above keeps `MAX_MEMORY=8` and sets `MAX_MEMORY_electron43=2048`,
`MAX_MEMORY_vscode=16` and `MAX_FILES_vscode=8192`;
`configure` does not install that file. Other build sets remain managed by
the server administrator. The private signing key remains
on the server; only its public key is included in the ISO.
