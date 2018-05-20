#!/usr/bin/env ksh
#******************************************************************************
# @(#) notify_mail.sh
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
# @(#) MAIN: notify_mail
# DOES: send e-mail alert
# EXPECTS: 1=HC name [string], 2=HC FAIL_ID [string]
# RETURNS: 0
# REQUIRES: curl, die(), init_hc(), log()
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function notify_mail
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _VERSION="2018-05-20"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _MAIL_HC="$1"
typeset _MAIL_FAIL_ID="$2"

typeset _HC_BODY=""
typeset _HC_STDOUT_LOG_SHORT=""
typeset _HC_STDERR_LOG_SHORT=""
typeset _HC_MSG_ENTRY=""
typeset _MAIL_MSG_STC=""
typeset _MAIL_MSG_TIME=""
typeset _MAIL_MSG_TEXT=""
typeset _MAIL_INFO_TPL="${CONFIG_DIR}/core/templates/mail_info.tpl"
typeset _MAIL_HEADER_TPL="${CONFIG_DIR}/core/templates/mail_header.tpl"
typeset _MAIL_BODY_TPL="${CONFIG_DIR}/core/templates/mail_body.tpl"
typeset _MAIL_FOOTER_TPL="${CONFIG_DIR}/core/templates/mail_footer.tpl"
typeset _MAIL_STDOUT_LOG=""
typeset _MAIL_STDERR_LOG=""
typeset _MAIL_STDOUT_MSG=""
typeset _MAIL_STDERR_MSG=""
typeset _MAIL_ATTACH_BIT=""
typeset _MAIL_METHOD=""
typeset _MAIL_RC=0
typeset _MAILX_BIN=""
typeset _MUTT_BIN=""
typeset _SENDMAIL_BIN=""
typeset _UUENCODE_BIN=""
typeset _TMP1_MAIL_FILE="${TMP_DIR}/.${SCRIPT_NAME}.mail.tmp1.$$"
typeset _TMP2_MAIL_FILE="${TMP_DIR}/.${SCRIPT_NAME}.mail.tmp2.$$"
typeset _NOW="$(date '+%d-%h-%Y %H:%M:%S')"
typeset _SUBJ_MSG="[${HOST_NAME}] HC ${_MAIL_HC} failed (${_NOW})"
typeset _FROM_MSG="${EXEC_USER}@${HOST_NAME}"
typeset _dummy=""

# set local trap for cleanup
trap "[[ -f ${_TMP1_MAIL_FILE} ]] && rm -f ${_TMP1_MAIL_FILE} >/dev/null 2>&1; [[ -f ${_TMP2_MAIL_FILE} ]] && rm -f ${_TMP2_MAIL_FILE} >/dev/null 2>&1; return 1" 1 2 3 15

# set short paths for STDOUT/STDERR logs
_HC_STDOUT_LOG_SHORT="${HC_STDOUT_LOG##*/}"
_HC_STDERR_LOG_SHORT="${HC_STDERR_LOG##*/}"

# check & determine mailer tools
case "${OS_NAME}" in
    "Linux")
        # prefer mutt :-)
        _MUTT_BIN="$(which mutt 2>/dev/null)"
        if [[ -x ${_MUTT_BIN} ]] && [[ -n "${_MUTT_BIN}" ]]
        then
            _MAIL_METHOD="mutt"
        else
            # prefer mailx next
            _MAILX_BIN="$(which mailx 2>/dev/null)"
            if [[ -x ${_MAILX_BIN} ]] && [[ -n "${_MAILX_BIN}" ]]
            then
                _MAIL_METHOD="mailx"
            else
                _MAIL_METHOD="sendmail"
            fi
        fi
        ;;
    *)
        _MAIL_METHOD="sendmail"
        ;;
esac
# check if fall-back & last resort exists
if [[ "${_MAIL_METHOD}" = "sendmail" ]]
then
    # find 'sendmail'
    _SENDMAIL_BIN="$(which sendmail 2>/dev/null)"
    if [[ ! -x ${_SENDMAIL_BIN} ]] || [[ -z "${_SENDMAIL_BIN}" ]]
    then
        die "unable to send e-mail - sendmail is not installed here"
    fi
    # find 'uuencode'
    _UUENCODE_BIN="$(which uuencode 2>/dev/null)"
    if [[ ! -x ${_UUENCODE_BIN} ]] || [[ -z "${_UUENCODE_BIN}" ]]
    then
        die "unable to send e-mail - uuencode is not installed here"
    fi
fi

# create info part (not for mailx or mutt)
if [[ "${_MAIL_METHOD}" = "sendmail" ]]
then
    [[ -r "${_MAIL_INFO_TPL}" ]] || die "cannot read mail info template at ${_MAIL_INFO_TPL}"
    eval "cat << __EOT
$(sed 's/[\$`]/\\&/g;s/<## @\([^ ]*\) ##>/${\1}/g' <${_MAIL_INFO_TPL})
__EOT" >${_TMP1_MAIL_FILE}
fi

# create header part
[[ -r "${_MAIL_HEADER_TPL}" ]] || die "cannot read mail header template at ${_MAIL_HEADER_TPL}"
eval "cat << __EOT
$(sed 's/[\$`]/\\&/g;s/<## @\([^ ]*\) ##>/${\1}/g' <${_MAIL_HEADER_TPL})
__EOT" >>${_TMP1_MAIL_FILE}

# create body part (from $HC_MSG_VAR)
print "${HC_MSG_VAR}" | while IFS=${MSG_SEP} read _MAIL_MSG_STC _MAIL_MSG_TIME _DISP_MAIL_MSG_TEXTLAY_MSG_TEXT _MAIL_MSG_CUR_VAL _MAIL_MSG_EXP_VAL
do
    # magically unquote if needed
    if [[ -n "${_MAIL_MSG_TEXT}" ]]
    then
        data_contains_string "${_MAIL_MSG_TEXT}" "${MAGIC_QUOTE}"
        if (( $? > 0 ))
        then
            _MAIL_MSG_TEXT=$(data_magic_unquote "${_MAIL_MSG_TEXT}")
        fi
    fi
    if [[ -n "${_MAIL_MSG_CUR_VAL}" ]]
    then
        data_contains_string "${_MAIL_MSG_CUR_VAL}" "${MAGIC_QUOTE}"
        if (( $? > 0 ))
        then
            _MAIL_MSG_CUR_VAL=$(data_magic_unquote "${_MAIL_MSG_CUR_VAL}")
        fi
    fi
    if [[ -n "${_MAIL_MSG_EXP_VAL}" ]]
    then
        data_contains_string "${_MAIL_MSG_EXP_VAL}" "${MAGIC_QUOTE}"
        if (( $? > 0 ))
        then
            _MAIL_MSG_EXP_VAL=$(data_magic_unquote "${_MAIL_MSG_EXP_VAL}")
        fi
    fi  
    if (( _MAIL_MSG_STC > 0 ))
    then
        _HC_BODY=$(printf "%s\n%s\n" "${_HC_BODY}" "${_MAIL_MSG_TEXT}")
    fi
done

# check for custom template
[[ -r "${_MAIL_BODY_TPL}-${_MAIL_HC}" ]] && _MAIL_BODY_TPL="${_MAIL_BODY_TPL}-${_MAIL_HC}"
[[ -r "${_MAIL_BODY_TPL}" ]] || die "cannot read mail body template at ${_MAIL_BODY_TPL}"
eval "cat << __EOT
$(sed 's/[\$`]/\\&/g;s/<## @\([^ ]*\) ##>/${\1}/g' <${_MAIL_BODY_TPL})
__EOT" >>${_TMP1_MAIL_FILE}

# HC STDOUT log? (drop the .$$ bit)
_MAIL_STDOUT_LOG="${EVENTS_DIR}/${DIR_PREFIX}/${_MAIL_FAIL_ID}/${_HC_STDOUT_LOG_SHORT%.*}"
if [[ -s "${_MAIL_STDOUT_LOG}" ]]
then
    _MAIL_STDOUT_MSG="${_MAIL_STDOUT_LOG}"
    _MAIL_ATTACH_BIT="-a ${_MAIL_STDOUT_LOG}"
else
    _MAIL_STDOUT_MSG="no log file available"
fi
# HC STDERR? (drop the .$$ bit)
_MAIL_STDERR_LOG="${EVENTS_DIR}/${DIR_PREFIX}/${_MAIL_FAIL_ID}/${_HC_STDERR_LOG_SHORT%.*}"
if [[ -s "${_MAIL_STDERR_LOG}" ]]
then
    _MAIL_STDERR_MSG="${_MAIL_STDERR_LOG}"
    _MAIL_ATTACH_BIT="${_MAIL_ATTACH_BIT} -a ${_MAIL_STDERR_LOG}"
else
    _MAIL_STDERR_MSG="no log file available"
fi

# create footer part
[[ -r ${_MAIL_FOOTER_TPL} ]] || die "cannot read mail body template at ${_MAIL_FOOTER_TPL}"
eval "cat << __EOT
$(sed 's/[\$`]/\\&/g;s/<## @\([^ ]*\) ##>/${\1}/g' <${_MAIL_FOOTER_TPL})
__EOT" >>${_TMP1_MAIL_FILE}

# combine and send message components
case "${_MAIL_METHOD}" in
    "mailx")
        # remove non-ASCII characters to avoid Exchange ATT00001.bin
        cat ${_TMP1_MAIL_FILE} | tr -cd '[:print:]\n' 2>/dev/null |\
            ${_MAILX_BIN} ${_MAIL_ATTACH_BIT} -s "${_SUBJ_MSG}" "${ARG_MAIL_TO}"
        _MAIL_RC=$?
        ;;
    "mutt")
        # attach bit goes at the end
        cat ${_TMP1_MAIL_FILE} 2>/dev/null |\
            ${_MUTT_BIN} -s "${_SUBJ_MSG}" "${ARG_MAIL_TO}" ${_MAIL_ATTACH_BIT}
        _MAIL_RC=$?
        ;;
    "sendmail")
        [[ -s "${_MAIL_STDOUT_LOG}" ]] && \
            uuencode ${_MAIL_STDOUT_LOG} stdout.log >>${_TMP2_MAIL_FILE} 2>/dev/null
        [[ -s "${_MAIL_STDERR_LOG}" ]] && \
            uuencode ${_MAIL_STDERR_LOG} stderr.log >>${_TMP2_MAIL_FILE} 2>/dev/null
        cat ${_TMP1_MAIL_FILE} ${_TMP2_MAIL_FILE} 2>/dev/null | ${_SENDMAIL_BIN} -t
        _MAIL_RC=$?
        ;;
    *)
        :
        ;;
esac

if (( _MAIL_RC == 0 ))
then
    log "e-mail alert sent/queued to ${ARG_MAIL_TO}: ${_MAIL_HC} failed, FAIL_ID=${_MAIL_FAIL_ID}"
else
    log "failed to send e-mail to ${ARG_MAIL_TO}: ${_MAIL_HC} failed, FAIL_ID=${_MAIL_FAIL_ID}"
fi

# clean up temporary files
[[ -f ${_TMP1_MAIL_FILE} ]] && rm -f ${_TMP1_MAIL_FILE} >/dev/null 2>&1
[[ -f ${_TMP2_MAIL_FILE} ]] && rm -f ${_TMP2_MAIL_FILE} >/dev/null 2>&1
 
return 0
}

#******************************************************************************
# END of script
#******************************************************************************
