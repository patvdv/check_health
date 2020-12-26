#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_postfix_status.sh
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
# @(#) MAIN: check_hpux_postfix_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2016-12-01: initial version [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# @(#) 2019-03-16: replace 'which' [Patrick Van der Veken]
# @(#) 2020-12-27: add configuration check + quoting fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_postfix_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2020-12-27"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _POSTFIX_BIN=""
typeset _POSTFIX_CHECKER=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0

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

_POSTFIX_BIN="$(command -v postfix 2>>${HC_STDERR_LOG})"
if [[ -x ${_POSTFIX_BIN} && -n "${_POSTFIX_BIN}" ]]
then
    ${_POSTFIX_BIN} status >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
    # shellcheck disable=SC2181
    if (( $? == 0 ))
    then
        _MSG="postfix is running"
    else
        _MSG="postfix is not running"
        _STC=1
    fi
else
    warn "postfix is not installed here"
    return 1
fi
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
    log_hc "$0" ${_STC} "${_MSG}"
fi

#-------------------------------------------------------------------------------
# configuration state
_POSTFIX_CHECKER="$(command -v postconf 2>>${HC_STDERR_LOG})"
if [[ -x ${_POSTFIX_CHECKER} && -n "${_POSTFIX_CHECKER}" ]]
then
    # dump configuration
    ${_POSTFIX_CHECKER} -n >>"${HC_STDOUT_LOG}" 2>>"${HC_STDERR_LOG}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        _MSG="postfix configuration files have syntax error(s) {${_POSTFIX_CHECKER} -n}"
        _STC=1
    else
        _MSG="postfix configuration files are syntactically correct"
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
PURPOSE     : Checks whether postfix (mail system) is running and whether the
              postfix configuration files are syntactically correct
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
