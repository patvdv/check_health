#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_hplog.sh
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
# @(#) MAIN: check_linux_hplog
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-04-22: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: added dump_logs() & STDERR fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2018-11-18: do not trap on signal 0 [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_hplog
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _STATE_FILE="${STATE_PERM_DIR}/discovered.hplog"
typeset _VERSION="2019-01-24"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _STC_COUNT=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _TMP1_FILE="${TMP_DIR}/.$0.tmp1.$$"
typeset _TMP2_FILE="${TMP_DIR}/.$0.tmp2.$$"
typeset _HPLOG_BIN=""
typeset _HPLOG_SEVERITIES=""
typeset _SEVERITIES_LINE=""
typeset _SEVERITY_ENTRY=""
typeset _EVENT_ENTRY=""

# set local trap for cleanup
# shellcheck disable=SC2064
trap "[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1
      [[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1
      return 1" 1 2 3 15

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
_HPLOG_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'hplog_bin')
if [[ -z "${_HPLOG_BIN}" ]]
then
    warn "no value set for 'hplog_bin' in ${_CONFIG_FILE}"
    return 1
fi
_SEVERITIES_LINE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'hplog_severities')
if [[ -z "${_SEVERITIES_LINE}" ]]
then
    # set complex search regex (default)
    _HPLOG_SEVERITIES="^([0-9]+)\s*(CRITICAL|CAUTION)"
else
    # build the complex search regex
    _HPLOG_SEVERITIES="^"
    print "${_SEVERITIES_LINE}" | tr ',' '\n' 2>/dev/null | while read -r _SEVERITY_ENTRY
    do
        _HPLOG_SEVERITIES="${_HPLOG_SEVERITIES}(([0-9]+)\s*${_SEVERITY_ENTRY})|"
    done
    # delete last 'OR'
    _HPLOG_SEVERITIES=${_HPLOG_SEVERITIES%?}
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

# check hplog utility
if [[ ! -x ${_HPLOG_BIN} || -z "${_HPLOG_BIN}" ]]
then
    warn "${_HPLOG_BIN} is not installed here"
    return 1
fi

# get hplog output
${_HPLOG_BIN} -v >${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
(( $? > 0 )) && {
    _MSG="unable to run ${_HPLOG_BIN}"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
}

# check state file
[[ -r ${_STATE_FILE} ]] || {
    print "## this file sorted! Do not edit manually!" >${_STATE_FILE}
    (( $? > 0 )) && {
        warn "failed to create new state file"
        return 1
    }
    log "created new state file at ${_STATE_FILE}"
}

# filter current hplog messages (must be uniquely sorted for 'comm')
log "searching HPLOG with filter: ${_HPLOG_SEVERITIES}"
grep -i -E -e "${_HPLOG_SEVERITIES}" ${HC_STDOUT_LOG} >${_TMP1_FILE} 2>/dev/null

# compare results to already discovered messages
comm -13 ${_STATE_FILE} ${_TMP1_FILE} 2>/dev/null >${_TMP2_FILE}

# report results
while read -r _EVENT_ENTRY
do
    _MSG="${_EVENT_ENTRY}"
    _STC_COUNT=$(( _STC_COUNT + 1 ))
    log_hc "$0" 1 "${_MSG}"
done <${_TMP2_FILE}
if (( _STC_COUNT > 0 ))
then
    _MSG="found ${_STC_COUNT} new HPLOG messages {${_HPLOG_BIN} -v}"
    _STC=1
    # add results to state file (must be sorted; re-use TMP_FILE)
    sort -u ${_TMP1_FILE} ${_TMP2_FILE} >${_STATE_FILE} 2>/dev/null
    (( $? > 0 )) && {
        warn "failed to sort temporary state file"
        return 1
    }
else
    _MSG="no new HPLOG messages found"
fi
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

# do cleanup
[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1
[[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1

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
                hplog_bin=<location_of_hplog_tool>
                hplog_severities=<list_of_severities_to_search_for>
PURPOSE     : Checks for errors from the HP Proliant 'hpacucli' tool (see HP Proliant
              support pack (PSP))
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
