#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_ioscan.sh
#******************************************************************************
# @(#) Copyright (C) 2014 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_ioscan
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_comma2pipe(), data_dequote(), dump_logs(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2013-08-28: initial version [Patrick Van der Veken]
# @(#) 2013-08-29: more verbosity & kernel_mode setting [Patrick Van der Veken]
# @(#) 2016-06-08: introduced _AGILE_VIEW parameter [Patrick Van der Veken]
# @(#) 2016-12-01: more standardized error handling [Patrick Van der Veken]
# @(#) 2018-05-11: small optimizations [Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# @(#) 2021-04-07: quotes & shellcheck fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_ioscan
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _IOSCAN_BIN="/usr/sbin/ioscan"
typeset _IOSCAN_OPTS="-Fn"
typeset _VERSION="2021-04-07"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "${0}" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _STC_COUNT=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CLASS_LINE=""
typeset _IOSCAN_CLASSES=""
typeset _AGILE_VIEW=""
typeset _KERNEL_MODE=""
typeset _IOSCAN_LINE=""
typeset _HW_CLASS=""
typeset _HW_PATH=""
typeset _HW_STATE=""

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
_CLASS_LINE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'ioscan_classes')
if [[ -z "${_CLASS_LINE}" ]]
then
    # default
    _IOSCAN_CLASSES="ctl|diag|disk|ext_bus|fc|fcp|i2o|ipmi|lan|lvm|olar|vm"
else
    # convert commas and strip quotes
    _IOSCAN_CLASSES=$(data_comma2pipe "$(data_dequote \"${_CLASS_LINE}\")")
fi
_KERNEL_MODE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'kernel_mode')
if [[ -z "${_KERNEL_MODE}" ]]
then
    # default
    _KERNEL_MODE="yes"
fi
_AGILE_VIEW=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'agile_view')
if [[ -z "${_AGILE_VIEW}" ]]
then
    # default
    _AGILE_VIEW="yes"
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

# check and get ioscan stuff
if [[ ! -x ${_IOSCAN_BIN} ]]
then
    warn "${_IOSCAN_BIN} is not installed here"
    return 1
else
    log "collecting ioscan information, this is may take a while ..."
    if [[ "${_KERNEL_MODE}" = "yes" ]] && [[ "${_AGILE_VIEW}" = "yes" ]]
    then
        _IOSCAN_OPTS="${_IOSCAN_OPTS}Nk"
    fi
    if [[ "${_KERNEL_MODE}" = "yes" ]] && [[ "${_AGILE_VIEW}" = "no" ]]
    then
        _IOSCAN_OPTS="${_IOSCAN_OPTS}k"
    fi
    if [[ "${_KERNEL_MODE}" = "no" ]] && [[ "${_AGILE_VIEW}" = "yes" ]]
    then
        _IOSCAN_OPTS="${_IOSCAN_OPTS}Nu"
    fi
    if [[ "${_KERNEL_MODE}" = "no" ]] && [[ "${_AGILE_VIEW}" = "no" ]]
    then
        _IOSCAN_OPTS="${_IOSCAN_OPTS}u"
    fi
    log "executing ioscan with options: ${_IOSCAN_OPTS}"
    ${_IOSCAN_BIN} ${_IOSCAN_OPTS} >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        _MSG="unable to run command: {${_IOSCAN_BIN}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi
fi

# check for requested device classes
grep -E -e ".*:.*:.*:.*:.*:.*:.*:.*:${_IOSCAN_CLASSES}:.*" "${HC_STDOUT_LOG}" 2>/dev/null |\
    while read -r _IOSCAN_LINE
do
    # possible states are: CLAIMED, UNCLAIMED, DIFF_HW, NO_HW, ERROR, SCAN
    _HW_CLASS=$(print "${_IOSCAN_LINE}" | cut -f9 -d':')
    _HW_PATH=$(print "${_IOSCAN_LINE}" | cut -f11 -d':')
    _HW_STATE=$(print "${_IOSCAN_LINE}" | cut -f16 -d':')

    case "${_HW_STATE}" in
        NO_HW)
            _MSG="detected NO_HW for device on path '${_HW_PATH}', class '${_HW_CLASS}'"
            _STC=1
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            ;;
        ERROR)
            _MSG="detected ERROR for device on HW path '${_HW_PATH}', class '${_HW_CLASS}'"
            _STC=1
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            ;;
        *)
            # everything else is considered non-fatal (do not report)
            continue
    esac

    # report result
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    _STC=0
done

# report OK situation
if (( _LOG_HEALTHY > 0 && _STC_COUNT == 0 ))
then
    _MSG="no problems detected by {${_IOSCAN_BIN}}"
    log_hc "$0" 0 "${_MSG}"
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
                ioscan_classes=<list_of_device_classes_to_check>
                kernel_mode=<yes|no>
                agile_view=<yes|no>
PURPOSE     : Checks whether 'ioscan' returns errors or not (NO_HW, ERROR)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
