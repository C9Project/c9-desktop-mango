#!/bin/sh
# Build the C9 installer on FreeBSD. Run only after the named bulk build ends.
set -eu
set -o pipefail
umask 022

fail() { echo "C9 image: $*" >&2; exit 1; }
# Emit one literal POSIX-shell word. In particular, an apostrophe in an output
# path must not terminate the generated customization script's quoted value.
shell_quote() {
    quote_tail=$1
    printf "'"
    while :; do
        case "$quote_tail" in
            *"'"*)
                quote_head=${quote_tail%%"'"*}
                printf '%s' "$quote_head" "'\\''"
                quote_tail=${quote_tail#*"'"}
                ;;
            *) printf "%s'" "$quote_tail"; break ;;
        esac
    done
}
emit_post_script() {
    printf '#!/bin/sh\nC9_IMAGE_INPUT='
    shell_quote "$input"
    printf '\nC9_PROJECT_ROOT='
    shell_quote "$project"
    printf '\n. '
    shell_quote "$project/installer/customize-image.sh"
    printf '\n'
}
usage() {
    echo "Usage: $0 --build-id ID --output NEW_ABSOLUTE_DIRECTORY [--payload SAVED_DISTRIBUTIONS_DIRECTORY]" >&2
    exit 2
}
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$project/installer/release.conf"
for hardware in $C9_HARDWARE_PROFILES; do
    case "$hardware" in virtualbox|intel) ;; *) fail 'Unknown hardware profile in release.conf.' ;; esac
    C9_REQUIRED_PACKAGES="$C9_REQUIRED_PACKAGES c9-hardware-$hardware"
done
release_packages=$(awk '{sub(/#.*/, ""); if (NF) {n=split($1, parts, "/"); print parts[n]}}' \
    "$project/poudriere/c9-release.list")
for package in $release_packages; do
    case "$package" in c9-*) C9_REQUIRED_PACKAGES="$C9_REQUIRED_PACKAGES $package" ;; *) fail 'Unexpected non-C9 origin in release list.' ;; esac
done
build_id= output= reuse_payload=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-id) [ "$#" -ge 2 ] || usage; build_id=$2; shift 2 ;;
        --output) [ "$#" -ge 2 ] || usage; output=$2; shift 2 ;;
        --payload) [ "$#" -ge 2 ] || usage; reuse_payload=$2; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$build_id" ] && [ -n "$output" ] || usage
case "$build_id" in *[!a-zA-Z0-9_.-]*|.|..) fail 'Invalid build ID.' ;; esac
case "$output" in /*) ;; *) fail 'Output must be an absolute path.' ;; esac
[ "$(uname -s)" = FreeBSD ] && [ "$(uname -m)" = "$C9_ARCH" ] || fail 'Run on FreeBSD amd64.'
[ "$(id -u)" -eq 0 ] || fail 'Run with doas/root.'
[ ! -e "$output" ] || fail 'Output already exists; choose a new directory to preserve prior artifacts.'
for tool in poudriere pkg tar sha256 awk realpath git; do
    command -v "$tool" >/dev/null || fail "Required tool is missing: $tool"
done

data=/usr/local/poudriere/data
logs="$data/logs/bulk/$C9_MASTER/$build_id"
[ -d "$logs" ] || fail "No logs for requested build: $logs"
case "$(cat "$logs/.poudriere.status")" in
    done:|stopped:done:) ;;
    *) fail 'Requested package build has not completed successfully.' ;;
esac
for statistic in failed skipped ignored; do
    [ "$(cat "$logs/.poudriere.stats_$statistic")" = 0 ] || fail "Package build has $statistic packages."
done
# Refuse any active jail using this package jail, even if an old build is done.
if jls -n name | awk -v j="$C9_PACKAGE_JAIL" '$0 ~ "name=" j "(-|$)" {found=1} END {exit !found}'; then
    fail 'The C9 package jail is active. Wait for all builds to finish.'
fi
[ -s "$C9_PUBLIC_KEY" ] || fail 'C9 repository public signing key is missing.'
repo=$(realpath "$C9_REPOSITORY/.latest")
case "$repo" in "$C9_REPOSITORY"/.real_*) ;; *) fail 'Unexpected published repository snapshot path.' ;; esac
[ "$(cat "$repo/.buildname")" = "$build_id" ] || fail 'Published repository belongs to a different build.'
[ "$(cat "$repo/.jailversion")" = "$C9_EXPECTED_VERSION" ] || fail 'Package repository was built against a different FreeBSD patch level.'

# Recheck the complete install transaction as well as signatures and hashes.
# Fetching the dependency closure alone cannot detect package conflicts.
/bin/sh "$project/scripts/c9-build.sh" verify "$build_id"
[ "$(realpath "$C9_REPOSITORY/.latest")" = "$repo" ] || fail 'Repository changed during release verification.'

# Prepare the exact source-built p6 kernel jail separately. HTTP creation now
# updates to p7, and the historical official p6 update contains a p5 kernel.
# Neither satisfies the approved p6 kernel/module checks.
metadata=/usr/local/etc/poudriere.d/jails
if [ ! -d "$metadata/$C9_IMAGE_JAIL" ]; then
    fail "Missing $C9_IMAGE_JAIL. First run scripts/prepare-image-jail.sh --build-id $build_id --output NEW_ABSOLUTE_DIRECTORY; see docs/INSTALLER.md."
fi

mkdir -p "$output"
output=$(realpath "$output")
work="$output/work"
input="$output/inputs"
mkdir -p "$work" "$input/packages" "$input/distributions" "$input/build" "$work/repos" "$work/pkgdb" "$work/pkgcache"
printf '%s\n' "$build_id" > "$input/build/package-build-id"
printf '%s\n' "$C9_EXPECTED_VERSION" > "$input/build/freebsd-version"
printf '%s\n' "$C9_VERSION" > "$input/build/c9-version"
poudriere version > "$input/build/poudriere-version"
git -C /usr/local/poudriere/ports/default rev-parse HEAD > "$input/build/ports-revision"
[ "$(cat "$input/build/ports-revision")" = "$C9_PORTS_COMMIT" ] || fail 'Ports revision differs from the approved release input.'
cp "$project/installer/release.conf" "$input/build/release.conf"
printf "C9_HARDWARE_PROFILES='%s'\n" "$C9_HARDWARE_PROFILES" > "$input/install.conf"
install -m 644 "$C9_PUBLIC_KEY" "$input/poudriere.cert"

# Copy only the published immutable generation, never .building or host logs.
tar -cf "$work/repository.tar" --exclude './logs' -C "$repo" .
tar -xpf "$work/repository.tar" -C "$input/packages"
rm "$work/repository.tar"
[ "$(realpath "$C9_REPOSITORY/.latest")" = "$repo" ] || fail 'Repository changed while snapshotting; retry after builds stop.'
cat > "$work/repos/C9Offline.conf" <<EOF
C9Offline: {
  url: "file://$input/packages",
  enabled: yes,
  signature_type: "pubkey",
  pubkey: "$input/poudriere.cert"
}
EOF
repo_pkg() {
    # An explicit ABI makes pkg guess the major release's .0 OSVERSION.
    # Supply the exact target userland revision as well, keeping its checks on.
    pkg -o REPOS_DIR="$work/repos" -o PKG_DBDIR="$work/pkgdb" \
        -o PKG_CACHEDIR="$work/pkgcache" -o ABI=FreeBSD:15:amd64 \
        -o OSVERSION="$C9_OSVERSION" "$@"
}
repo_pkg update -f
for package in $C9_REQUIRED_PACKAGES; do
    package_version=$(repo_pkg rquery -r C9Offline '%v' "$package")
    [ -n "$package_version" ] || fail "Required package is missing: $package"
    case "$package" in
        c9-*) [ "$package_version" = "$C9_VERSION" ] || fail "Unexpected $package version: $package_version" ;;
    esac
done
# This validates every signed digest in the runtime dependency closures.
repo_pkg fetch -d -y -r C9Offline $C9_REQUIRED_PACKAGES
repo_pkg rquery -r C9Offline '%n %v %o' > "$input/build/packages.txt"
pkg_archive_name=$(repo_pkg rquery -r C9Offline '%n-%v' pkg)
pkg_archive="$input/packages/All/$pkg_archive_name.pkg"
[ -s "$pkg_archive" ] || fail 'pkg bootstrap archive is missing.'
pkg_member=$(tar -tf "$pkg_archive" | awk '$0 == "/usr/local/sbin/pkg-static" || $0 == "usr/local/sbin/pkg-static" || $0 == "./usr/local/sbin/pkg-static" { print }')
[ -n "$pkg_member" ] || fail 'pkg-static is missing from the verified pkg archive.'
tar -xOf "$pkg_archive" "$pkg_member" > "$input/pkg-static"
chmod 755 "$input/pkg-static"
"$input/pkg-static" -v > "$input/build/pkg-version"
cat > "$input/C9.conf" <<EOF
C9: {
  url: "$C9_UPDATE_URL",
  enabled: yes,
  signature_type: "pubkey",
  pubkey: "/usr/local/etc/ssl/certs/c9-repository.pub"
}
EOF

image_root=$(cat "$metadata/$C9_IMAGE_JAIL/mnt")
[ "$(cat "$metadata/$C9_IMAGE_JAIL/arch")" = "$C9_ARCH" ] || fail 'Image jail architecture mismatch.'
[ "$(cat "$metadata/$C9_IMAGE_JAIL/version")" = "$C9_EXPECTED_VERSION" ] || fail 'Image jail patch level differs; restore the approved jail snapshot instead of silently upgrading.'
[ "$(chroot "$image_root" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] || fail 'Image jail userland revision mismatch.'
[ "$(chroot "$image_root" /usr/bin/uname -U)" = "$C9_OSVERSION" ] || fail 'Image jail numeric userland revision mismatch.'
[ "$(env ROOT="$image_root" /bin/freebsd-version -k)" = "$C9_EXPECTED_VERSION" ] || fail 'Image jail kernel revision mismatch.'
[ -f "$image_root/usr/src/Makefile" ] || fail 'Poudriere image needs the matching base source tree.'
awk -F: '$3 >= 1000 && $3 < 65534 {exit 1} $1 == "root" && $2 != "" && $2 != "*" {exit 1}' \
    "$image_root/etc/master.passwd" || fail 'Image jail contains personal accounts or a root password.'
if find "$image_root/etc/ssh" -name 'ssh_host_*' | grep . >/dev/null; then
    fail 'Image jail contains machine SSH host keys.'
fi
if jls -n name | awk -v j="$C9_IMAGE_JAIL" '$0 ~ "name=" j "(-|$)" {found=1} END {exit !found}'; then
    fail 'The image jail is active.'
fi
cp "$image_root/usr/libexec/bsdinstall/auto" "$input/build/bsdinstall-auto.freebsd"
sha256 "$image_root/boot/kernel/kernel" > "$input/build/kernel.sha256"
# Save the kernel-bearing jail including its matching /usr/src. Unlike the
# target payload, this archive can restore Poudriere's exact image build input
# after FreeBSD update servers have advanced. It is not copied into the ISO.
env XZ_OPT='-T1' tar -cJpf "$input/image-jail.tar.xz" \
    --exclude '.poudriere*' --exclude './dev/*' --exclude './tmp/*' \
    --exclude './var/tmp/*' --exclude './var/cache/*' --exclude './var/log/*' \
    --exclude './var/db/freebsd-update' --exclude './boot/kernel.old' \
    --exclude './etc/hostid' --exclude './boot/entropy' --exclude './var/db/entropy' \
    --exclude './root/.ssh' --exclude './etc/ssh/ssh_host_*' -C "$image_root" .
sha256 "$input/image-jail.tar.xz" > "$input/image-jail.sha256"

if [ -n "$reuse_payload" ]; then
    reuse_payload=$(realpath "$reuse_payload")
    [ "$(cat "$reuse_payload/freebsd-version")" = "$C9_EXPECTED_VERSION" ] || fail 'Saved payload version differs.'
    for dist in base kernel; do
        expected=$(awk -v name="$dist.txz" '$1 == name {print $2}' "$reuse_payload/MANIFEST")
        [ -n "$expected" ] && [ "$(sha256 -q "$reuse_payload/$dist.txz")" = "$expected" ] || fail "Saved $dist payload checksum mismatch."
        cp -p "$reuse_payload/$dist.txz" "$input/distributions/"
    done
    cp -p "$reuse_payload/MANIFEST" "$input/distributions/"
else
    world="$work/payload-world"
    mkdir "$world"
    # Export the dedicated image jail, never the running host or build jail.
    tar -cf "$work/world.tar" -X "$project/installer/image.exclude" \
        --exclude '.poudriere*' --exclude './dev/*' --exclude './tmp/*' \
        --exclude './var/tmp/*' --exclude './var/cache/*' --exclude './var/log/*' -C "$image_root" .
    tar -xpf "$work/world.tar" -C "$world"
    rm "$work/world.tar"
    # Refuse reused/customized image jails that could embed human credentials.
    awk -F: '$3 >= 1000 && $3 < 65534 {exit 1} $1 == "root" && $2 != "" && $2 != "*" {exit 1}' \
        "$world/etc/master.passwd" || fail 'Image jail contains personal accounts or a root password.'
    [ ! -d "$world/root/.ssh" ] || fail 'Image jail contains root SSH identity.'
    if [ -f "$world/etc/login.conf.orig" ]; then
        mv "$world/etc/login.conf.orig" "$world/etc/login.conf"
    fi
    cap_mkdb "$world/etc/login.conf"
    pwd_mkdb -d "$world/etc" -p "$world/etc/master.passwd"
    : > "$world/etc/fstab"
    : > "$world/etc/rc.conf"
    : > "$world/etc/resolv.conf"
    mkdir -p "$world/tmp" "$world/var/tmp" "$world/dev" "$world/mnt"
    chmod 1777 "$world/tmp" "$world/var/tmp"
    # Deterministic entry ordering, one compression thread, preserved base file
    # ownership/modes. Saved payload archives are the canonical repeat inputs.
    (cd "$world" && find . -xdev -print | LC_ALL=C sort) > "$work/world-files"
    env XZ_OPT='-T1' tar -cJpf "$input/distributions/base.txz" \
        --no-recursion --exclude './boot/kernel' --exclude './boot/kernel/*' \
        -C "$world" -T "$work/world-files"
    (cd "$world" && find ./boot/kernel -xdev -print | LC_ALL=C sort) > "$work/kernel-files"
    env XZ_OPT='-T1' tar -cJpf "$input/distributions/kernel.txz" \
        --no-recursion -C "$world" -T "$work/kernel-files"
    : > "$input/distributions/MANIFEST"
    for dist in base kernel; do
        checksum=$(sha256 -q "$input/distributions/$dist.txz")
        files=$(tar -tf "$input/distributions/$dist.txz" | wc -l | tr -d ' ')
        printf '%s.txz\t%s\t%s\t%s\t"C9 FreeBSD %s %s (MANDATORY)"\ton\n' \
            "$dist" "$checksum" "$files" "$dist" "$C9_EXPECTED_VERSION" "$dist" >> "$input/distributions/MANIFEST"
    done
fi
printf '%s\n' "$C9_EXPECTED_VERSION" > "$input/distributions/freebsd-version"
# Independently unpack the finished payload to validate version and separation.
mkdir "$work/verify-base"
tar -xpf "$input/distributions/base.txz" -C "$work/verify-base"
[ ! -e "$work/verify-base/boot/kernel/kernel" ] || fail 'Base archive unexpectedly contains the kernel.'
[ ! -e "$work/verify-base/etc/rc.local" ] || fail 'Base archive must not contain installer startup.'
tar -xpf "$input/distributions/kernel.txz" -C "$work/verify-base"
[ "$(chroot "$work/verify-base" /bin/freebsd-version -u)" = "$C9_EXPECTED_VERSION" ] || fail 'Archived userland revision mismatch.'
[ "$(env ROOT="$work/verify-base" /bin/freebsd-version -k)" = "$C9_EXPECTED_VERSION" ] || fail 'Archived kernel revision mismatch.'
[ "$(sha256 -q "$work/verify-base/boot/kernel/kernel")" = "$(sha256 -q "$image_root/boot/kernel/kernel")" ] || fail 'Archived kernel differs from image kernel.'
awk -F: '$3 >= 1000 && $3 < 65534 {exit 1} $1 == "root" && $2 != "" && $2 != "*" {exit 1}' \
    "$work/verify-base/etc/master.passwd" || fail 'Payload contains personal accounts or a root password.'
if find "$work/verify-base/etc/ssh" -name 'ssh_host_*' | grep . >/dev/null; then
    fail 'Payload contains machine SSH host keys.'
fi
[ ! -e "$work/verify-base/etc/hostid" ] && [ ! -e "$work/verify-base/boot/entropy" ] || fail 'Payload contains machine identity or entropy.'
cp "$input/distributions/MANIFEST" "$input/build/MANIFEST"
(cd "$project" && find installer scripts -type f -print | LC_ALL=C sort | xargs sha256) > "$input/build/installer-source.sha256"
tar -cJf "$input/build/project-source.tar.xz" -C "$project" installer scripts tests ports poudriere docs README.md CHANGELOG.md LICENSE MANIFEST.sha256
# The Poudriere executable starts its worker through env -i. Custom exported
# variables do not survive. Its -A script is therefore a root-owned wrapper
# containing safely quoted paths, sourced in the worker's shell environment.
post_script="$work/c9-post-build.sh"
emit_post_script > "$post_script"
chmod 0600 "$post_script"
chown root:wheel "$post_script"
/bin/sh -n "$post_script"
poudriere image -j "$C9_IMAGE_JAIL" -t hybridiso -n "$C9_IMAGE_NAME" \
    -c "$project/installer/overlay" -A "$post_script" \
    -X "$project/installer/image.exclude" -h c9-installer -o "$output"
sha256 "$output/$C9_IMAGE_NAME.iso" > "$output/SHA256"
sha512 "$output/$C9_IMAGE_NAME.iso" > "$output/SHA512"
echo "C9 ISO created: $output/$C9_IMAGE_NAME.iso"
echo "Keep $input for reproducibility. Boot and complete-install validation is still required."
