# Validation and release gates

## Project contact and source control — 23 November 2026

The source now uses `c9_project@proton.me` for all ten C9 port maintainers,
with unchanged `DISTVERSION=0.2.0`, dependencies and upstream port maintainers.
The verified source was preserved as Git tag `baseline-20261122` before this
separate metadata change. See [Source control](SOURCE-CONTROL.md).
Existing packages and ISOs were not rebuilt and retain their original metadata.

## Rebuild automation — 22 November 2026

The new [automated runner](AUTOMATED-REBUILD.md) passed all twelve isolated
FreeBSD orchestration regressions. They cover full stage order and argument
propagation, explicit package reuse, package/ISO-verification failure codes,
existing-output preservation, unsafe path rejection, real lock contention,
source-snapshot mutation, cancellation with lock retention through child
cleanup, and real daemon completion/failure status.

Evidence: `/usr/local/c9/tests/rebuild-regression-20261122T214351Z`, exit 0.
Runner SHA-256: `27e6f37eeef50356b3fa98f47c06556a1a461d7aad3d5812125e9c661aef5e66`.
Harness SHA-256: `f8e3e88fc6b084c8b0f0030d633d22f9422d24a8cba4cfab74fea2a13428835d`.

The image-input checker also passed against the real retained p6 jail/kernel
record/payload, and rejected wrong historical identity, symlink inputs, wrong
kernel hash, corrupt payload and writable-parent fixtures. Evidence:
`/usr/local/c9/tests/image-input-preflight-20261122T213716Z`.
The ISO verifier's change is limited to an optional separate kernel-origin ID
and evidence fields; its existing binary, package, boot and cleanup checks remain.

These are orchestration/preflight tests with fake build stages, not a new
production package or ISO build. The existing verified release below remains
the installation artifact until a new real pipeline completes successfully.

## Replacement ISO and Dell report — 22 November 2026

| Gate | Observed result |
| --- | --- |
| Packages | Existing successful build `c9release-20261122T094945Z` reused; all ten C9 packages remain 0.2.0 |
| Focused installer regression | Passed doubled-path repair, repeated correct-ZFS no-op, unchanged rejection of genuine wrong ownership, and real UFS no-op; data/account hashes and fixture cleanup passed |
| Replacement ISO build/static verification | Passed at 16:06:27 UTC |
| Full F: copy verification | Passed at 16:25:30 UTC; full SHA-256 and byte count match |
| Fresh EFI/ZFS VM installation | Not run: prepared VM was removed before boot |
| Dell installation | User subsequently reported successful installation on the Dell Latitude 5591 |

The replacement artifact is:

```text
/usr/local/c9/releases/c9-0.2.0-zfs-20261122T153649Z/C9MANGO020.iso
```

Size **6,238,777,344 bytes**; SHA-256 `19ff43a1a64f90edc3297aca45f76b40f107c762554a373eee0ee9d8fbeae0fe`.
The F: destination is `F:\C9\releases\c9-0.2.0-zfs-20261122T153649Z\C9MANGO020.iso`; the completed local file matches both values, verified at 16:25:30 UTC.

Durable runner: `/usr/local/c9/runs/c9iso-zfs-20261122T153649Z`.
Static evidence: `/usr/local/c9/tests/iso-zfs-20261122T153649Z`.
The reviewed static-evidence archive `static-verification-evidence.tar.gz` has SHA-256 `b055e47db8ab6b6851b8e4b6fa77542c2eca411f713f7cfde653f3c8b6d57891`.

The home-helper regression evidence remains at `/usr/local/c9/tests/zfs-home-regression-20261122T153700Z`. Its archive SHA-256 is `0fd394708293759c8ba7496865120cc116b744a6d2fa2e9ca06c378f4e928c79`. The tested helper SHA-256 is `a1da64d3f1495905210669894182b3a2efaabc2da3d9264977bb379d64b78463`.

The Dell success is a user-reported installation result. The report did not
identify the exact ISO/recovery route or separately describe native graphics
and application checks; those details are not inferred here. The maintenance
procedure is now documented in [Customize and rebuild](CUSTOMIZE-AND-REBUILD.md).

This was an installer-only change. All 106 port files and metadata were preserved, and package, kernel, authentication and ownership policies were retained. The build reused the completed repository and exact saved base/kernel payloads. The existing original-ISO UFS VM evidence below remains historical; it is not a completed replacement-ISO ZFS test.

## ZFS home mount correction — 22 November 2026

The first physical Dell installation reached the C9 setup stage but stopped
with `home is not owned by its account: daniel`. The packages were already
installed. The user confirmed ZFS, Rufus DD mode and the fully verified ISO.
The home dataset reported `/mnt/home/daniel` while the mount table showed
`/mnt/mnt/home/daniel`, with pool alternate root `/mnt`.

The exact retained p6 `adduser` reproduced this in an isolated file-backed
ZFS pool. Remounting only that home dataset from outside the chroot exposed
the original user-owned files without changing ownership. The user then
reported `uid=1001 gid=1001 path=/home/daniel` on the Dell and later reported
successful Dell installation. Prior VM installations used UFS and did not
cover this ZFS behavior.

An installer-only `prepare-user-homes` helper now runs before C9 system setup.
It passed focused regression tests in
`/usr/local/c9/tests/zfs-home-regression-20261122T153700Z`: the actual p6
adduser mount was repaired, the repeated invocation preserved correct ZFS
state, a real ownership mismatch was rejected unchanged, and a real UFS
image was left unchanged. Home content/metadata and account-file hashes were
preserved; overall test and guarded fixture cleanup exited zero. The reviewed
helper SHA-256 is
`a1da64d3f1495905210669894182b3a2efaabc2da3d9264977bb379d64b78463`.
The replacement ISO build and static verification passed at 16:06:27 UTC.
The complete F: copy passed verification at 16:25:30 UTC; the fresh EFI/ZFS installation test has not run.
The package ownership/authentication guards and all ports remain unchanged.
See [ZFS recovery](ZFS-INSTALL-RECOVERY.md) for the exact observed case, evidence
and steps to resume the existing installation without repeating partitioning.

**Package gate passed on 22 November 2026 at 09:50:39 UTC.** All ten C9
0.2.0 packages and their dependencies are built. `c9release-20261122T094945Z`
finished with zero failed, skipped or ignored ports. Signed repository
`.real_1795341030` passed verification: 545 packages in the installation plan
and all runtime archive hashes checked.

**Original-ISO creation and static verification also passed on 22 November.**
Image-jail preparation completed at approximately 10:44 UTC, including the
standard GENERIC kernel/modules and authenticated-source checks. ISO run
`c9iso-20261122T104752Z` finished with exit 0 at approximately 11:10 UTC;
the static verifier passed at 11:15:09 UTC. Artifact identity and evidence are
recorded below.

**The original full local ISO and its BIOS/EFI UFS installation/authentication gates passed.**
BIOS installed Essential applications offline (445 packages); EFI installed
Essential, Development and Office offline (542 packages). Both passed wrong-
password rejection, nonroot SDDM login, logout and authentication after actual
software reboots. Authentication used temporary VM-only X11 test sessions.
Package-upgrade preservation and physical Mango desktop acceptance remain
separate checks.

Source inspection, package tests, installation and graphics tests establish
different properties. None substitutes for the next stage.

## Package build history

The server has the C9 jail `c9151amd64` at `15.1-RELEASE-p6 / amd64`, full
`default` ports tree at `e7bc56a5d30dc24ce2e7990926836699cbd34e55`. The recursive
run `c9-20261114T082555Z` completed its remaining **79/79 packages with zero
failed, skipped or ignored ports**, combining with 215 earlier packages for
294 completed packages. Its restart record reports `2026-11-14T15:32:24Z` as
the finish time.

After that run finished, the overlay was registered at
`/usr/local/c9/c9-desktop-mango-0.2.0/ports`; original 0.1.0 sources were retained.
Prior configuration is saved under
`/usr/local/c9/backups/release-config-20261114T153245Z`.

The expanded recursive release run `c9release-20261114T104144Z` started at
15:33 UTC on 14 November. It queued 500 additional packages while reusing
compatible existing packages and replacing the old C9 desktop 0.1.0 package.
It finished after 13 hours 21 minutes with **474 built, three failed,
23 skipped and zero ignored**:

- `devel/doxygen`: `build_fs_violation` from documentation font caches.
- `devel/desktop-file-utils`: leftover `share/applications/intent.cache`.
- `devel/electron43`: Yarn fetch failed with Node's CodeRange virtual-memory
  reservation error.

Earlier queued retries refused to proceed when their failure sets were
superseded or contained additional unreviewed failures. The three reviewed
repairs and focused test evidence are recorded in
[PORTS-PATCHES.md](PORTS-PATCHES.md). They preserve package selections and QA.
Electron's exact dependency fetch passed with async Yarn archive processing
at concurrency two under the unchanged 8 GiB virtual-memory limit. That was
a fetch-only check; the subsequent full Electron build is recorded below.

After the build became idle, a 99-source-file snapshot was deployed to
`/usr/local/c9/c9-desktop-mango-0.2.0`. Its archive SHA-256 is
`ec079a9f4804634d2402ca783af3633b030a39713d79a46460ae051aaa3a1978`.
The dependency plan confirmed 26 remaining packages. Retry
`c9retry-20261115T104611Z`, attempt `attempt-20261115T104612Z`, started at
10:46 UTC on 15 November with all three reviewed fixes, retaining compatible
packages, two builders, two compile jobs per builder, disk-backed work
directories and existing resource limits. It finished at 20:01 UTC on
15 November after about 9 hours 15 minutes, with **20 built, two failed and
four skipped**. Firefox failed bundle generation; Electron subsequently
failed to reserve address space for its V8 snapshot generator's sandbox.

In this retry, `desktop-file-utils-0.29_1` and `doxygen-1.18.0_1,2` passed
their full Poudriere checks. `c9-desktop-defaults-0.2.0` also passed.
Electron's actual Yarn fetch passed and it progressed into Chromium compilation.
At approximately 14:12 UTC, Firefox failed its webpack bundle generation:
Node reached the 8 GiB virtual-address limit with about 570 MiB resident.
The same command was reproduced in an isolated test directory; running its
minifier without a worker passed twice under the unchanged limits. The local
`www/firefox` overlay contains that one-line repair with `PORTREVISION=1`.
The repair was deployed at 20:33 UTC in the 143-file source archive with
SHA-256
`1a71092b8a9d950f98709229e1af9bf3c881f59868eca48942fae0009012e115`.
Retry `c9firefox-20261115T203301Z` started at 20:34 UTC and finished at
22:59 UTC, with **three built, zero failed and zero skipped**. Firefox,
`c9-apps-essential`, and `c9-workstation` passed full Poudriere package QA.
That run published generation `.real_1794783552`, containing nine
C9 packages at version 0.2.0. See [PORTS-PATCHES.md](PORTS-PATCHES.md) for
the exact evidence and the separate Electron failure.

On 16 November, the user approved and the server installed
`/usr/local/etc/poudriere.d/c9151amd64-default-c9-poudriere.conf` with
`MAX_MEMORY=8` and `MAX_MEMORY_electron43=2048`. The backup is
`/usr/local/c9/backups/electron-address-limit-20261116T051731Z`.
Electron's full V8 sandbox needs 1,376 GiB of virtual addresses plus other
process mappings. The exception permits that reservation without allocating
2 TiB of RAM or disabling the sandbox. At that point, other packages retained
8 GiB; the later VS Code exception is recorded below.
Two builders and two compile jobs per package remain unchanged.
Run `c9release-20261116T052133Z` started at 05:21 UTC on 16 November
and finished at 02:03 UTC on 17 November: **one built, one failed, one
skipped and zero ignored**. Electron 43.8.7 passed after about 20 hours
21 minutes, including its standard V8 snapshot generator and package QA.
VS Code 1.145.1 failed with `tsgo exited with code 2`, and
`c9-apps-development` was skipped. That run published signed generation
`.real_1794880991`. These results were checked on 22 November; no build
was still running. At that point, complete release verification had not
passed. The subsequent retries reused Electron and the other compatible
completed packages.

On 22 November, the VS Code failure was reproduced directly as Go heap
exhaustion under the original 8 GiB address limit. Reducing concurrency and
requesting earlier garbage collection did not make it fit. The user approved
`MAX_MEMORY_vscode=16` and `MAX_FILES_vscode=8192`; these were installed with
the previous policy backed up under
`/usr/local/c9/backups/vscode-limits-20261122T092006Z`.
The exact cold compiler step then passed in 101.85 seconds with exit 0 and no
diagnostics using `GOMAXPROCS=2 GOMEMLIMIT=6GiB`. Peak resident memory was
about 9.9 GiB. The standard checker count and all type checks were retained.
See [PORTS-PATCHES.md](PORTS-PATCHES.md) for the complete evidence. The
compiler trial established that the revised limits supported that step.
The subsequent package and release results are recorded below.

Run `c9release-20261122T092234Z` subsequently completed with **one built,
one failed, zero skipped and zero ignored**. VS Code passed all package QA
after approximately 23 minutes. `c9-apps-development` failed `stage-qa`:
ports must not depend on `lang/python3`. Its declaration now uses
`USES=metaport python:3.12,run`, selecting the existing `python312-3.12.16`
package. Actual FreeBSD metadata evaluation confirmed no new build
dependencies, flavors, IGNORE or BROKEN values, and unchanged other runtime
dependencies. The signed repository generation `.real_1795340785` retained
the successful VS Code package. The failed Development metaport still blocked
image-jail creation until the following release retry passed.

That final one-package retry, `c9release-20261122T094945Z`, passed on
22 November: **one built, zero failed, zero skipped and zero ignored**,
reusing all completed dependencies. All ten C9 packages are version 0.2.0
in signed generation `.real_1795341030`. At 09:50:39 UTC, verification passed
the signed catalog, complete 545-package installation plan and runtime archive
hashes. Evidence is in `/usr/local/c9/verify.y1ioIsPy`. Only after this result
did the durable runner enter image-jail preparation. Its source archive has
147 files and SHA-256
`d06192ae4aafca0194eecc3119548eb5845f1b3b108fadf25ab2df63fda98cd6`.

The verification command was checked with the server's `pkg 2.9.0` on
16 November using a separate empty package database and the signed catalog.
For the workstation, office and two hardware groups available on that date,
`pkg install -n -U` printed a valid 511-package plan but returned 1;
`pkg install -n -y -U` printed the same plan and returned 0. A nonexistent
package still returned 1 through the script's `pipefail` pipeline. This follows
the [pkg 2.9.0 command implementation](https://github.com/freebsd/pkg/blob/2.9.0/src/install.c#L254):
the dry run exits before applying jobs, but its final status also depends on
the confirmation flag. The wrapper now supplies both `-n` and `-y`; it does
not accept arbitrary nonzero results. No packages were installed and the
host package database hash was unchanged. Test records are under
`/usr/local/c9/tests/pkg-dry-run-u7fPT3Bc`.

On 16 November, the updated wrapper passed actual FreeBSD shell parsing and
its resource check accepted the then-installed 8/2048 GiB policy. Isolated
fixtures changing either limit were rejected. Each build attempt records the
master-specific resource file. These were command-validation checks; the
completed package release has its separate evidence above.

[POUDRIERE-SERVER.md](POUDRIERE-SERVER.md) records the complete operational
history. Package, static image and BIOS installation/authentication checks are
complete; EFI, package-upgrade and physical desktop acceptance remain outstanding.

## Completed 0.2.0 source checks

- Reviewed selected upstream package metadata against the actual server tree,
  including package names, blank IGNORE/BROKEN values and hardware module files.
- Checked all ten custom ports' dependency graph for missing custom origins
  and cycles, and the application/artwork ports' version, layout and LF text.
- Evaluated metadata for all ten C9 ports on the actual FreeBSD server. The
  original 0.2.0 deployment verified 86 source-file hashes. The later
  99-source-file snapshot identified above supplied the first reviewed retry;
  the later 143-file deployment supplied the successful Firefox retry.
- Parsed both original artwork SVG files as XML and checked that they need no
  external fonts or images. On 22 November, visually inspected the actual
  packaged 2560×1440 wallpaper: complete dark blue/teal waves and C9 mark,
  without missing elements or clipping. Its PNG SHA-256 is
  `2517931a474fc690317a6c6e8428df5bb21792376a63dbd9b1a00c460c808729`.
- Compared Mango configuration keys/actions with tagged 0.18.5 source and
  Waybar's native Mango module interface; parsed the Waybar JSON configuration.
- On 22 November, the actual built `mango-0.18.5_1` successfully parsed the
  exact configuration from `c9-desktop-defaults-0.2.0` with `mango -c PATH -p`:
  exit 0 and an empty parser error log. Signed package archives were fetched
  into an isolated directory, then extracted and run as `daniel` (UID 1001).
  No compositor/backend was started and the host package database remained
  unchanged. The fixture explicitly selected its extracted XKB data because
  the package's absolute compatibility symlink otherwise resolved on the host.
  Evidence is under
  `/usr/local/c9/tests/mango-config-20261116T052319Z/resume-20261122T091207Z`.
- Checked all four desktop/system helper scripts with the server's actual
  FreeBSD `/bin/sh -n`, via stdin without installing them.
- Exercised the packaged `c9-user-init` on FreeBSD as `daniel` on
  22 November, redirecting only its template path to the extracted payload.
  Reversing that one substitution produced a byte-identical packaged script.
  All nine fresh files matched their templates; repeated runs, edited files,
  symlinked `.config`, valid and dangling file symlinks, alternate Mango/Waybar
  filenames and custom `XDG_CONFIG_HOME` were preserved. The host package
  database and extracted payload hashes remained unchanged. Results are in
  the Mango fixture directory above (`RESULTS.txt`, both exit-status files
  zero). These checks do not establish full installation or package-upgrade
  behavior.
- Inspected SDDM/PAM integration, base `pam_xdg`, seatd's `video` group and
  Mango startup/logout process-group handling.
- Verified the explicit Xorg greeter dependency in the actual ports tree:
  `xorg-server-21.1.26,1`, including `bin/X` and `bin/Xorg` in its package list.
  Its explicit `xf86-input-libinput-1.5.0` input-driver dependency was also
  checked, including `libinput_drv.so` in the upstream package list.
- Checked installer/image helper scripts and the package wrapper with the
  actual FreeBSD shell. Tested the patch against the server's installed 15.1
  bsdinstall script: disk/account/time actions remain, C9 hook failures propagate,
  and changed, duplicated or already-patched inputs are rejected.
- Verified FreeBSD tar's source-tree exclusion behavior and exercised the
  installer's account filter using synthetic fixtures on FreeBSD, including
  UID boundaries, locked/empty passwords, invalid shells and invalid homes.
  Those fixtures created no production test accounts, ISO or image jail.
- Fixed and tested two image/installer integration defects: Poudriere clears
  inherited environment variables, so its customization hook now receives
  paths through a generated wrapper; installer menus now preserve terminal
  output while capturing selections under bsdinstall's logfile redirection.
  Wrapper fixtures with an empty environment and quoted/metacharacter paths,
  and dialog-routing fixtures, passed on FreeBSD.
- On 22 November, authenticated the retained p6 source inventory against
  FreeBSD update metadata covered by a saved p7 signature and the pinned
  update public key. All 109,079 source files and 9,527 directories matched
  their hashes, types, owners, groups and modes; no entries were missing or
  extra. The filesystem's automatic archive flag was the only permitted
  flag difference. This establishes source integrity; kernel and image
  acceptance are separate checks. Current HTTP jail creation would
  fetch p7, while the historical official p6 binary kernel reports p5;
  preparation therefore keeps the project's exact p6 kernel checks and uses
  the authenticated p6 source. See [INSTALLER.md](INSTALLER.md).

The unchanged baseline and historical source records remain available.
Deployment hashes identify the source snapshot that was actually uploaded;
later local changes require a new deployment snapshot. Source checks do not
prove package staging, installation or graphics.
Documentation can be updated after a deployment. Archive hashes identify
their recorded snapshots, not subsequently edited local documentation.

## Package gate and target checks

Follow [BUILD.md](BUILD.md). **All offered meta-ports, custom packages,
application groups, hardware packages and dependencies must be built and
verified on the existing Poudriere server before ISO creation or VM
installation.** Reuse compatible existing packages; do not rebuild everything.
The package gate passed in `c9release-20261122T094945Z`. BIOS Essential-only
installation is verified below; optional-group installation and package-upgrade
behavior still need their separate target-system tests.

| Check | Required evidence |
| --- | --- |
| `scripts/c9-build.sh configure` | Idle jail, recorded inputs, correct new overlay and retained old configuration |
| `scripts/c9-build.sh plan` | Complete release list resolves against pinned tree and overlay |
| `scripts/c9-build.sh build BUILD_ID` | Recursive build/tests pass, including staged payloads; no failures/skips/ignored ports |
| `scripts/c9-build.sh verify BUILD_ID` | Matching published identity, signed catalog, required C9 versions, solvable install plan and all runtime archive hashes |
| Packaged Mango configuration | `mango -c PATH -p` succeeds with actual built binary |
| User preservation | Existing files/symlinks survive setup, repeated setup and package upgrade |
| Explicit system setup | Chroot-safe operation, correct groups/configuration, preserved credentials and keys |

The package build and verification gates have recorded passing results.
The isolated configuration and user-preservation fixtures above cover their
stated cases; they do not establish installation, package-upgrade or graphical
behavior. These recorded packages retained the placeholder maintainer contact.
The source contact was updated on 23 November; these artifacts were not rebuilt.

## Completed ISO and static artifact checks

The prepared image jail was imported successfully from
`/usr/local/c9/image-inputs/c9-0.2.0-p6-20261122T094945Z` (exit 0).
The ISO-only run reused that jail and the unchanged package build
`c9release-20261122T094945Z`.

| Artifact | Recorded value |
| --- | --- |
| ISO | `/usr/local/c9/releases/c9-0.2.0-20261122T104752Z/C9MANGO020.iso` |
| Size | 6,238,750,720 bytes |
| SHA-256 | `ead71c8b7e0c44032861305619e734690fea9600d6996ef5a69a3e345c8c3a2b` |
| ISO run | `c9iso-20261122T104752Z`, exit 0, approximately 11:10 UTC |
| Static verifier | `/usr/local/c9/tests/iso-20261122T104752Z-v3`, exit 0, 11:15:09 UTC |

The ISO run used the deployed 148-file source archive with SHA-256
`9a05464a19b7a74a7eb07607a484d2da407a9e7445502a46597e650249fd440a`.
The first ISO attempt stopped at catalog validation: setting only the ABI
made `pkg 2.9.0` infer OSVERSION 1500000 instead of the actual target 1501000.
The successful retry supplied both values and retained compatibility checks;
no package rebuild or kernel rebuild was needed.

Static verification checked BIOS/EFI boot structures and loaders, the exact p6
GENERIC kernel/base payload, installer hooks, account databases and credential
checks over configuration/home/provenance trees. It also verified all ten C9
0.2.0 packages, the signed dependency archives, the 545-package combined
installation plan and the installer's packaged bootstrap. The ISO hash and
host package database were unchanged by verification. Private-key scans did
not cover vendor package test fixtures.

The initial validator falsely rejected its comparison of the padded BIOS
boot image using `cmp -n`. Version 3 compares a stream limited to the boot
file's length and passed against the same immutable ISO. This was a validator
correction, not a change to the image. These checks establish artifact
contents; the BIOS boot/installation results below are separate runtime evidence.

## Local storage failure and recovery

The initial SCP transfer to the USB/exFAT E: volume stopped with a partial
5,326,209,024-byte file. Windows reported Disk event 154 hardware I/O errors
and `FullRepairNeeded` for the volume. The partial file is preserved, no repair
was run, and E: is excluded from further work. The server ISO, package repository
and passed static checks are unchanged.

The project was recovered from a trusted C: source archive plus the latest
saved small documentation/test files into
`C:\Users\DPeyer\AppData\Local\C9VMTests\20261122T100429Z\project-recovery`.
The first 4 GiB (4,294,967,296 bytes) of the ISO were recovered onto C: and
matched the server prefix with SHA-256
`0005aead298cfe059c85a5dc59dddf39715fceca626b3ce796d2879e3fdffdda`.
That initial check verified only the prefix. SFTP subsequently completed the
remaining transfer to
`C:\Users\DPeyer\AppData\Local\C9VMTests\20261122T100429Z\release-20261122T104752Z\C9MANGO020.iso`.
At 12:04:15 UTC, the complete 6,238,750,720-byte local image matched the server's
full SHA-256, `ead71c8b7e0c44032861305619e734690fea9600d6996ef5a69a3e345c8c3a2b`.
The BIOS tests used this verified copy.

## VirtualBox installation and authentication checks

After the package gate passed, the initial USB-backed VirtualBox configurations
were prepared but never started. They remain untouched. Their replacement VMs
are under
`C:\Users\DPeyer\AppData\Local\C9VMTests\20261122T100429Z\ntfs-vms`:

| Firmware | VM name | UUID |
| --- | --- | --- |
| BIOS | `C9-0.2.0-BIOS-20261122T100429Z-NTFS` | `0dadd859-e1f2-437d-bfa6-e284653acb57` |
| EFI64 | `C9-0.2.0-EFI64-20261122T100429Z-NTFS` | `8fc64501-59d5-43f4-9fa3-1715119f0419` |

Both use two CPUs, 2 GiB RAM, a 40 GiB dynamic disk, VBoxSVGA with 128 MiB VRAM,
disabled 3D acceleration and no network interfaces. The BIOS VM completed
standard interactive installation from the ISO with the VirtualBox profile
and Essential applications only. It installed 445 packages, then booted from
its installed disk with the ISO detached. EFI likewise completed offline with
Development and Office (542 packages) and booted its installed disk with the
ISO detached. Both tests used GPT and UFS; the EFI disk also has a 260 MiB
EFI system partition. ZFS installation was not exercised in these tests.

The initial collector passed at 12:35:18 UTC. The final collector passed at
12:45:37 UTC after actual reboot, repeated authentication/logout and removal
of the temporary session entry and its backup. Both recorded zero failed
checks and exit 0. Evidence is under the C: task directory:

| Evidence archive | SHA-256 |
| --- | --- |
| `bios-essential-initial/evidence.tar` | `84978a90b9a2b5624880c21be35d9082e210c2c9d1e1986f9d71d01a45e55e6e` |
| `bios-essential-after-reboot/evidence.tar` | `33398e09b725d8605209c5cd10f1c672a903da3477966beba28c640d89765b58` |

The copied archives matched their guest hashes. All 13 captured-command checks
passed in each collection. The 445-package inventory, seven selected C9 0.2.0
packages, hardware profile, service settings, account identities, public signer
and build identity remained unchanged. All 11 public configuration files and
all nine user-template contents/types/owners/modes matched the initial
baseline. Kernel, running kernel and userland all report p6; required services
are running. The only network interface is loopback, and no installer startup
or temporary package-repository mount remained.

SDDM hides Wayland entries when `/dev/dri` is absent, as it is in this VM.
For authentication observation only, a temporary desktop entry was installed
in `/usr/local/share/c9/sessions/empty`. Its original xterm command included
arguments that the stock Xsession wrapper kept in one executable argument.
Using `Exec=/usr/local/bin/xterm` without arguments allowed the test session
to remain open. This changed only the disposable VM test entry; no production
port, SDDM/PAM policy, C9 Wayland session or ISO was changed. The final collector
confirms that only the production C9 Wayland entry remains.

Screenshots are under `screenshots/bios` in the C: task directory. The accepted
sequence agrees with the final sanitized SDDM log:

| Observation | UTC / supporting evidence |
| --- | --- |
| Wrong password rejected | 12:38:40, `54-wrong-password-rejected.png` |
| Nonroot authenticated X11 session | Log success 12:41:34; `60-nonroot-session-identity.png` shows UID 1001, `x11`, display `:0`, user `c9tester` at 12:41:50 |
| Logout returns to greeter | 12:42:02, `61-logout-returned-greeter.png` |
| Actual reboot requires authentication | New SDDM startup 12:44:06 and greeter 12:44:10; `70-reboot-auth-required.png` |
| Wrong password rejected after reboot | 12:44:20, `71-reboot-wrong-password-rejected.png` |
| Nonroot authentication succeeds again | Log success 12:44:29; `72-after-reboot-nonroot-auth.png` shows UID 1001 and X11 identity at 12:44:37 |
| Temporary session removed; final checks pass | 12:45:37, `75-final-bios-collector.png` and final archive above |

Earlier automation attempts misinterpreted unquoted PowerShell scan-code values
`1d`/`9d`, and some commands were sent after restarting SDDM changed the active
console. These control mistakes were corrected before the accepted tests.
Screenshots `55-correct-login.png`, `56-test-xterm-login.png` and
`62-after-reboot-greeter.png` are not acceptance evidence; their filenames do
not establish login or reboot success. The actual log timeline, explicit
nonroot identity and final collector establish the results above.

Administrative collection used an already authenticated root console; root
guest-control authentication remained unavailable and no authentication policy
was weakened. The sanitized logs do not explain that transport restriction.
The installed Mango binary also parsed the user's configuration successfully,
without starting a graphics session; `bios-installed-mango-parse.log.exit-status` records exit 0.

These BIOS results establish offline installation and mandatory SDDM
authentication. The EFI results are recorded below. Preservation through a
package upgrade and native Mango rendering remain separate acceptance tasks.

### EFI offline installation and authentication validation

On 22 November 2026, the EFI64 VirtualBox test passed offline installation with Essential, Development and Office, installed-disk boot, SDDM password rejection and successful nonroot login, logout, and an actual software reboot. The installed system has 542 packages, including nine C9 packages at 0.2.0; kernel, running kernel and userland report FreeBSD 15.1-RELEASE-p6 with GENERIC. All network adapters were absent and the ISO was detached after installation.

The initial collector at 13:45:08 UTC and final collector at 13:52:00 UTC both returned exit 0 with zero failed checks; all 13 captured command statuses were zero. Independent comparison found all nine user configuration fingerprints, eleven public configuration files, package inventory, hardware profile, service settings, account identities and repository signer unchanged. This checks preservation across reboot/login, not a package upgrade or deliberate user-edit scenario. The temporary argument-free X11 xterm session was hash-checked and removed before final collection; the shipped ISO and production session configuration were not changed.

Accepted evidence is in `screenshots/efi` in the validation archive. Images 37/48/53 show both optional groups selected, installation completion and the installed greeter. SDDM logs record rejection at 13:47:32, successful c9tester authentication at 13:47:42, and return to the greeter at 13:48:48 (images 79/83/87; UID 1001). An actual software reboot completed without host intervention; images 95/97 show disk boot and a fresh greeter. Logs then record rejection at 13:50:46, success at 13:50:52 and logout at 13:51:10 (98/100/101; image 100 shows UID 1001 and X11 at 13:51:08). Image 105 shows temporary-session removal and the passing final collector. Its first export attempt hit a guest-property size limit; the subsequently completed bounded transfer was independently hash-verified.

Nine nonroot CLI checks returned zero within their 30-second limits: identity, VS Code 1.145.1, Git 2.56.1, CMake 3.31.12, Python 3.12.16, Node 24.22.2, npm 12.2.2, LibreOffice 26.8.2.2 and Mango configuration parsing. These version/parse checks do not establish graphical application usability. The temporary X11 session tests SDDM/PAM authentication; native Mango graphics and the physical Dell Latitude 5591 / Intel UHD630 remain untested.

Guestcontrol transport was unavailable despite successful root and nonroot console authentication. Collection used authenticated root-console execution and sanitized output transferred through bounded custom guest properties, with matching guest/host SHA-256 hashes; no authentication policy was changed. All task guest properties were removed afterward. Final machine metadata shows poweroff, an empty DVD drive and all eight NICs set to none. Final shutdown reached “All buffers synced” (image 108); the known VirtualBox poweroff hang required controlled host poweroff. The successful software reboot above was separate; no further shutdown investigation was performed, as requested.

Reviewed compressed archive SHA-256 values:

- Initial: `cbfba5b1cc30712a49142474f0f7a026ba406232af4f9a7f3bd11a082a51ba2a` (guest tar `2a6d5340d590615ee6d8a34e3a2406da2188036443b86e1a39ee6d591fb71845`).
- CLI: `98020a64d49863fe87ae9b9cc77aeb5fcba742362a16bd527c88141c710a5d63`.
- After reboot: `9f1306d9bcb2ce97d7660dd74c32a8ca0b6117cae8860b841f1a7a1e6c898bed` (guest tar `2d11d333f0b0536a012db78209e170496dbb075da73576bd3e1b1b38aab9fb0a`).

The combined reviewed evidence index is stored at `/usr/local/c9/tests/vm-20261122T100429Z/files/INDEX.md` with the exact archive and its SHA-256 record in the parent directory. The evidence collector is pinned to this release and test account; screenshots and SDDM logs establish the interactive authentication results.

### Repeat the installed-state collection

Copy [`tests/collect-installed-evidence.sh`](../tests/collect-installed-evidence.sh)
into the disposable installed VirtualBox VM and run it as root. It expects the
`c9tester` test account. Choose `bios-essential` for Essential only, or
`efi-all` for the EFI test with Development and Office:

```sh
sh /path/to/collect-installed-evidence.sh bios-essential /root/c9-initial
# After the separately observed login/logout/reboot tests:
sh /path/to/collect-installed-evidence.sh bios-essential /root/c9-after-reboot /root/c9-initial
```

Each output directory must be new; the collector refuses existing destinations.
The optional third argument compares all nine user configuration files with
the earlier baseline. It does not modify user settings or establish preservation
through an application/package upgrade. Screenshots and SDDM logs establish
the interactive authentication results separately.

This collector is pinned to package build `c9release-20261122T094945Z`, the
approved public-key digest, p6, C9 version 0.2.0 and `c9tester`; review those
expectations before using it for a future release. It records safe account
identities and sanitized logs, not passwords, password hashes or private keys.
No test credentials or temporary X11 session entry are included in the project.

## Separate physical acceptance

On the Dell Latitude 5591 / UHD 630, verify native Mango startup, matching
kernel/modules, input, display modes, Waybar, launcher, notifications,
wallpaper, clipboard, audio/portals, selected applications, manual locking,
logout to SDDM and authentication after reboot. Check user edits through an
upgrade. Test suspend or other hardware behavior before claiming support.

Record hardware, firmware, kernel/module/package versions, ports commit,
configuration, logs and outcomes. Successful VirtualBox login does not qualify
physical graphics; successful Poudriere builds qualify neither.
