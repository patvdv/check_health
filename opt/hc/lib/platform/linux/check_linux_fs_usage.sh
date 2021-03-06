#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_fs_usage.sh
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
# @(#) MAIN: check_linux_fs_usage
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2019-01-24: initial version [Patrick Van der Veken]
# @(#) 2019-01-27: regex fix [Patrick Van der Veken]
# @(#) 2019-01-30: refactored to support custom definitions with all
#                  filesystems check [Patrick Van der Veken]
# @(#) 2019-02-04: fix in cleanup [Patrick Van der Veken]
# @(#) 2019-02-18: fixes + help update [Patrick Van der Veken]
# @(#) 2019-03-25: exclude /dev/loop* + rationalization [Patrick Van der Veken]
# @(#) 2019-04-26: small string fix [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_fs_usage
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-04-26"                           # YYYY-MM-DD
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
typeset _CFG_CHECK_INODES_USAGE=""
typeset _CFG_CHECK_SPACE_USAGE=""
typeset _CFG_MAX_INODES_USAGE=""
typeset _CFG_MAX_SPACE_USAGE=""
typeset _CFG_INODES_THRESHOLD=""
typeset _CFG_SPACE_THRESHOLD=""
typeset _FS=""
typeset _DO_INODES=0
typeset _DO_SPACE=0
typeset _INODES_LIST=""
typeset _SPACE_LIST=""
typeset _INODES_USAGE=1
typeset _SPACE_USAGE=1

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
        check_inodes)
            log "enabled check of inodes usage via cmd-line option"
            _DO_INODES=1
            ;;
        check_space)
            log "enabled check of space usage via cmd-line option"
            _DO_SPACE=1
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
_CFG_CHECK_INODES_USAGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_inodes_usage')
case "${_CFG_CHECK_INODES_USAGE}" in
    yes|YES|Yes)
        log "enabled check of inodes usage via configuration file"
        _DO_INODES=1
        ;;
    *)
        :   # not set
        ;;
esac
_CFG_CHECK_SPACE_USAGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_space_usage')
case "${_CFG_CHECK_SPACE_USAGE}" in
    yes|YES|Yes)
        log "enabled check of space usage via configuration file"
        _DO_SPACE=1
        ;;
    *)
        :   # not set
        ;;
esac
_CFG_MAX_INODES_USAGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'max_inodes_usage')
if [[ -z "${_CFG_MAX_INODES_USAGE}" ]]
then
    # default
    _CFG_MAX_INODES_USAGE=90
fi
_CFG_MAX_SPACE_USAGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'max_space_usage')
if [[ -z "${_CFG_MAX_SPACE_USAGE}" ]]
then
    # default
    _CFG_MAX_SPACE_USAGE=90
fi
if (( _DO_INODES == 0 && _DO_SPACE == 0 ))
then
    warn "you must enable at least one check (inode and/or space)"
    return 1
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

# collect data (POSIX format)
if (( _DO_INODES > 0 ))
then
    _INODES_LIST=$(df -Pil 2>>${HC_STDERR_LOG})
    if (( $? > 0 ))
    then
        # df exits >0 if there are issues with some filesystems, consider non-fatal
        warn "error(s) occurred executing {df -Pil}"
    fi
fi
if (( _DO_SPACE > 0 ))
then
    _SPACE_LIST=$(df -Pl 2>>${HC_STDERR_LOG})
    if (( $? > 0 ))
    then
        # df exits >0 if there are issues with some filesystems, consider non-fatal
        warn "error(s) occurred executing {df -Pl}"
    fi
fi

# 1) validate inodes (df -Pil)
if (( _DO_INODES > 0 ))
then
    (( ARG_DEBUG > 0 )) && debug "checking inodes..."
    print -r "${_INODES_LIST}" | grep '^\/' 2>/dev/null | grep -v -E -e '^/dev/loop' 2>/dev/null | awk '{print $6}' 2>/dev/null |\
        while read -r _FS
    do
        (( ARG_DEBUG > 0 )) && debug "parsing inodes data for filesystem: ${_FS}"
        # add space to grep; must be non-greedy!
        _INODES_USAGE=$(print -r "${_INODES_LIST}" | grep -E -e " ${_FS}$" 2>/dev/null | awk '{gsub(/%/,"",$5);print $5}' 2>/dev/null)
        data_is_numeric "${_INODES_USAGE}"
        if (( $? > 0 ))
        then
            warn "discovered value for inodes usage is incorrect [${_FS}:${_INODES_USAGE}]"
            (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
            continue
        fi
        # which threshold to use (general or custom?)
        _CFG_FS_LINE=$(grep -E -e "^fs:${_FS}:" ${_CONFIG_FILE} 2>/dev/null)
        if [[ -n "${_CFG_FS_LINE}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "found custom definition for ${_FS} in configuration file ${_CONFIG_FILE}"
            _CFG_INODES_THRESHOLD=$(print "${_CFG_FS_LINE}" | cut -f3 -d':' 2>/dev/null)
            # null value means general threshold
            if [[ -z "${_CFG_INODES_THRESHOLD}" ]]
            then
                (( ARG_DEBUG > 0 )) && debug "found empty inodes threshold for ${_FS}, using general threshold"
                _CFG_INODES_THRESHOLD=${_CFG_MAX_INODES_USAGE}
            fi
            data_is_numeric "${_CFG_INODES_THRESHOLD}"
            if (( $? > 0 ))
            then
                warn "inodes parameter is not numeric for ${_FS} in configuration file ${_CONFIG_FILE}"
                continue
            fi
            # zero value means disabled check
            if (( _CFG_INODES_THRESHOLD == 0 ))
            then
                (( ARG_DEBUG > 0 )) && debug "found zero inodes threshold for ${_FS}, disabling check"
                continue
            fi
        else
            (( ARG_DEBUG > 0 )) && debug "no custom inodes threshold for ${_FS}, using general threshold"
            _CFG_INODES_THRESHOLD=${_CFG_MAX_INODES_USAGE}
        fi
        # check against the treshold
        if (( _INODES_USAGE > _CFG_INODES_THRESHOLD ))
        then
            _MSG="${_FS} exceeds its inode threshold (${_INODES_USAGE}%>${_CFG_INODES_THRESHOLD}%)"
            _STC=1
        else
            _MSG="${_FS} does not exceed its inode threshold (${_INODES_USAGE}%<=${_CFG_INODES_THRESHOLD}%)"
            _STC=0
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_INODES_USAGE}" "${_CFG_MAX_INODES_USAGE}"
        fi
    done
    # add df output to stdout log_hc
    print "==== df -Pil ====" >>${HC_STDOUT_LOG}
    print -r "${_INODES_LIST}" >>${HC_STDOUT_LOG}
fi

# 2) validate space (df -Pl)
if (( _DO_SPACE > 0 ))
then
    (( ARG_DEBUG > 0 )) && debug "checking space..."
    print -r "${_SPACE_LIST}" | grep '^\/' 2>/dev/null | grep -v -E -e '^/dev/loop' 2>/dev/null | awk '{print $6}' 2>/dev/null |\
        while read -r _FS
    do
        (( ARG_DEBUG > 0 )) && debug "parsing space data for filesystem: ${_FS}"
        # add space to grep; must be non-greedy!
        _SPACE_USAGE=$(print -r "${_SPACE_LIST}" | grep -E -e " ${_FS}$" 2>/dev/null | awk '{gsub(/%/,"",$5);print $5}' 2>/dev/null)
        data_is_numeric "${_SPACE_USAGE}"
        if (( $? > 0 ))
        then
            warn "discovered value for space usage is incorrect [${_FS}:${_SPACE_USAGE}]"
            (( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
            continue
        fi
        # which threshold to use (general or custom?)
        _CFG_FS_LINE=$(grep -E -e "^fs:${_FS}:" ${_CONFIG_FILE} 2>/dev/null)
        if [[ -n "${_CFG_FS_LINE}" ]]
        then
            (( ARG_DEBUG > 0 )) && debug "found custom definition for ${_FS} in configuration file ${_CONFIG_FILE}"
            _CFG_SPACE_THRESHOLD=$(print "${_CFG_FS_LINE}" | cut -f4 -d':' 2>/dev/null)
            # null value means general threshold
            if [[ -z "${_CFG_SPACE_THRESHOLD}" ]]
            then
                (( ARG_DEBUG > 0 )) && debug "found empty space threshold for ${_FS}, using general threshold"
                _CFG_SPACE_THRESHOLD=${_CFG_MAX_SPACE_USAGE}
            fi
            data_is_numeric "${_CFG_SPACE_THRESHOLD}"
            if (( $? > 0 ))
            then
                warn "space parameter is not numeric for ${_FS} in configuration file ${_CONFIG_FILE}"
                continue
            fi
            # zero value means disabled check
            if (( _CFG_SPACE_THRESHOLD == 0 ))
            then
                (( ARG_DEBUG > 0 )) && debug "found zero space threshold for ${_FS}, disabling check"
                continue
            fi
        else
            (( ARG_DEBUG > 0 )) && debug "no custom space threshold for ${_FS}, using general threshold"
            _CFG_SPACE_THRESHOLD=${_CFG_MAX_SPACE_USAGE}
        fi
        # check against the treshold
        if (( _SPACE_USAGE > _CFG_SPACE_THRESHOLD ))
        then
            _MSG="${_FS} exceeds its space threshold (${_SPACE_USAGE}%>${_CFG_SPACE_THRESHOLD}%)"
            _STC=1
        else
            _MSG="${_FS} does not exceed its space threshold (${_SPACE_USAGE}%<=${_CFG_SPACE_THRESHOLD}%)"
            _STC=0
        fi
        if (( _LOG_HEALTHY > 0 || _STC > 0 ))
        then
            log_hc "$0" ${_STC} "${_MSG}" "${_SPACE_USAGE}" "${_CFG_SPACE_THRESHOLD}"
        fi
    done
    # add df output to stdout log_hc
    print "==== df -Pl ====" >>${HC_STDOUT_LOG}
    print -r "${_SPACE_LIST}" >>${HC_STDOUT_LOG}
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
                check_inodes_usage=<yes|no>
                check_space_usage=<yes|no>
                max_inodes_usage=<general_inodes_usage_treshold>
                max_space_usage=<general_space_usage_treshold>
              with formatted stanzas (optional):
                fs:<fs_name>:<max_inodes_usage_%>:<max_space_usage_%>
EXT OPTIONS : --hc-args=check_inodes, --hc-args=check_space
PURPOSE     : Checks the inodes & space usage for the configured or all (local) filesystems
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
