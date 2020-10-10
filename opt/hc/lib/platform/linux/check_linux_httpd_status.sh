#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_httpd_status.sh
#******************************************************************************
# @(#) Copyright (C) 2017 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_linux_httpd_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), linux_get_init(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-04-23: initial version [Patrick Van der Veken]
# @(#) 2017-05-08: fix fall-back for sysv->pgrep [Patrick Van der Veken]
# @(#) 2017-05-17: removed _MSG dupe [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-11-18: add linux_has_systemd_service() [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2019-11-01: added support for configuration parameters 'check_type' and
# @(#)             'httpd_bin' [Patrick Van der Veken]
# @(#) 2020-10-10: added support for configuration parameters 'httpd_path' and
# @(#)             changed meaning of 'httpd_bin' in order to support debian/ubuntu
# @(#)             distros using the 'apache(2)' binary [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_httpd_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2020-10-10"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _HTTPD_INIT_SCRIPT=""
typeset _HTTPD_SYSTEMD_SERVICE=""
typeset _CHECK_SYSTEMD_SERVICE=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CFG_HTTPD_BIN=""
typeset _HTTPD_BIN=""
typeset _CFG_HTTPD_PATH=""
typeset _HTTPD_PATH=""
typeset _HTTPD_COMMAND=""
typeset _CFG_CHECK_TYPE=""
typeset _DO_PGREP=0
typeset _HTTPD_CHECKER=""
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
_CFG_HTTPD_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'httpd_bin')
if [[ -n "${_CFG_HTTPD_BIN}" ]]
then
    # strip path if full path is used (2019-11-01 version)
    _HTTPD_BIN="$(basename ${_CFG_HTTPD_BIN})"
    log "setting httpd binary to {${_HTTPD_BIN}} (config override)"
fi
_CFG_HTTPD_PATH=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'httpd_path')
if [[ -n "${_CFG_HTTPD_PATH}" ]]
then
    _HTTPD_PATH="${_CFG_HTTPD_PATH}"
    log "setting httpd path to {${_HTTPD_PATH}} (config override)"
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

# check init/systemd settings
case "${_HTTPD_BIN}" in
    apache2)
        typeset _HTTPD_INIT_SCRIPT="/etc/init.d/apache2"
        typeset _HTTPD_SYSTEMD_SERVICE="apache2.service"
        ;;
    apache)
        typeset _HTTPD_INIT_SCRIPT="/etc/init.d/apache"
        typeset _HTTPD_SYSTEMD_SERVICE="apache.service"
        ;;
    *)
        typeset _HTTPD_INIT_SCRIPT="/etc/init.d/httpd"
        typeset _HTTPD_SYSTEMD_SERVICE="apache.httpd"
        ;;
esac
log "setting httpd init script to {${_HTTPD_INIT_SCRIPT}}"
log "setting httpd systemd service to {${_HTTPD_SYSTEMD_SERVICE}}"
# check httpd (if specified)
if [[ -z "${_HTTPD_BIN}" || -z "${_HTTPD_PATH}" ]]
then
    if [[ -z "${_HTTPD_BIN}" ]]
    then
        _HTTPD_COMMAND="$(command -v httpd 2>>${HC_STDERR_LOG})"
    else
        _HTTPD_COMMAND="$(command -v ${_HTTPD_BIN} 2>>${HC_STDERR_LOG})"
    fi
    if [[ -n "${_HTTPD_COMMAND}" ]]
    then
        _HTTPD_BIN="$(basename ${_HTTPD_COMMAND})"
        _HTTPD_PATH="$(dirname ${_HTTPD_COMMAND})"
    fi
fi
if [[ ! -x ${_HTTPD_PATH}/${_HTTPD_BIN} || -z "${_HTTPD_BIN}" || -z "${_HTTPD_PATH}" ]]
then
    warn "httpd (apache) is not installed here"
    return 1
fi

# ---- process state ----
# 1) try using the init ways
if (( _DO_PGREP == 0 ))
then
    [[ -n "${LINUX_INIT}" ]] || linux_get_init
    case "${LINUX_INIT}" in
        'systemd')
            _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_HTTPD_SYSTEMD_SERVICE}")
            if (( _CHECK_SYSTEMD_SERVICE > 0 ))
            then
                systemctl --quiet is-active ${_HTTPD_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
            else
                warn "systemd unit file not found {${_HTTPD_SYSTEMD_SERVICE}}"
                _RC=1
            fi
            ;;
        'upstart')
            warn "code for upstart managed systems not implemented, NOOP"
            _RC=1
            ;;
        'sysv')
            # check running SysV
            if [[ -x ${_HTTPD_INIT_SCRIPT} ]]
            then
                if (( $(${_HTTPD_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
                then
                    _STC=1
                fi
            else
                warn "sysv init script not found {${_HTTPD_INIT_SCRIPT}}"
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
    (( $(pgrep -u root "${_HTTPD_BIN}" 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="${_HTTPD_BIN} is running"
        ;;
    1)
        _MSG="${_HTTPD_BIN} is not running"
        ;;
    *)
        _MSG="could not determine status of ${_HTTPD_BIN}"
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

# ---- config state ----
case "${_HTTPD_BIN}" in
    apache2)
        _HTTPD_CHECKER="$(command -v apache2ctl 2>>${HC_STDERR_LOG})"
        ;;
    apache)
        _HTTPD_CHECKER="$(command -v apachectl 2>>${HC_STDERR_LOG})"
        ;;
    *)
        _HTTPD_CHECKER="${_HTTPD_PATH}/${_HTTPD_BIN}"
        ;;
esac
if [[ -x ${_HTTPD_CHECKER} ]]
then
    ${_HTTPD_CHECKER} -t >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
    if (( $? == 0 ))
    then
        _MSG="${_HTTPD_BIN} configuration files are syntactically correct"
        _STC=0
    else
        _MSG="${_HTTPD_BIN} configuration files have syntax error(s) {${_HTTPD_CHECKER} -t}"
        _STC=1
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
CONFIG      : $3 with parameters:
               log_healthy=<yes|no>
               check_type=<auto|pgrep|sysv|systemd> [compt. >=2019-11-01]
               httpd_bin=<name_of_httpd> [compt. >=2020-10-10]
               httpd_path=<path_to_httpd> [compt. >=2020-10-10]
PURPOSE     : Checks whether httpd (apache service) is running and whether the
              httpd configuration files are syntactically correct
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
