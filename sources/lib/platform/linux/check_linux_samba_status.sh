#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_samba_status.sh
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
# @(#) MAIN: check_linux_samba_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), linux_get_init(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2013-05-17: initial version [Patrick Van der Veken]
# @(#) 2016-12-01: added systemd code [Patrick Van der Veken]
# @(#) 2017-05-08: fix fall-back for sysv->pgrep [Patrick Van der Veken]
# @(#) 2017-07-23: fix for systemd service names [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_samba_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _SMB_INIT_SCRIPT="/etc/init.d/samba"
typeset _SMB_SYSTEMD_SERVICE="smb.service"
typeset _NMB_SYSTEMD_SERVICE="nmb.service"
typeset _VERSION="2018-05-21"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _RC=0

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;  
    esac
done

# 1) try using the init ways
linux_get_init
case "${LINUX_INIT}" in
    'systemd')
        # check running NMB
        systemctl --quiet is-active ${_NMB_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=1
        # check running SMB
        systemctl --quiet is-active ${_SMB_SYSTEMD_SERVICE} 2>>${HC_STDERR_LOG} || _STC=$(( _STC + 2 ))
        ;;
    'upstart')
        warn "code for upstart managed systems not implemented, NOOP"
        return 1
        ;;
    'sysv')
        # check running NMB/SMB
        if [[ -x ${_SMB_INIT_SCRIPT} ]]
        then
            if (( $(${_SMB_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i -E -e 'NMB.*is running.*' 2>/dev/null) == 0 ))
            then
                _STC=1
            fi
            # check running SMB
            if (( $(${_SMB_INIT_SCRIPT} status 2>>${HC_STDERR_LOG} | grep -c -i -E -e 'SMB.*is running.*' 2>/dev/null) == 0 ))
            then
                _STC=$(( _STC + 2 ))
            fi
        else
            warn "sysv init script not found {${_SMB_INIT_SCRIPT}}"
            _RC=1
        fi
        ;;
    *)
        _RC=1
        ;;
esac

# 2) try the pgrep way (note: old pgreps do not support '-c')
if (( _RC != 0 ))
then
    (( $(pgrep -u root nmbd 2>>${HC_STDERR_LOG}| wc -l 2>/dev/null) == 0 )) && _STC=1
    (( $(pgrep -u root smbd 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=$(( _STC + 2 ))
fi

# evaluate results
case ${_STC} in
    0)
        _MSG="NMB/SMB are running"
        ;;
    1)
        _MSG="NMB is not running"
        ;;
    2)
        _MSG="SMB is not running"
        ;;
    3)
        _MSG="NMB/SMB are not running"
        ;;
    *)
        _MSG="could not determine status of NMB/SMB"
        ;;
esac
log_hc "$0" ${_STC} "${_MSG}"

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3
PURPOSE : Checks whether SAMBA daemons are running

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
