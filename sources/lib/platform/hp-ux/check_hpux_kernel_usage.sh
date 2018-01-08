#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_kernel_usage.sh
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
# @(#) MAIN: check_hpux_kernel_usage
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2017-12-22: original version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_kernel_usage
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _KCUSAGE_BIN="/usr/sbin/kcusage"
typeset _VERSION="2018-01-05"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _MAX_KCUSAGE=0
typeset _EXCLUDED_PARAMS=""
typeset _HANDLED_PARAMS=""
typeset _PARAM_NAME=""
typeset _CONFIG_VALUE=""
typeset _CEIL_VALUE=""
typeset _CHECK_VALUE=""
typeset _CURR_VALUE=""
typeset _FOUND_PARAM=0
typeset _KCUSAGE_LINE=""
typeset _LINE_COUNT=1
typeset _DUMMY=""

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
_MAX_KCUSAGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'max_kcusage')
if [[ -z "${_MAX_KCUSAGE}" ]]
then
    # default
    _IGNORE_FS=90
fi
_EXCLUDED_PARAMS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'exclude_params')
if [[ -n "${_EXCLUDED_PARAMS}" ]]
then
    log "excluding following kernel parameters: ${_EXCLUDED_PARAMS}"
fi

# check & get kcusage information
if [[ ! -x ${_KCUSAGE_BIN} ]]
then
    warn "kcusage is not installed here (not HP-UX 11.31?)"
    return 1
else
    ${_KCUSAGE_BIN} >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    if (( $? != 0 ))
    then
        _MSG="unable to gather kcusage information"
        log_hc "$0" 1 "${_MSG}"
        return 0
    fi
fi

# check configuration values
grep -i '^param:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _DUMMY _PARAM_NAME _CONFIG_VALUE
do
    # check for empties
    if [[ -z "${_PARAM_NAME}" || -z "${_CONFIG_VALUE}" ]]
    then
        warn "missing parameter name and/or value in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
        return 1
    fi
    # check if the kernel parameter is valid
    _FOUND_PARAM=$(awk '{ print $1 }' ${HC_STDOUT_LOG} 2>/dev/null | grep -c -E -e "^${_PARAM_NAME}$")
    if (( _FOUND_PARAM == 0 ))
    then
        warn "parameter '${_PARAM_NAME}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT} is not an existing kernel parameter"
        return 1
    fi
    # check if the threshold value is correct (integer)
    case "${_CONFIG_VALUE}" in
        [0-9]*)
            # numeric, OK
            if (( _CONFIG_VALUE < 1 || _CONFIG_VALUE > 99 ))
            then
                warn "incorrect threshold value '${_CONFIG_VALUE}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
                return 1
            fi
            ;;
        *) 
            # not numeric
            warn "invalid threshold value '${_CONFIG_VALUE}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1 
            ;;
    esac
    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

# 1) perform checks (first the invidually configured ones)
grep -i '^param:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _DUMMY _PARAM_NAME _CONFIG_VALUE
do
    # check for actual values and ceilings
    _CURR_VALUE=$(grep -E -e "^${_PARAM_NAME}[ \t].*" ${HC_STDOUT_LOG} 2>/dev/null | awk '{ print $2 }')
    _CEIL_VALUE=$(grep -E -e "^${_PARAM_NAME}[ \t].*" ${HC_STDOUT_LOG} 2>/dev/null | awk '{ print $4 }')

    _CHECK_VALUE=$(( (_CURR_VALUE * 100 ) / _CEIL_VALUE ))

    if (( _CHECK_VALUE > _CONFIG_VALUE ))
    then
        _MSG="${_PARAM_NAME} has exceeded its individual threshold (${_CHECK_VALUE} > ${_CONFIG_VALUE})"
        _STC=1
    else
        _MSG="${_PARAM_NAME} is below its individual threshold (${_CHECK_VALUE} <= ${_CONFIG_VALUE})"
    fi
    # push to handled list
    _HANDLED_PARAMS="${_HANDLED_PARAMS}\n${_PARAM_NAME}"

    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}" "${_CHECK_VALUE}" "${_CONFIG_VALUE}"
    _STC=0
done

# perform checks (second the ones mapping the general threshold)
cat ${HC_STDOUT_LOG} 2>/dev/null | tail -n +3 | while read _KCUSAGE_LINE
do
    _PARAM_NAME=$(print "${_KCUSAGE_LINE}" | awk '{ print $1 }')

    # parameter excluded?
    if (( $(print "${_EXCLUDED_PARAMS}" | tr ',' '\n' | grep -c -E -e "${_PARAM_NAME}") != 0 ))
    then
        (( ARG_DEBUG != 0 )) && debug "excluding kernel parameter ${_PARAM_NAME} ..."
        continue
    fi

    # parameter already handled?
    if (( $(print "${_HANDLED_PARAMS}" | grep -c -E -e "${_PARAM_NAME}") == 0 ))
    then
        # check for actual values and ceilings
        _CURR_VALUE=$(print "${_KCUSAGE_LINE}" | awk '{ print $2 }')
        _CEIL_VALUE=$(print "${_KCUSAGE_LINE}" | awk '{ print $4 }')

        _CHECK_VALUE=$(( (_CURR_VALUE * 100 ) / _CEIL_VALUE ))

        if (( _CHECK_VALUE > _MAX_KCUSAGE ))
        then
            _MSG="${_PARAM_NAME} has exceeded the general threshold (${_CURR_VALUE} > ${_MAX_KCUSAGE})"
            _STC=1
        else
            _MSG="${_PARAM_NAME} is below the general threshold (${_CHECK_VALUE} <= ${_MAX_KCUSAGE})"
        fi
    
        # handle unit result
        log_hc "$0" ${_STC} "${_MSG}" "${_CHECK_VALUE}" "${_MAX_KCUSAGE}"
        _STC=0
    fi
done

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with formatted stanzas:
            param:<my_param1>:<my_param1_threshold_%>
          Other options:
            max_kcusage=<threshold_%>
            exclude_params=<list_of_exluded_parameters>
PURPOSE : Checks the current usage of kernel paremeter resources

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
