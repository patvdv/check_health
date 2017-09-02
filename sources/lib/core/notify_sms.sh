#!/usr/bin/env ksh
#******************************************************************************
# @(#) notify_sms.sh
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
# @(#) MAIN: notify_sms
# DOES: send sms alert
# EXPECTS: 1=HC name [string], 2=HC FAIL_ID [string]
# RETURNS: 0
# REQUIRES: init_hc(), log(), warn()
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function notify_sms
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/core/providers/$0.conf"
typeset _VERSION="2017-04-27"								# YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="AIX,HP-UX,Linux"              # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG != 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _SMS_HC="$1"
typeset _SMS_FAIL_ID="$2"
typeset _SMS_TEXT=""
typeset _FROM_MSG="${EXEC_USER}@${HOST_NAME}"
typeset _CURL_BIN=""
typeset _SMS_PROVIDERS=""
typeset _SMS_KAPOW_SEND_URL=""
typeset _SMS_KAPOW_USER=""
typeset _SMS_KAPOW_PASSWORD=""

# handle config file
if [[ ! -r ${_CONFIG_FILE} ]] 
then
    warn "unable to read configuration file at ${_CONFIG_FILE}"
    return 1
fi
# read required config values
_SMS_PROVIDERS="$(grep -i '^SMS_PROVIDERS=' ${_CONFIG_FILE} | cut -f2 -d'=' | tr -d '\"')"
if [[ -z "${_SMS_PROVIDERS}" ]]
then
    warn "no value set for 'SMS_PROVIDERS' in ${_CONFIG_FILE}"
    return 1
fi

# SMS_PROVIDERS & SMS settings
if [[ -n "${_SMS_PROVIDERS}" ]]
then
    # SMS specific values are sourced in read_config()
    print "${_SMS_PROVIDERS}" |  tr ',' '\n' | while read -r _PROVIDER_OPTS
    do
        case "${_PROVIDER_OPTS}" in
            *kapow*|*KAPOW*|*Kapow*)
                # read required config values
                _SMS_KAPOW_SEND_URL="$(grep -i '^SMS_KAPOW_SEND_URL=' ${_CONFIG_FILE} | cut -f2 -d'=' | tr -d '\"')"
                if [[ -z "${_SMS_KAPOW_SEND_URL}" ]]
                then
                    warn "no value set for 'SMS_KAPOW_SEND_URL' in ${_CONFIG_FILE}"
                    return 1
                fi          
                _SMS_KAPOW_USER="$(grep -i '^SMS_KAPOW_USER=' ${_CONFIG_FILE} | cut -f2 -d'=' | tr -d '\"')"
                if [[ -z "${_SMS_KAPOW_USER}" ]]
                then
                    warn "no value set for 'SMS_KAPOW_USER' in ${_CONFIG_FILE}"
                    return 1
                fi      
                _SMS_KAPOW_PASS="$(grep -i '^SMS_KAPOW_PASS=' ${_CONFIG_FILE} | cut -f2 -d'=' | tr -d '\"')"
                if [[ -z "${_SMS_KAPOW_PASS}" ]]
                then
                    warn "no value set for 'SMS_KAPOW_PASS' in ${_CONFIG_FILE}"
                    return 1
                fi
        esac
    done
fi

# send SMS
case "${ARG_SMS_PROVIDER}" in
    *kapow*|*KAPOW*|*Kapow*)
        # KAPOW (https://www.kapow.co.uk/)
        # find 'curl'
        _CURL_BIN="$(which curl 2>/dev/null)"
        if [[ -x ${_CURL_BIN} ]] && [[ -n "${_CURL_BIN}" ]]
        then
            _SMS_TEXT=$(print "${_FROM_MSG}: HC ${_SMS_HC} failed, FAIL_ID=${_SMS_FAIL_ID}" | data_encode_url)
            if (( ARG_DEBUG == 0 ))
            then
                ${_CURL_BIN} -s --url "${_SMS_KAPOW_SEND_URL}?username=${_SMS_KAPOW_USER}&password=${_SMS_KAPOW_PASS}&mobile=${ARG_SMS_TO}&sms=${_SMS_TEXT}" >/dev/null 2>&1
            else
                ${_CURL_BIN} --url "${_SMS_KAPOW_SEND_URL}?username=${_SMS_KAPOW_USER}&password=${_SMS_KAPOW_PASS}&mobile=${ARG_SMS_TO}&sms=${_SMS_TEXT}"       
            fi
         else
            die "unable to send SMS - curl is not installed here"
        fi
        ;;
    *)
        # nothing here
        die "unable to send SMS - no method defined for SMS provider ${ARG_SMS_PROVIDER}"
        ;;
esac

log "SMS alert sent/queued to ${ARG_SMS_TO}: ${_SMS_HC} failed, FAIL_ID=${_SMS_FAIL_ID}"

return 0
}


#******************************************************************************
# END of script
#******************************************************************************
