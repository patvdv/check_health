#!/usr/bin/env ksh
#------------------------------------------------------------------------------
# @(#) check_linux_uptime
#------------------------------------------------------------------------------
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
#------------------------------------------------------------------------------
#
# DOCUMENTATION (MAIN)
# -----------------------------------------------------------------------------
# @(#) MAIN: check_linux_uptime
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_is_numeric(), data_timestring_to_mins(), data_comma2space(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2020-12-21: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#------------------------------------------------------------------------------

# -----------------------------------------------------------------------------
function check_linux_uptime
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _STATE_FILE="${STATE_PERM_DIR}/current.uptime"
typeset _VERSION="2020-12-21"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0
typset _CFG_HEALTHY=
typeset _CFG_CHECK_REBOOT=""
typeset _CFG_REBOOT_TIME=""
typeset _CFG_CHECK_OLD_AGE=""
typeset _CFG_OLD_AGE_TIME=""
typeset _CHECK_REBOOT=""
typeset _REBOOT_TIME=""
typeset _REBOOT_TIME_MINS=""
typeset _CHECK_OLD_AGE=""
typeset _OLD_AGE_TIME=""
typeset _OLD_AGE_TIME_MINS=""
typeset _CURRENT_UPTIME=""
typeset _CURRENT_UPTIME_MINS=""
typeset _PREVIOUS_UPTIME=""
typeset _PREVIOUS_UPTIME_MINS=""
typeset _THRESHOLD_UPTIME_MINS=""

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
_CFG_CHECK_REBOOT=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_reboot')
case "${_CFG_CHECK_REBOOT}" in
    no|No|NO)
        _CHECK_REBOOT=0
        ;;
    *)
        _CHECK_REBOOT=1
        ;;
esac
_CFG_REBOOT_TIME=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'reboot_time')
if [[ -z "${_CFG_REBOOT_TIME}" ]]
then
    # default
    _REBOOT_TIME="60m"
else
    _REBOOT_TIME="${_CFG_REBOOT_TIME}"
fi
_CFG_CHECK_OLD_AGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_old_age')
case "${_CFG_CHECK_OLD_AGE}" in
    yes|Yes|Yes)
        _CHECK_OLD_AGE=1
        ;;
    *)
        _CHECK_OLD_AGE=0
        ;;
esac
_CFG_OLD_AGE_TIME=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'old_age_time')
if [[ -z "${_CFG_OLD_AGE_TIME}" ]]
then
    # default
    _OLD_AGE_TIME="365d"
else
    _OLD_AGE_TIME="${_CFG_OLD_AGE_TIME}"
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
# read /proc/uptime
if [[ -r /proc/uptime ]]
then
    # drop decimals
    _CURRENT_UPTIME=$(awk '{ printf("%2.d", $1)}' /proc/uptime 2>/dev/null)
else
    warn "/proc/uptime cannot be found or queried"
    return 1
fi

#------------------------------------------------------------------------------
# read state file
if [[ -r ${_STATE_FILE} ]]
then
    _PREVIOUS_UPTIME=$(<"${_STATE_FILE}")
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "failed to read state file at ${_STATE_FILE}"
        _PREVIOUS_UPTIME=""
    fi
fi

#------------------------------------------------------------------------------
# convert uptimes values
_CURRENT_UPTIME_MINS=$(( _CURRENT_UPTIME / 60 ))
data_is_numeric "${_CURRENT_UPTIME_MINS}"
# shellcheck disable=SC2181
if (( $? > 0 ))
then
    warn "unable to calculate current uptime value (minutes)"
    (( ARG_DEBUG )) && debug "_CURRENT_UPTIME_MINS=${_CURRENT_UPTIME_MINS}"
    return 1
fi
_PREVIOUS_UPTIME_MINS=$(( _PREVIOUS_UPTIME / 60 ))
data_is_numeric "${_CURRENT_UPTIME_MINS}"
# shellcheck disable=SC2181
if (( $? > 0 ))
then
    warn "unable to calculate previous uptime value (minutes)"
    (( ARG_DEBUG )) && debug "_PREVIOUS_UPTIME_MINS=${_PREVIOUS_UPTIME_MINS}"
    return 1
fi

#------------------------------------------------------------------------------
# check reboot event
if (( _CHECK_REBOOT > 0 ))
then
    # convert _REBOOT_TIME to minutes
    _REBOOT_TIME_MINS=$(data_timestring_to_mins "${_REBOOT_TIME}")
    data_is_numeric "${_REBOOT_TIME_MINS}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "unable to calculate 'reboot_time' value from configuration file ${_CONFIG_FILE}"
        (( ARG_DEBUG )) && debug "_REBOOT_TIME=${_REBOOT_TIME}"
        return 1
    fi

    # previous uptime missing?
    if [[ -z "${_PREVIOUS_UPTIME}" ]]
    then
        if (( ARG_LOG > 0 ))
        then
            print "${_CURRENT_UPTIME}" >"${_STATE_FILE}"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                warn "failed to update state file at ${_STATE_FILE}"
                return 1
            else
                log "unable to find previously recorded uptime, resetting to current uptime"
                return 0
            fi
        else
            log "unable to find previously recorded uptime, resetting to current uptime"
        fi
    else
        # current uptime + reboot time is smaller than previous uptime?
        _THRESHOLD_UPTIME_MINS=$(( _CURRENT_UPTIME_MINS + _REBOOT_TIME_MINS ))
        if (( _THRESHOLD_UPTIME_MINS < _PREVIOUS_UPTIME_MINS ))
        then
            _MSG="reboot check: current uptime is NOK; check if reboot occurred"
            _STC=1
        else
            _MSG="reboot check: current uptime is OK"
            _STC=0
        fi
    fi
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}" "${_THRESHOLD_UPTIME_MINS}" "${_PREVIOUS_UPTIME_MINS}"
    fi

    # update state file
    if (( ARG_LOG > 0 ))
    then
        print "${_CURRENT_UPTIME}" >"${_STATE_FILE}"
        # shellcheck disable=SC2181
        if (( $? > 0 ))
        then
            warn "failed to update state file at ${_STATE_FILE}"
            return 1
        fi
    fi
else
    log "reboot check: not enabled"
fi

#------------------------------------------------------------------------------
# check old age event
if (( _CHECK_OLD_AGE > 0 ))
then
    # convert _OLD_AGE_TIME to minutes
    _OLD_AGE_TIME_MINS=$(data_timestring_to_mins "${_OLD_AGE_TIME}")
    data_is_numeric "${_OLD_AGE_TIME_MINS}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "unable to calculate 'old_age_time' value from configuration file ${_CONFIG_FILE}"
        (( ARG_DEBUG )) && debug "_OLD_AGE_TIME=${_OLD_AGE_TIME}"
        return 1
    fi

    # are we old age yet?
    if (( _CURRENT_UPTIME_MINS > _OLD_AGE_TIME_MINS ))
    then
        _MSG="old_age check: current uptime is NOK; old age has arrived (>${_OLD_AGE_TIME})"
        _STC=1
    else
        _MSG="old_age check: current uptime is OK"
        _STC=0
    fi
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}" "${_CURRENT_UPTIME_MINS}" "${_OLD_AGE_TIME_MINS}"
    fi
else
    log "old age check: not enabled"
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
               check_reboot=<yes|no>
               reboot_time=<timestring>
               check_old_age=<yes|no>
               old_age_time=<timestring>
PURPOSE     : Checks for unexpected/unplanned reboot events based on uptime
               values.
              Checks whether the host has been up and running for too much time.
LOG HEALTHY : Supported

EOT

return 0
}


#------------------------------------------------------------------------------
# END of script
#------------------------------------------------------------------------------
