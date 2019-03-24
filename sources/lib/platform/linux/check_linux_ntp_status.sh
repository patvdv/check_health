#!/usr/bin/env ksh
#------------------------------------------------------------------------------
# @(#) check_linux_ntp_status
#------------------------------------------------------------------------------
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
#------------------------------------------------------------------------------
#
# DOCUMENTATION (MAIN)
# -----------------------------------------------------------------------------
# @(#) MAIN: check_linux_ntp_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), init_hc(), log_hc(),
#           linux_has_systemd_service(), warn()
#
# @(#) HISTORY:
# @(#) 2018-03-20: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR + other small fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2018-10-31: added support for chronyd, --dump-logs
# @(#)             & --log-healthy [Patrick Van der Veken]
# @(#) 2018-11-18: add linux_has_systemd_service() [Patrick Van der Veken]
# @(#) 2019-01-10: add optional configuration+cmd-line parameters 'force_ntp' and
# @(#)             'force_chrony', added check on chronyd service alive, added
# @(#)             run user for chronyd+ntpd, added forced IPv4 support for ntpq,
# @(#)             fixed problem with offset calculation [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-24: set dynamic path to client tools [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
function check_linux_ntp_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _CHRONY_INIT_SCRIPT="/etc/init.d/chrony"
typeset _NTPD_INIT_SCRIPT="/etc/init.d/ntpd"
typeset _CHRONYD_SYSTEMD_SERVICE="chronyd.service"
typeset _NTPD_SYSTEMD_SERVICE="ntpd.service"
typeset _CHRONYD_USER="chrony"
typeset _NTPD_USER="ntp"
typeset _VERSION="2019-03-24"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _NTPQ_OPTS="-pn"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_FORCE_CHRONY=""
typeset _CFG_FORCE_NTP=""
typeset _CFG_NTPQ_IPV4=""
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CHECK_SYSTEMD_SERVICE=0
typeset _CURR_OFFSET=0
typeset _MAX_OFFSET=0
typeset _NTP_PEER=""
typeset _CHECK_OFFSET=0
typeset _USE_CHRONYD=0
typeset _USE_NTPD=0
typeset _CHRONYC_BIN=""
typeset _NTPQ_BIN=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
        force_chrony)
            log "forcing chrony since force_chrony was used"
            _USE_CHRONYD=1
            ;;
        force_ntp)
            log "forcing ntp since force_ntp was used"
            _USE_NTPD=1
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
_MAX_OFFSET=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'max_offset')
if [[ -z "${_MAX_OFFSET}" ]]
then
    # default
    _MAX_OFFSET=500
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
_CFG_FORCE_CHRONY=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'force_chrony')
case "${_CFG_FORCE_CHRONY}" in
    yes|YES|Yes)
        log "forcing chrony since force_chrony was set"
        _USE_CHRONYD=1
        ;;
    *)
        :   # not set
        ;;
esac
# force_ntp (optional)
_CFG_FORCE_NTP=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'force_ntp')
case "${_CFG_FORCE_NTP}" in
    yes|YES|Yes)
        log "forcing ntp since force_ntp was set"
        _USE_NTPD=1
        ;;
    *)
        :   # not set
        ;;
esac
_CFG_NTPQ_IPV4=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'ntpq_use_ipv4')
case "${_CFG_NTPQ_IPV4}" in
    yes|YES|Yes)
        log "forcing ntpq to use IPv4"
        _NTPQ_OPTS="${_NTPQ_OPTS}4"
        ;;
    *)
        :   # not set
        ;;
esac
if (( _USE_CHRONYD > 0 && _USE_NTPD > 0 ))
then
    warn "you cannot force chrony and ntp at the same time"
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

#------------------------------------------------------------------------------
# check for client tools
_CHRONYC_BIN="$(command -v chronyc 2>>${HC_STDERR_LOG})"


_NTPQ_BIN="$(command -v ntpq 2>>${HC_STDERR_LOG})"


#------------------------------------------------------------------------------
# chronyd (prefer) or ntpd (fallback)
# but do not check if _USE_CHRONYD or _USE_NTPD is already set
if (( _USE_CHRONYD == 0 && _USE_NTPD == 0 ))
then
    linux_get_init
    _CHRONYC_BIN="$(command -v chronyc 2>>${HC_STDERR_LOG})"
    if [[ -n "${_CHRONYC_BIN}" && -x ${_CHRONYC_BIN} ]]
    then
        # check that chrony is actually enabled
        (( ARG_DEBUG > 0 )) && debug "found ${_CHRONYC_BIN}, checking if the service is enabled"
        case "${LINUX_INIT}" in
            'systemd')
                _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_CHRONYD_SYSTEMD_SERVICE}")
                if (( _CHECK_SYSTEMD_SERVICE > 0 ))
                then
                    systemctl --quiet is-enabled ${_CHRONYD_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} && _USE_CHRONYD=1
                else
                    warn "systemd unit file not found {${_CHRONYD_SYSTEMD_SERVICE}}"
                    _USE_CHRONYD=0
                fi
                ;;
            'sysv')
                chkconfig chronyd >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
                if (( $? == 0 ))
                then
                    _USE_CHRONYD=1
                else
                    _USE_CHRONYD=0
                fi
                ;;
            *)
                _USE_CHRONYD=0
                ;;
        esac
        (( ARG_DEBUG > 0 )) && debug "chronyd service state: ${_USE_CHRONYD}"
    fi
    _NTPQ_BIN="$(command -v ntpq 2>>${HC_STDERR_LOG})"
    if (( _USE_CHRONYD == 0 )) && [[ -n "${_NTPQ_BIN}" && -x ${_NTPQ_BIN} ]]
    then
        # shellcheck disable=SC2034
        _USE_NTPD=1
        (( ARG_DEBUG > 0 )) && debug "ntpd service state: ${_USE_NTPD}"
    fi
    if (( _USE_CHRONYD == 0 && _USE_NTPD == 0 ))
    then
        _MSG="unable to find chronyd or ntpd (or they are not enabled)"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi
fi

#------------------------------------------------------------------------------
# check ntp service
# 1) try using the init ways
linux_get_init
case "${LINUX_INIT}" in
    'systemd')
        if (( _USE_CHRONYD > 0 ))
        then
            _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_CHRONYD_SYSTEMD_SERVICE}")
            if (( _CHECK_SYSTEMD_SERVICE > 0 ))
            then
                systemctl --quiet is-active ${_CHRONYD_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
            else
                warn "systemd unit file not found {${_CHRONYD_SYSTEMD_SERVICE}}"
                _RC=1
            fi
        else
            _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_NTPD_SYSTEMD_SERVICE}")
            if (( _CHECK_SYSTEMD_SERVICE > 0 ))
            then
                systemctl --quiet is-active ${_NTPD_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
            else
                warn "systemd unit file not found {${_NTPD_SYSTEMD_SERVICE}}"
                _RC=1
            fi
        fi
        ;;
    'upstart')
        warn "code for upstart managed systems not implemented, NOOP"
        _RC=1
        ;;
    'sysv')
        # check running SysV
        if (( _USE_CHRONYD > 0 ))
        then
            if [[ -x ${_CHRONY_INIT_SCRIPT} ]]
            then
                if (( $(${_CHRONY_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
                then
                    _STC=1
                fi
            else
                warn "sysv init script not found {${_NTPD_INIT_SCRIPT}}"
                _RC=1
            fi
        else
            if [[ -x ${_NTPD_INIT_SCRIPT} ]]
            then
                if (( $(${_NTPD_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
                then
                    _STC=1
                fi
            else
                warn "sysv init script not found {${_NTPD_INIT_SCRIPT}}"
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
    if (( _USE_CHRONYD > 0 ))
    then
        (( $(pgrep -u "${_CHRONYD_USER}" 'chronyd' 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
    else
        (( $(pgrep -u "${_NTPD_USER}" 'ntpd' 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
    fi
fi

# evaluate results
case ${_STC} in
    0)
        if (( _USE_CHRONYD > 0 ))
        then
            _MSG="chronyd is running"
        else
            _MSG="ntpd is running"
        fi
        ;;
    1)
        if (( _USE_CHRONYD > 0 ))
        then
            _MSG="chronyd is not running"
        else
            _MSG="ntpd is not running"
        fi
        ;;
    *)
        if (( _USE_CHRONYD > 0 ))
        then
            _MSG="could not determine status of chronyd"
        else
            _MSG="could not determine status of ntpd"
        fi
        ;;
esac
log_hc "$0" ${_STC} "${_MSG}"

#------------------------------------------------------------------------------
# check chronyc/ntpq results
_STC=0
if (( _USE_CHRONYD > 0 ))
then
    ${_CHRONYC_BIN} -nc sources 2>>${HC_STDERR_LOG} >>${HC_STDOUT_LOG}
    if (( $? > 0 ))
    then
        _MSG="unable to execute {${_CHRONYC_BIN}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi

    # 1) active server
    _CHRONY_PEER="$(grep -E -e '^\^,\*' 2>/dev/null ${HC_STDOUT_LOG} | cut -f3 -d',' 2>/dev/null)"
    if [[ -z "${_CHRONY_PEER}" ]]
    then
        _MSG="chrony is not synchronizing"
        log_hc "$0" 1 "${_MSG}"
        return 0
    fi
    case ${_CHRONY_PEER} in
        \*127.127.1.0*)
            _MSG="chrony is synchronizing against its internal clock"
            _STC=1
            ;;
        *)
            # some valid server
            _MSG="chrony is synchronizing against ${_CHRONY_PEER}"
            ;;
    esac
    log_hc "$0" ${_STC} "${_MSG}"

    # 2) offset value
    if (( _STC == 0 ))
    then
        _CURR_OFFSET="$(grep -E -e '^\^,\*' 2>/dev/null ${HC_STDOUT_LOG} | cut -f9 -d',' 2>/dev/null)"
        # convert from us to ms
        case ${_CURR_OFFSET} in
            +([-0-9])*(.)*([0-9]))
                # numeric, OK (negatives are OK too!)
                # convert from us to ms
                _CURR_OFFSET=$(print -R "${_CURR_OFFSET} * 1000" | bc 2>/dev/null)
                if (( $? > 0 )) || [[ -z "${_CURR_OFFSET}" ]]
                then
                    :
                fi
                # force awk into casting c as a float
                _CHECK_OFFSET=$(awk -v c="${_CURR_OFFSET}" -v m="${_MAX_OFFSET}" 'BEGIN { sub (/^-/, "", c); print ((c+0.0)>m) }' 2>/dev/null)
                if (( _CHECK_OFFSET > 0 ))
                then
                    _MSG="NTP offset of ${_CURR_OFFSET} is bigger than the configured maximum of ${_MAX_OFFSET}"
                    _STC=1
                else
                    _MSG="NTP offset of ${_CURR_OFFSET} is within the acceptable range"
                fi
                log_hc "$0" ${_STC} "${_MSG}"
                ;;
            *)
                # not numeric
                warn "invalid offset value of ${_CURR_OFFSET} found for ${_NTP_PEER}?"
                return 1
                ;;
        esac
    fi

else
    ${_NTPQ_BIN} ${_NTPQ_OPTS} 2>>${HC_STDERR_LOG} >>${HC_STDOUT_LOG}
    # RC is always 0

    # 1) active server
    _NTP_PEER="$(grep -E -e '^\*' 2>/dev/null ${HC_STDOUT_LOG} | awk '{ print $1 }' 2>/dev/null)"
    if [[ -z "${_NTP_PEER}" ]]
    then
        _MSG="NTP is not synchronizing"
        log_hc "$0" 1 "${_MSG}"
        return 0
    fi
    case ${_NTP_PEER} in
        \*127.127.1.0*)
            _MSG="NTP is synchronizing against its internal clock"
            _STC=1
            ;;
        *)
            # some valid server
            _MSG="NTP is synchronizing against ${_NTP_PEER##*\*}"
            ;;
    esac
    log_hc "$0" ${_STC} "${_MSG}"

    # 2) offset value
    if (( _STC == 0 ))
    then
        _CURR_OFFSET="$(grep -E -e '^\*' 2>/dev/null ${HC_STDOUT_LOG} | awk '{ print $9 }' 2>/dev/null)"
        case ${_CURR_OFFSET} in
            +([-0-9])*(.)*([0-9]))
                # numeric, OK (negatives are OK, force awk into casting c as a float)
                _CHECK_OFFSET=$(awk -v c="${_CURR_OFFSET}" -v m="${_MAX_OFFSET}" 'BEGIN { sub (/^-/, "", c); print ((c+0.0)>m) }' 2>/dev/null)
                if (( _CHECK_OFFSET > 0 ))
                then
                    _MSG="NTP offset of ${_CURR_OFFSET} is bigger than the configured maximum of ${_MAX_OFFSET}"
                    _STC=1
                else
                    _MSG="NTP offset of ${_CURR_OFFSET} is within the acceptable range"
                fi
                log_hc "$0" ${_STC} "${_MSG}"
                ;;
            *)
                # not numeric
                warn "invalid offset value of ${_CURR_OFFSET} found for ${_NTP_PEER}?"
                return 1
                ;;
        esac
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
CONFIG      : $3 with:
               log_healthy=<yes|no>
               max_offset=<max_offset (ms)>
               force_chrony=<yes|no>
               force_ntp=<yes|no>
               ntpq_use_ipv4=<yes|no>
EXTRA OPTS  : --hc-args=force_chrony, --hc-args=force_ntp
PURPOSE     : Checks the status of NTP service & synchronization.
                Supports chronyd & ntpd.
                Assumes chronyd is the preferred time synchronization.
LOG HEALTHY : Supported

EOT

return 0
}


#------------------------------------------------------------------------------
# END of script
#------------------------------------------------------------------------------
