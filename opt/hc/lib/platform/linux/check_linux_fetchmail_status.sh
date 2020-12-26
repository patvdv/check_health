#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_fetchmail_status.sh
#******************************************************************************
# @(#) Copyright (C) 2020 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_linux_fetchmail_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn')
#
# @(#) HISTORY:
# @(#) 2016-12-26: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_fetchmail_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2020-12-26"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0
typeset _CFG_HEALTHY=""
typeset _CFG_ERROR_REGEX=""
typeset _ERROR_REGEX=""
typeset _CFG_ACCOUNT=""
typeset _CFG_RC_FILE=""
typeset _CFG_CHECK_LOG=""
typeset _OPENSSL_BIN=""
typeset _MD5SUM_BIN=""
typeset _HAS_OPENSSL=0
typeset _HAS_MD5SUM=0
typeset _USE_OPENSSL=0
typeset _USE_MD5SUM=0
typeset _DO_LOG=0
typeset _LOG_FILE=""
typeset _HASH_FILE_NAME=""
typeset _STATE_FILE=""
typeset _LAST_POINTER=""
typeset _NEW_LAST_POINTER=""
typeset _LOG_COUNT=""
typeset _LINE_NR=""
typeset _LINE_TEXT=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage "$0" "${_VERSION}" "${_CONFIG_FILE}" && return 0
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
# read required config values
_CFG_ERROR_REGEX=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'error_regex')
if [[ -n "${_CFG_ERROR_REGEX}" ]]
then
    _ERROR_REGEX="${_CFG_ERROR_REGEX}"
else
    _ERROR_REGEX="error|authfail|lockbusy|ioerr"
    (( ARG_DEBUG > 0 )) && debug "setting error_regex to default value: ${_ERROR_REGEX}"
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

#-------------------------------------------------------------------------------
# check for auxiliary tools
_OPENSSL_BIN="$(command -v openssl 2>>${HC_STDERR_LOG})"
[[ -x ${_OPENSSL_BIN} && -n "${_OPENSSL_BIN}" ]] && _HAS_OPENSSL=1
_MD5SUM_BIN="$(command -v md5sum 2>>${HC_STDERR_LOG})"
[[ -x ${_MD5SUM_BIN} && -n "${_MD5SUM_BIN}" ]] && _HAS_MD5SUM=1
# prefer openssl
if (( _HAS_OPENSSL == 1 ))
then
    _USE_OPENSSL=1
elif (( _HAS_MD5SUM == 1 ))
then
    _USE_MD5SUM=1
else
    warn "unable to find the 'openssl/md5sum' tools, will not do fetchmail log checking"
    return 1
fi

#-------------------------------------------------------------------------------
# perform check(s)
grep -E -e "^fetchmail:" "${_CONFIG_FILE}" 2>/dev/null | while IFS=":" read -r _ _CFG_ACCOUNT _CFG_RC_FILE _CFG_CHECK_LOG
do
    _STC=0

    # check config
    if [[ -z "${_CFG_ACCOUNT}" ]] && [[ -z "${_CFG_RC_FILE}" ]]
    then
        warn "missing values in configuration file at ${_CONFIG_FILE}"
        return 1
    fi

    # check if account exists
    id "${_CFG_ACCOUNT}" >/dev/null 2>/dev/null || {
        warn "account ${_CFG_ACCOUNT} does not exist on host, skipping"
        continue
    }

    # check if fetchmailrc file exists
    [[ -r "${_CFG_RC_FILE}" ]] || {
        warn "unable to read fetchmailrc file at ${_CFG_RC_FILE} for account ${_CFG_ACCOUNT}, skipping"
        continue
    }

    # get process details
    (( $(pgrep -u "${_CFG_ACCOUNT}" -f "fetchmail.*${_CFG_RC_FILE}" | wc -l 2>/dev/null) == 0 )) && _STC=1

    # evaluate results
    case ${_STC} in
        0)
            _MSG="fetchmail is running for account ${_CFG_ACCOUNT} (${_CFG_RC_FILE})"
            ;;
        1)
            _MSG="fetchmail is not running for account ${_CFG_ACCOUNT} (${_CFG_RC_FILE})"
            ;;
        *)
            _MSG="could not determine status of fetchmail for account ${_CFG_ACCOUNT} (${_CFG_RC_FILE})"
            ;;
    esac
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi

    # check log?
    case "${_CFG_CHECK_LOG}" in
        Yes|YES|yes)
            (( ARG_DEBUG > 0 )) && debug "doing log check for account ${_CFG_ACCOUNT} (${_CFG_RC_FILE})"
            _DO_LOG=1;
            ;;
        *)
            log "skipping fetchmail log check for account ${_CFG_ACCOUNT} (${_CFG_RC_FILE})"
            _DO_LOG=0;
            ;;
    esac

    # check auxiliary tools
    if (( _HAS_OPENSSL == 0 && _HAS_MD5SUM == 0 ))
    then
        warn "unable to find the 'openssl/md5sum' tools, will not do fetchmail log checking for account ${_CFG_ACCOUNT}"
        _DO_LOG=0
    fi

    if (( _DO_LOG > 0 ))
    then
        (( ARG_DEBUG > 0 )) && debug "will do log check for account ${_CFG_ACCOUNT} [${_CFG_RC_FILE}]"
        # get logfile statement in .fetchmailrc
        _LOG_FILE=$(grep "^set logfile" "${_CFG_RC_FILE}" 2>/dev/null | awk '{ print $3 }' 2>/dev/null)
        [[ -z "${_LOG_FILE}" ]] && {
            warn "no fetchmail log file defined in fetchmailrc file at ${_CFG_RC_FILE} for account ${_CFG_ACCOUNT}, skipping log check"
            continue
        }
        [[ -r "${_LOG_FILE}" ]] || {
            warn "unable to read fetchmail log file at ${_LOG_FILE} for account ${_CFG_ACCOUNT}, skipping log check"
            continue
        }
        (( ARG_DEBUG > 0 )) && debug "log file found at ${_LOG_FILE}"

        # determine state file (we use a hashed file name based on the fetchmail log file full path
        # to avoid globbing when account has the same name for multiple entries in the configuration file)
        (( _USE_OPENSSL == 1 )) && \
            _HASH_FILE_NAME=$(${_OPENSSL_BIN} dgst -md5 "${_LOG_FILE}" 2>>"${HC_STDERR_LOG}" | cut -f2 -d'=' 2>/dev/null | tr -d ' ' 2>/dev/null)
        (( _USE_MD5SUM == 1 )) && \
            _HASH_FILE_NAME=$(${_MD5SUM_BIN} dgst -md5 "${_LOG_FILE}" 2>>"${HC_STDERR_LOG}" | cut -f1 -d' ' 2>/dev/null)
        if [[ -z "${_HASH_FILE_NAME}" ]]
        then
            warn "unable to determine log state file for account ${_CFG_ACCOUNT}, skipping log check"
            continue
        fi

        # get log pointer from state file
        _STATE_FILE="${STATE_PERM_DIR}/${_HASH_FILE_NAME}.fetchmail"
        if [[ -r "${_STATE_FILE}" ]]
        then
            _LAST_POINTER=$(<"${_STATE_FILE}")
        fi
        if [[ -z "${_LAST_POINTER}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "could not determine last known log entry, resetting to 0"
            _LAST_POINTER=0
        else
            (( ARG_DEBUG > 0 )) && debug "old _LAST_POINTER=${_LAST_POINTER}"
        fi

        # check last known vs current pointer
        _LOG_COUNT=$(wc -l "${_LOG_FILE}" 2>/dev/null | cut -f1 -d' ')
        (( ARG_DEBUG > 0 )) && debug "line count for current log: ${_LOG_COUNT}"
        if (( _LOG_COUNT >= _LAST_POINTER ))
        then
            # find errors in later log lines
            awk -F':' -v error_regex="${_ERROR_REGEX}" -v last_pointer=${_LAST_POINTER} '
                {
                    # find error lines which have a line count > last pointer
                    if (NR > last_pointer && $0 ~ error_regex) {
                        # cut fetchmail: prefix & replce possible pipes
                        gsub(/^fetchmail: +/, "");
                        gsub(/\|/, "_");
                        # report issue with line number
                        print $0 "|" NR;
                    }
                }' "${_LOG_FILE}" 2>/dev/null | while IFS="|" read -r _LINE_TEXT _LINE_NR
            do
                _MSG="found issue in ${_LOG_FILE}: ${_LINE_TEXT} (LINENO=${_LINE_NR})"
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" 1 "${_MSG}"
                fi
                # update new last pointer
                (( ARG_DEBUG > 0 )) && debug "updating _NEW_LAST_POINTER=${_LINE_NR}"
                _NEW_LAST_POINTER=${_LINE_NR}
            done
        else
            # log small has shrunk, assume it has been rotated, resetting pointer to zero
            log "log file for account ${_CFG_ACCOUNT} seems to have been rotated, resetting log file pointer to 0"
            _LAST_POINTER=0
        fi

        # update state file with new last pointer
        if (( ARG_LOG > 0 ))
        then
            if [[ -n "${_NEW_LAST_POINTER}" ]] && (( _NEW_LAST_POINTER > _LAST_POINTER ))
            then
                _LAST_POINTER=${_NEW_LAST_POINTER}
            fi
            (( ARG_DEBUG > 0 )) && debug "new _LAST_POINTER=${_LAST_POINTER}"
            print "${_LAST_POINTER}" >"${_STATE_FILE}"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                warn "failed to update state file at ${_STATE_FILE}"
                return 1
            fi
        fi
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
              and formatted stanzas:
                fetchmail:<account>:<rc_file>:<check_log=Yes|No>
PURPOSE     : Checks the status of local fetchmail services (process & log).
              Fetchmail should be configured to run in daemon mode.
LOG HEALTHY : Supported
EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
