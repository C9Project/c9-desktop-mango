# SPDX-License-Identifier: BSD-2-Clause
PORTNAME=	c9-desktop-defaults
DISTVERSION=	0.2.0
CATEGORIES=	x11
MASTER_SITES=
DISTFILES=

MAINTAINER=	maintainer@example.invalid
COMMENT=	Authenticated Mango session and preserved user defaults for C9
LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${FILESDIR}/LICENSE

RUN_DEPENDS=	c9-artwork>=0.2.0:x11-themes/c9-artwork \
		dbus-run-session:devel/dbus \
		mango>=0.18.5:x11-wm/mango \
		foot:x11/foot \
		fuzzel:x11/fuzzel \
		mako:x11/mako \
		swaybg:x11/swaybg \
		swaylock:x11/swaylock \
		waybar>=0.16.0:x11/waybar \
		xdg-user-dirs-update:devel/xdg-user-dirs

NO_ARCH=	yes
NO_BUILD=	yes
NO_WRKSUBDIR=	yes
DATADIR=	${PREFIX}/share/c9

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/bin ${STAGEDIR}${PREFIX}/libexec/c9
.for script in c9-user-init c9-mango-session
	${INSTALL_SCRIPT} ${FILESDIR}/${script} ${STAGEDIR}${PREFIX}/bin/
.endfor
	${INSTALL_SCRIPT} ${FILESDIR}/session-apps ${STAGEDIR}${PREFIX}/libexec/c9/
	${MKDIR} ${STAGEDIR}${DATADIR}/skel/.config
	(cd ${FILESDIR}/skel && ${COPYTREE_SHARE} . ${STAGEDIR}${DATADIR}/skel)
	${MKDIR} ${STAGEDIR}${PREFIX}/share/c9/sessions/wayland \
		${STAGEDIR}${PREFIX}/share/c9/sessions/empty \
		${STAGEDIR}${PREFIX}/share/wayland-sessions
	${INSTALL_DATA} ${FILESDIR}/c9-mango.desktop ${STAGEDIR}${PREFIX}/share/c9/sessions/wayland/
	${INSTALL_DATA} ${FILESDIR}/c9-mango.desktop ${STAGEDIR}${PREFIX}/share/wayland-sessions/

.include <bsd.port.mk>
