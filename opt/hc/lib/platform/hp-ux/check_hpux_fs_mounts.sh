#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_fs_mounts.sh
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
# @(#) MAIN: check_hpux_fs_mounts
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2013-05-27: initial version [Patrick Van der Veken]
# @(#) 2016-04-04: exclude dump/swap spaces (...) [Patrick Van der Veken]
# @(#) 2016-07-04: fix for nfs exclusion [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_fs_mounts
{
# ------------------------- CONFIGURATION starts here -------------------------
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
typeset _FS=""
typeset _FS_COUNT=0

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

# collect data (mount only)
mount >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
if (( $? > 0 ))
then
    warn "unable to execute {mount} command"
    return 1
fi

# check for each configured file system (except / and dump/swap)
grep -v -E -e '^#' -e '^$' \
    -e '[[:space:]]*\/[[:space:]]+' -e '\.\.\.' /etc/fstab 2>/dev/null |\
    awk '{print $2}' 2>/dev/null |\
while read _FS
do
    _FS_COUNT=$(grep -c -E -e "^${_FS}[ \t]+on.*[ \t]+" ${HC_STDOUT_LOG} 2>/dev/null)
    case ${_FS_COUNT} in
        0)
            _MSG="${_FS} is not mounted"
            _STC=1
            ;;
        1)
            _MSG="${_FS} is mounted"
            ;;
        *)
            _MSG="${_FS} is multiple times mounted?"
            ;;
    esac

    # report result
    if (( _LOG_HEALTHY > 0 || _STC > 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
    fi
    _STC=0
done

# add /etc/fstab to STDOUT log
cat /etc/fstab >>${HC_STDOUT_LOG}

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
PURPOSE     : Checks whether file systems are mounted or not
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
