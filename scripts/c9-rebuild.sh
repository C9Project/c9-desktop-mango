#!/bin/sh
# Incremental package build -> offline ISO -> static verification, on FreeBSD.
set -eu
set -o pipefail
umask 022
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
LC_ALL=C
export PATH LC_ALL

fail() { printf 'C9 rebuild: %s\n' "$*" >&2; exit 1; }
usage() {
    cat >&2 <<EOF
Usage: $0 check
       $0 start|run [--run-id ID] [--reuse-build ID]
           [--kernel-record DIR] [--payload DIR]
       $0 status RUN_ID
start detaches; run stays in the foreground. check does not change the server.
Default: configure, plan, incremental package build, ISO, static verification.
--reuse-build verifies an already published build and skips package building.
EOF
    exit 2
}
valid_id() {
    case "$1" in ''|.|..|-*|*[!a-zA-Z0-9_.-]*) fail "Invalid ID: $1" ;; esac
    [ "${#1}" -le 100 ] || fail 'ID is too long.'
}
safe_dir() {
    local path current mode
    path=$1
    case "$path" in /*) ;; *) fail "Path must be absolute: $path" ;; esac
    case "$path" in *[!a-zA-Z0-9_./-]*) fail "Unsafe path: $path" ;; esac
    [ -d "$path" ] && [ ! -L "$path" ] && [ "$(realpath "$path")" = "$path" ] ||
        fail "Use an existing canonical directory without symlinks: $path"
    current=$path
    while :; do
        [ "$(stat -f %u "$current")" = 0 ] || fail "Directory must belong to root: $current"
        mode=$(stat -f %Lp "$current")
        [ "$((0$mode & 0022))" = 0 ] || fail "Directory must not be group/world writable: $current"
        [ "$current" = / ] && break
        current=${current%/*}
        [ -n "$current" ] || current=/
    done
}
safe_file() {
    local mode
    safe_dir "$(dirname "$1")"
    [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -f %u "$1")" = 0 ] ||
        fail "Expected a root-owned regular file: $1"
    mode=$(stat -f %Lp "$1")
    [ "$((0$mode & 0022))" = 0 ] || fail "File must not be group/world writable: $1"
}
separate() {
    case "$1/" in "$2/"*) fail "Paths must not overlap: $1 and $2" ;; esac
    case "$2/" in "$1/"*) fail "Paths must not overlap: $1 and $2" ;; esac
}
fresh() { [ ! -e "$1" ] && [ ! -L "$1" ] || fail "Preserving existing path: $1"; }
stamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
[ "$(uname -s)" = FreeBSD ] || fail 'Run on the FreeBSD Poudriere server.'
safe_file "$project/installer/release.conf"
safe_file "$project/poudriere/rebuild.conf"
. "$project/installer/release.conf"
. "$project/poudriere/rebuild.conf"
valid_id "$C9_MASTER"
valid_id "$C9_PACKAGE_JAIL"
action=${1:-}
[ "$#" -gt 0 ] && shift || usage
run_id= reuse_build=
kernel_record=$C9_REBUILD_KERNEL_RECORD
payload=$C9_REBUILD_PAYLOAD
case "$action" in
    status|_worker) [ "$#" -eq 1 ] || usage; run_id=$1; shift ;;
    check|start|run) ;;
    *) usage ;;
esac
while [ "$#" -gt 0 ]; do
    [ "$#" -ge 2 ] || usage
    case "$1" in
        --run-id) run_id=$2 ;;
        --reuse-build) reuse_build=$2 ;;
        --kernel-record) kernel_record=$2 ;;
        --payload) payload=$2 ;;
        *) usage ;;
    esac
    shift 2
done
for directory in "$C9_REBUILD_RUN_ROOT" "$C9_REBUILD_RELEASE_ROOT" "$C9_REBUILD_EVIDENCE_ROOT"; do
    safe_dir "$directory"
done
separate "$C9_REBUILD_RUN_ROOT" "$C9_REBUILD_RELEASE_ROOT"
separate "$C9_REBUILD_RUN_ROOT" "$C9_REBUILD_EVIDENCE_ROOT"
separate "$C9_REBUILD_RELEASE_ROOT" "$C9_REBUILD_EVIDENCE_ROOT"
if [ "$action" = status ]; then
    valid_id "$run_id"
    run="$C9_REBUILD_RUN_ROOT/$run_id"
    safe_dir "$run"
    for item in run-id state phase package-build-id kernel-build-id started-at finished-at exit-status release-dir verification-dir; do
        if [ -f "$run/$item" ]; then
            printf '%s: %s\n' "$item" "$(cat "$run/$item")"
        fi
    done
    printf 'Logs: %s/logs/\nConsole: %s/console.log\n' "$run" "$run"
    exit 0
fi
[ "$(id -u)" = 0 ] || fail 'Run with doas/root.'
for tool in lockf daemon sha256 tar find sort cmp jls; do
    command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done

# Both the inventory and hash cover hidden desktop templates. No source symlinks
# or unusual filenames are accepted. A snapshot gets its own fresh manifest.
inventory() (
    cd "$1"
    set -- README.md CHANGELOG.md LICENSE docs installer scripts ports poudriere tests
    [ -z "$(find "$@" ! -type f ! -type d -print)" ] || fail 'Source contains symlinks or special files.'
    find "$@" -type f | sort | while IFS= read -r file; do
        case "$file" in *[!a-zA-Z0-9_./-]*) fail "Unsupported source filename: $file" ;; esac
        printf '%s  %s\n' "$(sha256 -q "$file")" "$file"
    done
)
idle() {
    local names
    names=$(jls -n name) || fail 'Cannot inspect active jails.'
    if printf '%s\n' "$names" | awk -v jail="$C9_PACKAGE_JAIL" '
        {for (i=1;i<=NF;i++) if ($i == "name=" jail || index($i, "name=" jail "-") == 1) active=1}
        END {exit !active}'; then
        fail 'The package jail is active. Wait for its current build to finish.'
    fi
}
preflight() {
    idle
    for file in scripts/c9-build.sh scripts/build-iso.sh scripts/check-image-inputs.sh tests/verify-iso.sh; do
        safe_file "$project/$file"
        /bin/sh -n "$project/$file"
    done
    /bin/sh "$project/scripts/check-image-inputs.sh" --kernel-record "$kernel_record" \
        --payload "$payload" --kernel-build-id "$kernel_build_id"
}
if [ "$action" != _worker ]; then
    safe_dir "$kernel_record"
    safe_dir "$payload"
    safe_file "$kernel_record/inputs/package-build-id"
    kernel_build_id=$(cat "$kernel_record/inputs/package-build-id")
    valid_id "$kernel_build_id"
    [ -z "$reuse_build" ] || valid_id "$reuse_build"
    if [ "$action" = check ]; then
        inventory "$project" >/dev/null
        preflight
        printf 'Read-only preflight passed. Package policy and ports are checked again by configure/plan during a run.\n'
        exit 0
    fi
    run_id=${run_id:-c9rebuild-$(date -u +%Y%m%dT%H%M%SZ)}
    valid_id "$run_id"
    run="$C9_REBUILD_RUN_ROOT/$run_id"
    release="$C9_REBUILD_RELEASE_ROOT/$run_id"
    evidence="$C9_REBUILD_EVIDENCE_ROOT/iso-$run_id"
    package_build_id=${reuse_build:-$run_id}
    for output in "$run" "$release" "$evidence"; do
        fresh "$output"
        for input in "$project" "$kernel_record" "$payload"; do separate "$output" "$input"; done
    done
    if [ -z "$reuse_build" ]; then
        fresh "/usr/local/poudriere/data/logs/bulk/$C9_MASTER/$package_build_id"
    fi
    mkdir -m 0755 "$run"
    setup_exit() {
        result=$?
        trap - EXIT
        if [ "$result" -ne 0 ]; then
            printf 'failed\n' > "$run/state"
            printf '%s\n' "$result" > "$run/exit-status"
            stamp > "$run/finished-at"
        fi
        exit "$result"
    }
    trap setup_exit EXIT
    printf '%s\n' "$run_id" > "$run/run-id"
    printf 'starting\n' > "$run/state"
    printf 'snapshot\n' > "$run/phase"
    stamp > "$run/started-at"
    mkdir "$run/source" "$run/logs"
    inventory "$project" > "$run/source-before.sha256"
    [ ! -f "$project/MANIFEST.sha256" ] || cp "$project/MANIFEST.sha256" "$run/original-MANIFEST.sha256"
    tar -cf - -C "$project" README.md CHANGELOG.md LICENSE docs installer scripts ports poudriere tests |
        tar -xf - -C "$run/source" --no-same-owner --no-same-permissions
    find "$run/source" -type d -exec chmod 0755 {} +
    find "$run/source" -type f -exec chmod 0644 {} +
    inventory "$run/source" > "$run/source/MANIFEST.sha256"
    cmp "$run/source-before.sha256" "$run/source/MANIFEST.sha256" || fail 'Source changed while making the snapshot.'
    inventory "$project" > "$run/source-after.sha256"
    cmp "$run/source-before.sha256" "$run/source-after.sha256" || fail 'Source changed while making the snapshot.'
    sha256 -q "$run/source/MANIFEST.sha256" > "$run/source-manifest.sha256"
    printf '%s\n' "$project" > "$run/original-project"
    printf '%s\n' "$package_build_id" > "$run/package-build-id"
    printf '%s\n' "$reuse_build" > "$run/reuse-build"
    printf '%s\n' "$kernel_build_id" > "$run/kernel-build-id"
    printf '%s\n' "$kernel_record" > "$run/kernel-record"
    printf '%s\n' "$payload" > "$run/payload"
    printf '%s\n' "$release" > "$run/release-dir"
    printf '%s\n' "$evidence" > "$run/verification-dir"
    printf 'queued\n' > "$run/phase"
    if [ "$action" = start ]; then
        # Redirection belongs to the worker, so daemon shutdown cannot close a
        # logging pipe while a child is still cleaning up. No automatic retries.
        daemon -f -P "$run/supervisor.pid" -p "$run/worker.pid" \
            /bin/sh "$run/source/scripts/c9-rebuild.sh" _worker "$run_id"
        trap - EXIT
        printf 'Started run: %s\nLog: %s/console.log\nStatus: sh %s/scripts/c9-rebuild.sh status %s\n' \
            "$run_id" "$run" "$project" "$run_id"
        exit 0
    fi
    trap - EXIT
    printf 'Run: %s\nLog: %s/console.log\n' "$run_id" "$run"
    exec /bin/sh "$run/source/scripts/c9-rebuild.sh" _worker "$run_id"
fi

# Internal worker: only operates on its own retained source snapshot.
valid_id "$run_id"
run="$C9_REBUILD_RUN_ROOT/$run_id"
safe_dir "$run"
[ "$project" = "$run/source" ] || fail 'Internal worker must run from its saved snapshot.'
fresh "$run/exit-status"
mkdir "$run/.worker" || fail 'This run already has a worker; use a new run ID.'
exec >> "$run/console.log" 2>&1
child= cancelled=no launching=no
finish() {
    result=$?
    trap - EXIT HUP INT TERM
    if [ "$cancelled" = yes ]; then
        printf 'cancelled\n' > "$run/state"
    elif [ "$result" = 0 ] && [ "$(cat "$run/phase")" = complete ]; then
        printf 'complete\n' > "$run/state"
    else
        [ "$result" -ne 0 ] || result=1
        printf 'failed\n' > "$run/state"
    fi
    stamp > "$run/finished-at"
    printf '%s\n' "$result" > "$run/exit-status"
    printf '%s finished: %s (exit %s)\n' "$(stamp)" "$(cat "$run/state")" "$result"
    exit "$result"
}
cancel() {
    cancelled=yes
    # A signal between spawning the stage and assigning $! must not orphan it.
    [ "$launching" = no ] || return 0
    trap '' HUP INT TERM
    if [ -n "$child" ]; then
        /bin/kill -TERM -- "-$child" 2>/dev/null || :
        wait "$child" 2>/dev/null || :
        # A helper can exit before one of its descendants finishes cleanup.
        # Retain the lock until the entire owned process group has gone away.
        while /bin/kill -0 -- "-$child" 2>/dev/null; do sleep 1; done
    fi
    exit 143
}
trap finish EXIT
trap cancel HUP INT TERM
printf 'lock\n' > "$run/phase"
lock="$C9_REBUILD_RUN_ROOT/.c9-rebuild-$C9_MASTER.lock"
[ ! -e "$lock" ] || safe_file "$lock"
[ ! -L "$lock" ] || fail 'Lock cannot be a symlink.'
# FD-only lockf leaves the lock held by this inherited open file description.
# The worker retains FD9 throughout work and cleanup; helpers may reuse theirs.
exec 9>> "$lock"
lockf -t 0 9
printf 'running\n' > "$run/state"
package_build_id=$(cat "$run/package-build-id")
reuse_build=$(cat "$run/reuse-build")
kernel_build_id=$(cat "$run/kernel-build-id")
kernel_record=$(cat "$run/kernel-record")
payload=$(cat "$run/payload")
release=$(cat "$run/release-dir")
evidence=$(cat "$run/verification-dir")
valid_id "$package_build_id"
valid_id "$kernel_build_id"
fresh "$release"
fresh "$evidence"
verify_snapshot() {
    [ "$(sha256 -q "$project/MANIFEST.sha256")" = "$(cat "$run/source-manifest.sha256")" ] || fail 'Snapshot manifest changed.'
    inventory "$project" > "$run/source-check.sha256"
    cmp "$project/MANIFEST.sha256" "$run/source-check.sha256" || fail 'Snapshot source changed; preserve this run and start a new one.'
}
stage() {
    local name result
    name=$1
    shift
    printf '%s\n' "$name" > "$run/phase"
    verify_snapshot
    printf '%s %s\n' "$(stamp)" "$name" | tee -a "$run/progress.log"
    # Job control gives this stage its own group, including its subprocesses.
    set -m
    launching=yes
    "$@" > "$run/logs/$name.log" 2>&1 &
    child=$!
    launching=no
    set +m
    [ "$cancelled" = no ] || cancel
    if wait "$child"; then result=0; else result=$?; fi
    child=
    printf '%s\n' "$result" > "$run/logs/$name.exit-status"
    [ "$result" = 0 ] || exit "$result"
}
stage preflight preflight
if [ -z "$reuse_build" ]; then
    stage configure /bin/sh "$project/scripts/c9-build.sh" configure
    stage plan /bin/sh "$project/scripts/c9-build.sh" plan
    stage packages /bin/sh "$project/scripts/c9-build.sh" build "$package_build_id"
else
    stage verify-packages /bin/sh "$project/scripts/c9-build.sh" verify "$package_build_id"
fi
stage image-inputs preflight
stage iso /bin/sh "$project/scripts/build-iso.sh" --build-id "$package_build_id" \
    --output "$release" --payload "$payload"
stage verify-iso /bin/sh "$project/tests/verify-iso.sh" --release-dir "$release" \
    --kernel-record "$kernel_record" --project "$project" --build-id "$package_build_id" \
    --kernel-build-id "$kernel_build_id" --output "$evidence"
verify_snapshot
printf 'complete\n' > "$run/phase"
printf 'Verified ISO: %s/%s.iso\nChecksums: %s/SHA256 and SHA512\n' "$release" "$C9_IMAGE_NAME" "$release"
