# C9 desktop Mango

Project account: [C9Project](https://github.com/C9Project).
Maintainer: [c9_project@proton.me](mailto:c9_project@proton.me).
The configured source-control remote is `https://github.com/C9Project/c9-desktop-mango.git`;
the intended repository visibility is private. See [Source control](docs/SOURCE-CONTROL.md).

**C9 0.2.0 now has a corrected ZFS installer.** The replacement ISO passed its server build and static verification on 22 November 2026 at 16:06:27 UTC. Its focused regression tests confirmed the home-dataset repair, unchanged user data and ownership checks, correct-ZFS no-op behavior, and UFS compatibility.

The replacement copy on F: passed its full checksum check at 16:25:30 UTC. The user subsequently reported successful installation on the Dell Latitude 5591. A fresh replacement-ISO EFI/ZFS VM test was not run; detailed native graphics and application acceptance were not separately reported.

All ten C9 0.2.0 packages and their dependencies already passed the full release gate, including the signed 545-package installation plan. The installer repair reused those packages and the exact p6 kernel/base payload. All 106 port files and their metadata remained unchanged.

Use [Automated rebuild](docs/AUTOMATED-REBUILD.md) to run packages through a verified ISO with one command and reuse compatible packages. [Customize and rebuild](docs/CUSTOMIZE-AND-REBUILD.md) explains changes to packages, defaults or the installer. The [quick start](docs/QUICKSTART.md) gives the current ISO path and checksum. The original ISO's BIOS/EFI **UFS** installation/authentication tests remain historical evidence. A paused original-ISO installation can be resumed with the [ZFS recovery steps](docs/ZFS-INSTALL-RECOVERY.md).

The recovered source is `F:\C9\source\c9-desktop-mango-0.2.0-zfs-20261122T153649Z`. E: reported hardware I/O errors and remains untouched. The requested replacement ISO destination is `F:\C9\releases\c9-0.2.0-zfs-20261122T153649Z\C9MANGO020.iso`.

C9 assembles a Mango desktop through FreeBSD packages. SDDM requires a regular
user's password; automatic login and root desktop sessions are excluded.
The default workstation includes Waybar, Fuzzel, Mako, Swaybg, Foot, Firefox,
Thunar, and Zathura. Development and Office are optional application groups.
Existing user configuration is preserved.

The physical target is FreeBSD **15.1-RELEASE-p6 / amd64** on the **Dell
Latitude 5591 with Intel UHD 630**. VirtualBox 7.2.10 is an installer/login
test target only. Its graphics do not provide the native DRM support required
by this Mango renderer. Physical graphics validation is a separate requirement.

## Packages

| Package | Role |
| --- | --- |
| `c9-workstation` | Desktop plus Essential applications |
| `c9-desktop-mango` | Mango, SDDM, desktop utilities, portals, C9 configuration/artwork |
| `c9-apps-essential` | Firefox, Foot, Thunar, Zathura and its MuPDF plugin |
| `c9-apps-development` | Optional VS Code, Git, CMake, Python, Node.js and npm |
| `c9-apps-office` | Optional LibreOffice |
| `c9-desktop-defaults` | Native session, user initializer and templates |
| `c9-system-config` | Explicit system setup, Xorg greeter dependency and SDDM policy |
| `c9-artwork` | Original C9 wallpaper and logo |
| `c9-hardware-intel` | Dell/UHD630 DRM module and firmware selection |
| `c9-hardware-virtualbox` | Xorg and guest additions for installer/login tests |

All C9 ports use version `0.2.0`. Original C9 source is BSD-2-Clause licensed;
dependency packages retain their own licenses. `ports/` is a partial overlay
requiring the complete pinned FreeBSD ports tree. It contains no prebuilt
packages or fetched upstream sources.

## Build packages first

The server is reached with `ssh daniel@192.168.178.55`; root commands use
`doas`. The initial 0.1.0 recursive build completed successfully, and the
expanded 0.2.0 build reuses its packages. Keep any active run's source,
overlay and configuration unchanged until it finishes. Reviewed dependency
repairs and their validation are documented in
[local port repairs](docs/PORTS-PATCHES.md).

Deploy the completed 0.2.0 source under
`/usr/local/c9/c9-desktop-mango-0.2.0`. Once the C9 build jail is idle:

```sh
cd /usr/local/c9/c9-desktop-mango-0.2.0
doas sh scripts/c9-build.sh configure
doas sh scripts/c9-build.sh plan
build_id="c9-0.2.0-$(date -u +%Y%m%dT%H%M%SZ)"
doas sh scripts/c9-build.sh build "$build_id"
doas sh scripts/c9-build.sh verify "$build_id"
```

The release workflow builds every offered C9 package and its dependencies on
the existing Poudriere server. It reuses compatible packages already built for
the same jail/tree/set; no rebuild-all is requested. **Complete and verify all
packages before creating an ISO or installing a VM.** The installer source
bundles signed packages for offline installation and configures subsequent
package updates from the existing LAN server.

## Documentation

- [Automated rebuild](docs/AUTOMATED-REBUILD.md): detached package-to-ISO runner, reuse, status, logs and retries.
- [Customize and rebuild](docs/CUSTOMIZE-AND-REBUILD.md): where to edit, version changes, deployment, package builds and a matching ISO.
- [Quick start](docs/QUICKSTART.md): use the existing ISO, install C9 or repeat the build.
- [Build workflow](docs/BUILD.md): package inputs, commands and verification.
- [Reproduction](docs/REPRODUCE.md): preserve and restore release inputs.
- [Design](docs/DESIGN.md): package ownership and configuration boundaries.
- [Desktop](docs/DESKTOP.md): authentication, defaults, session and hardware.
- [Installer](docs/INSTALLER.md): image creation and installation.
- [Validation](docs/VALIDATION.md): completed checks and outstanding work.
- [Local port repairs](docs/PORTS-PATCHES.md): scoped fixes to pinned dependencies.
- [Server history](docs/POUDRIERE-SERVER.md): earlier 0.1.0 setup and build runs.

The [project baseline](docs/C9-Project-Description.md), historical references,
and source records remain unchanged. They describe their recorded snapshots,
not a completed 0.2.0 release. Each deployed source archive carries
`MANIFEST.sha256` for its recorded inputs. The current C9 source uses the
maintainer contact above; previously built packages retain their original metadata.
