#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_health.sh
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
# @(#) MAIN: check_health.sh
# DOES: performs simple health checks on UNIX hosts. Individual checks are
#       contained in separate KSH functions (aka plug-ins)
# EXPECTS: (see --help for more options)
# REQUIRES: ksh88/93 (mksh/pdksh will probably work too but YMMV)
#           build_fpath(), check_config(), check_core(), check_lock_dir(),
#           check_params(), check_platform(), check_user(), check_shell(),
#           display_usage(), do_cleanup, fix_symlinks(), read_config()
#           + include functions
#           For other pre-requisites see the documentation in display_usage()
# REQUIRES (OPTIONAL): display_*(), notify_*(), report_*()
# EXISTS: 0=no errors encountered, >0=some errors encountered
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

#******************************************************************************
# DATA structures
#******************************************************************************

# ------------------------- CONFIGURATION starts here -------------------------
# define the version (YYYY-MM-DD)
typeset -r SCRIPT_VERSION="2019-05-19"
# location of parent directory containing KSH functions/HC plugins
typeset -r FPATH_PARENT="/opt/hc/lib"
# location of custom HC configuration files
typeset -r CONFIG_DIR="/etc/opt/hc"
# location of main configuration file
typeset -r CONFIG_FILE="${CONFIG_DIR}/core/check_health.conf"
# location of the host check configuration file (optional)
typeset -r HOST_CONFIG_FILE="${CONFIG_DIR}/check_host.conf"
# location of temporary working storage
typeset -r TMP_DIR="/var/tmp"
# specify the UNIX user that needs to be used for executing the script
typeset -r EXEC_USER="root"
# ------------------------- CONFIGURATION ends here ---------------------------
typeset PATH=${PATH}:/sbin:/usr/bin:/usr/sbin:/usr/local/bin
# read-only settings (but should not be changed)
typeset -r SCRIPT_NAME=$(basename "$0" 2>/dev/null)
typeset -r SCRIPT_DIR=$(dirname "$0" 2>/dev/null)
# shellcheck disable=SC2034
typeset -r HOST_NAME="$(hostname 2>/dev/null)"
typeset -r OS_NAME="$(uname -s 2>/dev/null)"
typeset -r LOCK_DIR="${TMP_DIR}/.${SCRIPT_NAME}.lock"
typeset -r HC_MSG_FILE="${TMP_DIR}/.${SCRIPT_NAME}.hc.msg.$$"   # plugin messages file
# shellcheck disable=SC2034
typeset -r LOG_SEP="|"          # single character only
# shellcheck disable=SC2034
typeset -r MSG_SEP="%"          # single character only
# shellcheck disable=SC2034
typeset -t NUM_LOG_FIELDS=6     # current number of fields in $HC_LOG + 1
# shellcheck disable=SC2034
typeset -r MAGIC_QUOTE="!_!"    # magic quote
typeset -r LOG_DIR="/var/opt/hc"
typeset -r LOG_FILE="${LOG_DIR}/${SCRIPT_NAME}.log"
typeset -r ARCHIVE_DIR="${LOG_DIR}/archive"
typeset -r EVENTS_DIR="${LOG_DIR}/events"
typeset -r STATE_DIR="${LOG_DIR}/state"
typeset -r STATE_PERM_DIR="${STATE_DIR}/persistent"
typeset -r STATE_TEMP_DIR="${STATE_DIR}/temporary"
# miscellaneous
typeset CMD_LINE=""
typeset CMD_PARAMETER=""
typeset CHILD_ERROR=0
# shellcheck disable=SC2034
typeset DIR_PREFIX="$(date '+%Y-%m')"
typeset EXIT_CODE=0
typeset FDIR=""
typeset FFILE=""
typeset FPATH=""
typeset HC_ARCHIVE=""
typeset HC_CHECK=""
typeset HC_DISABLE=""
typeset HC_ENABLE=""
typeset HC_RUN=""
typeset HC_FAIL_ID=""
# shellcheck disable=SC2034
typeset HC_FILE_LINE=""
typeset HC_NOW=""
typeset HC_TIME_OUT=60
typeset HC_MIN_TIME_OUT=30
# shellcheck disable=SC2034
typeset HC_MSG_VAR=""
typeset HC_STDOUT_LOG=""
typeset HC_STDERR_LOG=""
# shellcheck disable=SC2034
typeset LINUX_DISTRO=""
# shellcheck disable=SC2034
typeset LINUX_RELEASE=""
typeset ARCHIVE_RC=0
typeset DISABLE_RC=0
typeset ENABLE_RC=0
# shellcheck disable=SC2034
typeset FIX_FC=0
typeset IS_PDKSH=0
typeset RUN_RC=0
typeset RUN_CONFIG_FILE=""
typeset RUN_TIME_OUT=0
# shellcheck disable=SC2034
typeset SORT_CMD=""
typeset DEBUG_OPTS=""
# command-line parameters
typeset ARG_ACTION=0            # HC action flag
typeset ARG_CHECK_HOST=0        # host check is off by default
typeset ARG_CONFIG_FILE=""      # custom configuration file for a HC, none by default
typeset ARG_DEBUG=0             # debug is off by default
typeset ARG_DEBUG_LEVEL=0       # debug() only by default
typeset ARG_DETAIL=0            # for --report
typeset ARG_DISPLAY=""          # display is STDOUT by default
typeset ARG_FAIL_ID=""
typeset ARG_FLIP_RC=0           # swapping EXIT RC is off by default
typeset ARG_HC=""
typeset ARG_HC_ARGS=""          # no extra arguments to HC plug-in by default
typeset ARG_HISTORY=0           # include historical events is off by default
typeset ARG_LAST=0              # report last events
typeset ARG_LIST=""             # list all by default
typeset ARG_LOCK=1              # lock for concurrent script executions is on by default
typeset ARG_LOG=1               # logging is on by default
typeset ARG_LOG_HEALTHY=0       # logging of healthy health checks is off by default
typeset ARG_MONITOR=1           # killing long running HC processes is on by default
typeset ARG_NEWER=""
typeset ARG_NOTIFY=""           # notification of problems is off by default
typeset ARG_OLDER=""
typeset ARG_REVERSE=0           # show report in reverse date order is off by default
typeset ARG_REPORT=""           # report of HC events is off by default
typeset ARG_TIME_OUT=0          # custom timeout is off by default
typeset ARG_TERSE=0             # show terse help is off by default
typeset ARG_TODAY=0             # report today's events
typeset ARG_VERBOSE=1           # STDOUT is on by default
typeset ARG_WITH_RC=""
set +o bgnice


#******************************************************************************
# FUNCTION routines
#******************************************************************************

# -----------------------------------------------------------------------------
# COMMON
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# @(#) FUNCTION: build_fpath()
# DOES: build the FPATH environment variable from FPATH_PARENT
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function build_fpath
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FPATH_DIR=""

# do not use a while-do loop here because mksh/pdksh does not pass updated
# variables back from the sub shell (only works for true ksh88/ksh93)
for FPATH_DIR in $(find ${FPATH_PARENT} -type d | grep -v -E -e "^${FPATH_PARENT}$" | tr '\n' ' ' 2>/dev/null)
do
    if [[ -z "${FPATH}" ]]
    then
        FPATH="${FPATH_DIR}"
    else
        FPATH="${FPATH}:${FPATH_DIR}"
    fi
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_config()
# DOES: check script configuration settings, abort upon failure
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function check_config
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

# EXEC_USER
if [[ -z "${EXEC_USER}" ]]
then
    print -u2 "ERROR: you must define a value for the EXEC_USER setting in $0"
    exit 1
fi
# SCRIPT_VERSION
if [[ -z "${SCRIPT_VERSION}" ]]
then
    print -u2 "ERROR: you must define a value for the SCRIPT_VERSION setting in $0"
    exit 1
fi
# TMP_DIR
if [[ -z "${TMP_DIR}" ]]
then
    print -u2 "ERROR: you must define a value for the TMP_DIR setting in $0"
    exit 1
fi
# FPATH_PARENT
if [[ -z "${FPATH_PARENT}" ]]
then
    print -u2 "ERROR: you must define a value for the FPATH_PARENT setting in $0"
    exit 1
fi
if [[ ! -d "${FPATH_PARENT}" ]]
then
    print -u2 "ERROR: directory in setting FPATH_PARENT does not exist"
    exit 1
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_core()
# DOES: check core plugins & files/directories
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function check_core
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset INCLUDE_FILE=""

# check include_core (MUST be present)
if [[ ! -r ${FPATH_PARENT}/core/include_core.sh || ! -h ${FPATH_PARENT}/core/include_core ]]
then
    print -u2 "ERROR: library file ${FPATH_PARENT}/core/include_core(.sh) is not present (tip: run --fix-symlinks)"
    exit 1
fi
# include include_*
find ${FPATH_PARENT}/core -name "include_*.sh" -type f -print 2>/dev/null | while read INCLUDE_FILE
do
    if [[ -h ${INCLUDE_FILE%%.sh} ]]
    then
        # shellcheck source=/dev/null
        (( ARG_DEBUG > 0 )) && print -u2 "DEBUG: including ${INCLUDE_FILE}"
        # shellcheck source=/dev/null
        . ${INCLUDE_FILE}
    else
        print -u2 "ERROR: library file ${INCLUDE_FILE} exists but has no symlink. Run --fix-symlinks"
        exit 1
    fi
done

# check for core directories
[[ -d ${ARCHIVE_DIR} ]] || mkdir -p "${ARCHIVE_DIR}" >/dev/null 2>&1
if [[ ! -d "${ARCHIVE_DIR}" ]] || [[ ! -w "${ARCHIVE_DIR}" ]]
then
    print -u2 "ERROR: unable to access the archive directory at ${ARCHIVE_DIR}"
fi
[[ -d ${EVENTS_DIR} ]] || mkdir -p "${EVENTS_DIR}" >/dev/null 2>&1
if [[ ! -d "${EVENTS_DIR}" ]] || [[ ! -w "${EVENTS_DIR}" ]]
then
    print -u2 "ERROR: unable to access the state directory at ${EVENTS_DIR}"
fi
[[ -d ${STATE_DIR} ]] || mkdir -p "${STATE_DIR}" >/dev/null 2>&1
if [[ ! -d "${STATE_DIR}" ]] || [[ ! -w "${STATE_DIR}" ]]
then
    print -u2 "ERROR: unable to access the state directory at ${STATE_DIR}"
fi
[[ -d ${STATE_PERM_DIR} ]] || mkdir -p "${STATE_PERM_DIR}" >/dev/null 2>&1
if [[ ! -d "${STATE_PERM_DIR}" ]] || [[ ! -w "${STATE_PERM_DIR}" ]]
then
    print -u2 "ERROR: unable to access the persistent state directory at ${STATE_PERM_DIR}"
fi
[[ -d ${STATE_TEMP_DIR} ]] || mkdir -p "${STATE_TEMP_DIR}" >/dev/null 2>&1
if [[ ! -d "${STATE_TEMP_DIR}" ]] || [[ ! -w "${STATE_TEMP_DIR}" ]]
then
    print -u2 "ERROR: unable to access the temporary state directory at ${STATE_TEMP_DIR}"
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_lock_dir()
# DOES: check if script lock directory exists, abort upon duplicate run
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function check_lock_dir
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
if (( ARG_LOCK > 0 ))
then
    mkdir ${LOCK_DIR} >/dev/null || {
        print -u2 "ERROR: unable to acquire lock ${LOCK_DIR}"
        ARG_VERBOSE=0 warn "unable to acquire lock ${LOCK_DIR}"
        if [[ -f ${LOCK_DIR}/.pid ]]
        then
            typeset LOCK_PID="$(<${LOCK_DIR}/.pid)"
            print -u2 "ERROR: active health checker running on PID: ${LOCK_PID}"
            ARG_VERBOSE=0 warn "active health checker running on PID: ${LOCK_PID}. Exiting!"
        fi
        exit 1
    }
    print $$ >${LOCK_DIR}/.pid
else
    (( ARG_DEBUG > 0 )) && print "DEBUG: locking has been disabled"
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_params()
# DOES: check if arguments/options are valid, abort script upon error
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function check_params
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

# --debug-level
if (( ARG_DEBUG_LEVEL > 2 ))
then
    print -u2 "ERROR: you must specify a debug level between 0-2"
    exit 1
fi
# --config-file
if [[ -n "${ARG_CONFIG_FILE}" ]]
then
    # do not allow a custom configuration file for multiple checks
    if [[ "${ARG_HC}" = *,* ]]      # use =, ksh88
    then
        print -u2 "ERROR: custom configuration file is not allowed when executing multiple HC's"
        exit 1
    fi
    # check if config file exists
    if [[ ! -r "${ARG_CONFIG_FILE}" ]]
    then
        print -u2 "ERROR: unable to read configuration file at ${ARG_CONFIG_FILE}"
        exit 1
    fi
fi
# --flip-rc
if (( ARG_FLIP_RC > 0 ))
then
    # do not allow flip RC for multiple checks
    if [[ "${ARG_HC}" = *,* ]]      # use =, ksh88
    then
        print -u2 "ERROR: flipping RC (return code) is not allowed when executing multiple HC's"
        exit 1
    fi
    if (( ARG_ACTION != 4 ))
    then
        print -u2 "ERROR: you can only use '--flip-rc' in combination with '--run'"
        exit 1
    fi
fi
# --check-host,--check/--disable/--enable/--run/--show/--archive,--hc
if [[ -n "${ARG_HC}" ]] && (( ARG_ACTION == 0 ))
then
    print -u2 "ERROR: you must specify an action for the HC (--archive/--check/--disable/--enable/--run/--show)"
    exit 1
fi
if (( ARG_CHECK_HOST == 0 ))
then
    if (( ARG_ACTION < 6 || ARG_ACTION == 10 )) && [[ -z "${ARG_HC}" ]]
    then
        print -u2 "ERROR: you must specify a value for the '--hc' parameter"
        exit 1
    fi
    if (( ARG_ACTION == 5 )) || [[ -n "${ARG_HC_ARGS}" ]]
    then
        case "${ARG_HC}" in
            *,*)
                print -u2 "ERROR: you can only specify a single value for '--hc' in combination with '--show'"
                exit 1
                ;;
        esac
    fi
    if (( ARG_ACTION == 10 )) || [[ -n "${ARG_HC_ARGS}" ]]
    then
        case "${ARG_HC}" in
            *,*)
                print -u2 "ERROR: you can only specify a single value for '--hc' in combination with '--archive'"
                exit 1
                ;;
        esac
    fi
else
    # host checking has no other messages to display
    ARG_VERBOSE=0
fi
# --list/--show-stats
if (( ARG_ACTION == 9 || ARG_ACTION == 11 ))
then
    ARG_VERBOSE=0
    ARG_LOG=0
fi
# --fix-logs
if (( ARG_ACTION == 12 )) && [[ -n "${ARG_HC}" ]]
then
    print -u2 "ERROR: you can only use '--fix-logs' in combination with '--with-history'"
    exit 1
fi
# --timeout
if (( ARG_TIME_OUT > 0 ))
then
    if (( ARG_ACTION == 4 ))
    then
        # keep timeout to a sensible value
        if (( ARG_TIME_OUT < HC_MIN_TIME_OUT ))
        then
            print -u2 "ERROR: you cannot specify a value for '--timeout' smaller than ${HC_MIN_TIME_OUT} (see \$HC_MIN_TIME_OUT})"
            exit 1
        fi
        if (( ARG_TIME_OUT < HC_TIME_OUT ))
        then
            print -u2 "ERROR: you cannot specify a value for '--timeout' smaller than ${HC_TIME_OUT} (see ${CONFIG_FILE})"
            exit 1
        fi
        HC_TIME_OUT=${ARG_TIME_OUT}
    else
        print -u2 "ERROR: you can only specify a value for '--timeout' in combination with '--run'"
        exit 1
    fi
fi
# --log-healthy
if (( ARG_LOG_HEALTHY > 0 && ARG_ACTION != 4 ))
then
    print -u2 "ERROR: you can only use '--log-healthy' in combination with '--run'"
    exit 1
fi
# check log location
if (( ARG_LOG > 0 ))
then
    if [[ ! -d "${LOG_DIR}" ]] || [[ ! -w "${LOG_DIR}" ]]
    then
        print -u2 "ERROR: unable to write to the log directory at ${LOG_DIR}"
        exit 1
    fi
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_platform()
# DOES: check running platform
# EXPECTS: platform name [string]
# RETURNS: 0=platform matches, 1=platform does not match
# REQUIRES: $OS_NAME
function check_platform
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset HC_PLATFORM="${1}"
typeset RC=0

if [[ "${OS_NAME}" != @(${HC_PLATFORM}) ]]
then
    (( ARG_DEBUG > 0 )) && warn "platform ${HC_PLATFORM} does not match ${OS_NAME}"
    RC=1
fi

return ${RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_user()
# DOES: check user that is executing the script, abort script if user 'root'
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function check_user
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset WHOAMI=""

# avoid sub-shell for mksh/pdksh
# shellcheck disable=SC2046
WHOAMI=$(IFS='()'; set -- $(id); print "${2}")
if [[ "${WHOAMI}" != "${EXEC_USER}" ]]
then
    print -u2 "ERROR: must be run as user '${EXEC_USER}'"
    exit 1
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: check_shell()
# DOES: check for ksh version
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function check_shell
{
case "${KSH_VERSION}" in
    *MIRBSD*|*PD*|*LEGACY*)
        (( ARG_DEBUG > 0 )) && debug "running ksh: ${KSH_VERSION}"
        # shellcheck disable=SC2034
        IS_PDKSH=1
        ;;
    *)
        if [[ -z "${ERRNO}" ]]
        then
            # shellcheck disable=SC2154
            (( ARG_DEBUG > 0 )) && debug "running ksh: ${.sh.version}"
        else
            (( ARG_DEBUG > 0 )) && debug "running ksh: ksh88 or older"
        fi
        ;;
esac

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: display_usage()
# DOES: display usage and exit with error code 0
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function display_usage
{
cat << EOT

**** ${SCRIPT_NAME} ****
**** (c) KUDOS BVBA - Patrick Van der Veken ****

Execute/report simple health checks (HC) on UNIX hosts.

Syntax: ${SCRIPT_DIR}/${SCRIPT_NAME} [--help] | [--help-terse] | [--version] |
    [--list=<needle>] | [--list-core] | [--list-include] | [--fix-symlinks] | [--show-stats] | (--archive-all | --disable-all | --enable-all) | [--fix-logs [--with-history]] |
        (--check-host | ((--archive | --check | --enable | --disable | --run [--timeout=<secs>] | --show) --hc=<list_of_checks> [--config-file=<configuration_file>] [hc-args="<arg1,arg2=val,arg3">]))
            [--display=<method>] ([--debug] [--debug-level=<level>]) [--log-healthy] [--no-monitor] [--no-log] [--no-lock] [[--flip-rc] [--with-rc=<count|max|sum>]]]
                [--notify=<method_list>] [--mail-to=<address_list>] [--sms-to=<sms_rcpt> --sms-provider=<name>]
                    [--report=<method> [--with-history] ( ([--last] | [--today]) | [(--older|--newer)=<date>] | [--reverse] [--id=<fail_id> [--detail]] )]

EOT

if (( ARG_TERSE == 0 ))
then
    cat << EOT
Parameters:

--archive       : move events from the HC log file into archive log files (one HC)
--archive-all   : move events for all HCs from the HC log file into archive log files
--check         : display HC state.
--check-host    : execute all configured HC(s) (see check_host.conf)
--config-file   : custom configuration file for a HC (may only be specified when executing a single HC plugin)
--debug         : run script in debug mode
--debug-level   : level of debugging information to show (0,1,2)
--detail        : show detailed info on failed HC event (will show STDOUT+STDERR logs)
--disable       : disable HC(s).
--disable-all   : disable all HC.
--display       : display HC results in a formatted way. Default is STDOUT (see --list-core for available formats)
--enable        : enable HC(s).
--enable-all    : enable all HCs.
--fix-logs      : fix rogue log entries (can be used with --with-history)
--fix-symlinks  : update symbolic links for the KSH autoloader.
--flip-rc       : exit the health checker with the RC (return code) of the HC plugin instead of its own RC (will be discarded)
                  This option may only be specified when executing a single HC plugin
--hc            : list of health checks to be executed (comma-separated) (see also --list-hc)
--hc-args       : extra arguments to be passed to an individual HC. Arguments must be comma-separated and enclosed
                  in double quotes (example: --hc_args="arg1,arg2=value,arg3").
--id            : value of a FAIL ID (must be specified as uninterrupted sequence of numbers)
--last          : show the last (failed) events for each HC and their combined STC value
--list          : show the available health checks. Use <needle> to search with wildcards. Following details are shown:
                  - health check (plugin) name
                  - state of the HC plugin (disabled/enabled)
                  - version of the HC plugin
                  - whether the HC plugin requires a configuration file in ${CONFIG_DIR}
                  - whether the HC plugin is scheduled by cron
--list-core     : show the available core plugins (mail,SMS,...)
--list-include  : show the available includes/libraries
--log-healthy   : log/show also passed health checks. By default this is off when the plugin support this feature.
                  (can be overridden by --no-log to disable all logging)
--mail-to       : list of e-mail address(es) to which an e-mail alert will be send to [requires mail core plugin]
--newer         : show the (failed) events for each HC that are newer than the given date
--no-lock       : disable locking to allow concurrent script executions
--no-log        : do not log any messages to the script log file or health check results.
--no-monitor    : do not stop the execution of a HC after \$HC_TIME_OUT seconds
--notify        : notify upon HC failure(s). Multiple options may be specified if comma-separated (see --list-core for availble formats)
--older         : show the (failed) events for each HC that are older than the given date
--report        : report on failed HC events (STDOUT is the default reporting method)
--reverse       : show the report in reverse date order (newest events first)
--run           : execute HC(s).
--show          : show information/documentation on a HC
--show-stats    : show statistics on HC events (current & archived)
--sms-provider  : name of a supported SMS provider (see \$SMS_PROVIDERS) [requires SMS core plugin]
--sms-to        : name of person or group to which a sms alert will be send to [requires SMS core plugin]
--timeout       : maximum runtime of a HC plugin in seconds (overrides \$HC_TIME_OUT)
--today         : show today's (failed) events (HC and their combined STC value)
--version       : show the timestamp of the script.
--with-history  : also include events that have been archived already (reporting)
--with-rc       : define RC handling (plugin) when --flip-rc is used

EOT
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: do_cleanup()
# DOES: remove temporary file(s)/director(y|ies)
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: log()
function do_cleanup
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
log "performing cleanup ..."

# remove temporary files
[[ -f "${HC_MSG_FILE}" ]] && rm -f ${HC_MSG_FILE} >/dev/null 2>&1

# remove trailing log files
[[ -f "${HC_STDOUT_LOG}" ]] && rm -f ${HC_STDOUT_LOG} >/dev/null 2>&1
[[ -f "${HC_STDERR_LOG}" ]] && rm -f ${HC_STDERR_LOG} >/dev/null 2>&1

# remove lock directory
if [[ -d ${LOCK_DIR} ]]
then
    rm -rf ${LOCK_DIR} >/dev/null 2>&1
    log "${LOCK_DIR} lock directory removed"
fi

log "*** finish of ${SCRIPT_NAME} [${CMD_LINE}] ***"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: fix_symlinks()
# DOES: create symbolic links to HC scripts to satisfy KSH autoloader
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function fix_symlinks
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset FDIR=""
typeset FFILE=""
typeset FSYML=""

# find missing symlinks (do not skip core plug-ins here)
print "${FPATH}" | tr ':' '\n' 2>/dev/null | while read -r FDIR
do
    find ${FDIR} -type f -print 2>/dev/null | while read -r FFILE
    do
        FSYML="${FFILE%.sh}"
        # check if symlink already exists
        if [[ ! -h "${FSYML}" ]]
        then
            ln -s "${FFILE##*/}" "${FSYML}" >/dev/null
            # shellcheck disable=SC2181
            (( $? == 0 )) && \
                print -u2 "INFO: created symbolic link ${FFILE} -> ${FSYML}"
        fi
    done
done

# find & remove broken symbolic links (do not skip core plug-ins here)
print "${FPATH}" | tr ':' '\n' 2>/dev/null | while read -r FDIR
do
    # do not use 'find -type l' here!
    # shellcheck disable=SC2010
    ls ${FDIR} 2>/dev/null | grep -v "\." 2>/dev/null | while read -r FSYML
    do
        # check if file is a dead symlink
        if [[ -h "${FDIR}/${FSYML}" ]] && [[ ! -f "${FDIR}/${FSYML}" ]]
        then
            rm -f "${FDIR}/${FSYML}" >/dev/null
            # shellcheck disable=SC2181
            (( $? == 0 )) && print -u2 "INFO: removed dead symbolic link ${FSYML}"
        fi
    done
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: read_config()
# DOES: read & parse the main configuration file(s)
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: die()
function read_config
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

if [[ -z "${CONFIG_FILE}" ]] || [[ -z "${CONFIG_FILE}" ]]
then
    die "you must define a value for the CONFIG_DIR and CONFIG_FILE setting in $0"
fi
if [[ ! -r "${CONFIG_FILE}" ]]
then
    die "unable to read configuration file at ${CONFIG_FILE}"
else
    # shellcheck source=/dev/null
    . "${CONFIG_FILE}"
fi

return 0
}


#******************************************************************************
# MAIN routine
#******************************************************************************

# parse arguments/parameters
CMD_LINE="$*"
[[ -z "${CMD_LINE}" ]] && display_usage && exit 0
for CMD_PARAMETER in ${CMD_LINE}
do
    # ARG_ACTION is a toggle, do not allow double toggles
    case ${CMD_PARAMETER} in
        -archive|--archive)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=10
            fi
            ARG_LOCK=1
            ;;
        -archive-all|--archive-all)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=13
            fi
            ;;
        -check|--check)
            ARG_ACTION=1
            ;;
        -c|-check-host|--check-host)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=4
            fi
            ARG_CHECK_HOST=1
            ;;
        -config-file=*)
            ARG_CONFIG_FILE="${CMD_PARAMETER#-config-file=}"
            ;;
        --config-file=*)
            ARG_CONFIG_FILE="${CMD_PARAMETER#--config-file=}"
            ;;
        -debug|--debug)
            ARG_DEBUG=1
            PS4='DEBUG: $0: line $LINENO: '
            set "${DEBUG_OPTS}"
            ;;
        -debug-level=*)
            ARG_DEBUG_LEVEL="${CMD_PARAMETER#-debug-level=}"
            ;;
        --debug-level=*)
            ARG_DEBUG_LEVEL="${CMD_PARAMETER#--debug-level=}"
            ;;
        -detail|--detail)
            # shellcheck disable=SC2034
            ARG_DETAIL=1
            ;;
        -d|-disable|--disable)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=2
            fi
            ;;
        -disable-all|--disable-all)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=6
            fi
            ;;
        -display|--display)
            # STDOUT as default
            ARG_DISPLAY=""
            ;;
        -display=*)
            ARG_DISPLAY="${CMD_PARAMETER#-display=}"
            ;;
        --display=*)
            # shellcheck disable=SC2034
            ARG_DISPLAY="${CMD_PARAMETER#--display=}"
            ;;
        -e|-enable|--enable)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=3
            fi
            ;;
        -enable-all|--enable-all)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=7
            fi
            ;;
        -f|-fix-symlinks|--fix-symlinks)
            read_config
            check_config
            build_fpath
            check_shell
            check_user
            fix_symlinks
            exit 0
            ;;
        -fix-logs|--fix-logs)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=12
            fi
            ARG_LOCK=1
            ;;
        -flip-rc|--flip-rc)
            ARG_FLIP_RC=1
            ;;
        -hc=*)
            ARG_HC="${CMD_PARAMETER#-hc=}"
            ;;
        --hc=*)
            ARG_HC="${CMD_PARAMETER#--hc=}"
            ;;
        -hc-args=*)
            ARG_HC_ARGS="${CMD_PARAMETER#-hc-args=}"
            ;;
        --hc-args=*)
            ARG_HC_ARGS="${CMD_PARAMETER#--hc-args=}"
            ;;
        -id=*)
            # shellcheck disable=SC2034
            ARG_FAIL_ID="${CMD_PARAMETER#-id=}"
            ;;
        --id=*)
            # shellcheck disable=SC2034
            ARG_FAIL_ID="${CMD_PARAMETER#--id=}"
            ;;
        -last|--last)
            # shellcheck disable=SC2034
            ARG_LAST=1
            ;;
        -list|--list)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=9
            fi
            ;;
        -list=*)
            ARG_LIST="${CMD_PARAMETER#-list=}"
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=9
            fi
            ;;
        --list=*)
            ARG_LIST="${CMD_PARAMETER#--list=}"
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=9
            fi
            ;;
        -list-hc|--list-hc|-list-all|--list-all)
            print -u2 "WARN: deprecated option. Use --list | --list=<needle>"
            exit 0
            ;;
        -list-core|--list-core)
            read_config
            check_config
            build_fpath
            check_core
            check_shell
            check_user
            list_core
            exit 0
            ;;
        -list-include|--list-include)
            read_config
            check_config
            build_fpath
            check_core
            check_shell
            check_user
            list_include
            exit 0
            ;;
        -log-healthy|--log-healthy)
            ARG_LOG_HEALTHY=1
            ;;
        -mail-to=*)
            ARG_MAIL_TO="${CMD_PARAMETER#-mail-to=}"
            ;;
        --mail-to=*)
            # shellcheck disable=SC2034
            ARG_MAIL_TO="${CMD_PARAMETER#--mail-to=}"
            ;;
        -newer=*)
            ARG_NEWER="${CMD_PARAMETER#-newer=}"
            ;;
        --newer=*)
            # shellcheck disable=SC2034
            ARG_NEWER="${CMD_PARAMETER#--newer=}"
            ;;
        -notify=*)
            ARG_NOTIFY="${CMD_PARAMETER#-notify=}"
            ;;
        --notify=*)
            # shellcheck disable=SC2034
            ARG_NOTIFY="${CMD_PARAMETER#--notify=}"
            ;;
        -no-log|--no-log)
            ARG_LOG=0
            ;;
        -no-lock|--no-lock)
            ARG_LOCK=0
            ;;
        -no-monitor|--no-monitor)
            ARG_MONITOR=0
            ;;
        -older=*)
            ARG_OLDER="${CMD_PARAMETER#-older=}"
            ;;
        --older=*)
            # shellcheck disable=SC2034
            ARG_OLDER="${CMD_PARAMETER#--older=}"
            ;;
        -report|--report)   # compatability support <2017-12-15
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=8
            fi
            # STDOUT as default
            ARG_REPORT="std"
            ARG_LOG=0; ARG_VERBOSE=0
            ;;
        -report=*)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=8
            fi
            ARG_REPORT="${CMD_PARAMETER#-report=}"
            ARG_LOG=0; ARG_VERBOSE=0
            ;;
        --report=*)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=8
            fi
            # shellcheck disable=SC2034
            ARG_REPORT="${CMD_PARAMETER#--report=}"
            ARG_LOG=0; ARG_VERBOSE=0
            ;;
        -reverse|--reverse)
            # shellcheck disable=SC2034
            ARG_REVERSE=1
            ;;
        -r|-run|--run)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=4
            fi
            ;;
        -s|-show|--show)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=5
            fi
            ARG_LOG=0
            # shellcheck disable=SC2034
            ARG_VERBOSE=0
            ;;
        -show-stats|--show-stats)
            if (( ARG_ACTION > 0 ))
            then
                print -u2 "ERROR: you cannot request two actions at the same time"
                exit 1
            else
                ARG_ACTION=11
            fi
            ;;
        -sms-provider=*)
            ARG_SMS_PROVIDER="${CMD_PARAMETER#-sms-provider=}"
            ;;
        --sms-provider=*)
            # shellcheck disable=SC2034
            ARG_SMS_PROVIDER="${CMD_PARAMETER#--sms-provider=}"
            ;;
        -sms-to=*)
            ARG_SMS_TO="${CMD_PARAMETER#-sms-to=}"
            ;;
        --sms-to=*)
            # shellcheck disable=SC2034
            ARG_SMS_TO="${CMD_PARAMETER#--sms-to=}"
            ;;
        -timeout=*)
            ARG_TIME_OUT="${CMD_PARAMETER#-timeout=}"
            ;;
        --timeout=*)
            ARG_TIME_OUT="${CMD_PARAMETER#--timeout=}"
            ;;
        -today|--today)
            # shellcheck disable=SC2034
            ARG_TODAY=1
            ;;
        -v|-version|--version)
            print "INFO: $0: ${SCRIPT_VERSION}"
            exit 0
            ;;
        -with-history|--with-history)
            # shellcheck disable=SC2034
            ARG_HISTORY=1
            ;;
        -with-rc=*)
            # shellcheck disable=SC2034
            ARG_WITH_RC="${CMD_PARAMETER#-with-rc=}"
            ;;
        --with-rc=*)
            # shellcheck disable=SC2034
            ARG_WITH_RC="${CMD_PARAMETER#--with-rc=}"
            ;;
        \?|-h|-help|--help)
            display_usage
            exit 0
            ;;
        -help-terse|--help-terse)
            ARG_TERSE=1
            display_usage
            exit 0
            ;;
        *)
            display_usage
            exit 0
            ;;
    esac
done

# startup checks & processing (no build_fpath() here to avoid dupes in FPATH!)
read_config
check_config
build_fpath
check_core
check_shell
check_params        # parse cmd-line
discover_core       # parse cmd-line (for core plugins)
check_user

# catch shell signals
trap 'do_cleanup; exit 1' HUP INT QUIT TERM

# set debugging options
if (( ARG_DEBUG > 0 ))
then
    case ${ARG_DEBUG_LEVEL} in
        0)
            # display only messages via debug() (default)
            :
            ;;
        1)
            # set -x
            DEBUG_OPTS='-x'
            ;;
        2)
            # set -vx
            DEBUG_OPTS='-vx'
            ;;
    esac
set "${DEBUG_OPTS}"
fi

log "*** start of ${SCRIPT_NAME} [${CMD_LINE}] ***"
(( ARG_LOG > 0 )) && log "logging takes places in ${LOG_FILE}"

# check/create lock file & write PID file (only for --run/--archive/--fix-logs)
(( ARG_ACTION == 4 || ARG_ACTION == 11 || ARG_ACTION == 12 )) && check_lock_dir

# general HC log
# shellcheck disable=SC2034
HC_LOG="${LOG_DIR}/hc.log"

# get linux stuff
[[ "${OS_NAME}" = "Linux" ]] && linux_get_distro        # use =, ksh88

# act on HC check(s)
case ${ARG_ACTION} in
    1)  # check (status) HC(s)
        print "${ARG_HC}" | tr ',' '\n' 2>/dev/null | grep -v '^$' 2>/dev/null |\
            while read -r HC_CHECK
        do
            # check for HC (function)
            exists_hc "${HC_CHECK}" && die "cannot find HC: ${HC_CHECK}"
            stat_hc "${HC_CHECK}"
            # shellcheck disable=SC2181
            if (( $? == 0 ))
            then
                log "HC ${HC_CHECK} is currently disabled"
            else
                log "HC ${HC_CHECK} is currently enabled"
            fi
            is_scheduled "${HC_CHECK}"
            # shellcheck disable=SC2181
            if (( $? == 0 ))
            then
                log "HC ${HC_CHECK} is currently not scheduled (cron)"
            else
                log "HC ${HC_CHECK} is currently scheduled (cron)"
            fi
        done
        ;;
    2)  # disable HC(s)
        print "${ARG_HC}" | tr ',' '\n' 2>/dev/null | grep -v '^$' 2>/dev/null |\
            while read -r HC_DISABLE
        do
            # check for HC (function)
            exists_hc "${HC_DISABLE}" && die "cannot find HC: ${HC_DISABLE}"
            log "disabling HC: ${HC_DISABLE}"
            touch "${STATE_PERM_DIR}/${HC_DISABLE}.disabled" >/dev/null 2>&1
            # shellcheck disable=SC2181
            if (( $? == 0 ))
            then
                log "successfully disabled HC: ${HC_DISABLE}"
            else
                log "failed to disable HC: ${HC_DISABLE} [RC=${DISABLE_RC}]"
                EXIT_CODE=1
            fi
        done
        ;;
    3)  # enable HC(s)
        print "${ARG_HC}" | tr ',' '\n' 2>/dev/null | grep -v '^$' 2>/dev/null |\
            while read -r HC_ENABLE
        do
            # check for HC (function)
            exists_hc "${HC_ENABLE}" && die "cannot find HC: ${HC_ENABLE}"
            log "enabling HC: ${HC_ENABLE}"
            [[ -d ${STATE_PERM_DIR} ]] || \
                die "state directory does not exist, all HC(s) are enabled"
            stat_hc "${HC_ENABLE}" || die "HC is already enabled"
            rm -f "${STATE_PERM_DIR}/${HC_ENABLE}.disabled" >/dev/null 2>&1
            # shellcheck disable=SC2181
            if (( $? == 0 ))
            then
                log "successfully enabled HC: ${HC_ENABLE}"
            else
                log "failed to enable HC: ${HC_ENABLE} [RC=${ENABLE_RC}]"
                EXIT_CODE=1
            fi
        done
        ;;
    4)  # run HC(s)
        # pre-allocate FAIL_ID
        HC_NOW="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
        if [[ -z "${HC_FAIL_ID}" ]]
        then
            HC_FAIL_ID="$(print "${HC_NOW}" | tr -d '\-:[:space:]')"
        fi
        # --check-host handling
        (( ARG_CHECK_HOST == 1 )) && init_check_host
        # execute plug-in(s)
        print "${ARG_HC}" | tr ',' '\n' 2>/dev/null | grep -v '^$' 2>/dev/null |\
            while read -r HC_RUN
        do
            # re-initialize messages stash (log of failed checks)
            # shellcheck disable=SC2034
            HC_MSG_VAR=""
            : >${HC_MSG_FILE} 2>/dev/null
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                die "unable to reset the \${HC_MSG_FILE} file"
            fi
            # check for HC (function)
            exists_hc "${HC_RUN}"
            # shellcheck disable=SC2181
            if (( $? == 0 ))
            then
                # callback for display_init with extra code 'MISSING'
                if (( DO_DISPLAY_INIT == 1 ))
                then
                    display_init "${HC_RUN}" "" "MISSING"
                else
                    warn "cannot find HC: ${HC_RUN}"
                    EXIT_CODE=1
                fi
                continue
            fi
            stat_hc "${HC_RUN}"
            # shellcheck disable=SC2181
            if (( $? == 0 ))
            then
                # call for display_init with extra code 'DISABLED'
                if (( DO_DISPLAY_INIT == 1 ))
                then
                    display_init "${HC_RUN}" "" "DISABLED"
                else
                    warn "may not run disabled HC: ${HC_RUN}"
                    EXIT_CODE=0
                fi
                continue
            fi
            # set & initialize STDOUT/STDERR locations (not in init_hc()!)
            HC_STDOUT_LOG="${TMP_DIR}/${HC_RUN}.stdout.log.$$"
            HC_STDERR_LOG="${TMP_DIR}/${HC_RUN}.stderr.log.$$"
            : >${HC_STDOUT_LOG} 2>/dev/null
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                die "unable to reset the \${HC_STDOUT_LOG} file"
            fi
            : >${HC_STDERR_LOG} 2>/dev/null
            # shellcheck disable=SC2181
            if (( $? > 0 ))
            then
                die "unable to reset the \${HC_STDERR_LOG} file"
            fi

            # --check-host handling: alternative configuration file, mangle ARG_CONFIG_FILE & HC_TIME_OUT
            if (( ARG_CHECK_HOST == 1 ))
            then
                ARG_CONFIG_FILE=""      # reset from previous call
                RUN_CONFIG_FILE=$(grep -i -E -e "^hc:${HC_RUN}:" ${HOST_CONFIG_FILE} 2>/dev/null | cut -f3 -d':')
                [[ -n "${RUN_CONFIG_FILE}" ]] && ARG_CONFIG_FILE="${CONFIG_DIR}/${RUN_CONFIG_FILE}"
                RUN_TIME_OUT=$(grep -i -E -e "^hc:${HC_RUN}:" ${HOST_CONFIG_FILE} 2>/dev/null | cut -f5 -d':')
                if [[ -n "${RUN_TIME_OUT}" ]]
                then
                    (( RUN_TIME_OUT > HC_TIME_OUT )) && HC_TIME_OUT=${RUN_TIME_OUT}
                else
                    # reset for next HC
                    HC_TIME_OUT=60
                fi
            fi

            # run HC with or without monitor
            if (( ARG_MONITOR == 0 ))
            then
                ${HC_RUN} ${ARG_HC_ARGS}
                RUN_RC=$?
                EXIT_CODE=${RUN_RC}
                if (( RUN_RC == 0 ))
                then
                    log "executed HC: ${HC_RUN} [RC=${RUN_RC}]"
                    # call for display_init with extra code 'OK' because some plugin end
                    # successfully *without* any entries in $HC_MSG_FILE (so handle_hc will
                    # never get to display_init())
                    if (( DO_DISPLAY_INIT == 1 )) &&  [[ ! -s "${HC_MSG_FILE}" ]]
                    then
                        display_init "${HC_RUN}" "" "OK"
                    fi
                else
                    # call for display_init with extra code 'ERROR'
                    if (( DO_DISPLAY_INIT == 1 ))
                    then
                        # only do call if we have an empty messages stash
                        # (otherwise handle_hc() will call display_init())
                        [[ -s "${HC_MSG_FILE}" ]] || display_init "${HC_RUN}" "" "ERROR"
                    else
                        warn "failed to execute HC: ${HC_RUN} [RC=${RUN_RC}]"
                    fi
                fi
            else
                # set trap on SIGUSR1
                trap "handle_timeout" USR1

                # $PID is PID of the owner shell
                OWNER_PID=$$
                (
                    # sleep for $TIME_OUT seconds. If the sleep subshell is then still alive, send a SIGUSR1 to the owner
                    sleep ${HC_TIME_OUT}
                    kill -s USR1 ${OWNER_PID} >/dev/null 2>&1
                ) &
                # SLEEP_PID is the PID of the sleep subshell itself
                SLEEP_PID=$!

                ${HC_RUN} ${ARG_HC_ARGS} &
                CHILD_PID=$!
                log "spawning child process with time-out of ${HC_TIME_OUT} secs for HC call [PID=${CHILD_PID}]"
                # wait for the command to complete
                wait ${CHILD_PID}
                # when the child completes, we can get rid of the sleep trigger
                RUN_RC=$?
                EXIT_CODE=${RUN_RC}
                kill -s TERM ${SLEEP_PID} >/dev/null 2>&1
                # process return codes
                if (( RUN_RC > 0 ))
                then
                    # call for display_init with extra code 'ERROR'
                    if (( DO_DISPLAY_INIT == 1 ))
                    then
                        # only do call if we have an empty messages stash
                        # (otherwise handle_hc() will call display_init())
                        [[ -s "${HC_MSG_FILE}" ]] || display_init "${HC_RUN}" "" "ERROR"
                    else
                        warn "failed to execute HC: ${HC_RUN} [RC=${RUN_RC}]"
                    fi
                else
                    if (( CHILD_ERROR == 0 ))
                    then
                        log "executed HC: ${HC_RUN} [RC=${RUN_RC}]"
                        # call for display_init with extra code 'OK' because some plugin end
                        # successfully *without* any entries in $HC_MSG_FILE (so handle_hc will
                        # never get to display_init())
                        if (( DO_DISPLAY_INIT == 1 )) &&  [[ ! -s "${HC_MSG_FILE}" ]]
                        then
                            display_init "${HC_RUN}" "" "OK"
                        fi
                    else
                        # call for display_init with extra code 'ERROR'
                        if (( DO_DISPLAY_INIT == 1 ))
                        then
                            # only do call if we have an empty messages stash
                            # (otherwise handle_hc() will call display_init())
                            [[ -s "${HC_MSG_FILE}" ]] || display_init "${HC_RUN}" "" "ERROR"
                        else
                            warn "failed to execute HC as background process"
                        fi
                    fi
                fi
            fi

            # reset FAIL_ID & HC failure storage (also for failed HCs)
            handle_hc "${HC_RUN}"
            # exit with return code from handle_hc() (see --flip-rc)
            EXIT_CODE=$?
            rm -f ${HC_MSG_FILE} >/dev/null 2>&1
        done
        ;;
    5)  # show info on HC (single)
        exists_hc "${ARG_HC}"
        # shellcheck disable=SC2181
        if (( $? == 0 ))
        then
            die "cannot find HC: ${ARG_HC}"
        else
            ${ARG_HC} "help"
        fi
        ;;
    6)  # disable all HCs
        list_hc "list" | while read -r HC_DISABLE
        do
            # check for HC (function)
            exists_hc "${HC_DISABLE}" && die "cannot find HC: ${HC_DISABLE}"
            log "disabling HC: ${HC_DISABLE}"
            touch "${STATE_PERM_DIR}/${HC_DISABLE}.disabled" >/dev/null 2>&1
            DISABLE_RC=$?
            if (( DISABLE_RC == 0 ))
            then
                log "successfully disabled HC: ${HC_DISABLE}"
            else
                log "failed to disable HC: ${HC_DISABLE} [RC=${DISABLE_RC}]"
                EXIT_CODE=1
            fi
        done
        ;;
    7)  # enable all HCs
        list_hc "list" | while read -r HC_ENABLE
        do
            # check for HC (function)
            exists_hc "${HC_ENABLE}" && die "cannot find HC: ${HC_ENABLE}"
            log "enabling HC: ${HC_ENABLE}"
            [[ -d ${STATE_PERM_DIR} ]] || \
                die "state directory does not exist, all HC(s) are enabled"
            rm -f "${STATE_PERM_DIR}/${HC_ENABLE}.disabled" >/dev/null 2>&1
            ENABLE_RC=$?
            if (( ENABLE_RC == 0 ))
            then
                log "successfully enabled HC: ${HC_ENABLE}"
            else
                log "failed to enable HC: ${HC_ENABLE} [RC=${ENABLE_RC}]"
                EXIT_CODE=1
            fi
        done
        ;;
    8)  # report on HC events
        (( DO_REPORT_STD == 1 )) && report_std
        ;;
    9)  # list HC plugins
        list_hc "" "${ARG_LIST}"
        ;;
    10) # archive current log entries for a HC
        exists_hc "${ARG_HC}" && die "cannot find HC: ${ARG_HC}"
        log "archiving current log entries for ${ARG_HC}..."
        archive_hc "${ARG_HC}"
        ARCHIVE_RC=$?
        case ${ARCHIVE_RC} in
            0)
                log "no archiving needed for ${ARG_HC}"
                ;;
            1)
                log "successfully archived log entries for ${ARG_HC}"
                ;;
            2)
                log "failed to archive log entries for ${ARG_HC} [RC=${ARCHIVE_RC}]"
                EXIT_CODE=1
                ;;
        esac
        ;;
    11) # show HC event statistics
        show_statistics
        ;;
    12)
        # fix rogue log entries
        fix_logs
        FIX_RC=$?
        case ${FIX_RC} in
            0)
                :   # feedback via fix_logs()
                ;;
            1)
                log "successfully fixed log entries"
                ;;
            2)
                log "failed to fix log entries [RC=${FIX_RC}]"
                EXIT_CODE=1
                ;;
        esac
        ;;
    13)  # archive current log entries for all HCs
        list_hc "list" | while read -r HC_ARCHIVE
        do
            # check for HC (function)
            exists_hc "${HC_ARCHIVE}" && die "cannot find HC: ${HC_ARCHIVE}"
            log "archiving current log entries for HC: ${HC_ARCHIVE}"
            archive_hc "${HC_ARCHIVE}"
            ARCHIVE_RC=$?
            case ${ARCHIVE_RC} in
                0)
                    log "no archiving needed for ${HC_ARCHIVE}"
                    ;;
                1)
                    log "successfully archived log entries for ${HC_ARCHIVE}"
                    ;;
                2)
                    log "failed to archive log entries for ${HC_ARCHIVE} [RC=${ARCHIVE_RC}]"
                    EXIT_CODE=1
                    ;;
            esac
        done
        ;;
esac

# finish up work
do_cleanup

exit ${EXIT_CODE}

#******************************************************************************
# END of script
#******************************************************************************
