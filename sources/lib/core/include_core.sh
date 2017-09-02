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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset LOG_LINE=""

if [[ -n "$1" ]]
then
    if (( ARG_LOG != 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOTIFY_OPTS=""

# init global flags for core plugins (no typeset!)
DO_DISPLAY_CSV=0
DO_DISPLAY_INIT=0
DO_DISPLAY_TERSE=0
DO_NOTIFY_EIF=0
DO_NOTIFY_MAIL=0
DO_NOTIFY_SMS=0
HAS_DISPLAY_CSV=0
HAS_DISPLAY_INIT=0
HAS_DISPLAY_TERSE=0
HAS_NOTIFY_EIF=0
HAS_NOTIFY_MAIL=0
HAS_NOTIFY_SMS=0

# check which core display/notification plugins are installed
# do not use a while-do loop here because mksh/pdksh does not pass updated 
# variables back from the sub shell (only works for true ksh88/ksh93)
for FFILE in $(ls -1 ${FPATH_PARENT}/core/*.sh 2>/dev/null | grep -v "include_" 2>/dev/null)
do
    case "${FFILE}" in
        *display_csv.sh)
            HAS_DISPLAY_CSV=1
            (( ARG_DEBUG != 0 )) && debug "display_csv plugin is available"
            ;;
        *display_init.sh)
            HAS_DISPLAY_INIT=1
            (( ARG_DEBUG != 0 )) && debug "display_init plugin is available"
            ;;
        *display_terse.sh)
            HAS_DISPLAY_TERSE=1
            (( ARG_DEBUG != 0 )) && debug "display_terse plugin is available"
            ;;
        *notify_mail.sh)
            HAS_NOTIFY_MAIL=1
            (( ARG_DEBUG != 0 )) && debug "notify_mail plugin is available"
            ;;
        *notify_sms.sh)
            HAS_NOTIFY_SMS=1
            (( ARG_DEBUG != 0 )) && debug "notify_sms plugin is available"
            ;;
        *notify_eif.sh)
            HAS_NOTIFY_EIF=1
            (( ARG_DEBUG != 0 )) && debug "notify_eif plugin is available"
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
        terse) # terse format
            if (( HAS_DISPLAY_TERSE == 1 ))
            then
                DO_DISPLAY_TERSE=1
                ARG_VERBOSE=0
            else
                warn "terse plugin for '--display' not present"             
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
# --mail-to/--notify
if [[ -n "${ARG_MAIL_TO}" ]] && (( DO_NOTIFY_MAIL == 0 ))
then
    die "you cannot specify '--mail-to' without '--notify=mail'"
fi
if (( DO_NOTIFY_MAIL != 0 )) && [[ -z "${ARG_MAIL_TO}" ]]
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
if (( DO_NOTIFY_SMS != 0 )) && [[ -z "${ARG_SMS_TO}" ]]
then
    die "you cannot specify '--notify=sms' without '--sms-to'"
fi
if (( DO_NOTIFY_SMS != 0 )) && [[ -z "${ARG_SMS_PROVIDER}" ]]
then
    die "you cannot specify '--notify=sms' without '--sms-provider'"
fi

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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset EXISTS_HC="$1"
typeset FDIR=""
typeset EXISTS_RC=0

# do not use a while-do loop here because mksh/pdksh does not pass updated 
# variables back from the sub shell (only works for true ksh88/ksh93)
for FDIR in $(print "${FPATH}" | tr ':' ' ' 2>/dev/null)
do
	$(data_contains_string "${FDIR}" "core")
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FIND_HC="$1"
typeset FIND_PATH=""
typeset FDIR=""

print "${FPATH}" | tr ':' '\n' | grep -v "core$" | while read -r FDIR
do
    ls "${FDIR}/${FIND_HC}" >/dev/null 2>&1 && print "${FDIR}/${FIND_HC}"
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: handle_hc()
# DOES: handle HC results
# EXPECTS: 1=HC name [string], $HC_MSG_FILE temporary file
# RETURNS: 0
# REQUIRES: die(), display_csv(), display_terse(), notify_mail(), notify_sms(),
#           notify_eif(), warn()
function handle_hc
{
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_NAME="$1"
typeset HC_STC_COUNT=0
typeset I=0
typeset MAX_I=0
typeset HC_STDOUT_LOG_SHORT=""
typeset HC_STDERR_LOG_SHORT=""
set -A HC_MSG_STC
set -A HC_MSG_TIME
set -A HC_MSG_TEXT
set -A HC_MSG_CUR_VAL    # optional
set -A HC_MSG_EXP_VAL    # optional

if [[ -s ${HC_MSG_FILE} ]]
then
    # DEBUG: dump TMP file
    if (( ARG_DEBUG != 0 ))
    then
        debug "begin dumping plugin messages file (${HC_MSG_FILE})"
        cat ${HC_MSG_FILE} 2>/dev/null
        debug "end dumping plugin messages file (${HC_MSG_FILE})"
    fi

    # process message file into arrays
    while read HC_MSG_ENTRY
    do
        HC_MSG_STC[${I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $1'})
        HC_MSG_TIME[${I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $2'})
        HC_MSG_TEXT[${I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $3'})

        HC_MSG_CUR_VAL[${I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $4'})
        HC_MSG_EXP_VAL[${I}]=$(print "${HC_MSG_ENTRY}" | awk -F "%%" '{ print $5'})
        I=$(( I + 1 ))
    done <${HC_MSG_FILE} 2>/dev/null
fi
    
# display routines
if (( ${#HC_MSG_STC[*]} > 0 ))
then
   if (( DO_DISPLAY_CSV == 1 ))
   then
        if (( HAS_DISPLAY_CSV == 1 ))
        then
            # call plugin
            display_csv "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_csv plugin is not avaible, cannot display_results!"
        fi
    elif (( DO_DISPLAY_INIT == 1 ))
    then
        if (( HAS_DISPLAY_INIT == 1 ))
        then
            # call plugin
            display_init "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_init plugin is not avaible, cannot display_results!"
        fi      
    elif (( DO_DISPLAY_TERSE == 1 ))
    then
        if (( HAS_DISPLAY_TERSE == 1 ))
        then
            # call plugin
            display_terse "${HC_NAME}" "${HC_FAIL_ID}"
        else
            warn "display_terse plugin is not avaible, cannot display_results!"
        fi
    else
        # default STDOUT
        if (( ARG_VERBOSE != 0 )) 
        then
            I=0
            MAX_I=${#HC_MSG_STC[*]}
            while (( I < MAX_I ))
            do
                printf "%s" "INFO: ${HC_NAME} [STC=${HC_MSG_STC[${I}]}]: ${HC_MSG_TEXT[${I}]}"
                if (( HC_MSG_STC[${I}] != 0 ))
                then
                    printf " %s\n" "[FAIL_ID=${HC_FAIL_ID}]"
                else
                    printf "\n"
                fi
                I=$(( I + 1 ))
            done
        fi
    fi
fi

# log & notify routines
if (( ARG_LOG != 0 )) && (( ${#HC_MSG_STC[*]} > 0 ))
then
    # log routine (combined STC=0 or <>0)
    I=0
    MAX_I=${#HC_MSG_STC[*]}
    while (( I < MAX_I ))    
    do
        printf "%s${SEP}%s${SEP}%s${SEP}%s${SEP}" \
                "${HC_MSG_TIME[${I}]}" \
                "${HC_NAME}" \
                ${HC_MSG_STC[${I}]} \
                "${HC_MSG_TEXT[${I}]}" >>${HC_LOG}
        if (( HC_MSG_STC[${I}] != 0 )) 
        then
            printf "%s${SEP}\n" "${HC_FAIL_ID}" >>${HC_LOG}     
        else
            printf "\n" >>${HC_LOG}
        fi
        HC_STC_COUNT=$(( HC_STC_COUNT + HC_MSG_STC[${I}] ))
        I=$(( I + 1 ))
    done
    
    # notify routine (combined STC > 0)
    if (( HC_STC_COUNT > 0 ))   
    then
        # save stdout/stderr to HC events location
        if [[ -s ${HC_STDOUT_LOG} ]] || [[ -s ${HC_STDERR_LOG} ]]
        then
            # organize logs in sub-directories: YYYY/MM
            mkdir -p "${EVENTS_DIR}/${DIR_PREFIX}/${HC_FAIL_ID}" >/dev/null 2>&1 || \
                die "failed to create event directory at $1"
            if [[ -f ${HC_STDOUT_LOG} ]]
            then
                # cut off the path and the .$$ part from the file location
                HC_STDOUT_LOG_SHORT="${HC_STDOUT_LOG##*/}"
                mv ${HC_STDOUT_LOG} "${EVENTS_DIR}/${DIR_PREFIX}/${HC_FAIL_ID}/${HC_STDOUT_LOG_SHORT%.*}" >/dev/null 2>&1 || \
                die "failed to move ${HC_STDOUT_LOG} to event directory at $1"
            fi
            if [[ -f ${HC_STDERR_LOG} ]]
            then
                # cut off the path and the .$$ part from the file location
                HC_STDERR_LOG_SHORT="${HC_STDERR_LOG##*/}"
                mv ${HC_STDERR_LOG} "${EVENTS_DIR}/${DIR_PREFIX}/${HC_FAIL_ID}/${HC_STDERR_LOG_SHORT%.*}" >/dev/null 2>&1 || \
                die "failed to move ${HC_STDERR_LOG} to event directory at $1"
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

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: handle_timeout()
# DOES: kill long running background jobs
# EXPECTS: ${CHILD_PID} to be populated
# RETURNS: 0
# REQUIRES: warn()
function handle_timeout
{
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
[[ -n "${CHILD_PID}" ]] && kill -s TERM ${CHILD_PID}
warn "child process with PID ${CHILD_PID} has been forcefully stopped"
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset DUMMY=""
typeset HC_CONFIG=""
typeset HC_DESC=""
typeset HC_EXEC=""
typeset REPORT_STYLE=""

[[ -r ${HOST_CONFIG_FILE} ]] || die "unable to read configuration file at ${HOST_CONFIG_FILE}"

# read required config values
REPORT_STYLE="$(grep -i '^report_style=' ${HOST_CONFIG_FILE} | cut -f2 -d'=' | tr -d '\"')"
case "${REPORT_STYLE}" in
    csv|CSV) # csv format
        if (( HAS_DISPLAY_CSV == 1 ))
        then
            DO_DISPLAY_CSV=1
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
    while IFS=':' read DUMMY HC_EXEC HC_CONFIG HC_DESC
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_PLATFORMS="$2"
typeset HC_VERSION="$3"
typeset HC_OK=0

# check platform (don't use a pattern comparison here (~! mksh/pdksh))
HC_OK=$(print "${HC_PLATFORMS}" | grep -c "${OS_NAME}" 2>/dev/null)
(( HC_OK != 0 )) || die "may only run on platform(s): ${HC_PLATFORMS}"

# check version of HC plugin
case "${HC_VERSION}" in
    [0-2][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9])
        # OK
        (( ARG_DEBUG != 0 )) && debug "HC plugin $1 has version ${HC_VERSION}"
        ;;
    *)
        die "version of the HC plugin $1 is not in YYYY-MM-DD format (${HC_VERSION})"
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset CRON_HC="$1"
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FACTION="$1"
typeset FCONFIG=""
typeset FDIR=""
typeset FNAME=""
typeset FVERSION=""
typeset FCONFIG=""
typeset FSTATE="enabled"     # default
typeset FFILE=""
typeset HAS_FCONFIG=0
typeset HC_VERSION=""

# print header
if [[ "${FACTION}" != "list" ]]
then
    printf "%-30s\t%-8s\t%s\t\t%s\n" "Core plugin" "State" "Version" "Config?"
    printf "%80s\n" | tr ' ' -
fi
print "${FPATH}" | tr ':' '\n' | grep "core$" | sort 2>/dev/null | while read -r FDIR
do
    # exclude core helper librar(y|ies)
    ls -1 ${FDIR}/*.sh 2>/dev/null | grep -v "include_" | sort 2>/dev/null | while read -r FFILE
    do
        # find function name but skip helper functions in the plug-in file (function _name)
        FNAME=$(grep -E -e "^function[[:space:]]+[^_]" "${FFILE}" 2>&1)
        # look for version string (cut off comments but don't use [:space:] in tr)
        FVERSION=$(grep '^typeset _VERSION=' "${FFILE}" 2>&1 | tr -d '\"' | tr -d ' \t' | cut -f1 -d'#' | cut -f2 -d'=')
        # look for configuration file string
        HAS_FCONFIG=$(grep -c '^typeset _CONFIG_FILE=' "${FFILE}" 2>&1)
        if (( HAS_FCONFIG != 0 ))
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
            printf "%-30s\t%-8s\t%s\t%s\n" \
                "${FNAME#function *}" \
                "${FSTATE}" \
                "${FVERSION#typeset _VERSION=*}" \
                "${FCONFIG}"        
        else
            printf "%s\n" "${FNAME#function *}"
        fi
    done
done

# dead link detection
if [[ "${FACTION}" != "list" ]]
then
    print
    print -n "Dead links: "
    print "${FPATH}" | tr ':' '\n' | grep "core$" | while read -r FDIR
    do
        # do not use 'find -type l' here!
        ls ${FDIR} 2>/dev/null | grep -v "\." | while read -r FFILE
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FACTION="$1"
typeset FNEEDLE="$2"
typeset FCONFIG=""
typeset FDIR=""
typeset FNAME=""
typeset FVERSION=""
typeset FCONFIG=""
typeset FSTATE=""
typeset FFILE=""
typeset HAS_FCONFIG=0
typeset FSCHEDULED=0
typeset DISABLE_FFILE=""
typeset HC_VERSION=""

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
    printf "%-30s\t%-8s\t%s\t\t%s\t%s\n" "Health Check" "State" "Version" "Config?" "Sched?"
    printf "%80s\n" | tr ' ' -
fi
print "${FPATH}" | tr ':' '\n' | grep -v "core$" | sort 2>/dev/null | while read -r FDIR
do
    ls -1 ${FDIR}/${FNEEDLE} 2>/dev/null | sort 2>/dev/null | while read -r FFILE
    do
        # find function name but skip helper functions in the plug-in file (function _name)
        FNAME=$(grep -E -e "^function[[:space:]]+[^_]" "${FFILE}" 2>&1)
        # look for version string (cut off comments but don't use [:space:] in tr)
        FVERSION=$(grep '^typeset _VERSION=' "${FFILE}" 2>&1 | tr -d '\"' | tr -d ' \t' | cut -f1 -d'#' | cut -f2 -d'=')
        # look for configuration file string
        HAS_FCONFIG=$(grep -c '^typeset _CONFIG_FILE=' "${FFILE}" 2>&1)
        if (( HAS_FCONFIG != 0 ))
        then
            FCONFIG="Yes"
        else
            FCONFIG="No"
        fi
        # check state
        DISABLE_FFILE="$(print ${FFILE##*/} | sed 's/\.sh$//')"
        if [[ -f "${STATE_PERM_DIR}/${DISABLE_FFILE}.disabled" ]]
        then
            FSTATE="disabled"
        else
            FSTATE="enabled"
        fi
        [[ -h ${FFILE%%.*} ]] || FSTATE="unlinked"
        # check scheduling
        is_scheduled "${FNAME#function *}"
        if (( $? == 0 ))
        then
            FSCHEDULED="No"
        else
            FSCHEDULED="Yes"
        fi
        
        # show results
        if [[ "${FACTION}" != "list" ]]
        then
            printf "%-30s\t%-8s\t%s\t%s\t%s\n" \
                "${FNAME#function *}" \
                "${FSTATE}" \
                "${FVERSION#typeset _VERSION=*}" \
                "${FCONFIG}" \
                "${FSCHEDULED}"         
        else
            printf "%s\n" "${FNAME#function *}"
        fi
    done
done

# dead link detection
if [[ "${FACTION}" != "list" ]]
then
    print
    print -n "Dead links: "
    print "${FPATH}" | tr ':' '\n' | grep -v "core" | while read -r FDIR
    do
        # do not use 'find -type l' here!
        ls ${FDIR} 2>/dev/null | grep -v "\." | while read -r FFILE
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset LOG_LINE=""

if [[ -n "$1" ]]
then
    if (( ARG_LOG != 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            print "${NOW}: INFO: [$$]:" "${LOG_LINE}" >>${LOG_FILE}
        done
    fi
    if (( ARG_VERBOSE != 0 ))
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_NAME="$1"
typeset HC_STC=$2
typeset HC_MSG="$3"
typeset HC_NOW="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
typeset HC_MSG_CUR_VAL=""
typeset HC_MSG_EXP_VAL=""

# assign optional parameters
[[ -n "$4" ]] && HC_MSG_CUR_VAL=$(data_newline2hash "$4")
[[ -n "$5" ]] && HC_MSG_EXP_VAL=$(data_newline2hash "$5")

# save the HC failure message for now
print "${HC_STC}%%${HC_NOW}%%${HC_MSG}%%${HC_MSG_CUR_VAL}%%${HC_MSG_EXP_VAL}" \
    >>${HC_MSG_FILE}

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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset STAT_HC="$1"
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
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset LOG_LINE=""

if [[ -n "$1" ]]
then
    if (( ARG_LOG != 0 ))
    then
        print - "$*" | while read -r LOG_LINE
        do
            print "${NOW}: WARN: [$$]:" "${LOG_LINE}" >>${LOG_FILE}
        done
    fi
    if (( ARG_VERBOSE != 0 ))
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
