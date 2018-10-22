#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_linux_file_change.sh
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
# @(#) MAIN: check_linux_file_change
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_space2comma(), init_hc(), log_hc(), warn(),
#           openssl (sha256 digest) OR cksum (CRC32 digest)
#
# @(#) HISTORY:
# @(#) 2017-05-18: initial version [Patrick Van der Veken]
# @(#) 2018-05-21: STDERR fixes [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_linux_file_change
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _VERSION="2018-05-21"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="Linux"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_space2comma "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _STC_COUNT=0
typeset _DO_META_CHECK=0
typeset _CFG_STATE_FILE=""
typeset _STATE_FILE=""
typeset _STATE_FILE_LINE=""
typeset _FILE_TO_CHECK=""
typeset _EXCL_OBJECT=""
typeset _INCL_OBJECT=""
typeset _HAS_OPENSSL=0
typeset _HAS_CKSUM=0
typeset _OPENSSL_BIN=""
typeset _CKSUM_BIN=""
typeset _USE_OPENSSL=0
typeset _USE_CKSUM=0
typeset _TMP1_FILE="${TMP_DIR}/.$0.tmp1.$$"
typeset _TMP2_FILE="${TMP_DIR}/.$0.tmp2.$$"
typeset _TMP_INCL_FILE="${TMP_DIR}/.$0.tmp_incl.$$"
typeset _TMP_EXCL_FILE="${TMP_DIR}/.$0.tmp_excl.$$"
set -o noglob       # no file globbing

# set local trap for clean-up
trap "[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP_INCL_FILE} ]] && rm -f ${_TMP_INCL_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP_EXCL_FILE} ]] && rm -f ${_TMP_EXCL_FILE} >/dev/null 2>&1;
      return 0" 0
trap "[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP_INCL_FILE} ]] && rm -f ${_TMP_INCL_FILE} >/dev/null 2>&1;
      [[ -f ${_TMP_EXCL_FILE} ]] && rm -f ${_TMP_EXCL_FILE} >/dev/null 2>&1;
      return 1" 1 2 3 15

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
_CFG_STATE_FILE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'state_file')
if [[ -z "${_CFG_STATE_FILE}" ]]
then
    _STATE_FILE="${STATE_PERM_DIR}/discovered.file_change"
else
    _STATE_FILE="${STATE_PERM_DIR}/${_CFG_STATE_FILE}"
fi
log "using state file ${_STATE_FILE}"
_DO_META_CHECK=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'do_meta_check')
case "${_DO_META_CHECK}" in
    no|NO|No)
        _DO_META_CHECK=0
        log "check for meta characters is disabled"
        ;;
    *)
        _DO_META_CHECK=1
        log "check for meta characters is enabled"
        ;;
esac

# check for checksum tools
_OPENSSL_BIN="$(which openssl 2>>${HC_STDERR_LOG})"
[[ -x ${_OPENSSL_BIN} && -n "${_OPENSSL_BIN}" ]] && _HAS_OPENSSL=1
_CKSUM_BIN="$(which cksum 2>>${HC_STDERR_LOG})"
[[ -x ${_CKSUM_BIN} && -n "${_CKSUM_BIN}" ]] && _HAS_CKSUM=1
# prefer openssl (for sha256)
if (( _HAS_OPENSSL == 1 ))
then
    _USE_OPENSSL=1
elif (( _HAS_CKSUM == 1 ))
then
    _USE_CKSUM=1
else
    warn "unable to find the 'openssl/cksum' tools"
    return 1
fi

# check state file & TMP_FILEs
[[ -r ${_STATE_FILE} ]] || {
    >${_STATE_FILE}
    (( $? > 0 )) && {
        warn "failed to create new state file at ${_STATE_FILE}"
        return 1
    }
    log "created new state file at ${_STATE_FILE}"
}
>${_TMP_INCL_FILE}
(( $? > 0 )) && {
    warn "failed to create temporary file at ${_TMP_INCL_FILE}"
    return 1
}
>${_TMP_EXCL_FILE}
(( $? > 0 )) && {
    warn "failed to create temporary file at ${_TMP_EXCL_FILE}"
    return 1
}
>${_TMP1_FILE}
(( $? > 0 )) && {
    warn "failed to create temporary file at ${_TMP1_FILE}"
    return 1
}
>${_TMP2_FILE}
(( $? > 0 )) && {
    warn "failed to create temporary file at ${_TMP2_FILE}"
    return 1
}

# build list of configured objects: inclusion
grep -i '^incl:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _DUMMY _INCL_OBJECT
do
    # check for meta & globbing characters (*?[]{}|)
    if (( _DO_META_CHECK == 1 ))
    then
        case "${_INCL_OBJECT}" in
            *\**|*\?*|*\[*|*\]*|*\{*|*\}*|*\|*)
                warn "meta characters are not supported in the entry (incl:${_INCL_OBJECT})"
                continue
                ;;
        esac
    fi

    # expand directories
    if [[ -d ${_INCL_OBJECT} ]]
    then
        find ${_INCL_OBJECT} -type f -xdev >>${_TMP_INCL_FILE} 2>>${HC_STDERR_LOG}
    else
        print ${_INCL_OBJECT} >>${_TMP_INCL_FILE}
    fi
done

# build list of configured objects: exclusion
grep -i '^excl:' ${_CONFIG_FILE} 2>/dev/null |\
    while IFS=':' read _DUMMY _EXCL_OBJECT
do
    # check for meta & globbing characters (*?[]{}|)
    if (( _DO_META_CHECK == 1 ))
    then
        case "${_EXCL_OBJECT}" in
            *\**|*\?*|*\[*|*\]*|*\{*|*\}*|*\|*)
                warn "meta characters are not supported in the entry (excl:${_EXCL_OBJECT})"
                continue
                ;;
        esac
    fi

    # expand directories
    if [[ -d ${_EXCL_OBJECT} ]]
    then
        find ${_EXCL_OBJECT} -type f -xdev >>${_TMP_EXCL_FILE} 2>>${HC_STDERR_LOG}
    else
        print ${_EXCL_OBJECT} >>${_TMP_EXCL_FILE}
    fi
done

# subtract exclusion from inclusion (exclusion has higher priority)
sort ${_TMP_INCL_FILE} -o ${_TMP_INCL_FILE} 2>>${HC_STDERR_LOG}
sort ${_TMP_EXCL_FILE} -o ${_TMP_EXCL_FILE} 2>>${HC_STDERR_LOG}
comm -23 ${_TMP_INCL_FILE} ${_TMP_EXCL_FILE} 2>>${HC_STDERR_LOG} >${_TMP1_FILE}

# check discovered objects
while read _FILE_TO_CHECK
do
    # reset variables
    _STC=0
    _MSG=""
    _IS_NEW=0

    # object to check must be a file (and be present)
    if [[ ! -f ${_FILE_TO_CHECK} ]]
    then
        _MSG="${_FILE_TO_CHECK} is not a file or has disappeared"
        _STC=1
        log_hc "$0" ${_STC} "${_MSG}"
        continue
    fi

    # read entry from state file
    _STATE_FILE_LINE=$(grep -E -e "^${_FILE_TO_CHECK}\|" ${_STATE_FILE} 2>/dev/null)
    if [[ -n "${_STATE_FILE_LINE}" ]]
    then
        # field 1 is the file name
        _STATE_FILE_TYPE=$(print "${_STATE_FILE_LINE}" | cut -f2 -d'|' 2>/dev/null)
        _STATE_FILE_CKSUM=$(print "${_STATE_FILE_LINE}" | cut -f3 -d'|' 2>/dev/null)
    else
        _IS_NEW=1
    fi

    # compute new checksum (keep the same type as before)
    if (( _IS_NEW == 0 ))
    then
        case "${_STATE_FILE_TYPE}" in
            openssl-sha256)
                if (( _USE_OPENSSL == 1 ))
                then
                    _FILE_CKSUM=$(${_OPENSSL_BIN} dgst -sha256 ${_FILE_TO_CHECK} 2>>${HC_STDERR_LOG} | cut -f2 -d'=' 2>/dev/null | tr -d ' ' 2>/dev/null)
                    _FILE_TYPE="openssl-sha256"
                else
                    _MSG="cannot compute checksum [${_FILE_TYPE}] for ${_FILE_TO_CHECK}"
                    _STC=1
                fi
                ;;
            cksum-crc32)
                if (( _USE_CKSUM == 1 ))
                then
                    _FILE_CKSUM=$(${_CKSUM_BIN} ${_FILE_TO_CHECK} 2>>${HC_STDERR_LOG} | cut -f1 -d' ' 2>/dev/null)
                    _FILE_TYPE="cksum-crc32"
                else
                    _MSG="cannot compute checksum [${_FILE_TYPE}] for ${_FILE_TO_CHECK}"
                    _STC=1
                fi
                ;;
            *)
                _MSG="cannot compute checksum (unknown checksum type) for ${_FILE_TO_CHECK}"
                _STC=1
                ;;
        esac
    else
        # new file
        if (( _USE_OPENSSL == 1 ))
        then
            _FILE_CKSUM=$(${_OPENSSL_BIN} dgst -sha256 ${_FILE_TO_CHECK} 2>>${HC_STDERR_LOG} | cut -f2 -d'=' 2>/dev/null | tr -d ' ' 2>/dev/null)
            _FILE_TYPE="openssl-sha256"
        elif (( _USE_CKSUM == 1 ))
        then
            _FILE_CKSUM=$(${_CKSUM_BIN} ${_FILE_TO_CHECK} 2>>${HC_STDERR_LOG} | cut -f1 -d' ' 2>/dev/null)
            _FILE_TYPE="cksum-crc32"
        else
            _MSG="cannot compute checksum (openssl/cksum) for ${_FILE_TO_CHECK}"
            _STC=1
        fi
    fi

    # check for failed checksums
    if [[ -z "${_FILE_CKSUM}" ]]
    then
        _MSG="did not receive checksum (openssl/cksum) for ${_FILE_TO_CHECK}"
        _STC=1
    fi

    # bounce failures back and jump to next file
    if (( _STC != 0 ))
    then
        log_hc "$0" ${_STC} "${_MSG}"
        continue
    fi

    if (( _IS_NEW == 0 ))
    then
        # compare old vs new checksums
        if [[ "${_STATE_FILE_CKSUM}" != "${_FILE_CKSUM}" ]]
        then
            _MSG="${_FILE_TO_CHECK} has a changed checksum [${_FILE_TYPE}]"
            _STC=1
        else
            _MSG="${_FILE_TO_CHECK} has the same checksum [${_FILE_TYPE}]"
            _STC=0
        fi
    else
        _MSG="${_FILE_TO_CHECK} is a new file [${_FILE_TYPE}]"
        _STC=0
    fi

    # save entry to temp file
    printf "%s|%s|%s\n" "${_FILE_TO_CHECK}" "${_FILE_TYPE}" "${_FILE_CKSUM}" >>${_TMP2_FILE}

    # report with curr/exp values
    log_hc "$0" ${_STC} "${_MSG}" "${_FILE_CKSUM}" "${_STATE_FILE_CKSUM}"
done <${_TMP1_FILE}

# update state file (also if TMP2_FILE is empty)
if (( ARG_LOG != 0 ))
then
    [[ -s ${_TMP2_FILE} ]] || {
        warn "no files found to check, zeroing new state file"
    }
    mv ${_TMP2_FILE} ${_STATE_FILE} >/dev/null 2>&1
    (( $? > 0 )) && {
        warn "failed to move temporary state file"
        return 1
    }
fi

# clean up temporary files
[[ -f ${_TMP1_FILE} ]] && rm -f ${_TMP1_FILE} >/dev/null 2>&1
[[ -f ${_TMP2_FILE} ]] && rm -f ${_TMP2_FILE} >/dev/null 2>&1
[[ -f ${_TMP_INCL_FILE} ]] && rm -f ${_TMP_INCL_FILE} >/dev/null 2>&1
[[ -f ${_TMP_EXCL_FILE} ]] && rm -f ${_TMP_EXCL_FILE} >/dev/null 2>&1

return 0
}

# -----------------------------------------------------------------------------
function _show_usage
{
cat <<- EOT
NAME    : $1
VERSION : $2
CONFIG  : $3 with formatted stanzas:
            incl:<full path>
            excl:<full path>
PURPOSE : a KISS file integrity checker (like AIDE). Supports includes and excludes
          of files and directories (automatically expanded). Excludes have a higher
          priority than includes. Integrity checks will only be performed on files.
          Will detect changed, new & deleted files (but not when deleted files
          occur in an expanded directory tree). If you wish to detect deleted files:
          use only direct file references in the configuration file. Uses by preference
          openssl for hash calculation, with cksum as fall-back).
          Updated and deleted files will cause a HC failure, new files will not.
          CAVEAT EMPTOR: use only to check a relatively small number of files.
                         Processing a big number of files is likely to take
                         ages and probably will cause the plugin to time out
                         (see HC_TIME_OUT). YMMV.


EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
