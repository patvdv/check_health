#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_burp_backup.sh
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
# @(#) MAIN: check_linux_burp_backup
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_is_numeric(), data_strip_outer_space(),
#           init_hc(), log_hc(), warn()
#           GNU date that can calculate UNIX epoch seconds from given date,
#           BURP server must be be able to impersonate configured clients
#
# @(#) HISTORY:
# @(#) 2016-12-01: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-08-25: support for burp v2 [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: changed format of stanzas in configuration file &
# @(#)             added support for --log-healthy [Patrick Van der Veken]
# @(#) 2019-03-10: fix for burp v2
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2021-03-28: updated code for changing 'burp -v' option as of burp v2.2 +
#                  quote fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_burp_backup
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _BURP_SERVER_CONFIG_FILE="/etc/burp/burp-server.conf"
typeset _BURP_CLIENT_CONFIG_FILE="/etc/burp/burp.conf"
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2021-03-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _BURP_BIN=""
typeset _BURP_AGE=""
typeset _BURP_BACKUP_DIR=""
typeset _BURP_CLIENTCONF_DIR=""
typeset _BURP_CLIENT=""
typeset _BURP_VERSION=""
typeset _BURP_V_OUTPUT=""
typeset _BURP_WARNINGS=""
typeset _GNU_DATE=""
typeset _COUNT=1
typeset _IS_OLD_STYLE=0
typeset _NOW="$(date '+%Y%m%d %H%M' 2>/dev/null)"       # format: YYYYMMDD HHMM

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage "$0" "${_VERSION}" "${_CONFIG_FILE}" && return 0
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

# check for old-style configuration file (non-prefixed stanzas)
_IS_OLD_STYLE=$(grep -c -E -e "^client:" "${_CONFIG_FILE}" 2>/dev/null)
if (( _IS_OLD_STYLE == 0 ))
then
    warn "no 'client:' stanza(s) found in ${_CONFIG_FILE}; possibly an old-style configuration?"
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

# check for capable GNU date
_GNU_DATE=$(date --date="1 day ago" '+%s' 2>/dev/null)
data_is_numeric "${_GNU_DATE}"
# shellcheck disable=SC2181
if (( $? > 0 ))
then
    warn "no capable GNU date found here"
    return 1
fi

# find burp
_BURP_BIN="$(command -v burp 2>/dev/null)"
if [[ ! -x ${_BURP_BIN} || -z "${_BURP_BIN}" ]]
then
    warn "burp is not installed here"
    return 1
fi

# burp v1 or v2? (up to v2.1 burp -v; as of burp v2.2 use burp -V but we can still use burp -v with a workaround)
_BURP_V_OUTPUT="$(${_BURP_BIN} -v 2>/dev/null)"
# check if the output contains 'server version'
case "${_BURP_V_OUTPUT}" in
    *Server\ version*)
        # burp 2.2 and above
        _BURP_VERSION=$(print "${_BURP_V_OUTPUT}" | grep "Server version" | awk -F":" '{ print $NF}')
        _BURP_VERSION="burp-"$(data_strip_outer_space "${_BURP_VERSION}")
        ;;
    *)
        # burp 2.1 and below
        _BURP_VERSION="${_BURP_V_OUTPUT}"
        ;;
esac
(( ARG_DEBUG > 0 )) && debug "burp version: ${_BURP_VERSION}"
case "${_BURP_VERSION}" in
    burp-2*)
        # check for burp server
        if [[ ! -r ${_BURP_SERVER_CONFIG_FILE} ]]
        then
            warn "burp server configuration file not found ($_BURP_SERVER_CONFIG_FILE)"
            return 1
        fi
        # check for burp client
        if [[ ! -r ${_BURP_CLIENT_CONFIG_FILE} ]]
        then
            warn "burp client configuration file not found ($_BURP_SERVER_CONFIG_FILE)"
            return 1
        fi

        # burp v2 does not support yet the 'burp -a S -C <client> -z backup_stats' action
        # so we need to find the backup_stats file ourselves
        _BURP_BACKUP_DIR=$(_CONFIG_FILE="${_BURP_SERVER_CONFIG_FILE}" data_get_lvalue_from_config 'directory')
        if [[ -z "${_BURP_BACKUP_DIR}" ]]
        then
            _BURP_CLIENTCONF_DIR=$(_CONFIG_FILE="${_BURP_SERVER_CONFIG_FILE}" data_get_lvalue_from_config 'clientconfdir')
            if [[ -z "${_BURP_CLIENTCONF_DIR}" ]]
            then
                warn "could not determine backup directory from 'directory' or 'clientconfdir' directives'"
                return 1
            fi
        fi
        ;;
    burp-1*)
        # check for burp server
        if [[ ! -r ${_BURP_SERVER_CONFIG_FILE} ]]
        then
            warn "burp server configuration file not found ($_BURP_SERVER_CONFIG_FILE)"
            return 1
        fi
        ;;
    *)
        warn "incorrect burp version reported: ${_BURP_VERSION}"
        return 1
        ;;
esac

# check backup runs of clients
grep -E -e "^client:" "${_CONFIG_FILE}" 2>/dev/null |\
    while IFS=':' read -r _ _BURP_CLIENT _BURP_WARNINGS _BURP_AGE
do
    typeset _BACKUP_AGING=""
    typeset _BACKUP_DATE=""
    typeset _BACKUP_RUN=""
    typeset _BACKUP_STATS=""
    typeset _BACKUP_WARNINGS="" # set empty string, not 0!
    typeset _CUR_BACKUP_TIME=""
    typeset _MIN_BACKUP_TIME=""
    typeset _STC=0

    if [[ -n "${_BURP_CLIENT}" ]] && [[ -n "${_BURP_WARNINGS}" ]] && [[ -n "${_BURP_AGE}" ]]
    then
        # convert backup aging (UNIX seconds)
        case "${_BURP_AGE}" in
            *h)
                _BACKUP_AGING="${_BURP_AGE%%h}"
                _MIN_BACKUP_TIME=$(( $(date -d "${_NOW}" '+%s' 2>/dev/null) - (_BACKUP_AGING * 60 * 60) ))
                ;;
            *d)
                _BACKUP_AGING="${_BURP_AGE%%d}"
                _MIN_BACKUP_TIME=$(( $(date -d "${_NOW}" '+%s' 2>/dev/null) - (_BACKUP_AGING * 60 * 60 * 24) ))
                ;;
            *w)
                _BACKUP_AGING="${_BURP_AGE%%w}"
                _MIN_BACKUP_TIME=$(( $(date -d "${_NOW}" '+%s' 2>/dev/null) - (_BACKUP_AGING * 60 * 60 * 24 * 7) ))
                ;;
            *)
                warn "no correct backup age specified for client ${_BURP_CLIENT}"
                _COUNT=$(( _COUNT + 1 ))
                continue
                ;;
        esac

        # get the most recent burp backup of the client
        # ex.:
        #   Backup: 0000078 2016-11-27 03:39:03 (deletable)
        #   Backup: 0000079 2016-12-04 03:59:04
        _BACKUP_STATS="$(${_BURP_BIN} -a l -C "${_BURP_CLIENT}" 2>>"${HC_STDERR_LOG}" | grep '^Backup' | tail -n 1 | cut -f2- -d':')"
        if [[ -n "${_BACKUP_STATS}" ]]
        then
            _BACKUP_RUN="$(print "${_BACKUP_STATS}" | awk '{print $1}')"
            # output format: YYYYMMDD HHMM
            _BACKUP_DATE=$(print "${_BACKUP_STATS}" | awk '{gsub(/-/,"",$2); gsub(/:/,"",$3); print $2" "substr($3,0,4)}' 2>/dev/null)
            # convert to UNIX seconds
            _CUR_BACKUP_TIME=$(date -d "${_BACKUP_DATE}" '+%s' 2>/dev/null)
        else
            warn "no backup found for client ${_BURP_CLIENT}. Check client impersonation?"
            _COUNT=$(( _COUNT + 1 ))
            continue
        fi

        # get backup warnings
        case "${_BURP_VERSION}" in
            burp-2*)
                # burp v2 does not yet support the 'burp -a S -C <client> -z backup_stats' action
                # so we need to find the backup_stats file ourselves
                # first check client override
                _BURP_BACKUP_DIR=""; _BURP_CLIENTCONF_DIR=""
                _BURP_CLIENTCONF_DIR=$(_CONFIG_FILE="${_BURP_SERVER_CONFIG_FILE}" data_get_lvalue_from_config 'clientconfdir')
                _BURP_CLIENTCONF_DIR=$(data_strip_outer_space "${_BURP_CLIENTCONF_DIR}")
                if [[ -n "${_BURP_CLIENTCONF_DIR}" ]]
                then
                    _BURP_CLIENTCONF_FILE=${_BURP_CLIENTCONF_DIR}/${_BURP_CLIENT}
                    if [[ -r ${_BURP_CLIENTCONF_FILE} ]]
                    then
                        _BURP_BACKUP_DIR=$(_CONFIG_FILE="${_BURP_CLIENTCONF_FILE}" data_get_lvalue_from_config 'directory')
                        _BURP_BACKUP_DIR=$(data_strip_outer_space "${_BURP_BACKUP_DIR}")
                    else
                        warn "no client configuration file for client ${_BURP_CLIENT}, trying server configuration next"
                    fi
                fi
                # check server setting
                if [[ -z "${_BURP_BACKUP_DIR}" ]]
                then
                    _BURP_BACKUP_DIR=$(_CONFIG_FILE="${_BURP_SERVER_CONFIG_FILE}" data_get_lvalue_from_config 'directory')
                    _BURP_BACKUP_DIR=$(data_strip_outer_space "${_BURP_BACKUP_DIR}")
                    if [[ -z "${_BURP_BACKUP_DIR}" ]]
                    then
                        warn "could not determine backup directory from 'clientconfdir' or 'directory' directives' for client ${_BURP_CLIENT}"
                        continue
                    fi
                fi
                if [[ -r "${_BURP_BACKUP_DIR}"/"${_BURP_CLIENT}"/current/log.gz ]]
                then
                    _BACKUP_WARNINGS=$(zcat "${_BURP_BACKUP_DIR}"/"${_BURP_CLIENT}"/current/log.gz 2>/dev/null | grep -c "WARNING:" 2>/dev/null)
                else
                    warn "could not find ${_BURP_BACKUP_DIR}/${_BURP_CLIENT}/current/log.gz"
                    continue
                fi
                ;;
            burp-1*)
                _BACKUP_WARNINGS=$(${_BURP_BIN} -c ${_BURP_SERVER_CONFIG_FILE} -a S -C "${_BURP_CLIENT}" -b "${_BACKUP_RUN}" -z backup_stats 2>>"${HC_STDERR_LOG}" |\
                                    grep '^warnings' 2>/dev/null | cut -f2 -d':' 2>/dev/null)
                ;;
        esac

        if [[ -z "${_BACKUP_WARNINGS}" ]]
        then
            warn "could not get warnings for backup ${_BACKUP_RUN} of client ${_BURP_CLIENT}"
            _COUNT=$(( _COUNT + 1 ))
            continue
        fi

        # check & evaluate the results
        if (( _BACKUP_WARNINGS > _BURP_WARNINGS ))
        then
            _STC=$(( _STC + 1 ))
        fi
        if (( _CUR_BACKUP_TIME < _MIN_BACKUP_TIME ))
        then
            _STC=$(( _STC + 2 ))
        fi

        # report the results
        case ${_STC} in
            0)
                _MSG="backup ${_BACKUP_RUN} of client ${_BURP_CLIENT} is OK"
                ;;
            1)
                _MSG="backup ${_BACKUP_RUN} of client ${_BURP_CLIENT} has too many warnings (${_BACKUP_WARNINGS}>${_BURP_WARNINGS})"
                ;;
            2)
                _MSG="backup ${_BACKUP_RUN} of client ${_BURP_CLIENT} is too old (>${_BURP_AGE})"
                ;;
            3)
                _MSG="backup ${_BACKUP_RUN} of client ${_BURP_CLIENT} is too old (>${_BURP_AGE}) and has too many warnings (${_BACKUP_WARNINGS}>${_BURP_WARNINGS})"
                ;;
            *)
                :
                ;;
        esac
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
        fi
        _COUNT=$(( _COUNT + 1 ))

        # save STDOUT
        if (( _STC > 0 ))
        then
            print "=== ${_BURP_CLIENT}: ${_BACKUP_RUN} ===" >>"${HC_STDOUT_LOG}"
            case "${_BURP_VERSION}" in
                burp-2*)
                    if [[ -r "${_BURP_BACKUP_DIR}"/"${_BURP_CLIENT}"/current/log.gz ]]
                    then
                        zcat "${_BURP_BACKUP_DIR}"/"${_BURP_CLIENT}"/current/log.gz >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
                    fi
                    ;;
                burp-1*)
                    ${_BURP_BIN} -c ${_BURP_SERVER_CONFIG_FILE} -a S -C "${_BURP_CLIENT}" -b "${_BACKUP_RUN}" -z log.gz >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
                    ;;
            esac
        fi
    else
        warn "bad entry in the configuration file ${_CONFIG_FILE} on data line ${_COUNT}"
        _COUNT=$(( _COUNT + 1 ))
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
              and formatted stanzas:
                client:<client_name>:<max_warnings_allowed>:<max_backup_age>(d|h|w)
PURPOSE     : Checks the status and age of saved burp client backups.
              Should only be run only on a burp backup server (supports burp v1 and v2)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
