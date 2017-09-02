#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_syslog.sh
#******************************************************************************
# @(#) Copyright (C) 2016 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_syslog
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2016-06-20: initial version [Patrick Van der Veken]
# @(#) 2017-05-18: do not update the state file with --no-log [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_syslog
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _STATE_FILE="${STATE_PERM_DIR}/discovered.syslog"
typeset _VERSION="2017-05-18"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _STC_COUNT=0
typeset _TMP_FILE="${TMP_DIR}/.$0.tmp.$$"
typeset _CLASSES_LINE=""
typeset _SYSLOG_FILE=""
typeset _SYSLOG_CLASSES=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;  
    esac
done

# set local trap for cleanup
trap "[[ -f ${_TMP_FILE} ]] && rm -f ${_TMP_FILE} >/dev/null 2>&1; return 1" 1 2 3 15

# handle configuration file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]] 
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
# read required configuration values
_SYSLOG_FILE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'syslog_file')
if [[ -z "${_SYSLOG_FILE}" ]]
then
    # default
    _SYSLOG_FILE="/var/adm/syslog/syslog.log"
fi
_CLASSES_LINE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'syslog_classes')
if [[ -z "${_CLASSES_LINE}" ]]
then
    # default (mind the complex regex!, support facility[PID])
    _SYSLOG_CLASSES="vmunix(\[[0-9]+\])?:"
else
    # convert comma's (mind the complex regex!, support facility[PID])
    _SYSLOG_CLASSES=$(print "${_CLASSES_LINE}" | sed 's/,/(\\[[0-9]+\\])\?:\|/g')
    # add PID qualifier to last item
    _SYSLOG_CLASSES="${_SYSLOG_CLASSES}(\[[0-9]+\])?:"
fi

# check SYSLOG file
[[ -r ${_SYSLOG_FILE} ]] || _MSG="SYSLOG file ${_SYSLOG_FILE} cannot be found"
if [[ -n "${_MSG}" ]]
then
    # handle results
    log_hc "$0" 1 "${_MSG}"
    return 0
fi

# check state file
[[ -r ${_STATE_FILE} ]] || {
    print "## this file is not date sorted! Do not edit manually!" >${_STATE_FILE}
    (( $? > 0 )) && {
        warn "failed to create new state file at ${_STATE_FILE}"
        return 1       
    }
    log "created new state file at ${_STATE_FILE}"
}

# filter current SYSLOG messages (must be uniquely sorted for 'comm')
log "searching SYSLOG with filter: ${_SYSLOG_CLASSES}"
grep -E -e "${_SYSLOG_CLASSES}" ${_SYSLOG_FILE} | sort -u >${_TMP_FILE} 2>/dev/null

# compare results to already discovered messages
comm -13 ${_STATE_FILE} ${_TMP_FILE} 2>/dev/null | sed 's/^ //g' >${HC_STDOUT_LOG}

# report results
_STC_COUNT=$(wc -l ${HC_STDOUT_LOG} 2>/dev/null | cut -f1 -d' ')
if (( _STC_COUNT > 0 ))
then
    _MSG="found ${_STC_COUNT} new SYSLOG messages"
    _STC=1
    # add results to state file (must be sorted; re-use TMP_FILE)
    sort -u ${HC_STDOUT_LOG} ${_STATE_FILE} >${_TMP_FILE}
    (( $? > 0 )) && {
        warn "failed to sort temporary state file"
        return 1       
    }
    if (( ARG_LOG != 0 ))
    then
        mv ${_TMP_FILE} ${_STATE_FILE} >/dev/null 2>&1
        (( $? > 0 )) && {
            warn "failed to move temporary state file"
            return 1       
        }
    fi
else
    _MSG="no new SYSLOG messages found"
fi
  
# handle results
log_hc "$0" ${_STC} "${_MSG}"

# clean up temporary files
[[ -f ${_TMP_FILE} ]] && rm -f ${_TMP_FILE} >/dev/null 2>&1

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with:
            syslog_file=<path_to_syslog_file>
            syslog_classes=<list_of_facility_classes_to_search_for>
PURPOSE : Provides a KISS syslog monitor (keep tracks of already discovered messages in
          a state file and compares new lines in SYSLOG to the ones kept in the
          state file. The plugin will sort both state & SYSLOG data before doing
          the comparison.

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
