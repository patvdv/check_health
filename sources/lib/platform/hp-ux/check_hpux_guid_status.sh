#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_guid_status.sh
#******************************************************************************
# @(#) Copyright (C) 2017 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_guid_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2017-05-18: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_guid_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2017-05-18"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _GUID_PID=""
typeset _MSG=""
typeset _STC=0
typeset _RC=0

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;  
    esac
done

# ---- process state ----
# 1) try using the PID way
if [[ -r "${_GUID_PID_FILE}" ]]
then
    _GUID_PID=$(<${_GUID_PID_FILE})
    if [[ -n "${_GUID_PID}" ]]
    then
        # get PID list without heading
        (( $(UNIX95= ps -o pid= -p ${_GUID_PID}| wc -l) == 0 )) && _STC=1
    else
        # not running
        _RC=1
    fi
else
    _RC=1
fi

# 2) try the pgrep way (note: old pgreps do not support '-c')
if (( _RC != 0 ))
then
    # we need guidkeyd & guidd
    (( $(pgrep -P 1 -u root guidd 2>>${HC_STDERR_LOG} | wc -l) == 0 )) && _STC=1
    (( $(pgrep -P 1 -u root guidkeyd 2>>${HC_STDERR_LOG} | wc -l) == 0 )) && _STC=$(( _STC + 2 ))
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="guidd/guidkeyd are running"
        ;;
    1)
        _MSG="guidd is not running"
        ;;
    2)
        _MSG="guidkeyd is not running"
        ;;
    3)
        _MSG="guidd/guidkeyd are not running"
        ;;
    *)
        _MSG="could not determine status of GUID daemons"
        ;;
esac

# handle results
log_hc "$0" ${_STC} "${_MSG}"

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3
PURPOSE : Checks whether guid daemons (VSP GUID) are running

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
