# Recover the initial ZFS installation

The first C9 0.2.0 ISO (SHA-256
`ead71c8b7e0c44032861305619e734690fea9600d6996ef5a69a3e345c8c3a2b`)
can stop with `c9-system-setup: home is not owned by its account: daniel`
after packages have installed successfully. This was observed on the Dell
Latitude 5591 using ZFS and a verified USB written in Rufus DD mode.

The exact FreeBSD 15.1-RELEASE-p6 `adduser` was reproduced in an isolated
file-backed ZFS pool. Its final home-dataset remount runs inside the installer
chroot and applies the pool alternate root twice. The correctly owned home
remains intact at the doubled path, while C9 sees a root-owned placeholder.
Changing ownership is not the remedy.

## Diagnose before changing mounts

Use the live installer shell, outside any chroot. Keep the Restart/Exit dialog
open; do not restart disk partitioning or base extraction. Run:

```sh
zfs list -o name,mountpoint,mounted
zpool get altroot
mount -p | grep daniel
```

The confirmed Dell case showed:

```text
zroot/home/daniel  /mnt/home/daniel  yes
zroot             altroot         /mnt
zroot/home/daniel  /mnt/mnt/home/daniel  zfs
```

The following commands apply to that exact dataset and alternate root. For a
different account, pool or layout, inspect its actual account home and mounts
first. A normal mount at `/mnt/home/daniel` with a different UID is a different
problem; do not use recursive ownership changes to bypass the C9 guard.

## Remount only the affected home

Run outside the chroot, stopping if either ZFS command fails:

```sh
zfs unmount zroot/home/daniel
zfs mount zroot/home/daniel
mount -p | grep daniel
chroot /mnt id daniel
chroot /mnt stat -f 'uid=%u gid=%g path=%N' /home/daniel
```

The actual mount must now be `/mnt/home/daniel`, and its numeric owner must
match Daniel's UID from `id`. This preserves the original ownership and files.
Do not use force-unmount, mount all datasets, or change dataset properties.

## Resume the C9 stage

The error handler may have unmounted the target's devfs while leaving its ZFS
filesystems mounted. Restore devfs only if no filesystem is mounted there:

```sh
mount -p | awk '$2 == "/mnt/dev" {found=1} END {exit !found}' || bsdinstall mount_aux
sh /usr/local/libexec/c9/install-target /mnt
```

Choose the Intel profile and the same optional application groups. The hook
reuses the installed packages from the signed offline repository, completes
system/user setup, and writes the update configuration and success log.
If it fails, stop and inspect `/tmp/c9-install.log`.

Only after the **C9 configured** success dialog, finish the two stock
post-hook steps and reboot:

```sh
bsdinstall entropy && bsdinstall umount && reboot
```

Remove the USB when the machine restarts. The installed success log is
`/var/log/c9-install.log`. SDDM uses the regular account's password.

## Evidence and permanent correction

The original reproduction is retained on the build server at
`/usr/local/c9/tests/zfs-home-repro-20261122T152500Z`; both the reproduction
and guarded cleanup exited zero. The evidence archive SHA-256 is
`7187bca6d9e802f3b7870371d6b9f0e2eabcedc135377b20f99aeb03c1d2bc8f`.
The generated test pool was destroyed after verifying its GUID and file vdev.

The installer correction passed the focused FreeBSD regression at
`/usr/local/c9/tests/zfs-home-regression-20261122T153700Z`: repair, repeated
correct ZFS mount, wrong-owner rejection and real UFS preservation all passed;
fixture cleanup also exited zero. It remounts only a selected user's affected
home dataset from outside the target chroot. Replacement-ISO static checks and the full F: copy checksum have passed.
Fresh EFI/ZFS installation validation remains pending. The
C9 package ownership check remains required; package and kernel rebuilds are
not needed for this installer correction. See [VALIDATION.md](VALIDATION.md)
for the resulting regression and replacement-ISO status.

## Repeat the focused regression

Run on the FreeBSD build server from the reviewed source directory, before
rebuilding the image:

```sh
doas sh tests/verify-user-homes.sh \
  /usr/local/c9/c9-desktop-mango-0.2.0/installer/overlay/usr/local/libexec/c9/prepare-user-homes \
  a1da64d3f1495905210669894182b3a2efaabc2da3d9264977bb379d64b78463 \
  "/usr/local/c9/tests/zfs-home-regression-$(date -u +%Y%m%dT%H%M%SZ)"
```

The test requires the retained exact p6 base archive at the recorded original
release path. It creates a unique ZFS pool using only a new sparse image file,
plus a separate read-only UFS image. It replays the stock adduser behavior,
checks the repair and repeat-call behavior, compares home data and metadata,
and preserves/rejects a genuine ownership mismatch. Cleanup checks the exact
pool GUID and file-device bindings. It never targets a physical disk. Retain
its RESULTS.txt, reproduction-exit-status and cleanup-exit-status records;
both exit statuses must be zero. The image files remain in that new evidence
directory after the test pool and mounts are removed.
