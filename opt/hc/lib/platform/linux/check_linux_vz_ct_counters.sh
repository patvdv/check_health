#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_vz_ct_counters.sh
#******************************************************************************
# @(#) Copyright (C) 2019 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_linux_vz_ct_counters
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_is_numeric(), dump_logs(), init_hc(),
#           log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-02-08: initial version [Patrick Van der Veken]
# @(#) 2020-04-10: added support for OpenVZ 7. Now using /proc/user_beancounters
# @(#)             instead of the 'vzubc' tool. Added possbility to exclude
# @(#)             UBC counters [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_vz_ct_counters
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VZCTL_BIN="/usr/sbin/vzctl"
typeset _PRLCTL_BIN="/bin/prlctl"
typeset _UBC_FILE="/proc/user_beancounters"
typeset _VERSION="2020-04-10"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_EXCLUDE_COUNTERS=""
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CT_ID=""
typeset _HAS_VZ6=0
typeset _UBC_DATA=""
typeset _UBC_CT_DATA=""
typeset _UBC_NAME=""
typeset _UBC_CURR_FAIL=""
typeset _UBC_PREV_FAIL=""
typeset _UBC_HELD=""
typeset _UBC_MAX_HELD=""
typeset _UBC_STATE_FILE_STUB="${STATE_PERM_DIR}/vzct.failtcnt"
typeset _UBC_STATE_FILE=""

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
_CFG_EXCLUDE_COUNTERS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'exclude_counters')
if [[ -n "${_CFG_EXCLUDE_COUNTERS}" ]]
then
    log "excluding following counters from check: ${_CFG_EXCLUDE_COUNTERS}"
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

# check openvz (6.x or 7.x)
if [[ ! -x ${_PRLCTL_BIN} || -z "${_PRLCTL_BIN}" ]]
then
    if [[ ! -x ${_VZCTL_BIN} || -z "${_VZCTL_BIN}" ]]
    then
        warn "OpenVZ is not installed here"
        return 1
    else
        log "OpenVZ 6.x is installed here"
        _HAS_VZ6=1
    fi
else
    log "OpenVZ 7.x is installed here"
fi
if [[ ! -r "${_UBC_FILE}" ]]
then
    warn "missing user beancounters file at ${_UBC_FILE}"
    return 1
fi

# get bean counters
_UBC_DATA=$(cat ${_UBC_FILE} 2>>${HC_STDERR_LOG})
if (( $? > 0 )) || [[ -z "${_UBC_DATA}" ]]
then
    warn "unable to get UBC data from ${_UBC_FILE}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi

# check configuration values
grep -E -e '^ct:' ${_CONFIG_FILE} 2>/dev/null | cut -f2 -d':' 2>/dev/null |\
    while read -r _CT_ID
do
    # OpenVZ 6.x has only numeric CT IDs
    if (( _HAS_VZ6 > 0 ))
    then
        data_is_numeric "${_CT_ID}"
        if (( $? > 0 ))
        then
            warn "${_CT_ID} does not appear to be a correct OpenVZ 6 CT ID"
            continue
        fi
    fi

    # parse UBC data for CT ID
    _UBC_CT_DATA=$(print "${_UBC_DATA}" | awk -v ct_id=${_CT_ID} -v exclude_counters="${_CFG_EXCLUDE_COUNTERS}" '
        BEGIN {
            found_ct = 0;
        }

        {
            # find container start line
            if (NF == 7 && $1 !~ /uid/) {
                gsub (/:/, "", $1);

                if ($1 == ct_id) {
                    found_ct = 1;
                } else {
                    found_ct = 0;
                }
            } else {
                if (NF == 6 && found_ct > 0 ) {
                    if ($1 !~ /dummy/ && !match (exclude_counters, $1)) {
                        printf ("%s:%d:%d:%d\n", $1, $2, $3, $6);
                    }
                }
            }
        }
    ' 2>/dev/null)

    # check UBC data
    if [[ -n "${_UBC_CT_DATA}" ]]
    then
        print "${_UBC_CT_DATA}" | while IFS=":" read -r _UBC_NAME _UBC_HELD _UBC_MAX_HELD _UBC_CURR_FAIL
        do
            if [[ -z "${_UBC_NAME}" ]] || [[ -z "${_UBC_CURR_FAIL}" ]]
            then
                warn "unable to parse UBC name and/or fail count values for CT ID ${_CT_ID}"
                continue
            fi
            data_is_numeric "${_UBC_CURR_FAIL}"
            if (( $? > 0 ))
            then
                warn "${_UBC_CURR_FAIL} does not appear to a numeric fail count for CT ID ${_CT_ID}"
                continue
            fi

            # get previous fail count value
            _UBC_STATE_FILE="${_UBC_STATE_FILE_STUB}-${_UBC_NAME}_${_CT_ID}"
            if [[ -s "${_UBC_STATE_FILE}" ]]
            then
                _UBC_PREV_FAIL=$(<${_UBC_STATE_FILE} 2>/dev/null)
            else
                _UBC_PREV_FAIL=0
            fi

            if (( _UBC_CURR_FAIL > _UBC_PREV_FAIL ))
            then
                _MSG="${_UBC_NAME} for CT ${_CT_ID} increased with $(( _UBC_CURR_FAIL - _UBC_PREV_FAIL )) [HELD:${_UBC_HELD}/MAX_HELD:${_UBC_MAX_HELD}]"
                _STC=1
            else
                _MSG="${_UBC_NAME} for CT ${_CT_ID} is unchanged [HELD:${_UBC_HELD}/MAX_HELD:${_UBC_MAX_HELD}]"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_UBC_HELD}" "${_UBC_MAX_HELD}"
            fi

            # write current fail count value
            if (( ARG_LOG > 0 ))
            then
                print "${_UBC_CURR_FAIL}" >${_UBC_STATE_FILE}
            fi
        done
    else
        warn "unable to find UBC data for CT ID ${_CT_ID}"
        continue
    fi
done

# add UBC output to stdout log
print "==== ${_UBC_FILE} ====" >>${HC_STDOUT_LOG}
print "${_UBC_OUTPUT}" >>${HC_STDOUT_LOG}

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with parameters:
               exclude_counters=<ubc_name>,<ubc_name>,...
              with formatted stanzas:
               ct:<ct_id>
PURPOSE     : Checks whether UBC (User Bean Counters) for OpenVZ containers have
              increased (failures)
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
