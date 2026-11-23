#!/bin/sh
# Exercise the actual builder's wrapper generator with a harmless customization.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sed -n '/^shell_quote() {$/,/^}$/p; /^emit_post_script() {$/,/^}$/p' \
    "$root/scripts/build-iso.sh" > "$work/functions.sh"
. "$work/functions.sh"
project="$work/project's space;\$(false)\`false\`"
input="$work/input's space;\$(false)\`false\`"
mkdir -p "$project/installer" "$input"
cat > "$project/installer/customize-image.sh" <<'EOF'
: "${C9_IMAGE_INPUT:?missing input}"
: "${C9_PROJECT_ROOT:?missing project}"
printf '%s\n%s\n' "$C9_IMAGE_INPUT" "$C9_PROJECT_ROOT"
EOF
emit_post_script > "$work/wrapper.sh"
sh -n "$work/wrapper.sh"
expected=$(printf '%s\n%s' "$input" "$project")
actual=$(env -i PATH=/bin:/usr/bin /bin/sh "$work/wrapper.sh")
[ "$actual" = "$expected" ] || { echo 'Wrapper lost or expanded literal paths under env -i.' >&2; exit 1; }
actual=$(env -i PATH=/bin:/usr/bin C9_IMAGE_INPUT=wrong C9_PROJECT_ROOT=wrong /bin/sh "$work/wrapper.sh")
[ "$actual" = "$expected" ] || { echo 'Inherited variables overrode the wrapper.' >&2; exit 1; }
echo 'PASS: wrapper survives env -i, sources customization, and preserves spaces/apostrophes/shell metacharacters.'
