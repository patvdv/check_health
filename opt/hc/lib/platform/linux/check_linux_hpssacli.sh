#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_hpssacli.sh
#******************************************************************************
# @(#) Copyright (C) 2016 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: check_linux_hpssacli
# DOES: _show_usage()
# EXPECTS: _show_usage()
# REQUIRES: data_comma2space(), data_is_numeric(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2016-04-01: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2018-11-18: do not trap on signal 0 [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added code for data_is_numeric() & support for
# @(#)             --log-healthy [Patrick Van der Veken]
# @(#) 2020-02-03: made slot num detection smarter + fixed error in reporting
# @(#)             when no problems [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_hpssacli
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2020-02-03"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}"  "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC_COUNT=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _TMP_FILE="${TMP_DIR}/.$0.tmp.$$"
typeset _HPSSACLI_BIN=""
typeset _SSA_LINE=""
typeset _SLOT_NUM=""
typeset _SLOT_NUMS=""
typeset _DO_SSA_CTRL=1
typeset _DO_SSA_ENCL=1
typeset _DO_SSA_PHYS=1
typeset _DO_SSA_LOGL=1
typeset _DO_CHECK=0

# set local trap for cleanup
# shellcheck disable=SC2064
trap "[[ -f ${_TMP_FILE} ]] && rm -f ${_TMP_FILE} >/dev/null 2>&1; return 1" 1 2 3 15

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
    case "${_ARG}" in
        help)
            _show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
            ;;
    esac
done

# handle configuration file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]]
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
# read required configuration values
_HPSSACLI_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'hpssacli_bin')
if [[ -z "${_HPSSACLI_BIN}" ]]
then
    warn "no value set for 'hpssacli_bin' in ${_CONFIG_FILE}"
    return 1
fi
_DO_SSA_CTRL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_ssa_controller')
case "${_DO_SSA_CTRL}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_ssa_controller' in ${_CONFIG_FILE}, using default"
        _DO_SSA_CTRL=1
        ;;
esac
_DO_SSA_ENCL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_ssa_enclosure')
case "${_DO_SSA_ENCL}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_ssa_enclosure' in ${_CONFIG_FILE}, using default"
        _DO_SSA_ENCL=1
        ;;
esac
_DO_SSA_PHYS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_ssa_physical')
case "${_DO_SSA_PHYS}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_ssa_physical' in ${_CONFIG_FILE}, using default"
        _DO_SSA_PHYS=1
        ;;
esac
_DO_SSA_LOGL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_ssa_logical')
case "${_DO_SSA_LOGL}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_ssa_logical' in ${_CONFIG_FILE}, using default"
        _DO_SSA_LOGL=1
        ;;
esac
# check for dependencies: we need to do DO_SSA_CTRL to have the slot info for all
# the other checks
_DO_CHECK=$(( _DO_SSA_ENCL + _DO_SSA_PHYS + _DO_SSA_LOGL ))
if (( _DO_CHECK > 0 && _DO_SSA_CTRL == 0 ))
then
    log "switching setting 'do_ssa_controller' to 1 to fetch slot info"
    _DO_SSA_CTRL=1
fi
_CFG_HEALTHY=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'log_healthy')
case "${_CFG_HEALTHY}" in
    yes|YES|Yes)
        _LOG_HEALTHY=1
        ;;
    *)
        # do not override hc_arg
        (( _LOG_HEALTHY > 0 )) || _LOG_HEALTHY=0
        ;;
esac

# log_healthy
(( ARG_LOG_HEALTHY > 0 )) && _LOG_HEALTHY=1
if (( _LOG_HEALTHY > 0 ))
then
    if (( ARG_LOG > 0 ))
    then
        log "logging/showing passed health checks"
    else
        log "showing passed health checks (but not logging)"
    fi
else
    log "not logging/showing passed health checks"
fi

# check for HP tools
if [[ ! -x ${_HPSSACLI_BIN} || -z "${_HPSSACLI_BIN}" ]]
then
    warn "${_HPSSACLI_BIN} is not installed here"
    return 1
fi

# --- perform checks ---
# CONTROLLER(s)
if (( _DO_SSA_CTRL > 0 ))
then
    ${_HPSSACLI_BIN} controller all show status >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPSSACLI_BIN} controller all show status' exited non-zero"
    # look for failures
    grep -i -E -e "(nok|fail.*)" ${_TMP_FILE} 2>/dev/null |\
        while read _SSA_LINE
    do
        _MSG="failure in controller"
        _STC_COUNT=$(( _STC_COUNT + 1 ))
        log_hc "$0" 1 "${_MSG}"
    done
    print "=== SSA controller(s) ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    # get all slot numbers for multiple raid controllers
    cat ${_TMP_FILE} | grep "in Slot [0-9]" 2>/dev/null | while read _SSA_LINE
    do
        _SLOT_NUM="$(print ${_SSA_LINE} | sed 's/.*in Slot \([0-9][0-9]*\).*/\1/' 2>/dev/null)"
        data_is_numeric "${_SLOT_NUM}"
        if (( $? == 0 ))
        then
            _SLOT_NUMS="${_SLOT_NUMS} ${_SLOT_NUM}"
        else
            warn "found RAID controller at illegal slot?: ${_SLOT_NUM}"
        fi
    done
else
    warn "${_HPSSACLI_BIN}: do_ssa_controller check is not enabled"
fi

# ENCLOSURE(s)
if (( _DO_SSA_ENCL > 0 ))
then
    for _CTRL_SLOT in ${_SLOT_NUMS}
    do
        ${_HPSSACLI_BIN} controller slot=${_CTRL_SLOT} enclosure all show \
            >${_TMP_FILE} 2>${_TMP_FILE}
        (( $? > 0 )) && \
            warn "'${_HPSSACLI_BIN} controller slot=${_CTRL_SLOT} enclosure all show' exited non-zero"
        # look for failures
        grep -i -E -e "(nok|fail.*)" ${_TMP_FILE} 2>/dev/null |\
            while read _SSA_LINE
        do
            _MSG="failure in enclosure for controller ${_CTRL_SLOT}"
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            log_hc "$0" 1 "${_MSG}"
        done
        print "=== SSA enclosure(s) ===" >>${HC_STDOUT_LOG}
        cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    done
else
    warn "${_HPSSACLI_BIN}: do_ssa_enclosure check is not enabled"
fi

# PHYSICAL DRIVE(s)
if (( _DO_SSA_PHYS > 0 ))
then
    for _CTRL_SLOT in ${_SLOT_NUMS}
    do
        ${_HPSSACLI_BIN} controller slot=${_CTRL_SLOT} physicaldrive all show status \
            >${_TMP_FILE} 2>${_TMP_FILE}
        (( $? > 0 )) && \
            warn "'${_HPSSACLI_BIN} controller slot=${_CTRL_SLOT} physicaldrive all show status' exited non-zero"
        # look for failures
        grep -i -E -e "(nok|fail.*)" ${_TMP_FILE} 2>/dev/null |\
            while read _SSA_LINE
        do
            _MSG="failure in physical drive(s) for controller ${_CTRL_SLOT}"
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            log_hc "$0" 1 "${_MSG}"
        done
        print "=== SSA physical drive(s) ===" >>${HC_STDOUT_LOG}
        cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    done
else
    warn "${_HPSSACLI_BIN}: do_ssa_physical check is not enabled"
fi

# LOGICAL DRIVE(s)
if (( _DO_SSA_LOGL > 0 ))
then
    for _CTRL_SLOT in ${_SLOT_NUMS}
    do
        ${_HPSSACLI_BIN} controller slot=${_CTRL_SLOT} logicaldrive all show status \
            >${_TMP_FILE} 2>${_TMP_FILE}
        (( $? > 0 )) && \
        warn "'${_HPSSACLI_BIN} controller slot=${_CTRL_SLOT}logicaldrive all show status' exited non-zero"
        # look for failures
        grep -i -E -e "(nok|fail)" ${_TMP_FILE} 2>/dev/null |\
            while read _SSA_LINE
        do
            _MSG="failure in logical drive(s) for controller ${_CTRL_SLOT}"
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            log_hc "$0" 1 "${_MSG}"
        done
        print "=== SSA logical drive(s) ===" >>${HC_STDOUT_LOG}
        cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    done
else
    warn "${_HPSSACLI_BIN}: do_ssa_logical check is not enabled"
fi

# report OK situation
if (( _LOG_HEALTHY > 0 && _STC_COUNT == 0 ))
then
    _MSG="no problems detected by {${_HPSSACLI_BIN}}"
    log_hc "$0" 0 "${_MSG}"
fi

[[ -f ${_TMP_FILE} ]] && rm -f ${_TMP_FILE} >/dev/null 2>&1

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with parameters:
                log_healthy=<yes|no>
                hpssacli_bin=<location_of_hpssacli_tool>
                do_ssa_controller=<0|1>
                do_ssa_enclosure=<0|1>
                do_ssa_physical=<0|1>
                do_ssa_logical=<0|1>
PURPOSE     : Checks for errors from the HP Proliant 'hpssacli' tool (see HP Proliant
              support pack (PSP))
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
