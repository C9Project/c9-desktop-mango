# Rio terminal candidate for C9 0.2.1

This branch prepares the source change from Foot to Rio. It has not been
deployed to Poudriere or the Dell, and no 0.2.1 packages or ISO have been built.
The verified 0.2.0 artifacts remain the existing installation release.

## Package and desktop changes

The pinned ports tree contains `x11/rio` at version **0.5.30**. Its package is
`rio-terminal-emulator-0.5.30` and its executable is `/usr/local/bin/rio`.
Use that port identity even though the Rio website's general installation
instructions use a different package name.
[Pinned FreeBSD port](https://github.com/freebsd/freebsd-ports/tree/e7bc56a5d30dc24ce2e7990926836699cbd34e55/x11/rio).

All three C9 dependencies on Foot are replaced: Essential, desktop Mango,
and desktop defaults. New user defaults launch `rio` with Super+Enter and
use `rio -e` for Fuzzel's terminal applications. The C9-owned
`share/applications/c9-rio.desktop` also makes Rio visible in the application
launcher; the pinned upstream port installs only the executable.

The Rio template is `.config/rio/config.toml`. It retains C9's colors,
DejaVu Sans Mono at size 11, and ten-pixel margins. Its fields were checked
against the pinned Rio source; local TOML parsing is not a native Rio runtime
test. The old Foot template is no longer installed, but users' existing Foot
configuration is not removed.

All ten C9 packages move together to **0.2.1**, with matching internal dependency
minimums. This satisfies the existing exact-version release gate and prevents
reuse of old C9 package contents. Compatible upstream packages can still be
reused. The FreeBSD p6 baseline, ports commit, image jail, historical kernel
record, signing policy and builder limits remain the same.

## Pinned-port limitations

The upstream feature definitions and renderer selection indicate that this
standard FreeBSD build uses **CPU rendering**: its defaults enable Wayland and
X11, while the optional `wgpu` renderer is not enabled. This is a source-level
finding, not a measurement of a built FreeBSD binary. This change uses those
standard port defaults. Enabling a GPU renderer would require a separate
reviewed build-policy change and hardware testing.
[Feature definitions](https://github.com/raphamorim/rio/blob/v0.5.30/frontends/rioterm/Cargo.toml),
[renderer selection](https://github.com/raphamorim/rio/blob/v0.5.30/frontends/rioterm/src/screen/mod.rs).

No TERM override is configured. The pinned Rio code falls back to
`xterm-256color` when Rio-specific terminfo is unavailable; the port does not
install its own terminfo.
[Terminal environment setup](https://github.com/raphamorim/rio/blob/v0.5.30/frontends/rioterm/src/main.rs).

## Existing Dell user configuration

Package upgrades preserve existing user files. In particular, an existing
Mango/Fuzzel configuration can continue to launch Foot until its owner changes
it. Installing the candidate does not automatically migrate those files or
uninstall Foot.

After a future package build has passed and Rio is installed:

1. As the desktop user, confirm `rio --version` and open `rio` in the native
   Mango session. Verify text rendering, input, clipboard and a child command
   such as `rio -e sh -c 'printf "Rio child command works\\n"; read answer'`.
2. Back up the existing Mango and Fuzzel configuration files. In the Mango
   configuration actually used by the session, change the terminal binding to
   `bind=SUPER,Return,spawn,rio`. In Fuzzel's `[main]` section, set
   `terminal=rio -e`.
3. Run `c9-user-init` as that regular user to seed the Rio template if missing,
   or copy/review the installed template manually when using a custom config
   location. Existing files and symlinks remain untouched.
4. Reload Mango with Super+Shift+R or log in again. Test Super+Enter and a
   `Terminal=true` application through Fuzzel. In Rio, inspect `echo "$TERM"`
   and `tput colors`.
5. Consider removing Foot only after confirming no personal shortcuts or other
   packages still require it. Keep its old configuration available for recovery.

## Source checks and later release acceptance

The source test is `tests/test-terminal.py`. Run it with Python 3.11 or newer
from the project root:

```sh
python3 tests/test-terminal.py
```

Its local checks cover dependency and launch-command consistency, Rio TOML,
package versions, and agreement between the templates, initializer and plist.
The separate FreeBSD runtime mode exercises initializer preservation using an
isolated template-path fixture; it must not be reported as passed when skipped.
Use the test's `--help` for that mode.

The original `tests/collect-installed-evidence.sh` remains the historical
0.2.0/Foot acceptance collector. It is not a Rio acceptance test. Existing dated
build/VM evidence and source records are retained unchanged.

The old **545-package** installation count is not assumed for 0.2.1.
`installer/release.conf` has `C9_EXPECTED_INSTALL_PACKAGE_COUNT=unreviewed`.
The ISO verifier checks the new image label, all ten 0.2.1 identities and the
pinned Rio package, then refuses release acceptance until the new count has
been reviewed. Signature, archive-hash, kernel and installer checks remain.

For a later authorized build, inspect the complete signed-repository dependency
plan, including added and removed packages, and record a reviewed positive
count in that setting. Do not copy a count merely to silence the gate. Commit
and deploy that reviewed source before final ISO acceptance. A candidate ISO
produced while the count is unreviewed is not a passed release.

Still required: FreeBSD port metadata/build tests, native Rio execution on the
Dell, updated dependency-plan review, and package/ISO/installation acceptance.
The server was unreachable during source preparation; only local checks were
authorized for this change.
