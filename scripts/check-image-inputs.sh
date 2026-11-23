#!/bin/sh
# Read-only preflight for reusing a prepared image jail and saved distributions.
set -eu
set -o pipefail
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
LC_ALL=C
export PATH LC_ALL

fail() { printf 'C9 image inputs: %s\n' "$*" >&2; exit 1; }
usage() {
    echo "Usage: $0 --kernel-record DIR --payload DIR --kernel-build-id ID" >&2
    exit 2
}
kernel_record= payload= kernel_build_id=
while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || usage
    case "$1" in
        --kernel-record) kernel_record=$2 ;;
        --payload) payload=$2 ;;
        --kernel-build-id) kernel_build_id=$2 ;;
        *) usage ;;
    esac
    shift 2
done
[ -n "$kernel_record" ] && [ -n "$payload" ] && [ -n "$kernel_build_id" ] || usage
case "$kernel_build_id" in *[!a-zA-Z0-9_.-]*|.|..) fail 'Invalid kernel build ID.' ;; esac
[ "$(uname -s)" = FreeBSD ] && [ "$(id -u)" = 0 ] || fail 'Run as root on FreeBSD.'
for tool in realpath stat sha256 awk tar chroot config jls; do
    command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done

# Reject symlink aliases and writable ancestors before reading trusted inputs.
check_directory() {
    local path current mode
    path=$1
    case "$path" in /*) ;; *) fail "Path must be absolute: $path" ;; esac
    case "$path" in *[!a-zA-Z0-9_./-]*) fail "Unsafe input path: $path" ;; esac
    [ -d "$path" ] && [ ! -L "$path" ] || fail "Not a real directory: $path"
    [ "$(realpath "$path")" = "$path" ] || fail "Use a canonical path without symlinks: $path"
    current=$path
    while :; do
        [ ! -L "$current" ] && [ "$(stat -f %u "$current")" = 0 ] ||
            fail "Input ancestor is not controlled by root: $current"
        mode=$(stat -f %Lp "$current")
        [ "$((0$mode & 0022))" = 0 ] || fail "Input ancestor is writable by group/others: $current"
        [ "$current" = / ] && break
        current=${current%/*}
        [ -n "$current" ] || current=/
    done
}
check_file() {
    local path mode
    path=$1
    check_directory "$(dirname "$path")"
    [ -f "$path" ] && [ ! -L "$path" ] || fail "Not a regular input file: $path"
    [ "$(stat -f %u "$path")" = 0 ] || fail "Input file is not owned by root: $path"
    mode=$(stat -f %Lp "$path")
    [ "$((0$mode & 0022))" = 0 ] || fail "Input file is writable by group/others: $path"
}
assert_idle() {
    local active_names
    active_names=$(jls -n name) || fail 'Cannot inspect active jails.'
    if printf '%s\n' "$active_names" | awk -v jail="$C9_IMAGE_JAIL" '
        {for (i=1; i<=NF; i++) if (index($i, "name=") == 1) {
            name=substr($i, 6)
            if (name == jail || index(name, jail "-") == 1) active=1
        }}
        END {exit !active}'; then
        fail 'The configured image jail is active.'
    fi
}

project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
check_file "$project/installer/release.conf"
. "$project/installer/release.conf"
[ "$(uname -m)" = "$C9_ARCH" ] || fail 'Host architecture differs from release.conf.'
case "$C9_IMAGE_JAIL" in ''|.|..|*[!a-zA-Z0-9_.-]*) fail 'Invalid configured image jail name.' ;; esac
check_directory "$kernel_record"
check_directory "$payload"
for file in phase exit-status inputs/package-build-id inputs/kernel.sha256 inputs/kernel-version inputs/kernel-config; do
    check_file "$kernel_record/$file"
done
[ "$(cat "$kernel_record/phase")" = complete ] &&
    [ "$(cat "$kernel_record/exit-status")" = 0 ] || fail 'Kernel preparation did not complete successfully.'
[ "$(cat "$kernel_record/inputs/package-build-id")" = "$kernel_build_id" ] ||
    fail 'Kernel record names a different historical package build.'
[ "$(cat "$kernel_record/inputs/kernel-version")" = "$C9_EXPECTED_VERSION" ] ||
    fail 'Recorded kernel version differs from release.conf.'
awk '$1 == "ident" && $2 == "GENERIC" {found=1} END {exit !found}' \
    "$kernel_record/inputs/kernel-config" || fail 'Recorded kernel configuration is not GENERIC.'
kernel_hash=$(awk '
    NF {
        if (++n != 1 || $1 != "SHA256" || $(NF-1) != "=" ||
            length($NF) != 64 || $NF ~ /[^0-9a-f]/) bad=1
        digest=$NF
    }
    END {if (bad || n != 1) exit 1; print digest}
' "$kernel_record/inputs/kernel.sha256") || fail 'Malformed recorded kernel hash.'

metadata="/usr/local/etc/poudriere.d/jails/$C9_IMAGE_JAIL"
for file in arch version mnt method; do check_file "$metadata/$file"; done
[ "$(cat "$metadata/arch")" = "$C9_ARCH" ] || fail 'Image jail architecture differs.'
[ "$(cat "$metadata/version")" = "$C9_EXPECTED_VERSION" ] || fail 'Image jail metadata version differs.'
[ "$(cat "$metadata/method")" = tar ] || fail 'Image jail is not the retained tar import.'
image_root=$(cat "$metadata/mnt")
check_directory "$image_root"
[ "$image_root" != / ] || fail 'Image jail cannot be the host root.'
assert_idle
check_file "$image_root/boot/kernel/kernel"
[ "$(chroot "$image_root" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] ||
    fail 'Image jail userland version differs.'
[ "$(chroot "$image_root" /usr/bin/uname -U)" = "$C9_OSVERSION" ] ||
    fail 'Image jail numeric userland version differs.'
[ "$(env ROOT="$image_root" /bin/freebsd-version -k)" = "$C9_EXPECTED_VERSION" ] ||
    fail 'Image jail kernel version differs.'
[ "$(sha256 -q "$image_root/boot/kernel/kernel")" = "$kernel_hash" ] ||
    fail 'Image jail kernel differs from the retained source build.'
config -x "$image_root/boot/kernel/kernel" |
    awk '$1 == "ident" && $2 == "GENERIC" {found=1} END {exit !found}' ||
    fail 'Image jail kernel does not identify GENERIC.'

for file in freebsd-version MANIFEST base.txz kernel.txz; do check_file "$payload/$file"; done
[ "$(cat "$payload/freebsd-version")" = "$C9_EXPECTED_VERSION" ] ||
    fail 'Saved payload version differs.'
awk '
    NF {
        if (($1 != "base.txz" && $1 != "kernel.txz") || ++seen[$1] != 1 ||
            length($2) != 64 || $2 ~ /[^0-9a-f]/ || $3 !~ /^[0-9]+$/ || $3 < 1) bad=1
    }
    END {exit (bad || seen["base.txz"] != 1 || seen["kernel.txz"] != 1)}
' "$payload/MANIFEST" || fail 'Saved payload manifest is malformed.'
for archive in base kernel; do
    expected=$(awk -v name="$archive.txz" '$1 == name {print $2}' "$payload/MANIFEST")
    [ "$(sha256 -q "$payload/$archive.txz")" = "$expected" ] ||
        fail "Saved $archive archive hash differs."
done
kernel_member=$(tar -tf "$payload/kernel.txz" | awk '
    $0 !~ /^(\.\/)?boot\/kernel(\/|$)/ || $0 ~ /(^|\/)\.\.(\/|$)/ {bad=1}
    $0 == "./boot/kernel/kernel" || $0 == "boot/kernel/kernel" {member=$0; count++}
    END {if (bad || count != 1) exit 1; print member}
') || fail 'Kernel archive lacks one unambiguous kernel member or contains unexpected paths.'
payload_kernel_hash=$(tar -xOf "$payload/kernel.txz" "$kernel_member" | sha256 -q) ||
    fail 'Cannot read the archived kernel.'
[ "$payload_kernel_hash" = "$kernel_hash" ] || fail 'Archived kernel differs from the retained source build.'
assert_idle
printf 'Verified reusable image inputs.\nImage jail: %s\nKernel build ID: %s\nKernel record: %s\nPayload: %s\nKernel SHA256: %s\n' \
    "$C9_IMAGE_JAIL" "$kernel_build_id" "$kernel_record" "$payload" "$kernel_hash"
