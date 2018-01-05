#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_fs_mounts_options.sh
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
# @(#) MAIN: check_hpux_fs_mounts_options
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2016-04-04: original version [Patrick Van der Veken]
# @(#) 2016-12-02: add support for ignore_missing_fs option [Patrick Van der Veken]
# @(#) 2017-07-31: added support for current/expected value output [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_fs_mounts_options
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2017-07-31"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CONFIG_FS=""
typeset _CONFIG_OPTS=""
typeset _CURR_OPTS=""
typeset _DUMMY=""
typeset _IGNORE_FS=""
typeset _IS_ACTIVE=0
typeset _FS_ENTRY=""
typeset _CFG_SORTED_OPTS=""
typeset _CURR_SORTED_OPTS=""

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
_IGNORE_FS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'ignore_missing_fs')
if [[ -z "${_IGNORE_FS}" ]]
then
    # default
    _IGNORE_FS="yes"
fi

# collect data (mount only)
mount >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
(( $? == 0)) || return $?

# check for each configured file system
grep -i '^fs:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _DUMMY _CONFIG_FS _CONFIG_OPTS
do
    # check for active FS
    _IS_ACTIVE=$(grep -c -E -e "^${_CONFIG_FS}[ \t].*" ${HC_STDOUT_LOG} 2>/dev/null)
    if (( _IS_ACTIVE == 0 )) && [[ "${_IGNORE_FS}" = "yes" ]]
    then
        # ignore event
        warn "${_CONFIG_FS} is not active, ignoring in the HC"
        continue
    else
        # find needle in mount output
        _FS_ENTRY=$(grep -E -e "^${_CONFIG_FS}[ \t]+on.*" ${HC_STDOUT_LOG} 2>/dev/null)
        # get real mount options
        _CURR_OPTS=$(print "${_FS_ENTRY}" | awk '{ print $4 }' | sed s'/dev=.*//g')

        # get real mount options: compressed & sorted (comma's + 'dev=' deleted)
        _CURR_SORTED_OPTS=$(print "${_CURR_OPTS}" | tr -d ',' | sed 's/./&\n/g'| sort | tr -d '\n')
        # get options to match: compressed & sorted (comma's deleted)
        _CFG_SORTED_OPTS=$(print "${_CONFIG_OPTS}" | tr -d ',' | sed 's/./&\n/g'| sort | tr -d '\n')

        # compare strings (also flags FS that are not mounted)
        if [[ "${_CURR_SORTED_OPTS}" != "${_CFG_SORTED_OPTS}" ]]
        then
                _MSG="${_CONFIG_FS} is not mounted with the correct options"
                _STC=1
        else
                _MSG="${_CONFIG_FS} is mounted with the correct options"
        fi
    fi

    # handle unit result
    log_hc "$0" ${_STC} "${_MSG}" "${_CURR_OPTS}" "${_CONFIG_OPTS}"
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
CONFIG  : $3 with formatted stanzas:
            fs:<my_fs1>:<my_fs_opts1>
          Other options:
            ignore_missing_fs=yes|no
PURPOSE : Checks whether file systems are mounted with correct options

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
