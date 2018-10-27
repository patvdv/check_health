#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_aix_errpt.sh
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
# @(#) MAIN: check_aix_errpt
# DOES: see _show_usage()
# EXPECTS: n/a
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2013-05-15: initial version [Patrick Van der Veken]
# @(#) 2013-05-29: small fix errpt last check time [Patrick Van der Veken]
# @(#) 2013-06-24: big fix errpt last check time [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_aix_errpt
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX"                      # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _LAST_TIME_CHECK=""
typeset _LAST_TIME_FILE=""
typeset _LABEL=""
typeset _NEW_CHECK_TIME=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
    esac
done

# check for last known check date
_LAST_TIME_FILE="${STATE_DIR}/$0.lasttime"
if [[ -r ${_LAST_TIME_FILE} ]]
then
    if [[ -s ${_LAST_TIME_FILE} ]]
    then
        _LAST_TIME_CHECK="<${_LAST_TIME_FILE})"
    else
        warn "$0: no last known check date/time"
    fi
fi

# collect data
if [[ -z "${_LAST_TIME_CHECK}" ]]
then
    errpt -A >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
else
    errpt -s "${_LAST_TIME_CHECK}" |\
        grep -v "${_LAST_TIME_CHECK}" | grep -v "_IDENTIFIER" |\
        awk '{ print $1}' | uniq | while read _LABEL
        do
            errpt -a -j ${_LABEL} -s "${_LAST_TIME_CHECK}" \
                >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
        done
    (( $? == 0)) || return $?
fi

# do we have errors?
if [[ -s ${HC_STDOUT_LOG} ]]
then
    _MSG="new entries found in errpt: {$(grep -c '^LABEL' ${HC_STDOUT_LOG} 2>/dev/null)}"
    _STC=1
else
    _MSG="no new entries found in {errpt}"
fi

# update last known check date/time (potential race condition here,
# but we can live it :-))
_NEW_CHECK_TIME="$(errpt 2>/dev/null | head -n 2 | tail -n 1 | awk '{print $2}')"
# blank result indicates either no errpt entries or exist the time call failed
if [[ -n "${_NEW_CHECK_TIME}" ]]
then
    print "${_NEW_CHECK_TIME}" >${_LAST_TIME_FILE}
    (( $? == 0)) || warn "$0: unable to write last check time to ${_LAST_TIME_FILE}"
else
    warn "$0: no last check time received from errpt (no entries)"
fi

# handle results
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
PURPOSE : Checks AIX errpt for new error(s)

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
