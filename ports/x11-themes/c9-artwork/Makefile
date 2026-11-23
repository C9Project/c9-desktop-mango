# SPDX-License-Identifier: BSD-2-Clause
PORTNAME=	c9-artwork
DISTVERSION=	0.2.0
CATEGORIES=	x11-themes
MASTER_SITES=
DISTFILES=

MAINTAINER=	maintainer@example.invalid
COMMENT=	Original C9 wallpaper and scalable logo

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${FILESDIR}/LICENSE

BUILD_DEPENDS=	rsvg-convert:graphics/librsvg2-rust

NO_ARCH=	yes
NO_CONFIGURE=	yes
NO_WRKSUBDIR=	yes

# The SVG uses only paths and gradients, avoiding font or external-asset
# dependencies. Rendering is deterministic for a fixed librsvg version.
do-build:
	${SETENV} LC_ALL=C TZ=UTC ${LOCALBASE}/bin/rsvg-convert \
		--format=png --width=2560 --height=1440 \
		--output=${WRKDIR}/wallpaper.png ${FILESDIR}/wallpaper.svg

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/share/backgrounds/c9
	${INSTALL_DATA} ${WRKDIR}/wallpaper.png \
		${STAGEDIR}${PREFIX}/share/backgrounds/c9/wallpaper.png
	${INSTALL_DATA} ${FILESDIR}/wallpaper.svg \
		${STAGEDIR}${PREFIX}/share/backgrounds/c9/wallpaper.svg
	${MKDIR} ${STAGEDIR}${PREFIX}/share/icons/hicolor/scalable/apps
	${INSTALL_DATA} ${FILESDIR}/c9-logo.svg \
		${STAGEDIR}${PREFIX}/share/icons/hicolor/scalable/apps/c9-logo.svg

.include <bsd.port.mk>
