#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_vz_ct_status.sh
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
# @(#) MAIN: check_linux_vz_ct_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-04-01: initial version [Patrick Van der Veken]
# @(#) 2017-05-07: made checks more detailed for hc_log() [Patrick Van der Veken]
# @(#) 2017-06-08: return 1 on error [Patrick Van der Veken]
# @(#) 2018-04-30: fixes on variable names Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_vz_ct_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VZLIST_BIN="/usr/sbin/vzlist"
typeset _VERSION="2018-04-30"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _LINE_COUNT=1
typeset _CT_ENTRY=""
typeset _CT_ID=""
typeset _CT_CFG_STATUS=""
typeset _CT_RUN_STATUS=""
typeset _CT_CFG_BOOT=""
typeset _CT_RUN_BOOT=""
typeset _CT_ENTRY=""
typeset _CT_MATCH=""
typeset _MSG=""
typeset _STC=0
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

# check openvz
if [[ ! -x ${_VZLIST_BIN} || -z "${_VZLIST_BIN}" ]]
then
    warn "OpenVZ is not installed here"
    return 1
fi

# get container stati
${_VZLIST_BIN} -a -H -o ctid,status,onboot >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
(( $? != 0 )) && {
    _MSG="unable to run {vzlist}"
    log_hc "$0" 1 "${_MSG}"
    return 0
}

# check configuration values
grep -v -E -e '^$' -e '^#' ${_CONFIG_FILE} 2>/dev/null | while read _CT_ENTRY
do
    # field split
    _CT_ID="$(print ${_CT_ENTRY} | cut -f1 -d';')"
    _CT_CFG_STATUS=$(data_lc $(print "${_CT_ENTRY}" | cut -f2 -d';'))
    _CT_CFG_BOOT=$(data_lc $(print "${_CT_ENTRY}" | cut -f3 -d';'))
    
    # check config
    case "${_CT_ID}" in
        +([0-9])*(.)*([0-9]))
            # numeric, OK
            ;;
        *) 
            # not numeric
            warn "invalid container ID '${_CT_ID}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
            ;;
    esac
    case "${_CT_CFG_STATUS}" in
        running|stopped)
            ;;
        *) 
            warn "invalid container status '${_CT_CFG_STATUS}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1 
            ;;
    esac   
    case "${_CT_CFG_BOOT}" in
        yes|no)
            ;;
        *) 
            warn "invalid container boot value '${_CT_CFG_BOOT}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1 
            ;;
    esac
    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

    
# perform checks
grep -v -E -e '^$' -e '^#' ${_CONFIG_FILE} 2>/dev/null | while read _CT_ENTRY
do
    # field split
    _CT_ID="$(print ${_CT_ENTRY} | cut -f1 -d';')"
    _CT_CFG_STATUS="$(print ${_CT_ENTRY} | cut -f2 -d';')"
    _CT_CFG_BOOT="$(print ${_CT_ENTRY} | cut -f3 -d';')"
    
    # check run-time values
    _CT_MATCH=$(grep -i "^[[:space:]]*${_CT_ID}" ${HC_STDOUT_LOG} 2>/dev/null)
    if [[ -n "${_CT_MATCH}" ]]
    then
        # field split
        _CT_RUN_STATUS=$(data_lc $(print "${_CT_MATCH}" | tr -s ' ' ';' | cut -f3 -d';'))
        _CT_RUN_BOOT=$(data_lc $(print "${_CT_MATCH}" | tr -s ' ' ';' | cut -f4 -d';'))
        
        if [[ "${_CT_RUN_STATUS}" = "${_CT_CFG_STATUS}" ]]
        then
            _MSG="container ${_CT_ID} has a correct status [${_CT_RUN_STATUS}]"
            _STC=0
        else
             _MSG="container ${_CT_ID} has a wrong status [${_CT_RUN_STATUS}]"     
             _STC=1        
        fi
        log_hc "$0" ${_STC} "${_MSG}" "${_CT_RUN_STATUS}" "${_CT_CFG_STATUS}"           
        
        if [[ "${_CT_RUN_BOOT}" = "${_CT_CFG_BOOT}" ]]
        then
            _MSG="container ${_CT_ID} has a correct boot flag [${_CT_RUN_BOOT}]"
            _STC=0
        else
             _MSG="container ${_CT_ID} has a wrong boot flag [${_CT_RUN_BOOT}]"      
             _STC=1        
        fi
        log_hc "$0" ${_STC} "${_MSG}" "${_CT_RUN_BOOT}" "${_CT_CFG_BOOT}"         
    else
        warn "could not determine status for container ${_CT_ID} from command output {${_VZLIST_BIN}}"
        _RC=1
    fi
done

return ${_RC}
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with:
            <ctid>;<runtime_status>;<boot_status>
PURPOSE : Checks whether OpenVZ containers are running or not

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
