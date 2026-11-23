# Building C9 0.2.0 packages

For the complete automated package-to-ISO pipeline, use
[Automated rebuild](AUTOMATED-REBUILD.md).

For the complete edit/deploy/rebuild procedure, use
[Customize and rebuild](CUSTOMIZE-AND-REBUILD.md). It covers package identity,
installer-only repeats and matching kernel provenance for a new package run.

Build and verify the complete release on the existing Poudriere server before
creating an ISO or installing a VM. Keep an active run's overlay and
configuration unchanged until it finishes. Never install an incomplete
`.building` repository. See [VALIDATION.md](VALIDATION.md) for dated progress
and [POUDRIERE-SERVER.md](POUDRIERE-SERVER.md) for the operational history.

## Recorded inputs

[`installer/release.conf`](../installer/release.conf) supplies the checked
inputs shared by package and image scripts.

| Input | Value |
| --- | --- |
| Server | `daniel@192.168.178.55`, root access through `doas` |
| Source deployment | `/usr/local/c9/c9-desktop-mango-0.2.0` |
| Package jail | `c9151amd64`, `15.1-RELEASE-p6`, `amd64` |
| Full ports tree | `default` |
| Ports commit | `e7bc56a5d30dc24ce2e7990926836699cbd34e55` |
| Partial overlay / set | `c9overlay` / `c9` |
| Build master | `c9151amd64-default-c9` |
| Repository | `/usr/local/poudriere/data/packages/c9151amd64-default-c9` |
| Public signing key | `/usr/local/etc/ssl/certs/poudriere.cert` |

The registered overlay points at
`/usr/local/c9/c9-desktop-mango-0.2.0/ports`. The original 0.1.0 source directory
is retained. `configure` changes registration only when the C9 jail is idle;
keep the registered source directory in place. The server already has the package
jail, full tree, signing key, caches and approved C9 resource configuration.
See [REPRODUCE.md](REPRODUCE.md) for another server. Do not silently update the
shared ports tree or replace the recorded jail with a moving release target.

## Configure, plan, build and verify

After deploying the complete source, run on the FreeBSD server:

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0

# Requires an idle C9 jail and saves prior configuration.
doas sh scripts/c9-build.sh configure

# Resolve the complete release list without compiling.
doas sh scripts/c9-build.sh plan

# Use a new build ID; compile and recursively test all release packages.
doas sh scripts/c9-build.sh build c9-0.2.0-release1

# Recheck the completed, published build before image creation.
doas sh scripts/c9-build.sh verify c9-0.2.0-release1
```

`build` already invokes verification after a successful Poudriere exit.
Keep its build ID: the image builder must receive that same completed,
published repository generation.

The wrapper checks jail version/architecture, ports commit, clean base tree
and overlay registration. It runs `poudriere bulk -t -r` using
[`c9-release.list`](../poudriere/c9-release.list). All custom packages, both
optional application groups, both hardware profiles and their dependencies
are included. Compatible packages already built for `c9151amd64-default-c9`
are reused. Only missing, changed or dependency-invalidated packages need
rebuilding; no clean/rebuild-all option is used.

When a port fails, allow unaffected work to finish before applying an overlay
repair and retrying with a fresh build ID. Resuming the failed build ID does
not retry its recorded failed or skipped ports. The installed Poudriere 3.4.8
has no supported drain command: termination signals stop running builders.
Retain completed packages and the original failure logs. Local upstream port
repairs and their validation are recorded in [PORTS-PATCHES.md](PORTS-PATCHES.md).

The approved C9 policy uses two builders, disk-backed work directories and up
to two compile jobs per builder. The release make configuration disables
Thunar's unused trash-panel applet; the pinned upstream Thunar port still
requires xfce4-panel, which C9 does not start. Other existing resource limits
and signing configuration remain inherited.

The desktop's Fuzzel/Mako/Swaybg selection is fixed in 0.2.0. Old `LAUNCHER`,
`NOTIFICATIONS` and `WALLPAPER` options no longer apply. Development and Office
are separate packages selected at installation, not desktop build options.
Use the release list and release make configuration. The earlier single-port
list describes the 0.1.0 workflow; the legacy option example now points to the
release policy.

## Completion evidence

Verification requires a completed build with zero failed, skipped and ignored
ports, and a published repository whose build ID matches the request. It
checks the signed catalog, required packages, C9 versions and an installation
plan against an empty temporary package database. It does not install packages
into the build host.

Retain `/usr/local/c9/runs/BUILD_ID/` and Poudriere's logs under
`/usr/local/poudriere/data/logs/bulk/c9151amd64-default-c9/BUILD_ID/`, together
with the source, options, resource configuration, ports revision, inventory and
public key. The private signing key stays on the server.

Only after verification succeeds, follow [INSTALLER.md](INSTALLER.md) to build
an ISO. The image builder separately checks package payloads and matched
patched base/kernel inputs. Repository verification alone does not demonstrate
offline installation or graphics.

## Troubleshooting

| Failure | Action |
| --- | --- |
| C9 jail is active | Wait; do not change its current inputs |
| Overlay points elsewhere | Run `configure` from the intended deployment when idle |
| Jail/ports revision differs | Restore recorded inputs or deliberately prepare another release |
| Port fails or is skipped | Diagnose logs and use a fresh build ID for retries |
| Missing package or wrong C9 version | Build the complete release list; old 0.1.0 output is insufficient |
| Signature verification fails | Check the signing/public-key configuration; keep verification enabled |
| Repository belongs to another build | Use the actual completed published generation |
| Intel setup rejects kernel | Use matched 15.1-RELEASE-p6 kernel/module packages |

The C9 source maintainer contact is `c9_project@proton.me`; the project account
is [C9Project](https://github.com/C9Project). Previously built packages retain
their original contact metadata until rebuilt with a suitable release identity.
