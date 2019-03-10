#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_hpasmcli.sh
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
# @(#) MAIN: check_linux_hpasmcli
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2013-09-07: initial version [Patrick Van der Veken]
# @(#) 2017-04-06: bugfix in temperature checking [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# @(#) 2018-11-18: do not trap on signal 0 [Patrick Van der Veken]
# @(#) 2019-01-24: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: added support for --log-healthy [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_hpasmcli
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC_COUNT=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _TMP_FILE="${TMP_DIR}/.$0.tmp.$$"
typeset _HPASMCLI_BIN=""
typeset _ASM_LINE=""
typeset _DO_ASM_FANS=1
typeset _DO_ASM_DIMM=1
typeset _DO_ASM_POWR=1
typeset _DO_ASM_SRVR=1
typeset _DO_ASM_TEMP=1
typeset _FAN_UNIT=""
typeset _TEMP_FIELD=""
typeset _TEMP_VALUE=""
typeset _THRES_FIELD=""
typeset _THRES_VALUE=""
typeset _TEMP_UNIT=""

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
_HPASMCLI_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'hpasmcli_bin')
if [[ -z "${_HPASMCLI_BIN}" ]]
then
    warn "no value set for 'hpasmcli_bin' in ${_CONFIG_FILE}"
    return 1
fi
_DO_ASM_FANS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_asm_fans')
case "${_DO_ASM_FANS}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_asm_fans' in ${_CONFIG_FILE}, using default"
        _DO_ASM_FANS=1
        ;;
esac
_DO_ASM_DIMM=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_asm_dimm')
case "${_DO_ASM_DIMM}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_asm_dimm' in ${_CONFIG_FILE}, using default"
        _DO_ASM_DIMM=1
        ;;
esac
_DO_ASM_POWR=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_asm_powersupply')
case "${_DO_ASM_POWR}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_asm_powersupply' in ${_CONFIG_FILE}, using default"
        _DO_ASM_POWR=1
        ;;
esac
_DO_ASM_SRVR=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_asm_server')
case "${_DO_ASM_POWR}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_asm_server' in ${_CONFIG_FILE}, using default"
        _DO_ASM_SRVR=1
        ;;
esac
_DO_ASM_TEMP=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_asm_temperature')
case "${_DO_ASM_TEMP}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_asm_temperature' in ${_CONFIG_FILE}, using default"
        _DO_ASM_TEMP=1
        ;;
esac
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
if [[ ! -x ${_HPASMCLI_BIN} || -z "${_HPASMCLI_BIN}" ]]
then
    warn "${_HPASMCLI_BIN} is not installed here"
    return 1
fi

# --- perform checks ---
# SHOW FANS
if (( _DO_ASM_FANS > 0 ))
then
    ${_HPASMCLI_BIN} -s 'SHOW FANS' >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPASMCLI_BIN} -s SHOW FANS' exited non-zero"
    # look for failures
    grep -E -e '^#' ${_TMP_FILE} 2>/dev/null | grep -vi 'normal' 2>/dev/null |\
        while read _ASM_LINE
    do
        _FAN_UNIT="$(print ${_ASM_LINE} | cut -f1 -d' ')"
        _MSG="failure in 'SHOW FANS', unit ${_FAN_UNIT}"
        _STC_COUNT=$(( _STC_COUNT + 1 ))
        log_hc "$0" 1 "${_MSG}"
    done
    print "=== ASM fans ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
else
    warn "${_HPASMCLI_BIN}: do_asm_fans check not enabled"
fi

# SHOW DIMM
if (( _DO_ASM_DIMM > 0 ))
then
    ${_HPASMCLI_BIN} -s 'SHOW DIMM' >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPASMCLI_BIN} -s SHOW DIMM' exited non-zero"
    # look for failures
    grep -i -E -e "(nok|fail)" ${_TMP_FILE} 2>/dev/null |\
        while read _ASM_LINE
    do
        _MSG="failure in 'SHOW DIMM'"
        _STC_COUNT=$(( _STC_COUNT + 1 ))
        log_hc "$0" 1 "${_MSG}"
    done
    print "=== ASM DIMMs ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
else
    warn "${_HPASMCLI_BIN}: do_asm_dimm check not enabled"
fi

# SHOW POWERSUPPLY
if (( _DO_ASM_POWR > 0 ))
then
    ${_HPASMCLI_BIN} -s 'SHOW POWERSUPPLY' >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPASMCLI_BIN} -s SHOW POWERSUPPLY' exited non-zero"
    # look for failures
    grep -i -E -e "(nok|fail)" ${_TMP_FILE} 2>/dev/null |\
        while read _ASM_LINE
    do
        _MSG="failure in 'SHOW POWERSUPPLY'"
        _STC_COUNT=$(( _STC_COUNT + 1 ))
        log_hc "$0" 1 "${_MSG}"
    done
    print "=== ASM power supply ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
else
    warn "${_HPASMCLI_BIN}: do_asm_powersupply check not enabled"
fi

# SHOW SERVER
if (( _DO_ASM_SRVR > 0 ))
then
    ${_HPASMCLI_BIN} -s 'SHOW SERVER' >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPASMCLI_BIN} -s SHOW SERVER' exited non-zero"
    # look for failures
    grep -i -E -e "(nok|fail)" ${_TMP_FILE} 2>/dev/null |\
        while read _ASM_LINE
    do
        _MSG="failure in 'SHOW SERVER'"
        _STC_COUNT=$(( _STC_COUNT + 1 ))
        log_hc "$0" 1 "${_MSG}"
    done
    print "=== ASM server ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
else
    warn "${_HPASMCLI_BIN}: do_asm_server check not enabled"
    fi

# SHOW TEMP
if (( _DO_ASM_TEMP > 0 ))
then
    ${_HPASMCLI_BIN} -s 'SHOW TEMP' >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPASMCLI_BIN} -s SHOW TEMP' exited non-zero"
    # look for failures
    grep -E -e '^#' ${_TMP_FILE} 2>/dev/null |\
        while read _ASM_LINE
    do
        _TEMP_FIELD="$(print ${_ASM_LINE} | cut -f3 -d' ' 2>/dev/null)"
        _TEMP_VALUE="${_TEMP_FIELD%%C/*}"
        _THRES_FIELD="$(print ${_ASM_LINE} | cut -f4 -d' ' 2>/dev/null)"
        _THRES_VALUE="${_THRES_FIELD%%C/*}"
        if [[ "${_TEMP_VALUE}" != "-" ]] && [[ "${_THRES_VALUE}" != "-" ]]
        then
            if (( _TEMP_VALUE >= _THRES_VALUE ))
            then
                _TEMP_UNIT="$(print ${_ASM_LINE} | cut -f1 -d' ' 2>/dev/null)"
                _MSG="failure in 'SHOW TEMP', unit ${_TEMP_UNIT}"
                _MSG="${_MSG} has ${_TEMP_VALUE} >= ${_THRES_VALUE}"
                _STC_COUNT=$(( _STC_COUNT + 1 ))
                log_hc "$0" 1 "${_MSG}" "${_TEMP_VALUE}" "${_THRES_VALUE}"
            fi
        fi
    done
    print "=== ASM temperature ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
else
    warn "${_HPASMCLI_BIN}: do_asm_temperature check not enabled"
fi

# report OK situation
if (( _LOG_HEALTHY > 0 && _STC_COUNT == 0 ))
then
    _MSG="no problems detected by {${_HPASMCLI_BIN}}"
    log_hc "$0" 0 "${_MSG}"
fi

# do cleanup
[[ -f ${_TMP_FILE} ]] && rm -f ${_TMP_FILE} >/dev/null 2>&1

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME        : $1
VERSION     : $2
CONFIG      : $3 with paramets:
                log_healthy=<yes|no>
			    hpasmcli_bin=<location_of_hpasmcli_tool>
                do_asm_fans=<0|1>
                do_asm_dimm=<0|1>
                do_asm_powersupply=<0|1>
                do_asm_server=<0|1>
                do_asm_temperature=<0|1>
PURPOSE     : Checks for errors from the HP Proliant 'hpasmcli' tool (see HP Proliant
	          support pack (PSP))
LOG HEALTHY : Supported

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
