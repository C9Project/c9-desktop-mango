#!/bin/sh
# Verify the finished C9 0.2.1 ISO without installing packages or booting it.
# Only the new evidence directory is written. Both image mounts are read-only.
set -eu
set -o pipefail
umask 077
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
LC_ALL=C
export PATH LC_ALL

fail() { printf 'C9 ISO verification: %s\n' "$*" >&2; exit 1; }
usage() {
    echo "Usage: $0 --release-dir DIR --kernel-record DIR --project DIR --build-id ID [--kernel-build-id ID] --output NEW_DIR" >&2
    exit 2
}
release= kernel_record= project= build_id= kernel_build_id= output=
while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || usage
    case "$1" in
        --release-dir) release=$2 ;;
        --kernel-record) kernel_record=$2 ;;
        --project) project=$2 ;;
        --build-id) build_id=$2 ;;
        --kernel-build-id) kernel_build_id=$2 ;;
        --output) output=$2 ;;
        *) usage ;;
    esac
    shift 2
done
[ -n "$release" ] && [ -n "$kernel_record" ] && [ -n "$project" ] &&
    [ -n "$build_id" ] && [ -n "$output" ] || usage
[ "$(uname -s)" = FreeBSD ] && [ "$(id -u)" = 0 ] || fail 'Run as root on FreeBSD.'
for value in "$release" "$kernel_record" "$project" "$output"; do
    case "$value" in /*) ;; *) fail 'All paths must be absolute.' ;; esac
    case "$value" in *[!a-zA-Z0-9_./-]*) fail 'Use paths without whitespace or shell metacharacters.' ;; esac
done
case "$build_id" in *[!a-zA-Z0-9_.-]*|.|..) fail 'Invalid build ID.' ;; esac
# A retained kernel can accompany a newer package run; both kernels are still
# checked against its recorded hash below. Existing calls retain the old gate.
kernel_build_id=${kernel_build_id:-$build_id}
case "$kernel_build_id" in *[!a-zA-Z0-9_.-]*|.|..) fail 'Invalid kernel build ID.' ;; esac
release=$(realpath "$release")
kernel_record=$(realpath "$kernel_record")
project=$(realpath "$project")
. "$project/installer/release.conf"
parent=$(realpath "$(dirname "$output")")
[ "$(stat -f %u "$parent")" = 0 ] || fail 'Evidence parent must belong to root.'
parent_mode=$(stat -f %Lp "$parent")
[ "$((0$parent_mode & 0022))" = 0 ] || fail 'Evidence parent must not be group/world writable.'
output="$parent/$(basename "$output")"
case "$output/" in "$release/"*|"$kernel_record/"*|"$project/"*) fail 'Evidence must be separate from build inputs and outputs.' ;; esac
[ ! -e "$output" ] && [ ! -L "$output" ] || fail 'Evidence directory exists; preserve it and use a new one.'
iso="$release/C9MANGO021.iso"
inputs="$release/inputs"
[ -s "$iso" ] && [ -s "$release/SHA256" ] && [ -s "$release/SHA512" ] || fail 'Finished ISO and both checksums are required.'
[ "$(cat "$kernel_record/exit-status")" = 0 ] &&
    [ "$(cat "$kernel_record/phase")" = complete ] || fail 'Kernel preparation has not passed.'
[ "$(cat "$kernel_record/inputs/package-build-id")" = "$kernel_build_id" ] || fail 'Kernel input package build differs.'
for tool in etdump mdconfig mount_cd9660 mount_msdosfs gpart fstyp pkg tar sha256 sha512 openssl config; do
    command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done

mkdir -m 0700 "$output"
mkdir "$output/iso" "$output/esp" "$output/payload" "$output/source" "$output/repos" "$output/pkgdb" "$output/pkgcache"
iso_md= esp_md= iso_mounted=no esp_mounted=no
cleanup() {
    result=$?
    trap - EXIT HUP INT TERM
    set +e
    if [ "$esp_mounted" = yes ]; then
        umount "$output/esp" || result=1
    fi
    if [ "$iso_mounted" = yes ]; then
        umount "$output/iso" || result=1
    fi
    [ -z "$esp_md" ] || mdconfig -d -u "${esp_md#md}" || result=1
    [ -z "$iso_md" ] || mdconfig -d -u "${iso_md#md}" || result=1
    printf '%s\n' "$result" > "$output/exit-status"
    if [ "$result" -ne 0 ]; then
        printf 'FAIL: verification or read-only mount cleanup exited %s.\n' "$result" >> "$output/RESULTS.txt"
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
stage() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" | tee -a "$output/progress.log"; }
host_pkg_hash=absent
[ ! -f /var/db/pkg/local.sqlite ] || host_pkg_hash=$(sha256 -q /var/db/pkg/local.sqlite)
cp "$0" "$output/verifier.sh"
printf '%s\n' "$build_id" > "$output/package-build-id"
printf '%s\n' "$kernel_build_id" > "$output/kernel-build-id"
printf '%s\n' "$kernel_record" > "$output/kernel-record"

stage iso-checksums-and-boot-catalog
iso_hash=$(sha256 -q "$iso")
[ "$iso_hash" = "$(awk 'NF {print $NF}' "$release/SHA256")" ] || fail 'ISO SHA256 differs.'
[ "$(sha512 -q "$iso")" = "$(awk 'NF {print $NF}' "$release/SHA512")" ] || fail 'ISO SHA512 differs.'
printf '%s\n' "$iso_hash" > "$output/iso.sha256"
[ "$(dd if="$iso" bs=1 skip=510 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')" = 55aa ] || fail 'Protective MBR signature is missing.'
[ "$(dd if="$iso" bs=1 skip=512 count=8 2>/dev/null)" = 'EFI PART' ] || fail 'Primary GPT signature is missing.'
[ "$(dd if="$iso" bs=1 skip=32808 count=32 2>/dev/null | sed 's/ *$//')" = C9MANGO021 ] || fail 'ISO volume label differs.'
etdump --format shell "$iso" > "$output/el-torito.txt" 2> "$output/el-torito.stderr"
# etdump can warn about a bad catalog but still return zero.
[ ! -s "$output/el-torito.stderr" ] || fail 'El Torito catalog emitted warnings.'
awk -F '[=;]' '
    NF != 8 || $1 != "et_platform" || $3 != "et_system" || $4 != "i386" ||
    $5 != "et_lba" || $7 != "et_sectors" || $6 !~ /^[0-9]+$/ || $8 !~ /^[0-9]+$/ ||
    $6 < 1 || $8 < 1 {bad=1; next}
    $2 == "default" {bios++; next}
    $2 == "efi" {efi++; next}
    {bad=1}
    END {exit (bad || bios != 1 || efi != 1 || NR != 2)}
' "$output/el-torito.txt" || fail 'Expected one bootable BIOS entry and one bootable EFI entry.'
bios_lba=$(awk -F '[=;]' '$2 == "default" {print $6}' "$output/el-torito.txt")
efi_lba=$(awk -F '[=;]' '$2 == "efi" {print $6}' "$output/el-torito.txt")
efi_sectors=$(awk -F '[=;]' '$2 == "efi" {print $8}' "$output/el-torito.txt")
[ "$((efi_lba * 2048 + efi_sectors * 512))" -le "$(stat -f %z "$iso")" ] || fail 'EFI extent exceeds the ISO.'
iso_md=$(mdconfig -a -t vnode -f "$iso" -o readonly)
case "$iso_md" in md[0-9]*) ;; *) fail 'Unexpected ISO memory-disk name.' ;; esac
printf 'ISO %s\n' "$iso_md" > "$output/memory-disks.txt"
gpart show -p "$iso_md" > "$output/hybrid-gpt.txt"
grep -q 'freebsd-boot' "$output/hybrid-gpt.txt" && grep -q 'efi' "$output/hybrid-gpt.txt" || fail 'Hybrid GPT lacks BIOS/EFI boot partitions.'
# Poudriere writes only the primary GPT into the ISO system area. A missing
# backup GPT is recorded by gpart and is not repaired or treated as a new defect.
mount_cd9660 -o ro "/dev/$iso_md" "$output/iso"
iso_mounted=yes
live="$output/iso"
fstyp -l "/dev/$iso_md" > "$output/filesystem.txt"
bios_size=$(stat -f %z "$live/boot/cdboot")
dd if="$iso" of="$output/bios-boot.img" bs=512 skip="$((bios_lba * 4))" count="$(((bios_size + 511) / 512))" status=none
# FreeBSD 15.1 cmp -n still rejects unequal regular-file sizes after comparing
# the requested prefix. Remove sector padding from the comparison stream.
head -c "$bios_size" "$output/bios-boot.img" | cmp - "$live/boot/cdboot" || fail 'BIOS boot catalog does not point to the bundled cdboot.'
dd if="$iso" of="$output/efi.img" bs=512 skip="$((efi_lba * 4))" count="$efi_sectors" status=none
esp_md=$(mdconfig -a -t vnode -f "$output/efi.img" -o readonly)
case "$esp_md" in md[0-9]*) ;; *) fail 'Unexpected EFI memory-disk name.' ;; esac
printf 'EFI %s\n' "$esp_md" >> "$output/memory-disks.txt"
mount_msdosfs -o ro "/dev/$esp_md" "$output/esp"
esp_mounted=yes
cmp "$output/esp/EFI/BOOT/BOOTX64.EFI" "$live/boot/loader.efi" || fail 'EFI fallback loader differs from the bundled loader.'
sha256 "$live/boot/cdboot" "$live/boot/loader.efi" > "$output/boot-loaders.sha256"

stage live-image-and-installer-hooks
shared="$live/usr/local/share/c9"
[ "$(cat "$shared/build/package-build-id")" = "$build_id" ] || fail 'Image provenance names a different package build.'
[ "$(cat "$shared/packages/.buildname")" = "$build_id" ] || fail 'Bundled repository generation differs.'
[ "$(cat "$shared/packages/.jailversion")" = 15.1-RELEASE-p6 ] || fail 'Bundled repository jail revision differs.'
[ "$(cat "$shared/build/freebsd-version")" = 15.1-RELEASE-p6 ] || fail 'Recorded base revision differs.'
[ "$(cat "$shared/build/c9-version")" = 0.2.1 ] || fail 'Recorded C9 revision differs.'
[ "$(cat "$shared/build/ports-revision")" = e7bc56a5d30dc24ce2e7990926836699cbd34e55 ] || fail 'Recorded ports commit differs.'
for path in etc/rc.local etc/rc.conf boot/loader.conf usr/libexec/bsdinstall/local.post-configure usr/local/libexec/c9/install-target usr/local/libexec/c9/eligible-users.awk usr/local/libexec/c9/prepare-user-homes; do
    cmp "$project/installer/overlay/$path" "$live/$path" || fail "Installer overlay differs: $path"
done
for path in etc/rc.local usr/libexec/bsdinstall/auto usr/libexec/bsdinstall/local.post-configure usr/local/libexec/c9/install-target usr/local/libexec/c9/prepare-user-homes; do
    [ -x "$live/$path" ] || fail "Installer entry is not executable: $path"
    /bin/sh -n "$live/$path"
done
cmp "$live/usr/libexec/bsdinstall/auto.freebsd" "$shared/build/bsdinstall-auto.freebsd"
awk -f "$project/installer/patch-auto.awk" "$live/usr/libexec/bsdinstall/auto.freebsd" > "$output/auto.expected"
cmp "$output/auto.expected" "$live/usr/libexec/bsdinstall/auto" || fail 'Patched bsdinstall hooks differ.'
[ "$(readlink "$live/etc/resolv.conf")" = /tmp/bsdinstall_etc/resolv.conf ] || fail 'Live resolver symlink differs.'
awk '$1 == "/dev/iso9660/C9MANGO021" && $2 == "/" && $3 == "cd9660" && $4 == "ro" {root++}
     $1 == "tmpfs" && $2 == "/tmp" && $3 == "tmpfs" {tmp++}
     END {exit (root != 1 || tmp != 1)}' "$live/etc/fstab" || fail 'Live media mount entries differ.'
for file in C9.conf install.conf poudriere.cert; do cmp "$shared/$file" "$inputs/$file"; done
cmp "$shared/poudriere.cert" /usr/local/etc/ssl/certs/poudriere.cert || fail 'Bundled public key differs from the approved signer.'
openssl pkey -pubin -in "$shared/poudriere.cert" -noout > "$output/public-key-check.log" 2>&1
grep -q 'http://192.168.178.55/packages/c9151amd64-default-c9' "$shared/C9.conf" || fail 'Updates URL differs.'

stage installation-archives-and-exact-p6-kernel
dist="$live/usr/freebsd-dist"
cmp "$dist/MANIFEST" "$inputs/distributions/MANIFEST"
awk 'NF && ($1 != "base.txz" && $1 != "kernel.txz") {bad=1}
     $1 == "base.txz" {base++} $1 == "kernel.txz" {kernel++}
     END {exit (bad || base != 1 || kernel != 1)}' "$dist/MANIFEST" || fail 'Distribution set differs.'
for archive in base kernel; do
    expected=$(awk -v name="$archive.txz" '$1 == name {print $2}' "$dist/MANIFEST")
    [ "$(sha256 -q "$dist/$archive.txz")" = "$expected" ] || fail "Distribution checksum differs: $archive"
    cmp "$dist/$archive.txz" "$inputs/distributions/$archive.txz"
    tar -tf "$dist/$archive.txz" > "$output/$archive.members"
    awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ {bad=1} END {exit bad}' "$output/$archive.members" || fail 'Unsafe archive entry.'
    count=$(awk -v name="$archive.txz" '$1 == name {print $3}' "$dist/MANIFEST")
    [ "$(wc -l < "$output/$archive.members" | tr -d ' ')" = "$count" ] || fail 'Archive entry count differs.'
done
if grep -Eq '^\.?/?boot/kernel(/|$)' "$output/base.members"; then fail 'Base archive unexpectedly contains the kernel.'; fi
awk '$0 !~ /^\.?\/?boot\/kernel(\/|$)/ {bad=1} END {exit bad}' "$output/kernel.members" || fail 'Kernel archive contains non-kernel files.'
tar -xpf "$dist/base.txz" -C "$output/payload"
[ ! -e "$output/payload/etc/rc.local" ] || fail 'Installed payload contains the installer startup script.'
tar -xpf "$dist/kernel.txz" -C "$output/payload"
kernel_hash=$(awk 'NF {print $NF}' "$kernel_record/inputs/kernel.sha256")
for tree in "$live" "$output/payload"; do
    [ "$(sha256 -q "$tree/boot/kernel/kernel")" = "$kernel_hash" ] || fail 'Kernel differs from the reviewed source build.'
    [ "$(env ROOT="$tree" /bin/freebsd-version -k)" = 15.1-RELEASE-p6 ] || fail 'Kernel is not exactly p6.'
    [ "$(chroot "$tree" /bin/freebsd-version -u)" = 15.1-RELEASE-p6 ] || fail 'Userland is not exactly p6.'
done
/usr/sbin/config -x "$live/boot/kernel/kernel" > "$output/kernel-config"
awk '$1 == "ident" && $2 == "GENERIC" {found=1} END {exit !found}' "$output/kernel-config" || fail 'Kernel is not GENERIC.'

stage credentials-and-provenance
check_credentials() {
    checked=$1
    label=$2
    awk -F: '$1 == "root" && $3 == 0 {root++}
        $3 >= 1000 && $3 < 65534 {bad=1}
        $2 != "" && $2 != "*" && $2 != "!" {bad=1}
        END {exit (bad || root != 1)}' "$checked/etc/master.passwd" || fail "$label contains human accounts or password credentials."
    # Also reject stale passwd databases containing accounts absent from the
    # checked text file. Record identities only, never password fields.
    awk -F: '{print $1 ":" $3 ":" $4 ":" $9 ":" $10}' "$checked/etc/master.passwd" | sort > "$output/$label-users.expected"
    chroot "$checked" /usr/bin/getent passwd | awk -F: '
        $2 != "" && $2 != "*" && $2 != "!" {bad=1}
        {print $1 ":" $3 ":" $4 ":" $6 ":" $7}
        END {exit bad}' | sort > "$output/$label-users.actual" || fail "$label passwd database contains a password credential or cannot be read."
    cmp "$output/$label-users.expected" "$output/$label-users.actual" || fail "$label passwd database differs from checked accounts."
    for path in root/.ssh etc/hostid boot/entropy var/db/hostid var/db/entropy var/db/pkg/local.sqlite; do
        [ ! -e "$checked/$path" ] && [ ! -L "$checked/$path" ] || fail "$label contains excluded machine state: $path"
    done
    : > "$output/$label-sensitive-files.txt"
    : > "$output/$label-private-key-files.txt"
    for subtree in etc root home usr/home usr/local/etc; do
        [ -d "$checked/$subtree" ] && [ ! -L "$checked/$subtree" ] || continue
        find "$checked/$subtree" -xdev \( -name '.ssh' -o -name '.aws' -o -name '.gnupg' -o -name '.netrc' -o -name '.git-credentials' -o -name '.pgpass' -o -name 'ssh_host_*' -o -name 'poudriere.key' \) -print >> "$output/$label-sensitive-files.txt"
        find "$checked/$subtree" -xdev -type f -exec /bin/sh -c '
            grep -IlE "^-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----" "$@"
            result=$?
            case "$result" in 0|1) exit 0 ;; *) exit "$result" ;; esac
        ' c9-key-scan {} + >> "$output/$label-private-key-files.txt" || fail "$label private-key scan failed."
    done
    [ ! -s "$output/$label-sensitive-files.txt" ] && [ ! -s "$output/$label-private-key-files.txt" ] || fail "$label contains a credential path or private-key header; inspect the filenames, not secrets."
    sha256 "$checked/etc/master.passwd" "$checked/etc/pwd.db" "$checked/etc/spwd.db" > "$output/$label-account-files.sha256"
}
check_credentials "$live" live
check_credentials "$output/payload" payload
cmp "$shared/build/project-source.tar.xz" "$inputs/build/project-source.tar.xz"
tar -tf "$shared/build/project-source.tar.xz" > "$output/source.members"
awk '$0 ~ /^\// || $0 ~ /(^|\/)\.\.(\/|$)/ {bad=1} END {exit bad}' "$output/source.members" || fail 'Unsafe source archive entry.'
tar -xpf "$shared/build/project-source.tar.xz" -C "$output/source"
find "$output/source" \( -name '.ssh' -o -name '.aws' -o -name '.gnupg' -o -name '.netrc' -o -name '.git-credentials' -o -name '.pgpass' -o -name 'ssh_host_*' -o -name 'poudriere.key' \) -print > "$output/source-sensitive-files.txt"
[ ! -s "$output/source-sensitive-files.txt" ] || fail 'Bundled project source contains a credential path.'
find "$output/source" -type f -exec /bin/sh -c '
    grep -IlE "^-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----" "$@"
    result=$?
    case "$result" in 0|1) exit 0 ;; *) exit "$result" ;; esac
' c9-key-scan {} + > "$output/source-private-key-files.txt" || fail 'Source private-key scan failed.'
[ ! -s "$output/source-private-key-files.txt" ] || fail 'Bundled project source contains a private-key header.'

stage signed-bundled-packages-and-combined-install-plan
cat > "$output/repos/C9ISO.conf" <<EOF
C9ISO: {
  url: "file://$shared/packages",
  enabled: yes,
  signature_type: "pubkey",
  pubkey: "$shared/poudriere.cert"
}
EOF
repo_pkg() {
    pkg -C /dev/null -o REPOS_DIR="$output/repos" -o PKG_DBDIR="$output/pkgdb" \
        -o PKG_CACHEDIR="$output/pkgcache" -o ABI=FreeBSD:15:amd64 \
        -o OSVERSION=1501000 -o PKG_ENABLE_PLUGINS=no "$@"
}
repo_pkg update -f > "$output/catalog.log" 2>&1
repo_pkg rquery -U -r C9ISO '%n|%v|%o' > "$output/package-inventory.txt"
awk -F '|' '$1 ~ /^c9-/' "$output/package-inventory.txt" | sort > "$output/c9-actual.txt"
cat > "$output/c9-expected.txt" <<'EOF'
c9-apps-development|0.2.1|devel/c9-apps-development
c9-apps-essential|0.2.1|misc/c9-apps-essential
c9-apps-office|0.2.1|editors/c9-apps-office
c9-artwork|0.2.1|x11-themes/c9-artwork
c9-desktop-defaults|0.2.1|x11/c9-desktop-defaults
c9-desktop-mango|0.2.1|x11/c9-desktop-mango
c9-hardware-intel|0.2.1|sysutils/c9-hardware-intel
c9-hardware-virtualbox|0.2.1|emulators/c9-hardware-virtualbox
c9-system-config|0.2.1|sysutils/c9-system-config
c9-workstation|0.2.1|x11/c9-workstation
EOF
cmp "$output/c9-expected.txt" "$output/c9-actual.txt" || fail 'The ten C9 package identities/versions differ.'
grep -Fqx 'rio-terminal-emulator|0.5.30|x11/rio' "$output/package-inventory.txt" ||
    fail 'The pinned Rio terminal package is missing or differs.'
required="pkg $(cut -d '|' -f 1 "$output/c9-expected.txt" | tr '\n' ' ')"
# A file:// repository validates archives in place. No host package is installed.
repo_pkg fetch -d -y -r C9ISO $required > "$output/fetch.log" 2>&1
repo_pkg install -n -y -U -r C9ISO $required > "$output/install-plan.txt" 2>&1
case ${C9_EXPECTED_INSTALL_PACKAGE_COUNT:-unreviewed} in
    ''|*[!0-9]*|0) fail "C9 0.2.1 dependency count is not reviewed. Inspect $output/install-plan.txt and record a reviewed positive C9_EXPECTED_INSTALL_PACKAGE_COUNT before release acceptance." ;;
esac
[ "$C9_EXPECTED_INSTALL_PACKAGE_COUNT" -gt 0 ] || fail 'Expected install count must be positive.'
grep -qx "Number of packages to be installed: $C9_EXPECTED_INSTALL_PACKAGE_COUNT" "$output/install-plan.txt" ||
    fail 'Combined install plan differs from the reviewed release count.'
pkg_name=$(repo_pkg rquery -U -r C9ISO '%n-%v' pkg)
pkg_archive="$shared/packages/All/$pkg_name.pkg"
pkg_member=$(tar -tf "$pkg_archive" | awk '$0 == "/usr/local/sbin/pkg-static" || $0 == "usr/local/sbin/pkg-static" || $0 == "./usr/local/sbin/pkg-static" {print}')
[ -n "$pkg_member" ] || fail 'Verified pkg archive lacks pkg-static.'
tar -xOf "$pkg_archive" "$pkg_member" > "$output/pkg-static.reference"
cmp "$output/pkg-static.reference" "$live/usr/local/libexec/c9/pkg-static" || fail 'Installer bootstrap differs from the signed package.'
after_pkg_hash=absent
[ ! -f /var/db/pkg/local.sqlite ] || after_pkg_hash=$(sha256 -q /var/db/pkg/local.sqlite)
[ "$after_pkg_hash" = "$host_pkg_hash" ] || fail 'Host installed-package database changed during verification.'
[ "$(sha256 -q "$iso")" = "$iso_hash" ] || fail 'ISO changed during verification.'
stage complete
printf '%s\n' 'PASS: ISO structure, BIOS/EFI loaders, exact p6 GENERIC/base payload, installer hooks, credential checks, ten C9 packages, signed dependency closure and combined dry-run install.' > "$output/RESULTS.txt"
printf '%s\n' 'Limits: static artifact checks only; firmware boot, disk installation, authentication and SDDM require the separately authorized VM tests. Private-key scans cover configuration/home/provenance trees, not vendor package test fixtures.' >> "$output/RESULTS.txt"
cat "$output/RESULTS.txt"
