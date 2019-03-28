#!/usr/bin/env ksh
#******************************************************************************
# @(#) build script for HC BFF packages (uses 'build_bff.sh' & 'mkinstallp')
#******************************************************************************
# @(#) Copyright (C) 2014 by KUDOS BVBA (info@kudos.be).  All rights reserved.
#
# This program is a free software; you can redistribute it and/or modify
# it under the same terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details
#******************************************************************************

#******************************************************************************
# Build environment should typically exist on a NIM server.
# Requires following build (dir) structures:
#
#   build_bff.sh -> /usr/local/bin/build_bff.sh
#   build_aix_bff.sh
#   hc_aix/*              (containing mkinstallp template & sources)
#   hc_aix_platform/*     (containing mkinstallp template & sources)
#   ...
#   lpp_source/KUDOS      (defined in build_bff.sh script)
#
# Build order:
#  1) Copy sources/scrips to the correct locations
#  2) Copy pristine version of the build spec file to preserver %BUILD_DATE% (.template)
#  3) Copy template, build and installer script files into correct locations
#  4) Execute build_aix_bff.sh
#  5) RPM packages may be found in the individual 'tmp' directories per plugin
#     (also refer to the help of build_bff.sh, ./build_bff.sh --help)
#******************************************************************************

BUILD_DATE="$(date +'%Y%m%d')"
BUILD_PRETTY_DATE="$(date +'%Y.%m.%d')"
BUILD_DIR="$(dirname $0)"

# replace BUILD_DATE placeholder in template files
find ${BUILD_DIR} -name "*.template" | while read FILE
do
	perl -pi -e "s/%BUILD_DATE%/${BUILD_PRETTY_DATE}/g" ${FILE}
done

# cleanup of old BFF packages happens in build_bff.sh

# build BFF packages
${BUILD_DIR}/build_bff.sh

exit 0

#******************************************************************************
# END of script
#******************************************************************************
