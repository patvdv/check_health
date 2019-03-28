#!/usr/bin/env ksh
#******************************************************************************
# @(#) build script for HC SD packages (uses 'swpackage')
#******************************************************************************
# @(#) Copyright (C) 2014 by KUDOS BVBA (info@kudos.be).  All rights reserved.
#
# This program is a free software; you can redistribute it and/or modify
# it under the same terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details
#******************************************************************************

#******************************************************************************
# Requires following build (dir) structures:
#
#   build/<platform>/<build_files>
#   build/build_hpux_depots.sh
#   opt/hc/bin/<hc_scripts>
#   opt/hc/lib/*/<hc_plugins>
#   etc/opt/hc/<hc_configs>
#   depots/
#
# Build order:
#  1) Copy sources/scrips to the correct locations
#  2) Copy pristine version of the build spec file to preserver %BUILD_DATE% (.psf)
#  3) Copy template, build and installer script files into correct locations
#  4) Execute build_hpux_depots.sh
#  5) SD packages may be found in the 'depots' directory
#******************************************************************************

BUILD_DATE="$(date +'%Y%m%d')"
BUILD_PRETTY_DATE="$(date +'%Y.%m.%d')"
BUILD_DIR="$(dirname $0)"

# clean up previous packages
if [[ -d ../../depots ]]
then
    rm -f ../../depots/* 2>/dev/null
else
    mkdir -p ../../depots 2>/dev/null
fi

# see if we have BUILD_DATE placeholder in PSF files
find ${BUILD_DIR} -name "*.psf" | while read FILE
do
    if (( $(grep -c '%BUILD_DATE%' ${FILE}) == 0 ))
    then
        print -u2 "ERROR: no %BUILD_DATE% placeholder in ${FILE}!"
        exit 1
    fi
done

# replace BUILD_DATE placeholder in PSF files
find ${BUILD_DIR} -name "*.psf" | while read FILE
do
    perl -pi -e "s/%BUILD_DATE%/${BUILD_PRETTY_DATE}/g" ${FILE}
done

# build hc_hpux package
cd ${BUILD_DIR}/hc_hpux/ || exit 1
swpackage -s hc_hpux.psf -x media_type=tape -d ../../../depots/hc_hpux-${BUILD_DATE}.sd
cd - || exit 1

# build hc_hpux_platform package
cd ${BUILD_DIR}/hc_hpux_platform || exit 1
swpackage -s hc_hpux_platform.psf -x media_type=tape -d ../../../depots/hc_hpux_platform-${BUILD_DATE}.sd
cd - || exit 1

# build hc_display_csv package
cd ${BUILD_DIR}/hc_display_csv || exit 1
swpackage -s hc_display_csv.psf -x media_type=tape -d ../../../depots/hc_display_csv-${BUILD_DATE}.sd
cd - || exit 1

# build hc_display_init package
cd ${BUILD_DIR}/hc_display_init || exit 1
swpackage -s hc_display_init.psf -x media_type=tape -d ../../../depots/hc_display_init-${BUILD_DATE}.sd
cd - || exit 1

# build hc_display_json package
cd ${BUILD_DIR}/hc_display_json || exit 1
swpackage -s hc_display_json.psf -x media_type=tape -d ../../../depots/hc_display_json-${BUILD_DATE}.sd
cd - || exit 1

# build hc_display_terse package
cd ${BUILD_DIR}/hc_display_terse || exit 1
swpackage -s hc_display_terse.psf -x media_type=tape -d ../../../depots/hc_display_terse-${BUILD_DATE}.sd
cd - || exit 1

# build hc_display_zenoss package
cd ${BUILD_DIR}/hc_display_zenoss || exit 1
swpackage -s hc_display_zenoss.psf -x media_type=tape -d ../../../depots/hc_display_zenoss-${BUILD_DATE}.sd
cd - || exit 1

# build hc_notify_sms package
cd ${BUILD_DIR}/hc_notify_sms || exit 1
swpackage -s hc_notify_sms.psf -x media_type=tape -d ../../../depots/hc_notify_sms-${BUILD_DATE}.sd
cd - || exit 1

# build hc_notify_eif package
cd ${BUILD_DIR}/hc_notify_eif || exit 1
swpackage -s hc_notify_eif.psf -x media_type=tape -d ../../../depots/hc_notify_eif-${BUILD_DATE}.sd
cd - || exit 1

print "List of built packages:"
ls -l ../../depots/*

# when installed on an ignite server: possible addition of depot registration here

exit 0

#******************************************************************************
# END of script
#******************************************************************************
