#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_zfs_services.sh
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
# @(#) MAIN: check_exadata_zfs_services
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_get_lvalue_from_config, dump_logs(),
#           init_hc(), linux_exec_ssh(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-18: initial version [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2019-05-14: small fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_zfs_services
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-05-14"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# usage query script -- DO NOT CHANGE --
# svc1:online
# svc2:disabled
typeset _ZFS_SCRIPT="
    script
        run('configuration services');

        var svcs = children();
        for (var i = 0; i < svcs.length; ++i) {
             run(svcs[i]);
             try {
                 printf('%0s:%s\n', svcs[i], get('<status>'));
             } catch (err) { };
             run('done');
       }"
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
typeset _CFG_SSH_KEY_FILE=""
typeset _CFG_SSH_OPTS=""
typeset _CFG_SSH_USER=""
typeset _CFG_ZFS_HOSTS=""
typeset _CFG_ZFS_HOST=""
typeset _CFG_ZFS_LINE=""
typeset _SERVICE_NAME=""
typeset _SERVICE_STATE=""
typeset _SSH_BIN=""
typeset _SSH_OUTPUT=""
typeset _ZFS_DATA=""

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
# read configuration values
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
_CFG_SSH_USER=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'ssh_user')
if [[ -z "${_CFG_SSH_USER}" ]]
then
    _CFG_SSH_USER="root"
fi
_CFG_SSH_KEY_FILE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'ssh_key_file')
_CFG_SSH_OPTS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'ssh_opts')
# add quiet mode
_CFG_SSH_OPTS="${_CFG_SSH_OPTS} -q"
if [[ -n "${_CFG_SSH_KEY_FILE}" ]]
then
    if [[ -r "${_CFG_SSH_KEY_FILE}" ]]
    then
        log "will use SSH key ${_CFG_SSH_KEY_FILE}"
        _CFG_SSH_OPTS="${_CFG_SSH_OPTS} -i ${_CFG_SSH_KEY_FILE}"
    else
        warn "will use SSH key ${_CFG_SSH_KEY_FILE}, but file does not exist"
        return 1
    fi
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

# check ssh
_SSH_BIN="$(command -v ssh 2>>${HC_STDERR_LOG})"
if [[ ! -x ${_SSH_BIN} || -z "${_SSH_BIN}" ]]
then
    warn "SSH is not installed here"
    return 1
fi

# gather ZFS hostnames (for this we need at least one data line, possibly with wildcards)
_CFG_ZFS_HOSTS=$(grep -i -E -e '^zfs:' ${_CONFIG_FILE} 2>/dev/null | cut -f2 -d':' 2>/dev/null | sort -u 2>/dev/null)
if [[ -z "${_CFG_ZFS_HOSTS}" ]]
then
    warn "no monitoring rules defined in ${_CONFIG_FILE}"
    return 1
fi

# gather ZFS usage data
print "${_CFG_ZFS_HOSTS}" | while read -r _CFG_ZFS_HOST
do
    (( ARG_DEBUG > 0 )) && debug "executing remote ZFS script on ${_CFG_ZFS_HOST}"
    _SSH_OUTPUT=$(linux_exec_ssh "${_CFG_SSH_OPTS}" "${_CFG_SSH_USER}" "${_CFG_ZFS_HOST}" "${_ZFS_SCRIPT}" 2>>${HC_STDERR_LOG})
    # shellcheck disable=SC2181
    if (( $? > 0 )) || [[ -z "${_SSH_OUTPUT}" ]]
    then
        warn "unable to discover services data on ${_CFG_ZFS_HOST}"
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        continue
    else
        # mangle SSH output by prefixing with hostname
        print "${_SSH_OUTPUT}" | while read -r _SSH_LINE
        do
            if [[ -z "${_ZFS_DATA}" ]]
            then
                _ZFS_DATA="${_CFG_ZFS_HOST}:${_SSH_LINE}"
            else
                # shellcheck disable=SC1117
                _ZFS_DATA=$(printf "%s\n%s:%s" "${_ZFS_DATA}" "${_CFG_ZFS_HOST}" "${_SSH_LINE}")
            fi
        done
    fi
done

# process usage status data
if [[ -z "${_ZFS_DATA}" ]]
then
    _MSG="did not discover any ZFS services data"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    return 1
fi
grep -E -e '^zfs:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read -r _ _CFG_ZFS_HOST _CFG_SERVICE_NAME _CFG_SERVICE_STATE
do
    if [[ -z "${_CFG_SERVICE_NAME}" ]]
    then
        warn "value of <service_name> for ${_CFG_ZFS_HOST} is not defined in configuration file ${_CONFIG_FILE}"
        continue
    fi
    case "${_CFG_SERVICE_STATE}" in
        online|ONLINE|Online|disabled|DISABLED|Disabled)
            :
            ;;
        *)
            warn "value of <service_state> for ${_CFG_ZFS_HOST}/${_CFG_SERVICE_NAME} is not correct in configuration file ${_CONFIG_FILE}"
            continue
    esac
    (( ARG_DEBUG > 0 )) && debug "parsing services data for service: ${_CFG_ZFS_HOST}/${_CFG_SERVICE_NAME}"

    # perform check
    _SERVICE_STATE=$(print "${_ZFS_DATA}" | grep -E -e "^${_CFG_ZFS_HOST}:${_CFG_SERVICE_NAME}:" 2>/dev/null | cut -f3 -d':' 2>/dev/null)
    if [[ -n "${_SERVICE_STATE}" ]]
    then
        if [[ $(data_lc "${_SERVICE_STATE}") != $(data_lc "${_CFG_SERVICE_STATE}") ]]
        then
            _MSG="state of ${_CFG_ZFS_HOST}/${_CFG_SERVICE_NAME} is NOK (${_SERVICE_STATE}!=${_CFG_SERVICE_STATE})"
            _STC=1
        else
            _MSG="state of ${_CFG_ZFS_HOST}/${_CFG_SERVICE_NAME} is OK (${_SERVICE_STATE}==${_CFG_SERVICE_STATE})"
            _STC=0
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
        fi
    else
        warn "did not find services data for ${_CFG_ZFS_HOST}/${_CFG_SERVICE_NAME}"
        continue
    fi
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
               ssh_user=<ssh_user_account>
               ssh_key_file=<ssh_private_key_file>
              and formatted stanzas of:
               zfs:<host_name>:<service_name>:<service_state>
PURPOSE     : Checks the state of services for the configured ZFS hosts/shares
              CLI: zfs > status > services > show
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
