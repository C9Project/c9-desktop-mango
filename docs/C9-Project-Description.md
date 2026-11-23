# C9 Project — Project Description

**Document version:** 0.1  
**Date:** 10 November 2026  
**Status:** Initial project baseline; implementation and testing pending

## Purpose

C9 Project will provide a custom FreeBSD installation image that installs a complete, preconfigured desktop based on Mango. The system will combine a standard FreeBSD base with selected applications, consistent desktop settings, and C9 artwork.

After installation, the computer will boot to a login screen. The user must authenticate before the configured Mango desktop starts. **Automatic login will not be provided as an installation option.**

The project will use Poudriere to build packages and assemble the installation image, with FreeBSD's `bsdinstall` providing the foundation for installation onto the target disk.

## Design principles

- Keep the FreeBSD base standard and maintain a small, understandable customization layer.
- Define software selections through modular meta-ports.
- Deliver configuration, session scripts, and artwork through versioned packages.
- Preserve user changes when packages are updated.
- Support installation from bundled base-system files and packages without requiring downloads.
- Keep hardware-specific settings separate from common desktop defaults.
- Require authentication before granting access to the desktop.

## Package structure

The following package names define the proposed structure. Exact application selections will be finalized during implementation.

| Package | Type | Responsibility |
| --- | --- | --- |
| `c9-desktop-mango` | Meta-port | Mango, desktop utilities, session integration, fonts, and C9 defaults |
| `c9-apps-essential` | Meta-port | Browser, terminal, file manager, and document viewer |
| `c9-apps-development` | Meta-port | VS Code, Git, and selected language tools |
| `c9-apps-office` | Meta-port | Optional office applications |
| `c9-workstation` | Meta-port | Combines the desktop and default application groups |
| `c9-desktop-defaults` | Regular port | Desktop settings, keybindings, session scripts, and user templates |
| `c9-artwork` | Regular port | Wallpapers, branding, and theme assets |
| `c9-system-config` | Regular port | System configuration templates and a setup utility |

Meta-ports will declare dependencies using `USES=metaport`; they will not install configuration files themselves. Regular ports will own those files and will be dependencies of the appropriate meta-ports. See the [FreeBSD metaport documentation](https://docs.freebsd.org/en/books/porters-handbook/uses/#uses-metaport).

The desktop meta-port can depend on the existing FreeBSD port `x11-wm/mango`. Application groups will allow a minimal desktop to be extended with development or office tools without maintaining separate desktop configurations.

## Desktop and system configuration

The configuration packages will provide:

- Mango keybindings, layouts, window rules, and startup applications.
- Panel, launcher, notifications, wallpaper, fonts, and theme settings.
- Default applications and file associations.
- A C9 session launcher and a login-manager session entry.
- Templates for system services and hardware profiles.

User templates will be stored in a C9-owned directory, such as `/usr/local/share/c9/skel/`. During installation, the setup utility will initialize the new user's home directory from these templates and assign the correct ownership and permissions.

A first-login helper may initialize missing settings for users created later. It will run within an authenticated session and will preserve existing user files.

Editable system configuration will use the ports framework's `@sample` mechanism where appropriate. Updates will not blindly overwrite files under `~/.config`. Changes to defaults will require a deliberate migration approach when existing user settings need adjustment. See the [FreeBSD configuration-file packaging guidance](https://docs.freebsd.org/en/books/porters-handbook/plist/#plist-config).

## Image creation and installation

Poudriere will build the C9 packages and their dependencies into a package repository. Its image functionality can assemble ISO and hybrid ISO images, include a filesystem overlay with `-c`, and run a build-time customization script with `-A`.

The `-A` script customizes the image while it is being built; it is separate from configuration performed on the target system during installation or first boot.

A bootable image alone does not provide a complete installer. C9 must explicitly include the installation tools, base-system payload, package repository, and startup integration needed to install onto a target disk.

The installer will be based on `bsdinstall`, which supports scripted installation and post-installation configuration. Official FreeBSD release media support `/etc/installerconfig`; the custom C9 image must explicitly arrange the equivalent installer startup.

The installation flow will be:

1. Boot the C9 installation image.
2. Select the target disk, create the user credentials, and choose a hardware profile.
3. Install the FreeBSD base system and bootloader.
4. Install `c9-workstation` and selected optional groups from the bundled repository.
5. Apply system settings and initialize the user's desktop configuration.
6. Enable the login manager and register the C9 Mango session.
7. Reboot into the login screen.

The image will include all base-system files and package dependencies needed for the offered installation selections. Packages and configuration present in the installer environment must also be deliberately installed or applied to the target system.

Poudriere's image feature is documented as alpha. Image booting and the complete installation path therefore require validation with the selected Poudriere and FreeBSD versions. See [poudriere-image(8)](https://man.freebsd.org/cgi/man.cgi?manpath=freebsd-ports&query=poudriere-image&sektion=8) and [bsdinstall(8)](https://man.freebsd.org/cgi/man.cgi?query=bsdinstall&sektion=8).

## Startup and authentication

| Event | Required behavior |
| --- | --- |
| System boot | Display the login screen |
| Successful authentication | Start the preconfigured C9 Mango session as the authenticated user |
| Failed or cancelled authentication | Remain at the login screen |
| Desktop logout | Return to the login screen |
| Subsequent reboot | Require authentication again |

Automatic login is excluded from the C9 startup design. The installer will not offer an automatic-login option, and the installed configuration will not enable it.

The login manager remains an implementation choice. It must work reliably with FreeBSD and the Mango session. Desktop preconfiguration must not bypass authentication or start a desktop session as root.

User credentials and machine-specific keys will be created during installation or first boot, rather than shared across installations through the image.

## Hardware profiles

Common desktop settings will be shared across installations. Hardware profiles will supply the appropriate graphics modules and other machine-specific settings.

Initial profile candidates are:

| Profile | Intended purpose |
| --- | --- |
| VirtualBox | Virtual-machine installation and testing |
| Intel laptop | Supported Intel graphics and laptop-specific settings |
| AMD desktop | Supported AMD graphics and desktop-specific settings |

Each supported profile will need testing on its intended environment. Graphics modules must be compatible with the target FreeBSD kernel; profile names do not imply support for every device in that category.

## Updates and maintenance

C9 will maintain a Poudriere-built package repository for its meta-ports, configuration packages, artwork, and required applications. Desktop and application updates will be delivered as packages, with local configuration changes preserved.

The FreeBSD release, architecture, ports-tree revision, and package options will be recorded for each C9 build. Base-system maintenance and application-package maintenance will both be accounted for in the release process.

## Initial release scope

The first release will deliver an installer ISO that produces a working, preconfigured desktop. A live desktop on the installation media is a later extension, after the installation path is reliable.

Initial deliverables are:

- C9 meta-ports and regular ports for configuration and artwork.
- Poudriere build configuration and package lists.
- Image overlays and build-time customization scripts.
- `bsdinstall` integration and target-system configuration logic.
- A bootable installation ISO with its required installation payload.
- Build, installation, maintenance, and troubleshooting documentation.

The first release will be considered ready when a clean installation can complete using the bundled payload, reboot to a login screen, and start the configured Mango desktop only after successful authentication. The selected applications, user configuration, logout behavior, and package-update behavior must also pass validation on the supported profiles.

## Decisions to finalize during implementation

- Exact FreeBSD release and target architecture for the first build.
- Login manager and its session integration.
- Applications included in each group and which groups are installed by default.
- Panel, launcher, notification, and theme components.
- Supported hardware profiles, disk layout, and repository distribution details.

These choices refine the implementation. The baseline remains a standard FreeBSD system, modular C9 packages, a preconfigured Mango desktop, and mandatory login before desktop access.
