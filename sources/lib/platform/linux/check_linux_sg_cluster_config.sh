#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_sg_cluster_config
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
#*****************************************hpux*************************************
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
# @(#) 2018-05-21: added dump_logs() & other fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_sg_cluster_config
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _SG_DAEMON="/opt/cmcluster/bin/cmcld"
# rubbish that cmgetconf outputs to STDOUT instead of STDERR
typeset _SG_CMGETCONF_FILTER="Permission denied|Number of configured"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
PATH=$PATH:/opt/cmcluster/bin
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CLUSTER_RUN_FILE="${TMP_DIR}/.$0.cluster_run.$$"
typeset _CLUSTER_CFG_FILE="${TMP_DIR}/.$0.cluster_cfg.$$"
typeset _CLUSTER_INSTANCE=""
typeset _CLUSTER_INSTANCES=""
typeset _CLUSTER_ENTRY=""
typeset _CLUSTER_CFG_ENTRY=""
typeset _CLUSTER_MATCH=""
typeset _CLUSTER_PARAM=""
typeset _CLUSTER_VALUE=""

# set local trap for cleanup
# shellcheck disable=SC2064
trap "rm -f ${_CLUSTER_RUN_FILE}.* ${_CLUSTER_CFG_FILE}.* >/dev/null 2>&1; return 0" 0
# shellcheck disable=SC2064
trap "rm -f ${_CLUSTER_RUN_FILE}.* ${_CLUSTER_CFG_FILE}.* >/dev/null 2>&1; return 1" 1 2 3 15

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

# look for cluster instance names
grep -E -e '^\[' ${_CONFIG_FILE} 2>/dev/null | cut -f1 -d']' 2>/dev/null | cut -f2 -d'[' 2>/dev/null |\
while read _CLUSTER_INSTANCE
do
    _CLUSTER_INSTANCES="${_CLUSTER_INSTANCES} ${_CLUSTER_INSTANCE}"
done
if [[ -z "${_CLUSTER_INSTANCES}" ]]
then
    warn "no cluster information configured in ${_CONFIG_FILE}"
    return 1
fi

# check serviceguard status & gather cluster information from running cluster (compressed lines)
if [[ ! -x ${_SG_DAEMON} ]]
then
    warn "${_SG_DAEMON} is not installed here"
    return 1
else
    for _CLUSTER_INSTANCE in ${_CLUSTER_INSTANCES}
    do
    cmgetconf -c ${_CLUSTER_INSTANCE} 2>>${HC_STDERR_LOG} |\
        grep -v -E -e "${_SG_CMGETCONF_FILTER}" | tr -d ' \t' >${_CLUSTER_RUN_FILE}.${_CLUSTER_INSTANCE}
    [[ -s ${_CLUSTER_RUN_FILE}.${_CLUSTER_INSTANCE} ]] || {
        _MSG="unable to gather cluster configuration"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 0
    }
    done
fi

# gather cluster information from healthcheck configuration
for _CLUSTER_INSTANCE in ${_CLUSTER_INSTANCES}
do
    awk -v cluster="${_CLUSTER_INSTANCE}" '
    BEGIN { found = 0; needle = "^\["cluster"\]" }

    # skip blank lines
    /^\s*$/ { next; }
    # skip comment lines
    /^#/ { next; }

    # end marker
    ( $0 ~  /^\[.*\]/ && found ) {
        found = 0;
    }
    # start marker
    $0 ~ needle {
        found = 1;
    };
    # stanza body
    ( found && $0 !~ /^\[.*\]/ ) {
        # print non-compressed and compressed version
        printf "%s|", $0;
        gsub(" |\t", "", $0);
        printf "%s\n", $0;
    }' < ${_CONFIG_FILE} 2>>${HC_STDERR_LOG} >${_CLUSTER_CFG_FILE}.${_CLUSTER_INSTANCE}
done

# do cluster configuration checks (using the compressed strings)
for _CLUSTER_INSTANCE in ${_CLUSTER_INSTANCES}
do
    while read _CLUSTER_ENTRY
    do
        # split entry to get the compressed version
        _CLUSTER_CFG_ENTRY=$(print "${_CLUSTER_ENTRY}" | cut -f2 -d'|' 2>/dev/null)
        # get parameter name from non-compressed version
        _CLUSTER_PARAM=$(print "${_CLUSTER_ENTRY}" | cut -f1 -d'|' 2>/dev/null | awk '{ print $1 }' 2>/dev/null)
        # get parameter value from non-compressed version
        _CLUSTER_VALUE=$(print "${_CLUSTER_ENTRY}" | cut -f1 -d'|' 2>/dev/null | awk '{ print substr($2,1,30)}' 2>/dev/null)
        # is it present?
        _CLUSTER_MATCH=$(grep -c "${_CLUSTER_CFG_ENTRY}" ${_CLUSTER_RUN_FILE}.${_CLUSTER_INSTANCE} 2>/dev/null)
        if (( _CLUSTER_MATCH == 0 ))
        then
            # get parameter name from non-compressed version
            _MSG="'${_CLUSTER_PARAM} (${_CLUSTER_VALUE} ...)' is not correctly configured for ${_CLUSTER_INSTANCE}"
            _STC=1
        else
            _MSG="'${_CLUSTER_PARAM} (${_CLUSTER_VALUE} ...)' is configured for ${_CLUSTER_INSTANCE}"
        fi

        # handle unit result
        log_hc "$0" ${_STC} "${_MSG}"
        _STC=0
    done <${_CLUSTER_CFG_FILE}.${_CLUSTER_INSTANCE}
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
PURPOSE : Checks the configuration of a Serviceguard cluster (SG 11.16+) (comparing
          serialized strings from the plugin configuration file with the running
          cluster configuration)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
