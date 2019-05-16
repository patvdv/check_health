#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_cell_griddisks.sh
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
# @(#) MAIN: check_exadata_cell_griddisks
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_comma2newline(), data_get_lvalue_from_config,
#           dump_logs(), exadata_exec_dcli(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-05-14: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_cell_griddisks
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-05-14"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# cell query command -- DO NOT CHANGE --
#celadm01: name:                   RECOC5_CD_03_celadm01
#celadm01: asmDiskGroupName:       RECOC5
#celadm01: asmDiskName:            RECOC5_CD_03_CELADM01
#celadm01: asmFailGroupName:       CELADM01
#celadm01: availableTo:
#celadm01: cachedBy:
#celadm01: cachingPolicy:          none
#celadm01: cellDisk:               CD_03_celadm01
#celadm01: comment:                "Cluster DB diskgroup RECOC5"
#celadm01: creationTime:           2017-09-14T16:21:31+02:00
#celadm01: diskType:               HardDisk
#celadm01: errorCount:             0
#celadm01: id:                     67c31489-1ab4-4649-85f5-1e65ef9af213
#celadm01: size:                   118G
#celadm01: status:                 active
typeset _CELL_COMMAND="cellcli -e 'LIST GRIDDISK DETAIL'"
typeset _TARGET_STATUS="active"
typeset _TARGET_ERRORS=0
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
typeset _CFG_CHECK_ERRORCOUNT=""
typeset _CHECK_ERRORCOUNT=0
typeset _CFG_DCLI_USER=""
typeset _CFG_CELL_SERVERS=""
typeset _CFG_CELL_SERVER=""
typeset _CFG_EXCLUDED_DISKS=""
typeset _CELL_OUTPUT=""
typeset _CELL_DATA=""
typeset _GRID_DISK=""
typeset _DISK_ERRORS=0
typeset _DISK_STATUS=""
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
_CFG_EXCLUDED_DISKS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'excluded_disks')
if [[ -n "${_CFG_EXCLUDED_DISKS}" ]]
then
    log "excluding following grid disk(s) from the check: ${_CFG_EXCLUDED_DISKS}"
fi
_CFG_CHECK_ERRORCOUNT=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_errorcount')
case "${_CFG_CHECK_ERRORCOUNT}" in
    no|NO|No)
        _CHECK_ERRORCOUNT=0
        ;;
    *)
        _CHECK_ERRORCOUNT=1
        ;;
esac
(( _CHECK_ERRORCOUNT > 0 )) || log "checking errorCount has been disabled"

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

    BEGIN { found = 0; grid_disk = ""; disk_errors = 0; disk_status = ""; }

    {
        # split cell data line
        split ($0, cell_line, ":");

        if ( cell_line[2] ~ /name/ ) {
            found = 1;
            grid_disk = cell_line[3];
            # strip spaces
            gsub (/[[:space:]]/, "", grid_disk);
        }
        if ( cell_line[2] ~ /errorCount/ ) {
            disk_errors = cell_line[3];
            # strip spaces
            gsub (/[[:space:]]/, "", disk_errors);
        };

        if ( cell_line[2] ~ /status/ ) {
            disk_status = cell_line[3];
            # strip spaces
            gsub (/[[:space:]]/, "", disk_status);
        };
        if ( grid_disk != "" && disk_status != "" && found ) {
            printf "%s|%s|%s|%s\n", cell_line[1], grid_disk, disk_errors, disk_status
            found = 0; grid_disk = ""; disk_errors = 0; disk_status = "";
        }
    }' 2>>${HC_STDERR_LOG} | while IFS='|' read -r _CELL_SERVER _GRID_DISK _DISK_ERRORS _DISK_STATUS
do
    # check exclusion list
    data_list_contains_string "${_CFG_EXCLUDED_DISKS}" "${_GRID_DISK}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        (( ARG_DEBUG > 0 )) && debug "ignoring grid disk ${_GRID_DISK}"
    else
        # errorCount
        if (( _CHECK_ERRORCOUNT > 0 ))
        then
            if (( _DISK_ERRORS > _TARGET_COUNT ))
            then
                _MSG="error count of grid disk ${_CELL_SERVER}:/${_GRID_DISK} is NOK (${_DISK_ERRORS}!=${_TARGET_ERRORS})"
                _STC=1
            else
                _MSG="error count of grid disk ${_CELL_SERVER}:/${_GRID_DISK} is OK (${_DISK_ERRORS}==${_TARGET_ERRORS})"
                _STC=0
            fi
            if (( _LOG_HEALTHY > 0 || _STC > 0 ))
            then
                log_hc "$0" ${_STC} "${_MSG}" "${_DISK_ERRORS}" "${_TARGET_ERRORS}"
            fi
        fi

        # status
        if [[ "${_DISK_STATUS}" != "${_TARGET_STATUS}" ]]
        then
            _MSG="status of grid disk ${_CELL_SERVER}:/${_GRID_DISK} is NOK (${_DISK_STATUS}!=${_TARGET_STATUS})"
            _STC=1
        else
            _MSG="status of grid disk ${_CELL_SERVER}:/${_GRID_DISK} is OK (${_DISK_STATUS}==${_TARGET_STATUS})"
            _STC=0
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_DISK_STATUS}" "${_TARGET_STATUS}"
        fi
    fi
done

# add dcli output to stdout log
print "==== {dcli ${_CELL_COMMAND}} ====" >>${HC_STDOUT_LOG}
print "${_CELL_DATA}" >>${HC_STDOUT_LOG}

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
               excluded_disks=<list_of_grid_disks_to_exclude>
               check_errorcount=<yes|no>
PURPOSE     : Checks the status of grid disks on cell servers (via dcli)
                dcli> cellcli -e 'LIST GRIDDISK DETAIL'
                Target attributes:
                  * Status: normal
                  * Error count: 0 [optional]
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
