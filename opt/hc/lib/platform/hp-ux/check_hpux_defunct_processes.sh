#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_defunct_processes.sh
#******************************************************************************
# @(#) Copyright (C) 2021 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_defunct_processes
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), data_is_numeric(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2021-04-07: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_defunct_processes
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2021-04-07"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_GROUP_BY_PPID=""
typeset _GROUP_BY_PPID=""
typeset _CFG_PROCESS_THRESHOLD=""
typeset _PROCESS_THRESHOLD=""
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _DEFUNCT_PROCS=""
typeset _NUM_DEFUNCT_PROCS=""
typeset _PPID=""

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
# read required configuration values
_CFG_PROCESS_THRESHOLD=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'process_threshold')
if [[ -z "${_CFG_PROCESS_THRESHOLD}" ]]
then
    # default
    _PROCESS_THRESHOLD=10
    log "setting value for parameter process_threshold to its default (10)"
else
    data_is_numeric "${_CFG_PROCESS_THRESHOLD}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "value for parameter process_threshold in configuration file ${_CONFIG_FILE} is invalid"
        return 1
    else
        _PROCESS_THRESHOLD=${_CFG_PROCESS_THRESHOLD}
        log "setting value for parameter collect_interval (${_PROCESS_THRESHOLD})"
    fi
fi
_CFG_GROUP_BY_PPID=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'group_by_ppid')
case "${_CFG_GROUP_BY_PPID}" in
    no|NO|No)
        _GROUP_BY_PPID=0
        log "setting value for parameter group_by_ppid (No)"
        ;;
    *)
        # default
        _GROUP_BY_PPID=1
        log "setting value for parameter group_by_ppid to its default (Yes)"
        ;;
esac
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

# collect defunct processes
# shellcheck disable=SC2009
_DEFUNCT_PROCS=$(UNIX95=1 ps -eo ppid,pid,comm,etime 2>"${HC_STDERR_LOG}" | tee -a "${HC_STDOUT_LOG}" 2>/dev/null | grep '[d]efunct' 2>/dev/null)

# check defunct processes
if [[ -z "${_DEFUNCT_PROCS}" ]]
then
    _MSG="no defunct process(es) detected"
    _STC=0
    if (( _LOG_HEALTHY > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    return 0
else
    if (( _GROUP_BY_PPID > 0 ))
    then
        # per by PPID
        print -R "${_DEFUNCT_PROCS}" | awk '

            {
                # count PIDs per PPID
                counts[$1]++;
            }

            END {
                for (i in counts) print i ":" counts[i]
            }' 2>/dev/null | while IFS=":" read -r _PPID _NUM_DEFUNCT_PROCS
        do
            (( ARG_DEBUG > 0 )) && debug "awk found PPID: ${_PPID} with # procs: ${_NUM_DEFUNCT_PROCS}"
            if (( _NUM_DEFUNCT_PROCS <= _PROCESS_THRESHOLD ))
            then
                _MSG="defunct process(es) detected for PPID (${_PPID}) but are still under threshold (${_NUM_DEFUNCT_PROCS}<=${_PROCESS_THRESHOLD})"
                _STC=0
            else
                _MSG="defunct process(es) detected for PPID (${_PPID}) and are over threshold (${_NUM_DEFUNCT_PROCS}>${_PROCESS_THRESHOLD})"
                _STC=1
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_NUM_DEFUNCT_PROCS}" "${_PROCESS_THRESHOLD}"
            fi
        done
    else
        _NUM_DEFUNCT_PROCS=$(print -R "${_DEFUNCT_PROCS}" | wc -l 2>/dev/null)
        if (( _NUM_DEFUNCT_PROCS <= _PROCESS_THRESHOLD ))
        then
            _MSG="defunct process(es) detected but are still under threshold (${_NUM_DEFUNCT_PROCS}<=${_PROCESS_THRESHOLD})"
            _STC=0
        else
            _MSG="defunct process(es) detected and are over threshold (${_NUM_DEFUNCT_PROCS}>${_PROCESS_THRESHOLD})"
            _STC=1
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_NUM_DEFUNCT_PROCS}" "${_PROCESS_THRESHOLD}"
        fi
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
                process_threshold=<#_of_processes>
                group_by_ppid=<yes|no>
PURPOSE     : Checks whether there are (too many) defunct processes on the host.
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
