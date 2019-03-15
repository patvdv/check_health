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
# REQUIRES: count_log_errors(), die(), init_hc(), list_hc(), $EVENTS_DIR, $HC_LOG
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function report_std
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2019-03-18"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _DIR_PREFIX=""
typeset _ERROR_COUNT=0
typeset _ERROR_TOTAL_COUNT=0
typeset _HC_LAST=""
typeset _HC_LAST_TIME=""
typeset _HC_LAST_STC=0
typeset _HC_LAST_FAIL_ID="-"
typeset _ID_NEEDLE=""
typeset _IS_VALID_DATE=""
typeset _IS_VALID_ID=""
typeset _CHECK_FILE=""
typeset _LOG_FILE=""
typeset _LOG_FILES=""
typeset _LOG_STASH=""
typeset _SORT_CMD=""
typeset _LOG_MONTH=""
typeset _LOG_YEAR=""
typeset _OLDER_MONTH=""
typeset _OLDER_YEAR=""
typeset _NEWER_MONTH=""
typeset _NEWER_YEAR=""

# set archive log stash
if (( ARG_HISTORY > 0 )) || [[ -n "${ARG_OLDER}" ]] || [[ -n "${ARG_NEWER}" ]]
then
    set +f  # file globbing must be on
    _LOG_STASH="${ARCHIVE_DIR}/hc.*.log"
fi
# apply --newer or --older to log stash by intelligently selecting archive log files
if [[ -n "${_LOG_STASH}" ]]
then
    if [[ -n "${ARG_OLDER}" ]] || [[ -n "${ARG_NEWER}" ]]
    then
        (( ARG_DEBUG > 0 )) && debug "mangling archive log stash because we used --older/--newer"
        if [[ -n "${ARG_OLDER}" ]]
        then
            # check datestamp (should be YYYYMMDD)
            _IS_VALID_DATE=$(print "${ARG_OLDER}" | grep -c -E -e "^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])$" 2>/dev/null)
            (( _IS_VALID_DATE > 0 )) || die "invalid date for '--older' specified"
            # shellcheck disable=SC2003
            _OLDER_YEAR=$(expr substr "${ARG_OLDER}" 1 4 2>/dev/null)
            # shellcheck disable=SC2003
            _OLDER_MONTH=$(expr substr "${ARG_OLDER}" 5 2 2>/dev/null)
            (( ARG_DEBUG > 0 )) && debug "END date: ${_OLDER_YEAR}${_OLDER_MONTH}"
            # expand curent log stash (use for/do ~f*cking mskh)
            # shellcheck disable=SC2086
            _LOG_FILES=$(find ${_LOG_STASH} -type f 2>/dev/null | tr '\n' ' ' 2>/dev/null)
            _LOG_STASH=""
            for _LOG_FILE in ${_LOG_FILES}
            do
                # shellcheck disable=SC2003
                _LOG_YEAR=$(expr substr "$(basename ${_LOG_FILE} 2/dev/null)" 4 4 2>/dev/null)
                # shellcheck disable=SC2003
                _LOG_MONTH=$(expr substr "$(basename ${_LOG_FILE} 2/dev/null)" 9 2 2>/dev/null)
                (( ARG_DEBUG > 0 )) && debug "LOG date for ${_LOG_FILE}: ${_LOG_YEAR}${_LOG_MONTH}"
                # add log file to stash if file date <= older date; force arithemetic on strings
                if (( ${_LOG_YEAR}${_LOG_MONTH} <= ${_OLDER_YEAR}${_OLDER_MONTH} ))
                then
                    (( ARG_DEBUG > 0 )) && debug "push ${_LOG_FILE} to archive log stash"
                    _LOG_STASH="${_LOG_STASH} ${_LOG_FILE}"
                fi
            done
        fi
        if [[ -n "${ARG_NEWER}" ]]
        then
            # check datestamp (should be YYYYMMDD)
            _IS_VALID_DATE=$(print "${ARG_NEWER}" | grep -c -E -e "^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])$" 2>/dev/null)
            (( _IS_VALID_DATE > 0 )) || die "invalid date for '--newer' specified"
            # shellcheck disable=SC2003
            _NEWER_YEAR=$(expr substr "${ARG_NEWER}" 1 4)
            # shellcheck disable=SC2003
            _NEWER_MONTH=$(expr substr "${ARG_NEWER}" 5 2)
            (( ARG_DEBUG > 0 )) && debug "START date: ${_NEWER_YEAR}${_NEWER_MONTH}"
            # expand curent log stash (use for/do ~f*cking mskh)
            # shellcheck disable=SC2086
            _LOG_FILES=$(find ${_LOG_STASH} -type f 2>/dev/null | tr '\n' ' ' 2>/dev/null)
            _LOG_STASH=""
            for _LOG_FILE in ${_LOG_FILES}
            do
                # shellcheck disable=SC2003
                _LOG_YEAR=$(expr substr "$(basename ${_LOG_FILE} 2/dev/null)" 4 4)
                # shellcheck disable=SC2003
                _LOG_MONTH=$(expr substr "$(basename ${_LOG_FILE} 2/dev/null)" 9 2)
                (( ARG_DEBUG > 0 )) && debug "LOG date for ${_LOG_FILE}: ${_LOG_YEAR}${_LOG_MONTH}"
                # add log file to stash if file date <= older date; force arithemetic on strings
                if (( ${_LOG_YEAR}${_LOG_MONTH} >= ${_NEWER_YEAR}${_NEWER_MONTH} ))
                then
                    (( ARG_DEBUG > 0 )) && debug "push ${_LOG_FILE} to archive log stash"
                    _LOG_STASH="${_LOG_STASH} ${_LOG_FILE}"
                fi
            done
        fi
    fi
fi
# add current log file to log stash
_LOG_STASH="${HC_LOG} ${_LOG_STASH}"

# --last report
if (( ARG_LAST > 0 ))
then
    # shellcheck disable=SC1117
    printf "\n| %-40s | %-20s | %-14s | %-4s\n" "HC" "Timestamp" "FAIL ID" "STC (combined value)"
    # shellcheck disable=SC2183,SC1117
    printf "%120s\n" | tr ' ' -
    # loop over all HCs
    list_hc "list" | while read -r _HC_LAST
    do
        _HC_LAST_TIME=""
        _HC_LAST_STC=0
        _HC_LAST_FAIL_ID="-"
        # find last event or block of events (same timestamp)
        # (but unfortunately this is only accurate to events within the SAME second!)
        # shellcheck disable=SC2086
        _HC_LAST_TIME="$(grep -h ${_HC_LAST} ${_LOG_STASH} 2>/dev/null | sort -n 2>/dev/null | cut -f1 -d${LOG_SEP} 2>/dev/null | uniq 2>/dev/null | tail -1 2>/dev/null)"
        if [[ -z "${_HC_LAST_TIME}" ]]
        then
            _HC_LAST_TIME="-"
            _HC_LAST_STC="-"
        else
            # use of cat is not useless here, makes sure END {} gets executed even
            # if $_LOG STASH contains non-existing files (because of * wildcard)
            # shellcheck disable=SC2002,SC2086
            cat ${_LOG_STASH} 2>/dev/null | awk -F "${LOG_SEP}" -v needle_time="${_HC_LAST_TIME}" -v needle_hc="${_HC_LAST}" \
                '
                BEGIN {
                    last_stc     = 0
                    last_fail_id = "-"
                }
                {
                    if (($1 ~ needle_time && $2 ~ needle_hc) && NF <= '"${NUM_LOG_FIELDS}"') {
                        last_event_stc = $3
                        last_stc = last_stc + last_event_stc
                        last_event_fail_id = $5
                        if (last_event_fail_id != "") { last_fail_id = last_event_fail_id }
                    }
                }
                END {
                    print last_fail_id, last_stc
                }
                ' 2>/dev/null | read -r _HC_LAST_FAIL_ID _HC_LAST_STC
        fi
        # report on findings
        # shellcheck disable=SC1117
        printf "| %-40s | %-20s | %-14s | %-4s\n" \
            "${_HC_LAST}" "${_HC_LAST_TIME}" "${_HC_LAST_FAIL_ID}" "${_HC_LAST_STC}"
    done
    # disclaimer
    print "NOTE: this report only shows the overall combined status of all events of each HC within exactly"
    print "      the *same* time stamp (seconds precise). It may therefore fail to report certain FAIL IDs."
    print "      Use '--report' to get the exact list of failure events."
# other reports
else
    _ID_NEEDLE="[0-9][0-9]*"
    if [[ -n "${ARG_FAIL_ID}" ]]
    then
        # check FAIL_ID first (must be YYYYMMDDHHMMSS)
        _IS_VALID_ID=$(print "${ARG_FAIL_ID}" | grep -c -E -e "^[0-9]{4}(0[1-9]|1[0-2])(0[1-9]|[1-2][0-9]|3[0-1])([0-1][0-9]|2[0-3])([0-5][0-9])([0-5][0-9])$" 2>/dev/null)
        (( _IS_VALID_ID > 0 )) || die "invalid ID specified"
         _ID_NEEDLE="${ARG_FAIL_ID}"
    fi
    (( ARG_TODAY > 0 )) && _ID_NEEDLE="$(date '+%Y%m%d')"    # refers to timestamp of HC FAIL_ID

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
        # print failed events
        # not a useless use of cat here
        # (sort baulks if $_LOG STASH contains non-existing files (because of * wildcard))
        # shellcheck disable=SC2002,SC2086
        cat ${_LOG_STASH} 2>/dev/null | ${_SORT_CMD} 2>/dev/null | awk -F"${LOG_SEP}" \
            -v id_needle="${_ID_NEEDLE}" \
            -v older="${ARG_OLDER}" \
            -v newer="${ARG_NEWER}" \
            '
            BEGIN {
                event_count = 0
                if (older != "") { use_filter = 1; use_older = 1 }
                if (newer != "") { use_filter = 1; use_newer = 1 }
            }

            {
                # apply --older/--newer filter?
                if (use_filter > 0) {
                    # find log entries that are older than --older=<YYYYMMDD>
                    if (use_older > 0) {
                        log_date = substr($5, 1, 8);
                        if (log_date < older && $5 ~ id_needle && NF <= '"${NUM_LOG_FIELDS}"') {
                            events[event_count]=$0;
                            event_count++;
                        }
                    }
                    # find log entries that are newer than --older=<YYYYMMDD>
                    if (use_newer > 0) {
                        log_date = substr($5, 1, 8);
                        if (log_date > newer && $5 ~ id_needle && NF <= '"${NUM_LOG_FIELDS}"') {
                            events[event_count]=$0;
                            event_count++;
                        }
                    }
                # no --older/--newer filter
                } else {
                    if ($5 ~ id_needle && NF <= '"${NUM_LOG_FIELDS}"') {
                        events[event_count]=$0;
                        event_count++;
                    }
                }
            }

            END {
                if (event_count > 0) {
                    printf ("\n| %-20s | %-14s | %-40s | %-s\n", "Timestamp", "FAIL ID", "HC", "Message");
                    for (i=0; i<120; i++) { printf ("-"); }
                    # loop over array (sorted)
                    for (i=0; i<event_count; i++) {
                        split (events[i], event, "|");
                        printf ("\n| %-20s | %-14s | %-40s | %-s", event[1], event[5], event[2], event[4]);
                    }
                    printf ("\n\nSUMMARY: %s failed HC event(s) found.\n", event_count);
                } else {
                    printf ("\nSUMMARY: 0 failed HC events found.\n");
                }
            }
            ' 2>/dev/null
    else
        # print failed events (we may have multiple events for 1 FAIL ID)
        # not a useless use of cat here
        # (sort baulks if $_LOG STASH contains non-existing files (because of * wildcard))
        # shellcheck disable=SC2002,SC2086
        cat ${_LOG_STASH} 2>/dev/null | ${_SORT_CMD} 2>/dev/null | awk -F"${LOG_SEP}" -v id_needle="${_ID_NEEDLE}" \
            ' BEGIN {
                event_count = 1
                dashes = sprintf("%36s",""); gsub (/ /, "-", dashes);
            }
            {
                if ($5 ~ id_needle && NF <= '"${NUM_LOG_FIELDS}"') {
                    printf ("%36sMSG #%03d%36s", dashes, event_count, dashes)
                    printf ("\nTime    : %-s\nHC      : %-s\nDetail  : %-s\n", $1, $2, $4)
                    event_count++
                }
            }
            ' 2>/dev/null

        # shellcheck disable=SC2003,SC2086
        _DIR_PREFIX="$(expr substr ${ARG_FAIL_ID} 1 4 2>/dev/null)-$(expr substr ${ARG_FAIL_ID} 5 2 2>/dev/null)"
        # shellcheck disable=SC2183,SC1117
        printf "%37sSTDOUT%37s\n" | tr ' ' -;
        # display non-empty STDOUT file(s)
        # shellcheck disable=SC2086
        if [[ -n "$(du -a ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stdout.log 2>/dev/null | awk '$1*512 > 0 {print $2}')"  ]]
        then
            cat ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stdout.log
        else
            # shellcheck disable=SC1117
            printf "%-s\n" "No STDOUT found"
        fi

        # shellcheck disable=SC2183,SC1117
        printf "%37sSTDERR%37s\n" | tr ' ' -;
        # display non-empty STDERR file(s)
        # shellcheck disable=SC2086
        if [[ -n "$(du -a ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stderr.log 2>/dev/null | awk '$1*512 > 0 {print $2}')" ]]
        then
            cat ${EVENTS_DIR}/${_DIR_PREFIX}/${ARG_FAIL_ID}/*.stderr.log
        else
            # shellcheck disable=SC1117
            printf "%-s\n" "No STDERR found"
            fi

        # shellcheck disable=SC2183,SC1117
        printf "%80s\n" | tr ' ' -
    fi
fi

# general note: history or not?
if (( ARG_HISTORY > 0 ))
then
    print "NOTE: showing results with all history (archive) included (--with-history)"
else
    print "NOTE: showing results only of current log entries (use --with-history to view all entries)"
fi

# check consistency of log(s)
# shellcheck disable=SC2086
find ${_LOG_STASH} -type f -print 2>/dev/null | while read -r _CHECK_FILE
do
    _ERROR_COUNT=$(count_log_errors ${_CHECK_FILE})
    if (( _ERROR_COUNT > 0 ))
    then
        print "NOTE: found ${_ERROR_COUNT} rogue entr(y|ies) in log file ${_CHECK_FILE}"
        _ERROR_TOTAL_COUNT=$(( _ERROR_TOTAL_COUNT + _ERROR_COUNT ))
    fi
    _ERROR_COUNT=0
done
(( _ERROR_TOTAL_COUNT > 0 )) &&  print "NOTE: fix log errors with ${SCRIPT_NAME} --fix-logs [--with-history]"

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
