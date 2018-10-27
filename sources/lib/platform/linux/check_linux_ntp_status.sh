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
# REQUIRES: data_space2comma(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2018-03-20: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR + other small fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
function check_linux_ntp_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _NTPD_INIT_SCRIPT="/etc/init.d/ntpd"
typeset _NTPD_SYSTEMD_SERVICE="ntpd.service"
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _NTPQ_BIN="/usr/sbin/ntpq"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CURR_OFFSET=0
typeset _MAX_OFFSET=0
typeset _NTP_PEER=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
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

#------------------------------------------------------------------------------
# check ntp service
# 1) try using the init ways
linux_get_init
case "${LINUX_INIT}" in
    'systemd')
        systemctl --quiet is-active ${_NTPD_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
        ;;
    'upstart')
        warn "code for upstart managed systems not implemented, NOOP"
        _RC=1
        ;;
    'sysv')
        # check running SysV
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
        ;;
    *)
        _RC=1
        ;;
esac

# 2) try the pgrep way (note: old pgreps do not support '-c')
if (( _RC != 0 ))
then
    (( $(pgrep -u root ntpd 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="ntpd is running"
        ;;
    1)
        _MSG="ntpd is not running"
        ;;
    *)
        _MSG="could not determine status of n"
        ;;
esac
log_hc "$0" ${_STC} "${_MSG}"

#------------------------------------------------------------------------------
# check ntpq results
_STC=0
if [[ ! -x ${_NTPQ_BIN} ]]
then
    warn "${_NTPQ_BIN} is not installed here"
    return 1
else
    ${_NTPQ_BIN} -np 2>>${HC_STDERR_LOG} >>${HC_STDOUT_LOG}
    # RC is always 0
fi

# 1) active server
_NTP_PEER="$(grep -E -e '^\*' 2>/dev/null ${HC_STDOUT_LOG} | awk '{ print $1 }' 2>/dev/null)"
case ${_NTP_PEER} in
    \*127.127.1.0*)
        _MSG="NTP is synchronizing against its internal clock"
        _STC=1
        ;;
    \*[0-9]*)
        # some valid server
        _MSG="NTP is synchronizing against ${_NTP_PEER##*\*}"
        ;;
    *)
        _MSG="NTP is not synchronizing or NTP daemon is not running"
        _STC=1
        ;;
esac
log_hc "$0" ${_STC} "${_MSG}"

# 2) offset value
if (( _STC == 0 ))
then
    _CURR_OFFSET="$(grep -E -e '^\*' 2>/dev/null ${HC_STDOUT_LOG} | awk '{ print $9 }' 2>/dev/null)"
    case ${_CURR_OFFSET} in
        +([-0-9])*(.)*([0-9]))
            # numeric, OK (negatives are OK too!)
            if (( $(awk -v c="${_CURR_OFFSET}" -v m="${_MAX_OFFSET}" 'BEGIN { print (c>m) }' 2>/dev/null) != 0 ))
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

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3
PURPOSE : Checks the status of NTP service & synchronization

EOT

return 0
}


#------------------------------------------------------------------------------
# END of script
#------------------------------------------------------------------------------
