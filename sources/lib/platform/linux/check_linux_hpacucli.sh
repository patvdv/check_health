#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_hpacucli.sh
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
# @(#) MAIN: check_linux_hpacucli
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc()
#
# @(#) HISTORY:
# @(#) 2013-09-09: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# @(#) 2018-10-28: fixed (linter) errors [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_hpacucli
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2018-10-28"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}"  "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC_COUNT=0
typeset _TMP_FILE="${TMP_DIR}/.$0.tmp.$$"
typeset _HPACUCLI_BIN=""
typeset _ACU_LINE=""
typeset _SLOT_NUM=""
typeset _SLOT_NUMS=""
typeset _DO_ACU_CTRL=1
typeset _DO_ACU_ENCL=1
typeset _DO_ACU_PHYS=1
typeset _DO_ACU_LOGL=1
typeset _DO_CHECK=0

# set local trap for cleanup
# shellcheck disable=SC2064
trap "[[ -f ${_TMP_FILE} ]] && rm -f ${_TMP_FILE} >/dev/null 2>&1; return 0" 0
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
_HPACUCLI_BIN=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'hpacucli_bin')
if [[ -z "${_HPACUCLI_BIN}" ]]
then
    warn "no value set for 'hpacucli_bin' in ${_CONFIG_FILE}"
    return 1
fi
_DO_ACU_CTRL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_acu_controller')
case "${_DO_ACU_CTRL}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_acu_controller' in ${_CONFIG_FILE}, using default"
        _DO_ACU_CTRL=1
        ;;
esac
_DO_ACU_ENCL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_acu_enclosure')
case "${_DO_ACU_ENCL}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_acu_enclosure' in ${_CONFIG_FILE}, using default"
        _DO_ACU_ENCL=1
        ;;
esac
_DO_ACU_PHYS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_acu_physical')
case "${_DO_ACU_PHYS}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_acu_physical' in ${_CONFIG_FILE}, using default"
        _DO_ACU_PHYS=1
        ;;
esac
_DO_ACU_LOGL=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_acu_logical')
case "${_DO_ACU_LOGL}" in
    0|1)
        # on/off, OK
        ;;
    *)
        # set default
        warn "illegal value for 'do_acu_logical' in ${_CONFIG_FILE}, using default"
        _DO_ACU_LOGL=1
        ;;
esac
# check for dependencies: we need to do DO_ACU_CTRL to have the slot info for all
# the other checks
_DO_CHECK=$(( _DO_ACU_ENCL + _DO_ACU_PHYS + _DO_ACU_LOGL ))
if (( _DO_CHECK > 0 && _DO_ACU_CTRL == 0 ))
then
    log "switching setting 'do_acu_controller' to 1 to fetch slot info"
    _DO_ACU_CTRL=1
fi

# check for HP tools
if [[ ! -x ${_HPACUCLI_BIN} || -z "${_HPACUCLI_BIN}" ]]
then
    warn "${_HPACUCLI_BIN} is not installed here"
    return 1
fi

# --- perform checks ---
# CONTROLLER(s)
if (( _DO_ACU_CTRL > 0 ))
then
    ${_HPACUCLI_BIN} controller all show status >${_TMP_FILE} 2>${_TMP_FILE}
    (( $? > 0 )) && warn "'${_HPACUCLI_BIN} controller all show status' exited non-zero"
    # look for failures
    grep -i -E -e "(nok|fail.*)" ${_TMP_FILE} 2>/dev/null |\
        while read _ACU_LINE
    do
        _MSG="failure in controller"
        _STC_COUNT=$(( _STC_COUNT + 1 ))
        # handle unit result
        log_hc "$0" 1 "${_MSG}"
    done
    print "=== ACU controller(s) ===" >>${HC_STDOUT_LOG}
    cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    # get all slot numbers for multiple raid controllers
    cat ${_TMP_FILE} | grep "in Slot [0-9]" 2>/dev/null | while read _ACU_LINE
    do
        _SLOT_NUM="$(print ${_ACU_LINE} | cut -f6 -d' ' 2>/dev/null)"
        case "${_DO_ACU_LOGL}" in
            +([0-9])*([0-9]))
                # numeric OK
                _SLOT_NUMS="${_SLOT_NUMS} ${_SLOT_NUM}"
                ;;
            *)
                # non-numeric
                warn "found RAID controller at illegal slot?: ${_SLOT_NUM}"
                ;;
            esac
    done
else
    warn "${_HPACUCLI_BIN}: do_acu_controller check is not enabled"
fi

# ENCLOSURE(s)
if (( _DO_ACU_ENCL > 0 ))
then
    for _CTRL_SLOT in ${_SLOT_NUMS}
    do
        ${_HPACUCLI_BIN} controller slot=${_CTRL_SLOT} enclosure all show \
            >${_TMP_FILE} 2>${_TMP_FILE}
        (( $? > 0 )) && \
            warn "'${_HPACUCLI_BIN} controller slot=${_CTRL_SLOT} enclosure all show' exited non-zero"
        # look for failures
        grep -i -E -e "(nok|fail.*)" ${_TMP_FILE} 2>/dev/null |\
            while read _ACU_LINE
        do
            _MSG="failure in enclosure for controller ${_CTRL_SLOT}"
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            # handle unit result
            log_hc "$0" 1 "${_MSG}"
        done
        print "=== ACU enclosure(s) ===" >>${HC_STDOUT_LOG}
        cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    done
else
    warn "${_HPACUCLI_BIN}: do_acu_enclosure check is not enabled"
fi

# PHYSICAL DRIVE(s)
if (( _DO_ACU_PHYS > 0 ))
then
    for _CTRL_SLOT in ${_SLOT_NUMS}
    do
        ${_HPACUCLI_BIN} controller slot=${_CTRL_SLOT} physicaldrive all show status \
            >${_TMP_FILE} 2>${_TMP_FILE}
        (( $? > 0 )) && \
            warn "'${_HPACUCLI_BIN} controller slot=${_CTRL_SLOT} physicaldrive all show status' exited non-zero"
        # look for failures
        grep -i -E -e "(nok|fail.*)" ${_TMP_FILE} 2>/dev/null |\
            while read _ACU_LINE
        do
            _MSG="failure in physical drive(s) for controller ${_CTRL_SLOT}"
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            # handle unit result
            log_hc "$0" 1 "${_MSG}"
        done
        print "=== ACU physical drive(s) ===" >>${HC_STDOUT_LOG}
        cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    done
else
    warn "${_HPACUCLI_BIN}: do_acu_physical check is not enabled"
    fi

# LOGICAL DRIVE(s)
if (( _DO_ACU_LOGL > 0 ))
then
    for _CTRL_SLOT in ${_SLOT_NUMS}
    do
        ${_HPACUCLI_BIN} controller slot=${_CTRL_SLOT} logicaldrive all show status \
            >${_TMP_FILE} 2>${_TMP_FILE}
        (( $? > 0 )) && \
            warn "'${_HPACUCLI_BIN} controller slot=${_CTRL_SLOT}logicaldrive all show status' exited non-zero"
        # look for failures
        grep -i -E -e "(nok|fail)" ${_TMP_FILE} 2>/dev/null |\
            while read _ACU_LINE
        do
            _MSG="failure in logical drive(s) for controller ${_CTRL_SLOT}"
            _STC_COUNT=$(( _STC_COUNT + 1 ))
            # handle unit result
            log_hc "$0" 1 "${_MSG}"
        done
        print "=== ACU logical drive(s) ===" >>${HC_STDOUT_LOG}
        cat ${_TMP_FILE} >>${HC_STDOUT_LOG}
    done
else
    warn "${_HPACUCLI_BIN}: do_acu_logical check is not enabled"
fi

# report OK situation
if (( _STC_COUNT == 0 ))
then
    _MSG="no problems detected by {${_HPACUCLI_BIN}}"
    log_hc "$0" 0 "${_MSG}"
fi

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with:
            hpacucli_bin=<location_of_hpacucli_tool>
            do_acu_controller=0|1
            do_acu_enclosure=0|1
            do_acu_physical=0|1
            do_acu_logical=0|1
PURPOSE : Checks for errors from the HP Proliant 'hpacucli' tool (see HP Proliant
          support pack (PSP))

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
