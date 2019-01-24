#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_postfix_status.sh
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
# @(#) MAIN: check_linux_postfix_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), linux_get_init(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2016-12-01: initial version [Patrick Van der Veken]
# @(#) 2017-05-08: suppress errors on postfix call + fix fall-back
# @(#)             for sysv->pgrep[Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-11-18: add linux_has_systemd_service() [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_postfix_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _POSTFIX_INIT_SCRIPT="/etc/init.d/postfix"
typeset _POSTFIX_SYSTEMD_SERVICE="postfix.service"
typeset _VERSION="2019-01-24"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _POSTFIX_BIN=""
typeset _MSG=""
typeset _STC=0
typeset _RC=0
typeset _CHECK_SYSTEMD_SERVICE=0

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
    esac
done

# 1) try using the init ways
linux_get_init
case "${LINUX_INIT}" in
    'systemd')
        _CHECK_SYSTEMD_SERVICE=$(linux_has_systemd_service "${_POSTFIX_SYSTEMD_SERVICE}")
        if (( _CHECK_SYSTEMD_SERVICE > 0 ))
        then
            systemctl --quiet is-active ${_POSTFIX_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
        else
            warn "systemd unit file not found {${_POSTFIX_SYSTEMD_SERVICE}}"
            _RC=1
        fi
        ;;
    'upstart')
        warn "code for upstart managed systems not implemented, NOOP"
        _RC=1
        ;;
    'sysv')
        # check running SysV
        if [[ -x ${_POSTFIX_INIT_SCRIPT} ]]
        then
            if (( $(${_POSTFIX_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
            then
                _STC=1
            fi
        else
            warn "sysv init script not found {${_POSTFIX_INIT_SCRIPT}}"
            _RC=1
        fi
        ;;
    *)
        _RC=1
        ;;
esac

# 2) try the postfix way
if (( _RC > 0 ))
then
    _POSTFIX_BIN="$(which postfix 2>>${HC_STDERR_LOG})"
    if [[ -x ${_POSTFIX_BIN} && -n "${_POSTFIX_BIN}" ]]
    then
        if (( $(${_POSTFIX_BIN} status 2>>${HC_STDERR_LOG} | grep -c -i 'is running' 2>/dev/null) == 0 ))
        then
            _STC=1
        fi
    else
        warn "postfix is not installed here"
        return 1
    fi
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="postfix is running"
        ;;
    1)
        _MSG="postfix is not running"
        ;;
    *)
        _MSG="could not determine status of postfix"
        ;;
esac
log_hc "$0" ${_STC} "${_MSG}"

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3
PURPOSE : Checks whether postfix (mail system) is running

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
