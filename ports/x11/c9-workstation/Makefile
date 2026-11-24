# SPDX-License-Identifier: BSD-2-Clause
PORTNAME=	c9-workstation
DISTVERSION=	0.2.1
CATEGORIES=	x11

MAINTAINER=	c9_project@proton.me
COMMENT=	Default C9 workstation desktop and essential applications

RUN_DEPENDS=	c9-apps-essential>=0.2.1:misc/c9-apps-essential \
		c9-desktop-mango>=0.2.1:x11/c9-desktop-mango

USES=		metaport

# Development, office, and hardware profiles are installed as separate
# packages; this package has one consistent dependency set.
.include <bsd.port.mk>
