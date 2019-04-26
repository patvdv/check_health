#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_clusterware_resource_status
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
# @(#) MAIN: check_clusterware_resource_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_contains_string(), data_uc(), dump_logs(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-04-20: merged HP-UX+Linux version [Patrick Van der Veken]
# @(#) 2019-04-26: made _CRSCTL_BIN path configurable + fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_clusterware_resource_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-04-26"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
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
typeset _CRS_HOST=""
typeset _CRS_NEEDLE=""
typeset _CRS_RESOURCE=""
typeset _CRS_STATES=""
typeset _CRS_STATE=""
typeset _CRS_STATES_ENTRY=""
typeset _CRS_STATE_ENTRY=""
typeset _CRSCTL_BIN=""
typeset _CRSCTL_STATUS=""
typeset _IS_ONLINE=0
typeset _MATCH_RC=0

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

# do resource status checks
grep -E -e "^crs:" ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=":" read -r _ _CRS_RESOURCE _CRS_STATES
do
    # get actual resource info
    (( ARG_DEBUG > 0 )) && debug "checking for resource: ${_CRS_RESOURCE}"
    _CRSCTL_STATUS=$(${_CRSCTL_BIN} status resource "${_CRS_RESOURCE}" 2>>${HC_STDERR_LOG})
    if (( $? > 0 )) || [[ -z "${_CRSCTL_STATUS}" ]]
    then
        _MSG="unable to run command: {${_CRSCTL_BIN} status resource ${_CRS_RESOURCE}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi

    # loop over host/state entries
    print "${_CRS_STATES}" | while IFS=',' read -rA _CRS_STATES_ENTRY
    do
        _IS_ONLINE=0
        for _CRS_STATE_ENTRY in "${_CRS_STATES_ENTRY[@]}"
        do
            _CRS_HOST=$(print "${_CRS_STATE_ENTRY}" | cut -f1 -d'=' 2>/dev/null)
            _CRS_STATE=$(print "${_CRS_STATE_ENTRY}" | cut -f2 -d'=' 2>/dev/null)
            if [[ -z "${_CRS_HOST}" || -z "${_CRS_STATE}" ]]
            then
                warn "host/state value(s) for resource ${_CRS_RESOURCE} are/is incorrect in configuration file ${_CONFIG_FILE}"
                continue
            fi
            (( ARG_DEBUG > 0 )) && debug "checking for host/state: ${_CRS_HOST}/${_CRS_STATE}"

            # get actual resource state
            CRS_STATE_LINE=$(print "${_CRSCTL_STATUS}" | grep -E -e "^STATE=" 2>/dev/null)

            # set needle (wildcard or host check?)
            if [[ "${_CRS_HOST}" = "*" ]]
            then
                _CRS_NEEDLE=$(data_uc "${_CRS_STATE}")
            else
                case "${_CRS_STATE}" in
                    ONLINE|online|Online)
                        _CRS_NEEDLE=$(data_uc "${_CRS_STATE}")
                        _CRS_NEEDLE="${_CRS_NEEDLE} on ${_CRS_HOST}"
                        ;;
                    OFFLINE|offline|Offline)
                        _CRS_NEEDLE=$(data_uc "${_CRS_STATE}")
                        ;;
                esac
            fi

            # check for match
            # if resource is online on at least one node, then CRS will not flag it offline
            # on any other nodes in which case we just do a NOOP
            # (ONLINE stanzas must preceed OFFLINE stanzas in the configuration file)
            if (( _IS_ONLINE > 0 ))
            then
                _MATCH_RC=1
            else
                data_contains_string "${CRS_STATE_LINE}" "${_CRS_NEEDLE}"
                _MATCH_RC=$?
            fi
            if (( _MATCH_RC >> 0 ))
            then
                _MSG="resource ${_CRS_RESOURCE} has a correct state [${_CRS_STATE}@${_CRS_HOST}]"
                _STC=0
                _IS_ONLINE=1
            else
                _MSG="resource ${_CRS_RESOURCE} has a wrong state [${_CRS_STATE}@${_CRS_HOST}]"
                _STC=1
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}"
            fi
        done
    done

    # add crsctl output to stdout log
    print "==== {${_CRSCTL_BIN} status resource ${_CRS_RESOURCE}} ====" >>${HC_STDOUT_LOG}
    print "${_CRSCTL_STATUS}" >>${HC_STDOUT_LOG}

done

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
              and formatted stanzas:
                crs:<resource_name>:<*|node>=<ONLINE|OFFLINE>,<*|node>=<ONLINE|OFFLINE>,...
PURPOSE     : Checks the STATE of CRS resource(s)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
