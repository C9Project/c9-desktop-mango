# C9 0.2.0 quick start

**Use the corrected ZFS installer below for new installations.** It fixes the p6 adduser home-dataset mount without changing package ownership, user data or the already built packages. For a paused installation using the original ISO, follow [ZFS recovery](ZFS-INSTALL-RECOVERY.md).

Server build and static verification passed on 22 November 2026 at 16:06:27 UTC. The complete F: copy passed its size and full SHA-256 comparison at 16:25:30 UTC. The user subsequently reported successful installation on the Dell Latitude 5591. The fresh EFI/ZFS VM test was not run; detailed graphics/application acceptance was not separately reported.

To change this build and produce another release, follow
[Customize and rebuild](CUSTOMIZE-AND-REBUILD.md), then use the
[automated package-to-ISO runner](AUTOMATED-REBUILD.md).

C9 uses FreeBSD **15.1-RELEASE-p6 / amd64**, package jail `c9151amd64`, image jail `c9image151amd64` and the existing pinned `default` ports tree. Essential applications are included; Development and Office are optional and bundled.

## Use the replacement ISO

Server:

```text
/usr/local/c9/releases/c9-0.2.0-zfs-20261122T153649Z/C9MANGO020.iso
```

Verified F: copy:

```text
F:\C9\releases\c9-0.2.0-zfs-20261122T153649Z\C9MANGO020.iso
```

Size: **6,238,777,344 bytes**. SHA-256:

```text
19ff43a1a64f90edc3297aca45f76b40f107c762554a373eee0ee9d8fbeae0fe
```

The full local copy matches the server size and SHA-256; `copy-verification.json` beside it records the check.

1. Write the verified ISO with Rufus **DD mode** and boot it on the intended target.
2. Select the installation disk and partition layout carefully: installation replaces data on the selected disk.
3. Create your own root password and regular account. The stock root-password form accepts at most 32 characters; add the regular user to wheel if administrative access is needed.
4. Select **intel** for the Dell Latitude 5591 / UHD630, or **virtualbox** for installer/login tests. Select Development and/or Office if wanted.
5. Wait for **C9 configured**, finish installation, remove the USB and reboot. SDDM requires the regular account's password.

Initial installation needs no network. Later package updates use the signed repository at `http://192.168.178.55/packages/c9151amd64-default-c9` when the machine can reach that LAN address.

The original BIOS/EFI tests used UFS and passed offline installation and authenticated login/reboot checks. The replacement's fresh EFI/ZFS VM test was not run. VirtualBox lacks the native DRM support required by Mango, so its SDDM list has no Mango Wayland session; temporary X11 authentication-test files remain confined to disposable guests. See [validation](VALIDATION.md).

## Recreate the ISO using completed packages

```sh
ssh daniel@192.168.178.55
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas sh scripts/build-iso.sh \
  --build-id c9release-20261122T094945Z \
  --output "/usr/local/c9/releases/c9-0.2.0-zfs-repeat-$(date -u +%Y%m%dT%H%M%SZ)" \
  --payload /usr/local/c9/releases/c9-0.2.0-zfs-20261122T153649Z/inputs/distributions
```

The builder rechecks the recorded successful package build and current repository identity. It requires the prepared p6 image jail and copies saved base/kernel payloads. Each output directory must be new. Repeated builds need not produce identical ISO bytes. [REPRODUCE.md](REPRODUCE.md) describes restoring the saved inputs.

## Repeat the recorded package build

Deploy reviewed source only while the jail is idle. For a changed package release, update package identities and expected C9 versions together: source-file edits alone do not force Poudriere to replace an unchanged package identity. Preserve the pinned ports revision and approved per-package resource limits.

```sh
build_id="c9-0.2.0-$(date -u +%Y%m%dT%H%M%SZ)"
doas sh scripts/c9-build.sh configure
doas sh scripts/c9-build.sh plan
doas sh scripts/c9-build.sh build "$build_id"
doas sh scripts/c9-build.sh verify "$build_id"
```

These commands reuse compatible completed packages. Complete and verify every required package before creating an ISO or installing a VM. Use `doas poudriere status` or the [dashboard](http://192.168.178.55/) for status.

## Working source and recovery records

The recovered working source remains at:

```text
F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z
```

E: reported hardware I/O errors and is excluded from further work. The replacement ISO destination is F:, as requested. The original verified C: ISO remains historical evidence and has the old ZFS installation defect.

Keep the source archive, release inputs, repository and checksums for reproduction. Preserve the private repository signing-key backup separately on the server; the ISO contains only the public key.
