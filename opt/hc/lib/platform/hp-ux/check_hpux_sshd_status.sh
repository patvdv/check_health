#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_sshd_status.sh
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
# @(#) MAIN: check_hpux_sshd_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: datadata_comma2spacespace2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2017-04-01: initial version [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]

# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_sshd_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _SSHD_PID_FILE="/var/run/sshd/sshd.pid"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _SSHD_PID=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0
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

# log_healthy
(( ARG_LOG_HEALTHY > 0 )) && _LOG_HEALTHY=1
if (( _LOG_HEALTHY > 0 ))
then
    if (( ARG_LOG > 0 ))
    then
        log "logging/showing passed health checks"
    else
        log "showing passed health checks (but not logging)"
    fi
else
    log "not logging/showing passed health checks"
fi

# ---- process state ----
# 1) try using the PID way
if [[ -r "${_SSHD_PID_FILE}" ]]
then
    _SSHD_PID=$(<${_SSHD_PID_FILE})
    if [[ -n "${_SSHD_PID}" ]]
    then
        # get PID list without heading
        (( $(UNIX95='' ps -o pid= -p ${_SSHD_PID}| wc -l) == 0 )) && _STC=1
    else
        # not running
        _RC=1
    fi
else
    _RC=1
fi

# 2) try the pgrep way (note: old pgreps do not support '-c')
if (( _RC > 0 ))
then
    (( $(pgrep -P 1 -u root sshd 2>>${HC_STDERR_LOG} | wc -l) == 0 )) && _STC=1
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="sshd is running"
        ;;
    1)
        _MSG="sshd is not running"
        ;;
    *)
        _MSG="could not determine status of sshd"
        ;;
esac

# report results
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
NAME        : $1
VERSION     : $2
PURPOSE     : Checks whether sshd (Secure Shell daemon) is running
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
