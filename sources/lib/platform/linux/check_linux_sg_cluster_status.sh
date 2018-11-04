#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_sg_cluster_status
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
# @(#) MAIN: check_linux_sg_cluster_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-04-01: initial version [Patrick Van der Veken]
# @(#) 2017-05-07: made checks more detailed for log_hc() [Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_sg_cluster_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _SG_DAEMON="/opt/cmcluster/bin/cmcld"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
PATH=$PATH:/opt/cmcluster/bin
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _SG_ENTRY=""
typeset _SG_MATCH=""
typeset _SG_CFG_PARAM=""
typeset _SG_CFG_VALUE=""
typeset _SG_RUN_VALUE=""

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

# check & get serviceguard status
if [[ ! -x ${_SG_DAEMON} ]]
then
    warn "${_SG_DAEMON} is not installed here"
    return 1
else
    cmviewcl -v -f line 2>>${HC_STDERR_LOG} | tr '|' ':' >>${HC_STDOUT_LOG} 2>/dev/null
    (( $? > 0 )) && {
        _MSG="unable to run command: {cmviewcl}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 0
    }
fi

# do cluster status checks
# (replace ':' by '|' for cmcviewcl output)
grep -v -E -e '^$' -e '^#' ${_CONFIG_FILE} 2>/dev/null | tr '|' ':' 2>/dev/null |\
    while read _SG_ENTRY
do
    # field split
    _SG_CFG_PARAM="$(print ${_SG_ENTRY} | cut -f1 -d'=' 2>/dev/null)"   # field 1
    _SG_CFG_VALUE="$(print ${_SG_ENTRY} | cut -f2 -d'=' 2>/dev/null)"   # field 2

    # check run-time values (anchored grep here!)
    _SG_MATCH=$(grep -i "^${_SG_CFG_PARAM}" ${HC_STDOUT_LOG} 2>/dev/null)
    if [[ -n "${_SG_MATCH}" ]]
    then
        _SG_RUN_VALUE=$(print "${_SG_MATCH}" | cut -f2 -d'=' 2>/dev/null)   # field 2

        if [[ "${_SG_CFG_VALUE}" = "${_SG_RUN_VALUE}" ]]
        then
            _MSG="cluster parameter ${_SG_CFG_PARAM} has a correct value [${_SG_RUN_VALUE}]"
            _STC=0
        else
            _MSG="cluster parameter ${_SG_CFG_PARAM} has a wrong value [${_SG_RUN_VALUE}]"
            _STC=1
        fi
        log_hc "$0" ${_STC} "${_MSG}" "${_SG_RUN_VALUE}" "${_SG_CFG_VALUE}"
    else
        warn "could not determine status for ${_SG_CFG_PARAM} from command output {cmviewcl}"
    fi
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
PURPOSE : Checks the status of Serviceguard cluster parameters (SG 11.16+)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
