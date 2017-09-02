#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_ovpa_status
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
# @(#) MAIN: check_hpux_ovpa_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2016-04-08: initial version [Patrick Van der Veken]
# @(#) 2016-12-01: more standardized error handling  [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_ovpa_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2016-12-01"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
typeset _OVPA_BIN="/opt/perf/bin/perfstat"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _OVPA_MATCH=0
typeset _OVPA_VERSION=""
typeset _OVPA_DAEMONS=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;  
    esac
done

# check & get ovpa status
if [[ ! -x ${_OVPA_BIN} ]] 
then
    warn "${_OVPA_BIN} is not installed here"
    return 1
else
    ${_OVPA_BIN} -p >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    # no RC check here because perfstat will throw <>0 when procs are down
fi

# get ovpa version (<12.x: scopeux; >=12.x: oacore, no coda)
_OVPA_VERSION="$(${_OVPA_BIN} -v 2>>${HC_STDERR_LOG} | grep "HP Performance Agent" | awk '{ print $NF }')"
case "${_OVPA_VERSION}" in
    12.*)
        log "running HP Operations Agent v12 ..."
        _OVPA_DAEMONS="oacore midaemon perfalarm ttd ovcd ovbbccb"
        ;;
    *)
        log "running HP Operations Agent v11 or lower ..."
        _OVPA_DAEMONS="scopeux midaemon perfalarm ttd ovcd ovbbccb coda"
        ;;
esac

# do OVPA status checks
for _OVPA_DAEMON in ${_OVPA_DAEMONS}
do
    # anchored grep here!
    _OVPA_MATCH=$(grep -c -E -e "[ \t]*Running[ \t]*${_OVPA_DAEMON}" 2>/dev/null ${HC_STDOUT_LOG})
    case ${_OVPA_MATCH} in
        0)
            _MSG="${_OVPA_DAEMON} is not running"
            _STC=1
            ;;  
        *)
            _MSG="${_OVPA_DAEMON} is running"
            ;;
    esac
    
    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}"
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
CONFIG  : $3
PURPOSE : Checks the status of OVPA processes (OpenView Performance Agent)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
