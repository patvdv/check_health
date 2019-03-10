#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_lunpaths.sh
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
# @(#) MAIN: check_hpux_lunpaths
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2017-12-20: initial version [Patrick Van der Veken]
# @(#) 2018-18-22: reworked discovery routine (accommdate large number of LUNS)
# @(#)             [Patrick Van der Veken]
# @(#) 2018-11-18: do not trap on signal 0 [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-09-03: small variable fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_lunpaths
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _IOSCAN_BIN="/usr/sbin/ioscan"
typeset _IOSCAN_OPTS="-C disk -P wwid"
typeset _SCSIMGR_BIN="/usr/sbin/scsimgr"
typeset _SCSIMGR_OPTS="-v get_info all_lun"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _LOG_HEALTHY=0
typeset _TMP1_FILE="${TMP_DIR}/.$0.ioscan_tmp.$$"
typeset _TMP2_FILE="${TMP_DIR}/.$0.scsimgr_tmp.$$"
typeset _HW_PATH=""
typeset _ACTIVE_PATH_COUNT=""
typeset _ALL_PATH_COUNT=""
typeset _FAILED_PATH_COUNT=""
typeset _STANDBY_PATH_COUNT=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
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

# set local trap for cleanup
# shellcheck disable=SC2064
trap "[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1;
      return 1" 1 2 3 15

# check required tools
if [[ ! -x ${_IOSCAN_BIN} ]]
then
    warn "${_IOSCAN_BIN} is not installed here"
    return 1
fi
if [[ ! -x ${_SCSIMGR_BIN} ]]
then
    warn "${_SCSIMGR_BIN} is not installed here"
    return 1
fi

# check TMP_FILEs
: >${_TMP1_FILE}
(( $? > 0 )) && {
    warn "failed to create temporary file at ${_TMP1_FILE}"
    return 1
}
: >${_TMP2_FILE}
(( $? > 0 )) && {
    warn "failed to create temporary file at ${_TMP2_FILE}"
    return 1
}

# get all disk LUNs
(( ARG_DEBUG > 0 )) && debug "collecting ioscan information"
print "=== ioscan ===" >>${HC_STDOUT_LOG}
${_IOSCAN_BIN} ${_IOSCAN_OPTS} >${_TMP1_FILE} 2>>${HC_STDERR_LOG}
if (( $? > 0 ))
then
    _MSG="unable to gather ioscan information"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi

# collect scsimgr info for all LUNs
(( ARG_DEBUG > 0 )) && debug "collecting scsimgr information"
${_SCSIMGR_BIN} ${_SCSIMGR_OPTS} >${_TMP2_FILE} 2>>${HC_STDERR_LOG}
if (( $? > 0 ))
then
    _MSG="unable to gather scsimgr information"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi

# parse ioscan + scsimgr results (WWID is the glue)
(( ARG_DEBUG > 0 )) && debug "glueing ioscan & scsimgr information together"
awk 'BEGIN { wwid = ""; active_paths = ""; all_paths = ""; failed_paths = ""; standby_paths = ""; }

    {
        # parse ioscan file (build disks[] array)
        #Class     I  H/W Path  wwid
        #===============================
        #disk      4  64000/0xfa00/0x2    0x60060e8007e2b1000030e2b10000bb68
        #disk      5  64000/0xfa00/0x3    0x60060e8007e2b1000030e2b100006040
        if (FILENAME ~ /ioscan/) {
            if ($0 ~ /^disk/) {
                disks[$4] = $3;
            }
        }

        # parse scsimgr file (build paths_*[] arrays)
        if (FILENAME ~ /scsimgr/) {
            # parse until end of stanza (=empty line)
            if ($0 ~ /^World Wide Identifier/ ) {
                split ($0, line, "=");
                wwid = line[2];
                gsub (/ /,"", wwid);
                getline;
                while ($0 !~ /^$/) {
                    if ($0 ~ /^LUN path count/) {
                        split ($0, line, "=");
                        all_paths = line[2];
                        gsub (/ /,"", all_paths);
                    }
                    if ($0 ~ /^Active LUN paths/) {
                        split ($0, line, "=");
                        active_paths = line[2];
                        gsub (/ /,"", active_paths);
                    }
                    if ($0 ~ /^Failed LUN paths/) {
                        split ($0, line, "=");
                        failed_paths = line[2];
                        gsub (/ /,"", failed_paths);
                    }
                    if ($0 ~ /^Standby LUN paths/) {
                        split ($0, line, "=");
                        standby_paths = line[2];
                        gsub (/ /,"", standby_paths);
                    }
                    if (wwid != "" &&
                        active_paths != "" &&
                        all_paths != "" &&
                        failed_paths != "" &&
                        standby_paths != "") {
                            paths_active[wwid] = active_paths;
                            paths_all[wwid] = all_paths;
                            paths_failed[wwid] = failed_paths;
                            paths_standby[wwid] = standby_paths;
                            # reset variables
                            wwid = ""; active_paths = "";
                            all_paths = ""; failed_paths = "";
                            standby_paths = "";
                    }
                    getline;
                }
            }
        }
    }

    END {
        # loop over all disk LUNs to display their SCSI attributes
        for (wwid in disks) {
            print wwid "|" disks[wwid] "|" paths_active[wwid] "|" paths_all[wwid] "|" paths_failed[wwid] "|" paths_standby[wwid]
        }
    }' ${_TMP1_FILE} ${_TMP2_FILE} 2>/dev/null |\
while IFS='|' read -r _ _HW_PATH _ACTIVE_PATH_COUNT _ALL_PATH_COUNT _FAILED_PATH_COUNT _STANDBY_PATH_COUNT
do
    if [[ -z "${_ACTIVE_PATH_COUNT}" ]] ||
       [[ -z "${_ALL_PATH_COUNT}" ]] ||
       [[ -z "${_FAILED_PATH_COUNT}" ]] ||
       [[ -z "${_STANDBY_PATH_COUNT}" ]]
    then
        warn "missing info for ${_HW_PATH}, skipping LUN"
        continue
    fi

    # take standby paths out of the total path count (non-cabled FC ports)
    _ALL_PATH_COUNT=$(( _ALL_PATH_COUNT - _STANDBY_PATH_COUNT ))

    # check for failed paths
    if (( _FAILED_PATH_COUNT > 0 ))
    then
        _MSG="${_HW_PATH}: ${_FAILED_PATH_COUNT} failed lunpath(s)"
        _STC=1
    else
        _MSG="${_HW_PATH}: 0 failed lunpath(s)"
        _STC=0
    fi

    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}" ${_FAILED_PATH_COUNT} ${_ALL_PATH_COUNT}
    fi
done

# save ioscan info for posterity
printf "=== ioscan ===" >>${HC_STDOUT_LOG}
cat ${_TMP1_FILE} >>${HC_STDOUT_LOG}

# save scsimgr info for posterity
printf "\n\n=== scsimgr ===" >>${HC_STDOUT_LOG}
cat ${_TMP2_FILE} >>${HC_STDOUT_LOG}

# do cleanup
[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1
[[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
PURPOSE     : Check the active and failed (non-active) lunpaths of DISK devices
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
