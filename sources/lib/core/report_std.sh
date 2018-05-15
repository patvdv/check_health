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
typeset _VERSION="2018-04-29"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _DIR_PREFIX=""
typeset _FAIL_COUNT=0
typeset _HC_LAST=""
typeset _HC_LAST_TIME=""
typeset _HC_LAST_STC=0
typeset _HC_LAST_FAIL_ID="-"
typeset _ID_NEEDLE=""
typeset _LOG_STASH=""
typeset _REPORT_LINE=""
typeset _SORT_CMD=""

# which files do we need to examine
if (( ARG_HISTORY != 0 ))
then
    set +f  # file globbing must be on
    _LOG_STASH="${HC_LOG} ${ARCHIVE_DIR}/hc.*.log"
else
    _LOG_STASH="${HC_LOG}"
fi

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
        _HC_LAST_TIME="$(grep -h ${_HC_LAST} ${_LOG_STASH} 2>/dev/null | sort -n | cut -f1 -d${LOG_SEP} | uniq | tail -1)"
        if [[ -z "${_HC_LAST_TIME}" ]]
        then
            _HC_LAST_TIME="-"
            _HC_LAST_STC="-"
        else
            # use of cat is not useless here, makes sure END {} gets executed even
            # if $_LOG STASH contains non-existing files (because of * wildcard)
            cat ${_LOG_STASH} 2>/dev/null | awk -F "${LOG_SEP}" -v needle_time="${_HC_LAST_TIME}" -v needle_hc="${_HC_LAST}" \
                ' 
                BEGIN {
                    last_stc     = 0
                    last_fail_id = "-"
                }
                {
                    if ($1 ~ needle_time && $2 ~ needle_hc) {
                        last_event_stc = $3
                        last_stc = last_stc + last_event_stc
                        last_event_fail_id = $5
                        if (last_event_fail_id != "") { last_fail_id = last_event_fail_id }
                    }
                }
                END {
                    print last_fail_id, last_stc
                }
                ' 2>/dev/null | read _HC_LAST_FAIL_ID _HC_LAST_STC
        fi
        # report on findings
        printf "| %-30s | %-20s | %-14s | %-4s\n" \
            "${_HC_LAST}" "${_HC_LAST_TIME}" "${_HC_LAST_FAIL_ID}" "${_HC_LAST_STC}"
    done
    # disclaimer
    print "Note: this report only shows the overall combined status of all events of each HC within exactly"
    print "      the *same* time stamp (seconds precise). It may therefore fail to report certain FAIL IDs."
    print "      Use '--report' to get the exact list of failure events."
# other reports
else
    _ID_NEEDLE="[0-9][0-9]*"
    [[ -n "${ARG_FAIL_ID}" ]] && _ID_NEEDLE="${ARG_FAIL_ID}"
    (( ARG_TODAY != 0 )) && _ID_NEEDLE="$(date '+%Y%m%d')"    # refers to timestamp of HC FAIL_ID

    # check fail count (look for unique IDs in the 5th field of the HC log)
    _FAIL_COUNT=$(cut -f5 -d"${LOG_SEP}" ${_LOG_STASH} 2>/dev/null | grep -E -e "${_ID_NEEDLE}" | uniq | wc -l)
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
            # not a useless use of cat here 
            # (sort baulks if $_LOG STASH contains non-existing files (because of * wildcard))
            cat ${_LOG_STASH} 2>/dev/null | ${_SORT_CMD} 2>/dev/null | awk -F"${LOG_SEP}" -v id_needle="${_ID_NEEDLE}" \
                '
                {
                    if ($5 ~ id_needle) {
                        printf ("| %-20s | %-14s | %-30s | %-s\n", $1, $5, $2, $4)
                    }
                }
                ' 2>/dev/null
            printf "\n%-s\n" "SUMMARY: ${_FAIL_COUNT} failed HC event(s) found."
        else
            # print failed events (we may have multiple events for 1 FAIL ID)
            # not a useless use of cat here 
            # (sort baulks if $_LOG STASH contains non-existing files (because of * wildcard))
            cat ${_LOG_STASH} 2>/dev/null | ${_SORT_CMD} 2>/dev/null | awk -F"${LOG_SEP}" -v id_needle="${_ID_NEEDLE}" \
                ' BEGIN {
                    event_count = 1
                    dashes = sprintf("%36s",""); gsub (/ /, "-", dashes);
                }
                {
                    if ($5 ~ id_needle) {
                        printf ("%36sMSG #%03d%36s", dashes, event_count, dashes)
                        printf ("\nTime    : %-s\nHC      : %-s\nDetail  : %-s\n", $1, $2, $4)
                        event_count++
                    }
                }
                ' 2>/dev/null
                
            _DIR_PREFIX="$(expr substr ${ARG_FAIL_ID} 1 4)-$(expr substr ${ARG_FAIL_ID} 5 2)"
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
