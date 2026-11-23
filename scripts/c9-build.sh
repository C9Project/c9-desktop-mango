#!/bin/sh
# Reproduce the C9 package build on the configured FreeBSD Poudriere server.
set -eu
set -o pipefail
umask 022

fail() { printf 'C9 build: %s\n' "$*" >&2; exit 1; }
usage() {
    printf 'Usage: %s configure | plan | build [BUILD_ID] | verify BUILD_ID\n' "$0" >&2
    exit 2
}
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$project/installer/release.conf"
etc=/usr/local/etc/poudriere.d
data=/usr/local/poudriere/data
action=${1:-}
[ "$#" -gt 0 ] && shift || usage
[ "$(uname -s)" = FreeBSD ] || fail 'Run on the FreeBSD build server.'
[ "$(id -u)" -eq 0 ] || fail 'Run with doas/root.'
for command in poudriere git pkg sha256 cmp tar; do
    command -v "$command" >/dev/null || fail "Missing command: $command"
done

assert_idle() {
    if jls -n name | awk -v jail="$C9_PACKAGE_JAIL" \
        '$0 ~ "name=" jail "(-|$)" {active=1} END {exit !active}'; then
        fail 'The C9 jail is active. Let its current build finish before changing inputs.'
    fi
}

assert_inputs() {
    [ -f "$etc/jails/$C9_PACKAGE_JAIL/version" ] || fail "Missing package jail: $C9_PACKAGE_JAIL"
    [ "$(cat "$etc/jails/$C9_PACKAGE_JAIL/version")" = "$C9_EXPECTED_VERSION" ] || fail 'Package jail revision differs from release.conf.'
    [ "$(cat "$etc/jails/$C9_PACKAGE_JAIL/arch")" = "$C9_ARCH" ] || fail 'Package jail architecture differs.'
    [ -f "$etc/ports/$C9_PORTS_TREE/mnt" ] || fail "Missing full ports tree: $C9_PORTS_TREE"
    ports=$(cat "$etc/ports/$C9_PORTS_TREE/mnt")
    [ -f "$ports/Mk/bsd.port.mk" ] || fail 'The base ports tree is incomplete.'
    [ "$(git -C "$ports" rev-parse HEAD)" = "$C9_PORTS_COMMIT" ] || fail 'Ports commit differs; restore the recorded revision instead of silently updating it.'
    [ -z "$(git -C "$ports" status --porcelain)" ] || fail 'The base ports tree has local modifications.'
}

assert_overlay() {
    [ -f "$etc/ports/$C9_OVERLAY/mnt" ] || fail 'Run configure first to register the C9 overlay.'
    [ "$(realpath "$(cat "$etc/ports/$C9_OVERLAY/mnt")")" = "$project/ports" ] || fail 'Registered C9 overlay points to a different source checkout.'
}

emit_policy() {
    printf '# Managed by C9 scripts/c9-build.sh\n'
    cat "$project/poudriere/c9-release-make.conf.example"
}

assert_resources() {
    [ -f "$etc/c9-poudriere.conf" ] || fail 'Missing approved C9 resource configuration; see docs/REPRODUCE.md.'
    [ -f "$etc/$C9_MASTER-poudriere.conf" ] || fail 'Missing approved C9 package memory limits; see docs/REPRODUCE.md.'
    # Inspect the effective override order used by Poudriere 3.4.8. Configs are
    # root-controlled shell files, as when Poudriere itself sources them.
    (
        [ ! -f /usr/local/etc/poudriere.conf ] || . /usr/local/etc/poudriere.conf
        [ ! -f "$etc/poudriere.conf" ] || . "$etc/poudriere.conf"
        for scope in "$C9_SET" "$C9_PORTS_TREE" "$C9_PACKAGE_JAIL" \
            "$C9_PORTS_TREE-$C9_SET" "$C9_PACKAGE_JAIL-$C9_PORTS_TREE" \
            "$C9_PACKAGE_JAIL-$C9_SET" "$C9_MASTER"; do
            [ ! -f "$etc/$scope-poudriere.conf" ] || . "$etc/$scope-poudriere.conf"
        done
        [ "${PARALLEL_JOBS:-}" = 2 ] && [ "${USE_TMPFS:-}" = no ] && \
            [ "${ALLOW_MAKE_JOBS:-}" = yes ] || fail 'Effective C9 resource policy differs from the approved two-builder, disk-backed configuration.'
        [ "${MAX_MEMORY:-}" = 8 ] && [ "${MAX_MEMORY_electron43:-}" = 2048 ] && \
            [ "${MAX_MEMORY_vscode:-}" = 16 ] || \
            fail 'Effective C9 memory limits differ from the approved 8 GiB default, 2048 GiB Electron and 16 GiB VS Code exceptions.'
        [ "${MAX_FILES:-}" = 2048 ] && [ "${MAX_FILES_vscode:-}" = 8192 ] || \
            fail 'Effective C9 open-file limits differ from the approved 2048 default and 8192 VS Code exception.'
    )
}

assert_policy() {
    [ -s "$project/poudriere/c9-release.list" ] || fail 'Release port list is missing.'
    [ -s "$project/poudriere/c9-release-make.conf.example" ] || fail 'Release package policy is missing.'
    scoped="$etc/$C9_MASTER-make.conf"
    [ -f "$scoped" ] || fail 'Run configure first to install the release package policy.'
    emit_policy | cmp -s - "$scoped" || fail 'Installed package policy differs; run configure before planning/building.'
    assert_resources
}

validate_id() {
    case "$1" in ''|.|..|*[!a-zA-Z0-9_.-]*) fail 'Invalid build ID.' ;; esac
}

verify_build() {
    build_id=$1
    validate_id "$build_id"
    logs="$data/logs/bulk/$C9_MASTER/$build_id"
    [ -d "$logs" ] || fail "Missing build logs: $logs"
    status=$(cat "$logs/.poudriere.status")
    case "$status" in done:|stopped:done:) ;; *) fail "Build is not complete: $status" ;; esac
    for statistic in failed skipped ignored; do
        [ "$(cat "$logs/.poudriere.stats_$statistic")" = 0 ] || fail "Build contains $statistic ports; inspect its logs."
    done
    snapshot=$(realpath "$C9_REPOSITORY/.latest")
    case "$snapshot" in "$C9_REPOSITORY"/.real_*) ;; *) fail 'Unexpected repository snapshot path.' ;; esac
    [ "$(cat "$snapshot/.buildname")" = "$build_id" ] || fail 'The published repository belongs to a different build.'
    [ "$(cat "$snapshot/.jailversion")" = "$C9_EXPECTED_VERSION" ] || fail 'Published packages target a different FreeBSD patch level.'
    [ -s "$C9_PUBLIC_KEY" ] || fail 'Repository public signing key is missing.'
    check=$(mktemp -d /usr/local/c9/verify.XXXXXXXX)
    mkdir "$check/repos" "$check/db" "$check/cache"
    cat > "$check/repos/C9.conf" <<EOF
C9: {
  url: "file://$snapshot",
  enabled: yes,
  signature_type: "pubkey",
  pubkey: "$C9_PUBLIC_KEY"
}
EOF
    repo_pkg() {
        pkg -o REPOS_DIR="$check/repos" -o PKG_DBDIR="$check/db" \
            -o PKG_CACHEDIR="$check/cache" -o ABI=FreeBSD:15:amd64 \
            -o OSVERSION="$C9_OSVERSION" "$@"
    }
    repo_pkg update -f -r C9
    required="$C9_REQUIRED_PACKAGES"
    for hardware in $C9_HARDWARE_PROFILES; do
        required="$required c9-hardware-$hardware"
    done
    # All C9 names match the final component of their release-list origin.
    # Check payload packages explicitly, rather than trusting only metaport
    # constraints such as >=0.2.0 in the recursive dependency graph.
    release_packages=$(awk '{sub(/#.*/, ""); if (NF) {n=split($1, parts, "/"); print parts[n]}}' \
        "$project/poudriere/c9-release.list")
    for package in $release_packages; do
        case "$package" in c9-*) required="$required $package" ;; *) fail 'Unexpected non-C9 origin in the release list.' ;; esac
    done
    for package in $required; do
        version=$(repo_pkg rquery -r C9 '%v' "$package")
        [ -n "$version" ] || fail "Required package missing: $package"
        case "$package" in c9-*) [ "$version" = "$C9_VERSION" ] || fail "Wrong $package version: $version" ;; esac
    done
    # Solve against an empty database without changing the host's installation.
    # pkg 2.9 needs -y to return success for a nonempty dry-run plan. Keep -n:
    # it exits before applying jobs, including when -y is present.
    repo_pkg install -n -y -U -r C9 $required 2>&1 | tee "$check/install-plan.txt" || \
        fail "Dependency plan failed; see $check/install-plan.txt"
    # A signed catalog alone does not prove the package files still exist or
    # match it. Fetch the complete runtime closure and verify its signed hashes.
    printf 'Verifying package archive hashes and runtime dependencies...\n'
    repo_pkg fetch -d -y -r C9 $required > "$check/fetch.log" 2>&1 || \
        fail "Package archive verification failed; see $check/fetch.log"
    repo_pkg rquery -r C9 '%n %v %o' > "$check/package-inventory.txt"
    awk -v expected="$C9_VERSION" '$1 ~ /^c9-/ && $2 != expected {bad=1} END {exit bad}' \
        "$check/package-inventory.txt" || fail 'A C9 package in the published repository has an unexpected version.'
    [ "$(realpath "$C9_REPOSITORY/.latest")" = "$snapshot" ] || fail 'Published repository changed during verification.'
    assert_idle
    printf 'Verified build %s. Signed catalog, package hashes, and install plan saved in %s\n' "$build_id" "$check"
}

case "$action" in
configure)
    [ "$#" -eq 0 ] || usage
    assert_idle
    assert_inputs
    [ -f "$project/poudriere/c9-release.list" ] || fail 'Release port list is missing.'
    [ -s "$project/poudriere/c9-release-make.conf.example" ] || fail 'Release package policy is missing.'
    assert_resources
    scoped="$etc/$C9_MASTER-make.conf"
    if [ -e "$scoped" ]; then
        grep -q '^# Managed by C9 scripts/c9-build.sh$' "$scoped" || fail "Refusing to replace unmanaged configuration: $scoped"
    fi
    backup=/usr/local/c9/backups/release-config-$(date -u +%Y%m%dT%H%M%SZ)
    install -d -m 0700 "$backup"
    if [ -d "$etc/ports/$C9_OVERLAY" ]; then
        [ "$(cat "$etc/ports/$C9_OVERLAY/method")" = null ] || fail 'Existing C9 overlay uses an unexpected method.'
        cp -Rp "$etc/ports/$C9_OVERLAY" "$backup/overlay-registration"
        if [ "$(realpath "$(cat "$etc/ports/$C9_OVERLAY/mnt")")" != "$project/ports" ]; then
            # -k unregisters only; it never removes the previous source tree.
            poudriere ports -d -k -p "$C9_OVERLAY"
            poudriere ports -c -p "$C9_OVERLAY" -m null -M "$project/ports"
        fi
    else
        poudriere ports -c -p "$C9_OVERLAY" -m null -M "$project/ports"
    fi
    if [ -f "$etc/c9-make.conf" ]; then
        cp -p "$etc/c9-make.conf" "$backup/c9-make.conf"
        # The 0.2 desktop is a fixed selection; discard only its obsolete 0.1 force setting.
        sed '/^x11_c9-desktop-mango_SET_FORCE[[:space:]]*=/d' "$backup/c9-make.conf" > "$etc/c9-make.conf"
    fi
    if [ -e "$scoped" ]; then
        cp -p "$scoped" "$backup/scoped-make.conf"
    fi
    # Poudriere concatenates this into the jail's /etc/make.conf. An absolute
    # .include pointing at the host checkout would be unavailable in that jail.
    emit_policy > "$scoped"
    chmod 0644 "$scoped"
    printf 'C9 %s overlay configured. Prior configuration saved in %s\n' "$C9_VERSION" "$backup"
    ;;
plan)
    [ "$#" -eq 0 ] || usage
    assert_idle
    assert_inputs
    assert_overlay
    assert_policy
    exec poudriere bulk -n -t -r -j "$C9_PACKAGE_JAIL" -p "$C9_PORTS_TREE" \
        -O "$C9_OVERLAY" -z "$C9_SET" -f "$project/poudriere/c9-release.list"
    ;;
build)
    [ "$#" -le 1 ] || usage
    assert_idle
    assert_inputs
    assert_overlay
    assert_policy
    build_id=${1:-c9release-$(date -u +%Y%m%dT%H%M%SZ)}
    validate_id "$build_id"
    logs="$data/logs/bulk/$C9_MASTER/$build_id"
    if [ -d "$logs" ]; then
        for statistic in failed skipped ignored; do
            [ "$(cat "$logs/.poudriere.stats_$statistic")" = 0 ] || fail 'Use a fresh build ID to retry recorded failures/skips.'
        done
    fi
    run=/usr/local/c9/runs/$build_id/attempt-$(date -u +%Y%m%dT%H%M%SZ)
    install -d -m 0755 "$run"
    cp "$project/installer/release.conf" "$run/"
    cp "$etc/c9-poudriere.conf" "$run/"
    cp "$etc/$C9_MASTER-poudriere.conf" "$run/"
    cp "$project/poudriere/c9-release-make.conf.example" "$run/"
    cp "$etc/$C9_MASTER-make.conf" "$run/"
    cp "$project/poudriere/c9-release.list" "$run/"
    tar -cJf "$run/project-source.tar.xz" -C "$project" ports poudriere installer scripts tests docs README.md CHANGELOG.md LICENSE MANIFEST.sha256
    git -C "$ports" rev-parse HEAD > "$run/ports-commit"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$run/started-at"
    printf 'Build ID: %s\nRun record: %s\n' "$build_id" "$run"
    set +e
    poudriere bulk -t -r -j "$C9_PACKAGE_JAIL" -p "$C9_PORTS_TREE" -O "$C9_OVERLAY" \
        -z "$C9_SET" -B "$build_id" -f "$project/poudriere/c9-release.list"
    result=$?
    set -e
    printf '%s\n' "$result" > "$run/exit-status"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$run/finished-at"
    [ "$result" -eq 0 ] || exit "$result"
    verify_build "$build_id"
    ;;
verify)
    [ "$#" -eq 1 ] || usage
    assert_idle
    assert_inputs
    verify_build "$1"
    ;;
*) usage ;;
esac
