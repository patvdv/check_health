#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_autofs.sh
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
# @(#) MAIN: check_linux_autofs
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_is_numeric(), dump_logs(), init_hc(),
#           linux_change_service(), linux_has_service(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-07-14: original version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_autofs
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-07-14"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# shellcheck disable=SC2034
typeset _HC_CAN_FIX=1                                   # plugin has fix/healing logic?
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CFG_FIX_AUTOFS=""
typeset _FIX_AUTOFS=0
typeset _IS_ACTIVE=0
typeset _HAS_SERVICE=0
typeset _RETRY_START=3
typeset _SLEEP_TIME=5
typeset _RETRY_COUNT=1

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
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
_CFG_FIX_AUTOFS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'fix_autofs')
case "${_CFG_FIX_AUTOFS}" in
    yes|YES|Yes)
        _FIX_AUTOFS=1
        ;;
    *)
        _FIX_AUTOFS=0
        ;;
esac
_CFG_RETRY_START=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'retry_start')
data_is_numeric "${_CFG_RETRY_START}"
# shellcheck disable=SC2181
if (( $? > 0 ))
then
    warn "value for parameter 'retry_count' in configuration file ${_CONFIG_FILE} is invalid"
    return 1
else
    _RETRY_START=${_CFG_RETRY_START}
fi
_CFG_SLEEP_TIME=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'sleep_time')
data_is_numeric "${_CFG_SLEEP_TIME}"
# shellcheck disable=SC2181
if (( $? > 0 ))
then
    warn "value for parameter 'sleep_time' in configuration file ${_CONFIG_FILE} is invalid"
    return 1
else
    _SLEEP_TIME=${_CFG_SLEEP_TIME}
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

# log_healthy/--log-healthy
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
# --no-fix
if (( ARG_NO_FIX > 0 ))
then
    _FIX_AUTOFS=0
    log "fix/healing logic has been disabled"
fi

# check if autofs is enabled
log "checking if autofs daemon is enabled"
_HAS_SERVICE=$(linux_has_service "autofs")
if (( _HAS_SERVICE == 2 ))
then
    _MSG="autofs service is enabled"
    _STC=0
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    # check if autofs is running
    log "checking if autofs daemon is active"
    _IS_ACTIVE=$(linux_runs_service autofs)
    if (( _IS_ACTIVE > 0 ))
    then
        _MSG="autofs daemon is running"
        _STC=0
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
        fi
    else
        warn "autofs daemon is not running"
        # try restart if healing is desired
        if (( _FIX_AUTOFS > 0 ))
        then
            while (( _RETRY_COUNT <= _RETRY_START && _IS_ACTIVE == 0 ))
            do
                log "restarting autofs (attempt #${_RETRY_COUNT})"
                linux_change_service "autofs" "restart" >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
                # dump debug info
                (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
                log "sleeping for ${_SLEEP_TIME} seconds"
                sleep ${_SLEEP_TIME}
                _RETRY_COUNT=$(( _RETRY_COUNT + 1 ))
                _IS_ACTIVE=$(linux_runs_service "autofs")
            done
            # check again if autofs is running
            _IS_ACTIVE=$(linux_runs_service "autofs")
            if (( _IS_ACTIVE > 0 ))
            then
                _MSG="autofs daemon is running"
                _STC=0
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}"
                fi
            else
                _MSG="autofs daemon is not running"
                _STC=1
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}"
                fi
            fi
        else
            _MSG="autofs daemon is not running"
            _STC=1
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}"
            fi
        fi
    fi
else
    _MSG="autofs service is disabled"
    _STC=1
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
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
                fix_autofs=<yes|no>
                retry_start=<amount_of_start_retries>
                sleep_time=<seconds_to_sleep_during_restart_attempts>
PURPOSE     : Check/fix AutoFS service
LOG HEALTHY : Supported
CAN FIX?    : Yes

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
