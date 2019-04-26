#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_clusterware_resource_config
#******************************************************************************
# @(#) Copyright (C) 2019 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_clusterware_resource_config
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-04-20: merged HP-UX+Linux version + fixes [Patrick Van der Veken]
# @(#) 2019-04-26: made _CRSCTL_BIN path configurable + fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_clusterware_resource_config
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-04-26"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _MAX_LENGTH_VALUE_STRING=30
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CRSCTL_BIN=""
typeset _RES_RUN_FILE="${TMP_DIR}/.$0.res_run.$$"
typeset _RES_CFG_FILE="${TMP_DIR}/.$0.res_cfg.$$"
typeset _RES_INSTANCE=""
typeset _RES_INSTANCES=""
typeset _RES_CFG_ENTRY=""
typeset _RES_ENTRY=""
typeset _RES_MATCH=""
typeset _RES_PARAM=""
typeset _RES_VALUE=""

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
# shellcheck disable=SC2064
trap "rm -f ${_RES_RUN_FILE}.* ${_RES_CFG_FILE}.* >/dev/null 2>&1; return 1" 1 2 3 15

# handle configuration file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]]
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
_CFG_HEALTHY=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'log_healthy')
case "${_CFG_HEALTHY}" in
    yes|YES|Yes)
        _LOG_HEALTHY=1
        ;;
    *)
        # do not override hc_arg
        (( _LOG_HEALTHY > 0 )) || _LOG_HEALTHY=0
        ;;
esac
_CRSCTL_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'crsctl_bin')
if [[ -z "${_CRSCTL_BIN}" ]]
then
    _CRSCTL_BIN="$(command -v crsctl 2>>${HC_STDERR_LOG})"
    [[ -n "${_CRSCTL_BIN}" ]] && (( ARG_DEBUG > 0 )) && debug "crsctl path: ${_CRSCTL_BIN} (discover)"
else
    (( ARG_DEBUG > 0 )) && debug "crsctl path: ${_CRSCTL_BIN} (config)"
fi
if [[ -z "${_CRSCTL_BIN}" || ! -x ${_CRSCTL_BIN} ]]
then
    warn "could not determine location for CRS {crsctl} (or it is not installed here)"
    return 1
fi

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

# look for resource instance names
grep -E -e '^\[' ${_CONFIG_FILE} 2>/dev/null | cut -f1 -d']' 2>/dev/null | cut -f2 -d'[' 2>/dev/null |\
while read _RES_INSTANCE
do
    _RES_INSTANCES="${_RES_INSTANCES} ${_RES_INSTANCE}"
done
if [[ -z "${_RES_INSTANCES}" ]]
then
    warn "no resource information configured in ${_CONFIG_FILE}"
    return 1
fi

# get resource information from crsctl
for _RES_INSTANCE in ${_RES_INSTANCES}
do
${_CRSCTL_BIN} status resource ${_RES_INSTANCE} -f 2>>${HC_STDERR_LOG} |\
    tr -d ' \t' >${_RES_RUN_FILE}.${_RES_INSTANCE} 2>/dev/null
[[ -s ${_RES_RUN_FILE}.${_RES_INSTANCE} ]] || {
    _MSG="unable to run command: {${_CRSCTL_BIN} status resource -f ${_RES_INSTANCE}}"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
}
done

# gather resource information from healthcheck configuration
for _RES_INSTANCE in ${_RES_INSTANCES}
do
    awk -v resource="${_RES_INSTANCE}" '
    # double escape []
    BEGIN { found = 0; needle = "^\\["resource"\\]$" }

    # skip blank lines
    /^\s*$/ { next; }
    # skip comment lines
    /^#/ { next; }

    # end marker
    ( $0 ~  /^\[.*\]$/ && found ) {
        exit 1;
    }
    # start marker
    $0 ~ needle {
        found = 1;
    };
    # stanza body
    ( found && $0 !~ /^\[.*\]$/ ) {
        # print non-compressed and compressed version
        printf "%s|", $0;
        gsub(" |\t", "", $0);
        printf "%s\n", $0;
    }' < ${_CONFIG_FILE} 2>>${HC_STDERR_LOG} >${_RES_CFG_FILE}.${_RES_INSTANCE}
done

# do resource configuration checks (using the compressed strings)
for _RES_INSTANCE in ${_RES_INSTANCES}
do
    while read _RES_ENTRY
    do
        # split entry to get the compressed version
        _RES_CFG_ENTRY=$(print "${_RES_ENTRY}" | cut -f2 -d'|' 2>/dev/null)
        # get parameter name from non-compressed version
        _RES_PARAM=$(print "${_RES_ENTRY}" | cut -f1 -d'|' 2>/dev/null | cut -f1 -d'=' 2>/dev/null)
        # get parameter value from non-compressed version
        _RES_VALUE=$(print "${_RES_ENTRY}" | cut -f1 -d'|' 2>/dev/null | cut -f2 -d'=' 2>/dev/null)
        # is it present?
        _RES_MATCH=$(grep -c "${_RES_CFG_ENTRY}" ${_RES_RUN_FILE}.${_RES_INSTANCE} 2>/dev/null)

        # chop value if needed
        if (( $(data_get_length_string "${_RES_VALUE}") > _MAX_LENGTH_VALUE_STRING ))
        then
            _RES_VALUE=$(data_get_substring "${_RES_VALUE}" ${_MAX_LENGTH_VALUE_STRING})
            _RES_VALUE="${_RES_VALUE} ..."
        fi

        # find match between active and desired state?
        if (( _RES_MATCH == 0 ))
        then
            # get parameter name from non-compressed version
            _MSG="'${_RES_PARAM}' (${_RES_VALUE}) is not correctly configured for ${_RES_INSTANCE}"
            _STC=1
        else
            _MSG="'${_RES_PARAM}' (${_RES_VALUE}) is configured for ${_RES_INSTANCE}"
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
            _STC=0
        fi
    done <${_RES_CFG_FILE}.${_RES_INSTANCE}

    # add crsctl output to stdout log
    print "==== {${_CRSCTL_BIN} status resource ${_RES_INSTANCE} -f} ====" >>${HC_STDOUT_LOG}
    cat "${_RES_CFG_FILE}.${_RES_INSTANCE}" >>${HC_STDOUT_LOG}
done

# do cleanup
rm -f ${_RES_RUN_FILE}.* ${_RES_CFG_FILE}.* >/dev/null 2>&1

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with parameters:
                log_healthy=<yes|no>
                crsctl_bin=<path_to_crsctl>
              and formatted stanzas for resource definitions
PURPOSE     : Checks the configuration of Clusterware resources (parameters/values)
              (comparing serialized strings from the HC configuration file to the
              active cluster configuration)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
