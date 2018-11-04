#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_drd_status.sh
#******************************************************************************
# @(#) Copyright (C) 2018 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_hpux_drd_status
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), data_get_lvalue_from_config(), data_date2epoch(),
#           data_lc(), data_strip_space(), data_strip_outer_space(),
#           dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2018-05-11: initial version [Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2018-10-18: changed boot status [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2018-10-31: better result check for DRD output [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_drd_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _DRD_BIN="/opt/drd/bin/drd"
typeset _VERSION="2018-10-31"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _RC=0
typeset _CHECK_CLONE=""
typeset _CHECK_SYNC=""
typeset _CLONE_MAX_AGE=30
typeset _SYNC_MAX_AGE=30
typeset _CLONE_DISK=""
typeset _ORIGINAL_DISK=""
typeset _ACTIVE_DISK=""
typeset _BOOTED_DISK=""
typeset _NOW_EPOCH=""
typeset _EFI_CLONE=""
typeset _EFI_ORIGINAL=""
typeset _CLONE_DATE=""
typeset _CLONE_YEAR=""
typeset _CLONE_MONTH=""
typeset _CLONE_DAY=""
typeset _CLONE_HOUR=""
typeset _CLONE_MINUTE=""
typeset _CLONE_SECOND=""
typeset _CLONE_EPOCH=""
typeset _SYNC_DATE=""
typeset _SYNC_YEAR=""
typeset _SYNC_MONTH=""
typeset _SYNC_DAY=""
typeset _SYNC_HOUR=""
typeset _SYNC_MINUTE=""
typeset _SYNC_SECOND=""
typeset _SYNC_EPOCH=""

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
# read required configuration values
_CHECK_CLONE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_clone')
if [[ -z "${_CHECK_CLONE}" ]]
then
    # default
    _CHECK_CLONE="yes"
fi
_CLONE_MAX_AGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'clone_age')
_CHECK_SYNC=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_sync')
if [[ -z "${_CHECK_SYNC}" ]]
then
    # default
    _CHECK_SYNC="yes"
fi
_SYNC_MAX_AGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'sync_age')

# get drd status
if [[ ! -x ${_DRD_BIN} ]]
then
    warn "${_DRD_BIN} is not installed here"
    return 1
else
    log "executing {${_DRD_BIN}} ..."
    # drd outputs on STDERR
    ${_DRD_BIN} status >${HC_STDOUT_LOG} 2>&1
    _RC=$?
    # check for result in output since _RC is not reliable
    grep -q -E -e "succeeded" ${HC_STDOUT_LOG} 2>/dev/null || _RC=1
fi

# check drd status
if (( _RC == 0 ))
then
    # convert NOW to epoch (pass date values as quoted parameters)
    _NOW_EPOCH=$(data_date2epoch "$(date '+%Y' 2>/dev/null)" "$(date '+%m' 2>/dev/null)" "$(date '+%d' 2>/dev/null)" "$(date '+%H' 2>/dev/null)" "$(date '+%M' 2>/dev/null)" "$(date '+%S' 2>/dev/null)")

    # get devices
    _ORIGINAL_DISK=$(data_strip_space "$(grep "Original Disk:" ${HC_STDOUT_LOG} 2>/dev/null | cut -f2 -d':')")
    _CLONE_DISK=$(data_strip_space "$(grep 'Clone Disk:' ${HC_STDOUT_LOG} 2>/dev/null | cut -f2 -d':')")

    _BOOTED_DISK=$(grep "Booted Disk:" ${HC_STDOUT_LOG} 2>/dev/null | cut -f2 -d'(' | cut -f1 -d ')')
    _ACTIVE_DISK=$(grep "Activated Disk:" ${HC_STDOUT_LOG} 2>/dev/null | cut -f2 -d'(' | cut -f1 -d ')')

    # check boot status: after a fresh clone -> booted == activated == original
    if [[ "${_ORIGINAL_DISK}" = "${_BOOTED_DISK}" ]] &&
        [[ "${_ORIGINAL_DISK}" = "${_ACTIVE_DISK}" ]] &&
        [[ "${_BOOTED_DISK}"  = "${_ACTIVE_DISK}" ]]
    then
        _MSG="host was booted from original disk (${_ACTIVE_DISK})"
        log_hc "$0" 0 "${_MSG}"
    else
        _MSG="host was booted from clone disk (${_ACTIVE_DISK})"
        log_hc "$0" 0 "${_MSG}"
    fi

    # check EFI status
    _EFI_CLONE=$(data_strip_outer_space "$(grep 'Clone EFI Partition:' ${HC_STDOUT_LOG} 2>/dev/null | cut -f2 -d':')")
    if [[ "${_EFI_CLONE}" = "AUTO file present, Boot loader present" ]]
    then
        _MSG="clone disk ${_CLONE_DISK} has a bootable EFI partition"
        log_hc "$0" 0 "${_MSG}"
    else
        _MSG="clone disk ${_CLONE_DISK} does not have a bootable EFI partition"
        log_hc "$0" 1 "${_MSG}"
    fi
    _EFI_ORIGINAL=$(data_strip_outer_space "$(grep 'Original EFI Partition:' ${HC_STDOUT_LOG} 2>/dev/null | cut -f2 -d':')")
    if [[ "${_EFI_ORIGINAL}" = "AUTO file present, Boot loader present" ]]
    then
        _MSG="original disk ${_ORIGINAL_DISK} has a bootable EFI partition"
        log_hc "$0" 0 "${_MSG}"
    else
        _MSG="original disk ${_ORIGINAL_DISK} does not have a bootable EFI partition"
        log_hc "$0" 1 "${_MSG}"
    fi

    # check clone age
    if [[ $(data_lc "${_CHECK_CLONE}") = "yes" ]]
    then
        # e.g.: 05/10/18 16:52:21 METDST (always in US format)
        _CLONE_DATE=$(data_strip_outer_space "$(grep 'Clone Creation Date:' ${HC_STDOUT_LOG} 2>/dev/null | cut -f2- -d':')")

        if [[ "${_CLONE_DATE}" != "None" ]]
        then
            # split into year/month/day/hour/minute/second
            _CLONE_YEAR=$(print "${_CLONE_DATE}" | awk '{ print $1 }' 2>/dev/null | cut -f3 -d'/')
            _CLONE_MONTH=$(print "${_CLONE_DATE}" | awk '{ print $1 }' 2>/dev/null | cut -f1 -d'/')
            _CLONE_DAY=$(print "${_CLONE_DATE}" | awk '{ print $1 }' 2>/dev/null | cut -f2 -d'/')

            _CLONE_HOUR=$(print "${_CLONE_DATE}" | awk '{ print $2 }' 2>/dev/null | cut -f1 -d':')
            _CLONE_MINUTE=$(print "${_CLONE_DATE}" | awk '{ print $2 }' 2>/dev/null | cut -f2 -d':')
            _CLONE_SECOND=$(print "${_CLONE_DATE}" | awk '{ print $2 }' 2>/dev/null | cut -f3 -d':')

            # convert _CLONE_DATE to epoch
            _CLONE_EPOCH=$(data_date2epoch "20${_CLONE_YEAR}" "${_CLONE_MONTH}" "${_CLONE_DAY}" "${_CLONE_HOUR}" "${_CLONE_MINUTE}" "${_CLONE_SECOND}")

            # check age
            if (( _CLONE_EPOCH > (_NOW_EPOCH - (_CLONE_MAX_AGE * 24 * 60 * 60)) ))
            then
                _MSG="clone age is younger than ${_CLONE_MAX_AGE} days [${_CLONE_DATE}]"
                log_hc "$0" 0 "${_MSG}"
            else
                _MSG="clone age is older than ${_CLONE_MAX_AGE} days [${_CLONE_DATE}]"
                log_hc "$0" 1 "${_MSG}"
            fi
        else
            _MSG="clone has not yet been created"
            log_hc "$0" 1 "${_MSG}"
        fi
    else
        log "not checking age of clone (see ${_CONFIG_FILE})"
    fi

    # check sync age
    if [[ $(data_lc "${_CHECK_SYNC}") = "yes" ]]
    then
        # e.g.: 05/10/18 16:52:21 METDST (always in US format)
        _SYNC_DATE=$(data_strip_outer_space "$(grep 'Last Sync Date:' ${HC_STDOUT_LOG} 2>/dev/null | cut -f2- -d':')")

        if [[ "${_SYNC_DATE}" != "None" ]]
        then
            # split into year/month/day/hour/minute/second
            _SYNC_YEAR=$(print "${_SYNC_DATE}" | awk '{ print $1 }' 2>/dev/null | cut -f3 -d'/')
            _SYNC_MONTH=$(print "${_SYNC_DATE}" | awk '{ print $1 }' 2>/dev/null | cut -f1 -d'/')
            _SYNC_DAY=$(print "${_SYNC_DATE}" | awk '{ print $1 }' 2>/dev/null | cut -f2 -d'/')

            _SYNC_HOUR=$(print "${_SYNC_DATE}" | awk '{ print $2 }' 2>/dev/null | cut -f1 -d':')
            _SYNC_MINUTE=$(print "${_SYNC_DATE}" | awk '{ print $2 }' 2>/dev/null | cut -f2 -d':')
            _SYNC_SECOND=$(print "${_SYNC_DATE}" | awk '{ print $2 }' 2>/dev/null | cut -f3 -d':')

            # convert _SYNC_DATE to epoch
            _SYNC_EPOCH=$(data_date2epoch "20${_SYNC_YEAR}" "${_SYNC_MONTH}" "${_SYNC_DAY}" "${_SYNC_HOUR}" "${_SYNC_MINUTE}" "${_SYNC_SECOND}")

            # check age
            if (( _SYNC_EPOCH > (_NOW_EPOCH - (_SYNC_MAX_AGE * 24 * 60 * 60)) ))
            then
                _MSG="sync age is younger than ${_SYNC_MAX_AGE} days [${_SYNC_DATE}]"
                log_hc "$0" 0 "${_MSG}"
            else
                _MSG="sync age is older than ${_SYNC_MAX_AGE} days [${_SYNC_DATE}]"
                log_hc "$0" 1 "${_MSG}"
            fi
        else
            _MSG="sync has not yet been executed"
            log_hc "$0" 1 "${_MSG}"
        fi
    else
        log "not checking age of sync (see ${_CONFIG_FILE})"
    fi
else
    _MSG="unable to run command: {${_DRD_BIN}}"
    log_hc "$0" 1 "${_MSG}"
    # dump debug info
    (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
    return 1
fi

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with:
            check_clone=<yes|no>
            clone_age=<max_age_of_clone_in_days>
            check_sync=<yes|no>
            sync_age=<max_age_of_sync_in_days>
PURPOSE : Checks whether the DRD clone was correctly created
          Checks for correct EFI partitions
          Checks the age of the DRD clone and/or sync

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
