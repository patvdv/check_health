#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_hpvm_vpar_status.sh
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
# @(#) MAIN: check_hpux_hpvm_vpar_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-06-01: initial version [Patrick Van der Veken]
# @(#) 2017-06-08: return 1 on error [Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_hpvm_vpar_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _HPVMSTATUS_BIN="/opt/hpvm/bin/hpvmstatus"
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _LINE_COUNT=1
typeset _PAR_ENTRY=""
typeset _PAR_ID=""
typeset _PAR_CFG_STATUS=""
typeset _PAR_RUN_STATUS=""
typeset _PAR_CFG_BOOT=""
typeset _PAR_RUN_BOOT=""
typeset _PAR_ENTRY=""
typeset _PAR_MATCH=""
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

# check HPVM
if [[ ! -x ${_HPVMSTATUS_BIN} || -z "${_HPVMSTATUS_BIN}" ]]
then
    warn "HPVM is not installed here"
    return 1
fi

${_HPVMSTATUS_BIN} -M >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
(( $? != 0 )) && {
    _MSG="unable to run command: {${_HPVMSTATUS_BIN}}"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 0
}

# check configuration values
grep -v -E -e '^$' -e '^#' ${_CONFIG_FILE} 2>/dev/null | while read _PAR_ENTRY
do
    # field split
    _PAR_ID=$(print "${_PAR_ENTRY}" | cut -f1 -d';')
    _PAR_CFG_STATUS=$(data_lc "$(print \"${_PAR_ENTRY}\" | cut -f2 -d';')")
    _PAR_CFG_BOOT=$(data_lc "$(print \"${_PAR_ENTRY}\" | cut -f3 -d';')")

    # check configuration
    case "${_PAR_ID}" in
        +([0-9])*(.)*([0-9]))
            # numeric, OK
            ;;
        *)
            # not numeric
            warn "invalid partition ID '${_PAR_ID}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
            ;;
    esac
    case "${_PAR_CFG_STATUS}" in
        on|off)
            ;;
        *)
            warn "invalid partition status '${_PAR_CFG_STATUS}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
            ;;
    esac
    case "${_PAR_CFG_BOOT}" in
        auto|manual)
            ;;
        *)
            warn "invalid partition boot value '${_PAR_CFG_BOOT}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            return 1
            ;;
    esac
    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

# perform checks
grep -v -E -e '^$' -e '^#' ${_CONFIG_FILE} 2>/dev/null | while read _PAR_ENTRY
do
    # field split
    _PAR_ID=$(print "${_PAR_ENTRY}" | cut -f1 -d';')
    _PAR_CFG_STATUS=$(data_lc "$(print \"${_PAR_ENTRY}\" | cut -f2 -d';')")
    _PAR_CFG_BOOT=$(data_lc "$(print \"${_PAR_ENTRY}\" | cut -f3 -d';')")

    # check run-time values (we need to make the needle sufficiently less greedy)
    _PAR_MATCH=$(grep -i "^.*:.*:${_PAR_ID}::Integrity" ${HC_STDOUT_LOG} 2>/dev/null)
    if [[ -n "${_PAR_MATCH}" ]]
    then
        # field split
        _PAR_RUN_STATUS=$(data_lc "$(print \"${_PAR_MATCH}\" | cut -f11 -d':')")
        _PAR_RUN_BOOT=$(data_lc "$(print \"${_PAR_MATCH}\" | cut -f12 -d':')")

        if [[ "${_PAR_RUN_STATUS}" = "${_PAR_CFG_STATUS}" ]]
        then
            _MSG="partition ${_PAR_ID} has a correct status [${_PAR_RUN_STATUS}]"
            _STC=0
        else
             _MSG="partition ${_PAR_ID} has a wrong status [${_PAR_RUN_STATUS}]"
             _STC=1
        fi
        log_hc "$0" ${_STC} "${_MSG}" "${_PAR_RUN_STATUS}" "${_PAR_CFG_STATUS}"

        if [[ "${_PAR_RUN_BOOT}" = "${_PAR_CFG_BOOT}" ]]
        then
            _MSG="partition ${_PAR_ID} has a correct boot flag [${_PAR_RUN_BOOT}]"
            _STC=0
        else
             _MSG="partition ${_PAR_ID} has a wrong boot flag [${_PAR_RUN_BOOT}]"
             _STC=1
        fi
        log_hc "$0" ${_STC} "${_MSG}" "${_PAR_RUN_BOOT}" "${_PAR_CFG_BOOT}"
    else
        warn "could not determine status for partition ${_PAR_ID} from command output {${_HPVMSTATUS_BIN}}"
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
            <parid>;<runtime_status>;<boot_status>
PURPOSE : Checks the status of vPars (on a VSP)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
