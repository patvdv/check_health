#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_shorewall_status.sh
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
# @(#) MAIN: check_linux_shorewall_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2016-12-01: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_shorewall_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _SHOREWALL_BIN="/sbin/shorewall"
typeset _VERSION="2016-12-01"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
    esac
done


# check status
if [[ -x ${_SHOREWALL_BIN} && -n "${_SHOREWALL_BIN}" ]]
then
    # check status
    ${_SHOREWALL_BIN} status >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    if (( $? == 0 ))
    then
        _MSG="shorewall is running"
        _STC=0
    else
        _MSG="shorewall is not running {shorewall status}"
        _STC=1
    fi
    log_hc "$0" ${_STC} "${_MSG}"

    # check compile
    ${_SHOREWALL_BIN} check >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    if (( $? == 0 ))
    then
        _MSG="shorewall rules compile correctly"
        _STC=0
    else
        _MSG="shorewall rules do not compile correctly {shorewall check}"
        _STC=1
    fi
    log_hc "$0" ${_STC} "${_MSG}"
else
    warn "shorewall is not installed here"
    return 1
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
PURPOSE : Checks whether shorewall (firewall) service is running and whether
          shorewall rules compile correctly

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
