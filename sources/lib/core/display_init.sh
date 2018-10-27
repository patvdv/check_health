#!/usr/bin/env ksh
#******************************************************************************
# @(#) display_init.sh
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
# @(#) MAIN: display_init
# DOES: display HC results as boot/init-style messages (coloured stati)
# EXPECTS: 1=HC name [string], 2=HC FAIL_ID [string],
#          3=display code [string] (optional)
# RETURNS: 0
# REQUIRES: init_hc()
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function display_init
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2018-10-28"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _DISPLAY_HC="$1"
typeset _DISPLAY_FAIL_ID="$2"
typeset _DISPLAY_MSG_CODE="$3"

typeset _DISPLAY_MSG_STC=0
typeset _DISPLAY_HC_DESC=""
typeset _DISPLAY_CFG=""
typeset _DISPLAY_COLOR=""
typeset -R8 _DISPLAY_CODE=""
typeset _DISPLAY_ID=""

# check for terminal support (no ((...)) here)
if (( $(tput colors 2>/dev/null) > 0 ))
then
    typeset _RED=$(tput setaf 1)
    typeset _GREEN=$(tput setaf 2)
    typeset _YELLOW=$(tput setaf 3)
    typeset _BLUE=$(tput setaf 4)
    typeset _MAGENTA=$(tput setaf 5)
    typeset _CYAN=$(tput setaf 6)
    typeset _BOLD=$(tput bold)
    typeset _NORMAL=$(tput sgr0)
else
    typeset _RED=""
    typeset _GREEN=""
    typeset _YELLOW=""
    typeset _BLUE=""
    typeset _MAGENTA=""
    typeset _CYAN=""
    typeset _BOLD=""
    typeset _NORMAL=""
fi

# parse $HC_MSG_VAR
if [[ -n "${_DISPLAY_MSG_CODE}" ]]
then
    case "${_DISPLAY_MSG_CODE}" in
        ERROR|error)
            _DISPLAY_COLOR="${_MAGENTA}"
            ;;
        DISABLED|disabled)
            _DISPLAY_COLOR="${_CYAN}"
            ;;
        MISSING|missing)
            _DISPLAY_COLOR="${_BLUE}"
            ;;
        *)
            _DISPLAY_COLOR=""
            ;;
    esac
    _DISPLAY_CODE="${_DISPLAY_MSG_CODE}"
else
    if [[ -n "${HC_MSG_VAR}" ]]
    then
        print "${HC_MSG_VAR}" | while read _HC_MSG_ENTRY
        do
            # determine _DISPLAY_MSG_STC (sum of all STCs)
            _DISPLAY_MSG_STC=$(print "${_HC_MSG_ENTRY}" | awk -F"${MSG_SEP}" 'BEGIN { stc = 0 } { for (i=1;i<=NF;i++) { stc = stc + $1 } } END { print stc }' 2>/dev/null)
        done

        # display HC results
        if (( _DISPLAY_MSG_STC == 0 ))
        then
            _DISPLAY_CODE="OK"
            _DISPLAY_COLOR="${_GREEN}"
        else
            _DISPLAY_CODE="FAIL"
            _DISPLAY_COLOR="${_RED}"
            # check if we have a valid FAIL_ID
            if (( ARG_LOG == 1 ))
            then
                _DISPLAY_ID=" (${_BOLD}${_DISPLAY_FAIL_ID}${_NORMAL})"
            else
                _DISPLAY_ID=" (${_BOLD}not logged${_NORMAL})"
            fi
        fi
    else
        _DISPLAY_CODE="UNKNOWN"
        _DISPLAY_COLOR="${_YELLOW}"
    fi
fi

# check for alternative description, mangle _DISPLAY_HC
_DISPLAY_HC_DESC=$(grep -i "^hc:${HC_RUN}:" ${HOST_CONFIG_FILE} 2>/dev/null | cut -f4 -d':')
[[ -n "${_DISPLAY_HC_DESC}" ]] && _DISPLAY_HC="${_DISPLAY_HC_DESC}"

# check for alternative configuration file
if [[ -n "${ARG_CONFIG_FILE}" ]]
then
    # file name only
    _DISPLAY_CFG="${ARG_CONFIG_FILE##*/}"
else
    _DISPLAY_CFG="default config"
fi

# print status line (but also check for terminal support)

printf "%-30s %50s\t[ %8s ]%s\n" \
            "${_DISPLAY_HC}" \
            "(${_DISPLAY_CFG})" \
            "${_DISPLAY_COLOR}${_DISPLAY_CODE}${_NORMAL}" \
            "${_DISPLAY_ID}"

return 0
}

#******************************************************************************
# END of script
#**************************************************************************
