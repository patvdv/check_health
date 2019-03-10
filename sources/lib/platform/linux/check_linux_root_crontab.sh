#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_root_crontab
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
#*******************************************************************************
#
# DOCUMENTATION (MAIN)
# -----------------------------------------------------------------------------
# @(#) MAIN: check_linux_root_crontab
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2013-09-19: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: changed format of stanzas in configuration file &
# @(#)             added support for --log-healthy [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_root_crontab
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
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
typeset _CRON_LINE=""
typeset _CRON_ENTRY=""
typeset _CRON_MATCH=0
typeset _IS_OLD_STYLE=0

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
_IS_OLD_STYLE=$(grep -c -E -e "^cron:" ${_CONFIG_FILE} 2>/dev/null)
if (( _IS_OLD_STYLE == 0 ))
then
    warn "no 'cron:' stanza(s) found in ${_CONFIG_FILE}; possibly an old-style configuration?"
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

# collect data, since Linux can have multiple cron sources we will
# squash them all together, standard cron, vixie, anacron, you name it :)
print "=== crontab -l ===" >>${HC_STDOUT_LOG}
crontab -l >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
print "=== /etc/crontab ===" >>${HC_STDOUT_LOG}
[[ -s /etc/crontab ]] && cat /etc/crontab >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
print "=== /etc/cron.(hourly|daily|weekly|monthly) ===" >>${HC_STDOUT_LOG}
[[ -d /etc/cron.hourly ]] && cat /etc/cron.hourly/* \
    >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
[[ -d /etc/cron.daily ]] && cat /etc/cron.daily/* \
    >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
[[ -d /etc/cron.weekly ]] && cat /etc/cron.weekly/* \
    >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
[[ -d /etc/cron.monthly ]] && cat /etc/cron.monthly/* \
    >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
print "=== /etc/cron.d ===" >>${HC_STDOUT_LOG}
if [[ -d /etc/cron.d ]]
then
    cat /etc/cron.d/* 2>/dev/null | while read _CRON_LINE
    do
        if [[ $(print "${_CRON_LINE}" | awk '{print $6}' 2>/dev/null) == "root" ]]
        then
            print "${_CRON_LINE}" >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
        fi
    done
fi

# perform check
grep -E -e "^cron:" ${_CONFIG_FILE} 2>/dev/null  | while IFS=":" read -r _ _CRON_ENTRY
do
    _CRON_MATCH=$(grep -v '^#' ${HC_STDOUT_LOG} 2>/dev/null |\
        grep -c -E -e "${_CRON_ENTRY}" 2>/dev/null)
    case ${_CRON_MATCH} in
        0)
            _MSG="'${_CRON_ENTRY}' is not configured in cron"
            _STC=1
            ;;
        1)
            _MSG="'${_CRON_ENTRY}' is configured in cron"
            ;;
        +([0-9])*([0-9]))
            _MSG="'${_CRON_ENTRY}' is configured multiple times in cron"
            ;;
    esac

    # report result
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    _STC=0
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
                cron:<cron_entry>
PURPOSE     : Checks the content of the 'root' user crontab for required entries
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
