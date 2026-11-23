# C9 Poudriere server setup

Configured and dry-run verified on 13 November 2026. The initial 0.1.0 package
build completed on 14 November. The first expanded 0.2.0 run finished with
474 built, three failed and 23 skipped packages. The next retry completed
20 packages with two failures; the subsequent Firefox retry passed all three
queued packages. On 22 November, Electron and VS Code had passed their retries;
Development passed after correcting its Python runtime declaration. All ten
C9 0.2.0 packages are available and complete signed-repository verification
passed, including a 545-package installation plan. The p6 image jail and ISO
are complete, static verification passed, and BIOS offline installation and
SDDM authentication/reboot tests passed. EFI offline installation with both
optional groups and the same authentication/reboot checks also passed.
The dated records below retain earlier states; the last section records the
latest deployment and retry. Current build instructions are in
[BUILD.md](BUILD.md).

## Initial connection and 0.1.0 build inputs

- SSH: `ssh daniel@192.168.178.55`; root commands use `doas`.
- Server: `chzhs05.dragon.lab`, FreeBSD `15.1-RELEASE-p6`, amd64.
- Installed package: `poudriere-3.4.8`; version command reports `poudriere-git-3.4.8`.
- New jail: `c9151amd64`, FreeBSD `15.1-RELEASE-p6`, amd64, created with the HTTP method.
- Jail path: `/usr/local/poudriere/jails/c9151amd64`.
- Existing full ports tree: `default`, branch `main`.
- Verified ports commit: `e7bc56a5d30dc24ce2e7990926836699cbd34e55`.
- Root-owned C9 sources: `/usr/local/c9/c9-desktop-mango-0.1.0`.
- Partial overlay: `c9overlay`, registered with method `null` at the source directory's `ports/` path.
- Build set: `c9`; build master: `c9151amd64-default-c9`.
- Port list: `/usr/local/c9/c9-desktop-mango-0.1.0/poudriere/c9-desktop-mango.list`.
- Requested package: `c9-desktop-mango-0.1.0`.

The existing `15-1-R-amd64` jail and `default` ports checkout were retained. The shared ports checkout was not updated. Updating it later changes C9's dependencies, so record its new commit for each build.

## Historical initial C9 configuration

`/usr/local/etc/poudriere.d/c9-poudriere.conf`:

```sh
PARALLEL_JOBS=2
PREPARE_PARALLEL_JOBS=2
USE_TMPFS=no
RESOLV_CONF=/etc/resolv.conf
ALLOW_MAKE_JOBS=yes
```

`/usr/local/etc/poudriere.d/c9-make.conf`:

```make
x11_c9-desktop-mango_SET_FORCE= LAUNCHER NOTIFICATIONS WALLPAPER
MAKE_JOBS_NUMBER=2
```

These files apply when `-z c9` is supplied. Fuzzel, Mako, and Swaybg are enabled. Compilation work directories are disk-backed. Other settings are inherited, including the distfiles and ccache directories, memory/file limits, existing license policy, network policy, and repository signing. The pre-existing `ZROOTFS=/dev/null` setting was retained; the new jail's dataset is `zroot/dev/null/jails/c9151amd64`.

The existing private signing key remains `/usr/local/etc/ssl/keys/poudriere.key`. Its matching public key is `/usr/local/etc/ssl/certs/poudriere.cert`. The public key's SHA-256 fingerprint, calculated from DER SubjectPublicKeyInfo, is `2fb9d32aee137ad3a58de5326c63ca4144d74d7fcfcc64a9da1507c37d41bba1`. No private key was copied from the server.

## Verification completed

- All 14 files listed in the original `MANIFEST.sha256` matched locally and after upload.
- Port metadata resolved to the expected package name, all three enabled options, and 11 direct runtime dependencies. The port reported no `IGNORE` or `BROKEN` reason.
- The new jail was created and updated successfully to `15.1-RELEASE-p6`.
- Poudriere's dependency-resolution dry run exited with status 0 and planned **294 packages using 2 builders**: 0 built, 0 failed, 0 skipped, 0 ignored, 0 fetched.
- The dry run mounted the full tree and C9 overlay, loaded the C9 make configuration, and copied the host DNS configuration into its temporary jail.

Saved dry-run transcript: `/usr/local/c9/logs/c9151amd64-default-c9-plan-20261113.log`.

Poudriere logs: `/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/2026-11-13_15h36m05s`.

## Historical 0.1.0 plan/build commands

These commands record the initial single-port workflow. Do not use its old
port list for the expanded 0.2.0 release; follow [BUILD.md](BUILD.md). Both the
complete tree (`-p default`) and overlay (`-O c9overlay`) were used with `-z c9`.

```sh
# Repeat dependency resolution without compiling.
doas poudriere bulk -n -j c9151amd64 -p default -O c9overlay -z c9 \
  -f /usr/local/c9/c9-desktop-mango-0.1.0/poudriere/c9-desktop-mango.list

# Future validation: builds missing dependencies and tests the meta-port.
doas poudriere testport -j c9151amd64 -p default -O c9overlay -z c9 \
  -o x11/c9-desktop-mango

# Future deliverable build: generates the package repository.
doas poudriere bulk -j c9151amd64 -p default -O c9overlay -z c9 \
  -f /usr/local/c9/c9-desktop-mango-0.1.0/poudriere/c9-desktop-mango.list
```

At initial setup, the last two commands were **not run**. A later recursive build/test run is recorded below. A successful dependency plan does not prove that every dependency compiles or that the desktop starts.

Future package output: `/usr/local/poudriere/data/packages/c9151amd64-default-c9/`. The existing nginx configuration maps this to `http://192.168.178.55/packages/c9151amd64-default-c9/`. Package metadata will be available only after a successful build. Clients must be configured to trust the public signing key before using the signed repository.

At that initial stage, the other C9 configuration/artwork/application packages
were not implemented. They are now included in the 0.2.0 source and release
list. The old source directory is retained; the latest record below identifies
the current overlay registration.

The maintainer address remains the documented private-build placeholder; replace it before publishing the port. This server record is an added operational document and is not covered by the original archive manifest.
## Full build paused for shutdown — 13 November 2026

The user requested a full source build with recursive package tests. Run `c9-20261113T144442Z` used `poudriere bulk -t -r`, the same jail, tree, overlay, and C9 set, and two builders. The user then requested a stop so the machine could be shut down.

Poudriere stopped cleanly at approximately 16:55 Europe/Zurich after 1 hour 10 minutes. Its SIGTERM cleanup handler removed every running build jail. The wrapper recorded exit status 1 because the run was deliberately interrupted, not because a port failed.

- 294 packages queued; **215 built and tested successfully**, 79 remaining.
- 0 failed, 0 skipped, 0 ignored.
- All 215 completed package archives remain under `/usr/local/poudriere/data/packages/c9151amd64-default-c9/.building/`.
- Rust `1.99.1_1` and LLVM `19.1.7_5` were compiling when stopped. Their incomplete builds must restart; the persistent compiler cache may help.
- The final C9 meta-package and signed repository are not yet complete.
- Run record: `/usr/local/c9/runs/c9-20261113T144442Z/`.
- Build logs: `/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9-20261113T144442Z/`.

The following historical command restarted the 0.1.0 run on 14 November.
That run has since completed. A fresh build name is needed when retrying
recorded failures or skipped ports:

```sh
ssh daniel@192.168.178.55
doas poudriere bulk -t -r -j c9151amd64 -p default -O c9overlay -z c9 \
  -B c9-20261114T082555Z \
  -f /usr/local/c9/c9-desktop-mango-0.1.0/poudriere/c9-desktop-mango.list
```

Keep the existing ports revision and options to reuse the completed packages. No clean/rebuild-all flag is needed. This records the stop on 13 November. See the restart record below for the current state.
## IP change and build restart — 14 November 2026

The server is now reached at `192.168.178.55` using the same `daniel` account and SSH key. Poudriere's `URL_BASE` and nginx's `server_name` were updated. nginx configuration validation and reload succeeded. Original server configuration files were backed up under `/usr/local/c9/backups/ip-change-20261114T082508Z/`.

At reconnect, the old build logs contained a later attempt with three fetch failures (`print/harfbuzz`, `lang/vala`, `x11-fonts/libXft`) and 15 skipped ports. Each failure reported `Transient resolver failure`. These records postdated the clean stop documented above. The ports revision and C9 options were unchanged.

DNS and HTTPS access were verified from inside the Poudriere network-enabled reference jail against the exact source URLs for all three failed ports. All succeeded. The temporary verification jail was stopped. The dashboard and repository metadata were also reachable at the new address. No resolver or interface configuration changes were required.

A fresh build name was used because resuming the old named run would preserve its failed/skipped results. Dependency-plan validation confirmed 79 packages remaining, with completed package archives reused.

- Restarted build ID: `c9-20261114T082555Z`.
- Runner, input snapshots, console log and exit status: `/usr/local/c9/runs/c9-20261114T082555Z/`.
- Poudriere logs: `/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9-20261114T082555Z/`.
- Dashboard: `http://192.168.178.55/build.html?mastername=c9151amd64-default-c9&build=c9-20261114T082555Z`.
- Started with `bulk -t -r`, two builders, and disk-backed work directories, retaining the original jail, base tree, overlay, options, and signing key.

The build was running when this restart record was written. A final package and signed-repository validation is still required after completion.
### Approved compilation concurrency change

On 14 November, the user approved up to two compile jobs inside each of the two builders. `ALLOW_MAKE_JOBS=yes` was added to the C9 Poudriere configuration and `MAKE_JOBS_NUMBER=2` to its make configuration. Existing memory limits and disk-backed work directories were retained. Ports marked unsafe for parallel builds can still use one job.

The run was stopped cleanly with 2 newly completed packages (Cairo and Vala), 0 failures, and 77 remaining. The same build ID was restarted after verifying effective LLVM arguments `-j2` and Rust job count `2`. Completed packages and the compiler cache were preserved.

Runner record and console log for that attempt:
`/usr/local/c9/runs/c9-20261114T082555Z/restart-20261114T084307Z/`.
Its `exit-status` and `finished-at` files describe the completed restart; the
parent directory describes the deliberately stopped earlier attempt.

## 0.1.0 completed; 0.2.0 release started — 14 November 2026

The restarted `c9-20261114T082555Z` run completed all 79 remaining packages,
with **zero failed, skipped or ignored ports**. Its restart `finished-at` is
`2026-11-14T15:32:24Z`. Together with the 215 earlier completed packages, the
initial selection produced 294 packages. The original 0.1.0 source deployment
was retained.

After the jail became idle, C9 0.2.0 configuration was applied. The `null`
overlay registration now points to
`/usr/local/c9/c9-desktop-mango-0.2.0/ports`. The previous registration and
configuration were backed up under
`/usr/local/c9/backups/release-config-20261114T153245Z/`. The package jail,
base-tree commit, build set and signing key remain the same. All ten C9 ports'
metadata was evaluated on the server; the original 0.2.0 deployment verified
86 source-file hashes.

The complete release run `c9release-20261114T104144Z` started at 15:33 UTC with
500 additional packages queued. Compatible existing packages were reused;
the old `c9-desktop-mango-0.1.0` package was replaced by the release selection.
No rebuild-all was requested. At **18:58 UTC** its snapshot was:

- 188 built, 1 failed, 15 skipped, 296 remaining.
- Recursive build/tests remained enabled with the approved two builders and
  up to two compile jobs per builder.
- Logs: `/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9release-20261114T104144Z/`.
- Dashboard: `http://192.168.178.55/build.html?mastername=c9151amd64-default-c9&build=c9release-20261114T104144Z`.

Doxygen compiled but failed `build_fs_violation` because documentation
generation wrote caches under `/var/db/fontconfig`. The local overlay repair
and focused validation are recorded in [PORTS-PATCHES.md](PORTS-PATCHES.md).
At that snapshot, the local source had 92 files after adding that overlay and
its repair record. The repair had **not** changed the active build's overlay.

Retry `c9retry-20261114T182419Z` was queued to wait for the current build to
finish. Its guard allowed the prepared repair only if Doxygen remained the
sole failed origin, followed by a fresh build ID so failed/skipped packages
could be retried while retaining successful compatible packages. Additional
failures stopped that automatic continuation for review. The installed
Poudriere has no supported scheduling-drain facility; letting unaffected jobs
finish preserves their compilation work.

The environment-clearing image-hook wrapper and installer dialog-output fixes
also passed focused FreeBSD fixtures. These source checks are not boot tests.
No image jail, ISO or VM installation has been created. Complete package and
signed-repository verification remains mandatory before image creation, with
physical Dell/UHD630 desktop validation kept separate from VirtualBox login
testing.

## Expanded run completed; reviewed fixes deployed — 15 November 2026

Run `c9release-20261114T104144Z` completed after 13 hours 21 minutes with
**474 built, three failed, 23 skipped and zero ignored**. The failed origins
were:

| Origin | Failure |
| --- | --- |
| `devel/doxygen` | `build_fs_violation`: documentation tools wrote system font caches |
| `devel/desktop-file-utils` | Leftovers: `share/applications/intent.cache` remained after removal |
| `devel/electron43` | Fetch: Yarn's Node workers failed to reserve virtual memory for CodeRange |

Earlier queued retries refused superseded or unreviewed failure sets. Each
of the three failures was then reviewed; [PORTS-PATCHES.md](PORTS-PATCHES.md)
records the fixes and focused validation. Doxygen now directs documentation
font caches into its work directory. The desktop-file-utils cleanup trigger
removes both generated application caches. Electron alone receives
`YARN_TASK_POOL_MODE=async` and `YARN_TASK_POOL_CONCURRENCY=2` through the C9
make configuration. Its isolated exact-Yarn fetch succeeded under the same
8 GiB virtual-memory, 512 MiB stack and 2,048-open-file limits; the package
build itself remains unverified.

Once the build master was idle, the 99-source-file archive was deployed to
`/usr/local/c9/c9-desktop-mango-0.2.0`, retaining the overlay registration at
that directory's `ports/` path. Deployment records identify the archive by
SHA-256:

```text
ec079a9f4804634d2402ca783af3633b030a39713d79a46460ae051aaa3a1978
```

Backups made before applying the reviewed repairs:

- Prior source: `/usr/local/c9/backups/source-before-reviewed-fixes-20261115T104538Z`.
- Prior release configuration: `/usr/local/c9/backups/release-config-20261115T104539Z`.

The new dependency plan confirmed **26 remaining packages**, reusing
compatible completed packages. The recursive build/test retry started at
**10:46 UTC on 15 November**:

- Build ID: `c9retry-20261115T104611Z`.
- Attempt: `attempt-20261115T104612Z`.
- Run record: `/usr/local/c9/runs/c9retry-20261115T104611Z/attempt-20261115T104612Z/`.
- Poudriere logs: `/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/c9retry-20261115T104611Z/`.
- Dashboard: `http://192.168.178.55/build.html?mastername=c9151amd64-default-c9&build=c9retry-20261115T104611Z`.

The jail, pinned base tree, build set, signing key, two builders, two compile
jobs per builder, disk-backed work directories and existing resource limits
were retained. No rebuild-all or QA exemption was introduced. The retry is
in progress at this snapshot; the full package set and ISO are not complete.
Repository verification remains required before image creation.

This update to `POUDRIERE-SERVER.md` and `VALIDATION.md` was made locally
after deployment. These documentation edits are not part of the 99-file
archive identified above and have not themselves been uploaded by this
documentation task.

## Retry progress and Firefox repair — 15 November 2026

In `c9retry-20261115T104611Z`, desktop-file-utils and Doxygen passed their
complete recursive package checks, resolving both filesystem failures.
Waybar and `c9-desktop-defaults-0.2.0` also completed. Electron's actual Yarn
fetch succeeded and its Chromium compilation continued.

Firefox subsequently failed webpack bundle generation near 14:12 UTC.
The exact command reproduced the failure at the 8 GiB virtual-address
ceiling with approximately 570 MiB resident memory. A local upstream overlay
for `firefox-160.0_1,2` keeps minification enabled but runs it in the main
process. Two focused bundle-generation tests passed under the same limits.
Inputs and logs are saved in
`/usr/local/c9/tests/firefox-memory-20261115T141354Z/`.

The Firefox repair is prepared locally and has not modified the active
overlay. It must be deployed only after the current run finishes, then built
and checked under a fresh build ID. Completed packages and compiler cache
remain available for that retry. Full package verification, ISO creation,
and VM installation remain pending.

The reviewed Firefox retry is queued as `c9retry-20261115T160742Z`. Its
durable runner is `/usr/local/c9/runs/c9retry-20261115T160742Z/continue.sh`;
`phase`, `console.log`, and `continuation-exit-status` in that directory
record its result. It waits for the current runner to finish and permits
deployment only if Firefox is the sole failure, the two skipped origins
are Essential and workstation, no packages are ignored, the source hashes
still match, and the C9 jails are idle. Any other failure stops the retry
for review. It then backs up the source, deploys the repair, plans, builds,
and verifies the repository using a fresh build ID.

The queued 143-source-file archive has SHA-256
`1a71092b8a9d950f98709229e1af9bf3c881f59868eca48942fae0009012e115`.
It includes the Firefox overlay and prior repair records. This paragraph
was added locally after that archive was prepared; the queued archive
remains immutable. No ISO or VirtualBox action is queued by this runner.

## Firefox passed; Electron exception approved — 16 November 2026

Run `c9retry-20261115T104611Z` finished at 20:01 UTC on 15 November after
about 9 hours 15 minutes, with **20 built, two failed and four skipped**.
The additional Electron failure stopped the earlier guarded Firefox
continuation for review. Electron's Yarn fetch repair succeeded, but at
52% of its build commands `mksnapshot` could not reserve virtual addresses
for the V8 sandbox. Its full reservation needs 1,376 GiB before other
process mappings. The failure and source evidence are recorded in
[PORTS-PATCHES.md](PORTS-PATCHES.md).

After the original retry finished, the reviewed 143-file source archive
identified above was deployed at 20:33 UTC. The dedicated Firefox retry
`c9firefox-20261115T203301Z` started at 20:34 UTC and finished at 22:59 UTC
on 15 November, after about 2 hours 25 minutes:

- Three packages built, zero failed and zero skipped.
- `firefox-160.0_1,2`, `c9-apps-essential-0.2.0`, and
  `c9-workstation-0.2.0` passed complete Poudriere package QA.
- Signed repository generation: `.real_1794783552` under
  `/usr/local/poudriere/data/packages/c9151amd64-default-c9`.
- Nine C9 packages at version 0.2.0 are available. Electron, VS Code and
  `c9-apps-development` remain unbuilt.

The Firefox retry retained the 8 GiB virtual-address ceiling. On 16 November,
the user approved the separate Electron exception, and this master-specific
configuration was installed:

```text
/usr/local/etc/poudriere.d/c9151amd64-default-c9-poudriere.conf
```

```sh
MAX_MEMORY=8
MAX_MEMORY_electron43=2048
```

The pre-change backup is
`/usr/local/c9/backups/electron-address-limit-20261116T051731Z`.
The policy raises only Electron's process virtual-address ceiling to 2 TiB;
other packages retain 8 GiB. It permits the V8 sandbox reservation and does
not allocate that amount of physical RAM. The two-builder, two-compile-job
policy, file-descriptor limit and disk-backed work directories are unchanged.
Poudriere applies the package override in a fresh subprocess, so it does not
carry over to subsequent package jobs.

The next retry will process the three remaining packages using the same jail,
pinned ports tree, build set and completed compatible packages. Its ID will
be recorded once started. Execution of `mksnapshot` under the new limit,
the complete Electron package and final release verification remain pending.
No image jail, ISO or VM installation has been created. These documentation
updates are local changes after the archived deployment described above.

## Active final package retry — 16 November 2026

`c9release-20261116T052133Z` started at 05:21 UTC. The complete release list
resolves to three remaining builds: Electron 43, VS Code, and
`c9-apps-development`; all compatible completed packages are reused.
The actual Electron job header confirms the approved 2 TiB virtual-address
ceiling. Other packages retain the 8 GiB limit.

The deployed 144-source-file archive has SHA-256
`a6d8541b9d8446784b8119a666bad3b0d1393d51698163b92506bc2b8a19c24f`.
Prior source and configuration are saved in
`/usr/local/c9/backups/source-before-electron-limit-20261116T052052Z` and
`/usr/local/c9/backups/release-config-20261116T052053Z`.

The durable runner is `/usr/local/c9/runs/c9release-20261116T052133Z/`.
Check `phase`, `console.log`, and `runner-exit-status`; the helper runs full
repository verification after a successful bulk build. On the user's request,
chat monitoring stopped while the server build continued. No ISO or VM action
is queued. Resume by checking this run before making further changes.

The packaged Mango parse check remains pending. Its isolated preparation
record is `/usr/local/c9/tests/mango-config-20261116T052319Z`; unprivileged
pkg database ownership was rejected before archive fetching or execution.
No host package installation or compositor was started. This operational
note was added locally after the deployed archive was prepared.

## Electron passed; VS Code failed — checked 22 November 2026

`c9release-20261116T052133Z` completed at 02:03:11 UTC on 17 November,
after approximately 20 hours 41 minutes. The result was **one built, one
failed, one skipped and zero ignored**. The durable runner records
`phase=failed` and `runner-exit-status=2`.

- Electron 43.8.7 passed its full build and package QA after about 20 hours
  21 minutes. The approved address-space exception allowed the standard
  V8 sandbox and snapshot generator to complete.
- VS Code 1.145.1 failed in `compile-client`: its TypeScript wrapper reported
  `tsgo exited with code 2` while filtering the underlying diagnostic output.
- `c9-apps-development` was skipped because VS Code was unavailable.

The published signed repository generation is `.real_1794880991`.
Electron and all other compatible completed packages are available for
reuse. Nine C9 packages are present; Development remains missing.
At the 22 November check, no Poudriere build was running. The VS Code
failure is being reproduced in isolation before selecting a repair. ISO
creation remains gated on a complete successful package run and signed
repository verification.

## VS Code repair and complete release retry — 22 November 2026

The hidden compiler error was reproduced as Go heap exhaustion at the
8 GiB virtual-address ceiling. The user approved `MAX_MEMORY_vscode=16`
and `MAX_FILES_vscode=8192`. These limits were installed with the prior
configuration saved in
`/usr/local/c9/backups/vscode-limits-20261122T092006Z`.
All other resource limits and the two-builder/two-compile-job settings
were retained. The exact cold TypeScript check passed with
`GOMAXPROCS=2 GOMEMLIMIT=6GiB`, no source patch and no disabled checks;
[PORTS-PATCHES.md](PORTS-PATCHES.md) records its evidence.

The updated 144-source-file archive has SHA-256
`3a2afb87356e5aa47f6dba9cd73ed172a8119f6ca5d7495f4ee16007fe52918b`.
Deployment verified every file hash before replacing the idle source tree.
Prior source and make configuration are saved in
`/usr/local/c9/backups/source-before-vscode-limits-20261122T092202Z` and
`/usr/local/c9/backups/release-config-20261122T092203Z`.

The dependency plan resolved exactly two remaining packages: VS Code and
`c9-apps-development`. Run `c9release-20261122T092234Z` started at 09:22 UTC,
reusing Electron and all other compatible completed packages. Its actual
VS Code log confirms a 16 GiB address ceiling, 8,192 open files and the
scoped Go environment. The durable run directory is
`/usr/local/c9/runs/c9release-20261122T092234Z/`.
The runner performs complete signed-repository verification after a
successful bulk result. ISO creation remains gated on that success.

Extracted-package checks also passed for the actual Mango configuration and
user-default preservation; see [VALIDATION.md](VALIDATION.md). The wallpaper
was visually checked. None of these checks establishes VM installation,
authentication or physical graphics behavior.

These operational notes were added locally after the archived deployment;
they are not part of its recorded source hash.

## All packages verified; image workflow started — 22 November 2026

The previous retry completed VS Code successfully but failed Development's
dependency QA: a port must not depend on the generic `lang/python3` meta-port.
The Development port now uses `USES=metaport python:3.12,run`; all other
package inputs are unchanged. Python 3.12 was already built.

The 147-file source archive deployed for the final retry has SHA-256
`d06192ae4aafca0194eecc3119548eb5845f1b3b108fadf25ab2df63fda98cd6`.
Backups are `/usr/local/c9/backups/source-before-image-preparation-20261122T094902Z`
and `/usr/local/c9/backups/release-config-20261122T094903Z`.
The plan confirmed only Development needed building.

`c9release-20261122T094945Z` passed with **one built, zero failed, zero skipped
and zero ignored**. At **09:50:39 UTC**, complete verification passed:
all ten C9 packages at 0.2.0, signed catalog, 545-package installation plan,
and runtime package archive hashes. The published generation is
`.real_1795341030`; verification evidence is `/usr/local/c9/verify.y1ioIsPy`.

The durable runner now sequences image preparation and ISO creation, stopping
on any error. Its records are:

- Run: `/usr/local/c9/runs/c9release-20261122T094945Z/`.
- Kernel/image-jail preparation: `/usr/local/c9/image-inputs/c9-0.2.0-p6-20261122T094945Z/`.
- Planned ISO output: `/usr/local/c9/releases/c9-0.2.0-20261122T094945Z/`.

Read the run's `phase`, `package-status`, `console.log` and eventual
`runner-exit-status`. Preparation has its own `phase`, `progress.log`,
`logs/` and `exit-status`. `package-status=verified` records the completed
package gate independently of later image progress. `runner.sh` saves the
exact commands. An ISO success still requires boot/install validation.

Preparation keeps the approved p6 kernel target: current HTTP updates are
p7, and the historical official p6 binary kernel reports p5. The new helper
authenticates the retained p6 source, builds standard GENERIC with two jobs
in private directories, then imports a separate jail without later updates.
See [INSTALLER.md](INSTALLER.md) for the proof and reproduction procedure.
These notes were written locally after the deployed source archive.
## ISO completed and installed offline — 22 November 2026

Image preparation finished successfully at approximately 10:44 UTC, retaining
its standard source-built GENERIC kernel, matching p6 base/source and a
restorable `c9image151amd64` jail archive. The first ISO attempt stopped because
an ABI-only pkg override inferred OSVERSION 1500000. Supplying the actual
1501000 alongside the ABI corrected that check without weakening it.

ISO run `c9iso-20261122T104752Z` completed with exit 0 at approximately
11:10 UTC. Its source archive SHA-256 is
`9a05464a19b7a74a7eb07607a484d2da407a9e7445502a46597e650249fd440a`.
The completed image is:

```text
/usr/local/c9/releases/c9-0.2.0-20261122T104752Z/C9MANGO020.iso
6238750720 bytes
ead71c8b7e0c44032861305619e734690fea9600d6996ef5a69a3e345c8c3a2b  SHA256
```

The static verifier passed at 11:15:09 UTC; evidence is
`/usr/local/c9/tests/iso-20261122T104752Z-v3`. Its BIOS-padding comparison repair
changed the validator only. The complete local ISO matched the server hash at
12:04:15 UTC. Original build inputs and the released ISO are retained unchanged.

Offline VirtualBox installations passed with Essential only on BIOS (445
packages), and Essential plus Development and Office on EFI (542 packages).
Both booted with the ISO detached, rejected wrong SDDM passwords, authenticated
nonroot test sessions, returned to SDDM on logout and required authentication
after actual software reboots. The temporary X11 sessions serve only these VM
authentication tests. Native Mango and graphical application acceptance remain
for the physical Dell/Intel target; package-upgrade preservation is separate.

The test evidence index is
`/usr/local/c9/tests/vm-20261122T100429Z/files/INDEX.md`. See
[VALIDATION.md](VALIDATION.md) for exact hashes, timelines and test limitations.
The user-confirmed VirtualBox EFI shutdown hang was handled with host power-off
after the guest completed shutdown; it was not pursued further.

The original E: USB volume reported hardware I/O errors during ISO transfer.
The recovered Windows source and current documentation are under
`C:\Users\DPeyer\AppData\Local\C9VMTests\20261122T100429Z\project-recovery`.
The complete verified ISO is under the sibling `release-20261122T104752Z`.
No disk repair was attempted. The build server and repository were unaffected.

Final documentation and test-helper synchronization preserves all 106 port
files and the existing production installer/build scripts. The original ISO
source snapshot remains in its recorded inputs; later documentation and
validation helpers do not require rebuilding packages or reissuing the ISO.
