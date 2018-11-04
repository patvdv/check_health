#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_cdsf_cluster
#******************************************************************************
# @(#) Copyright (C) 2018 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_cdsf_cluster
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2016-07-21: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_cdsf_cluster
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2018-07-21"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
typeset _CDSF_BIN="/usr/sbin/io_cdsf_config"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _LOG_HEALTHY=0
typeset _CDSF_CONFLICTS=""
typeset _CDSF_DEV=""
typeset _CDSF_ENTRY=""

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

# check & get cDSF status
if [[ ! -x ${_CDSF_BIN} ]]
then
    warn "${_CDSF_BIN} is not installed here"
    return 1
else
    # io_cdsf_config outputs on STDERR (run status & check)
    # stable cluster: RC=0
    ${_CDSF_BIN} -s >${HC_STDOUT_LOG} 2>${HC_STDOUT_LOG}
    (( $? > 0 )) && {
        log_hc "$0" 1 "cDSF cluster has not yet been initialized or is not stable"
        return 0
    }
    # get device conflicts
    ${_CDSF_BIN} -c >>${HC_STDOUT_LOG} 2>>${HC_STDOUT_LOG}
fi

# do cDSF checks
_CDSF_CONFLICTS=$(grep 'uniq_name:' ${HC_STDOUT_LOG} 2>/dev/null | sort -u 2>/dev/null)
if [[ -n "${_CDSF_CONFLICTS}" ]]
then
    print "${_CDSF_CONFLICTS}" | while read -r _CDSF_ENTRY
    do
        _CDSF_DEV=$(print "${_CDSF_ENTRY}" | cut -f2 -d':' 2>/dev/null | cut -f4 -d'.' 2>/dev/null)
        log_hc "$0" 1 "cDSF conflict found for ${_CDSF_DEV}"
    done
else
    if (( _LOG_HEALTHY > 0 ))
    then
        log_hc "$0" 0 "no cDSF conflicts found"
    fi
fi

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3
PURPOSE     : Checks the health of the cDSF cluster (state/conflicts).
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
