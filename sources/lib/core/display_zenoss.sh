#!/usr/bin/env ksh
#******************************************************************************
# @(#) display_zenoss.sh
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
# @(#) MAIN: display_zenoss
# DOES: display HC results in a Zenoss like format. The format contains a status
#       field and 6 data fields:
#       OK/NOK|data1=<HC name> data2=<STC> data3=<FAIL ID> data4="<MSG>" data5=<current value> data6=<expected value>
# EXPECTS: 1=HC name [string], 2=HC FAIL_ID [string]
# RETURNS: 0
# REQUIRES: init_hc()
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function display_zenoss
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2017-12-20"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _DISPLAY_HC="$1"
typeset _DISPLAY_FAIL_ID="$2"

set -A _DISPLAY_MSG_STC
set -A _DISPLAY_MSG_TIME
set -A _DISPLAY_MSG_TEXT
set -A _DISPLAY_MSG_CUR_VAL
set -A _DISPLAY_MSG_EXP_VAL
typeset _I=0
typeset _MAX_I=0

# read HC_MSG_FILE into an arrays 
# note: this is less efficient but provides more flexibility for future extensions
#       max array size: 1023 in ksh88f, plugins spawning more than >1K messages are crazy :-)
while read HC_MSG_ENTRY
do
    _DISPLAY_MSG_STC[${_I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $1'})
    _DISPLAY_MSG_TIME[${_I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $2'})
    _DISPLAY_MSG_TEXT[${_I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $3'})
    _DISPLAY_MSG_CUR_VAL[${_I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $4'})
    _DISPLAY_MSG_EXP_VAL[${_I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $5'})
    _I=$(( _I + 1 ))
done <${HC_MSG_FILE} 2>/dev/null

# display HC results
_MAX_I=${#_DISPLAY_MSG_STC[*]}
_I=0
if (( _MAX_I > 0 ))
then
    while (( _I < _MAX_I ))    
    do
        if (( _DISPLAY_MSG_STC[${_I}] != 0 )) 
        then
            printf "NOK|data1=%s data2=%s data3=%s data4=\"%s\" data5=%s data6=%s\n" \
                "${_DISPLAY_HC}" \
                "${_DISPLAY_MSG_STC[${_I}]}" \
                "${_DISPLAY_FAIL_ID}" \
                "${_DISPLAY_MSG_TEXT[${_I}]}" \
                "${_DISPLAY_MSG_CUR_VAL[${_I}]}" \
                "${_DISPLAY_MSG_EXP_VAL[${_I}]}"
        else
            printf "OK|data1=%s data2=%s data3=%s data4=\"%s\" data5=%s data6=%s\n" \
                "${_DISPLAY_HC}" \
                "${_DISPLAY_MSG_STC[${_I}]}" \
                "0" \
                "${_DISPLAY_MSG_TEXT[${_I}]}" \
                "${_DISPLAY_MSG_CUR_VAL[${_I}]}" \
                "${_DISPLAY_MSG_EXP_VAL[${_I}]}"
        fi
        _I=$(( _I + 1 ))
    done
fi

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
