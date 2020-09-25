#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_mysqld_status.sh
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
# @(#) MAIN: check_linux_mysqld_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_list_is_string(), dump_logs(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-10: initial version [Patrick Van der Veken]
# @(#) 2019-03-09: text files [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2020-09-25: fixes around systemctl handling, better error handling,
#                  corrected handling of _DO_MYSQLCHECK, fix non-localhost
#                  process checking [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_mysqld_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _MYSQLD_INIT_SCRIPT="/etc/init.d/mysqld"
typeset _MYSQLD_SYSTEMD_SERVICE="mysqld.service"
typeset _MARIADB_INIT_SCRIPT="/etc/init.d/mariadb"
typeset _MARIADB_SYSTEMD_SERVICE="mariadb.service"
typeset _VERSION="2020-09-25"                           # YYYY-MM-DD
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
typeset _CFG_MYSQL_USER=""
typeset _CFG_MYSQL_PASSWORD=""
typeset _CFG_MYSQL_HOST=""
typeset _CFG_MYSQL_PORT=""
typeset _CFG_EXCLUDE_DATABASES=""
typeset _CFG_EXCLUDE_TABLES=""
typeset _MYSQLADMIN_BIN=""
typeset _DO_MYSQLCHECK=1
typeset _DO_MYSQL_STATS=1
typeset _MYSQLCHECK_BIN=""
typeset _MYSQLCHECK_OPTS=""
typeset _MYSQLSHOW_BIN=""
typeset _MYSQLSHOW_OPTS=""
typeset _MYSQLADMIN_BIN=""
typeset _MYSQLADMIN_OPTS=""
typeset _MYSQL_BIN=""
typeset _MYSQL_DB_LIST=""
typeset _MYSQL_DB=""
typeset _MYSQLCHECK_OUTPUT=""

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
_CFG_DO_CHECK=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_check')
case "${_CFG_DO_CHECK}" in
    yes|YES|Yes)
        _DO_MYSQLCHECK=1
        ;;
    *)
        _DO_MYSQLCHECK=0
        ;;
esac
_CFG_MYSQL_USER=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'mysql_user')
if [[ -z "${_CFG_MYSQL_USER}" ]]
then
    warn "no value for 'mysql_user' specified in ${_CONFIG_FILE}"
    _DO_MYSQLCHECK=0
else
    _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --user=${_CFG_MYSQL_USER}"
    _MYSQLSHOW_OPTS="${_MYSQLSHOW_OPTS} --user=${_CFG_MYSQL_USER}"
    _MYSQLADMIN_OPTS="${_MYSQLADMIN_OPTS} --user=${_CFG_MYSQL_USER}"
fi
_CFG_MYSQL_PASSWORD=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'mysql_password')
if [[ -z "${_CFG_MYSQL_PASSWORD}" ]]
then
    warn "no value for 'mysql_password' specified in ${_CONFIG_FILE}"
    _DO_MYSQLCHECK=0
else
    _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --password=${_CFG_MYSQL_PASSWORD}"
    _MYSQLSHOW_OPTS="${_MYSQLSHOW_OPTS} --password=${_CFG_MYSQL_PASSWORD}"
    _MYSQLADMIN_OPTS="${_MYSQLADMIN_OPTS} --password=${_CFG_MYSQL_PASSWORD}"
fi
_CFG_MYSQL_HOST=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'mysql_host')
if [[ -z "${_CFG_MYSQL_HOST}" ]]
then
    warn "no value for 'mysql_host' specified in ${_CONFIG_FILE}, using localhost"
else
    _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --host=${_CFG_MYSQL_HOST}"
    _MYSQLSHOW_OPTS="${_MYSQLSHOW_OPTS} --host=${_CFG_MYSQL_HOST}"
    _MYSQLADMIN_OPTS="${_MYSQLADMIN_OPTS} --host=${_CFG_MYSQL_HOST}"
fi
_CFG_MYSQL_PORT=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'mysql_port')
if [[ -z "${_CFG_MYSQL_PORT}" ]]
then
    warn "no value for 'mysql_port' specified in ${_CONFIG_FILE}, using 3306"
else
    _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --port=${_CFG_MYSQL_PORT}"
    _MYSQLSHOW_OPTS="${_MYSQLSHOW_OPTS} --port=${_CFG_MYSQL_PORT}"
    _MYSQLADMIN_OPTS="${_MYSQLADMIN_OPTS} --port=${_CFG_MYSQL_PORT}"
fi
_CFG_CHECK_TYPE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_type')
case "${_CFG_CHECK_TYPE}" in
    quick|QUICK|Quick)
        _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --quick"
        ;;
    medium|MEDIUM|Medium)
        _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --medium-check"
        ;;
    extended|EXTENDED|Extended)
        _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --extended"
        ;;
    *)
        _MYSQLCHECK_OPTS="${_MYSQLCHECK_OPTS} --quick"
        ;;
esac
_CFG_CHECK_DATABASES=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_databases')
_CFG_EXCLUDE_DATABASES=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'exclude_databases')
_CFG_EXCLUDE_TABLES=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'exclude_tables')
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

# check mysql
_MYSQL_BIN="$(command -v mysql 2>>${HC_STDERR_LOG})"
if [[ ! -x ${_MYSQL_BIN} || -z "${_MYSQL_BIN}" ]]
then
    warn "MySQL/mariaDB is not installed here"
    return 1
fi

# ---- process state ----
# don't check procs if table check on a non-localhost is requested
if (( _DO_MYSQLCHECK > 0 )) && ( [[ "${_CFG_MYSQL_HOST}" != "localhost" ]] &&
                                 [[ "${_CFG_MYSQL_HOST}" != "127.0.0.1" ]] &&
                                 [[ "${_CFG_MYSQL_HOST}" != "::1" ]] )
then
    warn "skipping process check because parameter 'mysql_host' is to a remote host in the configuration file ${_CONFIG_FILE}"
else
    # 1) try using the init ways
    linux_get_init
    case "${LINUX_INIT}" in
        'systemd')
            # first try mysqld
            _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_MYSQLD_SYSTEMD_SERVICE}")
            if (( _CHECK_SYSTEMD_SERVICE > 0 ))
            then
                (( ARG_DEBUG > 0 )) && debug "doing systemd service check for mysqld"
                systemctl --quiet is-active ${_MYSQLD_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
            fi
            # then try mariadb (also if mysqld check fails which can happen with --is-active when mysqld & mariadb are both enabled)
            if (( _STC > 1 ))
            then
                _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_MARIADB_SYSTEMD_SERVICE}")
                if (( _CHECK_SYSTEMD_SERVICE > 0 ))
                then
                    (( ARG_DEBUG > 0 )) && debug "doing systemd service check for mariadbd"
                    systemctl --quiet is-active ${_MARIADB_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
                else
                    warn "systemd unit file not found {${_MYSQLD_SYSTEMD_SERVICE}}/${_MARIADB_SYSTEMD_SERVICE}}"
                    _RC=1
                fi
            fi
            ;;
        'upstart')
            warn "code for upstart managed systems not implemented, NOOP"
            # fall through to pgrep
            _RC=1
            ;;
        'sysv')
            # first check running mysqld
            if [[ -x ${_MYSQLD_INIT_SCRIPT} ]]
            then
                if (( $(${_MYSQLD_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
                then
                    _STC=1
                fi
            else
                if [[ -x ${_MARIADB_INIT_SCRIPT} ]]
                then
                    if (( $(${_MARIADB_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
                    then
                        _STC=1
                    fi
                else
                    warn "sysv init script not found {${_MYSQLD_INIT_SCRIPT}}/{${_MARIADB_INIT_SCRIPT}}"
                    _RC=1
                fi
            fi
            ;;
        *)
            _RC=1
            ;;
    esac

    # 2) try the pgrep way (note: old pgreps do not support '-c')
    if (( _RC > 0 ))
    then
        (( ARG_DEBUG > 0 )) && debug "doing pgrep check for mysqld"
        (( $(pgrep -u root,mysql mysqld 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
    fi
    if (( _STC > 0 ))
    then
        _STC=0
        (( ARG_DEBUG > 0 )) && debug "doing pgrep check for mariadbd"
        (( $(pgrep -u root,mysql mariadbd 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
    fi

    # evaluate results
    case ${_STC} in
        0)
            _MSG="mysqld/mariadb is running"
            ;;
        1)
            _MSG="mysqld/mariadb is not running"
            ;;
        *)
        _MSG="could not determine status of mysqld/mariadb"
        ;;
    esac
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
fi

# ---- table states (ISAM)----
# check mysqlcheck
_MYSQLCHECK_BIN="$(command -v mysqlcheck 2>>${HC_STDERR_LOG})"
if [[ ! -x ${_MYSQLCHECK_BIN} || -z "${_MYSQLCHECK_BIN}" ]]
then
    warn "could not find {mysqlcheck}, skipping table checks"
    _DO_MYSQLCHECK=0
fi
if (( _DO_MYSQLCHECK > 0 ))
then
    # all databases or given ones? we run mysqlcheck on each database separately
    # to make parsing of the results easier.
    if [[ -z "${_CFG_CHECK_DATABASES}" ]]
    then
        # check mysqlshow
        _MYSQLSHOW_BIN="$(command -v mysqlshow 2>>${HC_STDERR_LOG})"
        if [[ ! -x ${_MYSQLSHOW_BIN} || -z "${_MYSQLSHOW_BIN}" ]]
        then
            warn "could not find {mysqlshow}, skipping table checks"
            return 1
        fi
        # get all databases from mysqlshow
        (( ARG_DEBUG > 0 )) && debug "mysqlshow command: ${_MYSQLSHOW_BIN} ${_MYSQLSHOW_OPTS}"
        _DB_LIST=$(${_MYSQLSHOW_BIN} ${_MYSQLSHOW_OPTS} 2>>${HC_STDERR_LOG})
        if (( $? > 0 )) || [[ -z "${_DB_LIST}" ]]
        then
            _MSG="unable to run command for {${_MYSQLSHOW_BIN}}"
            log_hc "$0" 1 "${_MSG}"
            # dump debug info
            (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
            return 1
        fi
        _DB_LIST=$(print "${_DB_LIST}" | grep -v -E -e '+--' -e 'Databases' 2>/dev/null | awk '{ print $2}' 2>/dev/null)
    else
        _DB_LIST=$(data_comma2newline "${_CFG_CHECK_DATABASES}")
    fi
    # exclude databases
    print "${_DB_LIST}" | while read -r _MYSQL_DB
    do
        data_list_is_string "${_CFG_EXCLUDE_DATABASES}" "${_MYSQL_DB}"
        (( $? == 0 )) && _MYSQL_DB_LIST="${_MYSQL_DB_LIST} ${_MYSQL_DB}"
    done
    if [[ -z "${_MYSQL_DB_LIST}" ]]
    then
        warn "could not execute/parse {mysqlshow} or list of databases to check is empty, skipping table checks"
        return 1
    fi
    (( ARG_DEBUG > 0 )) && debug "database list for mysqlcheck: ${_MYSQL_DB_LIST}"
    # run check
    for _MYSQL_DB in ${_MYSQL_DB_LIST}
    do
        (( ARG_DEBUG > 0 )) && debug "mysqlcheck command: ${_MYSQLCHECK_BIN} ${_MYSQLCHECK_OPTS} --database ${_MYSQL_DB}"
        _MYSQLCHECK_OUTPUT=$(${_MYSQLCHECK_BIN} ${_MYSQLCHECK_OPTS} --database ${_MYSQL_DB} 2>>${HC_STDERR_LOG})
        if (( $? > 0 )) || [[ -z "${_MYSQLCHECK_OUTPUT}" ]]
        then
            _MSG="unable to run command for {${_MYSQLCHECK_BIN} <hidden_opts> --database ${_MYSQL_DB}}"
            log_hc "$0" 1 "${_MSG}"
            # dump debug info
            (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
            continue
        fi
        # verify table states
        print "${_MYSQLCHECK_OUTPUT}" | grep -E -e "^${_MYSQL_DB}\." 2>/dev/null | while read -r _CHECK_LINE
        do
            _MYSQL_TABLE=$(print "${_CHECK_LINE}" | awk '{print $1}' 2>/dev/null)
            data_list_is_string "${_CFG_EXCLUDE_TABLES}" "${_MYSQL_TABLE}"
            if (( $? == 0 ))
            then
                if (( $(print "${_CHECK_LINE}" | grep -c -E -e "^${_MYSQL_TABLE}.*OK$" 2>/dev/null) > 0 ))
                then
                    _MSG="state of table ${_MYSQL_TABLE} is OK"
                    _STC=0
                else
                    _MSG="state of table ${_MYSQL_TABLE} is NOK"
                    _STC=1
                fi
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "excluding table: ${_MYSQL_TABLE}"
            fi
        done
        # add mysqlcheck output to stdout log
        print "==== {${_MYSQLCHECK_BIN} <hidden_opts> --database ${_MYSQL_DB}} ====" >>${HC_STDOUT_LOG}
        print "${_MYSQLCHECK_OUTPUT}" >>${HC_STDOUT_LOG}
    done
fi

# ---- statistics ----
# check mysqladmin
_MYSQLADMIN_BIN="$(command -v mysqladmin 2>>${HC_STDERR_LOG})"
if [[ ! -x ${_MYSQLADMIN_BIN} || -z "${_MYSQLADMIN_BIN}" ]]
then
    warn "could not find {mysqladmin}, skipping statistics gathering"
    _DO_MYSQL_STATS=0
fi
if (( _DO_MYSQL_STATS > 0 ))
then
    (( ARG_DEBUG > 0 )) && debug "mysql command: ${_MYSQLADMIN_BIN} ${_MYSQLADMIN_OPTS}"
    print "==== {${_MYSQLADMIN_BIN} <hidden_opts> extended-status} ====" >>${HC_STDOUT_LOG}
    ${_MYSQLADMIN_BIN} ${_MYSQLADMIN_OPTS} extended-status  >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    if (( $? > 0 ))
    then
        _MSG="unable to run command for {${_MYSQLADMIN_BIN}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        continue
    fi
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
               mysql_user=<mysql_user_account>
               mysql_password=<mysql_user_password>
               mysql_host=<database_host>
               mysql_port=<host_port>
               do_check=<yes|no>
               check_type=<quick|fast|medium|extended>
               check_databases=<list_of_databases>
               exclude_databases=<list_of_databases>
               exclude_tables=<list_of_tables>
               do_stats=<yes|no>
PURPOSE     : Checks the status of mysqld/mariadb & databases/table states. Can also
              gather statistics on mysqld (extended-status) but these are only logged
              when a health check fails.
              MySQL privileges required: SHOW DATABASES, SELECT (global or per database)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
