#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_exadata_cell_alerts.sh
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
# @(#) MAIN: check_exadata_cell_alerts
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_comma2newline(), data_get_lvalue_from_config,
#           data_lc(), data_list_contains_string(), data_is_numeric(),
#           data_get_lvalue_from_config(), dump_logs(), exadata_exec_dcli(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-05-14: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_exadata_cell_alerts
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-05-14"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# cell query command -- DO NOT CHANGE --
#celadm03: name:                   2
#celadm03: alertMessage:           "VD bad block table cleared on Adapter 0 VD Target 2"
#celadm03: alertSequenceID:        2
#celadm03: alertShortName:         Hardware
#celadm03: alertType:              Stateless
#celadm03: beginTime:              2019-04-21T08:17:44+02:00
#celadm03: endTime:
#celadm03: examinedBy:
#celadm03: notificationState:      non-deliverable
#celadm03: sequenceBeginTime:      2019-04-21T08:17:44+02:00
#celadm03: severity:               info
#celadm03: alertAction:            Informational.
typeset _CELL_COMMAND="cellcli -e 'LIST ALERTHISTORY DETAIL'"
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
typeset _CFG_ALERT_SEVERITIES=""
typeset _CELL_OUTPUT=""
typeset _CELL_DATA=""
typeset _LAST_SEQUENCE=0
typeset _STATE_FILE=""
typeset _ALERT_DESCRIPTION=""
typeset _ALERT_SEQUENCE=""
typeset _ALERT_SEVERITY=""

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
_CFG_ALERT_SEVERITIES=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'alert_severities')
if [[ -z "${_CFG_ALERT_SEVERITIES}" ]]
then
    warn "no alert severities specified in configuration file at ${_CONFIG_FILE}"
    return 1
else
    _CFG_ALERT_SEVERITIES=$(data_lc "${_CFG_ALERT_SEVERITIES}")
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

# gather cell data (serialized way to have better control of output & errors)
data_comma2newline "${_CFG_CELL_SERVERS}" | while read -r _CFG_CELL_SERVER
do
    # check state file
    _STATE_FILE="${STATE_PERM_DIR}/${_CFG_CELL_SERVER}.alerts"
    (( ARG_DEBUG > 0 )) && debug "checking/reading state file at ${_STATE_FILE}"
    if [[ -r ${_STATE_FILE} ]]
    then
        _LAST_SEQUENCE=$(<"${_STATE_FILE}")
        if [[ -z "${_LAST_SEQUENCE}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "no recorded last log entry for ${_CFG_CELL_SERVER}, resetting to 0"
            _LAST_SEQUENCE=0
        else
            (( ARG_DEBUG > 0 )) && debug "recorded last log entry for ${_CFG_CELL_SERVER}: ${_LAST_SEQUENCE}"
        fi
    else
        : >${_STATE_FILE}
        # shellcheck disable=SC2181
        (( $? > 0 )) && {
            warn "failed to create new state file at ${_STATE_FILE}"
            return 1
        }
        log "created new state file at ${_STATE_FILE}"
    fi

    # execute remote command
    (( ARG_DEBUG > 0 )) && debug "executing remote cell script on ${_CFG_CELL_SERVER}"
    _CELL_OUTPUT=$(exadata_exec_dcli "" "${_CFG_DCLI_USER}" "${_CFG_CELL_SERVER}" "" "${_CELL_COMMAND}" 2>>${HC_STDERR_LOG})
    # empty _CELL_OUTPUT means alert history reset
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        _MSG="did not discover cell data or one of the discoveries failed"
        _STC=2
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}"
        fi
        (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        continue
    else
        # empty alert history?
        if [[ -z "${_CELL_OUTPUT}" ]]
        then
            # zero the state file
            if (( ARG_LOG > 0 ))
            then
                warn "null resetting the current log pointer for ${_CFG_CELL_SERVER}"
                : >${_STATE_FILE} 2>>${HC_STDERR_LOG}
            fi
        fi
    fi

    # perform checks on cell data
    print -R "${_CELL_OUTPUT}" | awk '

        BEGIN { found = 0; alert_description = ""; alert_sequence = ""; alert_severity = ""; }

        {
            # split cell data line
            split ($0, cell_line, ":");

            if ( cell_line[2] ~ /alertDescription/ ) {
                found = 1;
                alert_description = cell_line[3];
                # strip leading spaces & quotes
                gsub (/^[[:space:]]*/, "", alert_description);
                gsub (/\"/, "", alert_description);
            }
            if ( cell_line[2] ~ /alertSequenceID/ ) {
                alert_sequence = cell_line[3];
                # strip spaces
                gsub (/[[:space:]]/, "", alert_sequence);
            };
            if ( cell_line[2] ~ /severity/ ) {
                alert_severity = cell_line[3];
                # strip spaces
                gsub (/[[:space:]]/, "", alert_severity);
            };
            if ( alert_description != "" && alert_sequence != "" && alert_severity != "" && found ) {
                printf "%s|%s|%s\n", alert_description, alert_sequence, tolower (alert_severity)
                found = 0; alert_description = ""; alert_sequence = ""; alert_severity = "";
            }
        }' 2>>${HC_STDERR_LOG} | while IFS='|' read -r _ALERT_DESCRIPTION _ALERT_SEQUENCE _ALERT_SEVERITY
        do
            # check for numeric
            data_is_numeric "${_ALERT_SEQUENCE}"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                warn "non-numeric sequence ID encountered: [${_CFG_CELL_SERVER}/${_ALERT_SEVERITY}/${_ALERT_SEQUENCE}/${_ALERT_DESCRIPTION}]"
                continue
            fi
            if (( _ALERT_SEQUENCE > _LAST_SEQUENCE ))
            then
                # check severities list
                data_list_contains_string "${_CFG_ALERT_SEVERITIES}" "${_ALERT_SEVERITY}"
                # shellcheck disable=SC2181
                if (( $? == 0 ))
                then
                    (( ARG_DEBUG > 0 )) && debug "ignoring alert because of severity: [${_CFG_CELL_SERVER}/${_ALERT_SEVERITY}/${_ALERT_SEQUENCE}/${_ALERT_DESCRIPTION}]"
                    continue
                else
                    _MSG="ID=${_ALERT_SEQUENCE} (${_ALERT_SEVERITY}) ${_ALERT_DESCRIPTION}"
                    if (( _LOG_HEALTHY > 0 ))
                    then
                        log_hc "$0" 1 "${_CFG_CELL_SERVER}: ${_MSG}"
                    fi
                fi
            else
                if (( _LOG_HEALTHY > 0 ))
                then
                    _MSG="no (new) messages discovered from ${_CFG_CELL_SERVER}"
                    log_hc "$0" 0 "${_MSG}"
                fi
            fi
            # rewrite log pointer from the last log entry we discovered
            if (( ARG_LOG > 0 ))
            then
                (( _ALERT_SEQUENCE == 0 )) && _ALERT_SEQUENCE=${_LAST_SEQUENCE}
                (( ARG_DEBUG > 0 )) && debug "updating last log entry for ${_CFG_CELL_SERVER} to ${_ALERT_SEQUENCE}"
                print "${_ALERT_SEQUENCE}" >${_STATE_FILE} 2>>${HC_STDERR_LOG}
            fi
        done

        # add dcli output to stdout log
        print "==== {dcli ${_CELL_COMMAND}} ====" >>${HC_STDOUT_LOG}
        print "${_CELL_DATA}" >>${HC_STDOUT_LOG}
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
               dlci_user=<dlci_user_account>
               cell_servers=<list_of_cell_servers>
               alert_severities=<list_of_severities_to_report_on>
PURPOSE     : Checks the alert history on cell servers (via dcli)
                dcli> cellcli -e 'LIST ALERTHISTORY DETAIL'
CAVEAT      : Requires a working dcli setup for the root user
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
