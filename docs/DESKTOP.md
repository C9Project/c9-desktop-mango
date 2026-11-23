# C9 desktop integration

The C9 0.2.1 source candidate keeps the authenticated SDDM login and Mango
session with Waybar, Fuzzel, Mako and Swaybg, and selects Rio as the terminal.
It targets Mango 0.18.5 and Waybar 0.16.0. This change is prepared and checked
locally only; no 0.2.1 packages, ISO or native graphics results are available.
The recorded 0.2.0 builds and installation tests used Foot and remain separate
evidence. See [Rio terminal](RIO-TERMINAL.md) for package and migration details.

## Install and configure

After a package release has passed its build and validation gates, install
the C9 workstation and matching hardware package, then create a
nonroot account with a nonempty password. On the target system, or inside the
installer's target chroot, run:

```sh
/usr/local/sbin/c9-system-setup --profile intel --user alice
```

The physical target is the Dell Latitude 5591 with Intel UHD 630. The other
profile, `virtualbox`, is for installer/login tests only. `--user` can be
repeated. When omitted, setup selects unlocked local accounts with UIDs
1000–65000 and interactive shells.
It adds those users to `video` and runs `c9-user-init` with each user's own
credentials. No package installation hook enables services. Setup changes
only the selected service/module settings, C9's SDDM profile selection, and
group membership. It never sets passwords, generates machine keys, loads
modules, starts services in a chroot, or recursively changes home ownership.

An existing conflicting SDDM automatic-login setting or modified C9 profile
file makes setup stop for administrator review. Existing files are retained.
The ordinary FreeBSD first-boot mechanisms generate machine keys when the
corresponding services are enabled; keys are never shared in C9 packages.

## Authentication and session lifetime

SDDM starts an Xorg greeter. All profiles expose C9's native Wayland session;
the VirtualBox profile is limited to installer and login validation.
`[Autologin]` has an empty user/session and `Relogin=false`. C9's launchers
reject UID 0. Existing FreeBSD PAM authentication remains in place.

FreeBSD 15.1's base `pam_xdg` creates the authenticated user's runtime
directory, normally `/var/run/xdg/USERNAME`. C9 checks its owner and mode 0700;
it does not create a shared runtime directory or install a second PAM module.
The launcher starts a fresh D-Bus session. Mango's `-s` startup command starts
the C9 background applications only after its backend and Wayland socket are
ready. Mango terminates that dedicated process group on logout. No global
`killall` command affects other sessions. Portal services use D-Bus activation.

## Preserving user settings

Versioned templates are installed under
`/usr/local/share/c9/skel/`. `c9-user-init` copies only missing
files into the current user's home. Existing files and symlinks, including
symlinked ancestor directories, are preserved. The helper runs at installation
and every C9 login, so a later user receives missing defaults too. An edited
configuration never gets overwritten by a package upgrade.
An existing alternate Mango/Waybar configuration name is not shadowed by a
new default. A custom `XDG_CONFIG_HOME` or symlinked home is left untouched.

The Rio change follows the same rule: existing Mango and Fuzzel files retain
their Foot commands, and existing Foot configuration is not deleted.
Changing those commands is an opt-in user migration, described in
[Rio terminal](RIO-TERMINAL.md). The shortcuts below describe fresh 0.2.1
defaults, not an automatic change to an installed 0.2.0 account.

The launcher honors an existing Mango configuration beneath `XDG_CONFIG_HOME`
and validates it with `mango -c PATH -p`. Configuration errors return to the
login screen instead of discarding the user's changes. Templates target the
0.18.5 names (`border_px`, `tag_rule`, `reload_config`); old Mango snippets
with renamed keys need deliberate migration.

| Shortcut | Action |
| --- | --- |
| Super+Enter | Rio terminal |
| Super+Space | Fuzzel launcher |
| Super+E / Super+B | File manager / browser from Essential applications |
| Super+Q / Super+F | Close window / toggle fullscreen |
| Super+1…9 | Select workspace |
| Super+Shift+1…9 | Move window to workspace |
| Super+Ctrl+L | Lock with Swaylock |
| Super+Shift+R | Reload Mango configuration |
| Super+Shift+E | Log out to SDDM |

The initial keyboard layout is US; change `xkb_rules_layout` in the user
configuration to match the installed system. No automatic idle/suspend policy
is configured in this prototype.

## Hardware boundaries

The candidate uses the pinned FreeBSD Rio port's standard CPU renderer,
without a custom GPU-feature override. This does not establish Rio runtime
acceptance or change Mango's graphics requirements below.

The Intel profile installs `drm-612-kmod` and Kaby Lake firmware for the Dell
Latitude 5591's UHD 630 and enables `i915kms`. Setup requires the installed
15.1-RELEASE-p6 kernel used for this package build, checked from its file even
inside an installer chroot. Kernel and module updates must remain matched.
Physical graphics validation on that laptop is still required. No AMD profile
is included in this release.

VirtualBox is for **installer and SDDM login tests only**. Its guest additions
support Xorg but do not supply the missing native DRM driver. Mango 0.18.5
directly uses scenefx's GLES renderer, which requires a usable DRM file
descriptor and EGL DMA-BUF support even when an X11 output backend is used.
No unsupported nested session, alternate compositor, or pixman setting is
shipped. A stock VirtualBox guest is not expected to run the Mango desktop.
Selecting Mango there can return to SDDM; renderer errors are recorded in
`~/.local/share/sddm/wayland-session.log`. Installer/login success in VirtualBox
does not count as successful Mango graphics validation.

## Runtime acceptance checks

On a disposable target: confirm the login screen appears; a wrong password is
rejected; a valid login runs Mango as the selected nonroot account; the panel,
launcher, notifications, wallpaper and Essential applications work; logout
returns to SDDM; reboot again requires authentication; manual lock requires the
password; and edited user files survive package upgrades and repeated setup.
Record the GPU, VM settings, kernel/module versions, and package build inputs.
VirtualBox validation is separate from native Intel graphics validation.

## Primary implementation references

- [Mango 0.18.5 startup and cleanup](https://github.com/mangowm/mango/blob/0.18.5/src/main.c)
- [Mango 0.18.5 configuration](https://github.com/mangowm/mango/blob/0.18.5/docs/configuration/basics.md)
- [Waybar Mango workspace module](https://github.com/Alexays/Waybar/blob/0.16.0/man/waybar-mango-workspaces.5.scd)
- [FreeBSD 15.1 base PAM runtime-directory implementation](https://github.com/freebsd/freebsd-src/blob/releng/15.1/lib/libpam/modules/pam_xdg/pam_xdg.c)
- [Scenefx 0.5 renderer requirements](https://github.com/wlrfx/scenefx/blob/0.5/render/fx_renderer/fx_renderer.c)
- [FreeBSD DRM virtual GPU support issue](https://github.com/freebsd/drm-kmod/issues/356)
- [FreeBSD VirtualBox guest configuration](https://docs.freebsd.org/en/books/handbook/virtualization/#virtualization-guest-virtualbox)
