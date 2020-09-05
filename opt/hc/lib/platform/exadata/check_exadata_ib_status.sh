#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_ib_status.sh
#******************************************************************************
# @(#) Copyright (C) 2020 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_exadata_ib_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2020-07-07: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_ib_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2020-07-07"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _IBSTATUS_BIN="/usr/sbin/ibstatus"
typeset _IBSWITCHES_BIN="/usr/sbin/ibswitches"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0
typeset _IBSTATUS_OUTPUT=""
typeset _IBSWITCHES_OUTPUT=""
typeset _NUM_INACTIVE_PORTS=0
typeset _NUM_SWITCHES=0

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

# check IB tools
if [[ ! -x ${_IBSTATUS_BIN} || -z "${_IBSWITCHES_BIN}" ]]
then
    warn "IB tools are not installed here. This is not an Exadata compute node?"
    return 1
fi

# gather infiniband status data
(( ARG_DEBUG > 0 )) && debug "executing command {${_IBSTATUS_BIN}}"
_IBSTATUS_OUTPUT=$(${_IBSTATUS_BIN} 2>>${HC_STDERR_LOG})
# shellcheck disable=SC2181
if (( $?> 0 )) || [[ -z "${_IBSTATUS_OUTPUT}" ]]
then
    _MSG="unable to run command {${_IBSTATUS_BIN}}"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi
(( ARG_DEBUG > 0 )) && debug "executing command {${_IBSWITCHES_BIN}}"
_IBSWITCHES_OUTPUT=$(${_IBSWITCHES_BIN} 2>>${HC_STDERR_LOG})
# shellcheck disable=SC2181
if (( $?> 0 )) || [[ -z "${_IBSWITCHES_OUTPUT}" ]]
then
    _MSG="unable to run command {${_IBSWITCHES_BIN}}"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi

# perform checks on IB status data
_NUM_INACTIVE_PORTS=$(print -R "${_IBSTATUS_OUTPUT}" | grep -E -e '^[[:space:]]+state:' 2>/dev/null | grep -c -v "ACTIVE" 2>/dev/null)
if (( _HAS_OFFLINE_PORTS > 0 ))
then
    _MSG="${_NUM_INACTIVE_PORTS} IB port(s) are/is in state INACTIVE"
    _STC=1
else
    _MSG="all IB port(s) are/is in ACTIVE state"
    _STC=0
fi
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

# perform checks on IB switches data
_NUM_SWITCHES=$(print -R "${_IBSWITCHES_OUTPUT}" | wc -l 2>/dev/null)
if (( _NUM_SWITCHES != 2 ))
then
    _MSG="only ${_NUM_SWITCHES} IB switch(es) are/is reporting (${_NUM_SWITCHES}<>2)"
    _STC=1
else
    _MSG="${_NUM_SWITCHES} IB switch(es) are/is reporting"
    _STC=0
fi
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

# add IB output to stdout log
print "==== {${_IBSTATUS_BIN}} ====" >>${HC_STDOUT_LOG}
print "${_IBSTATUS_OUTPUT}" >>${HC_STDOUT_LOG}

print "==== {${_IBSWITCHES_BIN}} ====" >>${HC_STDOUT_LOG}
print "${_IBSWITCHES_OUTPUT}" >>${HC_STDOUT_LOG}

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
PURPOSE     : 1) Checks that (local) Infiniband ports are in active
              2) Checks that Infiniband switches are present (should be 2)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
