# SPDX-License-Identifier: BSD-2-Clause
PORTNAME=	c9-apps-development
DISTVERSION=	0.2.1
CATEGORIES=	devel

MAINTAINER=	c9_project@proton.me
COMMENT=	Optional editor and development tool selection for C9

RUN_DEPENDS=	cmake-core>=0:devel/cmake-core \
		git>=0:devel/git \
		node24>=0:www/node24 \
		npm-node24>=0:www/npm-node24 \
		vscode>=0:editors/vscode

USES=		metaport python:3.12,run

# Depend on the selected runtime through USES, as required by ports QA.
# The generic lang/python3 metaport must not be another port's dependency.
# Node.js and npm are paired explicitly to the same supported major version.
.include <bsd.port.mk>
