# SPDX-License-Identifier: BSD-2-Clause
PORTNAME=	c9-system-config
DISTVERSION=	0.2.1
CATEGORIES=	sysutils
MASTER_SITES=
DISTFILES=

MAINTAINER=	c9_project@proton.me
COMMENT=	Explicit system setup for authenticated C9 desktop installations
LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${FILESDIR}/LICENSE

RUN_DEPENDS=	c9-desktop-defaults>=0.2.1:x11/c9-desktop-defaults \
		Xorg:x11-servers/xorg-server \
		xf86-input-libinput>=0:x11-drivers/xf86-input-libinput \
		sddm:x11/sddm \
		seatd:sysutils/seatd

NO_ARCH=	yes
NO_BUILD=	yes
NO_WRKSUBDIR=	yes

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/sbin \
		${STAGEDIR}${PREFIX}/etc/sddm.conf.d \
		${STAGEDIR}${DATADIR}/profiles
	${INSTALL_SCRIPT} ${FILESDIR}/c9-system-setup ${STAGEDIR}${PREFIX}/sbin/
	${INSTALL_DATA} ${FILESDIR}/90-c9.conf.sample ${STAGEDIR}${PREFIX}/etc/sddm.conf.d/
.for profile in virtualbox intel
	${INSTALL_DATA} ${FILESDIR}/${profile}.conf ${STAGEDIR}${DATADIR}/profiles/
.endfor

.include <bsd.port.mk>
