# Local upstream port repairs

These dated records preserve each failure, repair and intermediate result.
The complete package gate passed on 22 November 2026 in
`c9release-20261122T094945Z`, with no failed, skipped or ignored ports.
See [VALIDATION.md](VALIDATION.md) for the final package and image results.

## devel/doxygen: confine documentation font caches

The C9 overlay copies `devel/doxygen` intact from the default FreeBSD ports
tree at commit `e7bc56a5d30dc24ce2e7990926836699cbd34e55`, then applies the
changes described below. The upstream distinfo, description, and existing
patches remain unchanged. The local package is `doxygen-1.18.0_1,2`.

The release build `c9release-20261114T104144Z` on FreeBSD
`15.1-RELEASE-p6/amd64` compiled Doxygen and generated its documentation,
but failed Poudriere's `build_fs_violation` check. Eight entries were added
under `/var/db/fontconfig`: cache versions 9, 10, 11, and 12 for each of
`4c599c202bc5c08e2d34565a40eac3b2` and
`7758ace85a5dee1419d0d5d41073f680`, with the `-le64.cache-` suffix.
The failed log is retained on the build server at
`/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9release-20261114T104144Z/logs/doxygen-1.18.0,2.log`.

Fontconfig 2.18.3's installed configuration lists `/var/db/fontconfig`
before its XDG cache directory. The build already sets `XDG_CACHE_HOME`
inside `WRKDIR`; that setting cannot override the earlier writable system
cache when the build runs as root. Fontconfig writes its current cache and
compatibility links in the first writable cache directory. See the
[Fontconfig configuration reference](https://www.freedesktop.org/software/fontconfig/fontconfig-user.html)
and [2.18.3 cache writer](https://raw.githubusercontent.com/fontconfig/fontconfig/2.18.3/src/fccache.c).

The local Makefile increments `PORTREVISION` to 1. With DOCS enabled,
`pre-configure-DOCS-on` creates a fontconfig wrapper in `WRKDIR` that lists
`WRKDIR/fontconfig-cache` before including the installed system fontconfig
configuration. `DOCS_CONFIGURE_ENV` and `DOCS_MAKE_ENV` select this wrapper
through `FONTCONFIG_FILE`. Font discovery and aliases retain the installed
configuration. The pinned ports framework defaults `TEST_ENV` to
`MAKE_ENV`, so the test target inherits the same cache isolation.

DOCS, GRAPHVIZ, the upstream test target, package content, and Poudriere
checks remain enabled as before. The repair neither removes the generated
files after the fact nor exempts the system cache from filesystem checks.
Doxygen stays a resolved dependency; it is not added to the release list.

Validation status:

- The failure and installed fontconfig configuration were inspected from
  the retained log and built package archive.
- SHA-256 hashes confirmed that distinfo, the description, and both upstream
  patches are identical to the pinned tree.
- FreeBSD `make` metadata checks passed against the pinned ports framework
  in `/tmp/c9-doxygen-review.AjOzqi/doxygen`, with a separate temporary
  `WRKDIR`. The package name is `doxygen-1.18.0_1,2`; DOCS and GRAPHVIZ remain
  enabled, `TEST_TARGET` remains `test`, and IGNORE/BROKEN are unset.
- Effective `CONFIGURE_ENV`, `MAKE_ENV`, and `TEST_ENV` all select the
  generated wrapper. A separate DOCS-disabled metadata check confirmed that
  the override is absent when documentation is disabled.
- The isolated `pre-configure-DOCS-on` hook completed successfully and
  generated the expected XML with the work cache before the system include.
  Neither the active overlay nor the shared ports tree was modified.
- In retry `c9retry-20261115T104611Z`, `doxygen-1.18.0_1,2` passed its full
  package job under `poudriere bulk -t -r`, with DOCS and the original QA
  checks enabled. It completed at bulk elapsed `00:13:13` after a package
  build time of 12 minutes 58 seconds. Compilation, filesystem, staging,
  package, installation/deinstallation and leftovers checks passed; the
  original font-cache violation did not recur.
- The successful package log is
  `/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9retry-20261115T104611Z/logs/doxygen-1.18.0_1,2.log`.
  The complete release build and verification remain unfinished.

## devel/desktop-file-utils: remove both generated application caches

The C9 overlay copies all six files of `devel/desktop-file-utils` from the
same pinned ports commit, `e7bc56a5d30dc24ce2e7990926836699cbd34e55`.
Only the Makefile's new `PORTREVISION=1` and the cleanup section of
`files/desktop-file-utils.ucl.in` differ. The private package is
`desktop-file-utils-0.29_1`; upstream sources and application selection stay
unchanged.

In `c9release-20261114T104144Z`, desktop-file-utils 0.29 compiled, passed
staging/plist checks, packaged, installed, and was removed. Poudriere then
failed the leftovers check because `share/applications/intent.cache` remained.
The log explicitly records that the `desktop-file-utils.ucl` cleanup trigger
ran. The retained failure log is:

```text
/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9release-20261114T104144Z/logs/desktop-file-utils-0.29.log
```

The inspected 0.29 source archive defines both `mimeinfo.cache` and
`intent.cache`; `update_databases()` writes the MIME cache followed by
the intent cache. The
[pinned ports cleanup trigger](https://raw.githubusercontent.com/freebsd/freebsd-ports/e7bc56a5d30dc24ce2e7990926836699cbd34e55/devel/desktop-file-utils/files/desktop-file-utils.ucl.in)
only removed the former. This explains the leftover even when no application
desktop files remain.

The local cleanup loops over the two generated cache names using the existing
`pkg.stat`/`os.remove` behavior. The existing directory check still removes
`share/applications` only when empty, preserving any application desktop files.
The install/update trigger, post-install script, plist, upstream test target,
and Poudriere filesystem checks are unchanged. This is a cleanup repair, not a
leftovers exemption or a dependency removal.

Validation completed in isolated temporary files, without changing the active
overlay, shared ports tree, package database, or Poudriere configuration:

- SHA-256 comparisons confirmed `distinfo`, `pkg-descr`, `pkg-plist`, and
  `files/pkg-post-install.lua.in` are identical to the pinned upstream files.
  Direct diffs confirmed the other two changes are limited to the revision
  and cleanup loop.
- FreeBSD `make` metadata evaluation in
  `/tmp/c9-desktop-file-utils.Kuusaw/desktop-file-utils`, with separate
  temporary work/options paths, reports `desktop-file-utils-0.29_1`.
  `USES`, Bash test dependency, `TEST_TARGET=test`, and post-install script
  selection remain intact; `IGNORE` and `BROKEN` are empty.
- [`tests/desktop-file-utils-cleanup.lua`](../tests/desktop-file-utils-cleanup.lua)
  executes the actual cleanup body using FreeBSD's `/usr/libexec/flua` and
  real temporary files. A small LuaFileSystem adapter supplies the documented
  `pkg.stat`/`pkg.readdir` filesystem interface; this is not a full pkg
  installation/deinstallation test.
- All six cleanup fixtures passed: both caches, intent cache alone, MIME
  cache alone, empty directory, both caches with an application file, and an
  application file without caches. Application-file contents were preserved;
  empty application directories were removed.
- Running the same fixture against the original upstream trigger failed at
  the intended regression assertion: `both: intent cache remains`.

In retry `c9retry-20261115T104611Z`, `desktop-file-utils-0.29_1` passed its
full package job under `poudriere bulk -t -r`, including the original
build/staging/package, installation/deinstallation and leftovers checks.
It completed at bulk elapsed `00:00:22`, with a package build time of seven
seconds. The original `intent.cache` leftover did not recur. The successful
package log is
`/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9retry-20261115T104611Z/logs/desktop-file-utils-0.29_1.log`.
This verifies the repair under actual Poudriere QA; the complete release
build remains in progress.

## devel/electron43: bound Yarn archive processing within existing limits

The first full release run, `c9release-20261114T104144Z`, finished after
13 hours 21 minutes with 474 packages built, three failures, and 23 skipped
dependents. Electron 43.8.7 failed during its Yarn 4.18.0 dependency fetch,
before compilation, with `Failed to reserve virtual memory for CodeRange`
in Node's worker-isolate initialization. LLVM 22 and Node dependencies are
now cached. Retry `c9retry-20261115T104611Z` finished at 20:01 UTC on
2026-11-15 after about 9 hours 15 minutes, with 20 packages built, two
failures, and four skipped dependents. Doxygen and desktop-file-utils passed
actual package QA as recorded above. Firefox failed in its JavaScript
bundler; Electron passed its dependency fetch and later failed while
running V8's snapshot generator, as detailed below.

Yarn's archive task pool defaults to the parallelism reported by Node,
independently of `MAKE_JOBS_NUMBER`. Its worker mode creates additional Node
isolates for archive conversion; async mode performs the same conversion
through a limited queue in the main isolate. See the exact Yarn 4.18.0
[configuration](https://raw.githubusercontent.com/yarnpkg/berry/@yarnpkg/cli/4.18.0/packages/yarnpkg-core/sources/Configuration.ts),
[task pool](https://raw.githubusercontent.com/yarnpkg/berry/@yarnpkg/cli/4.18.0/packages/yarnpkg-core/sources/TaskPool.ts),
and [archive conversion](https://raw.githubusercontent.com/yarnpkg/berry/@yarnpkg/cli/4.18.0/packages/yarnpkg-core/sources/tgzUtils.ts).
The pinned ports `Mk/Uses/npm.mk` passes `MAKE_ENV` to the dependency-fetch
command, so compile-job settings alone do not constrain this work.

Focused tests ran in an ephemeral Poudriere reference jail with Node
24.22.2 and Electron's exact bundled Yarn 4.18.0 and immutable lockfile.
Node reported 12 available CPUs. Both tests used fresh caches and identical
limits: 8 GiB virtual memory, 512 MiB stack, 2,048 open files, and core dumps
disabled. No resource limit was increased.

| Yarn archive pool | Result | Elapsed | Maximum resident memory | Swaps |
| --- | --- | --- | --- | --- |
| Workers, concurrency 2 | Exit 134; `Committing semi space failed` | 16.52 s | 555,968 KiB | 0 |
| Async, concurrency 2 | Exit 0; fetch and link completed | 18.06 s | 856,464 KiB | 0 |

The successful test fetched 1,033 packages totaling 328.23 MiB. The failure
at low resident memory and success under the same virtual-memory ceiling
support address-space pressure from worker isolates as the relevant cause.
Merely reducing the worker count to two did not resolve it.

The repair is scoped in
[`poudriere/c9-release-make.conf.example`](../poudriere/c9-release-make.conf.example):

```make
.if !empty(.CURDIR:M*/devel/electron43)
MAKE_ENV+= YARN_TASK_POOL_MODE=async YARN_TASK_POOL_CONCURRENCY=2
.endif
```

Actual FreeBSD `make` evaluation with this configuration supplied through
`__MAKE_CONF` confirmed that Electron receives both variables, while Foot
and VS Code receive neither. `MAKE_JOBS_NUMBER` remains 2, the build set
retains two builders, and application selections and QA checks are unchanged.

Test scripts, source hashes, and logs are preserved on the server under
`/usr/local/c9/tests/node-memory-20261115T103725Z`, including
`yarn-workers2.log` and `yarn-async2.log`. The test reference jail was stopped
and the extra repository mount unmounted after validation.

During actual `poudriere bulk -t -r` retry `c9retry-20261115T104611Z`,
Electron's Yarn dependency fetch also succeeded: 1,033 dependencies totaling
328.23 MiB, completed in 22.614 seconds. The port completed source fetching
and reached 52% of its compile commands. This confirms the Yarn repair in
the actual bulk fetch environment; the later snapshot failure is a separate
issue. Its retained log is
`/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9retry-20261115T104611Z/logs/electron43-43.8.7.log`.
The complete Electron package and overall release build remain pending.

## devel/electron43: approved V8 snapshot address-space exception

At command 22,786 of 43,425 in the same retry, the freshly compiled
`mksnapshot` failed while generating `gen/v8/embedded.S` and
`snapshot_blob.bin`. The retained log reports:

```text
Fatal process out of memory: Failed to reserve the virtual address space for the V8 sandbox
```

The package job ended at 20:00:25 UTC on 2026-11-15 after 9 hours 12 minutes
20 seconds. Nearby Rust compiler commands are unrelated to this fatal
message. The compiled snapshot generator has `V8_ENABLE_SANDBOX` enabled.

Electron 43.8.7 pins Chromium 150.0.7871.250, which pins V8 revision
`c6e16522def1bf4dc2c91e54f5bfffa459168417`. The exact source was inspected
from the pinned Chromium distfile, without extracting the entire source
tree again. Its amd64 full sandbox reservation is:

| Region | Virtual address extent |
| --- | --- |
| Sandbox | 1,024 GiB |
| Two guard regions | 2 × 64 GiB |
| Additional trailing guard | 224 GiB |
| Total, before other process mappings | **1,376 GiB** |

The [pinned V8 constants](https://github.com/v8/v8/blob/c6e16522def1bf4dc2c91e54f5bfffa459168417/include/v8-internal.h#L218)
and [sandbox allocation code](https://github.com/v8/v8/blob/c6e16522def1bf4dc2c91e54f5bfffa459168417/src/sandbox/sandbox.cc#L187)
define these extents. If the full reservation fails, V8 tries progressively
smaller partial reservations down to 8 GiB. That minimum alone exhausts the
former 8 GiB process ceiling, leaving no room for the executable and other
mappings. Upstream also documents that partial reservations lack the full
sandbox's security properties. The approved remedy therefore provides room
for the full sandbox and keeps its security features enabled.

**Approved and installed on 16 November 2026; Electron's complete build and
package QA subsequently passed, as checked on 22 November.** The source file is
[`poudriere/c9-package-limits.conf.example`](../poudriere/c9-package-limits.conf.example),
installed at
`/usr/local/etc/poudriere.d/c9151amd64-default-c9-poudriere.conf`:

```sh
MAX_MEMORY=8
MAX_MEMORY_electron43=2048
```

Poudriere 3.4.8 documents [per-package limits in GiB](https://github.com/freebsd/poudriere/blob/3.4.8/src/etc/poudriere.conf.sample).
Inspection of the installed implementation confirmed that this most-specific
configuration loads last, and `electron43-43.8.7` selects the exact key
`MAX_MEMORY_electron43`. Every package starts in a fresh background process,
so the Electron override does not become the next package's default.
The [limit application code](https://raw.githubusercontent.com/freebsd/poudriere/3.4.8/src/share/poudriere/common.sh)
uses `/usr/bin/limits -v`, setting both the soft and hard virtual-memory
ceilings. A value of zero is a zero-byte limit, an empty override falls back
to the default, and the word `unlimited` is unsuitable for Poudriere's
integer-GiB conversion.

The approved 2 TiB ceiling permits virtual-address reservations; it does not
allocate 2 TiB of physical RAM. It applies to processes in the Electron
package job, with all other packages retaining 8 GiB. There is no separate
8 GiB resident-memory cap for Electron in this mechanism. Two builders,
two compile jobs per package, the existing file-descriptor limit, and
disk-backed work directories remain unchanged. The prior configuration was
backed up under
`/usr/local/c9/backups/electron-address-limit-20261116T051731Z`.

Read-only validation used the installed package-name conversion and limit
selection expression in isolated shell processes: Electron selected
2,048 GiB, Firefox and VS Code selected 8 GiB, and the parent retained 8 GiB.
`limits -e -v 2199023255552` accepted the proposed value and printed
`ulimit -v 2147483648` in KiB; this display-only check did not apply it.
Full validation subsequently passed for Electron 43.8.7 in
`c9release-20261116T052133Z`: its standard V8 snapshot generator, complete
build and Poudriere package QA succeeded after approximately 20 hours
21 minutes. The run finished on 17 November and was checked on 22 November.
VS Code failed later in its separate TypeScript compilation and
`c9-apps-development` was skipped. The signed repository generation is
`.real_1794880991`. Complete release verification remains pending.

## www/firefox: run the new-tab minifier in the existing Node isolate

The C9 overlay copies all 43 files of `www/firefox` from ports commit
`e7bc56a5d30dc24ce2e7990926836699cbd34e55`. It adds `PORTREVISION=1` and
`files/patch-browser_extensions_newtab_webpack.system-addon.config.js`.
The resulting package name is `firefox-160.0_1,2`; the source version,
distinfo, existing upstream patches, and application features are unchanged.

In retry `c9retry-20261115T104611Z`, the unmodified Firefox port failed while
generating its new-tab JavaScript bundles. `build-newtab-bundles.py` invoked
the vendored webpack CLI through Node 24.22.2; Node aborted with
`NewSpace::EnsureCurrentCapacity Allocation failed - JavaScript heap out of memory`.
The final garbage-collection entry reported about 61 MiB of live JavaScript
objects and 186 MiB of heap capacity, so this failure alone does not establish
that the bundle needs a larger JavaScript heap. The retained package log is:

```text
/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9retry-20261115T104611Z/logs/firefox-160.0,2.log
```

The exact `webpack.system-addon.config.js` creates a `MinimizerPlugin` with
its default `parallel: true`. The vendored plugin uses `jest-worker` with
Node worker threads and caps their number by the number of assets. The vendor
configuration produces one bundle, so this is not an unrestricted pool of
one worker per CPU. The Python launcher copies its inherited environment
and supplies no Node heap flags.

The local patch adds only `parallel: false` to that minifier. It keeps
`minimize: true`, the same Terser implementation and options, both webpack
configurations, and both JavaScript outputs. Minification runs in the existing
Node isolate. This changes build execution, without removing minification,
browser features, dependencies, or Poudriere QA checks. The two-builder,
two-compile-job policy and 8 GiB process virtual-memory limit stay unchanged.

Focused reproduction used the preserved Firefox 160.0 source subset and
vendored Node modules, plus the already-built Node 24.22.2 package and its
runtime libraries. Tests ran as `daniel` outside the active build jail, in
separate output directories. Each used the same limits: 8 GiB virtual memory,
512 MiB stack, 2,048 open files, and disabled core dumps. No package was
installed on the host and no active port, jail, or Poudriere configuration
was changed.

| Configuration | Result | Elapsed | Maximum resident memory | Swaps |
| --- | --- | --- | --- | --- |
| Original minifier | Exit 134; original heap failure reproduced | 3.47 s | 578,460 KiB | 0 |
| `parallel: false` | Exit 0; both bundles generated | 6.72 s | 466,312 KiB | 0 |
| `parallel: false`, fresh-output confirmation | Exit 0; both bundles generated | 5.53 s | 453,304 KiB | 0 |

The successful builds produced a minimized vendor bundle of about 399 KiB
and an activity-stream bundle of about 1.32 MiB. Separate trials with only
`--v8-pool-size=2`, `--max-old-space-size=1024`, or
`--disable-wasm-trap-handler` still failed. Those flags are not applied by
the repair. The paired tests support worker-isolate address-space pressure
as the relevant failure mechanism; they do not measure every individual
virtual-memory reservation.

Provenance and checks:

- The pinned source archive is `firefox-160.0.source.tar.xz`, SHA-256
  `2b23d2bf6716ea16b45c10aa5c275c78a1d7ff50ad53150809ab27424c58fd81`,
  as recorded in the unchanged upstream `distinfo`.
- The pristine webpack configuration has SHA-256
  `18107252dc012b04b3794c091b230632a7aacefa0e94428bd3419fdbae43e5c4`.
  It was preserved unchanged; test configurations were separate files.
- All 42 copied upstream files other than the revised Makefile were compared
  with the pinned server tree by SHA-256 and matched. The pinned port directory
  was clean according to Git.
- FreeBSD `patch` applied the new patch at line 68 without fuzz or offset in
  a separate source copy. Its result was byte-for-byte identical to the
  successfully tested serial-minifier configuration.
- FreeBSD `make` metadata from the temporary overlay reports
  `firefox-160.0_1,2`, with `IGNORE` and `BROKEN` unset. The approved
  `MAKE_JOBS_NUMBER=2` remains accepted; the existing DBUS, FFMPEG, JACK,
  OPTIMIZED_CFLAGS, PROFILE, PULSEAUDIO, and SNDIO selections remain enabled.

Scripts, logs, source subset, temporary overlay, and generated outputs are
retained under `/usr/local/c9/tests/firefox-memory-20261115T141354Z`.
The successful logs are `logs/serial-test.log` and
`logs/serial-confirm.log`; the temporary patch and metadata review is in
`port-review/`. The local patch SHA-256 is
`e8057ee3e2fb5df6c8f64e3b8e7bf837b1c4670e88084e2e19210d9060693eba`.

The repair was deployed at 20:33 UTC on 2026-11-15 in the 143-file source
archive with SHA-256
`1a71092b8a9d950f98709229e1af9bf3c881f59868eca48942fae0009012e115`.
Retry `c9firefox-20261115T203301Z` started at 20:34 UTC with three queued
packages: Firefox, `c9-apps-essential`, and `c9-workstation`, reusing the
existing compatible packages. It finished at 22:59 UTC on 15 November after
about 2 hours 25 minutes, with **three built, zero failed and zero skipped**.
Firefox and both dependent C9 packages passed their full Poudriere package
checks under the original 8 GiB virtual-address limit. The signed repository
generation is `.real_1794783552`. Nine C9 packages at version 0.2.0 are now
available; only Electron, VS Code, and `c9-apps-development` remain unbuilt.
Complete release verification remains pending. The Electron exception was
approved and installed the following morning and did not affect this retry.

## editors/vscode: native TypeScript compiler resource limits

The final package retry `c9release-20261116T052133Z` built Electron but failed
VS Code 1.145.1 in `compile-client`. Its `build/lib/tsgo.ts` wrapper filters
compiler output to TypeScript diagnostic lines, hiding the Go runtime's fatal
error and leaving only `tsgo exited with code 2` in the build log.

On 22 November, a focused cold run of the exact native TypeScript 7.0.2
compiler and `src/tsconfig.json` reproduced a Go heap allocation failure at
the original 8 GiB process virtual-address ceiling. The direct invocation
used `--noEmit --incremental` and a separate typecheck build-info path, as
the actual build does. It ran as `daniel` using extracted packages; no host
packages were installed. Records are under
`/usr/local/c9/tests/vscode-tsgo-20261122`.

Reducing Go scheduler threads to two, setting a 4 GiB soft garbage-collection
target, and reducing compiler checker instances to two or one did not make
the compile fit. The one-checker trial failed after 70 seconds at about
6.8 GiB resident memory. A separate garbage-collection trace still showed
6,114 MiB of live heap immediately before failure. The Go soft target cannot
reclaim live compiler data; see the
[Go garbage-collector guide](https://go.dev/doc/gc-guide#Memory_limit).
These trials kept all type checks enabled and did not change production
sources or server policy.

The user approved and the server installed these VS Code-only exceptions
on 22 November:

```sh
MAX_MEMORY_vscode=16
MAX_FILES_vscode=8192
```

The memory value is a per-process virtual-address ceiling in GiB, not a RAM
reservation. The open-file value is required by the pinned port's own
`pre-everything` message; an open-file failure was not observed in the
compiler reproduction. Other packages retain their 8 GiB and 2,048-file
defaults, except the previously approved Electron memory exception.
Two builders, two compile jobs and disk-backed work directories are retained.
The prior resource policy is saved under
`/usr/local/c9/backups/vscode-limits-20261122T092006Z`.

The exact cold compiler command passed under these approved limits with
`GOMAXPROCS=2 GOMEMLIMIT=6GiB`: exit 0, no compiler diagnostics, 101.85 seconds
wall time, maximum resident memory 10,380,080 KiB (about 9.9 GiB), and zero
reported swaps. The standard four checker instances and all type checks
were retained. The successful log is
`logs/approved-gomaxprocs2-gomemlimit6g.log`; the reproduction script is
`approved-limits.sh` in the same test directory.

The C9 make policy supplies those two environment variables only for
`editors/vscode`. No VS Code source patch or extra overlay port is needed.
The 6 GiB setting is Go's soft collection target, not a hard resident-memory
ceiling. VS Code subsequently passed full Poudriere build and package QA in
`c9release-20261122T092234Z`, after approximately 23 minutes. The main
TypeScript compilation finished with zero errors at 09:30 UTC. Its package
is retained in signed generation `.real_1795340785`. The Development
meta-package then failed a separate Python dependency QA rule; complete
release verification remains required.

## devel/c9-apps-development: declare the Python runtime through USES

The first actual build of this meta-port reached `stage-qa` on 22 November
and rejected its direct dependency on `lang/python3`. The pinned ports
framework requires ports to select a specific interpreter through `USES`.
The port now declares `USES=metaport python:3.12,run` and removes the generic
Python dependency. It retains the previously selected Python 3.12 runtime,
available as `python3.12`, and all five other application dependencies.

Actual FreeBSD make evaluation selects
`/usr/local/bin/python3.12:lang/python312`, with no build dependencies,
flavors, IGNORE or BROKEN values. `python312-3.12.16` is already built.
No successful Development package had yet been published, so its initial
version remains 0.2.0. Retry `c9release-20261122T094945Z` subsequently passed:
one built, zero failed/skipped/ignored. At 09:50 UTC on 22 November, the full
signed repository, 545-package installation plan and runtime archive hashes
also passed verification. QA was retained throughout.
