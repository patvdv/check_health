#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_cell_megaraid.sh
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
# @(#) MAIN: check_exadata_cell_megaraid
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_comma2newline(), data_contains_string(),
#           data_get_lvalue_from_config, dump_logs(), exadata_exec_dcli(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-05-14: initial version [Patrick Van der Veken]
# @(#) 2019-07-08: update _CELL_COMMAND [Patrick Van der Veken]
# @(#) 2019-07-18: added supercap check, see Oracle bug 28564584 + exclusion
#                  logic for components (cell_exclude) [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_cell_megaraid
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-07-18"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# cell query command -- DO NOT CHANGE --
typeset _CELL_COMMAND="/opt/MegaRAID/storcli/storcli64 -ShowSummary -aALL"
typeset _SUPERCAP_COMMAND="/opt/MegaRAID/storcli/storcli64 /c0/cv show all"
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
typeset _CFG_DCLI_USER=""
typeset _CFG_CELL_SERVERS=""
typeset _CFG_CELL_SERVER=""
typeset _CFG_CHECK_CONTROLLER=""
typeset _CHECK_CONTROLLER=0
typeset _CFG_CHECK_BBU=""
typeset _CHECK_BBU=0
typeset _CFG_CHECK_SUPERCAP=""
typeset _CHECK_SUPERCAP=0
typeset _CFG_CHECK_PHYSICAL=""
typeset _CHECK_PHYSICAL=0
typeset _CFG_CHECK_VIRTUAL=""
typeset _CHECK_VIRTUAL=0
typeset _CFG_EXCLUDES=""
typeset _CELL_OUTPUT=""
typeset _CELL_DATA=""
typeset _RAID_DEVICE=""
typeset _RAID_DEVICE_TYPE=""
typeset _RAID_STATUS=""
typeset _SUPERCAP_STATUS=""
typeset _CELL_ALL_RC=0
typeset _CELL_RC=0

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
_CFG_DCLI_USER=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'dcli_user')
if [[ -z "${_CFG_DCLI_USER}" ]]
then
    _CFG_DCLI_USER="root"
    log "will use DCLI user ${_CFG_DCLI_USER}"
fi
_CFG_CELL_SERVERS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'cell_servers')
if [[ -z "${_CFG_CELL_SERVERS}" ]]
then
    warn "no cell servers specified in configuration file at ${_CONFIG_FILE}"
    return 1
fi
_CFG_CHECK_CONTROLLER=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_controller')
case "${_CFG_CHECK_CONTROLLER}" in
    no|NO|No)
        _CHECK_CONTROLLER=0
        ;;
    *)
        _CHECK_CONTROLLER=1
        ;;
esac
(( _CHECK_CONTROLLER > 0 )) || log "checking controller has been disabled"
_CFG_CHECK_BBU=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_bbu')
case "${_CFG_CHECK_BBU}" in
    no|NO|No)
        _CHECK_BBU=0
        ;;
    *)
        _CHECK_BBU=1
        ;;
esac
(( _CHECK_BBU > 0 )) || log "checking bbu (battery) has been disabled"
_CFG_CHECK_SUPERCAP=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_supercap')
case "${_CFG_CHECK_SUPERCAP}" in
    no|NO|No)
        _CHECK_SUPERCAP=0
        ;;
    *)
        _CHECK_SUPERCAP=1
        ;;
esac
(( _CHECK_SUPERCAP > 0 )) || log "checking bbu (supercap) has been disabled"
_CFG_CHECK_PHYSICAL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_physical')
case "${_CFG_CHECK_PHYSICAL}" in
    no|NO|No)
        _CHECK_PHYSICAL=0
        ;;
    *)
        _CHECK_PHYSICAL=1
        ;;
esac
(( _CHECK_PHYSICAL > 0 )) || log "checking physical has been disabled"
_CFG_CHECK_VIRTUAL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_virtual')
case "${_CFG_CHECK_VIRTUAL}" in
    no|NO|No)
        _CHECK_VIRTUAL=0
        ;;
    *)
        _CHECK_VIRTUAL=1
        ;;
esac
(( _CHECK_VIRTUAL > 0 )) || log "checking virtual has been disabled"
_CFG_EXCLUDES=$(grep -i -E -e '^cell_exclude:' ${_CONFIG_FILE} 2>/dev/null)

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

# gather cell data (serialized way to have better control of output & errors)
data_comma2newline "${_CFG_CELL_SERVERS}" | while read -r _CFG_CELL_SERVER
do
    (( ARG_DEBUG > 0 )) && debug "executing remote cell script on ${_CFG_CELL_SERVER}"
    _CELL_OUTPUT=$(exadata_exec_dcli "" "${_CFG_DCLI_USER}" "${_CFG_CELL_SERVER}" "" "${_CELL_COMMAND}" 2>>${HC_STDERR_LOG})
    _CELL_RC=$?
    if (( _CELL_RC > 0 )) || [[ -z "${_CELL_OUTPUT}" ]]
    then
        _CELL_ALL_RC=$(( _CELL_ALL_RC + _CELL_RC ))
        warn "unable to discover cell data on ${_CFG_CELL_SERVER}"
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        continue
    else
        # _CELL_OUTPUT is always prefixed by cell server name, so no mangling needed
        # shellcheck disable=SC1117
        _CELL_DATA=$(printf "%s\n%s\n" "${_CELL_DATA}" "${_CELL_OUTPUT}")
    fi
done

# validate cell data
if (( _CELL_ALL_RC > 0 )) || [[ -z "${_CELL_DATA}" ]]
then
    _MSG="did not discover cell data or one of the discoveries failed"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    return 1
fi

# perform checks on cell data
print -R "${_CELL_DATA}" | awk '

    BEGIN { found_controller = 0; controller_status = "";
            found_bbu = 0; bbu_status = "";
            found_physical = 0; physical_device = ""; physical_status = "";
            found_virtual = 0; vitual_device = ""; virtual_status = "";
            status = "";
    }

    {
        # split cell data line
        split ($0, cell_line, ":");

        # find markers
        if ( cell_line[2] ~ /Controller/ ) {
            found_controller = 1;
        }
        if ( cell_line[2] ~ /BBU/ ) {
            found_bbu = 1;
        }
        if ( cell_line[2] ~ /Connector/ ) {
            found_physical = 1;
            physical_device = cell_line[4];
            # strip leading spaces
            gsub (/^[[:space:]]*/, "", physical_device);
        }
        if ( cell_line[2] ~ /Virtual drive/ ) {
            found_virtual = 1;
            virtual_device = cell_line[3];
            # strip leading spaces
            gsub (/^[[:space:]]*/, "", virtual_device);
        }

        # find attributes
        if ( cell_line[2] ~ /Status/ ) {
            status = cell_line[3];
            # strip spaces
            gsub (/[[:space:]]/, "", status);
            if (found_controller > 0 ) { controller_status = status }
            if (found_bbu > 0 ) {
                # delete the PITA "PD" string
                gsub (/[[:space:]]*PD[[:space:]]*/, "", status);
                bbu_status = status;
            }
        };
        if ( cell_line[2] ~ /State/ ) {
            status = cell_line[3];
            # strip spaces
            gsub (/[[:space:]]/, "", status);
            if (found_physical > 0 ) { physical_status = status }
            if (found_virtual > 0 ) { virtual_status = status }
        };

        # report results
        if ( controller_status != "" && found_controller ) {
            printf "%s|%s|%s|%s\n", cell_line[1], "CONTROLLER", "", controller_status
            found_controller = 0; controller_status = ""; status = "";
        }
        if ( bbu_status != "" && found_bbu ) {
            printf "%s|%s|%s|%s\n", cell_line[1], "BBU", "", bbu_status
            found_bbu = 0; bbu_status = ""; status = "";
        }
        if ( physical_device != "" && physical_status != "" && found_physical ) {
            printf "%s|%s|%s|%s\n", cell_line[1], "PHYSICAL", physical_device, physical_status
            found_physical = 0; physical_device = ""; physical_status = ""; status = "";
        }
        if ( virtual_device != "" && virtual_status != "" && found_virtual ) {
            printf "%s|%s|%s|%s\n", cell_line[1], "VIRTUAL", virtual_device, virtual_status
            found_virtual = 0; virtual_device = ""; virtual_status = ""; status = "";
        }

    }' 2>>${HC_STDERR_LOG} | while IFS='|' read -r _CELL_SERVER _RAID_DEVICE_TYPE _RAID_DEVICE _RAID_STATUS
do
    case "${_RAID_DEVICE_TYPE}" in
        CONTROLLER)
            if (( _CHECK_CONTROLLER > 0 ))
            then
                # check for exclusion
                $(data_contains_string "${_CFG_EXCLUDES}" "${_CELL_SERVER}:controller")
                if (( $? == 0 ))
                then
                    _TARGET_STATUS="Optimal"
                    if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                    then
                        _MSG="state of controller on ${_CELL_SERVER} is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                        _STC=1
                    else
                        _MSG="state of controller on ${_CELL_SERVER} is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                        _STC=0
                    fi
                    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                    then
                        log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                    fi
                else
                    (( ARG_DEBUG > 0 )) && debug "excluded check for controller on ${_CELL_SERVER}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for controller (disabled) [${_CELL_SERVER}]"
            fi
            ;;
        BBU)
            if (( _CHECK_BBU > 0 ))
            then
                # check for exclusion
                $(data_contains_string "${_CFG_EXCLUDES}" "${_CELL_SERVER}:bbu")
                if (( $? == 0 ))
                then
                    _TARGET_STATUS="Healthy"
                    if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                    then
                        _MSG="state of bbu (battery) on ${_CELL_SERVER} is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                        _STC=1
                    else
                        _MSG="state of bbu (battery) on ${_CELL_SERVER} is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                        _STC=0
                    fi
                    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                    then
                        log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                    fi
                else
                    (( ARG_DEBUG > 0 )) && debug "excluded check for BBU (battery) on ${_CELL_SERVER}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for bbu (battery) (disabled) [${_CELL_SERVER}]"
            fi
            ;;
        PHYSICAL)
            if (( _CHECK_PHYSICAL > 0 ))
            then
                # check for exclusion
                $(data_contains_string "${_CFG_EXCLUDES}" "${_CELL_SERVER}:physical")
                if (( $? == 0 ))
                then
                    _TARGET_STATUS="Online"
                    if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                    then
                        _MSG="state of physical device ${_CELL_SERVER}:/${_RAID_DEVICE} is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                        _STC=1
                    else
                        _MSG="state of physical device on ${_CELL_SERVER}:/${_RAID_DEVICE} is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                        _STC=0
                    fi
                    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                    then
                        log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                    fi
                else
                    (( ARG_DEBUG > 0 )) && debug "excluded check for physical devices on ${_CELL_SERVER}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for physical device [${_CELL_SERVER}:/${_RAID_DEVICE}] (disabled)"
            fi
            ;;
        VIRTUAL)
            if (( _CHECK_VIRTUAL > 0 ))
            then
                # check for exclusion
                $(data_contains_string "${_CFG_EXCLUDES}" "${_CELL_SERVER}:virtual")
                if (( $? == 0 ))
                then
                    _TARGET_STATUS="Optimal"
                    if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                    then
                        _MSG="state of virtual device ${_CELL_SERVER}:/${_RAID_DEVICE} is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                        _STC=1
                    else
                        _MSG="state of virtual device on ${_CELL_SERVER}:/${_RAID_DEVICE} is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                        _STC=0
                    fi
                    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                    then
                        log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                    fi
                else
                    (( ARG_DEBUG > 0 )) && debug "excluded check for virtual devices on ${_CELL_SERVER}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for virtual device [${_CELL_SERVER}:/${_RAID_DEVICE}] (disabled)"
            fi
            ;;
    esac
done

# add dcli output to stdout log
print "==== {dcli ${_CELL_COMMAND} [${_CFG_CELL_SERVER}]} ====" >>${HC_STDOUT_LOG}
print "${_CELL_DATA}" >>${HC_STDOUT_LOG}

# check if we need to check the BBU (supercap). Use different storcli query
# see Oracle Bug 28564584 : X5-2 Aspen w/storcli utility shows false bbu failed status
if (( _CHECK_SUPERCAP > 0 ))
then
    _CELL_DATA=""
    # gather cell data (serialized way to have better control of output & errors)
    data_comma2newline "${_CFG_CELL_SERVERS}" | while read -r _CFG_CELL_SERVER
    do
        (( ARG_DEBUG > 0 )) && debug "executing remote cell script on ${_CFG_CELL_SERVER}"
        _CELL_OUTPUT=$(exadata_exec_dcli "" "${_CFG_DCLI_USER}" "${_CFG_CELL_SERVER}" "" "${_SUPERCAP_COMMAND}" 2>>${HC_STDERR_LOG})
        _CELL_RC=$?
        if (( _CELL_RC > 0 )) || [[ -z "${_CELL_OUTPUT}" ]]
        then
            _CELL_ALL_RC=$(( _CELL_ALL_RC + _CELL_RC ))
            warn "unable to discover cell data on ${_CFG_CELL_SERVER}"
            (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
            continue
        else
        # _CELL_OUTPUT is always prefixed by cell server name, so no mangling needed
        # shellcheck disable=SC1117
        _CELL_DATA=$(printf "%s\n%s\n" "${_CELL_DATA}" "${_CELL_OUTPUT}")
        fi
    done

    # validate cell data
    if (( _CELL_ALL_RC > 0 )) || [[ -z "${_CELL_DATA}" ]]
    then
        _MSG="did not discover cell data or one of the discoveries failed"
        _STC=2
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
        fi
        return 1
    fi

    # perform checks on cell data
    _TARGET_STATUS="Optimal"
    data_comma2newline "${_CFG_CELL_SERVERS}" | while read -r _CFG_CELL_SERVER
    do
        # check for exclusion
        $(data_contains_string "${_CFG_EXCLUDES}" "${_CELL_SERVER}:supercap")
        if (( $? == 0 ))
        then
            _SUPERCAP_STATUS=$(print -R "${_CELL_DATA}" | grep -c -E -e "^${_CFG_CELL_SERVER}: *State *${_TARGET_STATUS}" 2>/dev/null)
            if (( _SUPERCAP_STATUS == 0 ))
            then
                _MSG="state of BBU (supercap) device on ${_CFG_CELL_SERVER} is NOK"
                _STC=1
            else
                _MSG="state of BBU (supercap) device on ${_CFG_CELL_SERVER} is OK"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "Non-optimal" "${_TARGET_STATUS}"
            fi
        else
            (( ARG_DEBUG > 0 )) && debug "excluded check for bbu (supercap) on ${_CELL_SERVER}"
        fi
    done

    # add dcli output to stdout log
    print "==== {dcli ${_SUPERCAP_COMMAND}} ====" >>${HC_STDOUT_LOG}
    print "${_CELL_DATA}" >>${HC_STDOUT_LOG}
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
               dlci_user=<dlci_user_account>
               cell_servers=<list_of_cell_servers>
               check_controller=<yes|no>
               check_bbu=<yes|no>
               check_supercap=<yes|no>
               check_physical=<yes|no>
               check_virtual=<yes|no>
              and formatted stanzas of:
               cell_exclude:<cell_server>:<component>
PURPOSE     : 1) Checks the status of MegaRAID device(s) on cell servers (via dcli)
                dcli> /opt/MegaRAID/MegaCli/MegaCli64 -ShowSummary -aALL
              Target attributes:
                * Controller: Optimal [optional]
                * BBU (battery): Healthy [optional]
                * Physical devices: Online [optional]
                * Virtual devices: Optimal [optional]
              2) Checks the status of the Supercap (battery):
                dcli> /opt/MegaRAID/storcli/storcli64 /c0/cv show all
CAVEAT      : Requires a working dcli setup for the root user
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
