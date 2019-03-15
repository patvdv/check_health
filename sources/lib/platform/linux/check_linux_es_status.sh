#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_es_status.sh
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
# @(#) MAIN: check_linux_es_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: curl, data_comma2space(), dump_logs(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2019-03-09: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_es_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
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
typeset _CFG_ES_URL=""
typeset _API_URL=""
typeset _ES_STATUS=""
typeset _ES_URL=""

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
_CFG_ES_URL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'es_url')
if [[ -z "${_CFG_ES_URL}" ]]
then
    warn "no value for 'es_url' specified in ${_CONFIG_FILE}, using localhost default"
    _ES_URL="http://localhost:9200"
else
    _ES_URL="${_CFG_ES_URL}"
fi
_API_URL="${_ES_URL}/_cat/health?h=status"
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

# check curl
_CURL_BIN="$(which curl 2>>${HC_STDERR_LOG})"
if [[ ! -x ${_CURL_BIN} || -z "${_CURL_BIN}" ]]
then
    warn "curl is not installed here"
    return 1
fi

# get cluster check_linux_es_status
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && debug "curl command: ${_CURL_BIN} -XGET '${_API_URL}'"
_ES_STATUS=$(${_CURL_BIN} -XGET "${_API_URL}" 2>>${HC_STDERR_LOG})
if (( $? > 0 )) || [[ -z "${_ES_STATUS}" ]]
then
    _MSG="unable to run command {${_CURL_BIN} -XGET '${_API_URL}'}"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
fi

# parse status results
case "${_ES_STATUS}" in
    green)
        _MSG="state of ES instance at ${_ES_URL} is OK [${_ES_STATUS}]"
        _STC=0
        ;;
    yellow|red)
        _MSG="state of ES instance at ${_ES_URL} is NOK [${_ES_STATUS}]"
        _STC=1
        ;;
    *)
        _MSG="state of ES instance at ${_ES_URL} is NOK [unknown]"
        _STC=1
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}" "${_ES_STATUS}" "green"
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
               es_url=<url_of_es_api>
PURPOSE     : Checks the status of an Elastich search instance (green)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
