#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_zfs_logs.sh
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
# @(#) MAIN: check_exadata_zfs_logs
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_get_lvalue_from_config(), dump_logs(),
#           init_hc(), linux_exec_ssh(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-18: initial version [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2019-05-14: _STC fix [Patrick Van der Veken]
# @(#) 2019-07-05: help fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_zfs_logs
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-07-05"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _AWK_RC=""
typeset _FILTER=""
typeset _FILTERS=""
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CFG_SSH_KEY_FILE=""
typeset _CFG_SSH_OPTS=""
typeset _CFG_SSH_USER=""
typeset _CFG_ZFS_HOSTS=""
typeset _CFG_ZFS_HOST=""
typeset _LAST_LOG_ENTRY=""
typeset _MSG_DESC=""
typeset _MSG_ID=""
typeset _MSG_MODULE=""
typeset _MSG_PRIO=""
typeset _MSG_RESULT=""
typeset _MSG_TEXT=""
typeset _MSG_TYPE=""
typeset _NEW_LAST_LOG_ENTRY=""
typeset _SSH_BIN=""
typeset _SSH_OUTPUT=""
typeset _STATE_FILE=""
typeset _ZFS_SCRIPT=""
typeset _ZFS_LOG=""
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

# gather ZFS hostnames
_CFG_ZFS_HOSTS=$(grep -i -E -e '^zfs:' ${_CONFIG_FILE} 2>/dev/null | cut -f2 -d':' 2>/dev/null | sort -u 2>/dev/null)
if [[ -z "${_CFG_ZFS_HOSTS}" ]]
then
    warn "no monitoring rules defined in ${_CONFIG_FILE}"
    return 1
fi

# gather ZFS log data
print "${_CFG_ZFS_HOSTS}" | while read -r _CFG_ZFS_HOST
do
    # for which log(s)?
    grep -i -E -e "^zfs:${_CFG_ZFS_HOST}:" ${_CONFIG_FILE} 2>/dev/null |\
        while IFS=':' read -r _ _ _ZFS_LOG _FILTERS
    do
        # validate _ZFS_LOG & define script settings
        case "${_ZFS_LOG}" in
            alert|ALERT|Alert)
                # define log query script -- DO NOT CHANGE --
                _ZFS_SCRIPT="
                    script
                        run('maintenance logs select alert');
                        entries = list();
                        for (i = 0; i < entries.length; i++) {
                            try { run('select ' + entries[i]);
                                printf('%s|%s|%s|%s|%s\n', entries[i], get('timestamp'),
                                    get('uuid'), get('description'), get('type'));
                                run('cd ..');
                            } catch (err) { }
                        }"
                # validate _FILTERS
                for _FILTER in $(data_comma2space "${_FILTERS}")
                do
                    case "${_FILTER}" in
                        minor|MINOR|major|MAJOR|CRITICAL|critical)
                            :
                            ;;
                        *)
                            warn "filter value is incorrect for ${_CFG_ZFS_HOST}/${_ZFS_LOG} in configuration file ${_CONFIG_FILE} "
                            return 1
                            ;;
                        esac
                done
                ;;
            FLTLOG|fltlog|Fltlog)
                # define log query script -- DO NOT CHANGE --
                _ZFS_SCRIPT="
                    script
                        run('maintenance logs select fltlog');
                        entries = list();
                        for (i = 0; i < entries.length; i++) {
                            try { run('select ' + entries[i]);
                                printf('%s|%s|%s|%s|%s\n', entries[i], get('timestamp'),
                                    get('uuid'), get('desc'), get('type'));
                                run('cd ..');
                            } catch (err) { }
                        }"
                # validate _FILTERS
                for _FILTER in $(data_comma2space "${_FILTERS}")
                do
                    case "${_FILTER}" in
                        minor|MINOR|major|MAJOR|CRITICAL|critical)
                            :
                            ;;
                        *)
                            warn "filter value is incorrect for ${_CFG_ZFS_HOST}/${_ZFS_LOG} in configuration file ${_CONFIG_FILE} "
                            return 1
                            ;;
                        esac
                done
                ;;
            SCRK|scrk|Scrk)
                # define log query script -- DO NOT CHANGE --
                _ZFS_SCRIPT="
                    script
                        run('maintenance logs select scrk');
                        entries = list();
                        for (i = 0; i < entries.length; i++) {
                            try { run('select ' + entries[i]);
                                printf('%s|%s|%s|%s\n', entries[i], get('timestamp'),
                                    get('description'), get('result'));
                                run('cd ..');
                            } catch (err) { }
                        }"
                # validate _FILTERS
                for _FILTER in $(data_comma2space "${_FILTERS}")
                do
                    case "${_FILTER}" in
                        failed|FAILED|OK|ok)
                            :
                            ;;
                        *)
                            warn "filter value is incorrect for ${_CFG_ZFS_HOST}/${_ZFS_LOG} in configuration file ${_CONFIG_FILE} "
                            return 1
                            ;;
                        esac
                done
                ;;
            SYSTEM|system|System)
                # define log query script -- DO NOT CHANGE --
                _ZFS_SCRIPT="
                    script
                        run('maintenance logs select system');
                        entries = list();
                        for (i = 0; i < entries.length; i++) {
                            try { run('select ' + entries[i]);
                                printf('%s|%s|%s|%s|%s\n', entries[i], get('timestamp'),
                                    get('module'), get('priority'), get('text'));
                                run('cd ..');
                            } catch (err) { }
                        }"
                _FILTERS="error"
                ;;
            *)
                warn "log name value is incorrect for ${_CFG_ZFS_HOST}/${_ZFS_LOG} in configuration file ${_CONFIG_FILE} "
                return 1
                ;;
        esac

        # check state file
        _STATE_FILE="${STATE_PERM_DIR}/${_CFG_ZFS_HOST}.${_ZFS_LOG}.logs"
        (( ARG_DEBUG > 0 )) && debug "checking/reading state file at ${_STATE_FILE}"
        if [[ -r ${_STATE_FILE} ]]
        then
            _LAST_LOG_ENTRY=$(<"${_STATE_FILE}")
            if [[ -z "${_LAST_LOG_ENTRY}" ]]
            then
                (( ARG_DEBUG > 0 )) && debug "no recorded last log entry for ${_CFG_ZFS_HOST}/${_ZFS_LOG}"
            else
                (( ARG_DEBUG > 0 )) && debug "recorded last log entry for ${_CFG_ZFS_HOST}/${_ZFS_LOG}: ${_LAST_LOG_ENTRY}"
            fi
        else
            : >${_STATE_FILE}
            # shellcheck disable=SC2181
            (( $? > 0 )) && {
                warn "failed to create new state file at ${_STATE_FILE}"
                return 1
            }
            log "created new state file at ${_STATE_FILE}"
        fi

        (( ARG_DEBUG > 0 )) && debug "executing remote ZFS script on ${_CFG_ZFS_HOST} for log ${_ZFS_LOG}"
        _SSH_OUTPUT=$(linux_exec_ssh "${_CFG_SSH_OPTS}" "${_CFG_SSH_USER}" "${_CFG_ZFS_HOST}" "${_ZFS_SCRIPT}" 2>>${HC_STDERR_LOG})
        # shellcheck disable=SC2181
        if (( $? > 0 )) || [[ -z "${_SSH_OUTPUT}" ]]
        then
            warn "unable to discover ${_ZFS_LOG} log data on ${_CFG_ZFS_HOST}"
            (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
            continue
        else
            # parse log lines based on the log source they originated from
            _ZFS_DATA=$(print -R "${_SSH_OUTPUT}" |\
                awk -F'|' -v zfs_log="${_ZFS_LOG}" -v filters="${_FILTERS}" -v last_entry="${_LAST_LOG_ENTRY}" '
                BEGIN {
                    found_last_entry = 0;

                    # build search needles/regexes
                    split (filters, filter_array, ",");
                    for (word in filter_array) {
                        filter_needle = filter_needle filter_array[word]"|";
                    }
                    # chop last "|"
                    gsub (/\|$/, "", filter_needle);

                    zfs_log = tolower(zfs_log);
                }

                {
                    # match log data against needle & $_LAST_LOG_ENTRY pointer
                    if (last_entry == "") {
                        # match against needle
                        if (zfs_log == "alert" || zfs_log == "fltlog") {
                            if (tolower ($5) ~ filter_needle) { print $0 };
                        }
                        if (zfs_log == "scrk" || zfs_log == "system") {
                            if (tolower ($4) ~ filter_needle) { print $0 };
                        }
                    } else {
                        # match against the $_LAST_LOG_ENTRY pointer
                        if ($1 ~ last_entry) {
                            found_last_entry = 1;
                            next;
                        }
                        if (found_last_entry > 0) {
                            # match against needle
                            if (zfs_log == "alert" || zfs_log == "fltlog") {
                                if (tolower ($5) ~ filter_needle) { print $0 };
                            }
                            if (zfs_log == "scrk" || zfs_log == "system") {
                                if (tolower ($4) ~ filter_needle) { print $0 };
                            }
                        }
                    }
                }

                END {
                    # when we had a log pointer at the start but did not
                    # encounter it, then we have a problematic situation (could
                    # be that the log pointer got rotated past the 100 lines query)
                    # flag this by RC=255 and reset the log pointer to last
                    # discovered entry (which is only a stopgap solution but the
                    # best we can come up with)
                    if (last_entry != "" && found_last_entry == 0) {
                        exit 255;
                    }
                }' 2>>${HC_STDERR_LOG})
            _AWK_RC=$?
            # check and reports results
            if (( _AWK_RC == 255 ))
            then
                warn "lost the current log pointer for ${_CFG_ZFS_HOST}/${_ZFS_LOG}"
                # rewrite log pointer from the last log entry we discovered
                _NEW_LAST_LOG_ENTRY=$(print "${_SSH_OUTPUT}" | tail -1 2>/dev/null | awk -F'|' '{ print $1 }' 2>/dev/null)
                if [[ -n "${_NEW_LAST_LOG_ENTRY}" ]]
                then
                    if (( ARG_LOG > 0 ))
                    then
                        warn "resetting the current log pointer for ${_CFG_ZFS_HOST}/${_ZFS_LOG} to ${_NEW_LAST_LOG_ENTRY}"
                        print "${_NEW_LAST_LOG_ENTRY}" >${_STATE_FILE} 2>>${HC_STDERR_LOG}
                    fi
                else
                    # zero the state file
                    if (( ARG_LOG > 0 ))
                    then
                        warn "null resetting the current log pointer for ${_CFG_ZFS_HOST}/${_ZFS_LOG}"
                        : >${_STATE_FILE} 2>>${HC_STDERR_LOG}
                    fi
                fi
                continue
            elif (( _AWK_RC > 0 ))
            then
                warn "unable to parse log data from ${_CFG_ZFS_HOST}/${_ZFS_LOG}"
                (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
                return 1
            else
                if [[ -n "${_ZFS_DATA}" ]]
                then
                    # save data to STDOUT
                    print "${_ZFS_DATA}" >>${HC_STDOUT_LOG}
                    # filter data based on logs
                    case "${_ZFS_LOG}" in
                        alert|ALERT|Alert)
                            print -R "${_ZFS_DATA}" | while IFS='|' read -r _MSG_ID _ _ _MSG_DESC _MSG_TYPE
                            do
                                _MSG="${_MSG_ID} (${_MSG_TYPE}) ${_MSG_DESC}"
                                log_hc "$0" 1 "${_CFG_ZFS_HOST}/${_ZFS_LOG}: ${_MSG}"
                            done
                            ;;
                        FLTLOG|fltlog|Fltlog)
                            print -R "${_ZFS_DATA}" | while IFS='|' read -r _MSG_ID _ _ _MSG_DESC _MSG_TYPE
                            do
                                _MSG="${_MSG_ID} (${_MSG_TYPE}) ${_MSG_DESC}"
                                log_hc "$0" 1 "${_CFG_ZFS_HOST}/${_ZFS_LOG}: ${_MSG}"
                            done
                            ;;
                        SCRK|scrk|Scrk)
                            print -R "${_ZFS_DATA}" | while IFS='|' read -r _MSG_ID _ _MSG_DESC _MSG_RESULT
                            do
                                if [[ "${_MSG_RESULT}" = "OK" ]]
                                then
                                    _STC=0
                                else
                                    _STC=1
                                fi
                                _MSG="${_MSG_ID} (${_MSG_RESULT}) ${_MSG_DESC}"
                                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                                then
                                    log_hc "$0" ${_STC} "${_CFG_ZFS_HOST}/${_ZFS_LOG}: ${_MSG}"
                                fi
                            done
                            ;;
                        SYSTEM|system|System)
                            print -R "${_ZFS_DATA}" | while IFS='|' read -r _MSG_ID _ _MSG_MODULE _MSG_PRIO _MSG_TEXT
                            do
                                _MSG="${_MSG_ID} (${_MSG_PRIO}) ${_MSG_MODULE}: ${_MSG_TEXT}"
                                log_hc "$0" 1 "${_CFG_ZFS_HOST}/${_ZFS_LOG}: ${_MSG}"
                            done
                            ;;
                    esac
                else
                    if (( _LOG_HEALTHY > 0 ))
                    then
                        _MSG="no (new) messages discovered from ${_CFG_ZFS_HOST}:/${_ZFS_LOG}"
                        log_hc "$0" 0 "${_MSG}"
                    fi
                fi
                # rewrite log pointer from the last log entry we discovered
                _NEW_LAST_LOG_ENTRY=$(print "${_SSH_OUTPUT}" | tail -1 2>/dev/null | awk -F'|' '{ print $1 }' 2>/dev/null )
                if (( ARG_LOG > 0 )) && [[ -n "${_NEW_LAST_LOG_ENTRY}" ]]
                then
                    (( ARG_DEBUG > 0 )) && debug "updating last log entry for ${_CFG_ZFS_HOST}/${_ZFS_LOG} to ${_NEW_LAST_LOG_ENTRY}"
                    print "${_NEW_LAST_LOG_ENTRY}" >${_STATE_FILE} 2>>${HC_STDERR_LOG}
                fi
            fi
        fi
    done
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
               zfs:<host_name>:<alert|fltlog|scrk|system>:<filters>
PURPOSE     : Checks the ZFS logs for (new) entries with particular alert level(s)
              Following logs are supported (filters in brackets):
               * alert (critical,major,minor)
               * fltlog (critical,major,minor)
               * system (error)
               * scrk (failed)
              CLI: zfs > maintenance > logs > select (log) > show
CAVEAT:       Plugin will use state files to track 'seen' messages. However each
              check will only retrieve the default 100 last log entries. So it
              is possible that log entries are lost between health checks (this
              can be avoided by scheduling the check quicker than the likely
              rotation time for 100 log entries).
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
