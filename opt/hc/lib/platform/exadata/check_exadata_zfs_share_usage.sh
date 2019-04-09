#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_zfs_share_usage.sh
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
# @(#) MAIN: check_exadata_zfs_share_usage
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), dump_logs(), init_hc(), linux_exec_ssh(),
#           log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-18: initial version [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2019-04-09: fix bad math in 2FS script & HC message [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_zfs_share_usage
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-04-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# usage query script -- DO NOT CHANGE --
# prj1:share1:16
# prj2:share1:85
typeset _ZFS_SCRIPT="
    script
        run('shares');
        projects = list();

        for (i = 0; i < projects.length; i++) {
            try { run('select ' + projects[i]);
                shares = list();

                for (j = 0; j < shares.length; j++) {
                    try { run('select ' + shares[j]);
                        printf('%s:%s:%d\n', projects[i], shares[j],
                            get('space_data')/get('quota')*100);
                            run('cd ..');
                        } catch (err) { }
                    }
                run('cd ..');
            } catch (err) {
                throw ('unexpected error occurred');
            }
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
typeset _CFG_MAX_SPACE_USAGE=""
typeset _CFG_SSH_KEY_FILE=""
typeset _CFG_SSH_OPTS=""
typeset _CFG_SSH_USER=""
typeset _CFG_SPACE_THRESHOLD=""
typeset _CFG_ZFS_HOSTS=""
typeset _CFG_ZFS_HOST=""
typeset _CFG_ZFS_LINE=""
typeset _PROJECT_NAME=""
typeset _SHARE_NAME=""
typeset _SPACE_USAGE=""
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
_CFG_MAX_SPACE_USAGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'max_space_usage')
if [[ -z "${_CFG_MAX_SPACE_USAGE}" ]]
then
    # default
    _CFG_MAX_SPACE_USAGE=90
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
                _ZFS_DATA="${_CFG_ZFS_HOST}:${_SSH_LINE}"
            else
                # shellcheck disable=SC1117
                _ZFS_DATA="${_ZFS_DATA}\n${_CFG_ZFS_HOST}:${_SSH_LINE}"
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
print "${_ZFS_DATA}" | while IFS=':' read -r _ZFS_HOST _PROJECT_NAME _SHARE_NAME _SPACE_USAGE
do
    (( ARG_DEBUG > 0 )) && debug "parsing space data for share: ${_ZFS_HOST}:${_PROJECT_NAME}/${_SHARE_NAME}"
    _CFG_SPACE_THRESHOLD=""

    # which threshold to use (general or custom?), keep in mind wildcards (custom will overrule wildcard entry)
    _CFG_ZFS_LINE=$(grep -E -e "^zfs:${_ZFS_HOST}:[*]:[*]:" ${_CONFIG_FILE} 2>/dev/null)
    if [[ -n "${_CFG_ZFS_LINE}" ]]
    then
        (( ARG_DEBUG > 0 )) && debug "found wilcard definition for ${_ZFS_HOST} in configuration file ${_CONFIG_FILE}"
        _CFG_SPACE_THRESHOLD=$(print "${_CFG_ZFS_LINE}" | cut -f5 -d':' 2>/dev/null)
        # null value means general threshold
        if [[ -z "${_CFG_SPACE_THRESHOLD}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "found empty space threshold for ${_ZFS_HOST}, using general threshold"
            _CFG_SPACE_THRESHOLD=${_CFG_MAX_SPACE_USAGE}
        fi
    fi
    _CFG_ZFS_LINE=$(grep -E -e "^zfs:${_ZFS_HOST}:${_PROJECT_NAME}:${_SHARE_NAME}:" ${_CONFIG_FILE} 2>/dev/null)
    if [[ -n "${_CFG_ZFS_LINE}" ]]
    then
        (( ARG_DEBUG > 0 )) && debug "found custom definition for ${_ZFS_HOST}:${_PROJECT_NAME}/${_SHARE_NAME} in configuration file ${_CONFIG_FILE}"
        _CFG_SPACE_THRESHOLD=$(print "${_CFG_ZFS_LINE}" | cut -f5 -d':' 2>/dev/null)
        # null value means general threshold
        if [[ -z "${_CFG_SPACE_THRESHOLD}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "found empty space threshold for ${_ZFS_HOST}:${_PROJECT_NAME}:${_SHARE_NAME}, using general threshold"
            _CFG_SPACE_THRESHOLD=${_CFG_MAX_SPACE_USAGE}
        fi
    fi
    if [[ -n "${_CFG_SPACE_THRESHOLD}" ]]
    then
        data_is_numeric "${_CFG_SPACE_THRESHOLD}"
        if (( $? > 0 ))
        then
            warn "value for <max_space_threshold> is not numeric in configuration file ${_CONFIG_FILE}"
            continue
        fi
        # zero value means disabled check
        if (( _CFG_SPACE_THRESHOLD == 0 ))
        then
            (( ARG_DEBUG > 0 )) && debug "found zero space threshold, disabling check"
            continue
        fi
    else
        (( ARG_DEBUG > 0 )) && debug "no custom space threshold for ${_ZFS_HOST}:${_PROJECT_NAME}:${_SHARE_NAME}, using general threshold"
        _CFG_SPACE_THRESHOLD=${_CFG_MAX_SPACE_USAGE}
    fi

    # perform check
    if (( _SPACE_USAGE > _CFG_SPACE_THRESHOLD ))
    then
        _MSG="${_ZFS_HOST}:${_PROJECT_NAME}/${_SHARE_NAME} exceeds its space threshold (${_SPACE_USAGE}%>${_CFG_SPACE_THRESHOLD}%)"
        _STC=1
    else
        _MSG="${_ZFS_HOST}:${_PROJECT_NAME}/${_SHARE_NAME} does not exceed its space threshold (${_SPACE_USAGE}%<=${_CFG_SPACE_THRESHOLD}%)"
        _STC=0
    fi
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}" "${_SPACE_USAGE}" "${_CFG_SPACE_THRESHOLD}"
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
               max_space_usage=<general_max_space_treshold>
              and formatted stanzas of:
               zfs:<host_name>:<replication_name>:<replication_enabled>:<replication_result>:<max_space_threshold>
PURPOSE     : Checks the space usage for the configured ZFS hosts/shares
              CLI: zfs > shares > select (project) > (select share) > show
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
