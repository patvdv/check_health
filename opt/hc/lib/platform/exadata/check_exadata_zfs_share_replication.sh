#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_zfs_share_replication.sh
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
# @(#) MAIN: check_exadata_zfs_share_replication
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_contains_string(), data_expand_numerical_range(),
#           data_get_lvalue_from_config(), data_has_newline(), data_is_numeric(),
#           dump_logs(), init_hc(), linux_exec_ssh(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-18: initial version [Patrick Van der Veken]
# @(#) 2019-02-19: fix for <unknown> replication value [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2019-04-12: small fixes [Patrick Van der Veken]
# @(#) 2019-05-14: small fixes [Patrick Van der Veken]
# @(#) 2020-01-27: addition of day check option +
# @(#)             newline config value check [Patrick Van der Veken]
# @(#) 2020-03-05: addition of hour check option
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_zfs_share_replication
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2020-03-04"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# replication query script -- DO NOT CHANGE --
# prj1/share1:true:idle:success:111
# prj2/share2:true:idle:success:51
typeset _ZFS_SCRIPT="
    script
        run('shares replication actions');
        actions = list();
        for (i = 0; i < actions.length; i++) {
            try { run('select ' + actions[i]);
                printf('%s:%s:%s:%s\n', get('replication_of'),
                    get('enabled'),
                    get('last_result'),
                    get('replica_lag'));
                run('cd ..');
            } catch (err) { }
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
typeset _CFG_MAX_REPLICA_LAG=""
typeset _CFG_REPLICATION_LAG=""
typeset _CFG_SSH_KEY_FILE=""
typeset _CFG_SSH_OPTS=""
typeset _CFG_SSH_USER=""
typeset _CFG_ZFS_HOSTS=""
typeset _CFG_ZFS_HOST=""
typeset _CFG_ZFS_LINE=""
typeset _CFG_REPLICATION_DAYS=""
typeset _CFG_REPLICATION_HOURS=""
typeset _REPLICATION_ENABLED=""
typeset _REPLICATION_HOURS=""
typeset _REPLICATION_LAG=""
typeset _REPLICATION_RESULT=""
typeset _SSH_BIN=""
typeset _SSH_OUTPUT=""
typeset _ZFS_DATA=""
typeset _WEEKDAY=$(data_lc "$(date '+%a' 2>/dev/null)")  # Sun
typeset _HOUR=$(data_strip_space "$(date '+%k' 2>/dev/null)") # 7,23 etc

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
_CFG_MAX_REPLICA_LAG=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'max_replica_lag')
if [[ -z "${_CFG_MAX_REPLICA_LAG}" ]]
then
    # default
    _CFG_MAX_REPLICA_LAG=90
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

# gather ZFS hostnames
_CFG_ZFS_HOSTS=$(grep -i -E -e '^zfs:' ${_CONFIG_FILE} 2>/dev/null | cut -f2 -d':' 2>/dev/null | sort -u 2>/dev/null)
if [[ -z "${_CFG_ZFS_HOSTS}" ]]
then
    warn "no monitoring rules defined in ${_CONFIG_FILE}"
    return 1
fi

# gather ZFS replication data
print "${_CFG_ZFS_HOSTS}" | while read -r _CFG_ZFS_HOST
do
    (( ARG_DEBUG > 0 )) && debug "executing remote ZFS script on ${_CFG_ZFS_HOST}"
    _SSH_OUTPUT=$(linux_exec_ssh "${_CFG_SSH_OPTS}" "${_CFG_SSH_USER}" "${_CFG_ZFS_HOST}" "${_ZFS_SCRIPT}" 2>>${HC_STDERR_LOG})
    # shellcheck disable=SC2181
    if (( $? > 0 )) || [[ -z "${_SSH_OUTPUT}" ]]
    then
        warn "unable to discover replication data on ${_CFG_ZFS_HOST}"
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

# process replication status data
if [[ -z "${_ZFS_DATA}" ]]
then
    _MSG="did not discover any ZFS replication data"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    return 1
fi
print "${_ZFS_DATA}" | while IFS=':' read -r _ZFS_HOST _REPLICATION_NAME _REPLICATION_ENABLED _REPLICATION_RESULT _REPLICATION_LAG
do
    (( ARG_DEBUG > 0 )) && debug "parsing replication data for share: ${_ZFS_HOST}:${_REPLICATION_NAME}"
    _CFG_REPLICATION_ENABLED=""
    _CFG_REPLICATION_RESULT=""
    _CFG_REPLICATION_LAG=""
    _CFG_REPLICATION_DAYS=""
    _CFG_REPLICATION_HOURS=""

    # which values to use (general or custom?), keep in mind wildcards (custom will overrule wildcard entry)
    _CFG_ZFS_LINE=$(grep -E -e "^zfs:${_ZFS_HOST}:[*]:" ${_CONFIG_FILE} 2>/dev/null)
    if [[ -n "${_CFG_ZFS_LINE}" ]]
    then
        (( ARG_DEBUG > 0 )) && debug "found wildcard definition for ${_ZFS_HOST} in configuration file ${_CONFIG_FILE}"
        _CFG_REPLICATION_ENABLED=$(print "${_CFG_ZFS_LINE}" | cut -f4 -d':' 2>/dev/null)
        _CFG_REPLICATION_RESULT=$(print "${_CFG_ZFS_LINE}" | cut -f5 -d':' 2>/dev/null)
        _CFG_REPLICATION_LAG=$(print "${_CFG_ZFS_LINE}" | cut -f6 -d':' 2>/dev/null)
        _CFG_REPLICATION_DAYS=$(print "${_CFG_ZFS_LINE}" | cut -f7 -d':' 2>/dev/null)
        _CFG_REPLICATION_HOURS=$(print "${_CFG_ZFS_LINE}" | cut -f8 -d':' 2>/dev/null)
        # null value means general threshold
        if [[ -z "${_CFG_REPLICATION_LAG}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "found empty lag threshold for ${_ZFS_HOST}, using general threshold"
            _CFG_REPLICATION_LAG=${_CFG_MAX_REPLICATION_LAG}
        fi
    fi
    _CFG_ZFS_LINE=$(grep -E -e "^zfs:${_ZFS_HOST}:${_REPLICATION_NAME}:" ${_CONFIG_FILE} 2>/dev/null)
    if [[ -n "${_CFG_ZFS_LINE}" ]]
    then
        data_has_newline "${_CFG_ZFS_LINE}"
        # shellcheck disable=SC2181
        if (( $? > 0 ))
        then
            warn "ignoring ${_ZFS_HOST}:${_REPLICATION_NAME} because it parses to multiple results in ${_CONFIG_FILE}"
            continue
        fi
        (( ARG_DEBUG > 0 )) && debug "found custom definition for ${_ZFS_HOST}:${_REPLICATION_NAME} in configuration file ${_CONFIG_FILE}"
        _CFG_REPLICATION_ENABLED=$(print "${_CFG_ZFS_LINE}" | cut -f4 -d':' 2>/dev/null)
        _CFG_REPLICATION_RESULT=$(print "${_CFG_ZFS_LINE}" | cut -f5 -d':' 2>/dev/null)
        _CFG_REPLICATION_LAG=$(print "${_CFG_ZFS_LINE}" | cut -f6 -d':' 2>/dev/null)
        _CFG_REPLICATION_DAYS=$(print "${_CFG_ZFS_LINE}" | cut -f7 -d':' 2>/dev/null)
        _CFG_REPLICATION_HOURS=$(print "${_CFG_ZFS_LINE}" | cut -f8 -d':' 2>/dev/null)
        # null value means general threshold
        if [[ -z "${_CFG_REPLICATION_LAG}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "found empty lag threshold for ${_ZFS_HOST}, using general threshold"
            _CFG_REPLICATION_LAG=${_CFG_MAX_REPLICATION_LAG}
        fi
    fi
    if [[ -n "${_CFG_REPLICATION_LAG}" ]]
    then
        data_is_numeric "${_CFG_REPLICATION_LAG}"
        # shellcheck disable=SC2181
        if (( $? > 0 ))
        then
            warn "value for <max_replication_lag> is not numeric in configuration file ${_CONFIG_FILE}"
            continue
        fi
        # zero value means disabled check
        if (( _CFG_REPLICATION_LAG == 0 ))
        then
            (( ARG_DEBUG > 0 )) && debug "found zero lag threshold, disabling check"
            continue
        fi
    else
        (( ARG_DEBUG > 0 )) && debug "no custom space threshold for ${_ZFS_HOST}:${_REPLICATION_NAME}, using general threshold"
        _CFG_REPLICATION_LAG=${_CFG_MAX_REPLICATION_LAG}
    fi
    # fixed defaults if missing
    [[ -z "${_CFG_REPLICATION_ENABLED}" || "${_CFG_REPLICATION_ENABLED}" = '*' ]] && _CFG_REPLICATION_ENABLED="true"
    [[ -z "${_CFG_REPLICATION_RESULT}" || "${_CFG_REPLICATION_RESULT}" = '*' ]] && _CFG_REPLICATION_RESULT="success"
    _CFG_REPLICATION_DAYS=$(data_lc "${_CFG_REPLICATION_DAYS}")
    [[ -z "${_CFG_REPLICATION_DAYS}" || "${_CFG_REPLICATION_DAYS}" = '*' ]] && _CFG_REPLICATION_DAYS="${_WEEKDAY}"
    if [[ -z "${_CFG_REPLICATION_HOURS}" || "${_CFG_REPLICATION_HOURS}" = '*' ]]
    then
        _REPLICATION_HOURS="${_HOUR}"
    else
        _REPLICATION_HOURS=$(data_expand_numerical_range "${_CFG_REPLICATION_HOURS}")
    fi

    # perform checks
    # do we need to perform the check today?
    data_contains_string "${_CFG_REPLICATION_DAYS}" "${_WEEKDAY}"
    if (( $? > 0 ))
    then
        # do we need to perform the check this hour?
        data_contains_string "${_REPLICATION_HOURS}" "${_HOUR}"
        if (( $? > 0 ))
        then
            # check replication enabled state (active or not?)
            if [[ $(data_lc "${_REPLICATION_ENABLED}") != $(data_lc "${_CFG_REPLICATION_ENABLED}") ]]
            then
                _MSG="state for ${_ZFS_HOST}:${_REPLICATION_NAME} is NOK [${_REPLICATION_ENABLED}!=${_CFG_REPLICATION_ENABLED}]"
                _STC=1
            else
                _MSG="state for ${_ZFS_HOST}:${_REPLICATION_NAME} is OK [${_REPLICATION_ENABLED}==${_CFG_REPLICATION_ENABLED}]"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_REPLICATION_ENABLED}" "${_CFG_REPLICATION_ENABLED}"
            fi
            # check replication last result (success or not?)
            if [[ $(data_lc "${_REPLICATION_RESULT}") !=  $(data_lc "${_CFG_REPLICATION_RESULT}") ]]
            then
                _MSG="result for ${_ZFS_HOST}:${_REPLICATION_NAME} is NOK [${_REPLICATION_RESULT}!=${_CFG_REPLICATION_RESULT}]"
                _STC=1
            else
                _MSG="result for ${_ZFS_HOST}:${_REPLICATION_NAME} is OK [${_REPLICATION_RESULT}==${_CFG_REPLICATION_RESULT}]"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_REPLICATION_RESULT}" "${_CFG_REPLICATION_RESULT}"
            fi
            # check replication lag
            # caveat: replication lag is <unknown> at initial replication
            data_contains_string "${_REPLICATION_LAG}" "unknown"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                _MSG="lag for ${_ZFS_HOST}:${_REPLICATION_NAME} is unknown"
                _REPLICATION_LAG=-1
                _STC=1
            else
                if (( _REPLICATION_LAG > _CFG_REPLICATION_LAG ))
                then
                    _MSG="lag for ${_ZFS_HOST}:${_REPLICATION_NAME} is too big [${_REPLICATION_LAG}>${_CFG_REPLICATION_LAG}]"
                    _STC=1
                else
                    _MSG="lag for ${_ZFS_HOST}:${_REPLICATION_NAME} is OK [${_REPLICATION_LAG}<=${_CFG_REPLICATION_LAG}]"
                    _STC=0
                fi
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_REPLICATION_LAG}" "${_CFG_REPLICATION_LAG}"
            fi
        else
            warn "check of ${_ZFS_HOST}:${_REPLICATION_NAME} is not configured for this hour/these hours: ${_REPLICATION_HOURS}"
        fi
    else
        warn "check of ${_ZFS_HOST}:${_REPLICATION_NAME} is not configured for today"
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
               max_replication_lag=<general_max_replication>
              and formatted stanzas of:
               zfs:<host_name>:<replication_name>:<replication_enabled>:<replication_result>:<max_replication_lag>:<day1,day2>:<start_hour>-<end_hour>
PURPOSE     : Checks the replication state, sync status and maximum lag of the configured ZFS hosts/shares on certain days
              CLI: zfs > shares > replications > packages > select (action) > show
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
