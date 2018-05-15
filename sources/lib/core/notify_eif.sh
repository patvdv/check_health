#!/usr/bin/env ksh
#******************************************************************************
# @(#) notify_eif.sh
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
# @(#) MAIN: notify_eif
# DOES: send alert via posteifmsg
# EXPECTS: HC name [string]
# RETURNS: 0
# REQUIRES: data_get_lvalue_from_config(), handle_timeout(), init_hc(), log()
#           warn()
# INFO: https://www-01.ibm.com/support/knowledgecenter/SSSHTQ_8.1.0/com.ibm.netcool_OMNIbus.doc_8.1.0/omnibus/wip/eifsdk/reference/omn_eif_posteifmsg.html
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function notify_eif
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/core/providers/$0.conf"
typeset _VERSION="2018-05-12"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _EIF_MESSAGE="$1 alert with ID ${HC_FAIL_ID}"
typeset _EIF_CLASS="${SCRIPT_NAME}"
typeset _EIF_BIN=""
typeset _EIF_ETC=""
typeset _EIF_SEVERITY=""
typeset _TIME_OUT=10
typeset _CHILD_ERROR=0
typeset _OWNER_PID=0
typeset _SLEEP_PID=0
typeset _CHILD_RC=0

# handle config file
if [[ ! -r ${_CONFIG_FILE} ]] 
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
# read required config values
_EIF_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config '_EIF_BIN')
if [[ -z "${_EIF_BIN}" ]]
then
    warn "no value set for 'EIF_BIN' in ${_CONFIG_FILE}"
    return 1
fi
_EIF_ETC=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config '_EIF_ETC')
if [[ -z "${_EIF_ETC}" ]]
then
    warn "no value set for 'EIF_ETC' in ${_CONFIG_FILE}"
    return 1
fi
_EIF_SEVERITY=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config '_EIF_SEVERITY')
if [[ -z "${_EIF_SEVERITY}" ]]
then
    warn "no value set for 'EIF_SEVERITY' in ${_CONFIG_FILE}"
    return 1
fi

# send EIF
if [[ -x ${EIF_BIN} ]]
then
    # set trap on SIGUSR1
    trap "handle_timeout" USR1

    # $PID is PID of the owner shell
    _OWNER_PID=$$
    (
        # sleep for $_TIME_OUT seconds. If the sleep sub-shell is then still alive, send a SIGUSR1 to the owner
        sleep ${_TIME_OUT}
        kill -s USR1 ${_OWNER_PID} >/dev/null 2>&1
    ) &
    # $_SLEEP_PID is the PID of the sleep subshell itself
    _SLEEP_PID=$!

    # do POSTEIFMSG in the background
    ${EIF_BIN} -f ${EIF_ETC} -r ${EIF_SEVERITY} -m "${_EIF_MESSAGE}" \
        hostname=${HOST_NAME} sub_origin=part1 ${_EIF_CLASS} POST &
    CHILD_PID=$!
    log "spawning child process with time-out of ${_TIME_OUT} secs for EIF notify [PID=${CHILD_PID}]"
    # wait for the command to complete
    wait ${CHILD_PID}
    # when the child completes, we can get rid of the sleep trigger
    _CHILD_RC=$?
    kill -s TERM ${_SLEEP_PID} >/dev/null 2>&1
    # process return codes
    if (( _CHILD_RC != 0 ))
    then
        warn "problem in sending alert via EIF [RC=${_CHILD_RC}]"
    else
        if (( _CHILD_ERROR == 0 ))
        then
            log "child process with PID ${CHILD_PID} ended correctly"
        else
            log "child process with PID ${CHILD_PID} did end correctly"
        fi
    fi
else
    warn "could not sent alert via EIF (posteifmsg tool not found)"
fi

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
