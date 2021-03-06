#!/usr/bin/env ksh
#------------------------------------------------------------------------------
# @(#) check_hpux_ntp_status
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
# @(#) MAIN: check_hpux_ntp_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2016-12-01: initial version [Patrick Van der Veken]
# @(#) 2016-12-29: added threshold & config file [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2018-10-31: added support for --log-healthy [Patrick Van der Veken]
# @(#) 2019-01-10: added configuration option 'ntpq_use_ipv4', fixed problem
# @(#)             with offset calculation [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: Text updates [Patrick Van der Veken]
# @(#) 2020-12-21: fixes for --log-healthy [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
function check_hpux_ntp_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2020-12-21"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
typeset _NTPQ_BIN="/usr/sbin/ntpq"
typeset _NTPQ_OPTS="-pn"
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _CFG_NTPQ_IPV4=""
typeset _LOG_HEALTHY=0
typeset _CURR_OFFSET=0
typeset _MAX_OFFSET=0
typeset _NTP_PEER=""
typeset _CHECK_OFFSET=0

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

# check & get NTP status
if [[ ! -x ${_NTPQ_BIN} ]]
then
    warn "${_NTPQ_BIN} is not installed here"
    return 1
else
    ${_NTPQ_BIN} ${_NTPQ_OPTS} 2>>${HC_STDERR_LOG} >>${HC_STDOUT_LOG}
    # RC is always 0
fi

# evaluate ntpq results
# 1) active server
_NTP_PEER="$(grep -E -e '^\*' 2>/dev/null ${HC_STDOUT_LOG} | awk '{ print $1 }')"
if [[ -z "${_NTP_PEER}" ]]
then
    _MSG="NTP is not synchronizing"
    log_hc "$0" 1 "${_MSG}"
    return 0
fi
case "${_NTP_PEER}" in
    \*127.127.1.0*)
        _MSG="NTP is synchronizing against its internal clock"
        _STC=1
        ;;
    *)
        # some valid server
        _MSG="NTP is synchronizing against ${_NTP_PEER##*\*}"
        ;;
esac
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

# 2) offset value
if (( _STC == 0 ))
then
    _CURR_OFFSET="$(grep -E -e '^\*' 2>/dev/null ${HC_STDOUT_LOG} | awk '{ print $9 }')"
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
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}"
            fi
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
NAME        : $1
VERSION     : $2
CONFIG      : $3 with parameters:
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
