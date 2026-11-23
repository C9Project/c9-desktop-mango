#!/bin/sh
# Sourced by poudriere image -A. The caller provides a prepared immutable input.
# Do not enable set -u here: Poudriere intentionally uses unset variables.
: "${C9_IMAGE_INPUT:?Missing prepared C9 input directory}"
: "${C9_PROJECT_ROOT:?Missing C9 project directory}"
: "${WRKDIR:?This script must be sourced by poudriere image}"
c9_world="$WRKDIR/world"
[ -d "$c9_world/etc" ] || err 1 'C9 image world is missing'

mkdir -p "$c9_world/usr/freebsd-dist" "$c9_world/usr/local/share/c9" "$c9_world/usr/local/libexec/c9"
cp -p "$C9_IMAGE_INPUT/distributions/base.txz" "$C9_IMAGE_INPUT/distributions/kernel.txz" \
    "$C9_IMAGE_INPUT/distributions/MANIFEST" "$c9_world/usr/freebsd-dist/" || err 1 'Copying C9 distributions failed'
cp -Rp "$C9_IMAGE_INPUT/packages" "$c9_world/usr/local/share/c9/" || err 1 'Copying C9 repository failed'
cp -Rp "$C9_IMAGE_INPUT/build" "$c9_world/usr/local/share/c9/" || err 1 'Copying C9 provenance failed'
cp -p "$C9_IMAGE_INPUT/poudriere.cert" "$C9_IMAGE_INPUT/C9.conf" "$C9_IMAGE_INPUT/install.conf" "$c9_world/usr/local/share/c9/" || err 1 'Copying repository trust failed'
install -m 755 "$C9_IMAGE_INPUT/pkg-static" "$c9_world/usr/local/libexec/c9/pkg-static" || err 1 'Installing pkg-static failed'

# Preserve the exact upstream file for review/debugging. Patch only the image.
cp -p "$c9_world/usr/libexec/bsdinstall/auto" "$c9_world/usr/libexec/bsdinstall/auto.freebsd"
awk -f "$C9_PROJECT_ROOT/installer/patch-auto.awk" \
    "$c9_world/usr/libexec/bsdinstall/auto.freebsd" > "$c9_world/usr/libexec/bsdinstall/auto.c9" || err 1 'Unsupported upstream bsdinstall auto script'
install -m 755 "$c9_world/usr/libexec/bsdinstall/auto.c9" "$c9_world/usr/libexec/bsdinstall/auto"
rm "$c9_world/usr/libexec/bsdinstall/auto.c9"
chmod 755 "$c9_world/etc/rc.local" "$c9_world/usr/libexec/bsdinstall/local.post-configure" \
    "$c9_world/usr/local/libexec/c9/install-target" "$c9_world/usr/local/libexec/c9/prepare-user-homes"
for c9_script in "$c9_world/etc/rc.local" "$c9_world/usr/libexec/bsdinstall/auto" \
    "$c9_world/usr/libexec/bsdinstall/local.post-configure" "$c9_world/usr/local/libexec/c9/install-target" \
    "$c9_world/usr/local/libexec/c9/prepare-user-homes"; do
    /bin/sh -n "$c9_script" || err 1 "Invalid installer shell: $c9_script"
done
# Match release-media resolver handling on a read-only root filesystem.
rm -f "$c9_world/etc/resolv.conf"
ln -s /tmp/bsdinstall_etc/resolv.conf "$c9_world/etc/resolv.conf"
mkdir -p "$c9_world/mnt" "$c9_world/tmp"
chmod 1777 "$c9_world/tmp"
test -s "$c9_world/boot/kernel/kernel" || err 1 'Image kernel is missing'
test -s "$c9_world/usr/local/share/c9/packages/packagesite.pkg" || err 1 'Repository catalog is missing'
test "$(env ROOT="$c9_world" /bin/freebsd-version -k)" = 15.1-RELEASE-p6 || err 1 'Image kernel revision mismatch'
