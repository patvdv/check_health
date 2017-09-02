#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_aix_sysbackup.sh
#******************************************************************************
# @(#) Copyright (C) 2014 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_aix_sysbackup
# DOES: see _show_usage() 
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2013-05-28: initial version [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_aix_sysbackup
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
# mksysb identifier prefix of error code(s)
typeset _MKSYSB_NEEDLE="^0512"
typeset _VERSION="2013-05-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX"                      # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _BACKUP_PATH=""
typeset _BACKUP_HOST=""
typeset _BACKUP_LOG=""
typeset _BACKUP_AGE=0
typeset _MKSYSB_LOG=""
typeset _MKSYSB_CODE=""
typeset _COUNT=0

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
_BACKUP_PATH=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'backup_path')
if [[ -z "${_BACKUP_PATH}" ]]
then
    warn "ERROR: no value for the _BACKUP_PATH setting in ${_CONFIG_FILE}"
    return 1
fi
if [[ ! -d ${_BACKUP_PATH} ]]
then
    warn "ERROR: ${_BACKUP_PATH} does not exist"
    return 1
fi
_MKSYSB_LOG=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'mksysb_log')
if [[ -z "${_MKSYSB_LOG}" ]]
then
    warn "ERROR: no value for the _MKSYSB_LOG setting in ${_CONFIG_FILE}"
    return 1
fi
_BACKUP_AGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'backup_age')
case "${_BACKUP_AGE}" in
    +([0-9])*(.)*([0-9]))
        # numeric, OK
        ;;
    *) 
        # not numeric, set default
        _BACKUP_AGE=14
        ;;
esac

# perform state check on mksysb log files
ls -1 ${_BACKUP_PATH} | while read _BACKUP_HOST
do
    _BACKUP_LOG="${_BACKUP_PATH}/${_BACKUP_HOST}/curr/${_MKSYSB_LOG}"
    if [[ -r "${_BACKUP_LOG}" ]]
    then
        # read status from log file
        _MKSYSB_CODE=$(grep -E -e "${_MKSYSB_NEEDLE}" ${_BACKUP_LOG} 2>/dev/null)
        case "${_MKSYSB_CODE}" in
            # 0512-038 mksysb: Backup Completed Successfully
            0512-038*)
                _MSG="sysbackup status for ${_BACKUP_HOST}: completed successfully"
                ;;
            # 0512-003 mksysb may not have been able to archive some files
            0512-003*)
                _MSG="sysbackup status for ${_BACKUP_HOST}: completed with warnings"
                # save log
                print "=== ${_BACKUP_HOST} ===" >>${HC_STDOUT_LOG}
                cat ${_BACKUP_LOG} >>${HC_STDOUT_LOG}
                ;;          
            *)
                _MSG="sysbackup status for ${_BACKUP_HOST}: failed"
                _STC=1
                print "=== ${_BACKUP_HOST} ===" >>${HC_STDOUT_LOG}
                cat ${_BACKUP_LOG} >>${HC_STDOUT_LOG}
                ;;  
        esac
    else
        # don't flag this as erroneous, we could drop into this fork for
        # VIO servers for example without mksysb but having backupios instead 
        # caveat emptor: also means that hosts *without* backup go undetected
        continue
    fi
   
    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}"
    _STC=0
done

# perform age check on mksysb log files
ls -1 ${_BACKUP_PATH} | while read _BACKUP_HOST
do
    _BACKUP_LOG="${_BACKUP_PATH}/${_BACKUP_HOST}/curr/${_MKSYSB_LOG}"
    if [[ -r "${_BACKUP_LOG}" ]]
    then
        _COUNT=$(find "${_BACKUP_LOG}" -mtime +${_BACKUP_AGE} | wc -l)
        if (( _COUNT == 0 ))
        then
            _MSG="sysbackup age for ${_BACKUP_HOST}: <=${_BACKUP_AGE} days"
            _STC=0        
        else
            _MSG="sysbackup age for ${_BACKUP_HOST}: >${_BACKUP_AGE} days"
            _STC=1
            print "=== ${_BACKUP_HOST} ===" >>${HC_STDOUT_LOG}
            print "age: $(ls -l ${_BACKUP_LOG})" >>${HC_STDOUT_LOG}       
        fi
    else
        # don't flag this as erroneous, we could drop into this fork for
        # VIO servers for example without mksysb but having backupios instead 
        # caveat emptor: also means that hosts *without* backup go undetected
        continue
    fi
   
    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}"
    _STC=0
done
    
return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with:
            backup_path=<location_of_mksysb_images>
            mksysb_log=<name_of_standard_standard_mksysb_log>
            backup_age=<days_till_last_backup>
PURPOSE : Checks the state of saved mksysb client backups (should typically be 
          run only on the NIM master or server that is acting as mksysb repo,
          do NOT run on a typical client LPAR) 

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
