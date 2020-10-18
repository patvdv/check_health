#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_fail2ban_status.sh
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
# @(#) MAIN: check_linux_fail2ban_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2newline(), data_comma2space(), linux_get_init(), init_hc(),
#           log(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2020-10-18: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_fail2ban_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _FAIL2BAN_INIT_SCRIPT="/etc/init.d/fail2ban"
typeset _FAIL2BAN_SYSTEMD_SERVICE="fail2ban.service"
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2020-10-18"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CHECK_SYSTEMD_SERVICE=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CFG_CHECK_JAILS=""
typeset _CFG_CHECK_TYPE=""
typeset _DO_PGREP=0
typeset _DO_CHECK_JAIL=1
typeset _CHECK_JAIL=""
typeset _JAIL_OUTPUT=""
typeset _FAILED_NUM=0
typeset _BANNED_NUM=0
typeset _RC=0

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
_CFG_CHECK_TYPE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_type')
case "${_CFG_CHECK_TYPE}" in
    pgrep|Pgrep|PGREP)
        _DO_PGREP=1
        log "using pgrep process check (config override)"
        ;;
    sysv|Sysv|SYSV)
        LINUX_INIT="sysv"
        log "using init based process check (config override)"
        ;;
    systemd|Systemd|SYSTEMD)
        LINUX_INIT="systemd"
        log "using systemd based process check (config override)"
        ;;
    *)
        # no overrides
        :
        ;;
esac
_CFG_CHECK_JAILS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_jails')
if [[ -n "${_CFG_CHECK_JAILS}" ]]
then
    log "setting jail list to ${_CFG_CHECK_JAILS}"
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

# check fail2ban-server
_FAIL2BAN_BIN="$(command -v fail2ban-server 2>>${HC_STDERR_LOG})"
if [[ -x ${_FAIL2BAN_BIN} && -n "${_FAIL2BAN_BIN}" ]]
then
    log "fail2ban (server) is installed at {${_FAIL2BAN_BIN}}"
else
    warn "fail2ban (server) is not installed here"
    return 1
fi

# ---- process state ----
# 1) try using the init ways
if (( _DO_PGREP == 0 ))
then
    [[ -n "${LINUX_INIT}" ]] || linux_get_init
    case "${LINUX_INIT}" in
        'systemd')
            _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_FAIL2BAN_SYSTEMD_SERVICE}")
            if (( _CHECK_SYSTEMD_SERVICE > 0 ))
            then
                systemctl --quiet is-active ${_FAIL2BAN_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
            else
                warn "systemd unit file not found {${_FAIL2BAN_SYSTEMD_SERVICE}}"
                _RC=1
            fi
            ;;
        'upstart')
            warn "code for upstart managed systems not implemented, NOOP"
            _RC=1
            ;;
        'sysv')
            # check running SysV
            if [[ -x ${_FAIL2BAN_INIT_SCRIPT} ]]
            then
                if (( $(${_FAIL2BAN_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
                then
                    _STC=1
                fi
            else
                warn "sysv init script not found {${_FAIL2BAN_INIT_SCRIPT}}"
                _RC=1
            fi
            ;;
        *)
            _RC=1
            ;;
    esac
fi

# 2) try the pgrep way (note: old pgreps do not support '-c')
if (( _DO_PGREP > 0 || _RC > 0 ))
then
    (( $(pgrep --full -u root "python.*${_FAIL2BAN_BIN}" 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="${_FAIL2BAN_BIN} is running"
        ;;
    1)
        _MSG="${_FAIL2BAN_BIN} is not running"
        _DO_CHECK_JAIL=0
        ;;
    *)
        _MSG="could not determine status of ${_FAIL2BAN_BIN}"
        _DO_CHECK_JAIL=0
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

# ---- jail states ----
if (( _DO_CHECK_JAIL == 0 ))
then
    warn "fail2ban (server) is not running, skipping jail checks"
    return 0
fi
_FAIL2BAN_BIN="$(command -v fail2ban-client 2>>${HC_STDERR_LOG})"
if [[ -x ${_FAIL2BAN_BIN} && -n "${_FAIL2BAN_BIN}" ]]
then
    log "fail2ban (client) is installed at {${_FAIL2BAN_BIN}}"
else
    warn "fail2ban (client) is not installed here, skipping jail checks"
    return 1
fi
print "$(data_comma2newline ${_CFG_CHECK_JAILS})" | while read -r _CHECK_JAIL
do
    _FAILED_NUM=0
    _BANNED_NUM=0
    _JAIL_OUTPUT=$(${_FAIL2BAN_BIN} status ${_CHECK_JAIL} 2>>${HC_STDERR_LOG})
    if (( $? > 0 ))
    then
        _MSG="state of jail ${_CHECK_JAIL} is NOK"
        _STC=1
    else
        _FAILED_NUM=$(print "${_JAIL_OUTPUT}" | grep -i 'currently failed' 2>/dev/null | awk -F':' '{ gsub(/[[:space:]]/,"",$2); print $2 }')
        _BANNED_NUM=$(print "${_JAIL_OUTPUT}" | grep -i 'currently banned' 2>/dev/null | awk -F':' '{ gsub(/[[:space:]]/,"",$2); print $2 }')
        _MSG="state of jail ${_CHECK_JAIL} is OK [failed=${_FAILED_NUM}/banned=${_BANNED_NUM}]"
        _STC=0
    fi
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        # report only number of banned if OK
        log_hc "$0" ${_STC} "${_MSG}" ${_BANNED_NUM} ${_BANNED_NUM}
    fi
    # add jail output to STDOUT
    print "==== {${_FAIL2BAN_BIN} status ${_CHECK_JAIL}} ====" >>${HC_STDOUT_LOG}
    print "${_JAIL_OUTPUT}" >>${HC_STDOUT_LOG}
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
               check_type=<auto|pgrep|sysv|systemd>
               check_jails=<list_of_jails>
PURPOSE     : Checks whether fail2ban (server service) is running and the state
              of the configured jails.
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
