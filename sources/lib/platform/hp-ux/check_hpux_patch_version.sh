#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_patch_version.sh
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
# @(#) MAIN: check_hpux_patch_version
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), data_get_lvalue_from_config(), data_dequote(),
#           dump_logs(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2018-05-11: initial version [Patrick Van der Veken]
# @(#) 2018-05-20: added dump_logs() [Patrick Van der Veken]
# @(#) 2018-10-22: added check on fileset state [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_patch_version
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _SWLIST_BIN="/usr/sbin/swlist"
typeset _SWLIST_OPTS=""
typeset _SHOW_PATCHES_BIN="/usr/contrib/bin/show_patches"
typeset _SHOW_PATCHES_OPTS=""
typeset _VERSION="2018-10-22"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _OE_VERSION=""
typeset _PATCH_LINE=""
typeset _CHECK_FILESETS=""
typeset _FILESET=""
typeset _FILESET_LINE=""
typeset _PATCHES=""
typeset _PATCH=""

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
_OE_VERSION=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'required_oe')
_PATCH_LINE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'required_patches')
if [[ -n "${_PATCH_LINE}" ]]
then
    # convert commas and strip quotes
    _PATCHES=$(data_comma2space $(data_dequote "${_PATCH_LINE}"))
fi
if [[ -z "${_CHECK_FILESETS}" ]]
then
    # default
    _CHECK_FILESETS="yes"
fi
_EXCLUDE_FILESETS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'exclude_filesets')
[[ -n "${_EXCLUDE_FILESETS}" ]] && log "excluding filesets: $(print ${_EXCLUDE_FILESETS})"
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

# check required tools
if [[ ! -x ${_SWLIST_BIN} ]]
then
    warn "${_SWLIST_BIN} is not installed here"
    return 1
fi
if [[ ! -x ${_SHOW_PATCHES_BIN} ]]
then
    warn "${_SHOW_PATCHES_BIN} is not installed here"
    return 1
fi

# get and check OE version
if [[ -n "${_OE_VERSION}" ]]
then
    if [[ ! -x ${_SWLIST_BIN} ]]
    then
        warn "${_SWLIST_BIN} is not installed here"
        return 1
    else
        if [[ -n "${_SWLIST_OPTS}" ]]
        then
            log "executing {${_SWLIST_BIN}} with options: ${_SWLIST_OPTS}"
            ${_SWLIST_BIN} ${_SWLIST_OPTS} >${HC_STDOUT_LOG} 2>${HC_STDERR_LOG}
        else
            log "executing {${_SWLIST_BIN}}"
            ${_SWLIST_BIN} >${HC_STDOUT_LOG} 2>${HC_STDERR_LOG}
            fi
    fi
    if (( $? == 0 ))
    then
        if (( $(grep -c -E -e "${_OE_VERSION}.*Operating Environment" ${HC_STDOUT_LOG} 2>/dev/null) > 0 ))
        then
            if (( _LOG_HEALTHY > 0 ))
            then
                _MSG="required OE with version ${_OE_VERSION} is installed"
                log_hc "$0" 0 "${_MSG}"
            fi
        else
            _MSG="required OE with version ${_OE_VERSION} is not installed"
            log_hc "$0" 1 "${_MSG}"
        fi
    else
        _MSG="unable to run command: {${_SWLIST_BIN}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi
else
    warn "required OE will not be checked (not configured in ${_CONFIG_FILE})"
fi

# get and check patches
if [[ -n "${_PATCHES}" ]]
then
    if [[ ! -x ${_SHOW_PATCHES_BIN} ]]
    then
        warn "${_SHOW_PATCHES_BIN} is not installed here"
        return 1
    else
        if [[ -n "${_SHOW_PATCHES_OPTS}" ]]
        then
            log "executing {${_SHOW_PATCHES_BIN}} with options: ${_SHOW_PATCHES_OPTS}"
            print "=== show_patches ===" >>${HC_STDOUT_LOG}
            ${_SHOW_PATCHES_BIN} ${_SHOW_PATCHES_OPTS} >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
        else
            log "executing {${_SHOW_PATCHES_BIN}}"
            print "=== show_patches ===" >>${HC_STDOUT_LOG}
            ${_SHOW_PATCHES_BIN} ${_SHOW_PATCHES_OPTS} >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
        fi
    fi
    if (( $? == 0 ))
    then
        for _PATCH in ${_PATCHES}
        do
            if (( $(grep -c "${_PATCH}" ${HC_STDOUT_LOG} 2>/dev/null) > 0 ))
            then
                if (( _LOG_HEALTHY > 0 ))
                then
                    _MSG="required patch ${_PATCH} is installed"
                    log_hc "$0" 0 "${_MSG}"
                fi
            else
                _MSG="required patch ${_PATCH} is not installed"
                log_hc "$0" 1 "${_MSG}"
            fi
        done
    else
        _MSG="unable to run command: {${_SHOW_PATCHES_BIN}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi
else
    warn "required patches will not be checked (not configured in ${_CONFIG_FILE})"
fi

# get and check (all) filesets
if [[ "${_CHECK_FILESETS}" = "yes" ]]
then
    _SWLIST_OPTS="-a state -l fileset"
    log "executing {${_SWLIST_BIN}} with options: ${_SWLIST_OPTS}"
    print "=== swlist ({$_SWLIST_OPTS}) ===" >>${HC_STDOUT_LOG}
    ${_SWLIST_BIN} ${_SWLIST_OPTS} >>${HC_STDOUT_LOG} 2>${HC_STDERR_LOG}

    if (( $? == 0 ))
    then
        grep -E -e "installed[[:space:]]*$" ${HC_STDOUT_LOG} 2>/dev/null |\
        while read _FILESET_LINE
        do
            _FILESET=$(print "${_FILESET_LINE}" | awk '{print $1}' 2>/dev/null)
            # check exclude(s)
            if [[ "${_EXCLUDE_FILESETS#*${_FILESET}}" = "${_EXCLUDE_FILESETS}" ]]
            then
                _MSG="fileset ${_FILESET} is not in a configured state"
                log_hc "$0" 1 "${_MSG}"
            fi
        done
    else
        _MSG="unable to run command: {${_SWLIST_BIN}}"
        log_hc "$0" 1 "${_MSG}"
        # dump debug info
        (( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
        return 1
    fi
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
            required_patches=<list_of_patches_to_check>
            required_oe=<OE_version>
PURPOSE : Checks whether the required OE (Operating Environment) version is installed
          Checks whether the required patches are installed

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
