#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_autopath.sh
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
# @(#) MAIN: check_hpux_autopath
# DOES: see _show_usage().
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2013-08-29: initial version [Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_autopath
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _AUTOPATH_BIN="/sbin/autopath"
typeset _AUTOPATH_NEEDLE="Failed"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _STC_COUNT=0
typeset _LOG_HEALTHY=0
typeset _AUTOPATH_LINE=""
typeset _DEVICE=""

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

# check autopath presence
if [[ ! -x ${_AUTOPATH_BIN} ]]
then
    warn "${_AUTOPATH_BIN}  is not installed here"
    return 1
fi

# collect autopath info
log "collecting autopath information, this may take a while ..."
${_AUTOPATH_BIN} display >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
(( $? > 0 )) && {
    _MSG="unable to run {${_AUTOPATH_BIN}}"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 0
}

# check for device failures
grep -E -e "${_AUTOPATH_NEEDLE}" ${HC_STDOUT_LOG} 2>/dev/null |\
    while read _AUTOPATH_LINE
do
    _DEVICE="$(print ${_AUTOPATH_LINE} | cut -f1 -d' ')"
    _MSG="failed path for device '${_DEVICE}'"
    _STC=1
    _STC_COUNT=$(( _STC_COUNT + 1 ))

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
    _MSG="no failed paths detected by {${_AUTOPATH_BIN}}"
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
PURPOSE     : Checks whether failed paths exist for StorageWorks disk arrays
              using the 'autopath' utility.
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
