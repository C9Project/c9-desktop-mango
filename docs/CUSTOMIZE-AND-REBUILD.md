# Customize C9 and rebuild on Poudriere

This guide covers changing the C9 sources, deploying them to the existing
Poudriere server, rebuilding packages, and producing another offline ISO.
**The current 0.2.1 Rio branch is a source-only candidate.** Only source edits
and local checks are in scope; the server is unavailable and no deployment,
package build or ISO run has been performed. Review [Rio terminal](RIO-TERMINAL.md)
before using the later deployment/build sections. Its dependency count is
deliberately `unreviewed`, so it cannot yet pass final ISO acceptance.

For a later approved deployment, [Automated rebuild](AUTOMATED-REBUILD.md)
performs the package-to-ISO sequence with retained logs and compatible package reuse.
The user reported successful installation on the Dell Latitude 5591 on
22 November 2026. Detailed graphics and application acceptance was not
separately reported.

## 1. Choose the rebuild you need

| Your change | What to rebuild |
| --- | --- |
| Documentation only | Regenerate the source manifest/archive; no package or ISO build |
| Installer screens, installer logic, or the ZFS home helper | ISO only, provided the package selection and FreeBSD inputs stay the same |
| Applications, desktop defaults, artwork, startup scripts, services, or driver dependencies | C9 package release, verification, then ISO |
| FreeBSD release/patch level, architecture, or the base ports revision | Deliberately prepare and validate a new platform baseline; see section 8 |

The quickest repeat of the existing **0.2.0** ISO is in section 5, using its
matching retained source rather than this Rio branch. For changed packages,
follow sections 2–4 and 6. The current scripts enforce a particular release;
changing a configuration value alone does not update every validation rule.

### Recorded 0.2.0 baseline and current checkout

| Item | Recorded value |
| --- | --- |
| Local checkout, now carrying the 0.2.1 source branch | `F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z` |
| SSH / root commands | `ssh daniel@192.168.178.55` / `doas` |
| Retained 0.2.0 server source | `/usr/local/c9/c9-desktop-mango-0.2.0` |
| Package jail / tree / set | `c9151amd64` / `default` / `c9` |
| Recorded overlay | `c9overlay`; points at the recorded server source's `ports/` |
| FreeBSD | `15.1-RELEASE-p6`, amd64, OSVERSION 1501000 |
| Ports commit | `e7bc56a5d30dc24ce2e7990926836699cbd34e55` |
| Successful package build | `c9release-20261122T094945Z` |
| Current image jail | `c9image151amd64` |
| Kernel preparation record | `/usr/local/c9/image-inputs/c9-0.2.0-p6-20261122T094945Z` |
| Corrected ISO and saved inputs | `/usr/local/c9/releases/c9-0.2.0-zfs-20261122T153649Z` |
| Published repository | `/usr/local/poudriere/data/packages/c9151amd64-default-c9` |

The existing package jail, ports tree, distfiles, compiler cache and signing
key can be reused for changes on this same FreeBSD baseline. Keep the
registered overlay and build configuration unchanged while a job is running.
The old source-directory names and p6 preparation paths remain valid evidence;
they do not imply the local 0.2.1 branch has been deployed. Recheck live server
state before any future build.

## 2. Make the change in the source tree

All paths in this table are relative to the source root.

| What you want to adjust | Files to edit |
| --- | --- |
| Essential applications | `ports/misc/c9-apps-essential/Makefile`, especially RUN_DEPENDS |
| Development applications | `ports/devel/c9-apps-development/Makefile` |
| Office applications | `ports/editors/c9-apps-office/Makefile` |
| Core desktop components | `ports/x11/c9-desktop-mango/Makefile` |
| Groups installed by the workstation meta-port | `ports/x11/c9-workstation/Makefile` |
| Mango, Waybar, Rio, Fuzzel, Mako and GTK defaults | `ports/x11/c9-desktop-defaults/files/skel/.config/` |
| C9 Rio launcher entry | `ports/x11/c9-desktop-defaults/files/c9-rio.desktop` and that port's `pkg-plist` |
| Session launch and background applications | That port's `files/c9-mango-session`, `files/session-apps`, and `files/c9-mango.desktop` |
| Wallpaper and logo | `ports/x11-themes/c9-artwork/files/wallpaper.svg` and `c9-logo.svg`; the PNG is generated during the package build |
| SDDM, services and explicit system setup | `ports/sysutils/c9-system-config/files/` |
| Intel or VirtualBox driver dependencies | `ports/sysutils/c9-hardware-intel/Makefile` or `ports/emulators/c9-hardware-virtualbox/Makefile` |
| Installer choices and selected groups | `installer/overlay/usr/local/libexec/c9/install-target` |
| ZFS home-mount correction | `installer/overlay/usr/local/libexec/c9/prepare-user-homes` |
| Release inputs and update URL | `installer/release.conf` |
| Complete C9 origin list | `poudriere/c9-release.list` |
| Per-port build options and compile jobs | `poudriere/c9-release-make.conf.example` |

**Example: include Git in Essential.** Add `git>=0:devel/git` to the
RUN_DEPENDS list in the Essential Makefile, retaining the backslash between
continued dependency lines. This uses the same dependency already present
in Development. Then follow the package-release workflow below.

An application added to an existing group is resolved recursively. Do not
add its third-party origin to `c9-release.list`: that list accepts C9
origins only. A new C9 group needs a port, its C9 origin in that list, the
installer checklist/case entries, and updated expected package inventories.
The current scripts expect the origin's final component to equal its C9
package name.

Development and Office are built and bundled even when their installer
checkboxes default to `off`. Changing a checkbox to `on` changes the
default selection; changing a group's Makefile changes its contents.
Removing a dependency does not guarantee its archive disappears from the
ISO: the builder copies the entire published repository, and other packages
may still require it.

**Defaults preserve user changes.** Updating the defaults package does not
overwrite the Dell user's existing configuration. A new template also needs
an entry in that port's `pkg-plist`, the fixed file list in
`files/c9-user-init`, and the relevant test expectations. For an existing
user, review and merge the changed template into their configuration.
For Rio, this includes the existing Mango terminal binding and Fuzzel terminal
command; adding the Rio template does not rewrite either file. Follow the
opt-in migration in [Rio terminal](RIO-TERMINAL.md), preserving Foot settings
and verifying the new terminal before considering removal of the old package.

For Python, use the port's `USES=python:3.12,run` mechanism; the generic
`lang/python3` meta-port is not a valid substitute dependency here. Keep
Node.js and npm on matching majors. A new hardware profile also needs its
C9 origin in c9-release.list, C9_HARDWARE_PROFILES in release.conf, the
profile whitelists in the image builder and installer, the system-config
profile/setup logic, and its package/plist entries.

## 3. Give changed packages a new release identity

The current build gates require **every C9 package's full version to equal
C9_VERSION** in `installer/release.conf`. Editing packaged files while
keeping the same package identity can cause old packages to be reused.
A single `PORTREVISION=1` on this candidate produces `0.2.1_1`, which fails
its exact `0.2.1` gate.

The coordinated **0.2.1** source changes follow these rules. A later release
needs the same review with its own version:

1. Set DISTVERSION to 0.2.1 in all C9 Makefiles named by
   `poudriere/c9-release.list` (currently ten), including any new C9 ports.
   Reset a C9 PORTREVISION when changing
   DISTVERSION, if one was added. Leave unrelated upstream port versions alone.
2. Set `C9_VERSION=0.2.1` and update the internal C9 dependency minimums
   to `>=0.2.1`.
3. Keep the existing image jail when the FreeBSD baseline is unchanged.
   Section 6 checks its retained kernel/payload proof separately from the
   new package build ID. A platform change requires new prepared inputs.
4. Use `C9_IMAGE_NAME=C9MANGO021` and update the
   filename, volume-label and fstab expectations in `tests/verify-iso.sh`.
5. Update that verifier's C9 version and package/origin table. The earlier
   **545-package** combined installation plan belongs to 0.2.0. This candidate
   sets `C9_EXPECTED_INSTALL_PACKAGE_COUNT=unreviewed` in release.conf. The
   verifier retains the future actual plan and fails acceptance until its
   dependency changes are reviewed and a positive expected count is committed.
   Do not guess a count or automatically accept the observed value. The ten
   exact C9 identities, signatures and archive-hash checks remain required.
6. Preserve `tests/collect-installed-evidence.sh` as the historical 0.2.0
   collector. It pins that release's build ID, test account, VirtualBox profile,
   signing key, Foot and original templates. Prepare a separate collector for
   later 0.2.1 installation tests once their actual inputs exist; do not relabel
   the old checks or dated evidence as Rio validation.
7. Record the intended changes in CHANGELOG.md.

When a build is authorized, this rebuilds the small C9 packages together;
compatible upstream packages are still reused. Installer-only edits made from
the retained 0.2.0 source can keep its package release and use section 5.
The Rio dependency/default changes require new packages and cannot use that path.

For a change only to a third-party overlay port, such as a Firefox patch,
give that port an appropriate version/revision change. The exact-version
gate applies to C9 packages, so unchanged C9 ports retain their matching
`C9_VERSION` (0.2.0 on the retained release, 0.2.1 on this branch).
This still needs a new successful package build and verified image
inputs from section 6. For build
option changes, install the updated policy with configure and review the
plan to confirm the intended packages will rebuild.

## 4. Archive and deploy the edited sources

The current task stops at local source preparation and checks. The commands
below describe a future approved deployment; they have not been run for Rio.

Use the existing archive helper so hidden `.config` templates and the
updated MANIFEST.sha256 are included. In **Windows PowerShell**:

```powershell
Set-Location -LiteralPath 'F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z'
$c9_stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$c9_archive = "F:\C9\c9-source-$c9_stamp.tar.gz"
.\scripts\prepare-source.ps1 -Output $c9_archive
scp $c9_archive daniel@192.168.178.55:/home/daniel/
```

Keep the printed timestamp and SHA-256. From the Windows terminal, connect
directly to an interactive Bourne shell; the remaining server examples use
`sh` syntax:

```sh
ssh -t daniel@192.168.178.55 /bin/sh
```

Substitute the two printed values below. Extract your own verified archive
into a **new** source directory, preserving the current source:

```sh
set -eu
c9_stamp=PASTE_TIMESTAMP
c9_expected=PASTE_SHA256
printf '%s\n' "$c9_stamp" | grep -Eq '^[0-9]{8}T[0-9]{6}Z$'
printf '%s\n' "$c9_expected" | grep -Eq '^[0-9a-f]{64}$'
c9_upload="/home/daniel/c9-source-$c9_stamp.tar.gz"
c9_source="/usr/local/c9/c9-source-$c9_stamp"
[ "$(sha256 -q "$c9_upload")" = "$c9_expected" ]
[ ! -e "$c9_source" ] && [ ! -L "$c9_source" ]
doas mkdir -m 0755 "$c9_source"
doas tar -xzf "$c9_upload" --no-same-owner --no-same-permissions -C "$c9_source"
doas chown -R root:wheel "$c9_source"
doas find "$c9_source" -type d -exec chmod 0755 {} +
doas find "$c9_source" -type f -exec chmod 0644 {} +
cd "$c9_source"
while read -r digest relative; do
    [ "$(sha256 -q "$relative")" = "$digest" ] || exit 1
done < MANIFEST.sha256
```

These commands rely on the trusted archive produced from your project by
prepare-source.ps1. They do not switch the live overlay. For a package build,
`configure` below switches its registration to this new source directory
when the package jail is idle; it saves the previous registration/configuration.
For an installer-only build, the image script can use this source directly
without changing the package overlay.

## 5. Rebuild only the ISO with the completed packages

This path applies to unchanged packages on the current p6 baseline. It uses
the original successful package build and existing prepared image jail.
It requires matching 0.2.0 source and does **not** apply to the 0.2.1 Rio branch.
Use the freshly deployed source directory for installer edits, or the
current canonical source for an unchanged repeat. The default below applies
only when c9_source is unset; it preserves the new directory selected in
section 4. Check the printed source path before continuing:

```sh
set -eu
c9_source=${c9_source:-/usr/local/c9/c9-desktop-mango-0.2.0}
printf 'Installer source: %s\n' "$c9_source"
cd "$c9_source"
grep -qx 'C9_VERSION=0.2.0' installer/release.conf
c9_build_id=c9release-20261122T094945Z
c9_kernel_record=/usr/local/c9/image-inputs/c9-0.2.0-p6-20261122T094945Z
c9_payload=/usr/local/c9/releases/c9-0.2.0-zfs-20261122T153649Z/inputs/distributions
c9_repeat=$(date -u +%Y%m%dT%H%M%SZ)
c9_iso_dir="/usr/local/c9/releases/c9-iso-repeat-$c9_repeat"

doas sh scripts/c9-build.sh verify "$c9_build_id"
doas sh scripts/build-iso.sh --build-id "$c9_build_id" \
    --output "$c9_iso_dir" --payload "$c9_payload"
doas sh tests/verify-iso.sh --release-dir "$c9_iso_dir" \
    --kernel-record "$c9_kernel_record" --project "$c9_source" \
    --build-id "$c9_build_id" --output "/usr/local/c9/tests/iso-repeat-$c9_repeat"
```

Run these foreground commands in a session that stays connected. The
verifier must finish with exit 0. Keep the output directory and its inputs.
This path does not rebuild packages or the kernel; image assembly still
archives/copies inputs and calculates checksums.

If a later package run has replaced the published repository, verification
of the old build ID will stop. The package build ID must identify the current
published repository. The kernel-origin ID identifies the unchanged preparation
record and may be older; its exact hashes must still match the image inputs.

## 6. Build changed packages, then the complete new ISO

Use the coordinated source changes from section 3 and the new deployed
directory from section 4. Keep the same package jail, pinned ports tree
and resource settings for this workflow.
These are future release steps, not completed validation of the source-only
Rio candidate. Its first actual dependency plan still needs review before
the `unreviewed` count can be replaced and ISO acceptance can pass.

**This master is also the Dell's live update repository.** Poudriere
publishes before the C9 wrapper verifies its result. The current
COMMIT_PACKAGES_ON_FAILURE policy permits publication even when some ports
fail. Run client updates only after explicit C9 verification succeeds;
the wrapper checks the result but does not control when it is published.

### Configure, plan and start the package build

In the server `sh` session, with c9_source set to that new directory:

```sh
set -eu
cd "$c9_source"
doas poudriere status
doas sh scripts/c9-build.sh configure
doas sh scripts/c9-build.sh plan
c9_build_id="c9release-$(date -u +%Y%m%dT%H%M%SZ)"
c9_run="/usr/local/c9/runs/$c9_build_id"
doas mkdir -m 0755 "$c9_run"
doas daemon -f -p "$c9_run/runner.pid" -o "$c9_run/console.log" \
    /bin/sh "$c9_source/scripts/c9-build.sh" build "$c9_build_id"
printf 'Build ID: %s\nSource: %s\n' "$c9_build_id" "$c9_source"
```

This explicit daemon invocation keeps the package job running after SSH
disconnects and creates its console.log. Save the two printed values to
restore the variables after reconnecting. Do not start another C9 build or
edit this source while the runner is active.

The wrapper uses `poudriere bulk -t -r`. It reuses compatible completed
packages and builds/tests the missing or invalidated ones. It does not
request a clean rebuild of every upstream dependency.

Check progress:

```sh
doas poudriere status
doas tail -n 40 "/usr/local/c9/runs/$c9_build_id/console.log"
```

The [dashboard](http://192.168.178.55/) and logs under
`/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/BUILD_ID/`
show individual port failures. The wrapper's attempt directory records
inputs and Poudriere's exit status. A zero in that attempt's exit-status
file is not sufficient: it is written before the final repository checks.

Poudriere can become idle while the wrapper is still verifying its repository.
The daemon normally removes runner.pid when the wrapper exits. After that
file has disappeared, require the explicit success gate below; if a PID file
remains after an interrupted server session, inspect its process and log first:

```sh
set -eu
doas test ! -e "/usr/local/c9/runs/$c9_build_id/runner.pid"
cd "$c9_source"
doas sh scripts/c9-build.sh verify "$c9_build_id"
```

This checks zero failed/skipped/ignored ports, the published build identity,
exact C9 versions, the signed catalog, every required archive hash and the
dependency transaction. A successful build publishes the new repository
used by the Dell's configured update URL.

### Reuse the verified image inputs and build

On the unchanged p6 baseline, retain the existing image jail, kernel record
and exact saved distribution payload. The verifier accepts an explicit
historical kernel-origin ID separately from the new package build ID. It
still requires the record, image jail and archived kernel hashes to agree.
The automated runner performs this sequence; the equivalent manual steps are:

```sh
set -eu
cd "$c9_source"
c9_kernel_record=/usr/local/c9/image-inputs/c9-0.2.0-p6-20261122T094945Z
c9_kernel_build_id=$(cat "$c9_kernel_record/inputs/package-build-id")
c9_payload=/usr/local/c9/releases/c9-0.2.0-zfs-20261122T153649Z/inputs/distributions
c9_iso_dir="/usr/local/c9/releases/$c9_build_id"
doas sh scripts/check-image-inputs.sh --kernel-record "$c9_kernel_record" \
    --payload "$c9_payload" --kernel-build-id "$c9_kernel_build_id"
doas sh scripts/build-iso.sh --build-id "$c9_build_id" \
    --output "$c9_iso_dir" --payload "$c9_payload"
doas sh tests/verify-iso.sh --release-dir "$c9_iso_dir" \
    --kernel-record "$c9_kernel_record" --project "$c9_source" \
    --build-id "$c9_build_id" --kernel-build-id "$c9_kernel_build_id" \
    --output "/usr/local/c9/tests/iso-$c9_build_id"
```

Keep this foreground session connected. Each output directory must be new.
Never relabel the retained kernel proof as belonging to the new package build.
If deliberately preparing a new image jail/kernel instead, use a new jail name
and preparation output. Omit the old --payload on its first ISO build so the
builder generates matching distributions; preparation itself does not produce
base.txz/kernel.txz/MANIFEST. Save that new payload and record for future runs.

For later ISO-only repeats, use the currently published successful package
build ID and retain the verified image jail, kernel record and matching
inputs/distributions. The optional `--kernel-build-id` preserves the old
kernel provenance without weakening the binary-hash checks.

## 7. Copy, verify and test the new image

On the server, keep the ISO, SHA256, SHA512, inputs directory, build logs and
verification evidence together. In a new **Windows PowerShell** session,
substitute the actual release directory and image name:

```powershell
$c9_remote_release = '/usr/local/c9/releases/ACTUAL_RELEASE_DIRECTORY'
$c9_image = 'C9MANGO021'
$c9_destination = 'F:\C9\releases\ACTUAL_NEW_RELEASE'
New-Item -ItemType Directory -Path $c9_destination -ErrorAction Stop
scp "daniel@192.168.178.55:$c9_remote_release/$c9_image.iso" "$c9_destination\$c9_image.iso"
scp "daniel@192.168.178.55:$c9_remote_release/SHA256" "$c9_destination\SHA256-server.txt"
Get-FileHash -Algorithm SHA256 -LiteralPath "$c9_destination\$c9_image.iso"
Get-Content -LiteralPath "$c9_destination\SHA256-server.txt"
```

For a 0.2.0 repeat the image name remains C9MANGO020. Require a successful
transfer and an exact full SHA-256 match before writing USB media. Use
Rufus DD mode, as for the working Dell installation.

Test the changed behavior, not only image structure: offline installation,
selected package groups, ZFS home mount and ownership, SDDM authentication,
and the changed application/default/profile. Review /var/log/c9-install.log
after installation. The live failure log is /tmp/c9-install.log.
VirtualBox covers installer/login behavior; native Mango graphics require
the physical Intel machine. This workflow does not require investigating
the known VirtualBox shutdown hang.

For already-installed machines, packages update through the configured C9
repository. As root on the Dell, `pkg update` followed by
`pkg upgrade -n` previews the new transaction; review it before an actual
`pkg upgrade`. This applies to the same FreeBSD baseline, not a base-system
upgrade. Existing per-user configuration remains preserved; a new default
in a package is not automatically a migration of the user's current file.
Package upgrades also do not invoke c9-system-setup: it has no package hook.
For changed services, SDDM policy or hardware-profile settings, review the
new setup helper and the installed configuration before applying a migration.
Existing sample/profile files may be preserved, and conflicting settings
can be rejected; rerunning the helper is not a general overwrite operation.

## 8. Changes to the platform or build resources

- **Ports tree:** the wrapper requires a clean checkout at C9_PORTS_COMMIT.
  Advancing it requires deliberate revision selection and review of the
  local doxygen, desktop-file-utils and Firefox overlay repairs. Do not run
  a routine ports update during an active build.
- **FreeBSD/architecture:** release.conf is only part of the change.
  prepare-image-jail.sh's authenticated recipe is specifically p6/amd64.
  The installer, image customization, Intel system setup and tests also pin
  p6; package tooling pins ABI/OSVERSION. A new baseline needs matching
  package-jail sources, kernel/modules, image jail and validation. Do not
  update the working jail in place as an incidental package rebuild.
- **Resources:** current policy is two builders, two compile jobs and
  disk-backed work directories. The set file is
  /usr/local/etc/poudriere.d/c9-poudriere.conf; master-specific limits are in
  c9151amd64-default-c9-poudriere.conf in the same directory. Default limits
  are 8 GiB virtual address space and 2,048 open files; Electron43 has the
  approved 2,048 GiB address-space exception and VS Code has 16 GiB/8,192
  files. These are not RAM reservations. The wrapper asserts these values;
  a deliberate policy change must update both configuration and assertions.
- **Update URL or signing key:** change release.conf and the corresponding
  verification expectations together. Existing installations already have
  their own /usr/local/etc/pkg/repos/C9.conf and trusted public key; a new
  ISO does not update those files on an installed Dell. Keep the private
  signing key on the server.

## 9. If a build fails

Read the failing port's error log and the runner console. Let other active
work finish before replacing inputs. Fix the source, give changed packaged
contents an appropriate identity, deploy a fresh source snapshot, then use
a **new build ID**. The completed compatible packages are reused.

The same ID may be resumed only for a deliberately interrupted run with no
recorded failed, skipped or ignored ports. A failed ID retains exclusions;
the wrapper rejects using it as a retry. Do not treat an unpublished
.building repository as a completed release.

| Failure | What to check |
| --- | --- |
| Wrong C9 package version | All ten package identities, C9_VERSION and the actual published repository |
| Overlay points elsewhere | Run configure from the intended new source while idle |
| Ports/jail version differs | Restore the intended pinned inputs or complete a deliberate platform migration |
| Kernel-record package build differs | Use the matching fresh preparation record from section 6 |
| Kernel payload hash differs | Do not reuse an old payload with a newly built image-jail kernel |
| Combined package count is unreviewed or differs | Review the retained dependency plan, commit the reviewed numeric expectation, and verify a new candidate; never copy the old 545 count blindly |
| Signature/archive verification fails | Check the signer, public key and archive integrity; retain verification |
| Installer reports a home-ownership failure | Inspect actual ZFS mounts; use [ZFS recovery](ZFS-INSTALL-RECOVERY.md), not recursive chown |

Keep the known working ISO and saved inputs for recovery. Reproduction
details are in [REPRODUCE.md](REPRODUCE.md), dated evidence in
[VALIDATION.md](VALIDATION.md), and dependency repairs in
[PORTS-PATCHES.md](PORTS-PATCHES.md).
