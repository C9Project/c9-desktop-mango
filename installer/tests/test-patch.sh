#!/bin/sh
# Usage: sh installer/tests/test-patch.sh /path/to/FreeBSD-15.1-bsdinstall-auto
# Exercises the actual upstream input without modifying it or a target disk.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
upstream=${1:-/usr/libexec/bsdinstall/auto}
[ -s "$upstream" ] || { echo 'Supply the actual FreeBSD bsdinstall auto script.' >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk -f "$root/installer/patch-auto.awk" "$upstream" > "$work/auto"
sh -n "$work/auto"
for action in 'bsdinstall rootpass' 'bsdinstall adduser' 'bsdinstall autopart' 'bsdinstall zfsboot' 'bsdinstall time' 'bsdinstall bootconfig'; do
    grep -F "$action" "$work/auto" >/dev/null
done
grep -F 'PKGBASE=no' "$work/auto" >/dev/null
if grep -F 'Select Installation Type' "$work/auto" >/dev/null; then
    echo 'Network/pkgbase choice remains in offline installer.' >&2; exit 1
fi
grep 'local.post-configure.*|| error' "$work/auto" >/dev/null

# A changed hook name must fail closed, rather than silently omit C9 setup.
sed 's/local.post-configure/local.changed-hook/g' "$upstream" > "$work/changed"
if awk -f "$root/installer/patch-auto.awk" "$work/changed" > "$work/bad" 2>/dev/null; then
    echo 'Changed upstream hook was wrongly accepted.' >&2; exit 1
fi
# Duplicate hooks or an already-patched input are also unsupported.
cat "$upstream" "$upstream" > "$work/duplicate"
if awk -f "$root/installer/patch-auto.awk" "$work/duplicate" > "$work/bad" 2>/dev/null; then
    echo 'Duplicate upstream hooks were wrongly accepted.' >&2; exit 1
fi
if awk -f "$root/installer/patch-auto.awk" "$work/auto" > "$work/bad" 2>/dev/null; then
    echo 'Already patched upstream script was wrongly accepted.' >&2; exit 1
fi
echo 'PASS: interactive actions retained; offline selection and C9 failure handling installed; incompatible inputs rejected.'
