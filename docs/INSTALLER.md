# C9 installer: build and install

**Current corrected ISO:** server build/static checks and the full F: checksum
passed for `c9-0.2.0-zfs-20261122T153649Z`. The verified ISO is at
`F:\C9\releases\c9-0.2.0-zfs-20261122T153649Z\C9MANGO020.iso`;
its SHA-256 is `19ff43a1a64f90edc3297aca45f76b40f107c762554a373eee0ee9d8fbeae0fe`.
The installer-only fix passed actual FreeBSD ZFS/UFS regressions; a fresh
replacement-ISO EFI/ZFS installation test has not run. See
[quick start](QUICKSTART.md) for the new artifact and [ZFS recovery](ZFS-INSTALL-RECOVERY.md)
for resuming a paused original-ISO installation. The original BIOS/EFI
installation results below used UFS.

The image installs FreeBSD **15.1-RELEASE-p6 / amd64** and C9 **0.2.0** from
bundled files. It contains a text installer, not a live desktop. After a
successful installation the machine boots to SDDM; a regular user's password
is required. No automatic-login option or shared user credentials are included.

**Recorded status, 22 November 2026:** ISO creation and static verification
passed for `c9iso-20261122T104752Z`; the complete NTFS ISO copy matches the
server's size and full SHA-256. The initial BIOS installation passed with
networking disconnected, the VirtualBox profile and Essential applications
only. It installed 445 packages and booted the installed system to SDDM.
BIOS authentication/logout/reboot tests passed. EFI also installed 542 packages
with Development and Office, and passed the same SDDM tests after an actual
software reboot. The [reproduction guide](REPRODUCE.md) records the completed
server/local artifact paths, checksum, evidence and ISO-only repeat command.

VirtualBox is an **installer and login-screen test target**. Use VBoxSVGA with
3D acceleration disabled. Its FreeBSD graphics driver cannot run native Mango;
reaching the SDDM greeter is not evidence that Mango works. The normal Mango
Wayland session targets the Dell Latitude 5591 with Intel UHD 630 and requires
separate physical-machine validation. That profile installs `i915kms` through
the matched `drm-612-kmod` package and the selected Kaby Lake firmware set used
by this Coffee Lake graphics device. No general Intel or AMD hardware support
claim is made.

A blank **Session** list in the tested VirtualBox guest has a confirmed cause:
`/dev/dri` is absent, and SDDM's
[pinned session model](https://github.com/sddm/sddm/blob/c2b97dd/src/greeter/SessionModel.cpp#L43)
only enumerates Wayland sessions when that directory exists. C9's X11 session
directory is empty. Wayland support was compiled into SDDM, and the C9 desktop
entries and executable launcher have the correct paths and permissions.
For authentication tests, a temporary X11 test session may be installed only
inside disposable guests. Keep it out of production packages and ISO inputs;
its results concern SDDM authentication, not native Mango graphics.

## Build the ISO

The existing server already has the prepared `c9image151amd64` jail. Reuse it
for another image; do not rerun preparation against an existing jail. The
first-build procedure below is for a server without that jail. A repeated
image still verifies the package repository and payload before use.

Run on the FreeBSD Poudriere server from the complete project directory. First
complete and verify the entire C9 package build. Preparation calls the existing
package verifier, including all ten C9 packages, the signed catalog, dependency
plan, and package archive hashes. It refuses active jails. No kernel compilation
or image-jail creation starts before that gate passes.

The host-side repository checks explicitly select both `ABI=FreeBSD:15:amd64`
and `OSVERSION=1501000`, as recorded in `installer/release.conf`. Setting only
the ABI makes pkg infer the major release's .0 revision and reject these 15.1
packages. The scripts retain compatibility checks and verify the image jail's
numeric userland revision against this target.

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas install -d -m 0755 /usr/local/c9/image-inputs /usr/local/c9/releases
doas sh scripts/prepare-image-jail.sh \
  --build-id YOUR_COMPLETED_POUDRIERE_BUILD_ID \
  --output /usr/local/c9/image-inputs/c9-0.2.0-p6
doas sh scripts/build-iso.sh \
  --build-id YOUR_COMPLETED_POUDRIERE_BUILD_ID \
  --output /usr/local/c9/releases/c9-0.2.0-first
```

Use the same verified build ID for both commands. Both output directories must
be new: prior releases and failed-build evidence are never overwritten. The
preparation output's parent must already exist, be owned by root, and not be
writable by other users. Use paths without spaces or shell characters because
FreeBSD's kernel makefiles and Poudriere do not support those build paths.

Preparation downloads authenticated metadata and builds the standard GENERIC
kernel and modules with two make jobs. Keep this potentially lengthy process
running on the server. Its `phase`, `progress.log`, `exit-status`, and
`logs/*.log` files record progress and failure details. It creates the separate
`c9image151amd64` jail without changing the package jail. The image builder
requires that prepared jail and never fetches a newer base release on its own.
Initial preparation needs network access; installation from the ISO does not.

The central inputs are in [`installer/release.conf`](../installer/release.conf):

| Input | Value |
| --- | --- |
| Package jail/tree/set | `c9151amd64` / `default` / `c9` |
| Overlay | `c9overlay` |
| Image jail | `c9image151amd64`, with `GENERIC` kernel |
| Ports commit | `e7bc56a5d30dc24ce2e7990926836699cbd34e55` |
| Default package | `c9-workstation`, including Essential applications |
| Optional groups | `c9-apps-development`, `c9-apps-office` |
| Hardware choices | `intel` (Dell Latitude 5591 / UHD 630), `virtualbox` (installer/login tests) |
| Update repository | `http://192.168.178.55/packages/c9151amd64-default-c9` |
| Signing public key source | `/usr/local/etc/ssl/certs/poudriere.cert` |

The script checks the signed repository catalog, then fetches each required
package's recursive runtime dependencies from the local snapshot to verify
their recorded digests. The entire published repository generation is bundled;
the incomplete `.building` directory is never used. Only the public key enters
the image. The repository private signing key stays on the build server.

The result is `C9MANGO020.iso`, a BIOS/UEFI hybrid image, plus `SHA256`, `SHA512`,
and an `inputs/` directory. Keep `inputs/`: it contains the exact package
snapshot, public key, base/kernel archives, a restorable image-jail archive
including `/usr/src`, project source archive, ports revision, package inventory,
and build identity. The image-jail archive stays outside the ISO. `work/` is retained for diagnosis and
can be removed deliberately after validation if space is needed.

### Matching the patched base and kernel

The approved target requires **both** kernel and userland to report
`15.1-RELEASE-p6`. FreeBSD's update feed has moved to p7. Furthermore, the
official p6 update metadata identifies a GENERIC kernel whose embedded version
is p5; kernel and userland patch numbers can differ. Neither downloading the
current updates nor importing that historical binary satisfies C9's exact p6
requirement. The preparation helper therefore builds a standard GENERIC kernel
from the retained, authenticated p6 source. It keeps all version checks intact.

The helper uses the clean p6 package jail as the base-system input, verifies
that it contains no third-party packages or personal accounts, and takes a
separate copy. It restores the original login configuration when necessary and
removes build settings, cached updates, machine identity, SSH host keys, and
temporary state. Host world and host kernel files are never copied.

Source authentication uses a pinned p6 metadata-index digest retained from the
previously verified FreeBSD update, plus a saved p7 signature. The helper checks
the update public key's pinned fingerprint, verifies that signature, and checks
every downloaded metadata digest. Every selected p6 record must also appear in
the metadata authenticated by the saved signature. The signature authenticates
those records through the p7 indexes; it does not directly sign the retained
p6 tag. All proof inputs are saved under `inputs/authentication/`.

The complete source inventory is checked against those records: all 109,079
regular files and 9,527 directories, including hashes, types, owners, groups,
and modes. Unexpected or missing files fail preparation. Only ZFS's automatic
archive flag is disregarded. The source is copied before use, and separate
source, object, temporary, and destination directories keep compilation away
from the package jail and running host. Host make configuration and local
kernel modules are excluded from the build.

After `kernel-toolchain`, `buildkernel`, and `installkernel`, the helper checks
the exact kernel/userland versions, embedded GENERIC configuration, and source
inventory again. It saves the clean base archive, source archive, complete
image-jail archive, kernel hash/configuration, compiler identity, and logs. It
imports the archive with Poudriere's `tar` method and `-K GENERIC`, which does
not apply later updates, then verifies the imported jail. Existing jails are
never replaced. If a step fails, preserve its output and inspect its logs.

The build exports that jail into a separate staging directory, removes build
state and machine identity, and splits it into `base.txz` and `kernel.txz`.
The base archive contains the boot loaders and standard configuration; the
kernel archive contains `/boot/kernel`. This is a standard patched FreeBSD
world repackaged for C9, not an official FreeBSD release-distribution archive.
A new distribution `MANIFEST` records the actual hashes and file counts.

The complete archives are unpacked again to verify their patch levels,
kernel identity, absence of installer startup in the target base, and absence
of personal accounts, root passwords, SSH host keys, and machine identity.
Installer overlays are added **after** preparing the target payload. This
prevents the installed machine from booting into the installer again.

Keep the preparation output as well as the ISO's inputs. The saved signature
and content-addressed metadata pin this recipe independently of the current
update feed, but remote historical files are not guaranteed to remain available.
The completed image-jail archive is the repeat input for another server and
avoids both network acquisition and another kernel build. Do not edit the
version checks to suppress a mismatch. Before running the image builder on a
new server, restore the saved jail under the configured name:

```sh
# Only when c9image151amd64 is not already registered.
doas poudriere jail -c -j c9image151amd64 -v 15.1-RELEASE-p6 \
  -a amd64 -K GENERIC \
  -m tar=/path/to/saved/image-inputs/c9-0.2.0-p6/inputs/image-jail.tar.xz
```

Verify `inputs/image-jail.sha256` before restoration. Both preparation and the
ISO builder retain a restorable image-jail archive. Poudriere's `tar` method
does not automatically fetch newer updates. Preserve an existing jail; inspect
it instead of deleting/replacing it to make the command succeed.

To reuse the exact saved target archives with a compatible image jail:

```sh
doas sh scripts/build-iso.sh \
  --build-id YOUR_COMPLETED_POUDRIERE_BUILD_ID \
  --output /usr/local/c9/releases/c9-0.2.0-repeat \
  --payload /usr/local/c9/releases/c9-0.2.0-first/inputs/distributions
```

Saved archive hashes, version strings, and kernel content are checked again.
The workflow preserves reproducible inputs; it does not promise a byte-identical
ISO because filesystem metadata, image-generation timestamps, and build paths
can vary. Retaining the released ISO and its checksums is the definitive record.

## Install

1. Attach the ISO to a disposable VM or boot it on the intended machine. A VM
   with networking disabled is the clearest offline-installation check.
2. Choose **Install** and use standard bsdinstall keyboard, hostname, disk,
   UFS/ZFS, root-password, timezone, and account dialogs. Disk operations remain
   interactive and require the installer's normal confirmation.
3. Create a regular account with a non-empty password and a normal login shell.
   C9 asks again if the account step was skipped or no usable account exists.
4. Select one of the hardware profiles included in the image. Read the
   VirtualBox limitation before choosing that profile.
5. Select optional Development and/or Office applications. Desktop and
   Essential applications are always installed.
6. Wait for package installation and C9 configuration. Reboot and detach the
   ISO. Use your new regular account at SDDM, subject to the VirtualBox session
   limitation described above.

The stock FreeBSD 15.1 root-password dialog has a **32-character maximum** in
each field (`/usr/libexec/bsdinstall/rootpass`). Longer pasted input is limited
by the form, so enter a password within that length. This is the installer's
root-password form limit; it does not define the regular-account dialog or
FreeBSD's password storage limit. No test credentials are shipped or recorded
in this guide.

The installer mounts its bundled package repository read-only inside the new
system. An isolated package configuration accepts only that repository and its
public key. It installs the selected packages, then runs:

```sh
/usr/local/sbin/c9-system-setup --profile SELECTED_PROFILE --user CREATED_USER
```

Each eligible account is passed separately. Configuration files and user
templates belong to the C9 packages; setup initializes missing settings while
preserving existing user files. User passwords and SSH host keys are never
copied from another installation. Host keys are generated normally on the
installed system when the corresponding service is first started.

The installed package configuration enables the signed C9 update repository
and disables the default FreeBSD package repository to keep one consistent
package set. Later `pkg update`/`pkg upgrade` requires access to the LAN server.
FreeBSD base maintenance is separate; match kernel-module packages to any
future base/kernel change. No automatic base or application updates are enabled
by the ISO.

The source-built kernel uses an unchanged GENERIC configuration and remains
recognizable by `freebsd-update`. Future binary base updates can replace it
with an official kernel and move beyond this image's validated p6 baseline.
Coordinate such updates with compatible kernel-module packages and revised
C9 version checks, then validate the resulting system. An end-to-end base
update has not yet been tested for this image. See the
[FreeBSD Handbook's GENERIC guidance](https://docs.freebsd.org/en/books/handbook/cutting-edge/#freebsdupdate-custom-kernel-9x)
and the [15.1 updater implementation](https://raw.githubusercontent.com/freebsd/freebsd-src/releng/15.1/usr.sbin/freebsd-update/freebsd-update.sh).

## Integration and validation

The image's `/etc/rc.local` starts FreeBSD's `startbsdinstall` through
`runconsoles`. The installer uses the bundled distribution sets, skips online
firmware retrieval, and retains the normal interactive partitioning/account
flow. Its `local.post-configure` hook installs C9 before bsdinstall unmounts the
target.

Stock FreeBSD 15.1 does not propagate that hook's failure. A checked AWK patch
adds failure handling and removes the alternative network/pkgbase path. It
requires exactly the expected upstream matches and aborts image creation when
the upstream script changes. The original file is retained in the ISO as
`/usr/libexec/bsdinstall/auto.freebsd` and in the build inputs.

Run the focused patch test on FreeBSD:

```sh
sh installer/tests/test-patch.sh /usr/libexec/bsdinstall/auto
sh installer/tests/test-users.sh
sh installer/tests/test-wrapper.sh
sh installer/tests/test-dialog-routing.sh
sh -n scripts/prepare-image-jail.sh
sh -n scripts/build-iso.sh
sh -n installer/overlay/usr/local/libexec/c9/install-target
```

The patch test checks the actual upstream script, retention of disk and account
actions, propagation of C9 failure, and rejection of changed, duplicated, or
already-patched inputs. Image creation also checks syntax and payload contents.
These checks **do not replace** booting and installing the produced ISO.

The wrapper test exercises image customization after Poudriere clears its
environment, including paths with spaces, apostrophes, and shell characters.
The dialog test verifies that menus remain on the terminal while bsdinstall
redirects diagnostics to its log. User filtering checks FreeBSD's ten-field
`master.passwd` format and excludes locked or passwordless accounts.

The initial BIOS Essential-only installation and installed-state collection
passed with zero failed checks at 12:35:18 UTC on 22 November 2026. Its 445
packages, VirtualBox hardware profile, and installed/running p6 kernel and p6
userland were verified. Development and Office were not selected in that run.
SDDM wrong-password, non-root login, logout and actual software-reboot checks
passed on BIOS and EFI. EFI installed both optional groups and passed bounded
nonroot application-version checks and Mango configuration parsing. See
[VALIDATION.md](VALIDATION.md) for the recorded scope and evidence. Native
Mango rendering and graphical application acceptance still require
the physical Dell/Intel target. User-edited settings must also survive an
actual package upgrade before that acceptance item is complete.

## Repeat VirtualBox authentication testing

Use this only inside a disposable installed VirtualBox guest. The packaged
Mango session requires native DRM; an X11 xterm session lets you observe SDDM
password handling without changing the production session or authentication
policy. First collect the initial installed state as described in
[VALIDATION.md](VALIDATION.md).

Log in as root on a text console inside that guest and create this temporary
entry, refusing to replace an existing file or symlink:

```sh
test_session=/usr/local/share/c9/sessions/empty/c9-vm-auth-test.desktop
if [ -e "$test_session" ] || [ -L "$test_session" ]; then
  echo 'Inspect the existing test entry before continuing.' >&2
  exit 1
fi
cat > "$test_session" <<'SESSION'
[Desktop Entry]
Type=Application
Name=C9 VM authentication test (temporary)
Comment=Disposable VM X11 login observation only; not a Mango session
Exec=/usr/local/bin/xterm
TryExec=/usr/local/bin/xterm
DesktopNames=C9VMTest;
SESSION
chmod 0644 "$test_session"
service sddm restart
```

Keep the `Exec` value argument-free: the tested FreeBSD Xsession wrapper does
not split a command containing arguments. Log out of the root console and use
the graphical greeter. Reject a deliberately wrong password, then authenticate
as the regular user. Click inside xterm if needed; `id` must show that user's nonzero UID. Check
`echo "$XDG_SESSION_TYPE $DISPLAY"`. Run `exit` to return to SDDM, reboot, and
repeat the rejection/success/logout checks. Record screenshots and SDDM logs.
If the console used to restart SDDM no longer accepts input after logout,
switch to another text console before administrative collection.

After the test, authenticate at a root text console and remove only the entry
you created:

```sh
rm -- /usr/local/share/c9/sessions/empty/c9-vm-auth-test.desktop
```

Run the final installed-state collector against the initial baseline, then
shut down the guest. These tests establish login-manager behavior; they do
not establish native Mango rendering, application graphics, or package-upgrade
preservation. The temporary entry is not a production package or ISO change.

## Troubleshooting

| Symptom | Action |
| --- | --- |
| Build says package run is incomplete | Wait for the requested run to finish and publish; do not use an earlier build ID with newer packages |
| Image jail is missing | Run `prepare-image-jail.sh` after the full package release passes, or restore its saved image-jail archive |
| Image jail version differs | Inspect the existing jail; restore an approved p6 image input on a clean server or prepare a deliberate new release |
| Preparation fails source authentication or inventory checks | Preserve its logs and proof inputs; restore the approved source rather than weakening the checks |
| Missing C9 group/dependency | Complete the package build; all offered groups must be available offline |
| Signature verification fails | Confirm the public key matches the package signing key; do not disable signature checks |
| Installer C9 stage fails | Inspect `/tmp/c9-install.log` and `/tmp/bsdinstall_log` before rebooting |
| Installed system needs diagnosis | Read `/var/log/c9-install.log` and `/usr/local/share/c9/build/` |
| VirtualBox SDDM Session list is blank | The tested guest lacks `/dev/dri`, so SDDM hides Wayland sessions; C9's X11 list is empty. Use a temporary X11 test session only in disposable guests for authentication checks |
| VirtualBox reaches SDDM but Mango does not start | Expected native-graphics limitation; use the physical Dell/Intel target for Mango validation |
| Root password differs from a longer pasted value | Stock bsdinstall's root-password form accepts at most 32 characters per field; use input within that limit |
| VirtualBox EFI remains running after guest shutdown | Known behavior in this test environment. After FreeBSD finishes shutdown and syncing, power off the disposable test VM through VirtualBox |
| Updates cannot reach server | Check the LAN route and C9 repository URL; the initial installation remains offline |

References: [Poudriere image manual](https://man.freebsd.org/cgi/man.cgi?query=poudriere-image&sektion=8),
[bsdinstall manual](https://man.freebsd.org/cgi/man.cgi?query=bsdinstall&sektion=8),
[FreeBSD 15.1 release startup](https://raw.githubusercontent.com/freebsd/freebsd-src/releng/15.1/release/rc.local),
and [FreeBSD distribution manifest generator](https://raw.githubusercontent.com/freebsd/freebsd-src/releng/15.1/release/scripts/make-manifest.sh).
