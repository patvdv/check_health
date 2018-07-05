#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_sg_qs_status.sh
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
# @(#) MAIN: check_linux_sg_qs_status
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2017-05-01: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_sg_qs_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2018-05-21"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
typeset _QS_BIN="/opt/qs/bin/qsc"
typeset _QS_AUTH_FILE="/opt/qs/conf/qs_authfile"
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

# check QS presence
if [[ ! -x ${_QS_BIN} ]] 
then
    warn "${_QS_BIN} is not installed here"
    return 1
fi

# ---- process state ----
(( $(pgrep -u root -f ${_QS_BIN} 2>>${HC_STDERR_LOG} | wc -l 2>/dev/null) == 0 )) && _STC=1

# evaluate results
case ${_STC} in
    0)
        _MSG="QS is running"
        ;;
    1)
        _MSG="QS is not running"
        ;;
    *)
        _MSG="could not determine status of QS"
        ;;
esac
log_hc "$0" ${_STC} "${_MSG}"

# ---- config state ----
if [[ -s ${_QS_AUTH_FILE} ]]
then
    _MSG="QS authorizations file has been configured"
    _STC=0
else
    _MSG="QS authorizations file is missing or empty (${_QS_AUTH_FILE})"
    _STC=1
fi
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
PURPOSE : Checks whether the Serviceguard quorum server is running

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
