#!/bin/sh
# Prepare the exact C9 image input after the entire package release passes.
# The source package jail is read only throughout; all builds use private paths.
set -eu
set -o pipefail
umask 077
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
export PATH

fail() { printf 'C9 image jail: %s\n' "$*" >&2; exit 1; }
usage() { echo "Usage: $0 --build-id ID --output NEW_ABSOLUTE_DIRECTORY" >&2; exit 2; }
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$project/installer/release.conf"
build_id= output=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-id) [ "$#" -ge 2 ] || usage; build_id=$2; shift 2 ;;
        --output) [ "$#" -ge 2 ] || usage; output=$2; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$build_id" ] && [ -n "$output" ] || usage
case "$build_id" in *[!a-zA-Z0-9_.-]*|.|..) fail 'Invalid build ID.' ;; esac
# FreeBSD's kernel makefiles and Poudriere contain unquoted build paths.
case "$output" in /*) ;; *) fail 'Output must be absolute.' ;; esac
case "$output" in *[!a-zA-Z0-9_./-]*) fail 'Output path may contain only letters, digits, underscores, dots, slashes and hyphens.' ;; esac
[ "$(uname -s)" = FreeBSD ] && [ "$(uname -m)" = amd64 ] || fail 'Run on FreeBSD amd64.'
[ "$(id -u)" -eq 0 ] || fail 'Run with doas/root.'
[ "$C9_RELEASE/$C9_EXPECTED_VERSION/$C9_ARCH" = 15.1-RELEASE/15.1-RELEASE-p6/amd64 ] || fail 'This authenticated input recipe is specific to FreeBSD 15.1-RELEASE-p6 amd64.'
for tool in poudriere fetch openssl sha256 base64 awk mtree make tar stat realpath jls config; do
    command -v "$tool" >/dev/null || fail "Required tool is missing: $tool"
done
[ ! -e "$output" ] && [ ! -L "$output" ] || fail 'Output exists; preserve it and choose a new directory.'
parent=$(realpath "$(dirname -- "$output")")
[ "$(stat -f %u "$parent")" = 0 ] || fail 'Output parent must be owned by root.'
parent_mode=$(stat -f %Lp "$parent")
[ "$((0$parent_mode & 0022))" -eq 0 ] || fail 'Output parent must not be writable by group or others.'
output="$parent/$(basename -- "$output")"
metadata=/usr/local/etc/poudriere.d/jails
[ ! -e "$metadata/$C9_IMAGE_JAIL" ] && [ ! -L "$metadata/$C9_IMAGE_JAIL" ] || fail 'The image jail already exists; inspect or use it instead of replacing it.'
[ -d "$metadata/$C9_PACKAGE_JAIL" ] || fail 'The approved package jail is missing.'
[ "$(cat "$metadata/$C9_PACKAGE_JAIL/version")" = "$C9_EXPECTED_VERSION" ] || fail 'Package jail revision differs.'
[ "$(cat "$metadata/$C9_PACKAGE_JAIL/arch")" = "$C9_ARCH" ] || fail 'Package jail architecture differs.'
source_root=$(realpath "$(cat "$metadata/$C9_PACKAGE_JAIL/mnt")")
[ "$source_root" != / ] || fail 'Invalid package jail mountpoint.'
case "$output/" in "$source_root/"*|"$project/"*) fail 'Output must be outside the source jail and project.' ;; esac
case "$output/" in /usr/local/poudriere/*|/usr/local/etc/poudriere.d/*) fail 'Output must be outside Poudriere managed storage.' ;; esac
case "$source_root" in *[!a-zA-Z0-9_./-]*) fail 'Unsupported package jail path.' ;; esac
assert_idle() {
    [ -z "$(jls -n name)" ] || fail 'A jail is active. Wait for all package jobs and other jails to stop.'
}
assert_idle
[ "$(chroot "$source_root" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] || fail 'Package jail userland differs.'
[ -f "$source_root/usr/src/sys/conf/newvers.sh" ] || fail 'Retained source is missing.'
[ ! -e "$source_root/var/db/pkg/local.sqlite" ] || fail 'Package jail contains an installed package database.'
[ -z "$(find "$source_root/usr/local" -mindepth 1 -maxdepth 1 -print)" ] || fail 'Package jail /usr/local is not empty.'
clean_accounts() {
    awk -F: '$3 >= 1000 && $3 < 65534 {exit 1} $1 == "root" && $2 != "" && $2 != "*" {exit 1}' \
        "$1/etc/master.passwd" || fail 'Base contains personal accounts or a root password.'
}
clean_accounts "$source_root"

mkdir -m 0700 "$output"
work="$output/work"
inputs="$output/inputs"
logs="$output/logs"
mkdir -m 0700 "$work" "$inputs" "$logs" "$inputs/authentication"
proof="$inputs/authentication"
phase() {
    printf '%s\n' "$1" > "$output/phase"
    printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" | tee -a "$output/progress.log"
}
finish() {
    result=$?
    trap - EXIT
    printf '%s\n' "$result" > "$output/exit-status"
    [ "$result" -eq 0 ] || phase "failed (see $logs)"
    exit "$result"
}
trap finish EXIT
trap 'exit 1' HUP INT TERM
run_logged() {
    stage=$1; shift
    phase "$stage"
    printf '%s\n' "$@" > "$logs/$stage.argv"
    "$@" > "$logs/$stage.log" 2>&1 || fail "$stage failed; see $logs/$stage.log"
}

# No kernel build, clone, or jail creation may precede this complete release gate.
run_logged verify-packages sh "$project/scripts/c9-build.sh" verify "$build_id"
assert_idle
printf '%s\n' "$build_id" > "$inputs/package-build-id"
cp "$project/installer/release.conf" "$inputs/release.conf"
cp "$0" "$inputs/prepare-image-jail.sh"
cp "$project/scripts/image-jail-inputs/source-mtree.awk" "$inputs/source-mtree.awk"
poudriere version > "$inputs/poudriere-version"
uname -a > "$inputs/build-host"
freebsd-version -ku > "$inputs/build-host-freebsd-version"
cc --version > "$inputs/build-compiler"
sha256 /usr/bin/cc /usr/bin/make /bin/sh > "$inputs/build-tools.sha256"
df -h "$output" > "$inputs/space-before"

phase authenticate-p6-inputs
# FreeBSD update's original p6 signature is not retained by its client. The
# trusted retained p6 tINDEX digest pins the selected historical snapshot.
# Every selected record must also occur in metadata covered by the separately
# saved, verified p7 signature. We never claim that signature signs the p6 tag.
update_url=http://update.FreeBSD.org/15.1-RELEASE/amd64
key_hash=800651ef4b4c71c27e60786d7b487188970f4b4169cc055784e21eb71d410cc5
p6_index=1fc17b79f0042220dbc07818727e8a0793374c903896977e09a3ad53bf7f916b
p7_index=752e9d7c9175624437c3ec972beced364461e94b39c9c5cd4a20d9a14c794f26
printf 'freebsd-update|amd64|15.1-RELEASE|6|%s|1806537600\n' "$p6_index" > "$proof/p6-retained-tag"
printf 'freebsd-update|amd64|15.1-RELEASE|7|%s|1806537600\n' "$p7_index" > "$proof/p7-expected-tag"
fetch -T 60 -q -o "$proof/pub.ssl" "$update_url/pub.ssl"
[ "$(sha256 -q "$proof/pub.ssl")" = "$key_hash" ] || fail 'FreeBSD update public key fingerprint differs.'
base64 -d < "$project/scripts/image-jail-inputs/p7-signature.b64" > "$proof/p7-signature.ssl"
openssl pkeyutl -pubin -inkey "$proof/pub.ssl" -verifyrecover \
    < "$proof/p7-signature.ssl" > "$proof/p7-verified-tag"
cmp "$proof/p7-expected-tag" "$proof/p7-verified-tag" || fail 'Saved FreeBSD update signature differs.'
for version in p6 p7; do
    case "$version" in p6) digest=$p6_index ;; p7) digest=$p7_index ;; esac
    fetch -T 60 -q -o "$proof/$version-tINDEX" "$update_url/t/$digest"
    [ "$(sha256 -q "$proof/$version-tINDEX")" = "$digest" ] || fail 'Update index checksum mismatch.'
    for item in INDEX-ALL INDEX-NEW INDEX-OLD; do
        digest=$(awk -F '|' -v item="$item" '$1 == item {print $2}' "$proof/$version-tINDEX")
        [ "${#digest}" -eq 64 ] || fail 'Missing or duplicated update metadata digest.'
        case "$digest" in *[!0-9a-f]*) fail 'Invalid update metadata digest.' ;; esac
        fetch -T 60 -q -o "$proof/$version-$item.gz" "$update_url/m/$digest.gz"
        gunzip -c "$proof/$version-$item.gz" > "$proof/$version-$item"
        [ "$(sha256 -q "$proof/$version-$item")" = "$digest" ] || fail 'Update metadata checksum mismatch.'
    done
done
cat "$proof/p7-INDEX-ALL" "$proof/p7-INDEX-NEW" "$proof/p7-INDEX-OLD" | LC_ALL=C sort -u > "$work/authenticated-p7-records"
LC_ALL=C sort -u "$proof/p6-INDEX-ALL" > "$work/selected-p6-records"
LC_ALL=C comm -23 "$work/selected-p6-records" "$work/authenticated-p7-records" > "$proof/p6-uncovered-records"
[ ! -s "$proof/p6-uncovered-records" ] || fail 'Historical records lack coverage by the saved signed metadata.'
printf '%s\n' 'PASS: saved p7 signature/hash chain and complete retained-p6 record coverage.' > "$proof/verification.txt"

phase snapshot-and-verify-source
assert_idle
src="$work/src"
obj="$work/obj"
world="$work/world"
mkdir -m 0755 "$src" "$obj" "$world" "$work/tmp"
# A true copy, never hard links into Poudriere's source tree.
tar -cf "$work/source-copy.tar" -C "$source_root/usr/src" .
tar -xpf "$work/source-copy.tar" -C "$src"
rm "$work/source-copy.tar"
LC_ALL=C sort -t '|' -k3,3 "$proof/p6-INDEX-ALL" | \
    awk -f "$inputs/source-mtree.awk" > "$inputs/source-p6.mtree"
verify_source() {
    checked_source=$1
    check_log=$2
    mtree -f "$inputs/source-p6.mtree" -p "$checked_source" > "$check_log" 2>&1 || fail "Source inventory/hash mismatch; see $check_log"
    # mtree reports extra entries but may return zero for them.
    [ ! -s "$check_log" ] || fail "Unexpected source entries; see $check_log"
    # ZFS automatically sets UF_ARCHIVE (2048). No other unrecorded file flags
    # are accepted; the authenticated source records themselves all have zero.
    find "$checked_source" -xdev -exec stat -f %f {} + | \
        awk '$1 != 0 && $1 != 2048 {bad=1} END {exit bad}' || fail 'Unexpected source file flags.'
}
verify_source "$src" "$logs/source-before-build.log"
grep -q '^REVISION="15.1"$' "$src/sys/conf/newvers.sh" || fail 'Source release differs.'
grep -q '^BRANCH="RELEASE-p6"$' "$src/sys/conf/newvers.sh" || fail 'Source patch level differs.'
[ -f "$src/sys/amd64/conf/GENERIC" ] || fail 'Standard GENERIC configuration is missing.'
env XZ_OPT=-T1 tar -cJpf "$inputs/source-p6.tar.xz" -C "$src" .
sha256 "$inputs/source-p6.tar.xz" > "$inputs/source-p6.sha256"

phase snapshot-clean-p6-base
assert_idle
# Keep the source and build configuration out of the base copy. The verified
# source is added back only after compilation, for Poudriere image's use.
tar -cf "$work/base-copy.tar" -X "$project/installer/image.exclude" \
    --exclude '.poudriere*' --exclude './boot/kernel' --exclude './dev/*' \
    --exclude './tmp/*' --exclude './var/tmp/*' --exclude './var/cache/*' \
    --exclude './var/log/*' -C "$source_root" .
tar -xpf "$work/base-copy.tar" -C "$world"
rm "$work/base-copy.tar"
clean_accounts "$world"
[ ! -d "$world/root/.ssh" ] || fail 'Copied base contains an SSH identity.'
[ ! -e "$world/var/db/pkg/local.sqlite" ] || fail 'Copied base contains installed packages.'
if find "$world/etc/ssh" -name 'ssh_host_*' | grep . >/dev/null; then
    fail 'Copied base contains SSH host keys.'
fi
if [ -f "$world/etc/login.conf.orig" ]; then
    mv "$world/etc/login.conf.orig" "$world/etc/login.conf"
fi
cap_mkdb "$world/etc/login.conf"
pwd_mkdb -d "$world/etc" -p "$world/etc/master.passwd"
: > "$world/etc/fstab"
: > "$world/etc/rc.conf"
: > "$world/etc/resolv.conf"
[ ! -e "$world/etc/rc.local" ] || fail 'Copied base contains a custom startup script.'
mkdir -p "$world/tmp" "$world/var/tmp" "$world/dev" "$world/mnt"
chmod 1777 "$world/tmp" "$world/var/tmp"
[ "$(chroot "$world" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] || fail 'Copied base is not the approved p6 userland.'
env XZ_OPT=-T1 tar -cJpf "$inputs/base-p6.tar.xz" -C "$world" .
sha256 "$inputs/base-p6.tar.xz" > "$inputs/base-p6.sha256"

# Isolated source, object directory and destination; no host world/kernel is
# copied. The complete standard GENERIC kernel and its modules are built.
assert_idle
kernel_make() {
    build_stage=$1
    shift
    run_logged "$build_stage" env -i PATH="$PATH" LC_ALL=C TZ=UTC \
        TMPDIR="$work/tmp" MAKEOBJDIRPREFIX="$obj" /usr/bin/make -C "$src" -j2 \
        SRCCONF=/dev/null SRC_ENV_CONF=/dev/null __MAKE_CONF=/dev/null \
        TARGET=amd64 TARGET_ARCH=amd64 KERNCONF=GENERIC WITHOUT_LOCAL_MODULES=yes "$@"
}
kernel_make kernel-toolchain kernel-toolchain
kernel_make buildkernel buildkernel
kernel_make installkernel DESTDIR="$world" installkernel
phase verify-built-kernel
verify_source "$src" "$logs/source-after-build.log"
[ "$(env ROOT="$world" /bin/freebsd-version -k)" = "$C9_EXPECTED_VERSION" ] || fail 'Built GENERIC kernel is not exactly p6.'
[ "$(chroot "$world" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] || fail 'Userland changed during kernel build.'
sha256 "$world/boot/kernel/kernel" > "$inputs/kernel.sha256"
env ROOT="$world" /bin/freebsd-version -k > "$inputs/kernel-version"
/usr/sbin/config -x "$world/boot/kernel/kernel" > "$inputs/kernel-config"
awk '$1 == "ident" && $2 == "GENERIC" {found=1} END {exit !found}' "$inputs/kernel-config" || fail 'Built kernel does not identify standard GENERIC.'
mkdir -p "$world/usr/src"
tar -xpf "$inputs/source-p6.tar.xz" -C "$world/usr/src"
verify_source "$world/usr/src" "$logs/source-in-image-input.log"
for path in etc/hostid boot/entropy var/db/hostid var/db/entropy; do
    [ ! -e "$world/$path" ] || fail "Image input contains machine identity: $path"
done
clean_accounts "$world"
env XZ_OPT=-T1 tar -cJpf "$inputs/image-jail.tar.xz" -C "$world" .
sha256 "$inputs/image-jail.tar.xz" > "$inputs/image-jail.sha256"
(cd "$proof" && find . -type f -print | LC_ALL=C sort | xargs sha256) > "$inputs/authentication.sha256"

# tar import does not apply later updates. Check again immediately before the
# sole operation that registers a jail; an existing jail is never replaced.
assert_idle
[ ! -e "$metadata/$C9_IMAGE_JAIL" ] && [ ! -L "$metadata/$C9_IMAGE_JAIL" ] || fail 'Image jail appeared during preparation; preserved without replacement.'
run_logged import-image-jail poudriere jail -c -j "$C9_IMAGE_JAIL" \
    -v "$C9_EXPECTED_VERSION" -a "$C9_ARCH" -K GENERIC \
    -m "tar=$inputs/image-jail.tar.xz"
image_root=$(realpath "$(cat "$metadata/$C9_IMAGE_JAIL/mnt")")
[ "$image_root" != / ] && [ "$image_root" != "$source_root" ] || fail 'Invalid imported image jail path.'
[ "$(cat "$metadata/$C9_IMAGE_JAIL/version")" = "$C9_EXPECTED_VERSION" ] || fail 'Imported jail metadata differs.'
[ "$(cat "$metadata/$C9_IMAGE_JAIL/arch")" = "$C9_ARCH" ] || fail 'Imported jail architecture differs.'
[ "$(cat "$metadata/$C9_IMAGE_JAIL/method")" = tar ] || fail 'Imported jail method differs.'
[ "$(chroot "$image_root" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] || fail 'Imported userland differs.'
[ "$(env ROOT="$image_root" /bin/freebsd-version -k)" = "$C9_EXPECTED_VERSION" ] || fail 'Imported kernel differs.'
[ "$(sha256 -q "$image_root/boot/kernel/kernel")" = "$(sha256 -q "$world/boot/kernel/kernel")" ] || fail 'Imported kernel hash differs.'
verify_source "$image_root/usr/src" "$logs/source-after-import.log"
clean_accounts "$image_root"
cp -Rp "$metadata/$C9_IMAGE_JAIL" "$inputs/jail-registration"
phase complete
printf 'Prepared %s with exact p6 userland, source and GENERIC kernel.\nKeep %s and its build logs. No ISO was created.\n' "$C9_IMAGE_JAIL" "$inputs"
