#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_kernel_params.sh
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
# @(#) MAIN: check_hpux_kernel_params
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2017-12-22: original version [Patrick Van der Veken]
# @(#) 2018-01-05: added validation on config values [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_kernel_params
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _KCTUNE_BIN="/usr/sbin/kctune"
typeset _VERSION="2017-12-22"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _PARAM_NAME=""
typeset _CONFIG_VALUE=""
typeset _CURR_VALUE=""
typeset _EXPR_VALUE=""
typeset _REPORTED_VALUE=""
typeset _DUMMY=""
typeset _FOUND_PARAM=0
typeset _LINE_COUNT=1

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

# collect data (mount only)
${_KCTUNE_BIN} >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
if (( $? != 0 ))
then
    _MSG="unable to gather kctune information (not HP-UX 11.31?)"
    log_hc "$0" 1 "${_MSG}"
    return 0
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
    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

# perform checks
grep -i '^param:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _DUMMY _PARAM_NAME _CONFIG_VALUE
do
    # check for actual values and expression values
    _CURR_VALUE=$(grep -E -e "^${_PARAM_NAME}[ \t].*" ${HC_STDOUT_LOG} 2>/dev/null | awk '{ print $2 }')
    _EXPR_VALUE=$(grep -E -e "^${_PARAM_NAME}[ \t].*" ${HC_STDOUT_LOG} 2>/dev/null | awk '{ print $3 }')

    if [[ "${_EXPR_VALUE}" = @(Default|default) ]]
    then
        if [[ "${_CONFIG_VALUE}" = "${_CURR_VALUE}" ]]
        then
            _MSG="${_PARAM_NAME} is set with the right value (${_CURR_VALUE})"
        else
            _MSG="${_PARAM_NAME} has a wrong value (${_CONFIG_VALUE} != ${_CURR_VALUE})"
            _STC=1
        fi
        _REPORTED_VALUE="${_CURR_VALUE}"
    else
        if [[ "${_CONFIG_VALUE}" = "${_EXPR_VALUE}" ]]
        then
            _MSG="${_PARAM_NAME} is set with the right expression (${_EXPR_VALUE})"
        else
            _MSG="${_PARAM_NAME} has a wrong expression (${_CONFIG_VALUE} != ${_EXPR_VALUE})"
            _STC=1
        fi
        _REPORTED_VALUE="${_EXPR_VALUE}"
    fi

    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}" "${_REPORTED_VALUE}" "${_CONFIG_VALUE}"
    _STC=0
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
            param:<my_param1>:<my_param1_value>
PURPOSE : Checks kernel parameters have a correct run-time value/expression

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
