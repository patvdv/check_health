#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_cron_status.sh
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
# @(#) MAIN: check_hpux_cron_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_is_numeric(), data_comma2space(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2018-02-08: initial version [Patrick Van der Veken]µ
# @(#) 2018-02-13: fix to avoid log check if cron is not active [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2021-03-25: make _WAIT_TIME & _CRON_LOG_FILE configurable [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_cron_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2021-03-25"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CFG_CRON_LOG_FILE=""
typeset _CFG_WAIT_TIME=""
typeset _LOG_HEALTHY=0
typeset _CRON_LOG_FILE=""
typeset _WAIT_TIME=""
typeset _JOB_ID=""
typeset _AT_BIN=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage "${0}" "${_VERSION}" "${_CONFIG_FILE}" && return 0
            ;;
    esac
done

# handle configuration file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]]
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
_CFG_WAIT_TIME=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'wait_time')
if [[ -z "${_CFG_WAIT_TIME}" ]]
then
    # default
    _WAIT_TIME=10
    log "setting value for parameter wait_time to its default (${_WAIT_TIME})"
else
    data_is_numeric "${_CFG_WAIT_TIME}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "wait time parameter is not numeric in configuration file ${_CONFIG_FILE}"
        return 1
    else
        _WAIT_TIME=${_CFG_WAIT_TIME}
    fi
fi
_CFG_CRON_LOG_FILE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'cron_log')
if [[ -z "${_CFG_CRON_LOG_FILE}" ]]
then
    # default
    _CRON_LOG_FILE="/var/adm/cron/log"
    log "setting value for parameter cron_log to its default (${_CRON_LOG_FILE})"
else
    _CRON_LOG_FILE="${_CFG_CRON_LOG_FILE}"
    log "setting value for parameter cron_log (${_CRON_LOG_FILE})"
fi
_CFG_HEALTHY=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'log_healthy')
case "${_CFG_HEALTHY}" in
    yes|YES|Yes)
        _LOG_HEALTHY=1
        ;;
    *)
        # do not override hc_arg
        (( _LOG_HEALTHY > 0 )) || _LOG_HEALTHY=0
        ;;
esac

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

# check timeout (_WAIT_TIME must be at least 30 secs smaller than health check timeout)
if (( _WAIT_TIME > 0 ))
then
    if (( (_WAIT_TIME + 30) > HC_TIME_OUT ))
    then
        warn "wait time value will conflict with health check timeout. Specify a (larger) --timeout value"
    return 1
    fi
fi

# ---- process state ----
# try the pgrep way (note: old pgreps do not support '-c')
(( ARG_DEBUG > 0 )) && debug "checking cron service via pgrep"
(( $(pgrep -u root cron 2>>"${HC_STDERR_LOG}" | wc -l 2>/dev/null) == 0 )) && _STC=1

# evaluate results
case ${_STC} in
    0)
        _MSG="cron is running"
        ;;
    1)
        _MSG="cron is not running"
        ;;
    *)
        _MSG="could not determine status of cron"
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
    # return if cron is not running
    (( _STC > 0 )) && return 1
fi

# ---- log state ----
# check cron log file
if [[ ! -r ${_CRON_LOG_FILE} ]]
then
    _MSG="cron log does not exist (${_CRON_LOG_FILE})"
    _STC=1
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" 1 "${_MSG}"
    fi
    return 0
fi
# create test event
_AT_BIN=$(command -v at 2>>"${HC_STDERR_LOG}")
if [[ -x ${_AT_BIN} && -n "${_AT_BIN}" ]]
then
    # start test job
    (( ARG_DEBUG > 0 )) && debug "checking cron log via {${_AT_BIN}}"
    (echo "*** CHECK LOG ***" >/dev/null | ${_AT_BIN} now) >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
    sleep "${_WAIT_TIME}"
    if (( $(grep -c 'cron may not be running' "${HC_STDERR_LOG}" 2>/dev/null) == 0 ))
    then
        # find job results
        _JOB_ID=$(grep -E -e '^job' "${HC_STDERR_LOG}" 2>/dev/null | awk '{ print $2}' 2>/dev/null)
        if [[ -n "${_JOB_ID}" ]] && (( $(grep -c "${_JOB_ID}" "${_CRON_LOG_FILE}" 2>/dev/null) > 0 ))
        then
            _MSG="cron is logging correctly, schedule via {${_AT_BIN}} OK"
            _STC=0
        else
            _MSG="cron is not logging (correctly), schedule via {${_AT_BIN}} NOK"
            _STC=1
        fi
    else
        _MSG="cron is not logging (correctly), schedule via {${_AT_BIN}} NOK"
        _STC=1
    fi
else
    # check cron log itself
    (( ARG_DEBUG > 0 )) && debug "checking cron log via file check"
    if [[ -s ${_CRON_LOG_FILE} ]]
    then
        _MSG="cron is logging correctly (${_CRON_LOG_FILE})"
        _STC=0
    else
        _MSG="cron is not logging (correctly) (${_CRON_LOG_FILE})"
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
CONFIG      : $3 with parameters:
                log_healthy=<yes|no>
                wait_time=<seconds>
                cron_log=<file_path>
PURPOSE     : Checks whether cron (CRON) service is running and whether cron is
              actually logging to the cron log file.
LOG HEALTHY : Supported

EOT

return 0
}


#******************************************************************************
# END of script
#******************************************************************************
