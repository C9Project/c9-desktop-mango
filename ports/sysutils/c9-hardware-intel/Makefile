# SPDX-License-Identifier: BSD-2-Clause
PORTNAME=	c9-hardware-intel
DISTVERSION=	0.2.1
CATEGORIES=	sysutils

MAINTAINER=	c9_project@proton.me
COMMENT=	Graphics packages for C9 on Dell Latitude 5591 with Intel UHD 630

ONLY_FOR_ARCHS=	amd64
ONLY_FOR_ARCHS_REASON=	the selected Dell Latitude 5591 profile targets amd64

# Coffee Lake-H UHD 630 (8086:3e9b) uses the i915 driver and Kaby Lake
# firmware family. This profile does not claim support for every Intel GPU.
RUN_DEPENDS=	drm-612-kmod>=0:graphics/drm-612-kmod \
		gpu-firmware-intel-kmod-kabylake>=0:graphics/gpu-firmware-intel-kmod@kabylake

USES=		metaport

.include <bsd.port.mk>
