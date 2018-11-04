#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_sg_package_config
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
# @(#) MAIN: check_linux_sg_package_config
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
function check_linux_sg_package_config
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
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
PATH=$PATH:/opt/cmcluster/bin
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _PKG_RUN_FILE="${TMP_DIR}/.$0.pkg_run.$$"
typeset _PKG_CFG_FILE="${TMP_DIR}/.$0.pkg_cfg.$$"
typeset _PKG_INSTANCE=""
typeset _PKG_INSTANCES=""
typeset _PKG_ENTRY=""
typeset _PKG_CFG_ENTRY=""
typeset _PKG_MATCH=""
typeset _PKG_PARAM=""
typeset _PKG_VALUE=""

# set local trap for cleanup
# shellcheck disable=SC2064
trap "rm -f ${_PKG_RUN_FILE}.* ${_PKG_CFG_FILE}.* >/dev/null 2>&1; return 0" 0
# shellcheck disable=SC2064
trap "rm -f ${_PKG_RUN_FILE}.* ${_PKG_CFG_FILE}.* >/dev/null 2>&1; return 1" 1 2 3 15

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
    esac
done

# handle config file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]]
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi

# look for package instance names
grep -E -e '^\[' ${_CONFIG_FILE} 2>/dev/null | cut -f1 -d']' 2>/dev/null | cut -f2 -d'[' 2>/dev/null |\
while read _PKG_INSTANCE
do
    _PKG_INSTANCES="${_PKG_INSTANCES} ${_PKG_INSTANCE}"
done
if [[ -z "${_PKG_INSTANCES}" ]]
then
    warn "no package information configured in ${_CONFIG_FILE}"
    return 1
fi

# check serviceguard status & gather package information from running cluster (compressed lines)
if [[ ! -x ${_SG_DAEMON} ]]
then
    warn "${_SG_DAEMON} is not installed here"
    return 1
else
    for _PKG_INSTANCE in ${_PKG_INSTANCES}
    do
    cmgetconf -p ${_PKG_INSTANCE} -v 0 2>>${HC_STDERR_LOG} |\
        grep -v -E -e "${_SG_CMGETCONF_FILTER}" | tr -d ' \t' >${_PKG_RUN_FILE}.${_PKG_INSTANCE}
    [[ -s ${_PKG_RUN_FILE}.${_PKG_INSTANCE} ]] || {
        _MSG="unable to gather package configuration for at least one cluster package"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 0
    }
    done
fi

# gather package information from healthcheck configuration
for _PKG_INSTANCE in ${_PKG_INSTANCES}
do
    awk -v package="${_PKG_INSTANCE}" '
    BEGIN { found = 0; needle = "^\["package"\]" }

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
    }' < ${_CONFIG_FILE} 2>>${HC_STDERR_LOG} >${_PKG_CFG_FILE}.${_PKG_INSTANCE}
done

# do package configuration checks (using the compressed strings)
for _PKG_INSTANCE in ${_PKG_INSTANCES}
do
    while read _PKG_ENTRY
    do
        # split entry to get the compressed version
        _PKG_CFG_ENTRY=$(print "${_PKG_ENTRY}" | cut -f2 -d'|' 2>/dev/null)
        # get parameter name from non-compressed version
        _PKG_PARAM=$(print "${_PKG_ENTRY}" | awk '{ print $1 }' 2>/dev/null)
        # get parameter value from non-compressed version
        _PKG_VALUE=$(print "${_PKG_ENTRY}" | cut -f1 -d'|' 2>/dev/null| awk '{ print substr($2,1,30)}' 2>/dev/null)
        # is it present?
        _PKG_MATCH=$(grep -c "${_PKG_CFG_ENTRY}" ${_PKG_RUN_FILE}.${_PKG_INSTANCE} 2>/dev/null)
        if (( _PKG_MATCH == 0 ))
        then
            # get parameter name from non-compressed version
            _MSG="'${_PKG_PARAM} (${_PKG_VALUE} ...)' is not correctly configured for ${_PKG_INSTANCE}"
            _STC=1
        else
            _MSG="'${_PKG_PARAM} (${_PKG_VALUE} ...)' is configured for ${_PKG_INSTANCE}"
        fi

        # handle unit result
        log_hc "$0" ${_STC} "${_MSG}"
        _STC=0
    done <${_PKG_CFG_FILE}.${_PKG_INSTANCE}
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
PURPOSE : Checks the configuration of Serviceguard package parameters (SG 11.16+)
          (comparing serialized strings from the HC configuration file to the
          running cluster configuration)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
