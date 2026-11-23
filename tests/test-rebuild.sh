#!/bin/sh
# Exercise the real rebuild orchestrator with isolated fake stage executables.
# No Poudriere build, jail, package installation or production path is modified.
set -eu
set -o pipefail
umask 077
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
LC_ALL=C
export PATH LC_ALL

fail() { printf 'Rebuild regression: %s\n' "$*" >&2; exit 1; }
[ "$#" = 2 ] || fail 'Usage: test-rebuild.sh RUNNER NEW_ABSOLUTE_EVIDENCE_DIRECTORY'
runner=$1
testroot=$2
[ "$(uname -s)" = FreeBSD ] && [ "$(id -u)" = 0 ] || fail 'Run as root on FreeBSD.'
case "$runner" in /*) ;; *) fail 'Runner path must be absolute.' ;; esac
[ -f "$runner" ] && [ ! -L "$runner" ] || fail 'Runner must be a regular file.'
runner=$(realpath "$runner")
printf '%s\n' "$testroot" | grep -Eq '^/usr/local/c9/tests/rebuild-regression-[A-Za-z0-9_-]+$' ||
    fail 'Use a new /usr/local/c9/tests/rebuild-regression-NAME directory.'
[ "$(realpath /usr/local/c9/tests)" = /usr/local/c9/tests ] || fail 'Unexpected evidence parent.'
[ "$(stat -f %u /usr/local/c9/tests)" = 0 ] || fail 'Evidence parent is not root-owned.'
[ ! -e "$testroot" ] && [ ! -L "$testroot" ] || fail 'Preserving existing evidence.'
for tool in awk cmp cp daemon find lockf mkdir ps sha256 sleep stat; do
    command -v "$tool" >/dev/null || fail "Missing required tool: $tool"
done
mkdir -m 0700 "$testroot"
[ "$(realpath "$testroot")" = "$testroot" ] || fail 'Unexpected resolved evidence path.'
runner_sha=$(sha256 -q "$runner")
printf '%s\n' "$runner_sha" > "$testroot/runner.sha256"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "$testroot/started-at"
: > "$testroot/RESULTS.txt"
active_pid=
case_root=
finish() {
    result=$?
    trap - EXIT HUP INT TERM
    set +e
    # Unblock only our synthetic stages. They have a bounded lifetime themselves.
    for control in "$testroot"/*/control; do
        [ -d "$control" ] && [ ! -L "$control" ] || continue
        : > "$control/release"
    done
    if [ -n "$active_pid" ] && kill -0 "$active_pid" 2>/dev/null; then
        command=$(ps -p "$active_pid" -o command= 2>/dev/null)
        case "$command" in *"$testroot/"*) kill -TERM "$active_pid" 2>/dev/null ;; esac
    fi
    printf '%s\n' "$result" > "$testroot/exit-status"
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$testroot/finished-at"
    printf 'Rebuild regression evidence: %s\nExit status: %s\n' "$testroot" "$result"
    exit "$result"
}
trap finish EXIT
trap 'exit 1' HUP INT TERM

pass() { printf 'PASS %s\n' "$*" | tee -a "$testroot/RESULTS.txt"; }
assert_equal() { [ "$1" = "$2" ] || fail "$3: expected [$2], got [$1]"; }
assert_file() { [ -f "$1" ] && [ ! -L "$1" ] || fail "Expected regular file: $1"; }
wait_file() {
    awaited=$1
    count=0
    while [ ! -f "$awaited" ]; do
        count=$((count + 1))
        [ "$count" -lt 200 ] || fail "Timed out waiting for $awaited"
        sleep 0.1
    done
}
assert_no_stage() {
    if [ -f "$control/trace" ] && grep -q "^$1|" "$control/trace"; then
        fail "Unexpected stage executed: $1"
    fi
}
invoke() {
    log=$1
    shift
    set +e
    /bin/sh "$fixture/scripts/c9-rebuild.sh" "$@" > "$case_root/$log.log" 2>&1
    status=$?
    set -e
    printf '%s\n' "$status" > "$case_root/$log.exit-status"
}
make_fixture() {
    name=$1
    case_root=$testroot/$name
    fixture=$case_root/project
    control=$case_root/control
    runs=$case_root/runs
    releases=$case_root/releases
    evidence=$case_root/evidence
    payload=$case_root/payload
    record=$case_root/kernel-record
    mkdir -m 0700 "$case_root" "$fixture" "$control" "$runs" "$releases" "$evidence" "$payload" "$record"
    mkdir "$record/inputs"
    for entry in docs installer scripts ports poudriere tests; do mkdir "$fixture/$entry"; done
    printf 'Fixture documentation; no buildable ports.\n' > "$fixture/README.md"
    printf 'Fixture changelog.\n' > "$fixture/CHANGELOG.md"
    printf 'Fixture license.\n' > "$fixture/LICENSE"
    cp "$runner" "$fixture/scripts/c9-rebuild.sh"
    [ "$(sha256 -q "$fixture/scripts/c9-rebuild.sh")" = "$runner_sha" ] || fail 'Runner copy differs.'
    printf '%s\n' "$control" > "$fixture/poudriere/fixture-control"
    printf 'complete\n' > "$record/phase"
    printf '0\n' > "$record/exit-status"
    printf 'historic-kernel\n' > "$record/inputs/package-build-id"
    printf '15.1-RELEASE-p6\n' > "$record/inputs/kernel-version"
    printf 'ident GENERIC\n' > "$record/inputs/kernel-config"
    printf 'kernel fixture\n' > "$record/inputs/kernel"
    sha256 "$record/inputs/kernel" > "$record/inputs/kernel.sha256"
    printf '15.1-RELEASE-p6\n' > "$payload/freebsd-version"
    printf 'retained base payload sentinel\n' > "$payload/base.txz"
    printf 'retained kernel payload sentinel\n' > "$payload/kernel.txz"
    printf 'base.txz\t%s\t1\n' "$(sha256 -q "$payload/base.txz")" > "$payload/MANIFEST"
    printf 'kernel.txz\t%s\t1\n' "$(sha256 -q "$payload/kernel.txz")" >> "$payload/MANIFEST"
    mkdir "$control/repository" "$control/repository/.real_fixture"
    ln -s .real_fixture "$control/repository/.latest"
    printf 'retained-packages\n' > "$control/repository/.real_fixture/.buildname"
    printf '15.1-RELEASE-p6\n' > "$control/repository/.real_fixture/.jailversion"
    printf 'already-built-package-cache-sentinel\n' > "$control/package-cache"
    sha256 -q "$control/package-cache" > "$control/package-cache.expected"
    cat > "$fixture/installer/release.conf" <<EOF
C9_VERSION=0.2.0
C9_EXPECTED_VERSION=15.1-RELEASE-p6
C9_OSVERSION=1501000
C9_ARCH=amd64
C9_IMAGE_JAIL=c9fixture-image
C9_PACKAGE_JAIL=c9fixture-package
C9_PORTS_TREE=default
C9_OVERLAY=c9fixture-overlay
C9_SET=fixture
C9_MASTER=c9fixture-default-fixture
C9_IMAGE_NAME=C9MANGO020
C9_REPOSITORY=$control/repository
EOF
    cat > "$fixture/poudriere/rebuild.conf" <<EOF
C9_REBUILD_KERNEL_RECORD=$record
C9_REBUILD_PAYLOAD=$payload
C9_REBUILD_RUN_ROOT=$runs
C9_REBUILD_RELEASE_ROOT=$releases
C9_REBUILD_EVIDENCE_ROOT=$evidence
EOF
    cat > "$fixture/scripts/fixture-stage.sh" <<'STAGE'
# Sourced only by synthetic stage siblings, never by a production build helper.
set -eu
set -o pipefail
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
control=$(cat "$project/poudriere/fixture-control")
record_event() {
    printf '%s' "$stage" >> "$control/trace"
    for argument do printf '|%s' "$argument" >> "$control/trace"; done
    printf '\n' >> "$control/trace"
    printf '%s\n' "$$" > "$control/$stage.pid"
    if [ -f "$control/block-stage" ] && [ "$(cat "$control/block-stage")" = "$stage" ]; then
        trap 'printf "cleanup\n" > "$control/cleanup-entered"; if [ -f "$control/cleanup-delay" ]; then sleep 2; fi; printf "terminated\n" > "$control/child-terminated"; exit 143' TERM INT HUP
        : > "$control/entered"
        count=0
        while [ ! -e "$control/release" ]; do
            count=$((count + 1))
            [ "$count" -lt 300 ] || exit 97
            sleep 0.1
        done
    fi
    if [ -f "$control/mutate-stage" ] && [ "$(cat "$control/mutate-stage")" = "$stage" ]; then
        printf '\nUnplanned snapshot change.\n' >> "$project/README.md"
    fi
    if [ -f "$control/fail-stage" ] && [ "$(cat "$control/fail-stage")" = "$stage" ]; then
        exit "$(cat "$control/fail-code")"
    fi
}
STAGE
    cat > "$fixture/scripts/check-image-inputs.sh" <<'STAGE'
#!/bin/sh
. "$(dirname -- "$0")/fixture-stage.sh"
stage=image-inputs
record_event "$@"
kernel_record= payload= kernel_build_id=
while [ "$#" -gt 0 ]; do
    case "$1" in --kernel-record) kernel_record=$2 ;; --payload) payload=$2 ;; --kernel-build-id) kernel_build_id=$2 ;; *) exit 81 ;; esac
    shift 2
done
[ "$(cat "$kernel_record/inputs/package-build-id")" = "$kernel_build_id" ]
[ -s "$payload/base.txz" ] && [ -s "$payload/kernel.txz" ]
STAGE
    cat > "$fixture/scripts/c9-build.sh" <<'STAGE'
#!/bin/sh
. "$(dirname -- "$0")/fixture-stage.sh"
case "$1" in
    configure|plan) stage=$1 ;;
    build) stage=packages ;;
    verify) stage=verify-packages ;;
    *) exit 82 ;;
esac
record_event "$@"
if [ "$1" = build ]; then
    printf '%s\n' "$2" > "$control/repository/.real_fixture/.buildname"
elif [ "$1" = verify ]; then
    [ "$(cat "$control/repository/.real_fixture/.buildname")" = "$2" ]
fi
[ "$(sha256 -q "$control/package-cache")" = "$(cat "$control/package-cache.expected")" ]
STAGE
    cat > "$fixture/scripts/build-iso.sh" <<'STAGE'
#!/bin/sh
. "$(dirname -- "$0")/fixture-stage.sh"
stage=iso
record_event "$@"
build_id= output= payload=
while [ "$#" -gt 0 ]; do
    case "$1" in --build-id) build_id=$2 ;; --output) output=$2 ;; --payload) payload=$2 ;; *) exit 83 ;; esac
    shift 2
done
[ "$build_id" = "$(cat "$control/repository/.real_fixture/.buildname")" ]
[ -s "$payload/base.txz" ]
[ ! -e "$output" ] && [ ! -L "$output" ]
mkdir "$output"
printf 'synthetic ISO for %s\n' "$build_id" > "$output/C9MANGO020.iso"
sha256 "$output/C9MANGO020.iso" > "$output/SHA256"
sha512 "$output/C9MANGO020.iso" > "$output/SHA512"
printf '%s\n' "$build_id" > "$output/package-build-id"
STAGE
    cat > "$fixture/tests/verify-iso.sh" <<'STAGE'
#!/bin/sh
. "$(dirname -- "$0")/../scripts/fixture-stage.sh"
stage=verify-iso
record_event "$@"
release= kernel_record= project_arg= build_id= kernel_build_id= output=
while [ "$#" -gt 0 ]; do
    case "$1" in
        --release-dir) release=$2 ;; --kernel-record) kernel_record=$2 ;;
        --project) project_arg=$2 ;; --build-id) build_id=$2 ;;
        --kernel-build-id) kernel_build_id=$2 ;; --output) output=$2 ;;
        *) exit 84 ;;
    esac
    shift 2
done
[ "$build_id" = "$(cat "$release/package-build-id")" ]
[ "$kernel_build_id" = "$(cat "$kernel_record/inputs/package-build-id")" ]
[ "$project_arg" = "$project" ]
[ -s "$release/C9MANGO020.iso" ]
[ ! -e "$output" ] && [ ! -L "$output" ]
mkdir "$output"
printf 'Synthetic verifier passed.\n' > "$output/RESULTS.txt"
printf '0\n' > "$output/exit-status"
STAGE
    # A real manifest makes a fixture valid even if the input checker requires one.
    (cd "$fixture" && find . -type f ! -name MANIFEST.sha256 -print | sort |
        while IFS= read -r file; do printf '%s  %s\n' "$(sha256 -q "$file")" "${file#./}"; done) > "$fixture/MANIFEST.sha256"
}

make_fixture success
invoke check check --run-id success
assert_equal "$status" 0 'Read-only preflight'
[ ! -e "$runs/success" ] && [ ! -e "$releases/success" ] && [ ! -e "$evidence/iso-success" ] ||
    fail 'check created a run, release or verification directory.'
: > "$control/trace"
invoke run run --run-id success
assert_equal "$status" 0 'Whole foreground pipeline'
assert_equal "$(cat "$runs/success/state")" complete 'Successful durable state'
assert_equal "$(cat "$runs/success/exit-status")" 0 'Successful durable status'
assert_file "$releases/success/C9MANGO020.iso"
assert_file "$runs/success/source/MANIFEST.sha256"
cut -d '|' -f 1 "$control/trace" > "$case_root/stages"
printf 'image-inputs\nconfigure\nplan\npackages\nimage-inputs\niso\nverify-iso\n' > "$case_root/expected-stages"
cmp -s "$case_root/stages" "$case_root/expected-stages" || fail 'Success stage order differs.'
grep -Fx 'packages|build|success' "$control/trace" >/dev/null || fail 'Package run ID not forwarded.'
assert_equal "$(sha256 -q "$control/package-cache")" "$(cat "$control/package-cache.expected")" 'Retained package cache'
pass 'whole pipeline, immutable snapshot, stage order, historical kernel ID and existing package cache'

make_fixture reuse
base_before=$(sha256 -q "$payload/base.txz")
kernel_before=$(sha256 -q "$payload/kernel.txz")
invoke run run --run-id reuse --reuse-build retained-packages --kernel-record "$record" --payload "$payload"
assert_equal "$status" 0 'Explicit published-package reuse'
assert_no_stage packages
assert_no_stage configure
assert_no_stage plan
grep -Fx 'verify-packages|verify|retained-packages' "$control/trace" >/dev/null || fail 'Reuse skipped package verification.'
assert_equal "$(cat "$releases/reuse/package-build-id")" retained-packages 'Reused package ID'
assert_equal "$(sha256 -q "$payload/base.txz")" "$base_before" 'Retained base payload'
assert_equal "$(sha256 -q "$payload/kernel.txz")" "$kernel_before" 'Retained kernel payload'
pass 'explicit package/payload/kernel provenance reuse without rebuilding or modifying retained inputs'

for failure in packages:37 verify-iso:42; do
    failed_stage=${failure%:*}
    failed_code=${failure#*:}
    make_fixture "failure-$failed_stage"
    printf '%s\n' "$failed_stage" > "$control/fail-stage"
    printf '%s\n' "$failed_code" > "$control/fail-code"
    invoke run run --run-id failed
    assert_equal "$status" "$failed_code" "Forwarded $failed_stage exit"
    assert_equal "$(cat "$runs/failed/state")" failed 'Failure durable state'
    assert_equal "$(cat "$runs/failed/exit-status")" "$failed_code" 'Failure durable exit'
    if [ "$failed_stage" = packages ]; then assert_no_stage iso; else assert_file "$releases/failed/C9MANGO020.iso"; fi
    pass "$failed_stage failure stops the pipeline and retains exact status/evidence"
done

make_fixture collision
mkdir "$runs/occupied"
printf 'preserve this run\n' > "$runs/occupied/sentinel"
sentinel=$(sha256 -q "$runs/occupied/sentinel")
invoke run run --run-id occupied
[ "$status" -ne 0 ] || fail 'Existing run was accepted.'
assert_equal "$(sha256 -q "$runs/occupied/sentinel")" "$sentinel" 'Existing run sentinel'
assert_no_stage packages
mkdir "$releases/existing"
printf 'preserve this release\n' > "$releases/existing/sentinel"
sentinel=$(sha256 -q "$releases/existing/sentinel")
invoke release-collision run --run-id existing
[ "$status" -ne 0 ] || fail 'Existing release was accepted.'
assert_equal "$(sha256 -q "$releases/existing/sentinel")" "$sentinel" 'Existing release sentinel'
assert_no_stage packages
pass 'run and release collisions preserve prior artifacts before build stages'

make_fixture unsafe-path
ln -s "$payload" "$case_root/payload-alias"
invoke alias run --run-id alias --payload "$case_root/payload-alias"
[ "$status" -ne 0 ] || fail 'Symlink payload alias was accepted.'
assert_no_stage packages
invoke traversal run --run-id ../escape
[ "$status" -ne 0 ] || fail 'Traversal run ID was accepted.'
[ ! -e "$case_root/escape" ] || fail 'Traversal created an escaped path.'
assert_no_stage packages
pass 'symlink reuse path and traversal run ID rejected before build stages'

make_fixture overlap
printf 'C9_REBUILD_EVIDENCE_ROOT=%s\n' "$fixture/docs" >> "$fixture/poudriere/rebuild.conf"
readme_before=$(sha256 -q "$fixture/README.md")
invoke run run --run-id overlap
[ "$status" -ne 0 ] || fail 'Evidence output beneath the source project was accepted.'
[ ! -e "$fixture/docs/iso-overlap" ] || fail 'Overlapping output was created.'
assert_equal "$(sha256 -q "$fixture/README.md")" "$readme_before" 'Overlap leaves original source intact'
assert_no_stage packages
pass 'source/output overlap rejected before writing into the source tree'

make_fixture lock
printf 'packages\n' > "$control/block-stage"
/bin/sh "$fixture/scripts/c9-rebuild.sh" run --run-id first > "$case_root/first.log" 2>&1 &
active_pid=$!
wait_file "$control/entered"
invoke second run --run-id second
[ "$status" -ne 0 ] || fail 'Concurrent runner was accepted.'
assert_equal "$(grep -c '^packages|' "$control/trace")" 1 'Concurrent package-stage count'
: > "$control/release"
set +e
wait "$active_pid"
status=$?
set -e
active_pid=
assert_equal "$status" 0 'Lock owner completion'
invoke third run --run-id third
assert_equal "$status" 0 'Lock released after completion'
pass 'real lockf serialization rejects a concurrent run and permits a later run'

make_fixture source-change
printf 'packages\n' > "$control/mutate-stage"
original_readme=$(sha256 -q "$fixture/README.md")
invoke run run --run-id changed
[ "$status" -ne 0 ] || fail 'Changed source snapshot was accepted.'
assert_equal "$(cat "$runs/changed/state")" failed 'Changed-source durable state'
assert_no_stage iso
assert_equal "$(sha256 -q "$fixture/README.md")" "$original_readme" 'Original checkout stays separate from snapshot'
pass 'snapshot mutation stops the next expensive stage without modifying original sources'

make_fixture cancellation
printf 'packages\n' > "$control/block-stage"
: > "$control/cleanup-delay"
/bin/sh "$fixture/scripts/c9-rebuild.sh" run --run-id cancelled > "$case_root/cancelled.log" 2>&1 &
active_pid=$!
wait_file "$control/entered"
kill -TERM "$active_pid"
wait_file "$control/cleanup-entered"
invoke during-cleanup run --run-id during-cleanup
[ "$status" -ne 0 ] || fail 'A new run acquired the lock while its predecessor was cleaning up.'
assert_equal "$(grep -c '^packages|' "$control/trace")" 1 'Package-stage count during cancellation cleanup'
wait_file "$runs/cancelled/exit-status"
set +e
wait "$active_pid"
status=$?
set -e
active_pid=
[ "$status" -ne 0 ] || fail 'Cancelled foreground run returned success.'
assert_equal "$(cat "$runs/cancelled/state")" cancelled 'Cancelled durable state'
wait_file "$control/child-terminated"
assert_no_stage iso
: > "$control/release"
invoke recovered run --run-id recovered
assert_equal "$status" 0 'Lock released after cancelled child cleanup'
pass 'TERM reaches child; lock excludes new work during cleanup and releases afterward'

make_fixture daemon
printf 'packages\n' > "$control/block-stage"
invoke start start --run-id background
assert_equal "$status" 0 'Daemon start'
wait_file "$control/entered"
invoke status-running status background
assert_equal "$status" 0 'Running status command'
assert_equal "$(cat "$runs/background/state")" running 'Running daemon state'
: > "$control/release"
wait_file "$runs/background/exit-status"
assert_equal "$(cat "$runs/background/exit-status")" 0 'Background completion status'
assert_equal "$(cat "$runs/background/state")" complete 'Background completion state'
invoke status-complete status background
assert_equal "$status" 0 'Completed status command'
pass 'real daemon execution and status transition from running to complete'

make_fixture daemon-failure
printf 'packages\n' > "$control/fail-stage"
printf '37\n' > "$control/fail-code"
invoke start start --run-id background-failed
assert_equal "$status" 0 'Failed worker was accepted for asynchronous launch'
wait_file "$runs/background-failed/exit-status"
assert_equal "$(cat "$runs/background-failed/exit-status")" 37 'Detached failure status'
assert_equal "$(cat "$runs/background-failed/state")" failed 'Detached failure state'
invoke status-failed status background-failed
assert_equal "$status" 0 'Status query for failed run'
grep -qx 'state: failed' "$case_root/status-failed.log" || fail 'Status output conceals worker failure.'
grep -qx 'exit-status: 37' "$case_root/status-failed.log" || fail 'Status output loses worker exit code.'
assert_no_stage iso
pass 'detached failure remains visible with exact exit status through status'

[ "$(sha256 -q "$runner")" = "$runner_sha" ] || fail 'Runner input changed during regression.'
printf 'All orchestration checks passed; no production build stages executed.\n' >> "$testroot/RESULTS.txt"
cat "$testroot/RESULTS.txt"

