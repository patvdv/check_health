#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_zfs_cluster.sh
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
# @(#) MAIN: check_exadata_zfs_cluster
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_get_lvalue_from_config, dump_logs(),
#           data_strip_outer_space(), init_hc(), linux_exec_ssh(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-07-05: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_zfs_cluster
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-07-05"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# cluster query script -- DO NOT CHANGE --
# state=AKCS_CLUSTERED
# link=clustron3_ng3:0/clustron_uart:0 = AKCIOS_ACTIVE
# link=clustron3_ng3:0/clustron_uart:1 = AKCIOS_ACTIVE
# link=clustron3_ng3:0/dlpi:0 = AKCIOS_ACTIVE
typeset _ZFS_SCRIPT="
    script
        run('configuration cluster');
        printf('state=%s\n', get('state'));
        var links = run('links');
        var links_array = links.split('\n');
        for (var i = 0; i < links_array.length; ++i) {
            if (links_array[i] != '') {
                printf('link=%s\n', links_array[i].replace(/^\s+|\s+$/g,''));
            }
        }"
# target state of the cluster
typeset _CLUSTER_TARGET="AKCS_CLUSTERED"
# target state of the cluster links
typeset _LINK_TARGET="AKCIOS_ACTIVE"
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
typeset _CFG_SPACE_THRESHOLD=""
typeset _CFG_ZFS_HOSTS=""
typeset _CFG_ZFS_HOST=""
typeset _CFG_ZFS_LINE=""
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
        warn "unable to discover usage data on ${_CFG_ZFS_HOST}"
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        continue
    else
        # mangle SSH output by prefixing with hostname
        print "${_SSH_OUTPUT}" | while read -r _SSH_LINE
        do
            if [[ -z "${_ZFS_DATA}" ]]
            then
                _ZFS_DATA="${_CFG_ZFS_HOST}#${_SSH_LINE}"
            else
                # shellcheck disable=SC1117
                _ZFS_DATA=$(printf "%s\n%s#%s" "${_ZFS_DATA}" "${_CFG_ZFS_HOST}" "${_SSH_LINE}")
            fi
        done
    fi
done

# process usage status data
if [[ -z "${_ZFS_DATA}" ]]
then
    _MSG="did not discover any ZFS share data"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    return 1
fi
print "${_ZFS_DATA}" | while IFS='#' read -r _ZFS_HOST _CLUSTER_LINE
do
    (( ARG_DEBUG > 0 )) && debug "parsing cluster data for appliance: ${_ZFS_HOST}"

    # split up cluster data & perform checks
    case "${_CLUSTER_LINE}" in
        link=*)
            _LINK_STATE=$(data_strip_outer_space "$(print "${_CLUSTER_LINE}" | cut -f3 -d'=' 2>/dev/null)")

            if [[ "${_LINK_STATE}" != "${_LINK_TARGET}" ]]
            then
                _MSG="${_ZFS_HOST} cluster link state is NOK ([${_LINK_STATE}!=${_LINK_TARGET})"
                _STC=1
            else
                _MSG="${_ZFS_HOST} cluster link state is OK (${_LINK_STATE}==${_LINK_TARGET})"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_LINK_STATE}" "${_LINK_TARGET}"
            fi
            ;;
        state=*)
            _CLUSTER_STATE=$(print "${_CLUSTER_LINE##state=}")

            if [[ "${_CLUSTER_STATE}" != "${_CLUSTER_TARGET}" ]]
            then
                _MSG="${_ZFS_HOST} cluster state is NOK (${_CLUSTER_STATE}!=${_CLUSTER_TARGET})"
                _STC=1
            else
                _MSG="${_ZFS_HOST} cluster state is OK (${_CLUSTER_STATE}==${_CLUSTER_TARGET})"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_CLUSTER_STATE}" "${_CLUSTER_TARGET}"
            fi
            ;;
    esac
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
               ssh_opts=<ssh_options>
              and formatted stanzas of:
               zfs:<host_name>
PURPOSE     : Checks the state of the cluster and its links
              CLI: zfs > configuration > cluster > show
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
