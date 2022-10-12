#!/usr/bin/env ksh
#******************************************************************************
# @(#) notify_slack.sh
#******************************************************************************
# @(#) Copyright (C) 2022 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: notify_slack
# DOES: send message to slack app
# EXPECTS: 1=HC name [string], 2=HC FAIL_ID [string]
# RETURNS: 0
# REQUIRES: data_contains_string(), data_get_lvalue_from_config(), data_magic_unquote(),
#           init_hc(), log(), warn(), curl
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function notify_slack
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/core/providers/$0.conf"
typeset _VERSION="2022-10-14"                               # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"

typeset _SLACK_HC="$1"
typeset _SLACK_FAIL_ID="$2"

typeset _SLACK_TEXT=""
typeset _SLACK_MSG_STC=""
typeset _SLACK_MSG_TEXT=""
typeset _SLACK_MSG_CUR_VAL=""
typeset _SLACK_MSG_EXP_VAL=""
typeset _CURL_BIN=""
typeset _SLACK_WEBHOOK=""

# handle config file
if [[ ! -r ${_CONFIG_FILE} ]]
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
# read required config values
_SLACK_WEBHOOK=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'SLACK_WEBHOOK')
if [[ -z "${_SLACK_WEBHOOK}" ]]
then
    warn "no value set for 'SLACK_WEBHOOK' in ${_CONFIG_FILE}"
    return 1
fi

# create header part
_SLACK_TEXT="${EXEC_USER}@${HOST_NAME}: HC ${_SLACK_HC} failed, FAIL_ID=${_SLACK_FAIL_ID}"

# create body part (from $HC_MSG_VAR)
print "${HC_MSG_VAR}" | while IFS=${MSG_SEP} read -r _SLACK_MSG_STC _ _SLACK_MSG_TEXT _SLACK_MSG_CUR_VAL _SLACK_MSG_EXP_VAL
do
    # magically unquote if needed
    if [[ -n "${_SLACK_MSG_TEXT}" ]]
    then
        data_contains_string "${_SLACK_MSG_TEXT}" "${MAGIC_QUOTE}"
        # shellcheck disable=SC2181
        if (( $? > 0 ))
        then
            _SLACK_MSG_TEXT=$(data_magic_unquote "${_SLACK_MSG_TEXT}")
        fi
    fi
    if [[ -n "${_SLACK_MSG_CUR_VAL}" ]]
    then
        data_contains_string "${_SLACK_MSG_CUR_VAL}" "${MAGIC_QUOTE}"
        # shellcheck disable=SC2181
        if (( $? > 0 ))
        then
            _SLACK_MSG_CUR_VAL=$(data_magic_unquote "${_SLACK_MSG_CUR_VAL}")
        fi
    fi
    if [[ -n "${_SLACK_MSG_EXP_VAL}" ]]
    then
        data_contains_string "${_SLACK_MSG_EXP_VAL}" "${MAGIC_QUOTE}"
        # shellcheck disable=SC2181
        if (( $? > 0 ))
        then
            _SLACK_MSG_EXP_VAL=$(data_magic_unquote "${_SLACK_MSG_EXP_VAL}")
        fi
    fi
    if (( _SLACK_MSG_STC > 0 ))
    then
        # shellcheck disable=SC1117
        _SLACK_BODY=$(printf "%s\n%s\n" "${_SLACK_BODY}" "${_SLACK_MSG_TEXT}")
    fi
done

# send message
# find 'curl'
_CURL_BIN="$(command -v curl 2>/dev/null)"
if [[ -x ${_CURL_BIN} ]] && [[ -n "${_CURL_BIN}" ]]
then
    if (( ARG_DEBUG == 0 ))
    then
        ${_CURL_BIN} --silent --data-urlencode \
          "$(printf 'payload={"text": "%s\n\n%s" }' "${_SLACK_TEXT}" "${_SLACK_BODY}")" \
          "${_SLACK_WEBHOOK}" >/dev/null 2>&1
    else
        ${_CURL_BIN} --data-urlencode \
          "$(printf 'payload={"text": "%s\n\n%s" }' "${_SLACK_TEXT}" "${_SLACK_BODY}")" \
          "${_SLACK_WEBHOOK}"
    fi
 else
    die "unable to send message to Slack - curl is not installed here"
fi

log "Slack alert sent: ${_SLACK_HC} failed, FAIL_ID=${_SLACK_FAIL_ID}"

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
