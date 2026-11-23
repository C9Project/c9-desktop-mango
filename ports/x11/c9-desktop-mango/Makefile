# SPDX-License-Identifier: BSD-2-Clause
# C9 0.2 provides a complete package selection; configuration is owned by
# regular ports and applied deliberately by c9-system-setup.
PORTNAME=	c9-desktop-mango
DISTVERSION=	0.2.0
CATEGORIES=	x11

MAINTAINER=	c9_project@proton.me
COMMENT=	Mango desktop and authenticated session package selection for C9

RUN_DEPENDS=	c9-artwork>=0.2.0:x11-themes/c9-artwork \
		c9-desktop-defaults>=0.2.0:x11/c9-desktop-defaults \
		c9-system-config>=0.2.0:sysutils/c9-system-config \
		dbus>=0:devel/dbus \
		dejavu>=0:x11-fonts/dejavu \
		foot>=0:x11/foot \
		fuzzel>=0:x11/fuzzel \
		mako>=0:x11/mako \
		mango>=0:x11-wm/mango \
		polkit-gnome>=0:sysutils/polkit-gnome \
		sddm>=0:x11/sddm \
		seatd>=0:sysutils/seatd \
		swaybg>=0:x11/swaybg \
		waybar>=0:x11/waybar \
		wl-clipboard>=0:x11/wl-clipboard \
		xdg-desktop-portal>=0:deskutils/xdg-desktop-portal \
		xdg-desktop-portal-gtk>=0:x11/xdg-desktop-portal-gtk \
		xdg-desktop-portal-wlr>=0:x11/xdg-desktop-portal-wlr \
		xdg-user-dirs>=0:devel/xdg-user-dirs \
		xdg-utils>=0:devel/xdg-utils

USES=		metaport

.include <bsd.port.mk>
