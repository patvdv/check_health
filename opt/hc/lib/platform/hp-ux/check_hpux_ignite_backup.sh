#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_ignite_backup.sh
#******************************************************************************
# @(#) Copyright (C) 2014 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_ignite_backup
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2013-05-28: initial version [Patrick Van der Veken]
# @(#) 2016-05-26: added a simple exclusion list for hosts as configurable
# @(#)             parameter [Patrick Van der Veken]
# @(#) 2016-06-03: small fix [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-01-31: improve discovery routine + add log_healthy [Patrick Van der Veken]
# @(#) 2019-03-09: text updates [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_ignite_backup
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
# backup DONE identifier
typeset _IGNITE_NEEDLE="^DONE"
typeset _IGNITE_SERVER_FILE="/var/opt/ignite/server/ignite.defs"
typeset _IGNITE_CLIENTS_DIR="/var/opt/ignite/clients"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}"  "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _BACKUP_AGE=0
typeset _EXCLUDE_HOSTS=""
typeset _IGNITE_HOST=""
typeset _IGNITE_LOG=""
typeset _IGNITE_STATUS=""
typeset _COUNT=0
typeset _OLD_PWD=""

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
# read required configuration values
_BACKUP_AGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'backup_age')
case "${_BACKUP_AGE}" in
    +([0-9])*(.)*([0-9]))
        # numeric, OK
        ;;
    *)
        # not numeric, set default
        _BACKUP_AGE=14
        ;;
esac
log "backup age to check: ${_BACKUP_AGE} days"
_EXCLUDE_HOSTS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'exclude_hosts')
[[ -n "${_EXCLUDE_HOSTS}" ]] && log "excluding hosts: $(print ${_EXCLUDE_HOSTS})"
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

# check if this host is an Ignite-UX server
if [[ ! -f ${_IGNITE_SERVER_FILE} ]]
then
    warn "host is not an Ignite-UX server"
    return 1
fi

# perform check on Ignite 'client_status' files
if [[ -d ${_IGNITE_CLIENTS_DIR} ]]
then
    _OLD_PWD="$(pwd)"
    # shellcheck disable=SC2164
    cd ${_IGNITE_CLIENTS_DIR}
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
      warn "unable to run command: {cd ${_IGNITE_CLIENTS_DIR}}"
      # dump debug info
      (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
      return 1
    fi

    # check backup states
    find -- * -prune -type l 2>/dev/null | while read -r _IGNITE_HOST
    do
        # check exclude
        [[ "${_EXCLUDE_HOSTS#*${_IGNITE_HOST}}" != "${_EXCLUDE_HOSTS}" ]] && continue
        _IGNITE_LOG="${_IGNITE_HOST}/recovery/client_status"
        if [[ -r "${_IGNITE_LOG}" ]]
        then
            # read status from log file
            _IGNITE_STATUS=$(grep -E -e "${_IGNITE_NEEDLE}" ${_IGNITE_LOG} 2>/dev/null)
            case "${_IGNITE_STATUS}" in
                *Complete*)
                    _MSG="ignite backup status for ${_IGNITE_HOST}: completed successfully"
                    ;;
                *Warning*)
                    _MSG="ignite backup status for ${_IGNITE_HOST}: completed with warnings"
                    # save log
                    print "=== ${_IGNITE_HOST} ===" >>${HC_STDOUT_LOG}
                    cat ${_IGNITE_LOG} >>${HC_STDOUT_LOG}
                    ;;
                *Error*)
                    _MSG="ignite backup status for ${_IGNITE_HOST}: failed"
                    _STC=1
                    # save log
                    print "=== ${_IGNITE_HOST} ===" >>${HC_STDOUT_LOG}
                    cat ${_IGNITE_LOG} >>${HC_STDOUT_LOG}
                    ;;
                *)
                    _MSG="ignite backup status for ${_IGNITE_HOST}: failed"
                    _STC=1
                    # save log
                    print "=== ${_IGNITE_HOST} ===" >>${HC_STDOUT_LOG}
                    cat ${_IGNITE_LOG} >>${HC_STDOUT_LOG}
                    ;;
            esac
        else
            _MSG="ignite backup status for ${_IGNITE_HOST}: unknown"
            _STC=1
        fi

        # handle unit result
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
            _STC=0
        fi
    done

    # check backup ages
    find -- * -prune -type l 2>/dev/null | while read -r _IGNITE_HOST
    do
        # check exclude
        [[ "${_EXCLUDE_HOSTS#*${_IGNITE_HOST}}" != "${_EXCLUDE_HOSTS}" ]] && continue
        _IGNITE_LOG="${_IGNITE_HOST}/recovery/client_status"
        if [[ -r "${_IGNITE_LOG}" ]]
        then
            _COUNT=$(find "${_IGNITE_LOG}" -mtime +${_BACKUP_AGE} | wc -l)
            if (( _COUNT == 0 ))
            then
                _MSG="ignite backup age for ${_IGNITE_HOST}: <=${_BACKUP_AGE} days"
                _STC=0
            else
                _MSG="ignite backup age for ${_IGNITE_HOST}: >${_BACKUP_AGE} days"
                _STC=1
                print "=== ${_IGNITE_HOST} ===" >>${HC_STDOUT_LOG}
                print "age: $(ls -l ${_IGNITE_LOG})" >>${HC_STDOUT_LOG}
            fi
        else
            _MSG="ignite backup age for ${_IGNITE_HOST}: unknown"
            _STC=1
        fi

        # handle unit result
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
            _STC=0
        fi
    done

    # shellcheck disable=SC2164
    cd "${_OLD_PWD}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
      _MSG="unable to run command: {cd ${_IGNITE_CLIENTS_DIR}}"
      log_hc "$0" 1 "${_MSG}"
      # dump debug info
      (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
      return 1
    fi
else
    warn "could not access/find the Ignite-UX's clients directory at ${_IGNITE_CLIENTS_DIR}"
    return 1
fi

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
                backup_age=<days_till_last_backup>
                exclude_hosts=<list_of_hosts>
PURPOSE     : Checks the state and age of saved Ignite-UX client backups (should only be
              run only on the Ignite-UX server). Backups with warnings are considered
              to OK. Backups older than \$backup_age will not pass the health check.
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
