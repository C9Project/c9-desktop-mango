# C9 0.2.0 design

C9 separates package selection, installed configuration and installation.
The source implements each part; integration awaits the 0.2.0 package build
and runtime acceptance. The unchanged [project description](C9-Project-Description.md)
remains the baseline.

## Dependency-only packages

| Origin | Responsibility |
| --- | --- |
| `x11/c9-workstation` | Desktop plus Essential applications |
| `x11/c9-desktop-mango` | Mango, SDDM, desktop utilities, portals, fonts and C9 configuration/artwork |
| `misc/c9-apps-essential` | Firefox, Foot, Thunar, Zathura and MuPDF plugin |
| `devel/c9-apps-development` | VS Code, Git, CMake, Python, Node.js 24 and matching npm |
| `editors/c9-apps-office` | LibreOffice |
| `emulators/c9-hardware-virtualbox` | VirtualBox 7.2 Xorg guest additions and Xorg |
| `sysutils/c9-hardware-intel` | DRM 6.12 module and Kaby Lake firmware for Dell Latitude 5591 / UHD 630 |

These ports use `USES=metaport`. C9 package versions describe this dependency
selection independently of upstream versions. FreeBSD's ports framework
resolves the applications' libraries and build tools.

The workstation has one consistent dependency set. Development, Office and
hardware profiles are separate packages. Fuzzel, Mako and Swaybg are fixed
components; the three 0.1.0 desktop options are removed. All offered groups
must be built for the offline image even though users can omit optional groups
when installing.

## Packages that install files

| Origin | Content |
| --- | --- |
| `x11/c9-desktop-defaults` | Native session entry/launchers, nonroot user initializer, supervised startup helper and templates |
| `sysutils/c9-system-config` | SDDM sample policy, profile templates, explicit setup command and Xorg server dependency |
| `x11-themes/c9-artwork` | Original SVG wallpaper/logo and PNG rendered during the package build |

These regular ports declare their files in `pkg-plist`. Configuration packages
fetch no external source. The artwork package uses the pinned tree's librsvg
to render its original SVG at fixed dimensions without external fonts/assets.
Original C9 source and artwork use BSD-2-Clause; dependency licenses remain
independent. All C9 ports are version `0.2.0`.

Package installation does not enable services or change accounts. Explicit
`c9-system-setup --profile intel|virtualbox` configures the target, including
inside the installer's chroot. It enables selected services/modules for the
next boot, adds desktop users to `video`, and invokes the user initializer
under their own credentials. It does not start services in the chroot, change
passwords, generate shared keys or recursively change home ownership.
Conflicting autologin settings and modified profile files stop setup for review.

## Authentication and desktop session

SDDM uses an Xorg greeter and existing FreeBSD PAM authentication. The Xorg
server and its libinput input driver are direct system-configuration
dependencies, including for Intel.
Base `pam_xdg` supplies the user's runtime directory; C9 checks its owner and
mode. The launcher refuses UID 0, validates the user's Mango configuration,
starts a D-Bus session and selects native DRM/libinput backends.

Mango's startup process group owns Waybar, Mako, Swaybg and session helpers.
Mango stops that group on logout. Portals use D-Bus activation; no global
`killall` is used. User templates fill only missing paths and preserve existing
settings and symlinks. [DESKTOP.md](DESKTOP.md) documents shortcuts and the
Mango 0.18.5/Waybar 0.16.0 integration with primary source references.

Intel targets the specified Dell/UHD630 with matched p6 kernel modules.
VirtualBox is limited to installer and authenticated-login testing. No nested
Mango session, alternate compositor or AMD profile is included.

## Build and installation boundaries

The partial overlay is combined with the recorded full ports tree. It does
not replace category indexes. The build wrapper checks inputs and idle state,
registers the overlay, then builds/tests the complete release list. Compatible
existing packages are reused. The running 0.1.0 build keeps its inputs until
completion; 0.2.0 is deployed in a separate source directory.

The installer source combines matching patched FreeBSD base/kernel files and
a completed signed repository. It retains bsdinstall's interactive disk and
account steps, installs selected C9 packages, and invokes explicit setup.
Initial installation is offline; later package updates use the LAN repository.
Credentials and private signing keys are not embedded. See
[INSTALLER.md](INSTALLER.md) for implementation details and acceptance checks.

The scripts retain release inputs and identities without promising byte-identical
ISO output. Source checks, successful builds, VM installation and physical
Mango graphics are separate evidence in [VALIDATION.md](VALIDATION.md).

## Maintenance

The current release gate requires every C9 package's full version to match
`C9_VERSION`. Use the coordinated version procedure in
[Customize and rebuild](CUSTOMIZE-AND-REBUILD.md) for packaged changes;
an isolated `PORTREVISION` increment does not satisfy that gate.
Keep custom dependency versions and release inputs consistent.
Coordinate kernel/module updates and preserve user edits.
Removing a meta-package does not automatically remove all dependencies or
restore system configuration.

The C9 maintainer is `c9_project@proton.me`; the project account is
[C9Project](https://github.com/C9Project). Source control is configured for a
private repository; choose a publicly accessible project homepage before public ports
submission. Historical references and source records describe their earlier
snapshot; they are not current dependency version locks.
