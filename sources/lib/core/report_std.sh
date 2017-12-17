#!/usr/bin/env ksh
#******************************************************************************
# @(#) report_std.sh
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
# @(#) MAIN: report_std
# DOES: report HC events on STDOUT
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: init_hc(), list_hc(), $EVENTS_DIR, $HC_LOG
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function report_std
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2017-12-15"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _DIR_PREFIX=""
typeset _EVENT_COUNT=0
typeset _FAIL_COUNT=0
typeset _FAIL_F1=""
typeset _FAIL_F2=""
typeset _FAIL_F3=""
typeset _FAIL_F4=""
typeset _HC_LAST=""
typeset _HC_LAST_TIME=""
typeset _HC_LAST_STC=0
typeset _HC_LAST_FAIL_ID="-"
typeset _HC_LAST_EVENT_FAIL_ID=0
typeset _HC_LAST_EVENT_STC=""
typeset _ID_NEEDLE=""
typeset _REPORT_LINE=""
typeset _SORT_CMD=""

# --last report
if (( ARG_LAST != 0 ))
then
    printf "\n| %-30s | %-20s | %-14s | %-4s\n" "HC" "Timestamp" "FAIL ID" "STC (combined value)"
    printf "%100s\n" | tr ' ' -
    # loop over all HCs
    list_hc "list" | while read -r _HC_LAST
    do
        _HC_LAST_TIME=""
        _HC_LAST_STC=0
        _HC_LAST_FAIL_ID="-"
        # find last event or block of events (same timestamp)
        # (but unfortunately this is only accurate to events within the SAME second!)
        _HC_LAST_TIME="$(grep ${_HC_LAST} ${HC_LOG} 2>/dev/null | sort -n | cut -f1 -d${SEP} | uniq | tail -1)"
        if [[ -z "${_HC_LAST_TIME}" ]]
        then
            _HC_LAST_TIME="-"
            _HC_LAST_STC="-"
        else
            # find all STC codes for the last event and add them up
            grep "${_HC_LAST_TIME}${SEP}${HC_LAST}" ${HC_LOG} 2>/dev/null |\
            while read -r _REPORT_LINE
            do
                _HC_LAST_EVENT_STC=$(print "${_REPORT_LINE}" | cut -f3 -d"${SEP}")
                _HC_LAST_EVENT_FAIL_ID=$(print "${_REPORT_LINE}" | cut -f5 -d"${SEP}")
                _HC_LAST_STC=$(( _HC_LAST_STC + _HC_LAST_EVENT_STC ))
                [[ -n "${_HC_LAST_EVENT_FAIL_ID}" ]] && _HC_LAST_FAIL_ID="${_HC_LAST_EVENT_FAIL_ID}"
            done
        fi
        # report on findings
        printf "| %-30s | %-20s | %-14s | %-4s\n" \
            "${_HC_LAST}" "${_HC_LAST_TIME}" "${_HC_LAST_FAIL_ID}" "${_HC_LAST_STC}"
    done
    # disclaimer
    print "Note: this report only shows the overall combined status of all events of each HC within exactly"
    print "      the *same* time stamp (seconds precise). It may therefore fail to report certain FAIL IDs."
    print "      Use $0 --report to get the exact list of failure events."
# other reports
else
    _ID_NEEDLE="[0-9][0-9]*"
    [[ -n "${ARG_FAIL_ID}" ]] && _ID_NEEDLE="${ARG_FAIL_ID}"
    (( ARG_TODAY != 0 )) && _ID_NEEDLE="$(date '+%Y%m%d')"    # refers to timestamp of HC FAIL_ID

    # check fail count (look for unique IDs in the 5th field of the HC log)
    _FAIL_COUNT=$(cut -f5 -d"${SEP}" ${HC_LOG} 2>/dev/null | grep -E -e "${_ID_NEEDLE}" | uniq | wc -l)
    if (( _FAIL_COUNT != 0 ))
    then
        # check for detail or not?
        if (( ARG_DETAIL != 0 )) && (( _FAIL_COUNT != 1 ))
        then
            ARG_LOG=1 die "you must specify a unique FAIL_ID value"
        fi
        # reverse?
        if (( ARG_REVERSE == 0 ))
        then
            _SORT_CMD="sort -n"
        else
            _SORT_CMD="sort -rn"
        fi
        # global or detailed?
        if (( ARG_DETAIL == 0 ))
        then
            printf "\n| %-20s | %-14s | %-30s | %-s\n" \
                "Timestamp" "FAIL ID" "HC" "Message"
            printf "%120s\n" | tr ' ' -

            # print failed events
            # no extended grep here and no end $SEP!
            grep ".*${SEP}.*${SEP}.*${SEP}.*${SEP}${_ID_NEEDLE}" ${HC_LOG} 2>/dev/null |\
                ${_SORT_CMD} | while read -r _REPORT_LINE
            do
                _FAIL_F1=$(print "${_REPORT_LINE}" | cut -f1 -d"${SEP}")
                _FAIL_F2=$(print "${_REPORT_LINE}" | cut -f2 -d"${SEP}")
                _FAIL_F3=$(print "${_REPORT_LINE}" | cut -f4 -d"${SEP}")
                _FAIL_F4=$(print "${_REPORT_LINE}" | cut -f5 -d"${SEP}")

                printf "| %-20s | %-14s | %-30s | %-s\n" \
                    "${_FAIL_F1}" "${_FAIL_F4}" "${_FAIL_F2}" "${_FAIL_F3}"
            done

            printf "\n%-s\n" "SUMMARY: ${_FAIL_COUNT} failed HC event(s) found."
        else
            # print failed events (we may have multiple events for 1 FAIL ID)
            _EVENT_COUNT=1
            _DIR_PREFIX="$(expr substr ${ARG_FAIL_ID} 1 4)-$(expr substr ${ARG_FAIL_ID} 5 2)"
            # no extended grep here!
            grep ".*${SEP}.*${SEP}.*${SEP}.*${SEP}${_ID_NEEDLE}${SEP}" ${HC_LOG} 2>/dev/null |\
                ${_SORT_CMD} | while read -r _REPORT_LINE
            do
                _FAIL_F1=$(print "${_REPORT_LINE}" | cut -f1 -d"${SEP}")
                _FAIL_F2=$(print "${_REPORT_LINE}" | cut -f2 -d"${SEP}")
                _FAIL_F3=$(print "${_REPORT_LINE}" | cut -f4 -d"${SEP}")

                printf "%36sMSG #%03d%36s" "" ${_EVENT_COUNT} "" | tr ' ' -
                printf "\nTime    : %-s\nHC      : %-s\nDetail  : %-s\n" \
                    "${_FAIL_F1}" "${_FAIL_F2}" "${_FAIL_F3}"
                _EVENT_COUNT=$(( _EVENT_COUNT + 1 ))
            done

            printf "%37sSTDOUT%37s\n" | tr ' ' -;
            # display non-empty STDOUT file(s)
            if [[ -n "$(du -a ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stdout.log 2>/dev/null | awk '$1*512 > 0 {print $2}')"  ]]
            then
                cat ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stdout.log
            else
                printf "%-s\n" "No STDOUT found"
            fi

            printf "%37sSTDERR%37s\n" | tr ' ' -;
            # display non-empty STDERR file(s)
            if [[ -n "$(du -a ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stderr.log 2>/dev/null | awk '$1*512 > 0 {print $2}')" ]]
            then
                cat ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stderr.log
            else
                printf "%-s\n" "No STDERR found"
            fi

            printf "%80s\n" | tr ' ' -
        fi
    else
        printf "\n%-s\n" "SUMMARY: 0 failed HC events found."
    fi
fi

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
