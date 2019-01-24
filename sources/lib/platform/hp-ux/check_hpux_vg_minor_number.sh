#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_vg_minor_number
#******************************************************************************
# @(#) Copyright (C) 2016 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
#
# DOCUMENTATION (MAIN)
# -----------------------------------------------------------------------------
# @(#) MAIN: check_hpux_vg_minor_number
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2016-04-28: initial version [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_vg_minor_number
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2019-01-24"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _VG=""
typeset _VG_DUPE=""
typeset _VG_DUPES=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
    esac
done

# get list of major and minor numbers for vgs
vgdisplay -F | cut -f1 -d':' | cut -f2 -d'=' | while read _VG
do
    ls -l ${_VG}/group >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
done

# check unique combination of major/minor numbers
_VG_DUPES="$(awk '{ print $5":"$6 }' ${HC_STDOUT_LOG} | sort | uniq -d)"
if [[ -n ${_VG_DUPES} ]]
then
    print "${_VG_DUPES}" | while read _VG_DUPE
    do
        _MSG="MAJ/MIN numbers combination '${_VG_DUPE}' is not unique"
        _STC=1

        # handle unit result
        log_hc "$0" ${_STC} "${_MSG}"
    done
else
    _MSG="no VGs with duplicate MAJ/MIN numbers detected"

    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}"
fi

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3
PURPOSE : Checks whether all volume groups have a unique minor number

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
