# References and provenance

Checked on **10 November 2026**. References are retained so that later changes
can be compared with the source material used for this example. The C9 code
and dependency selection are original project work; upstream applications are
resolved through their existing ports and are not bundled in this archive.

## Framework and build references

| ID | Primary source | Used for |
| --- | --- | --- |
| R1 | [Porter's Handbook: metaport](https://docs.freebsd.org/en/books/porters-handbook/uses/#uses-metaport) | Purpose of `USES=metaport` |
| R2 | [metaport.mk at inspected revision](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/Mk/Uses/metaport.mk) | Empty-package behavior and license metadata |
| R3 | [Porter's Handbook: dependencies](https://docs.freebsd.org/en/books/porters-handbook/makefiles/#makefile-depend) | Runtime dependencies and package constraints |
| R4 | [bsd.options.mk at inspected revision](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/Mk/bsd.options.mk) | Origin-based options names and `_UNSET_FORCE` precedence |
| R5 | [poudriere-ports(8)](https://man.freebsd.org/cgi/man.cgi?query=poudriere-ports&sektion=8&manpath=freebsd-ports) | Full-tree creation and `null` registration |
| R6 | [poudriere-bulk(8)](https://man.freebsd.org/cgi/man.cgi?query=poudriere-bulk&sektion=8&manpath=freebsd-ports) | `-O`, `-z`, build lists, dry run, and repository generation |
| R7 | [poudriere-testport(8)](https://man.freebsd.org/cgi/man.cgi?query=poudriere-testport&sektion=8&manpath=freebsd-ports) | Jail-based port validation and overlays |
| R8 | [poudriere-options(8)](https://man.freebsd.org/cgi/man.cgi?query=poudriere-options&sektion=8&manpath=freebsd-ports) | Documented options-command interface; no `-O` assumed |
| R9 | [FreeBSD Handbook: Poudriere](https://docs.freebsd.org/en/books/handbook/ports/#ports-poudriere) | Builder setup and package repository workflow |
| R10 | [Porter's Handbook: pkg-message](https://docs.freebsd.org/en/books/porters-handbook/pkg-files/#porting-message) | UCL install-time package message |
| R11 | [pkg.conf(5)](https://man.freebsd.org/cgi/man.cgi?query=pkg.conf&sektion=5&manpath=freebsd-ports) | Local repository configuration and `REPOS_DIR` |
| R12 | [Porter's Handbook: testing](https://docs.freebsd.org/en/books/porters-handbook/testing/) | Port inspection and Poudriere testing |
| R13 | [Mango upstream](https://github.com/mangowm/mango) | Compositor project and upstream documentation |
| R14 | [Mango FreeBSD dependency update](https://cgit.freebsd.org/ports/commit/?id=bbc6ec4778897754573affe58fccd7f0e98cf6be) | Previously cited FreeBSD port history; retained from initial research |
| R15 | [bsd.port.mk at inspected revision](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/Mk/bsd.port.mk) | Port/package metadata handling, including an unset WWW field |

The Poudriere source was also checked for the registration and options details:

- [ports.sh](https://github.com/freebsd/poudriere/blob/master/src/share/poudriere/ports.sh)
- [options.sh](https://github.com/freebsd/poudriere/blob/master/src/share/poudriere/options.sh)
- [Poudriere project and documentation](https://github.com/freebsd/poudriere)

## Dependency sources

The eleven dependency origins below were read from FreeBSD's official GitHub
mirror at commit **`6e4a386577aaa191a68b11865fcb18e02f98e525`**. That commit is
the inspected reference snapshot, not a guarantee that a later `main` build
will resolve the same versions or that these applications have been runtime
tested together.

| Dependency | FreeBSD port Makefile at inspected revision |
| --- | --- |
| Mango | [x11-wm/mango](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11-wm/mango/Makefile) |
| Foot | [x11/foot](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11/foot/Makefile) |
| seatd | [sysutils/seatd](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/sysutils/seatd/Makefile) |
| D-Bus | [devel/dbus](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/devel/dbus/Makefile) |
| DejaVu | [x11-fonts/dejavu](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11-fonts/dejavu/Makefile) |
| wl-clipboard | [x11/wl-clipboard](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11/wl-clipboard/Makefile) |
| xdg-user-dirs | [devel/xdg-user-dirs](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/devel/xdg-user-dirs/Makefile) |
| xdg-utils | [devel/xdg-utils](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/devel/xdg-utils/Makefile) |
| Fuzzel | [x11/fuzzel](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11/fuzzel/Makefile) |
| Mako | [x11/mako](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11/mako/Makefile) |
| Swaybg | [x11/swaybg](https://github.com/freebsd/freebsd-ports/blob/6e4a386577aaa191a68b11865fcb18e02f98e525/x11/swaybg/Makefile) |

The inspected Mango Makefile reports version `0.18.5`, revision `1`, and lists
Xwayland as a runtime dependency. The C9 Makefile intentionally leaves the
application version under control of the selected ports tree.

[`source-records.json`](source-records.json) records source URLs, sizes, and
SHA-256 hashes of the files actually inspected. `ports_commit` pins the
FreeBSD-ports records; the Poudriere source records identify the fetched
`master` URLs and their exact content hashes. This is provenance metadata,
not a dependency lockfile or a complete software bill of materials.

## References retained from the project baseline

The original [C9-Project-Description.md](C9-Project-Description.md) is included
unchanged. Its references remain:

- [FreeBSD metaport documentation](https://docs.freebsd.org/en/books/porters-handbook/uses/#uses-metaport)
- [Configuration-file packaging guidance](https://docs.freebsd.org/en/books/porters-handbook/plist/#plist-config)
- [poudriere-image(8)](https://man.freebsd.org/cgi/man.cgi?manpath=freebsd-ports&query=poudriere-image&sektion=8)
- [bsdinstall(8)](https://man.freebsd.org/cgi/man.cgi?query=bsdinstall&sektion=8)

Additional primary sources from the original architecture discussion are kept
for the later stages:

- [Poudriere image implementation](https://github.com/freebsd/poudriere/blob/master/src/share/poudriere/image.sh)
- [bsdinstall manual source](https://github.com/freebsd/freebsd-src/blob/main/usr.sbin/bsdinstall/bsdinstall.8)
- [FreeBSD Handbook: Wayland](https://docs.freebsd.org/en/books/handbook/wayland/)

Image assembly, scripted installation, and system configuration are future
stages. Their references do not imply that this archive implements them.
