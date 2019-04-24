#!/usr/bin/env ksh
#******************************************************************************
# @(#) CGK build script for HC SD packages (uses 'swpackage')
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
#   build/hpux/<build_files>
#   build/hpux/check_health-build_hpux_depots.sh
#   opt/hc/bin/<hc_scripts>
#   opt/hc/lib/*/<hc_plugins>
#   etc/opt/hc/<hc_configs>
#   depots/
#
# Build order:
#  1) Copy sources/scrips to the correct locations
#  2) Copy pristine version of the build spec file to preserver %BUILD_DATE% (.psf)
#  3) Copy template, build and installer script files into correct locations
#  4) Execute check_health-build_hpux_depots.sh
#  5) SD packages may be found in the 'depots' directory
#******************************************************************************

BUILD_DATE="$(date +'%Y%m%d')"
BUILD_PRETTY_DATE="$(date +'%Y.%m.%d')"
BUILD_DIR=$(dirname "${0}")
DEPOTS_DIR="${BUILD_DIR}/../../depots"

case "${1}" in
    prod)
        SW_DEPOT_LOC="/var/opt/ignite/depots/3rdparty"
        ;;
    *)
        SW_DEPOT_LOC="/var/opt/ignite/depots/3rdparty-test"
        ;;
esac

# replace BUILD_DATE placeholder in PSF file(s)
function fix_build_date
{
find . -name "*.psf" | while read -r FILE
do
    if (( $(grep -c '%BUILD_DATE%' "${FILE}") == 0 ))
    then
        print -u2 "ERROR: no %BUILD_DATE% placeholder in ${FILE}!"
        exit 1
    else
        perl -pi -e "s/%BUILD_DATE%/${BUILD_PRETTY_DATE}/g" "${FILE}"
    fi
done
}

# check for depot directory or clean up previous packages
if [[ -d "${DEPOTS_DIR}" ]]
then
    # shellcheck disable=SC2086
    rm -f ${DEPOTS_DIR}/hc_hpux*.sd ${DEPOTS_DIR}/hc_display*.sd ${DEPOTS_DIR}/hc_notify*.sd >/dev/null
else
    mkdir -p "${DEPOTS_DIR}" || exit 1
fi

# build hc_hpux package
cd "${BUILD_DIR}/hc_hpux/" || exit 1
fix_build_date
swpackage -s hc_hpux.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_hpux-${BUILD_DATE}.sd"
swpackage -s hc_hpux.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_hpux_platform package
cd "${BUILD_DIR}/hc_hpux_platform" || exit 1
fix_build_date
swpackage -s hc_hpux_platform.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_hpux_platform-${BUILD_DATE}.sd"
swpackage -s hc_hpux_platform.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_display_csv package
cd "${BUILD_DIR}/hc_display_csv" || exit 1
fix_build_date
swpackage -s hc_display_csv.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_display_csv-${BUILD_DATE}.sd"
swpackage -s hc_display_csv.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_display_init package
cd "${BUILD_DIR}/hc_display_init" || exit 1
fix_build_date
swpackage -s hc_display_init.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_display_init-${BUILD_DATE}.sd"
swpackage -s hc_display_init.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_display_json package
cd "${BUILD_DIR}/hc_display_json" || exit 1
fix_build_date
swpackage -s hc_display_json.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_display_json-${BUILD_DATE}.sd"
swpackage -s hc_display_json.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_display_terse package
cd "${BUILD_DIR}/hc_display_terse" || exit 1
fix_build_date
swpackage -s hc_display_terse.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_display_terse-${BUILD_DATE}.sd"
swpackage -s hc_display_terse.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_display_zenoss package
cd "${BUILD_DIR}/hc_display_zenoss" || exit 1
fix_build_date
swpackage -s hc_display_zenoss.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_display_zenoss-${BUILD_DATE}.sd"
swpackage -s hc_display_zenoss.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_notify_sms package
cd "${BUILD_DIR}/hc_notify_sms" || exit 1
fix_build_date
swpackage -s hc_notify_sms.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_notify_sms-${BUILD_DATE}.sd"
swpackage -s hc_notify_sms.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# build hc_notify_eif package
cd "${BUILD_DIR}/hc_notify_eif" || exit 1
fix_build_date
swpackage -s hc_notify_eif.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_notify_eif-${BUILD_DATE}.sd"
swpackage -s hc_notify_eif.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

# -- additional depots --
# build hc_serviceguard_platform package
cd "${BUILD_DIR}/hc_serviceguard_platform" || exit 1
fix_build_date
swpackage -s hc_serviceguard_platform.psf -x media_type=tape -d "${DEPOTS_DIR}/hc_serviceguard_platform-${BUILD_DATE}.sd"
swpackage -s hc_serviceguard_platform.psf @ ${SW_DEPOT_LOC}
cd - || exit 1

print "INFO: list of built packages (local @${DEPOTS_DIR}):"
# shellcheck disable=SC2086
ls -l ${DEPOTS_DIR}/hc_hpux*.sd ${DEPOTS_DIR}/hc_display*.sd ${DEPOTS_DIR}/hc_notify*.sd

print "INFO: list of built packages (central @${SW_DEPOT_LOC}):"
swlist @ ${SW_DEPOT_LOC} | grep "HC-"

exit 0

#******************************************************************************
# END of script
#******************************************************************************
