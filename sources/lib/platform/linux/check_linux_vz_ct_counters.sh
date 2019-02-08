#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_vz_ct_counters.sh
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
# @(#) MAIN: check_linux_vz_ct_counters
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_is_numeric(), data_strip_space(),
#           dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-08: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_vz_ct_counters
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VZUBC_BIN="/usr/sbin/vzubc"
typeset _VZUBC_OPTS="-q -i -r"
typeset _VERSION="2019-02-08"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
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
typeset _CT_ID=""
typeset _UBC_OUTPUT=""
typeset _UBC_NAME=""
typeset _UBC_FAIL=""
typeset _UBC_HELD=""
typeset _UBC_MAX_HELD=""
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

# handle configuration file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]]
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
# read configuration values
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

# check openvz
if [[ ! -x ${_VZUBC_BIN} || -z "${_VZUBC_BIN}" ]]
then
    warn "OpenVZ is not installed here"
    return 1
fi

# check configuration values
grep -E -e '^ct:' ${_CONFIG_FILE} 2>/dev/null | cut -f2 -d':' 2>/dev/null |\
    while read -r _CT_ID
do
    data_is_numeric "${_CT_ID}"
    if (( $? > 0 ))
    then
        warn "${_CT_ID} appears to be an incorrect value for CT ID"
        continue
    fi

    # get bean counters
    _UBC_OUTPUT=$(${_VZUBC_BIN} ${_VZUBC_OPTS} ${_CT_ID} 2>>${HC_STDERR_LOG})
    if (( $? > 0 )) || [[ -z "${_UBC_OUTPUT}" ]]
    then
        warn "unable to run command {${_VZUBC_BIN}}. Container ${_CT_ID} does not exist?"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        _RC=1
        continue
    fi

    # check values (data lines start with a space)
    print "${_UBC_OUTPUT}" | grep "^ " 2>/dev/null | while read -r _UBC_LINE
    do
        _UBC_NAME=$(data_strip_space "$(print ${_UBC_LINE} | cut -f1 -d'|' 2>/dev/null)")
        _UBC_FAIL=$(data_strip_space "$(print ${_UBC_LINE} | cut -f6 -d'|' 2>/dev/null)")
        _UBC_HELD=$(data_strip_space "$(print ${_UBC_LINE} | cut -f2 -d'|' 2>/dev/null | awk '{print $1}')")
        _UBC_MAX_HELD=$(data_strip_space "$(print ${_UBC_LINE} | cut -f3 -d'|' 2>/dev/null | awk '{print $1}')")

        if [[ -z "${_UBC_FAIL}" ]] || [[ "${_UBC_FAIL}" = '-' ]]
        then
            _MSG="${_UBC_NAME} for CT ${_CT_ID} is unchanged [HELD:${_UBC_HELD}/MAX_HELD:${_UBC_MAX_HELD}]"
            _STC=0
        else
            _MSG="${_UBC_NAME} for CT ${_CT_ID} increased with ${_UBC_FAIL} [HELD:${_UBC_HELD}/MAX_HELD:${_UBC_MAX_HELD}]"
            _STC=1
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_UBC_HELD}" "${_UBC_MAX_HELD}"
        fi
    done

    # add vzubc output to stdout log
    print "==== ${_VZUBC_BIN} ${_VZUBC_OPTS} ${_CT_ID} ====" >>${HC_STDOUT_LOG}
    print "${_UBC_OUTPUT}" >>${HC_STDOUT_LOG}
done

return ${_RC}
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with formatted stanzas:
               ct:<ct_id>
PURPOSE     : Checks whether UBC (User Bean Counters) for an OpenVZ containers have
              increased (failures)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
