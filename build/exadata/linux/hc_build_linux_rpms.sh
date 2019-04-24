#!/usr/bin/env ksh
#******************************************************************************
# @(#) build script for HC RPM packages (uses 'rpmbuild')
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
# Requires following build (dir) structures:
#
#   hc_build_linux_rpms.sh
#   BUILD/
#   BUILDROOT/
#   RPMS/
#   SOURCES/
#   SOURCES/opt/hc/bin/<hc_scripts>
#   SOURCES/opt/hc/lib/*/<hc_plugins>
#   SOURCES/etc/opt/hc/<hc_configs>
#   SPECS/<spec_files>
#   SRPMS/
#
# Build order:
#  1) Copy sources/scripts to the correct locations
#  2) Copy template, build and installer script files into correct locations
#  3) Execute hc_build_linux_rpms.sh
#  4) RPM packages may be found in the RPMS directory
#******************************************************************************

BUILD_DIR="$(dirname $0)"

# clean up previous packages
rm -f ${BUILD_DIR}/RPMS/*/* >/dev/null

# build main packages
rpmbuild -bb ${BUILD_DIR}/SPECS/hc-exadata-platform.spec

print "List of built packages:"
ls -l ${BUILD_DIR}/RPMS/*/*

exit 0

#******************************************************************************
# END of script
#******************************************************************************
