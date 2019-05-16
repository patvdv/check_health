#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_megaraid.sh
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
# @(#) MAIN: check_exadata_megaraid
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_comma2newline(), data_get_lvalue_from_config,
#           dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-05-14: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_megaraid
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-05-14"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _MEGACLI_BIN="/opt/MegaRAID/MegaCli/MegaCli64"
typeset _MEGACLI_COMMAND="-ShowSummary -aALL"
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
typeset _CFG_CHECK_CONTROLLER=""
typeset _CHECK_CONTROLLER=0
typeset _CFG_CHECK_BBU=""
typeset _CHECK_BBU=0
typeset _CFG_CHECK_PHYSICAL=""
typeset _CHECK_PHYSICAL=0
typeset _CFG_CHECK_VIRTUAL=""
typeset _CHECK_VIRTUAL=0
typeset _CLI_OUTPUT=""
typeset _CLI_DATA=""
typeset _RAID_DEVICE=""
typeset _RAID_DEVICE_TYPE=""
typeset _RAID_STATUS=""

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
(( _CHECK_BBU > 0 )) || log "checking bbu has been disabled"
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

# check megacli
if [[ ! -x ${_MEGACLI_BIN} || -z "${_MEGACLI_BIN}" ]]
then
    warn "MegaCLI is not installed here. This is not an Exadata compute node?"
    return 1
fi

# gather MegaCLI data
(( ARG_DEBUG > 0 )) && debug "executing MegaCLI command"
_CLI_OUTPUT=$(${_MEGACLI_BIN} "${_MEGACLI_COMMAND}" 2>>${HC_STDERR_LOG})
# shellcheck disable=SC2181
if (( $?> 0 )) || [[ -z "${_CLI_OUTPUT}" ]]
then
    _MSG="unable to query MegaRAID controller"
    _STC=2
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi

# perform checks on cell data
print -R "${_CLI_OUTPUT}" | awk '

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
        if ( cell_line[1] ~ /Controller/ ) {
            found_controller = 1;
        }
        if ( cell_line[1] ~ /BBU/ ) {
            found_bbu = 1;
        }
        if ( cell_line[1] ~ /Connector/ ) {
            found_physical = 1;
            physical_device = cell_line[3];
            # strip leading & trailing spaces
            gsub (/^[[:space:]]*/, "", physical_device);
            gsub (/[[:space:]]*$/, "", physical_device);
        }
        if ( cell_line[1] ~ /Virtual drive/ ) {
            found_virtual = 1;
            virtual_device = cell_line[2];
            # strip leading spaces
            gsub (/^[[:space:]]*/, "", virtual_device);
        }

        # find attributes
        if ( cell_line[1] ~ /Status/ ) {
            status = cell_line[2];
            # strip spaces
            gsub (/[[:space:]]/, "", status);
            if (found_controller > 0 ) { controller_status = status }
            if (found_bbu > 0 ) {
                # delete the PITA "PD" string
                gsub (/[[:space:]]*PD[[:space:]]*/, "", status);
                bbu_status = status;
            }
        };
        if ( cell_line[1] ~ /State/ ) {
            status = cell_line[2];
            # strip spaces
            gsub (/[[:space:]]/, "", status);
            if (found_physical > 0 ) { physical_status = status }
            if (found_virtual > 0 ) { virtual_status = status }
        };

        # report results
        if ( controller_status != "" && found_controller ) {
            printf "%s|%s|%s\n", "CONTROLLER", "", controller_status
            found_controller = 0; controller_status = ""; status = "";
        }
        if ( bbu_status != "" && found_bbu ) {
            printf "%s|%s|%s\n", "BBU", "", bbu_status
            found_bbu = 0; bbu_status = ""; status = "";
        }
        if ( physical_device != "" && physical_status != "" && found_physical ) {
            printf "%s|%s|%s\n", "PHYSICAL", physical_device, physical_status
            found_physical = 0; physical_device = ""; physical_status = ""; status = "";
        }
        if ( virtual_device != "" && virtual_status != "" && found_virtual ) {
            printf "%s|%s|%s\n", "VIRTUAL", virtual_device, virtual_status
            found_virtual = 0; virtual_device = ""; virtual_status = ""; status = "";
        }

    }' 2>>${HC_STDERR_LOG} | while IFS='|' read -r _RAID_DEVICE_TYPE _RAID_DEVICE _RAID_STATUS
do
    case "${_RAID_DEVICE_TYPE}" in
        CONTROLLER)
            if (( _CHECK_CONTROLLER > 0 ))
            then
                _TARGET_STATUS="Optimal"
                if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                then
                    _MSG="state of controller is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                    _STC=1
                else
                    _MSG="state of controller is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                    _STC=0
                fi
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for controller (disabled)"
            fi
            ;;
        BBU)
            if (( _CHECK_BBU > 0 ))
            then
                _TARGET_STATUS="Healthy"
                if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                then
                    _MSG="state of bbu is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                    _STC=1
                else
                    _MSG="state of bbu is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                    _STC=0
                fi
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for bbu (disabled)"
            fi
            ;;
        PHYSICAL)
            if (( _CHECK_PHYSICAL > 0 ))
            then
                _TARGET_STATUS="Online"
                if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                then
                    _MSG="state of physical device ${_RAID_DEVICE} is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                    _STC=1
                else
                    _MSG="state of physical device on ${_RAID_DEVICE} is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                    _STC=0
                fi
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for physical device [${_RAID_DEVICE}] (disabled)"
            fi
            ;;
        VIRTUAL)
            if (( _CHECK_VIRTUAL > 0 ))
            then
                _TARGET_STATUS="Optimal"
                if [[ "${_RAID_STATUS}" != "${_TARGET_STATUS}" ]]
                then
                    _MSG="state of virtual device ${_RAID_DEVICE} is NOK (${_RAID_STATUS}!=${_TARGET_STATUS})"
                    _STC=1
                else
                    _MSG="state of virtual device on ${_RAID_DEVICE} is OK (${_RAID_STATUS}==${_TARGET_STATUS})"
                    _STC=0
                fi
                if (( _LOG_HEALTHY > 0 || _STC > 0 ))
                then
                    log_hc "$0" ${_STC} "${_MSG}" "${_RAID_STATUS}" "${_TARGET_STATUS}"
                fi
            else
                (( ARG_DEBUG > 0 )) && debug "skipping check for virtual device [${_RAID_DEVICE}] (disabled)"
            fi
            ;;
    esac
done

# add dcli output to stdout log
print "==== {${_MEGACLI_COMMAND}} ====" >>${HC_STDOUT_LOG}
print "${_CLI_DATA}" >>${HC_STDOUT_LOG}

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
               check_controller=<yes|no>
               check_bbu=<yes|no>
               check_physical=<yes|no>
               check_virtual=<yes|no>
PURPOSE     : Checks the status of MegaRAID device(s)
                # /opt/MegaRAID/MegaCli/MegaCli64 -ShowSummary -aALL
              Target attributes:
                * Controller: Optimal [optional]
                * BBU: Healthy [optional]
                * Physical devices: Online [optional]
                * Virtual devices: Optimal [optional]
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
