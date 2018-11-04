#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_process_limits.sh
#******************************************************************************
# @(#) Copyright (C) 2018 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_linux_process_limits
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2018-07-10: original version [Patrick Van der Veken]
# @(#) 2018-07-12: better log_healthy handling [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_process_limits
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _LINE_COUNT=1
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _MAX_OPEN_FILES=0
typeset _MAX_PROCESSES=0
typeset _PROCESS=""
typeset _PROCESS_LIMIT=""
typeset _PROCESS_SOFT_THRESHOLD=0
typeset _PROCESS_HARD_THRESHOLD=0
typeset _PROCESS_PS=""
typeset _PROCESS_PS_PID=""
typeset _PROCESS_PS_USER=""
typeset _USER=""
typeset _USER_LIMIT=""
typeset _USER_SOFT_THRESHOLD=0
typeset _USER_HARD_THRESHOLD=0
typeset _USER_PS=""
typeset _USER_PS_PID=""
typeset _USER_PS_COMM=""

# set local trap for cleanup
# shellcheck disable=SC2064
trap "rm -f ${_INSTANCE_RUN_FILE}.* >/dev/null 2>&1; return 0" 0
# shellcheck disable=SC2064
trap "rm -f ${_INSTANCE_RUN_FILE}.* >/dev/null 2>&1; return 1" 1 2 3 15

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
# read required configuration values
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

# check PROCESS stanzas
grep -i '^process' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=';' read _ _PROCESS _PROCESS_LIMIT _PROCESS_SOFT_THRESHOLD _PROCESS_HARD_THRESHOLD
do
    # check for empties
    if [[ -z "${_PROCESS}" || -z "${_PROCESS_LIMIT}" ]]
    then
        warn "missing parameter in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
        return 1
    fi
    if [[ -n "${_PROCESS_SOFT_THRESHOLD}" ]]
    then
        data_is_numeric ${_PROCESS_SOFT_THRESHOLD}
        if (( $? > 0 ))
        then
            warn "parameter is not numeric in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
        fi
    fi
    if [[ -n "${_PROCESS_HARD_THRESHOLD}" ]]
    then
        data_is_numeric ${_PROCESS_HARD_THRESHOLD}
        if (( $? > 0 ))
        then
            warn "parameter is not numeric in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
        fi
    fi

    # which limit to check?
    case "${_PROCESS_LIMIT}" in
        "Max open files")
            # collect ps info
            (( ARG_DEBUG > 0 )) && debug "${_PROCESS_LIMIT}: collecting information for process class ${_PROCESS}"
            _PROCESS_PS=$(_get_psinfo_by_process "${_PROCESS}")
            if [[ -z "${_PROCESS_PS}" ]]
            then
                warn "${_PROCESS_LIMIT}: could not find any matching processes for process ${_PROCESS}"
                continue
            fi
            print "${_PROCESS_PS}" | while read _PROCESS_PS_PID _PROCESS_PS_USER
            do
                (( ARG_DEBUG > 0 )) && debug "${_PROCESS_LIMIT}: checking process ${_PROCESS_PS_PID}"
                # get current values and check thresholds
                _MAX_OPEN_FILES=$(_get_open_files ${_PROCESS_PS_PID})
                # SOFT limit
                _check_limit "${_PROCESS_LIMIT}" soft ${_PROCESS_PS_PID} ${_PROCESS_PS_USER} \
                    ${_PROCESS} ${_PROCESS_SOFT_THRESHOLD} ${_MAX_OPEN_FILES} ${_LOG_HEALTHY}
                # HARD limit
                _check_limit "${_PROCESS_LIMIT}" hard ${_PROCESS_PS_PID} ${_PROCESS_PS_USER} \
                    ${_PROCESS} ${_PROCESS_HARD_THRESHOLD} ${_MAX_OPEN_FILES} ${_LOG_HEALTHY}
            done
            ;;
        *)
            # no other limits are supported yet ;-)
            warn "'${_PROCESS_LIMIT}' is an unsupported limit check"
            continue
            ;;
    esac

    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

# check USER stanzas
_LINE_COUNT=0
grep -i '^user' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=';' read _ _USER _USER_LIMIT _USER_SOFT_THRESHOLD _USER_HARD_THRESHOLD
do
    # check for empties
    if [[ -z "${_USER}" || -z "${_USER_LIMIT}" ]]
    then
        warn "missing parameter in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
        return 1
    fi
    if [[ -n "${_USER_SOFT_THRESHOLD}" ]]
    then
        data_is_numeric ${_USER_SOFT_THRESHOLD}
        if (( $? > 0 ))
        then
            warn "parameter is not numeric in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
        fi
    fi
    if [[ -n "${_USER_HARD_THRESHOLD}" ]]
    then
        data_is_numeric ${_USER_HARD_THRESHOLD}
        if (( $? > 0 ))
        then
            warn "parameter is not numeric in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
        fi
    fi

    # which limit to check?
    case "${_USER_LIMIT}" in
        "Max open files")
            # collect ps info
            (( ARG_DEBUG > 0 )) && debug "${_USER_LIMIT}: collecting information for user ${_USER}"
            _USER_PS=$(_get_psinfo_by_user "${_USER}")
            if [[ -z "${_USER_PS}" ]]
            then
                warn "${_USER_LIMIT}: could not find any matching processes for user ${_USER}"
                continue
            fi
            print "${_USER_PS}" | while read _USER_PS_PID _USER_PS_COMM
            do
                (( ARG_DEBUG > 0 )) && debug "${_USER_LIMIT}: checking process ${_USER_PS_PID}"
                # get current values and check thresholds
                _MAX_OPEN_FILES=$(_get_open_files ${_USER_PS_PID})
                # SOFT limit
                _check_limit "${_USER_LIMIT}" soft ${_USER_PS_PID} ${_USER} ${_USER_PS_COMM} \
                    ${_USER_SOFT_THRESHOLD} ${_MAX_OPEN_FILES} ${_LOG_HEALTHY}
                # HARD limit
                _check_limit "${_USER_LIMIT}" hard ${_USER_PS_PID} ${_USER} ${_USER_PS_COMM} \
                    ${_USER_HARD_THRESHOLD} ${_MAX_OPEN_FILES} ${_LOG_HEALTHY}
            done
            ;;
        "Max processes")
            (( ARG_DEBUG > 0 )) && debug "${_USER_LIMIT}: collecting information for user ${_USER}"
            _MAX_PROCESSES=$(_get_processes ${_USER})
            # SOFT limit
            _check_limit "${_USER_LIMIT}" soft 0 ${_USER} "" ${_USER_SOFT_THRESHOLD} \
                ${_MAX_PROCESSES} ${_LOG_HEALTHY}
            # HARD limit
            _check_limit "${_USER_LIMIT}" hard 0 ${_USER} "" ${_USER_HARD_THRESHOLD} \
                ${_MAX_PROCESSES} ${_LOG_HEALTHY}
            ;;
        *)
            # no other limits are supported yet ;-)
            warn "'${_USER_LIMIT}' is an unsupported limit check"
            continue
            ;;
    esac

    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

return 0
}

# -----------------------------------------------------------------------------
# example:
#1991 root
#1992 root
function _get_psinfo_by_process
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}

ps -C "${1}" -o pid:1,user:1 --no-headers 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# example:
#7270 qmgr
#8539 pickup
function _get_psinfo_by_user
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}

ps -U "${1}" -o pid:1,comm:1 --no-headers 2>/dev/null

return 0
}
# -----------------------------------------------------------------------------
function _check_limit
{
typeset _LIMIT_NAME="${1}"
typeset _LIMIT_TYPE="${2}"
typeset _LIMIT_PID=${3}         # can be 0
typeset _LIMIT_USER="${4}"
typeset _LIMIT_PROCESS="${5}"   # can be ""
typeset _LIMIT_THRESHOLD=${6}
typeset _CURR_VALUE=${7}
typeset _LOG_HEALTHY=${8}
typeset _LIMIT_COMMAND=""
typeset _LIMIT_ENTRY=""
typeset _LIMIT_FIELD=0
typeset _MSG_BIT=""
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}

# check for empties
(( _LIMIT_PID == 0 )) && _LIMIT_PID="N/A"
[[ -z "${_LIMIT_PROCESS}" ]] && _LIMIT_PROCESS="N/A"

if [[ -n "${_LIMIT_THRESHOLD}" ]]
then
    # get limit value
    case "${_LIMIT_NAME}" in
        "Max open files")
            _LIMIT_ENTRY=$(grep -i "${_LIMIT_NAME}" /proc/${_LIMIT_PID}/limits 2>/dev/null)
            if [[ -z "${_LIMIT_ENTRY}" ]]
            then
                warn "${_LIMIT_TYPE}: unable to gather limits information (${_LIMIT_PID}/${_LIMIT_USER}/${_LIMIT_PROCESS})"
                return 1
            fi
            case "${_LIMIT_TYPE}" in
                soft)
                    _LIMIT_FIELD=1
                    ;;
                hard)
                    _LIMIT_FIELD=2
                    ;;
            esac
            _LIMIT_VALUE=$(print "${_LIMIT_ENTRY}" | sed -s "s/${_LIMIT_NAME}//g" 2>/dev/null |\
                awk -v f="${_LIMIT_FIELD}" '{ print $f}' 2>/dev/null)
            _MSG_BIT="${_LIMIT_PID}/${_LIMIT_USER}/${_LIMIT_PROCESS}"
            ;;
        "Max processes")
            case "${_LIMIT_TYPE}" in
                soft)
                    _LIMIT_COMMAND="ulimit -a"
                    ;;
                hard)
                    _LIMIT_COMMAND="ulimit -Ha"
                    ;;
            esac
            _LIMIT_VALUE=$(su - ${_LIMIT_USER} -c "${_LIMIT_COMMAND}" 2>/dev/null |\
                grep -i "max user processes" 2>/dev/null | sed -s "s/max user processes//g" 2>/dev/null |\
                awk '{ print $2}' 2>/dev/null)
            if [[ -z "${_LIMIT_VALUE}" ]]
            then
                warn "${_LIMIT_TYPE}: unable to gather limits information (${_LIMIT_USER})"
                return 1
            fi
            _MSG_BIT="${_LIMIT_USER}"
            ;;
    esac
    # check limit value -> threshold
    if [[ "${_LIMIT_VALUE}" = "unlimited" ]]
    then
        log "limit (${_LIMIT_TYPE} on '${_LIMIT_NAME}' is unlimited (${_MSG_BIT})"
        return 0
    else
        if (( _CURR_VALUE > (_LIMIT_VALUE * _LIMIT_THRESHOLD / 100) ))
        then
            _MSG="(${_MSG_BIT}) limit (${_LIMIT_TYPE}) on '${_LIMIT_NAME}' has been surpassed (${_CURR_VALUE} > ${_LIMIT_VALUE} @${_LIMIT_THRESHOLD}%)"
            log_hc "$0" 1 "${_MSG}" ${_CURR_VALUE} $(( _LIMIT_VALUE * _LIMIT_THRESHOLD / 100 ))
        else
            if (( _LOG_HEALTHY > 0 ))
            then
                _MSG="(${_MSG_BIT}) limit (${_LIMIT_TYPE}) on '${_LIMIT_NAME}' is safe (${_CURR_VALUE} <= ${_LIMIT_VALUE} @${_LIMIT_THRESHOLD}%)"
                log_hc "$0" 0 "${_MSG}" ${_CURR_VALUE} $(( _LIMIT_VALUE * _LIMIT_THRESHOLD / 100 ))
            fi
        fi
    fi
else
    warn "limit on (${_LIMIT_TYPE} on '${_LIMIT_NAME}' was not checked (PID=${_LIMIT_PID})"
fi

return 0
}

# -----------------------------------------------------------------------------
function _get_open_files
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}

ls -f /proc/${1}/fd/ 2>/dev/null | wc -l 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
function _get_processes
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}

ps -U ${1} --no-headers 2>/dev/null | wc -l 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with:
                log_healthy=<yes|no>
                and formatted stanzas:
                    user:<user_name>:<limit_name>:<soft_limit_threshold_%>:<hard_limit_threshold_%>
                    process:<process_name>:<limit_name>:<soft_limit_threshold_%>:<hard_limit_threshold_%>
PURPOSE     : Checks the value(s) of the process limits from /proc/*/limits or ulimit
              Currenty following checks are supported:
                * Max open files (/proc/*/limits)
                * Max processes (ulimit)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
