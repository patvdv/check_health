#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_syslogd_status.sh
#******************************************************************************
# @(#) Copyright (C) 2019 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_syslogd_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2018-02-08: initial version [Patrick Van der Veken]
# @(#) 2018-02-13: fix to avoid log check if syslogd is not active [Patrick Van der Veken]
# @(#) 2019-03-09: text updates [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_syslogd_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _SYSLOGD_PID_FILE="/var/run/syslog.pid"
typeset _SYSLOGD_LOG_FILE="/var/adm/syslog.log"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _SYSLOGD_PID=""
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _RC=0
typeset _LOGGER_BIN=""
typeset _LOG_HEALTHY=0

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
if [[ -r "${_SYSLOGD_PID_FILE}" ]]
then
    (( ARG_DEBUG > 0 )) && debug "checking syslogd service via PID file"
    _SYSLOGD_PID=$(<${_SYSLOGD_PID_FILE})
    if [[ -n "${_SYSLOGD_PID}" ]]
    then
        # get PID list without heading
        (( $(UNIX95='' ps -o pid= -p ${_SYSLOGD_PID} 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
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
    (( ARG_DEBUG > 0 )) && debug "checking syslogd service via pgrep"
    (( $(pgrep -u root syslogd 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="syslogd is running"
        ;;
    1)
        _MSG="syslogd is not running"
        ;;
    *)
        _MSG="could not determine status of syslogd"
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
    # return if syslogd is not running
    (( _STC > 0 )) && return 1
fi

# ---- log state ----
_LOGGER_BIN="$(which logger 2>>${HC_STDERR_LOG})"
if [[ -x ${_LOGGER_BIN} && -n "${_LOGGER_BIN}" ]]
then
    # write test entry
    (( ARG_DEBUG > 0 )) && debug "checking syslogd log via {${_LOGGER_BIN}}"
    ${_LOGGER_BIN} -i -t "check_health" "*** LOG CHECK ***" >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    if (( $? == 0 ))
    then
        _MSG="syslogd is logging correctly, write via {${_LOGGER_BIN}} OK"
        _STC=0
    else
        _MSG="syslogd is not logging (correctly), write via {${_LOGGER_BIN}} NOK"
        _STC=1
    fi
else
    # check the syslog itself
    (( ARG_DEBUG > 0 )) && debug "checking syslogd log via file check"
    if [[ -r ${_SYSLOGD_LOG_FILE} ]] && [[ -s ${_SYSLOGD_LOG_FILE} ]]
    then
        _MSG="syslogd is logging correctly (${_CRON_LOG_FILE})"
        _STC=0
    else
        _MSG="syslogd is not logging (correctly) (${_SYSLOGD_LOG_FILE})"
        _STC=1
    fi
fi
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
VERSION     : $2
PURPOSE     : Checks whether syslogd service is running and whether syslogd
              is actually logging to ${_SYSLOGD_LOG_FILE}.
LOG HEALTHY : Supported

EOT

return 0
}


#******************************************************************************
# END of script
#******************************************************************************
