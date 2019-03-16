#!/usr/bin/env ksh
#******************************************************************************
# @(#) include_core.sh
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
# @(#) MAIN: include_core
# DOES: helper functions
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
# @(#) FUNCTION: version_include_core()
# DOES: dummy function for version placeholder
# EXPECTS: n/a
# RETURNS: 0
function version_include_core
{
typeset _VERSION="2019-03-16"                               # YYYY-MM-DD

print "INFO: $0: ${_VERSION#version_*}"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: archive_hc()
# DOES: archive log entries for a given HC
# EXPECTS: HC name [string]
# RETURNS: 0=no archiving needed; 1=archiving OK; 2=archiving NOK
# REQUIRES: ${HC_LOG}
function archive_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_NAME="${1}"
typeset ARCHIVE_FILE=""
typeset ARCHIVE_RC=0
typeset YEAR_MONTH=""
typeset LOG_COUNT=0
typeset PRE_LOG_COUNT=0
typeset TODO_LOG_COUNT=0
typeset ARCHIVE_RC=0
typeset SAVE_HC_LOG="${HC_LOG}.$$"
typeset TMP1_FILE="${TMP_DIR}/.$0.tmp1.archive.$$"
typeset TMP2_FILE="${TMP_DIR}/.$0.tmp2.archive.$$"

# set local trap for cleanup
# shellcheck disable=SC2064
trap "rm -f ${TMP1_FILE} ${TMP2_FILE} ${SAVE_LOG_FILE} >/dev/null 2>&1; return 1" 1 2 3 15

# get pre-archive log co
PRE_LOG_COUNT=$(wc -l ${HC_LOG} 2>/dev/null | cut -f1 -d' ' 2>/dev/null)
if (( PRE_LOG_COUNT == 0 ))
then
    warn "${HC_LOG} is empty, nothing to archive"
    return 0
fi

# isolate messages from HC, find unique %Y-%m combinations
grep ".*${LOG_SEP}${HC_NAME}${LOG_SEP}" ${HC_LOG} 2>/dev/null |\
    cut -f1 -d"${LOG_SEP}" 2>/dev/null | cut -f1 -d' ' 2>/dev/null |\
    cut -f1-2 -d'-' 2>/dev/null | sort -u 2>/dev/null |\
    while read -r YEAR_MONTH
do
    # find all messages for that YEAR-MONTH combination
    grep "${YEAR_MONTH}.*${LOG_SEP}${HC_NAME}${LOG_SEP}" ${HC_LOG} >${TMP1_FILE}
    TODO_LOG_COUNT=$(wc -l ${TMP1_FILE} 2>/dev/null | cut -f1 -d' ' 2>/dev/null)
    log "# of entries in ${YEAR_MONTH} to archive: ${TODO_LOG_COUNT}"

    # combine existing archived messages and resort
    ARCHIVE_FILE="${ARCHIVE_DIR}/hc.${YEAR_MONTH}.log"
    cat ${ARCHIVE_FILE} ${TMP1_FILE} 2>/dev/null | sort -u >${TMP2_FILE} 2>/dev/null
    mv ${TMP2_FILE} ${ARCHIVE_FILE} 2>/dev/null || {
        warn "failed to move archive file, aborting"
        return 2
    }
    LOG_COUNT=$(wc -l ${ARCHIVE_FILE} 2>/dev/null | cut -f1 -d' ' 2>/dev/null)
    log "# of entries in ${ARCHIVE_FILE} now: ${LOG_COUNT}"

    # remove archived messages from the $HC_LOG (but create a backup first!)
    cp -p ${HC_LOG} ${SAVE_HC_LOG} 2>/dev/null
    # compare with the sorted $HC_LOG
    sort ${HC_LOG} >${TMP1_FILE}
    comm -23 ${TMP1_FILE} ${ARCHIVE_FILE} 2>/dev/null >${TMP2_FILE}

    # check archive action (HC_LOG should not be empty unless it contained
    # only messages from one single HC plugin before archival)
    if [[ -s ${TMP2_FILE} ]] || (( PRE_LOG_COUNT == TODO_LOG_COUNT ))
    then
        mv ${TMP2_FILE} ${HC_LOG} 2>/dev/null || {
            warn "failed to move HC log file, aborting"
            return 2
        }
        LOG_COUNT=$(wc -l ${HC_LOG} 2>/dev/null | cut -f1 -d' ' 2>/dev/null)
        log "# entries in ${HC_LOG} now: ${LOG_COUNT}"
        ARCHIVE_RC=1
    else
        warn "a problem occurred. Rolling back archival"
        mv ${SAVE_HC_LOG} ${HC_LOG} 2>/dev/null
        ARCHIVE_RC=2
    fi
done

# clean up temporary file(s)
rm -f ${TMP1_FILE} ${TMP2_FILE} ${SAVE_HC_LOG} >/dev/null 2>&1

return ${ARCHIVE_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: count_log_errors()
# DOES: check hc log file(s) for rogue entries (=lines with NF<>$NUM_LOG_FIELDS
#       or empty lines). Log entries may get scrambled if the append operation
#       in handle_hc() does not happen fully atomically.
#       This means that log entries are written without line separator (same line)
#       There is no proper way to avoid this without an extra file locking utility
# EXPECTS: path to log file to check
# OUTPUTS: number of errors [number]
# RETURNS: 0
# REQUIRES: n/a
function count_log_errors
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset LOG_STASH="${1}"
typeset ERROR_COUNT=0

ERROR_COUNT=$(cat ${LOG_STASH} 2>/dev/null | awk -F"${LOG_SEP}" '
    BEGIN { num = 0 }
    {
        if (NF>'"${NUM_LOG_FIELDS}"' || $0 == "") {
            num++;
        }
    }
    END { print num }' 2>/dev/null)

print ${ERROR_COUNT}

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: debug()
# DOES: handle debug messages
# EXPECTS: log message [string]
# RETURNS: 0
# REQUIRES: n/a
function debug
{
typeset LOG_LINE=""

print - "$*" | while read -r LOG_LINE
do
    print -u2 "DEBUG: ${LOG_LINE}"
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: die()
# DOES: handle fatal errors and exit script
# EXPECTS: log message [string]
# RETURNS: 0
# REQUIRES: n/a
function die
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset LOG_LINE=""

if [[ -n "${1}" ]]
then
    if (( ARG_LOG > 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            # shellcheck disable=SC2153
            print "${NOW}: ERROR: [$$]:" "${LOG_LINE}" >>${LOG_FILE}
        done
    fi
    print - "$*" | while read -r LOG_LINE
    do
        print -u2 "ERROR:" "${LOG_LINE}"
    done
fi

# finish up work
do_cleanup

exit 1
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: discover_core()
# DOES: discover core plugins
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: die()
function discover_core
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOTIFY_OPTS=""

# init global flags for core plugins (no typeset!)
DO_DISPLAY_CSV=0
DO_DISPLAY_INIT=0
DO_DISPLAY_JSON=0
DO_DISPLAY_TERSE=0
DO_DISPLAY_ZENOSS=0
DO_DISPLAY_CUSTOM1=0
DO_DISPLAY_CUSTOM2=0
DO_DISPLAY_CUSTOM3=0
DO_DISPLAY_CUSTOM4=0
DO_DISPLAY_CUSTOM5=0
DO_DISPLAY_CUSTOM6=0
DO_DISPLAY_CUSTOM7=0
DO_DISPLAY_CUSTOM8=0
DO_DISPLAY_CUSTOM9=0
DO_NOTIFY_EIF=0
DO_NOTIFY_MAIL=0
DO_NOTIFY_SMS=0
DO_REPORT_STD=0
HAS_DISPLAY_CSV=0
HAS_DISPLAY_INIT=0
HAS_DISPLAY_JSON=0
HAS_DISPLAY_TERSE=0
HAS_DISPLAY_ZENOSS=0
HAS_DISPLAY_CUSTOM1=0
HAS_DISPLAY_CUSTOM2=0
HAS_DISPLAY_CUSTOM3=0
HAS_DISPLAY_CUSTOM4=0
HAS_DISPLAY_CUSTOM5=0
HAS_DISPLAY_CUSTOM6=0
HAS_DISPLAY_CUSTOM7=0
HAS_DISPLAY_CUSTOM8=0
HAS_DISPLAY_CUSTOM9=0
HAS_NOTIFY_EIF=0
HAS_NOTIFY_MAIL=0
HAS_NOTIFY_SMS=0
HAS_REPORT_STD=0

# check which core display/notification plugins are installed
# do not use a while-do loop here because mksh/pdksh does not pass updated
# variables back from the sub shell (only works for true ksh88/ksh93)
# shellcheck disable=SC2010
for FFILE in $(ls -1 ${FPATH_PARENT}/core/*.sh 2>/dev/null | grep -v "include_" 2>/dev/null)
do
    case "${FFILE}" in
        *display_csv.sh)
            HAS_DISPLAY_CSV=1
            (( ARG_DEBUG > 0 )) && debug "display_csv plugin is available"
            ;;
        *display_init.sh)
            HAS_DISPLAY_INIT=1
            (( ARG_DEBUG > 0 )) && debug "display_init plugin is available"
            ;;
        *display_json.sh)
            HAS_DISPLAY_JSON=1
            (( ARG_DEBUG > 0 )) && debug "display_json plugin is available"
            ;;
        *display_terse.sh)
            HAS_DISPLAY_TERSE=1
            (( ARG_DEBUG > 0 )) && debug "display_terse plugin is available"
            ;;
        *display_zenoss.sh)
            HAS_DISPLAY_ZENOSS=1
            (( ARG_DEBUG > 0 )) && debug "display_zenoss plugin is available"
            ;;
        *display_custom1.sh)
            HAS_DISPLAY_CUSTOM1=1
            (( ARG_DEBUG > 0 )) && debug "display_custom1 plugin is available"
            ;;
        *display_custom2.sh)
            HAS_DISPLAY_CUSTOM2=1
            (( ARG_DEBUG > 0 )) && debug "display_custom2 plugin is available"
            ;;
        *display_custom3.sh)
            HAS_DISPLAY_CUSTOM3=1
            (( ARG_DEBUG > 0 )) && debug "display_custom3 plugin is available"
            ;;
        *display_custom4.sh)
            HAS_DISPLAY_CUSTOM4=1
            (( ARG_DEBUG > 0 )) && debug "display_custom4 plugin is available"
            ;;
        *display_custom5.sh)
            HAS_DISPLAY_CUSTOM5=1
            (( ARG_DEBUG > 0 )) && debug "display_custom5 plugin is available"
            ;;
        *display_custom6.sh)
            HAS_DISPLAY_CUSTOM6=1
            (( ARG_DEBUG > 0 )) && debug "display_custom6 plugin is available"
            ;;
        *display_custom7.sh)
            HAS_DISPLAY_CUSTOM7=1
            (( ARG_DEBUG > 0 )) && debug "display_custom7 plugin is available"
            ;;
        *display_custom8.sh)
            HAS_DISPLAY_CUSTOM8=1
            (( ARG_DEBUG > 0 )) && debug "display_custom8 plugin is available"
            ;;
        *display_custom9.sh)
            HAS_DISPLAY_CUSTOM9=1
            (( ARG_DEBUG > 0 )) && debug "display_custom9 plugin is available"
            ;;
        *notify_mail.sh)
            HAS_NOTIFY_MAIL=1
            (( ARG_DEBUG > 0 )) && debug "notify_mail plugin is available"
            ;;
        *notify_sms.sh)
            HAS_NOTIFY_SMS=1
            (( ARG_DEBUG > 0 )) && debug "notify_sms plugin is available"
            ;;
        *notify_eif.sh)
            HAS_NOTIFY_EIF=1
            (( ARG_DEBUG > 0 )) && debug "notify_eif plugin is available"
            ;;
        *report_std.sh)
            # shellcheck disable=SC2034
            HAS_REPORT_STD=1
            (( ARG_DEBUG > 0 )) && debug "report_std plugin is available"
            ;;
    esac
done

# check command-line parameters for core plugins
# --display
if [[ -n "${ARG_DISPLAY}" ]]
then
    case "${ARG_DISPLAY}" in
        csv) # csv format
            if (( HAS_DISPLAY_CSV == 1 ))
            then
                DO_DISPLAY_CSV=1
                ARG_VERBOSE=0
            else
                warn "csv plugin for '--display' not present"
            fi
            ;;
        init) # init/boot format
            if (( HAS_DISPLAY_INIT == 1 ))
            then
                DO_DISPLAY_INIT=1
                ARG_VERBOSE=0
            else
                warn "init plugin for '--display' not present"
            fi
            ;;
        json) # json format
            if (( HAS_DISPLAY_JSON == 1 ))
            then
                DO_DISPLAY_JSON=1
                ARG_VERBOSE=0
            else
                warn "json plugin for '--display' not present"
            fi
            ;;
        terse) # terse format
            if (( HAS_DISPLAY_TERSE == 1 ))
            then
                DO_DISPLAY_TERSE=1
                ARG_VERBOSE=0
            else
                warn "terse plugin for '--display' not present"
            fi
            ;;
        zenoss) # zenoss format
            if (( HAS_DISPLAY_ZENOSS == 1 ))
            then
                DO_DISPLAY_ZENOSS=1
                ARG_VERBOSE=0
            else
                warn "zenoss plugin for '--display' not present"
            fi
            ;;
        custom1) # custom1 format
            if (( HAS_DISPLAY_CUSTOM1 == 1 ))
            then
                DO_DISPLAY_CUSTOM1=1
                ARG_VERBOSE=0
            else
                warn "custom1 plugin for '--display' not present"
            fi
            ;;
        custom2) # custom2 format
            if (( HAS_DISPLAY_CUSTOM2 == 1 ))
            then
                DO_DISPLAY_CUSTOM2=1
                ARG_VERBOSE=0
            else
                warn "custom2 plugin for '--display' not present"
            fi
            ;;
        custom3) # custom3 format
            if (( HAS_DISPLAY_CUSTOM3 == 1 ))
            then
                DO_DISPLAY_CUSTOM3=1
                ARG_VERBOSE=0
            else
                warn "custom3 plugin for '--display' not present"
            fi
            ;;
        custom4) # custom4 format
            if (( HAS_DISPLAY_CUSTOM4 == 1 ))
            then
                DO_DISPLAY_CUSTOM4=1
                ARG_VERBOSE=0
            else
                warn "custom4 plugin for '--display' not present"
            fi
            ;;
        custom5) # custom5 format
            if (( HAS_DISPLAY_CUSTOM5 == 1 ))
            then
                DO_DISPLAY_CUSTOM5=1
                ARG_VERBOSE=0
            else
                warn "custom5 plugin for '--display' not present"
            fi
            ;;
        custom6) # custom6 format
            if (( HAS_DISPLAY_CUSTOM6 == 1 ))
            then
                DO_DISPLAY_CUSTOM6=1
                ARG_VERBOSE=0
            else
                warn "custom6 plugin for '--display' not present"
            fi
            ;;
        custom7) # custom7 format
            if (( HAS_DISPLAY_CUSTOM7 == 1 ))
            then
                DO_DISPLAY_CUSTOM7=1
                ARG_VERBOSE=0
            else
                warn "custom7 plugin for '--display' not present"
            fi
            ;;
        custom8) # custom8 format
            if (( HAS_DISPLAY_CUSTOM8 == 1 ))
            then
                DO_DISPLAY_CUSTOM8=1
                ARG_VERBOSE=0
            else
                warn "custom8 plugin for '--display' not present"
            fi
            ;;
        custom9) # custom9 format
            if (( HAS_DISPLAY_CUSTOM9 == 1 ))
            then
                DO_DISPLAY_CUSTOM9=1
                ARG_VERBOSE=0
            else
                warn "custom9 plugin for '--display' not present"
            fi
            ;;
        *) # stdout default
            ;;
    esac
fi
# --notify
if [[ -n "${ARG_NOTIFY}" ]]
then
    # do not use a while-do loop here because mksh/pdksh does not pass updated
    # variables back from the sub shell (only works for true ksh88/ksh93)
    for NOTIFY_OPTS in $(print "${ARG_NOTIFY}" | tr ',' ' ' 2>/dev/null)
    do
        case "${NOTIFY_OPTS}" in
            *eif*) # by ITM
                DO_NOTIFY_EIF=1
                ;;
            *mail*) # by mail
                DO_NOTIFY_MAIL=1
                ;;
            *sms*) # by sms
                DO_NOTIFY_SMS=1
                ;;
            *) # no valid option
                die "you have specified an invalid option for '--notify'"
                ;;
        esac
    done
fi
# --report
if [[ -n "${ARG_REPORT}" ]]
then
    # do not use a while-do loop here because mksh/pdksh does not pass updated
    # variables back from the sub shell (only works for true ksh88/ksh93)
    for REPORT_OPTS in $(print "${ARG_REPORT}" | tr ',' ' ' 2>/dev/null)
    do
        case "${REPORT_OPTS}" in
            *std*) # STDOUT
                DO_REPORT_STD=1
                ;;
            *) # no valid option
                die "you have specified an invalid option for '--report'"
                ;;
        esac
    done
fi
# --mail-to/--notify
if [[ -n "${ARG_MAIL_TO}" ]] && (( DO_NOTIFY_MAIL == 0 ))
then
    die "you cannot specify '--mail-to' without '--notify=mail'"
fi
if (( DO_NOTIFY_MAIL > 0 )) && [[ -z "${ARG_MAIL_TO}" ]]
then
    die "you cannot specify '--notify=mail' without '--mail-to'"
fi
# --sms-to/--sms-provider/--notify
if [[ -n "${ARG_SMS_TO}" ]] && (( DO_NOTIFY_SMS == 0 ))
then
    die "you cannot specify '--sms-to' without '--notify=sms'"
fi
if [[ -n "${ARG_SMS_PROVIDER}" ]] && (( DO_NOTIFY_SMS == 0 ))
then
    die "you cannot specify '--sms-provider' without '--notify=sms'"
fi
if (( DO_NOTIFY_SMS > 0 )) && [[ -z "${ARG_SMS_TO}" ]]
then
    die "you cannot specify '--notify=sms' without '--sms-to'"
fi
if (( DO_NOTIFY_SMS > 0 )) && [[ -z "${ARG_SMS_PROVIDER}" ]]
then
    die "you cannot specify '--notify=sms' without '--sms-provider'"
fi
# --report/--detail/--id/--reverse/--last/--today/--with-history/--older/--newer
if (( DO_REPORT_STD > 0 ))
then
    if (( ARG_DETAIL > 0 )) && [[ -z "${ARG_FAIL_ID}" ]]
    then
        die "you must specify an unique value for '--id' when using '--detail'"
    fi
    if (( ARG_LAST > 0 )) && (( ARG_TODAY > 0 ))
    then
        die "you cannot specify '--last' with '--today'"
    fi
    if (( ARG_LAST > 0 )) && (( ARG_DETAIL > 0 ))
    then
        die "you cannot specify '--last' with '--detail'"
    fi
    if (( ARG_LAST > 0 )) && (( ARG_REVERSE > 0 ))
    then
        die "you cannot specify '--last' with '--detail'"
    fi
    if (( ARG_LAST > 0 )) && [[ -n "${ARG_FAIL_ID}" ]]
    then
        die "you cannot specify '--last' with '--id'"
    fi
    if (( ARG_LAST > 0 )) && [[ -n "${ARG_OLDER}" ]]
    then
        die "you cannot specify '--last' with '--older'"
    fi
    if (( ARG_LAST > 0 )) && [[ -n "${ARG_NEWER}" ]]
    then
        die "you cannot specify '--last' with '--newer'"
    fi
    if (( ARG_TODAY > 0 )) && (( ARG_DETAIL > 0 ))
    then
        die "you cannot specify '--today' with '--detail'"
    fi
    if (( ARG_TODAY > 0 )) && (( ARG_REVERSE > 0 ))
    then
        die "you cannot specify '--today' with '--detail'"
    fi
    if (( ARG_TODAY > 0 )) && [[ -n "${ARG_FAIL_ID}" ]]
    then
        die "you cannot specify '--today' with '--id'"
    fi
    if (( ARG_TODAY > 0 )) && [[ -n "${ARG_OLDER}" ]]
    then
        die "you cannot specify '--today' with '--older"
    fi
    if (( ARG_TODAY > 0 )) && [[ -n "${ARG_NEWER}" ]]
    then
        die "you cannot specify '--today' with '--newer'"
    fi
    if [[ -n "${ARG_OLDER}" ]] && [[ -n "${ARG_NEWER}" ]]
    then
        die "you cannot use '--older' with '--newer'"
    fi
    if [[ -n "${ARG_FAIL_ID}" ]] && [[ -n "${ARG_OLDER}" ]]
    then
        die "you cannot use '--id' with '--older'"
    fi
    if [[ -n "${ARG_FAIL_ID}" ]] && [[ -n "${ARG_NEWER}" ]]
    then
        die "you cannot use '--id' with '--newer'"
    fi
fi
if (( DO_REPORT_STD == 0 )) && (( ARG_LAST > 0 ))
then
    die "you cannot specify '--last' without '--report'"
fi
if (( DO_REPORT_STD == 0 )) && (( ARG_REVERSE > 0 ))
then
    die "you cannot specify '--reverse' without '--report'"
fi
if (( DO_REPORT_STD == 0 )) && (( ARG_DETAIL > 0 ))
then
    die "you cannot specify '--detail' without '--report'"
fi
if (( DO_REPORT_STD == 0 )) && [[ -n "${ARG_FAIL_ID}" ]]
then
    die "you cannot specify '--id' without '--report'"
fi
if (( DO_REPORT_STD == 0 )) && [[ -n "${ARG_OLDER}" ]]
then
    die "you cannot specify '--older' without '--report'"
fi
if (( DO_REPORT_STD == 0 )) && [[ -n "${ARG_NEWER}" ]]
then
    die "you cannot specify '--newer' without '--report'"
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: dump_logs()
# DOES: current STDOUT+STDERR log via log()
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function dump_logs
{
log "=== STDOUT ==="
log "$(<${HC_STDOUT_LOG})"
log "=== STDERR ==="
log "$(<${HC_STDERR_LOG})"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: exists_hc()
# DOES: check if a HC (function) exists in $FPATH
# EXPECTS: health check name [string]
# RETURNS: 0=HC not found; 1=HC found
# REQUIRES: n/a
function exists_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset EXISTS_HC="${1}"
typeset FDIR=""
typeset EXISTS_RC=0

# do not use a while-do loop here because mksh/pdksh does not pass updated
# variables back from the sub shell (only works for true ksh88/ksh93)
for FDIR in $(print "${FPATH}" | tr ':' ' ' 2>/dev/null)
do
    data_contains_string "${FDIR}" "core"
    # shellcheck disable=SC2181
    if (( $? == 0 ))
    then
        ls "${FDIR}/${EXISTS_HC}" >/dev/null 2>&1 && EXISTS_RC=1
    fi
done

return ${EXISTS_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: find_hc()
# DOES: find location of a HC (function) in $FPATH
# EXPECTS: health check name [string]
# RETURNS: file location [string]
# REQUIRES: n/a
function find_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FIND_HC="${1}"
typeset FDIR=""

print "${FPATH}" | tr ':' '\n' | grep -v "core$" | while read -r FDIR
do
    ls "${FDIR}/${FIND_HC}" >/dev/null 2>&1 && print "${FDIR}/${FIND_HC}"
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: fix_logs()
# DOES: fix hc log file(s) with rogue entries
# EXPECTS: n/a
# REQUIRES: n/a
# RETURNS: 0=no fix needed; 1=fix OK; 2=fix NOK
# NOTE: this routine rewrites the HC log(s). Since we cannot use file locking,
#       some log entries may be lost if the HC is accessing the HC log during
#       the rewrite operation!!
function fix_logs
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FIX_FILE=""
typeset FIX_RC=0
typeset LOG_STASH=""
typeset EMPTY_COUNT=0
typeset ERROR_COUNT=0
typeset STASH_COUNT=0
typeset TMP_COUNT=0
typeset SAVE_TMP_FILE="${TMP_DIR}/.$0.save.log.$$"
typeset TMP_FILE="${TMP_DIR}/.$0.tmp.log.$$"

if (( ARG_HISTORY > 0 ))
then
    set +f  # file globbing must be on
    LOG_STASH="${HC_LOG} ${ARCHIVE_DIR}/hc.*.log"
else
    LOG_STASH="${HC_LOG}"
fi

# set local trap for clean-up
# shellcheck disable=SC2064
trap "[[ -f ${TMP_FILE} ]] && rm -f ${TMP_FILE} >/dev/null 2>&1; return 1" 1 2 3 15

# check and rewrite log file(s)
find ${LOG_STASH} -type f -print 2>/dev/null | while read -r FIX_FILE
do
    log "fixing log file ${FIX_FILE} ..."

    # count before rewrite
    STASH_COUNT=$(wc -l ${FIX_FILE} 2>/dev/null | cut -f1 -d' ' 2>/dev/null)

    # does it have errors?
    ERROR_COUNT=$(count_log_errors ${FIX_FILE})

    # we count the empty lines (again)
    EMPTY_COUNT=$(grep -c -E -e '^$' ${FIX_FILE} 2>/dev/null)

    # rewrite if needed
    if (( ERROR_COUNT > 0 ))
    then
        : >${TMP_FILE} 2>/dev/null
        cat ${FIX_FILE} 2>/dev/null | awk -F"${LOG_SEP}" -v OFS="${LOG_SEP}" '

            BEGIN { max_log_fields = '"${NUM_LOG_FIELDS}"'
                    max_fields = (max_log_fields - 1) * 2
                    glue_field = max_log_fields - 1
            }

            # Fix log lines that were smashed together because of unatomic appends
            # This can lead to 4 distinct cases that we need to rewrite based on
            # whether a FAIL_ID is present in each part of the log line.
            # Following examples are based on a log file with 5 standard fields:
            #   case 1: NO  (FAIL_ID) +  NO  (FAIL_ID) ->  9 fields
            #   case 2: NO  (FAIL_ID) +  YES (FAIL_ID) -> 10 fields
            #   case 3: YES (FAIL_ID) +  NO  (FAIL_ID) -> 10 fields
            #   case 4: YES (FAIL_ID) +  YES (FAIL_ID) -> 11 fields

            {
                if (NF > max_log_fields) {
                    # rogue line that needs rewriting
                    if (NF < max_fields) {
                        # case 1
                        for (i=1;i<max_log_fields-1;i++) {
                            printf ("%s%s", $i, OFS)
                        }
                        printf ("\n")
                        if ($NF ~ //) {
                            for (i=max_log_fields-1;i<NF;i++) {
                                printf ("%s%s", $i, OFS)
                            }
                        } else {
                            for (i=max_log_fields-1;i<=NF;i++) {
                                printf ("%s%s", $i, OFS)
                            }
                        }
                    } else {
                        if ($max_fields == "") {
                            # case 2+3
                            # is the glue field a DATE or FAIL_ID?
                            if ($glue_field ~ /[:-]/) {
                                # it is a DATE (belongs to next line)
                                for (i=1;i<max_log_fields-1;i++) {
                                    printf ("%s%s", $i, OFS)
                                }
                                printf ("\n")
                                for (i=max_log_fields-1;i<NF;i++) {
                                    printf ("%s%s", $i, OFS)
                                }
                            } else {
                                # it is a FAIL_ID (belongs to this line)
                                for (i=1;i<max_log_fields;i++) {
                                    printf ("%s%s", $i, OFS)
                                }
                                printf ("\n")
                                for (i=max_log_fields;i<NF;i++) {
                                    printf ("%s%s", $i, OFS)
                                }
                            }
                        } else {
                            # case 4
                            for (i=1;i<max_log_fields;i++) {
                                printf ("%s%s", $i, OFS)
                            }
                            printf ("\n")
                            for (i=max_log_fields;i<NF;i++) {
                                printf ("%s%s", $i, OFS)
                            }
                        }
                    }
                    printf ("\n")
                } else if ($0 == "") {
                    # skip empty line
                    next;
                } else {
                    # correct log line, no rewrite needed
                    print $0
                }
            }' >${TMP_FILE} 2>/dev/null

        # count after rewrite (include empty lines again in the count)
        TMP_COUNT=$(wc -l ${TMP_FILE} 2>/dev/null | cut -f1 -d' ' 2>/dev/null)
        TMP_COUNT=$(( TMP_COUNT + EMPTY_COUNT ))

        # bail out when we do not have enough records
        if (( TMP_COUNT < STASH_COUNT ))
        then
            warn "found inconsistent record count (${TMP_COUNT}<${STASH_COUNT}), aborting"
            return 2
        fi

        # swap log file (but create a backup first!)
        cp -p ${FIX_FILE} ${SAVE_TMP_FILE} 2>/dev/null
        # shellcheck disable=SC2181
        if (( $? == 0 ))
        then
            mv ${TMP_FILE} ${FIX_FILE} 2>/dev/null
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                warn "failed to move/update log file, rolling back"
                mv ${SAVE_TMP_FILE} ${FIX_FILE} 2>/dev/null
                return 2
            fi
            FIX_RC=1
        else
            warn "failed to create a backup of original log file, aborting"
            return 2
        fi

        # clean up temporary file(s)
        rm -f ${SAVE_TMP_FILE} ${TMP_FILE} >/dev/null 2>&1
    else
        log "no fixing needed for ${FIX_FILE}"
    fi

    ERROR_COUNT=0
done

return ${FIX_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: handle_hc()
# DOES: handle HC results
# EXPECTS: 1=HC name [string], $HC_MSG_FILE temporary file
# RETURNS: 0 or $HC_STC_RC
# REQUIRES: die(), display_*(), notify_*(), warn()
function handle_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_NAME="${1}"
typeset HC_STDOUT_LOG_SHORT=""
typeset HC_STDERR_LOG_SHORT=""
typeset HC_STC_RC=0
typeset ONE_MSG_STC=0
typeset ONE_MSG_TIME=""
typeset ONE_MSG_TEXT=""
typeset ONE_MSG_CUR_VAL=""
typeset ONE_MSG_EXP_VAL=""
typeset ALL_MSG_STC=0

if [[ -s ${HC_MSG_FILE} ]]
then
    # load messages file into memory
    # do not use array: max 1024 items in ksh88; regular variable is only 32-bit memory limited
    HC_MSG_VAR=$(<${HC_MSG_FILE})

    # DEBUG: dump TMP file
    if (( ARG_DEBUG > 0 ))
    then
        debug "begin dumping plugin messages file (${HC_MSG_FILE})"
        print "${HC_MSG_VAR}"
        debug "end dumping plugin messages file (${HC_MSG_FILE})"
    fi

    # determine ALL_MSG_STC (sum of all STCs)
    ALL_MSG_STC=$(print "${HC_MSG_VAR}" | awk -F"${MSG_SEP}" 'BEGIN { stc = 0 } { for (i=1;i<=NF;i++) { stc = stc + $1 }} END { print stc }' 2>/dev/null)
    (( ARG_DEBUG > 0 )) && debug "HC all STC: ${ALL_MSG_STC}"
    data_is_numeric "${ALL_MSG_STC}" || die "HC all STC computes to a non-numeric value"
else
    # nothing to do, respect current EXIT_CODE
    if (( EXIT_CODE > 0 ))
    then
        return ${EXIT_CODE}
    else
        return 0
    fi
fi

# display routines
if [[ -n "${HC_MSG_VAR}" ]]
then
   if (( DO_DISPLAY_CSV == 1 ))
   then
        if (( HAS_DISPLAY_CSV == 1 ))
        then
            # call plugin
            display_csv "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_csv plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_INIT == 1 ))
    then
        if (( HAS_DISPLAY_INIT == 1 ))
        then
            # call plugin
            display_init "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_init plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_JSON == 1 ))
    then
        if (( HAS_DISPLAY_JSON == 1 ))
        then
            # call plugin
            display_json "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_json plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_TERSE == 1 ))
    then
        if (( HAS_DISPLAY_TERSE == 1 ))
        then
            # call plugin
            display_terse "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_terse plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_ZENOSS == 1 ))
    then
        if (( HAS_DISPLAY_ZENOSS == 1 ))
        then
            # call plugin
            display_zenoss "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_zenoss plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM1 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM1 == 1 ))
        then
            # call plugin
            display_custom1 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom1 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM2 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM2 == 1 ))
        then
            # call plugin
            display_custom2 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom2 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM3 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM3 == 1 ))
        then
            # call plugin
            display_custom3 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom3 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM4 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM4 == 1 ))
        then
            # call plugin
            display_custom4 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom4 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM5 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM5 == 1 ))
        then
            # call plugin
            display_custom5 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom5 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM6 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM6 == 1 ))
        then
            # call plugin
            display_custom6 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom6 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM7 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM7 == 1 ))
        then
            # call plugin
            display_custom7 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom7 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM8 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM8 == 1 ))
        then
            # call plugin
            display_custom8 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom8 plugin is not available, cannot display_results!"
        fi
    elif (( DO_DISPLAY_CUSTOM9 == 1 ))
    then
        if (( HAS_DISPLAY_CUSTOM9 == 1 ))
        then
            # call plugin
            display_custom9 "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_custom9 plugin is not available, cannot display_results!"
        fi
    else
        # default STDOUT
        if (( ARG_VERBOSE > 0 ))
        then
            print "${HC_MSG_VAR}" | while IFS=${MSG_SEP} read -r ONE_MSG_STC ONE_MSG_TIME ONE_MSG_TEXT ONE_MSG_CUR_VAL ONE_MSG_EXP_VAL
            do
                # magically unquote if needed
                if [[ -n "${ONE_MSG_TEXT}" ]]
                then
                    data_contains_string "${ONE_MSG_TEXT}" "${MAGIC_QUOTE}"
                    # shellcheck disable=SC2181
                    if (( $? > 0 ))
                    then
                        ONE_MSG_TEXT=$(data_magic_unquote "${ONE_MSG_TEXT}")
                    fi
                fi
                if [[ -n "${ONE_MSG_CUR_VAL}" ]]
                then
                    data_contains_string "${ONE_MSG_CUR_VAL}" "${MAGIC_QUOTE}"
                    # shellcheck disable=SC2181
                    if (( $? > 0 ))
                    then
                        ONE_MSG_CUR_VAL=$(data_magic_unquote "${ONE_MSG_CUR_VAL}")
                    fi
                fi
                if [[ -n "${ONE_MSG_EXP_VAL}" ]]
                then
                    data_contains_string "${ONE_MSG_EXP_VAL}" "${MAGIC_QUOTE}"
                    # shellcheck disable=SC2181
                    if (( $? > 0 ))
                    then
                        ONE_MSG_EXP_VAL=$(data_magic_unquote "${ONE_MSG_EXP_VAL}")
                    fi
                fi
                printf "%s" "INFO: ${HC_NAME} [STC=${ONE_MSG_STC}]: ${ONE_MSG_TEXT}"
                if (( ONE_MSG_STC > 0 ))
                then
                    # shellcheck disable=SC1117
                    printf " %s\n" "[FAIL_ID=${HC_FAIL_ID}]"
                else
                    # shellcheck disable=SC1117
                    printf "\n"
                fi
            done
        fi
    fi
fi

# log & notify routines
if (( ARG_LOG > 0 ))
then
    # log routine (combined STC=0 or <>0)
    print "${HC_MSG_VAR}" | while IFS=${MSG_SEP} read -r ONE_MSG_STC ONE_MSG_TIME ONE_MSG_TEXT ONE_MSG_CUR_VAL ONE_MSG_EXP_VAL
    do
        # magically unquote if needed
        if [[ -n "${ONE_MSG_TEXT}" ]]
        then
            data_contains_string "${ONE_MSG_TEXT}" "${MAGIC_QUOTE}"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                ONE_MSG_TEXT=$(data_magic_unquote "${ONE_MSG_TEXT}")
            fi
        fi
        if [[ -n "${ONE_MSG_CUR_VAL}" ]]
        then
            data_contains_string "${ONE_MSG_CUR_VAL}" "${MAGIC_QUOTE}"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                ONE_MSG_CUR_VAL=$(data_magic_unquote "${ONE_MSG_CUR_VAL}")
            fi
            fi
        if [[ -n "${ONE_MSG_EXP_VAL}" ]]
        then
            data_contains_string "${ONE_MSG_EXP_VAL}" "${MAGIC_QUOTE}"
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                ONE_MSG_EXP_VAL=$(data_magic_unquote "${ONE_MSG_EXP_VAL}")
            fi
        fi
        printf "%s${LOG_SEP}%s${LOG_SEP}%s${LOG_SEP}%s${LOG_SEP}" \
                "${ONE_MSG_TIME}" \
                "${HC_NAME}" \
                ${ONE_MSG_STC} \
                "${ONE_MSG_TEXT}" >>${HC_LOG}
        if (( ONE_MSG_STC > 0 ))
        then
            # shellcheck disable=SC1117
            printf "%s${LOG_SEP}\n" "${HC_FAIL_ID}" >>${HC_LOG}
            HC_STC_RC=$(( HC_STC_RC + 1 ))
        else
            # shellcheck disable=SC1117
            printf "\n" >>${HC_LOG}
        fi
    done

    # notify routine (combined STC > 0)
    if (( ALL_MSG_STC > 0 ))
    then
        # save stdout/stderr to HC events location
        if [[ -s ${HC_STDOUT_LOG} ]] || [[ -s ${HC_STDERR_LOG} ]]
        then
            # organize logs in sub-directories: YYYY/MM
            mkdir -p "${EVENTS_DIR}/${DIR_PREFIX}/${HC_FAIL_ID}" >/dev/null 2>&1 || \
                die "failed to create event directory at ${1}"
            if [[ -f ${HC_STDOUT_LOG} ]]
            then
                # cut off the path and the .$$ part from the file location
                HC_STDOUT_LOG_SHORT="${HC_STDOUT_LOG##*/}"
                mv ${HC_STDOUT_LOG} "${EVENTS_DIR}/${DIR_PREFIX}/${HC_FAIL_ID}/${HC_STDOUT_LOG_SHORT%.*}" >/dev/null 2>&1 || \
                die "failed to move ${HC_STDOUT_LOG} to event directory at ${1}"
            fi
            if [[ -f ${HC_STDERR_LOG} ]]
            then
                # cut off the path and the .$$ part from the file location
                HC_STDERR_LOG_SHORT="${HC_STDERR_LOG##*/}"
                mv ${HC_STDERR_LOG} "${EVENTS_DIR}/${DIR_PREFIX}/${HC_FAIL_ID}/${HC_STDERR_LOG_SHORT%.*}" >/dev/null 2>&1 || \
                die "failed to move ${HC_STDERR_LOG} to event directory at ${1}"
            fi
        fi

        # notify if needed (i.e. when we have HC failures)
        # by mail?
        if (( DO_NOTIFY_MAIL == 1 ))
        then
            if (( HAS_NOTIFY_MAIL == 1 ))
            then
                # call plugin (pick up HC failure/stdout/stderr files in notify_mail())
                notify_mail "${HC_NAME}" "${HC_FAIL_ID}"
            else
                warn "notify_mail plugin is not avaible, cannot send alert via e-mail!"
            fi
        fi
        # by sms?
        if (( DO_NOTIFY_SMS == 1 ))
        then
            if (( HAS_NOTIFY_SMS == 1 ))
            then
                # call plugin
                notify_sms "${HC_NAME}" "${HC_FAIL_ID}"
            else
                warn "notify_sms plugin is not avaible, cannot send alert via sms!"
            fi
        fi
        # by EIF?
        if (( DO_NOTIFY_EIF == 1 ))
        then
            if (( HAS_NOTIFY_EIF == 1 ))
            then
                # call plugin
                notify_eif "${HC_NAME}" "${HC_FAIL_ID}"
            else
                warn "notify_sms plugin is not avaible, cannot send alert via sms!"
            fi
        fi
    fi
fi

# --flip-rc: pass RC of HC plugin back
if (( ARG_FLIP_RC == 0 ))
then
    # standard RC, error free
    return 0
else
    # exit with max 255
    (( HC_STC_RC > 255 )) && HC_STC_RC=255
    return ${HC_STC_RC}
fi
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: handle_timeout()
# DOES: kill long running background jobs
# EXPECTS: ${CHILD_PID} to be populated
# RETURNS: 0
# REQUIRES: warn()
function handle_timeout
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
[[ -n "${CHILD_PID}" ]] && kill -s TERM ${CHILD_PID}
warn "child process with PID ${CHILD_PID} has been forcefully stopped"
# shellcheck disable=SC2034
CHILD_ERROR=1

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: init_check_host
# DOES: init full host check
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: die()
function init_check_host
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_EXEC=""
typeset DISPLAY_STYLE=""

[[ -r ${HOST_CONFIG_FILE} ]] || die "unable to read configuration file at ${HOST_CONFIG_FILE}"

# read required config values
DISPLAY_STYLE=$(_CONFIG_FILE="${HOST_CONFIG_FILE}" data_get_lvalue_from_config 'display_style')
case "${DISPLAY_STYLE}" in
    csv|CSV) # csv format
        if (( HAS_DISPLAY_CSV == 1 ))
        then
            DO_DISPLAY_CSV=1
            ARG_VERBOSE=0
        fi
        ;;
    json|JSON) # json format
        if (( HAS_DISPLAY_JSON == 1 ))
        then
            DO_DISPLAY_JSON=1
            ARG_VERBOSE=0
        fi
        ;;
    terse|TERSE) # terse format
        if (( HAS_DISPLAY_TERSE == 1 ))
        then
            DO_DISPLAY_TERSE=1
            ARG_VERBOSE=0
        fi
        ;;
    zenoss|ZENOSS) # zenoss format
        if (( HAS_DISPLAY_ZENOSS == 1 ))
        then
            DO_DISPLAY_ZENOSS=1
            ARG_VERBOSE=0
        fi
        ;;
    custom1|CUSTOM1) # custom1 format
        if (( HAS_DISPLAY_CUSTOM1 == 1 ))
        then
            DO_DISPLAY_CUSTOM1=1
            ARG_VERBOSE=0
        fi
        ;;
    custom2|CUSTOM2) # custom2 format
        if (( HAS_DISPLAY_CUSTOM2 == 1 ))
        then
            DO_DISPLAY_CUSTOM2=1
            ARG_VERBOSE=0
        fi
        ;;
    custom3|CUSTOM3) # custom3 format
        if (( HAS_DISPLAY_CUSTOM3 == 1 ))
        then
            DO_DISPLAY_CUSTOM3=1
            ARG_VERBOSE=0
        fi
        ;;
    custom4|CUSTOM4) # custom4 format
        if (( HAS_DISPLAY_CUSTOM4 == 1 ))
        then
            DO_DISPLAY_CUSTOM4=1
            ARG_VERBOSE=0
        fi
        ;;
    custom5|CUSTOM5) # custom5 format
        if (( HAS_DISPLAY_CUSTOM5 == 1 ))
        then
            DO_DISPLAY_CUSTOM5=1
            ARG_VERBOSE=0
        fi
        ;;
    custom6|CUSTOM6) # custom6 format
        if (( HAS_DISPLAY_CUSTOM6 == 1 ))
        then
            DO_DISPLAY_CUSTOM6=1
            ARG_VERBOSE=0
        fi
        ;;
    custom7|CUSTOM7) # custom7 format
        if (( HAS_DISPLAY_CUSTOM7 == 1 ))
        then
            DO_DISPLAY_CUSTOM7=1
            ARG_VERBOSE=0
        fi
        ;;
    custom8|CUSTOM8) # custom8 format
        if (( HAS_DISPLAY_CUSTOM8 == 1 ))
        then
            DO_DISPLAY_CUSTOM8=1
            ARG_VERBOSE=0
        fi
        ;;
    custom9|CUSTOM9) # custom9 format
        if (( HAS_DISPLAY_CUSTOM9 == 1 ))
        then
            DO_DISPLAY_CUSTOM9=1
            ARG_VERBOSE=0
        fi
        ;;
    *) # init/boot default, stdout fallback
        if (( HAS_DISPLAY_INIT == 1 ))
        then
            DO_DISPLAY_INIT=1
            ARG_VERBOSE=0
        else
            ARG_VERBOSE=1
            warn "default boot/init display plugin not present"
        fi
esac

# mangle $ARG_HC to build the full list of HCs to be executed
ARG_HC=""
grep -i '^hc:' ${HOST_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _ HC_EXEC _ _
do
    ARG_HC="${ARG_HC},${HC_EXEC}"
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: init_hc
# DOES: init routines for HC/core plugins
# EXPECTS: 1=HC name [string], 2=list of platforms [string], 3=HC version [string]
# RETURNS: 0
# REQUIRES: die()
function init_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_PLATFORMS="${2}"
typeset HC_VERSION="${3}"
typeset HC_OK=0

# check platform (don't use a pattern comparison here (~! mksh/pdksh))
HC_OK=$(print "${HC_PLATFORMS}" | grep -c "${OS_NAME}" 2>/dev/null)
(( HC_OK > 0 )) || die "may only run on platform(s): ${HC_PLATFORMS}"

# check version of HC plugin
case "${HC_VERSION}" in
    [0-2][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9])
        # OK
        (( ARG_DEBUG > 0 )) && debug "HC plugin ${1} has version ${HC_VERSION}"
        ;;
    *)
        die "version of the HC plugin ${1} is not in YYYY-MM-DD format (${HC_VERSION})"
        ;;
esac

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: is_scheduled()
# DOES: check if a HC is scheduled in a cron
# EXPECTS: health check name [string]
# RETURNS: 0=HC not scheduled; <>0=HC is scheduled
# REQUIRES: n/a
function is_scheduled
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset CRON_HC="${1}"
typeset CRON_COUNT=0
typeset CRON_SYS_LOCATIONS='/etc/crontab /etc/cron.d/*'
typeset CRON_ANACRON_LOCATIONS='/etc/anacrontab /etc/cron.*'

# check for a scheduled job
case "${OS_NAME}" in
    "Linux")
        # check default root crontab
        CRON_COUNT=$(crontab -l 2>/dev/null | grep -c -E -e "^[^#].*${CRON_HC}" 2>/dev/null)
        # check system crontabs
        if (( CRON_COUNT == 0 ))
        then
            CRON_COUNT=$(cat ${CRON_SYS_LOCATIONS} 2>/dev/null | grep -c -E -e "^[^#].*${CRON_HC}" 2>/dev/null)
        fi
        # check anacron
        if (( CRON_COUNT == 0 ))
        then
            CRON_COUNT=$(cat ${CRON_ANACRON_LOCATIONS} 2>/dev/null | grep -c -E -e "^[^#].*${CRON_HC}" 2>/dev/null)
        fi
        ;;
    *)
        # use default root crontab
        CRON_COUNT=$(crontab -l 2>/dev/null | grep -c -E -e "^[^#].*${CRON_HC}" 2>/dev/null)
esac

return ${CRON_COUNT}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: list_core()
# DOES: find HC core plugins
# EXPECTS: action identifier [string]
# RETURNS: 0
# REQUIRES: n/a
function list_core
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FCONFIG=""
typeset FDIR=""
typeset FNAME=""
typeset FVERSION=""
typeset FCONFIG=""
typeset FSTATE="enabled"     # default
typeset FFILE=""
typeset FSCRIPT=""
typeset HAS_FCONFIG=0

# print header
# shellcheck disable=SC1117
printf "%-30s\t%-8s\t%s\t\t%s\n" "Core plugin" "State" "Version" "Config?"
# shellcheck disable=SC2183,SC1117
printf "%80s\n" | tr ' ' -

print "${FPATH}" | tr ':' '\n' 2>/dev/null | grep "core$" | sort 2>/dev/null | while read -r FDIR
do
    # exclude core helper librar(y|ies)
    # shellcheck disable=SC2010
    ls -1 ${FDIR}/*.sh 2>/dev/null | grep -v "include_" | sort 2>/dev/null | while read -r FFILE
    do
        # cache script contents in memory
        FSCRIPT=$(<${FFILE})

        # reset state
        FSTATE="enabled"
        # find function name but skip helper functions in the plug-in file (function _name)
        FNAME=$(print -R "${FSCRIPT}" | grep -E -e "^function[[:space:]]+[^_]" 2>/dev/null)
        # look for version string (cut off comments but don't use [:space:] in tr)
        FVERSION=$(print -R "${FSCRIPT}" | grep '^typeset _VERSION=' 2>/dev/null |\
            awk 'match($0,/[0-9]+-[0-9]+-[0-9]+/){print substr($0, RSTART, RLENGTH)}' 2>/dev/null)
        # look for configuration file string
        HAS_FCONFIG=$(print -R "${FSCRIPT}" | grep -c '^typeset _CONFIG_FILE=' 2>/dev/null)
        if (( HAS_FCONFIG > 0 ))
        then
            FCONFIG="Yes"
        else
            FCONFIG="No"
        fi
        # check state (only for unlinked)
        [[ -h ${FFILE%%.*} ]] || FSTATE="unlinked"

        # show results
        if [[ "${FACTION}" != "list" ]]
        then
            # shellcheck disable=SC1117
            printf "%-30s\t%-8s\t%s\t%s\n" \
                "${FNAME#function *}" \
                "${FSTATE}" \
                "${FVERSION#typeset _VERSION=*}" \
                "${FCONFIG}"
        else
            # shellcheck disable=SC1117
            printf "%s\n" "${FNAME#function *}"
        fi
    done
done

# dead link detection
print
print -n "Dead links: "
print "${FPATH}" | tr ':' '\n' 2>/dev/null | grep "core$" 2>/dev/null | while read -r FDIR
do
    # do not use 'find -type l' here!
    # shellcheck disable=SC2010,SC1117
    ls ${FDIR} 2>/dev/null | grep -v "\." 2>/dev/null | while read -r FFILE
    do
        if [[ -h "${FDIR}/${FFILE}" ]] && [[ ! -f "${FDIR}/${FFILE}" ]]
        then
            printf "%s " ${FFILE##*/}
        fi
    done
done
print

# show FPATH
print
print "current FPATH: ${FPATH}"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: list_hc()
# DOES: find HC plugins/functions
# EXPECTS: action identifier [string]
# RETURNS: 0
# REQUIRES: is_scheduled()
function list_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FACTION="${1}"
typeset FNEEDLE="${2}"
typeset FCONFIG=""
typeset FDIR=""
typeset FNAME=""
typeset FVERSION=""
typeset FCONFIG=""
typeset FSTATE=""
typeset FFILE=""
typeset FHEALTHY=""
typeset FSCHEDULED=0
typeset FSCRIPT=""
typeset HAS_FCONFIG=0
typeset HAS_FHEALTHY=""
typeset DISABLE_FFILE=""

# build search needle
if [[ -z "${ARG_LIST}" ]]
then
    FNEEDLE="*.sh"
else
    FNEEDLE="${ARG_LIST}.sh"
fi

# print header
if [[ "${FACTION}" != "list" ]]
then
    # shellcheck disable=SC1117
    printf "%-40s\t%-8s\t%s\t\t%s\t%s\t%s\n" "Health Check" "State" "Version" "Config?" "Sched?" "H+?"
    # shellcheck disable=SC2183,SC1117
    printf "%100s\n" | tr ' ' -
fi
print "${FPATH}" | tr ':' '\n' 2>/dev/null | grep -v "core$" 2>/dev/null | sort 2>/dev/null |\
    while read -r FDIR
do
    ls -1 ${FDIR}/${FNEEDLE} 2>/dev/null | sort 2>/dev/null | while read -r FFILE
    do
        # cache script contents in memory
        FSCRIPT=$(<${FFILE})

        # find function name but skip helper functions in the plug-in file (function _name)
        FNAME=$(print -R "${FSCRIPT}" | grep -E -e "^function[[:space:]]+[^_]" 2>/dev/null)
        # look for version string (cut off comments but don't use [:space:] in tr)
        FVERSION=$(print -R "${FSCRIPT}" | grep '^typeset _VERSION=' 2>/dev/null |\
            awk 'match($0,/[0-9]+-[0-9]+-[0-9]+/){print substr($0, RSTART, RLENGTH)}' 2>/dev/null)
        # look for configuration file string
        HAS_FCONFIG=$(print -R "${FSCRIPT}" | grep -c '^typeset _CONFIG_FILE=' 2>/dev/null)
        if (( HAS_FCONFIG > 0 ))
        then
            FCONFIG="Yes"
            # *.conf.dist first
            if [[ -r ${CONFIG_DIR}/${FNAME#function *}.conf.dist ]]
            then
                # check for log_healthy parameter (config file)
                HAS_FHEALTHY=$(_CONFIG_FILE="${CONFIG_DIR}/${FNAME#function *}.conf.dist" data_get_lvalue_from_config 'log_healthy')
                case "${HAS_FHEALTHY}" in
                    no|NO|No)
                        FHEALTHY="No"
                        ;;
                    yes|YES|Yes)
                        FHEALTHY="Yes"
                        ;;
                    *)
                        FHEALTHY="N/S"
                        ;;
                esac
            else
                FHEALTHY="N/S"
            fi
            # *.conf next
            if [[ -r ${CONFIG_DIR}/${FNAME#function *}.conf ]]
            then
                # check for log_healthy parameter (config file)
                HAS_FHEALTHY=$(_CONFIG_FILE="${CONFIG_DIR}/${FNAME#function *}.conf" data_get_lvalue_from_config 'log_healthy')
                case "${HAS_FHEALTHY}" in
                    no|NO|No)
                        FHEALTHY="No"
                        ;;
                    yes|YES|Yes)
                        FHEALTHY="Yes"
                        ;;
                    *)
                        FHEALTHY="N/S"
                        ;;
                esac
            fi
        # check for log_healthy support through --hc-args (plugin)
        elif (( $(print -R "${FSCRIPT}" | grep -c -E -e "_LOG_HEALTHY" 2>/dev/null) > 0 ))
        then
            FCONFIG="No"
            FHEALTHY="S"
        else
            FCONFIG="No"
            FHEALTHY="N/S"
        fi
        # check state
        DISABLE_FFILE="$(print ${FFILE##*/} | sed 's/\.sh$//')"
        if [[ -f "${STATE_PERM_DIR}/${DISABLE_FFILE}.disabled" ]]
        then
            FSTATE="disabled"
        else
            FSTATE="enabled"
        fi
        # reset state when unlinked
        [[ -h ${FFILE%%.*} ]] || FSTATE="unlinked"
        # check scheduling
        is_scheduled "${FNAME#function *}"
        # shellcheck disable=SC2181
        if (( $? == 0 ))
        then
            FSCHEDULED="No"
        else
            FSCHEDULED="Yes"
        fi

        # show results
        if [[ "${FACTION}" != "list" ]]
        then
            # shellcheck disable=SC1117
            printf "%-40s\t%-8s\t%s\t%s\t%s\t%s\n" \
                "${FNAME#function *}" \
                "${FSTATE}" \
                "${FVERSION#typeset _VERSION=*}" \
                "${FCONFIG}" \
                "${FSCHEDULED}" \
                "${FHEALTHY}"
        else
            # shellcheck disable=SC1117
            printf "%s\n" "${FNAME#function *}"
        fi
    done
done

# dead link detection
if [[ "${FACTION}" != "list" ]]
then
    print
    print -n "Dead links: "
    print "${FPATH}" | tr ':' '\n' 2>/dev/null | grep -v "core" 2>/dev/null | while read -r FDIR
    do
        # do not use 'find -type l' here!
        # shellcheck disable=SC2010,SC1117
        ls ${FDIR} 2>/dev/null | grep -v "\." 2>/dev/null | while read -r FFILE
        do
            if [[ -h "${FDIR}/${FFILE}" ]] && [[ ! -f "${FDIR}/${FFILE}" ]]
            then
                printf "%s " ${FFILE##*/}
            fi
        done
    done
    print

    # show FPATH
    print
    print "current FPATH: ${FPATH}"
fi

# legend
if [[ "${FACTION}" != "list" ]]
then
    print
    print "Config?: plugin has a default configuration file (Yes/No)"
    print "Sched? : plugin is scheduled through cron (Yes/No)"
    print "H+?    : plugin can choose whether to log/show passed health checks (Yes/No/Supported/Not supported)"
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: list_include()
# DOES: find HC include files (libraries)
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function list_include
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FDIR=""
typeset FNAME=""
typeset FVERSION=""
typeset FFILE=""
typeset FSTATE="enabled"     # default
typeset FSCRIPT=""
typeset FFUNCTIONS=""
typeset FFUNCTION=""

# print header
# shellcheck disable=SC1117
printf "%-20s\t%-8s\t%12s\t\t%s\n" "Include/libary" "State" "Version" "Functions"
# shellcheck disable=SC2183,SC1117
printf "%100s\n" | tr ' ' -

print "${FPATH}" | tr ':' '\n' 2>/dev/null  | grep "core$" 2>/dev/null | sort 2>/dev/null | while read -r FDIR
do
    # exclude core helper librar(y|ies)
    # shellcheck disable=SC2010
    ls -1 ${FDIR}/*.sh 2>/dev/null | grep "include_" 2>/dev/null | sort 2>/dev/null | while read -r FFILE
    do
        # cache script contents in memory
        FSCRIPT=$(<${FFILE})

        # find function name
        FNAME=$(print -R "${FSCRIPT}" | grep -E -e "^function[[:space:]].*version_" 2>/dev/null)
        # look for version string (cut off comments but don't use [:space:] in tr)
        FVERSION=$(print -R "${FSCRIPT}" | grep '^typeset _VERSION=' 2>/dev/null |\
            awk 'match($0,/[0-9]+-[0-9]+-[0-9]+/){print substr($0, RSTART, RLENGTH)}' 2>/dev/null)

        # get list of functions
        FFUNCTIONS=$(print -R "${FSCRIPT}" | grep -E -e "^function[[:space:]]+" 2>/dev/null | awk '{ print $2}' 2>/dev/null)

        # check state (only for unlinked)
        [[ -h ${FFILE%%.*} ]] || FSTATE="unlinked"

        # show results
        # shellcheck disable=SC1117
        printf "%-20s\t%-8s\t%12s\n" \
            "${FNAME#function version_*}" \
            "${FSTATE}" \
            "${FVERSION#typeset _VERSION=*}"
        print "${FFUNCTIONS}" | while read -r FFUNCTION
        do
            printf "%64s%s\n" "" "${FFUNCTION}"
        done
    done
done

# dead link detection
print
print -n "Dead links: "
print "${FPATH}" | tr ':' '\n' 2>/dev/null | grep "core$" 2>/dev/null | while read -r FDIR
do
    # do not use 'find -type l' here!
    # shellcheck disable=SC2010,SC1117
    ls ${FDIR} 2>/dev/null | grep -v "\." 2>/dev/null | while read -r FFILE
    do
        if [[ -h "${FDIR}/${FFILE}" ]] && [[ ! -f "${FDIR}/${FFILE}" ]]
        then
            printf "%s " ${FFILE##*/}
        fi
    done
done
print

# show FPATH
print
print "current FPATH: ${FPATH}"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: log()
# DOES: handle messages
# EXPECTS: log message [string]
# RETURNS: 0
# REQUIRES: n/a
function log
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset LOG_LINE=""

if [[ -n "${1}" ]]
then
    if (( ARG_LOG > 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            print "${NOW}: INFO: [$$]:" "${LOG_LINE}" >>${LOG_FILE}
        done
    fi
    if (( ARG_VERBOSE > 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            print "INFO:" "${LOG_LINE}"
        done
    fi
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: log_hc()
# DOES: log a HC plugin result
# EXPECTS: 1=HC name [string], 2=HC status code [integer], 3=HC message [string],
#          4=HC found value [string] (optional),
#          5=HC expected value [string] (optional)
# RETURNS: 0
# REQUIRES: n/a
function log_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_NAME="${1}"
typeset HC_STC=${2}
typeset HC_NOW="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
typeset HC_MSG_CUR_VAL=""
typeset HC_MSG_EXP_VAL=""

# assign optional parameters; magically quote if necessary
if [[ -n "${3}" ]]
then
    data_contains_string "${3}" "${MSG_SEP}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        HC_MSG_TEXT=$(data_magic_quote "${3}")
    else
        HC_MSG_TEXT="${3}"
    fi
fi
if [[ -n "${4}" ]]
then
    data_contains_string "${4}" "${MSG_SEP}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        HC_MSG_CUR_VAL=$(data_magic_quote "${4}")
    else
        HC_MSG_CUR_VAL="${4}"
    fi
fi
if [[ -n "${5}" ]]
then
    data_contains_string "${5}" "${MSG_SEP}"
    # shellcheck disable=SC2181
    if (( $? > 0 ))
    then
        HC_MSG_EXP_VAL=$(data_magic_quote "${5}")
    else
        HC_MSG_EXP_VAL="${5}"
    fi
fi

# save the HC failure message for now
print "${HC_STC}${MSG_SEP}${HC_NOW}${MSG_SEP}${HC_MSG_TEXT}${MSG_SEP}${HC_MSG_CUR_VAL}${MSG_SEP}${HC_MSG_EXP_VAL}" \
    >>${HC_MSG_FILE}

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: show_statistics
# DOES: show statistics about HC events
# EXPECTS: n/a
# RETURNS: n/a
# REQUIRES: n/a
function show_statistics
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _ARCHIVE_FILE=""

# current events
print
print -R "--- CURRENT events --"
print
print "${HC_LOG}:"
awk -F"${LOG_SEP}" '{
                    # all entries
                    total_count[$2]++
                    # set zero when empty
                    if (ok_count[$2] == "") { ok_count[$2]=0 }
                    if (nok_count[$2] == "") { nok_count[$2]=0 }
                    # count STCs
                    if ($3 == 0) {
                        ok_count[$2]++
                    } else {
                        nok_count[$2]++
                    }
                    # record first entry
                    if (first_entry[$2] == "" ) {
                        first_entry[$2]=$1
                    }
                    # pile up last entry
                    last_entry[$2]=$1
                    last_failid[$2]=$5
                }

                 END {
                    for (hc in total_count) {
                        # empty hc variable means count of empty lines in log file
                        if (hc != "") {
                            printf ("\t%s:\n", hc)
                            printf ("\t\t# entries: %d\n", total_count[hc])
                            printf ("\t\t# STC==0 : %d\n", ok_count[hc])
                            printf ("\t\t# STC<>0 : %d\n", nok_count[hc])
                            printf ("\t\tfirst    : %s\n", first_entry[hc])
                            printf ("\t\tlast     : %s\n", last_entry[hc])
                        }
                    }
                }
                ' ${HC_LOG} 2>/dev/null

# archived events
print; print
print -R "--- ARCHIVED events --"
print
find ${ARCHIVE_DIR} -type f -name "hc.*.log" 2>/dev/null | while read -r _ARCHIVE_FILE
do
    print "${_ARCHIVE_FILE}:"
    awk -F"${LOG_SEP}" '{
                        # all entries
                        total_count[$2]++
                        # set zero when empty
                        if (ok_count[$2] == "") { ok_count[$2]=0 }
                        if (nok_count[$2] == "") { nok_count[$2]=0 }
                        # count STCs
                        if ($3 == 0) {
                            ok_count[$2]++;
                        } else {
                            nok_count[$2]++
                        }
                        # record first entry
                        if (first_entry[$2] == "" ) {
                            first_entry[$2]=$1
                        }
                        # pile up last entry
                        last_entry[$2]=$1
                    }

                    END {
                        for (hc in total_count) {
                            # empty hc variable means count of empty lines in log file
                            if (hc != "") {
                                printf ("\t%s:\n", hc)
                                printf ("\t\t# entries: %d\n", total_count[hc])
                                printf ("\t\t# STC==0 : %d\n", ok_count[hc])
                                printf ("\t\t# STC<>0 : %d\n", nok_count[hc])
                                printf ("\t\tfirst    : %s\n", first_entry[hc])
                                printf ("\t\tlast     : %s\n", last_entry[hc])
                            }
                        }
                    }
                    ' ${_ARCHIVE_FILE} 2>/dev/null
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: stat_hc()
# DOES: retrieve status of a HC
# EXPECTS: HC name [string]
# RETURNS: 0=HC is disabled; 1=HC is enabled
# REQUIRES: n/a
function stat_hc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset STAT_HC="${1}"
typeset STAT_RC=1   # default: enabled

[[ -f "${STATE_PERM_DIR}/${STAT_HC}.disabled" ]] && STAT_RC=0

return ${STAT_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: warn()
# DOES: handle warnings
# EXPECTS: log message [string]
# RETURNS: 0
# REQUIRES: n/a
function warn
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset LOG_LINE=""

if [[ -n "${1}" ]]
then
    if (( ARG_LOG > 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            print "${NOW}: WARN: [$$]:" "${LOG_LINE}" >>${LOG_FILE}
        done
    fi
    if (( ARG_VERBOSE > 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            print "WARN:" "${LOG_LINE}"
        done
    fi
fi

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
