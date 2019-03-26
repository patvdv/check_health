#!/usr/bin/env ksh
#******************************************************************************
# @(#) check_hpux_sfm_status.sh
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
# @(#) MAIN: check_hpux_sfm_statuss
# DOES: see _show_usage()
# EXPECTS: see _show_usage()
# REQUIRES: data_comma2space(), data_contains_string(), data_is_numeric(),
#           init_hc(), log_hc(), warn()
#
# @(#) HISTORY:
# @(#) 2018-10-28: initial version [Patrick Van der Veken]
# @(#) 2019-01-27: arguments fix [Patrick Van der Veken]
# @(#) 2019-03-09: text updates [Patrick Van der Veken]
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
function check_hpux_sfm_status
{
# ------------------------- CONFIGURATION starts here -------------------------
typeset _CONFIG_FILE="${CONFIG_DIR}/$0.conf"
typeset _SFMCONFIG_BIN="/opt/sfm/bin/sfmconfig"
typeset _EVWEB_BIN="/opt/sfm/bin/evweb"
typeset _CIMPROVIDER_BIN="/opt/wbem/bin/cimprovider"
typeset _VERSION="2019-03-09"                           # YYYY-MM-DD
typeset _SUPPORTED_PLATFORMS="HP-UX"                    # uname -s match
# ------------------------- CONFIGURATION ends here ---------------------------

# set defaults
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
init_hc "$0" "${_SUPPORTED_PLATFORMS}" "${_VERSION}"
typeset _ARGS=$(data_comma2space "$*")
typeset _ARG=""
typeset _MSG=""
typeset _STC=0
typeset _CFG_HEALTHY=""
typeset _LOG_HEALTHY=0
typeset _CFG_CHECK_EVENTS=""
typeset _CHECK_EVENTS=1
typeset _CFG_EVENTS_AGE=""
typeset _EVENTS_AGE="1:dd"
typeset _CFG_EVENTS_SEVERITY=""
typeset _CFG_SEND_TEST_EVENT=""
typeset _SEND_TEST_EVENT=0
typeset _CFG_WAIT_TEST_EVENT=""
typeset _WAIT_TEST_EVENT=60
typeset _CFG_EVENT_SUBSCRIBER_CIMOM=""
typeset _CFG_EVENT_SUBSCRIBER_WBEM=""
typeset _CHECK_EVENT_SUBSCRIBER=0
typeset _CHECK_CIM_OUTPUT=""
typeset _CHECK_CIM_MODULE=""
typeset _CHECK_SFM_OUTPUT=""
typeset _CHECK_EVWEB_OUTPUT=""
typeset _COUNT_SUBS_CIMOM=0
typeset _COUNT_SUBS_WBEM=0
typeset _EVWEB_LINE=""
typeset _EVENT_ID=""
typeset _EVENT_SUMMARY=""

# handle arguments (originally comma-separated)
for _ARG in ${_ARGS}
do
	case "${_ARG}" in
		help)
			_show_usage $0 ${_VERSION} ${_CONFIG_FILE} && return 0
			;;
	esac
done

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

# handle configuration file
[[ -n "${ARG_CONFIG_FILE}" ]] && _CONFIG_FILE="${ARG_CONFIG_FILE}"
if [[ ! -r ${_CONFIG_FILE} ]]
then
	warn "unable to read configuration file at ${_CONFIG_FILE}"
	return 1
fi
# read required configuration values
_CFG_CHECK_EVENTS=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'check_events')
case "${_CFG_CHECK_EVENTS}" in
	No|NO|no)
		_CHECK_EVENTS=0
		log "will not check current events"
		;;
	*)
		log "will check current events"
		;;
esac
_CFG_EVENTS_AGE=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'events_age')
case "${_CFG_EVENTS_AGE}" in
	*:dd|*:mm|*:yy)
		_EVENTS_AGE="${_CFG_EVENTS_AGE}"
		log "will use following age for current events: ${_CFG_EVENTS_AGE}"
		;;
	*)
		warn "invalid event age value '${_CFG_EVENTS_AGE}' in configuration file at ${_CONFIG_FILE}"
		return 1
		;;
esac
_CFG_EVENTS_SEVERITY=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'events_severity')
if [[ -n "${_CFG_EVENTS_SEVERITY}" ]] && (( _CHECK_EVENTS > 0 ))
then
		log "will use following severities for current events: ${_CFG_EVENTS_SEVERITY}"
fi
_CFG_SEND_TEST_EVENT=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'send_test_event')
case "${_CFG_SEND_TEST_EVENT}" in
	Yes|YES|yes)
		if (( ARG_LOG > 0 ))
		then
			_SEND_TEST_EVENT=1
		else
			warn "--no-log is enabled, skipping the generation of a test event"
		fi
		log "will send & check a test event"
		;;
	*)
		log "will not send & check a test event"
		;;
esac
_CFG_WAIT_TEST_EVENT=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'wait_test_event')
if (( _SEND_TEST_EVENT > 0 ))
then
	if [[ -z "${_CFG_WAIT_TEST_EVENT}" ]]
	then
		_WAIT_TEST_EVENT=60
	else
		data_is_numeric "${_WAIT_TEST_EVENT}"
		if (( $? > 0 ))
		then
			warn "invalid wait test event value '${_WAIT_TEST_EVENT}' in configuration file at ${_CONFIG_FILE}"
			return 1
		fi
	fi
fi
_CFG_EVENT_SUBSCRIBER_CIMOM=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'event_subscriber_cimom')
_CFG_EVENT_SUBSCRIBER_WBEM=$(_CONFIG_FILE="${_CONFIG_FILE}" data_get_lvalue_from_config 'event_subscriber_wbem')
if [[ -n "${_CFG_EVENT_SUBSCRIBER_CIMOM}" ]] || [[ -n "${_CFG_EVENT_SUBSCRIBER_WBEM}" ]]
then
	_CHECK_EVENT_SUBSCRIBER=1
	log "will check external subscriber (cimom and/or wbem)"
else
	log "will not check external subscriber (cimom and/or wbem)"
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

# check timeout (_WAIT_TEST_EVENT must be at least 30 secs smaller than health check timeout)
if (( _SEND_TEST_EVENT > 0 ))
then
	if (( (_WAIT_TEST_EVENT + 30) > HC_TIME_OUT ))
	then
		warn "wait test event value will conflict with health check timeout. Specify a (larger) --timeout value"
		return 1
	fi
fi

# check required tools
if [[ ! -x ${_SFMCONFIG_BIN} ]]
then
	warn "${_SFMCONFIG_BIN} is not installed here"
	return 1
fi
if [[ ! -x ${_EVWEB_BIN} ]]
then
	warn "${_EVWEB_BIN} is not installed here"
	return 1
fi
if [[ ! -x ${_CIMPROVIDER_BIN} ]]
then
	warn "${_CIMPROVIDER_BIN} is not installed here"
	return 1
fi

# 1. is SFM active?
log "checking whether SFM is configured as default monitoring mode ..."
print "=== ${_SFMCONFIG_BIN} -w -q ===" >>${HC_STDOUT_LOG}
_CHECK_SFM_OUTPUT=$(${_SFMCONFIG_BIN} -w -q 2>>${HC_STDERR_LOG})
# RC for sfmconfig -w -q is meaningless so no check here
data_contains_string "${_CHECK_SFM_OUTPUT}" "SysFaultMgmt is the default monitoring mode"
if (( $? == 0 ))
then
	_MSG="SysFaultMgmt is not configured as default monitoring mode {${_SFMCONFIG_BIN} -w -q}"
	_STC=1
else
	_MSG="SysFaultMgmt is configured as default monitoring mode"
	_STC=0
fi
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
	log_hc "$0" ${_STC} "${_MSG}"
fi
# save sfmconfig OUTPUT for posterity
print "${_CHECK_SFM_OUTPUT}" >>${HC_STDOUT_LOG}

# 2. is SFM provider module active in CIM?
log "checking whether SFM provider is active ..."
print "=== ${_CIMPROVIDER_BIN} -ls ===" >>${HC_STDOUT_LOG}
_CHECK_CIM_OUTPUT=$(${_CIMPROVIDER_BIN} -ls 2>>${HC_STDERR_LOG})
if (( $? > 0 ))
then
	_MSG="unable to execute {${_CIMPROVIDER_BIN} -ls}, cimserver is probably not running"
	log_hc "$0" 1 "${_MSG}"
	# save cimprovider OUTPUT
	print "${_CHECK_CIM_OUTPUT}" >>${HC_STDOUT_LOG}
	# dump debug info
	(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
	return 1
else
	# find module
	_CHECK_CIM_MODULE=$(print "${_CHECK_CIM_OUTPUT}" | grep -c -E -e 'SFMProviderModule[[:space:]]*OK' 2>/dev/null)
	if (( _CHECK_CIM_MODULE > 0 ))
	then
		_MSG="SFM CIM provider is active"
		_STC=0
	else
		_MSG="SFM CIM provider is not active {${_CIMPROVIDER_BIN} -ls}"
		_STC=0
	fi
fi
if (( _LOG_HEALTHY > 0 || _STC > 0 ))
then
	log_hc "$0" ${_STC} "${_MSG}"
fi
# save sfmconfig OUTPUT for posterity
print "${_CHECK_CIM_OUTPUT}" >>${HC_STDOUT_LOG}

# 3. check if there is an external SIM/IRS subscriber
if (( _CHECK_EVENT_SUBSCRIBER > 0 ))
then
	log "checking external SIM/IRS subscriber ..."
	print "=== ${_EVWEB_BIN} subscribe -L -b external ===" >>${HC_STDOUT_LOG}
	_CHECK_EVWEB_OUTPUT=$(${_EVWEB_BIN} subscribe -L -b external)
	_COUNT_SUBS_CIMOM=$(print "${_CHECK_EVWEB_OUTPUT}" | grep -c "${_CFG_EVENT_SUBSCRIBER_CIMOM}" 2>/dev/null)
	_COUNT_SUBS_WBEM=$(print "${_CHECK_EVWEB_OUTPUT}" | grep -c "${_CFG_EVENT_SUBSCRIBER_WBEM}" 2>/dev/null)
	if (( _COUNT_SUBS_CIMOM > 0 || _COUNT_SUBS_WBEM > 0 ))
	then
		case ${_COUNT_SUBS_CIMOM} in
			0)
				:
				;;
			3)
				_MSG="found external subscriber for CIMOM with ${_COUNT_SUBS_CIMOM} subscriptions"
				_STC=0
				;;
			*)
				_MSG="found external subscriber for CIMOM but not with sufficient number of subscriptions: ${_COUNT_SUBS_CIMOM}"
				_STC=1
				;;
		esac
		if (( _COUNT_SUBS_WBEM > 0 ))
		then
			_MSG="found external subscriber for WBEM"
			_STC=0
		fi
	else
		_MSG="did not find any external subscribers for CIMOM or WBEM"
		_STC=1
	fi
	if (( _LOG_HEALTHY > 0 || _STC > 0 ))
	then
		log_hc "$0" ${_STC} "${_MSG}"
	fi
	# save evweb OUTPUT for posterity
	print "${_CHECK_EVWEB_OUTPUT}" >>${HC_STDOUT_LOG}
fi

# 4. send a test event?
if (( _SEND_TEST_EVENT > 0 ))
then
	log "generating SFM test event ..."
	print "=== ${_SFMCONFIG_BIN} -t -a ===" >>${HC_STDOUT_LOG}
	${_SFMCONFIG_BIN} -t -a >>${HC_STDOUT_LOG} 2>>${HC_STDERR_LOG}
	if (( $? > 0 ))
	then
		_MSG="unable to execute {${_SFMCONFIG_BIN} -t -a}, cimserver is probably not running"
		log_hc "$0" 1 "${_MSG}"
		# dump debug info
		(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
		return 1
	else
		# wait for test event to showing
		log "waiting for SFM test event to show (${_WAIT_TEST_EVENT} seconds) ..."
		sleep ${_WAIT_TEST_EVENT}
		# run event viewer
		print "=== ${_EVWEB_BIN} eventviewer -L -a 1:dd ===" >>${HC_STDOUT_LOG}
		_CHECK_EVWEB_OUTPUT=$(${_EVWEB_BIN} eventviewer -L -a 1:dd | grep "Test event" 2>/dev/null)
		if (( $? > 0 ))
		then
			_MSG="unable to execute {${_EVWEB_BIN} eventviewer -L -a 1:dd}"
			log_hc "$0" 1 "${_MSG}"
			# save evweb OUTPUT
			print "${_CHECK_EVWEB_OUTPUT}" >>${HC_STDOUT_LOG}
			# dump debug info
			(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
			return 1
		else
			if [[ -n "${_CHECK_EVWEB_OUTPUT}" ]]
			then
				_MSG="at least one test event was successfully generated in the last 24hrs"
				_STC=0
			else
				_MSG="found no test event in the last 24hrs"
				_STC=1
			fi
		fi
	fi
	if (( _LOG_HEALTHY > 0 || _STC > 0 ))
	then
		log_hc "$0" ${_STC} "${_MSG}"
	fi
	# save evweb OUTPUT for posterity
	print "${_CHECK_EVWEB_OUTPUT}" >>${HC_STDOUT_LOG}
fi

# 5. check events
if (( _CHECK_EVENTS > 0 ))
then
	_CHECK_EVWEB_OUTPUT=""
	log "checking for current events (age: ${_EVENTS_AGE}) ..."
	print "=== ${_EVWEB_BIN} eventviewer -L -a ${_EVENTS_AGE} ===" >>${HC_STDOUT_LOG}
	_CHECK_EVWEB_OUTPUT=$(${_EVWEB_BIN} eventviewer -L -a ${_EVENTS_AGE} | grep -v "Test event" 2>/dev/null)
	if (( $? > 0 ))
	then
		_MSG="unable to execute {${_EVWEB_BIN} eventviewer -L -a ${_EVENTS_AGE}}"
		log_hc "$0" 1 "${_MSG}"
		# save evweb OUTPUT
		print "${_CHECK_EVWEB_OUTPUT}" >>${HC_STDOUT_LOG}
		# dump debug info
		(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && dump_logs
		return 1
	else
		_CFG_EVENTS_SEVERITY=$(data_lc "${_CFG_EVENTS_SEVERITY}")
		print "${_CHECK_EVWEB_OUTPUT}" | grep -v -E -e "^$" -e "^=" -e "^Ev" 2>/dev/null |\
		while read -r _EVWEB_LINE
		do
			_EVENT_ID=$(print "${_EVWEB_LINE}" | awk '{ print $1}' 2>/dev/null)
			_EVENT_SEVERITY=$(print "${_EVWEB_LINE}" | awk '{ print $2}' 2>/dev/null)
			_EVENT_SEVERITY=$(data_lc "${_EVENT_SEVERITY}")
			_EVENT_SUMMARY=$(print "${_EVWEB_LINE}" | awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=""; gsub (/^ */,"",$0); print $0}' 2>/dev/null)
			# check severity
			data_contains_string "${_CFG_EVENTS_SEVERITY}" "${_EVENT_SEVERITY}"
			if (( $? > 0 ))
			then
				_MSG="found SFM event (ID=${_EVENT_ID}/SUMMARY=${_EVENT_SUMMARY})"
				log_hc "$0" 1 "${_MSG}"
			fi
		done
	fi
	# save evweb OUTPUT for posterity
	print "${_CHECK_EVWEB_OUTPUT}" >>${HC_STDOUT_LOG}
fi

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
				check_events=<yes|no>
				events_age=<age_of_open_events>
				events_severity=<severities_of_open_events>
				send_test_event=<yes|no>
				wait_test_event=<interval_to_wait>
				event_subscriber=<url_of_external_subscriber>
PURPOSE     : Checks the heath of SFM (System Fault Management)
				* checks default monitoring mode
				* checks CIM provider module
				* checks external event subscriber (optional)
				* sends & checks a test event (optional)
				* checks current events (optional)
LOG HEALTHY : Supported
NOTE        : Test events should not be generated more than once a day

EOT

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
