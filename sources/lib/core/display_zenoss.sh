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
typeset _VERSION="2018-10-28"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _DISPLAY_HC="$1"
typeset _DISPLAY_FAIL_ID="$2"

typeset _DISPLAY_MSG_STC=""
typeset _DISPLAY_MSG_TIME=""
typeset _DISPLAY_MSG_TEXT=""
typeset _DISPLAY_MSG_CUR_VAL=""
typeset _DISPLAY_MSG_EXP_VAL=""

# parse $HC_MSG_VAR
if [[ -n "${HC_MSG_VAR}" ]]
then
    # shellcheck disable=SC2034
    print "${HC_MSG_VAR}" | while IFS=${MSG_SEP} read _DISPLAY_MSG_STC _DISPLAY_MSG_TIME _DISPLAY_MSG_TEXT _DISPLAY_MSG_CUR_VAL _DISPLAY_MSG_EXP_VAL
    do
        # magically unquote if needed
        if [[ -n "${_DISPLAY_MSG_TEXT}" ]]
        then
            data_contains_string "${_DISPLAY_MSG_TEXT}" "${MAGIC_QUOTE}"
            if (( $? > 0 ))
            then
                _DISPLAY_MSG_TEXT=$(data_magic_unquote "${_DISPLAY_MSG_TEXT}")
            fi
        fi
        if [[ -n "${_DISPLAY_MSG_CUR_VAL}" ]]
        then
            data_contains_string "${_DISPLAY_MSG_CUR_VAL}" "${MAGIC_QUOTE}"
            if (( $? > 0 ))
            then
                _DISPLAY_MSG_CUR_VAL=$(data_magic_unquote "${_DISPLAY_MSG_CUR_VAL}")
            fi
        fi
        if [[ -n "${_DISPLAY_MSG_EXP_VAL}" ]]
        then
            data_contains_string "${_DISPLAY_MSG_EXP_VAL}" "${MAGIC_QUOTE}"
            if (( $? > 0 ))
            then
                _DISPLAY_MSG_EXP_VAL=$(data_magic_unquote "${_DISPLAY_MSG_EXP_VAL}")
            fi
        fi
        if (( _DISPLAY_MSG_STC > 0 ))
        then
            printf "NOK|data1=%s data2=%s data3=%s data4=\"%s\" data5=%s data6=%s\n" \
                "${_DISPLAY_HC}" \
                "${_DISPLAY_MSG_STC}" \
                "${_DISPLAY_FAIL_ID}" \
                "${_DISPLAY_MSG_TEXT}" \
                "${_DISPLAY_MSG_CUR_VAL}" \
                "${_DISPLAY_MSG_EXP_VAL}"
        else
            printf "OK|data1=%s data2=%s data3=%s data4=\"%s\" data5=%s data6=%s\n" \
                "${_DISPLAY_HC}" \
                "${_DISPLAY_MSG_STC}" \
                "0" \
                "${_DISPLAY_MSG_TEXT}" \
                "${_DISPLAY_MSG_CUR_VAL}" \
                "${_DISPLAY_MSG_EXP_VAL}"
        fi
    done
fi

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
