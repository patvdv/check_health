#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_vz_ct_status.sh
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
# @(#) MAIN: check_linux_vz_ct_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_is_numeric(), data_has_newline(), data_lc(),
#           dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-04-01: initial version [Patrick Van der Veken]
# @(#) 2017-05-07: made checks more detailed for hc_log() [Patrick Van der Veken]
# @(#) 2017-06-08: return 1 on error [Patrick Van der Veken]
# @(#) 2018-04-30: fixes on variable names Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-02-08: added support for log_healthy + fixes [Patrick Van der Veken]
# @(#) 2020-04-11: added support for OpenVZ 7 [Patrick Van der Veken]
# @(#) 2020-04-12: copy/paste fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_vz_ct_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VZLIST_BIN="/usr/sbin/vzlist"
typeset _VZLIST_OPTS="-a -H -o ctid,status,onboot"
typeset _PRLCTL_BIN="/bin/prlctl"
typeset _PRLCTL_OPTS="list --info -a"
typeset _VERSION="2020-04-12"                           # YYYY-MM-DD
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
typeset _LINE_COUNT=1
typeset _CT_ENTRY=""
typeset _CT_ID=""
typeset _CT_CFG_STATUS=""
typeset _CT_RUN_STATUS=""
typeset _CT_CFG_BOOT=""
typeset _CT_RUN_BOOT=""
typeset _CT_ENTRY=""
typeset _HAS_VZ6=0
typeset _RC=0
set -A _CHECK_CT

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
    if [[ ! -x ${_VZLIST_BIN} || -z "${_VZLIST_BIN}" ]]
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

# get container stati
if (( _HAS_VZ6 > 0 ))
then
    ${_VZLIST_BIN} ${_VZLIST_OPTS} >${HC_STDOUT_LOG} 2>${HC_STDERR_LOG}
    (( $? > 0 )) && {
        _MSG="unable to run command {${_VZLIST_BIN} ${_VZLIST_OPTS}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 0
    }
else
    ${_PRLCTL_BIN} ${_PRLCTL_OPTS} >${HC_STDOUT_LOG} 2>${HC_STDERR_LOG}
    (( $? > 0 )) && {
        _MSG="unable to run command {${_PRLCTL_BIN} ${_PRLCTL_OPTS}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 0
    }
fi

# check configuration values
grep -E -e '^ct:' ${_CONFIG_FILE} 2>/dev/null | cut -f2- -d':' 2>/dev/null |\
    while read -r _CT_ENTRY
do
    # field split
    _CT_ID=$(print "${_CT_ENTRY}" | cut -f1 -d':' 2>/dev/null)
    _CT_CFG_STATUS=$(data_lc "$(print ${_CT_ENTRY} | cut -f2 -d':' 2>/dev/null)")
    _CT_CFG_BOOT=$(data_lc "$(print ${_CT_ENTRY} | cut -f3 -d':' 2>/dev/null)")

    # check config
    if (( _HAS_VZ6 > 0 ))
    then
        data_is_numeric "${_CT_ID}"
        if (( $? > 0 ))
        then
            warn "invalid container ID '${_CT_ID}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            continue
        fi
    fi
    case "${_CT_CFG_STATUS}" in
        running|stopped)
            ;;
        *)
            warn "invalid container status '${_CT_CFG_STATUS}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
            continue
            ;;
    esac
    if (( _HAS_VZ6 > 0 ))
    then
        case "${_CT_CFG_BOOT}" in
            yes|no)
                ;;
                *)
                warn "invalid container boot value '${_CT_CFG_BOOT}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
                continue
                ;;
            esac
    else
        case "${_CT_CFG_BOOT}" in
            on|off)
                ;;
                *)
                warn "invalid container boot value '${_CT_CFG_BOOT}' in configuration file ${_CONFIG_FILE} at data line ${_LINE_COUNT}"
                continue
                ;;
            esac
    fi

    # add CT to check check list
    _CHECK_CT[${#_CHECK_CT[*]}+1]="${_CT_ID}"
    _LINE_COUNT=$(( _LINE_COUNT + 1 ))
done

# fetch data & perform checks
for _CT_ID in "${_CHECK_CT[@]}"
do
    # field split
    _CT_CFG_STATUS=$(grep "^ct:${_CT_ID}" ${_CONFIG_FILE} 2>/dev/null | cut -f3 -d':' 2>/dev/null)
    _CT_CFG_BOOT=$(grep "^ct:${_CT_ID}" ${_CONFIG_FILE} 2>/dev/null | cut -f4 -d':' 2>/dev/null)

    # check for multiple hits
    data_has_newline "${_CT_CFG_STATUS}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "ignoring ${_CT_ID}:${_CT_CFG_STATUS} because it parses to multiple results in ${_CONFIG_FILE}"
        continue
    fi
    data_has_newline "${_CT_CFG_BOOT}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        warn "ignoring ${_CT_ID}:${_CT_CFG_BOOT} because it parses to multiple results in ${_CONFIG_FILE}"
        continue
    fi
    _CT_CFG_STATUS=$(data_lc "${_CT_CFG_STATUS}")
    _CT_CFG_BOOT=$(data_lc "${_CT_CFG_BOOT}")

    # fetch current data
    if (( _HAS_VZ6 > 0 ))
    then
        _CT_ENTRY=$(grep -i "^[[:space:]]*${_CT_ID}" ${HC_STDOUT_LOG} 2>/dev/null)
        if [[ -n "${_CT_ENTRY}" ]]
        then
            # field split
            _CT_RUN_STATUS=$(data_lc "$(print ${_CT_ENTRY} | awk '{print $2}' 2>/dev/null)")
            _CT_RUN_BOOT=$(data_lc "$(print ${_CT_ENTRY} | awk '{print $3}' 2>/dev/null)")
        fi
    else
        awk -F":" -v ct_id="${_CT_ID}" '
        BEGIN {
            found_ct = 0; ct_state = ""; auto_start = "";
            regex_ct = "^EnvID:[[:space:]]+"ct_id;
        }

        {
            if ($0 ~ regex_ct) {
                found_ct = 1;
            } else {
                if (found_ct == 1 && $0 ~ /State:/) {
                    ct_state = $2;
                    gsub (/[[:space:]]/, "", ct_state);
                    #print "State:" ct_state;
                }
                if (found_ct == 1 && $0 ~ /Autostart:/) {
                    auto_start = $2;
                    gsub (/[[:space:]]/, "", auto_start);
                    #print "Start:" auto_start;
                }
            }
            if ($0 ~ /^$/) { found_ct = 0; }
            # bail out when we have both data points
            if (found_ct == 0 && ct_state && auto_start) { nextfile; };
        }
        END {
            printf ("%s:%s", ct_state, auto_start);
        }
        ' ${HC_STDOUT_LOG} 2>/dev/null | IFS=":" read -r _CT_RUN_STATUS _CT_RUN_BOOT
    fi

    # check stati
    if [[ -n "${_CT_RUN_STATUS}" ]] && [[ -n "${_CT_RUN_BOOT}" ]]
    then
        if [[ "${_CT_RUN_STATUS}" = "${_CT_CFG_STATUS}" ]]
        then
            _MSG="container ${_CT_ID} has a correct status [${_CT_RUN_STATUS}]"
            _STC=0
        else
            _MSG="container ${_CT_ID} has a wrong status [${_CT_RUN_STATUS}]"
            _STC=1
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_CT_RUN_STATUS}" "${_CT_CFG_STATUS}"
        fi

        if [[ "${_CT_RUN_BOOT}" = "${_CT_CFG_BOOT}" ]]
        then
            _MSG="container ${_CT_ID} has a correct boot flag [${_CT_RUN_BOOT}]"
            _STC=0
        else
             _MSG="container ${_CT_ID} has a wrong boot flag [${_CT_RUN_BOOT}]"
             _STC=1
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_CT_RUN_BOOT}" "${_CT_CFG_BOOT}"
        fi
    else
        if (( _HAS_VZ6 > 0 ))
        then
            warn "could not determine status for container ${_CT_ID} from command output {${_VZLIST_BIN} ${_VZLIST_OPTS}}"
        else
            warn "could not determine status for container ${_CT_ID} from command output {${_PRLCTL_BIN} ${_PRLCTL_OPTS}}"
        fi
        _RC=$(( _RC + 1 ))
        continue
    fi
done

return ${_RC}
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with formatted stanzas:
               ct:<ctid>:<runtime_status>:<boot_status>
PURPOSE     : Checks whether OpenVZ containers are running or not
LOG HEALTHY : Supported
NOTES       : Supports OpenVZ 6.x & OpenVZ 7.x (release >20200411)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
