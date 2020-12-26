#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_dovecot_status.sh
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
# @(#) MAIN: check_linux_dovecot_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), linux_get_init(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2020-12-27: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_dovecot_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _DOVECOT_INIT_SCRIPT="/etc/init.d/dovecot"
typeset _DOVECOT_SYSTEMD_SERVICE="dovecot.service"
typeset _VERSION="2020-12-27"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _DOVECOT_BIN=""
typeset _DOVECOT_CHECKER=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0
typeset _RC=0
typeset _CHECK_SYSTEMD_SERVICE=0

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage "$0" "${_VERSION}" "${_CONFIG_FILE}" && return 0
            ;;
    esac
done

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
# process state

# 1) try using the init ways
linux_get_init
case "${LINUX_INIT}" in
    'systemd')
        # Debian8/Ubuntu16 do not correctly report a unit file for dovecot,
        # do not check for it and instead just query systemd service
        linux_get_distro
        if [[ "${LINUX_DISTRO}" = "Debian" ]] && (( ${LINUX_RELEASE%%.*} < 9 ))
        then
            _CHECK_SYSTEMD_SERVICE=1
        elif [[ "${LINUX_DISTRO}" = "Ubuntu" ]] && (( ${LINUX_RELEASE%%.*} < 17 ))
        then
            _CHECK_SYSTEMD_SERVICE=1
        else
            _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_DOVECOT_SYSTEMD_SERVICE}")
        fi
        if (( _CHECK_SYSTEMD_SERVICE > 0 ))
        then
            systemctl --quiet is-active ${_DOVECOT_SYSTEMD_SERVICE} 2>>"${HC_STDERR_LOG}" || _STC=1
        else
            warn "systemd unit file not found {${_DOVECOT_SYSTEMD_SERVICE}}"
            _RC=1
        fi
        ;;
    'upstart')
        warn "code for upstart managed systems not implemented, NOOP"
        _RC=1
        ;;
    'sysv')
        # check running SysV
        if [[ -x ${_DOVECOT_INIT_SCRIPT} ]]
        then
            if (( $(${_DOVECOT_INIT_SCRIPT} status 2>>"${HC_STDERR_LOG}" | grep -c -i 'is running' 2>/dev/null) == 0 ))
            then
                _STC=1
            fi
        else
            warn "sysv init script not found {${_DOVECOT_INIT_SCRIPT}}"
            _RC=1
        fi
        ;;
    *)
        _RC=1
        ;;
esac

# 2) try the dovecot way
if (( _RC > 0 ))
then
    _DOVECOT_BIN="$(command -v dovecot 2>>${HC_STDERR_LOG})"
    if [[ -x ${_DOVECOT_BIN} && -n "${_DOVECOT_BIN}" ]]
    then
        if (( $(${_DOVECOT_BIN} status 2>>"${HC_STDERR_LOG}" | grep -c -i 'is running' 2>/dev/null) == 0 ))
        then
            _RC=1
        fi
    else
        warn "dovecot is not installed here"
        return 1
    fi
fi

# 3) try the pgrep way (note: old pgreps do not support '-c')
if (( _RC > 0 ))
then
    (( $(pgrep -u dovecot 2>>"${HC_STDERR_LOG}" | wc -l 2>/dev/null) == 0 )) && _STC=1
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="dovecot is running"
        ;;
    1)
        _MSG="dovecot is not running"
        ;;
    *)
        _MSG="could not determine status of dovecot"
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

#-------------------------------------------------------------------------------
# configuration state
_DOVECOT_CHECKER="$(command -v doveconf 2>>${HC_STDERR_LOG})"
if [[ -x ${_DOVECOT_CHECKER} && -n "${_DOVECOT_CHECKER}" ]]
then
    # dump configuration
    ${_DOVECOT_CHECKER} -n >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        _MSG="dovecot configuration files have syntax error(s) {${_DOVECOT_CHECKER} -n}"
        _STC=1
    else
        _MSG="dovecot configuration files are syntactically correct"
        _STC=0
    fi
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
else
    warn "skipping syntax check (unable to find syntax check tool)"
fi

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
PURPOSE     : Checks whether dovecot (mail system) is running and whether the
              dovecot configuration files are syntactically correct
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
