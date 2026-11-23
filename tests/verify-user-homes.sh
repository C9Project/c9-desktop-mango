#!/bin/sh
# Isolated reproduction of the p6 bsdinstall/adduser ZFS home transition.
set -eu
set -o pipefail
umask 077
PATH=/sbin:/bin:/usr/sbin:/usr/bin
LC_ALL=C
export PATH LC_ALL
# Usage: sh verify-user-homes.sh HELPER SHA256 NEW_ABSOLUTE_EVIDENCE_DIR
[ "$#" = 3 ] || { echo 'Expected helper path, SHA256 and new evidence directory.' >&2; exit 1; }
testroot=$3
printf '%s\n' "$testroot" | grep -Eq '^/usr/local/c9/tests/zfs-home-regression-[A-Za-z0-9_-]+$' || exit 1
pool=c9homereg_$(date -u +%Y%m%dT%H%M%SZ)_$$
vdev=$testroot/vdev.img
target=$testroot/target
user=c9zfstest
dataset=$pool/home/$user
payload=/usr/local/c9/releases/c9-0.2.0-20261122T104752Z/inputs/distributions/base.txz
expected=1a5df92b5dfcade2ba8321c121beafc391aee1cf999dcb97e51b271af10b70bc

helper_input=$1
helper_sha=$2
case "$helper_input" in /*) ;; *) exit 1 ;; esac
printf '%s\n' "$helper_sha" | grep -Eq '^[0-9a-f]{64}$'
[ -f "$helper_input" ] && [ ! -L "$helper_input" ]
[ "$(sha256 -q "$helper_input")" = "$helper_sha" ]
helper=$testroot/reconcile-user-homes
ufsimage=$testroot/ufs.img
ufstarget=$testroot/ufs-target
mdunit=
ufsmounted=no
created=no
devfs=no
guid=
fail() { printf '%s\n' "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] && [ "$(uname -s)" = FreeBSD ] || fail 'Requires FreeBSD root.'
[ "$(realpath /usr/local/c9/tests)" = /usr/local/c9/tests ] || fail 'Unexpected parent path.'
[ "$(stat -f %u /usr/local/c9/tests)" = 0 ] || fail 'Parent not root-owned.'
[ ! -e "$testroot" ] && [ ! -L "$testroot" ] || fail 'Preserving existing test directory.'
if zpool list -H "$pool" >/dev/null 2>&1; then fail 'Preserving existing pool.'; fi
[ -f "$payload" ] && [ ! -L "$payload" ] || fail 'Payload missing or linked.'
[ "$(sha256 -q "$payload")" = "$expected" ] || fail 'Patched base hash mismatch.'
mkdir -m 0700 "$testroot"
[ "$(realpath "$testroot")" = "$testroot" ] || fail 'Unexpected resolved test path.'
install -o root -g wheel -m 0500 "$helper_input" "$helper"
[ "$(sha256 -q "$helper")" = "$helper_sha" ]
exec > "$testroot/console.log" 2>&1
printf 'Reviewed helper SHA256: %s\n' "$helper_sha"
printf 'Test root: %s\nPool: %s\nBase SHA256: %s\n' "$testroot" "$pool" "$expected"
date -u
guard_pool() {
    [ "$created" = yes ] || return 1
    [ -f "$vdev" ] && [ ! -L "$vdev" ] && [ "$(realpath "$vdev")" = "$vdev" ] || return 1
    [ "$(stat -f %z "$vdev")" = 4294967296 ] || return 1
    [ -n "$guid" ] && [ "$(zpool get -H -o value guid "$pool")" = "$guid" ] || return 1
    [ "$(zpool get -H -o value altroot "$pool")" = "$target" ] || return 1
    zpool status -P "$pool" | awk -v p="$vdev" '
        $1 ~ /^\// {if ($1 != p) bad=1; n++}
        END {exit (bad || n != 1)}'
}
guard_md() {
    [ -n "$mdunit" ] && [ -f "$ufsimage" ] && [ ! -L "$ufsimage" ] || return 1
    [ "$(realpath "$ufsimage")" = "$ufsimage" ] || return 1
    [ "$(mdconfig -l -n -u "$mdunit" -f "$ufsimage")" = "$mdunit" ]
}
finish() {
    status=$?
    trap - EXIT HUP INT TERM
    set +e
    printf '%s\n' "$status" > "$testroot/reproduction-exit-status"
    cleanup=0
    if [ "$ufsmounted" = yes ]; then
        actual=$(mount -p | awk -v p="$ufstarget" '$2==p {print $1 "|" $3}')
        if guard_md && [ "$actual" = "/dev/md$mdunit|ufs" ] && [ "$(realpath "$ufstarget")" = "$ufstarget" ]; then
            umount "$ufstarget" || cleanup=1
        else
            printf '%s\n' 'Refusing unexpected UFS cleanup.'
            cleanup=1
        fi
    fi
    if [ -n "$mdunit" ]; then
        if guard_md; then mdconfig -d -u "$mdunit" || cleanup=1; else cleanup=1; fi
    fi
    if [ "$devfs" = yes ]; then
        actual=$(mount -p | awk -v p="$target/dev" '$2==p {print $1 "|" $3}')
        if [ "$actual" = 'devfs|devfs' ] && [ "$(realpath "$target/dev")" = "$target/dev" ]; then
            umount "$target/dev" || cleanup=1
        else
            printf '%s\n' 'Refusing unexpected devfs cleanup.'
            cleanup=1
        fi
    fi
    if [ "$created" = yes ]; then
        if guard_pool; then
            zpool status -P "$pool" > "$testroot/pool-before-cleanup.txt"
            zfs list -H -r -o name,mountpoint,mounted "$pool" > "$testroot/datasets-before-cleanup.txt"
            zpool destroy "$pool" || cleanup=1
        else
            printf '%s\n' 'Refusing pool cleanup: exact pool/vdev guard failed.'
            cleanup=1
        fi
    fi
    zpool list -H -o name,guid > "$testroot/pools-after.txt"
    cmp -s "$testroot/pools-before.txt" "$testroot/pools-after.txt" || cleanup=1
    mount -p | awk -v p="$testroot/" -v pool="$pool" 'index($2,p)==1 || $1==pool || index($1,pool "/")==1' > "$testroot/remaining-mounts.txt"
    [ ! -s "$testroot/remaining-mounts.txt" ] || cleanup=1
    printf '%s\n' "$cleanup" > "$testroot/cleanup-exit-status"
    date -u > "$testroot/finished-at"
    printf 'Reproduction exit: %s; cleanup exit: %s\n' "$status" "$cleanup"
    [ "$status" = 0 ] && [ "$cleanup" = 0 ]
    exit $?
}
trap finish EXIT
trap 'exit 1' HUP INT TERM
zpool list -H -o name,guid > "$testroot/pools-before.txt"
mkdir -m 0700 "$target"
truncate -s 4294967296 "$vdev"
[ -f "$vdev" ] && [ ! -L "$vdev" ] && [ "$(realpath "$vdev")" = "$vdev" ] || fail 'Unsafe vdev path.'
zpool create -o cachefile=none -O mountpoint=none -R "$target" "$pool" "$vdev"
created=yes
guid=$(zpool get -H -o value guid "$pool")
printf '%s\n' "$guid" > "$testroot/pool-guid"
guard_pool || fail 'Created pool failed ownership/vdev checks.'
zfs create -o mountpoint=none "$pool/ROOT"
zfs create -o mountpoint=/ "$pool/ROOT/default"
zfs create -o mountpoint=/home "$pool/home"
tar -xpf "$payload" -C "$target"
[ "$(chroot "$target" /bin/freebsd-version -u)" = 15.1-RELEASE-p6 ] || fail 'Chroot is not exact p6.'
sha256 "$target/usr/sbin/adduser" "$target/sbin/zfs" "$target/usr/sbin/pw" > "$testroot/tool-hashes.txt"
cp "$target/usr/sbin/adduser" "$testroot/adduser-p6.sh"
[ ! -e "$target/root/c9-account.txt" ] || fail 'Unexpected test-account input.'
printf '%s\n' 'c9zfstest:21001:::0:0:C9 ZFS Reproduction:/home/c9zfstest:/bin/sh:' > "$target/root/c9-account.txt"
mount -t devfs devfs "$target/dev"
devfs=yes
snapshot() {
    phase=$1
    zfs list -H -r -o name,mountpoint,mounted "$pool" > "$testroot/$phase-datasets.txt"
    zfs get -H -r -o name,property,value,source mountpoint,canmount,mounted "$pool" > "$testroot/$phase-properties.txt"
    mount -p | awk -v p="$testroot/" -v pool="$pool" 'index($2,p)==1 || $1==pool || index($1,pool "/")==1' > "$testroot/$phase-mounts.txt"
    chroot "$target" /usr/bin/stat -f '%N|uid=%u|gid=%g|mode=%Lp' /home > "$testroot/$phase-home-stat.txt"
    if [ -e "$target/home/$user" ]; then
        chroot "$target" /usr/bin/stat -f '%N|uid=%u|gid=%g|mode=%Lp' "/home/$user" >> "$testroot/$phase-home-stat.txt"
    fi
    doubled=$target$target/home/$user
    if [ -e "$doubled" ]; then
        stat -f '%N|uid=%u|gid=%g|mode=%Lp' "$doubled" >> "$testroot/$phase-home-stat.txt"
    fi
}
snapshot before
[ "$(chroot "$target" /sbin/zfs list -H -o name /home)" = "$pool/home" ] || fail 'adduser would address an unexpected parent dataset.'
printf '%s\n' 'Running unmodified p6 adduser with a synthetic disabled account and no password.'
chroot "$target" /usr/bin/env BSDINSTALL_CHROOT="$target" /bin/sh -x /usr/sbin/adduser -N -f /root/c9-account.txt -w no -E > "$testroot/adduser-trace.txt" 2>&1
awk -F: -v u="$user" '$1==u {if ($2 !~ /^\*LOCKED\*/) exit 1; found=1; print $1 ":uid=" $3 ":gid=" $4 ":home=" $9 ":shell=" $10 ":locked=yes"} END {if (!found) exit 1}' "$target/etc/master.passwd" > "$testroot/identity.txt"
snapshot after-adduser
[ "$(zfs list -H -o name "$dataset")" = "$dataset" ] || fail 'Expected test home dataset missing.'
[ "$(stat -f %u "$target/home/$user")" = 0 ] || fail 'Expected root-owned placeholder fault was not reproduced.'

# Keep synthetic credentials unused and private; generated plaintext is discarded.
chroot "$target" /usr/sbin/pw usermod "$user" -w random >/dev/null
awk -F: -v u="$user" '$1==u {if ($2=="" || $2 ~ /^[!*]/) exit 1; found=1} END {if (!found) exit 1}' "$target/etc/master.passwd"
doubled=$target$target/home/$user
[ "$(stat -f %u "$doubled")" = 21001 ] || fail 'Wrong fixture home owner before helper.'
printf '%s\n' 'C9 preserved data: original home content must survive mount repair.' > "$doubled/preservation-sentinel.txt"
chown 21001:21001 "$doubled/preservation-sentinel.txt"
chmod 0640 "$doubled/preservation-sentinel.txt"
mtree -c -p "$doubled" -k type,uid,gid,mode,size,sha256digest > "$testroot/home-before.mtree"
sha256 -q "$target/etc/master.passwd" > "$testroot/account-file-before.sha256"
run_helper() {
    name=$1
    destination=$2
    set +e
    /bin/sh "$helper" "$destination" "$user" > "$testroot/$name.log" 2>&1
    code=$?
    set -e
    printf '%s\n' "$code" > "$testroot/$name.exit-status"
    return "$code"
}
run_helper repair "$target" || fail 'Helper did not repair exact p6 doubled mount.'
snapshot after-repair
[ "$(stat -f %u "$target/home/$user")" = 21001 ] || fail 'Correct owner not visible after helper.'
actual=$(mount -p | awk -v d="$dataset" '$1==d {print $2}')
[ "$actual" = "$target/home/$user" ] || fail 'Repair did not place exactly the intended dataset mount.'
mtree -f "$testroot/home-before.mtree" -p "$target/home/$user" > "$testroot/repair-data-comparison.txt"
[ ! -s "$testroot/repair-data-comparison.txt" ] || fail 'Home data or metadata changed during repair.'
[ "$(sha256 -q "$target/etc/master.passwd")" = "$(cat "$testroot/account-file-before.sha256")" ] || fail 'Account records changed during repair.'
printf '%s\n' 'PASS repair: exact p6 adduser defect corrected; dataset/content/owners preserved.' >> "$testroot/RESULTS.txt"
run_helper correct-zfs "$target" || fail 'Correctly mounted ZFS home rejected.'
snapshot after-correct-zfs
for item in datasets properties mounts home-stat; do
    cmp -s "$testroot/after-repair-$item.txt" "$testroot/after-correct-zfs-$item.txt" || fail 'Correct ZFS case was not a no-op.'
done
mtree -f "$testroot/home-before.mtree" -p "$target/home/$user" > "$testroot/correct-zfs-data-comparison.txt"
[ ! -s "$testroot/correct-zfs-data-comparison.txt" ] || fail 'Correct ZFS case changed home data.'
printf '%s\n' 'PASS correct-zfs: repeated invocation leaves mounts/properties/data unchanged.' >> "$testroot/RESULTS.txt"
# Deliberately wrong ownership is fixture setup, never a helper operation.
chown 21002:21001 "$target/home/$user"
mtree -c -p "$target/home/$user" -k type,uid,gid,mode,size,sha256digest > "$testroot/wrong-owner-before.mtree"
if run_helper wrong-owner "$target"; then
    printf '%s\n' 'Helper preserved the mismatch for the existing setup ownership guard.' > "$testroot/wrong-owner-policy.txt"
else
    printf '%s\n' 'Helper rejected the genuine mismatch without rewriting it.' > "$testroot/wrong-owner-policy.txt"
fi
[ "$(stat -f %u "$target/home/$user")" = 21002 ] || fail 'Helper silently rewrote a real owner mismatch.'
mtree -f "$testroot/wrong-owner-before.mtree" -p "$target/home/$user" > "$testroot/wrong-owner-data-comparison.txt"
[ ! -s "$testroot/wrong-owner-data-comparison.txt" ] || fail 'Helper changed genuinely misowned home data/metadata.'
[ "$(stat -f %u "$target/home/$user")" != 21001 ] || fail 'Existing setup ownership condition would unexpectedly accept mismatch.'
printf '%s\n' 'PASS wrong-owner: mismatch/data unchanged; original UID ownership condition rejects.' >> "$testroot/RESULTS.txt"
chown 21001:21001 "$target/home/$user"

# Real UFS filesystem with the same p6 base, on a new file-backed md device.
prototype=$testroot/ufs-prototype
mkdir -m 0700 "$prototype" "$ufstarget"
tar -xpf "$payload" -C "$prototype"
mkdir -p "$prototype/home/$user"
cp -p "$target/etc/master.passwd" "$prototype/etc/master.passwd"
cp -p "$target/home/$user/preservation-sentinel.txt" "$prototype/home/$user/preservation-sentinel.txt"
chown 21001:21001 "$prototype/home/$user"
chmod 0700 "$prototype/home/$user"
[ ! -e "$ufsimage" ] && [ ! -L "$ufsimage" ] || fail 'Preserving existing UFS image.'
makefs -t ffs -s 4g "$ufsimage" "$prototype" > "$testroot/makefs.log" 2>&1
mdunit=$(mdconfig -a -t vnode -n -o readonly -f "$ufsimage")
case "$mdunit" in ''|*[!0-9]*) fail 'Unexpected md unit.' ;; esac
guard_md || fail 'UFS image/device binding not verified.'
mdconfig -l -v -u "$mdunit" > "$testroot/ufs-md-binding.txt"
mount -t ufs -o ro "/dev/md$mdunit" "$ufstarget"
ufsmounted=yes
mount -p | awk -v p="$ufstarget" '$2==p' > "$testroot/ufs-mount-before.txt"
mtree -c -p "$ufstarget/home/$user" -k type,uid,gid,mode,size,sha256digest > "$testroot/ufs-home-before.mtree"
run_helper ufs "$ufstarget" || fail 'Normal UFS home rejected.'
mount -p | awk -v p="$ufstarget" '$2==p' > "$testroot/ufs-mount-after.txt"
cmp -s "$testroot/ufs-mount-before.txt" "$testroot/ufs-mount-after.txt" || fail 'UFS mount changed.'
mtree -f "$testroot/ufs-home-before.mtree" -p "$ufstarget/home/$user" > "$testroot/ufs-data-comparison.txt"
[ ! -s "$testroot/ufs-data-comparison.txt" ] || fail 'UFS home changed.'
[ "$(sha256 -q "$ufstarget/etc/master.passwd")" = "$(cat "$testroot/account-file-before.sha256")" ] || fail 'UFS account records changed.'
printf '%s\n' 'PASS ufs: real readonly image-backed UFS target/home accepted without changes.' >> "$testroot/RESULTS.txt"
[ "$(sha256 -q "$target/etc/master.passwd")" = "$(cat "$testroot/account-file-before.sha256")" ] || fail 'Final account records changed.'
cat "$testroot/RESULTS.txt"
