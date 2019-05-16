#!/usr/bin/env ksh
#******************************************************************************
# @(#) include_os.sh
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
# @(#) MAIN: include_os
# DOES: helper functions for OS related functions
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
# @(#) FUNCTION: version_include_core()
# DOES: dummy function for version placeholder
# EXPECTS: n/a
# RETURNS: 0
function version_include_os
{
typeset _VERSION="2019-03-16"                               # YYYY-MM-DD

print "INFO: $0: ${_VERSION#version_*}"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_get_distro()
# DOES: get Linux distribution name & version, sets $LINUX_DISTRO & $LINUX_RELEASE
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function linux_get_distro
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

# linux only
check_platform 'Linux' || {
    (( ARG_DEBUG > 0 )) && debug "may only run on platform(s): Linux"
    return 1
}

# try LSB first (good for Ubuntu & derivatives)
if [[ -f /etc/lsb-release ]]
then
    # shellcheck disable=SC1091
    . /etc/lsb-release
    LINUX_DISTRO="${DISTRIB_ID}"
    LINUX_RELEASE="${DISTRIB_RELEASE}"
fi

# LSB turned up zippo, start digging
if [[ -z "${LINUX_DISTRO}" || -z "${LINUX_RELEASE}" ]]
then
    if [[ -f /etc/debian_version ]]
    then
        LINUX_DISTRO="Debian"
        LINUX_RELEASE=$(</etc/debian_version 2>/dev/null)
    elif [[ -f /etc/SuSE-release ]]
    then
        LINUX_DISTRO="SuSE"
        LINUX_RELEASE=$(grep 'VERSION' /etc/SuSE-release 2>/dev/null | cut -f2 -d'=' 2>/dev/null | tr -d ' ' 2>/dev/null)
        [[ -n "${LINUX_RELEASE}" ]] || LINUX_RELEASE=$(grep 'CPE_NAME' /etc/os-release 2>/dev/null | cut -f2 -d'=' 2>/dev/null | cut -f5 -d':' 2>/dev/null)
    elif [[ -f /etc/redhat-release ]]
    then
        LINUX_DISTRO="Redhat"
        if [[ -f /etc/system-release-cpe ]]
        then
            # system-release-cpe is present since Fedora 9 [cpe:/o:centos:linux:6:GA]
            LINUX_RELEASE=$(cut -f5 -d':' </etc/system-release-cpe 2>/dev/null)
        else
            LINUX_RELEASE=$(print "${LINUX_RELEASE##*release }")
        fi
    else
        LINUX_DISTRO="${OS_NAME}"
        LINUX_RELEASE="unknown"
    fi
fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_get_init()
# DOES: get Linux init mechanism, sets $LINUX_INIT
# EXPECTS: n/a
# RETURNS: 0
# REQUIRES: n/a
function linux_get_init
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

# linux only
check_platform 'Linux' || {
    (( ARG_DEBUG > 0 )) && debug "may only run on platform(s): Linux"
    return 1
}

# default is sysv
LINUX_INIT="sysv"
if [[ -r /usr/lib/systemd && -n "$(command -v systemctl 2>/dev/null)" ]]
then
    LINUX_INIT="systemd"
elif [[ -r /usr/share/upstart ]]
then
    # shellcheck disable=SC2034
    LINUX_INIT="upstart"

fi

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_has_crm()
# DOES: check if Corosync (CRM version) is running
# EXPECTS: n/a
# OUTPUTS: 0=not active/installed; 1=active/installed
# RETURNS: 0=success; 1=error
# REQUIRES: Corosync
function linux_has_crm
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _CRM_BIN=""
typeset _HAS_CRM=0

# linux only
check_platform 'Linux' || {
    warn "may only run on platform(s): Linux"
    return 1
}

_CRM_BIN="$(command -v crm 2>/dev/null)"
if [[ -x ${_CRM_BIN} && -n "${_CRM_BIN}" ]]
then
    # check for active
    crm status >/dev/null 2>/dev/null
    # shellcheck disable=SC2181
    (( $? == 0 )) && _HAS_CRM=1
else
    (( ARG_DEBUG > 0 )) && debug "corosync (crm) is not active here"
    return 1
fi

print ${_HAS_CRM}

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_has_docker()
# DOES: check if docker is running
# EXPECTS: n/a
# OUTPUTS: 0=not active/installed; 1=active/installed
# RETURNS: 0=success; 1=error
# REQUIRES: Docker
function linux_has_docker
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _DOCKER_BIN=""
typeset _HAS_DOCKER=0

# linux only
check_platform 'Linux' || {
    warn "may only run on platform(s): Linux"
    return 1
}

_DOCKER_BIN="$(command -v docker 2>/dev/null)"
if [[ -x ${_DOCKER_BIN} && -n "${_DOCKER_BIN}" ]]
then
    # check for active
    docker ps >/dev/null 2>/dev/null
    # shellcheck disable=SC2181
    (( $? == 0 )) && _HAS_DOCKER=1
else
    (( ARG_DEBUG > 0 )) && debug "docker is not active here"
    return 1
fi

print ${_HAS_DOCKER}

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_has_nm()
# DOES: check if NetworkManager is running
# EXPECTS: n/a
# OUTPUTS: 0=not active/installed; 1=active/installed
# RETURNS: 0=success; 1=error
# REQUIRES: NetworkManager
function linux_has_nm
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _NMCLI_BIN=""
typeset _HAS_NM=0

# linux only
check_platform 'Linux' || {
    warn "may only run on platform(s): Linux"
    return 1
}

_NMCLI_BIN="$(command -v nmcli 2>/dev/null)"
if [[ -x ${_NMCLI_BIN} && -n "${_NMCLI_BIN}" ]]
then
    # check for active
    _HAS_NM=$(nmcli networking 2>/dev/null | grep -c -i "enabled" 2>/dev/null)
else
    (( ARG_DEBUG > 0 )) && debug "NetworkManager is not active here"
    return 1
fi

print ${_HAS_NM}

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_has_systemd_service()
# DOES: check if a systemd service is present (unit file)
# EXPECTS: name of service [string]
# OUTPUTS: 0=not installed; 1=installed
# RETURNS: 0=success; 1=error
# REQUIRES: systemd
function linux_has_systemd_service
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _RC=0

systemctl list-unit-files 2>/dev/null | grep -c "^${1}" 2>/dev/null
_RC=$?

return ${_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: linux_exec_ssh()
# DOES: execute a shell command remotely via SSH
# EXPECTS: 1=options [string], 2=user [string], 3=host [string], 4=command [string]
# RETURNS: exit code of remote command
# OUTPUTS: STDOUT from SSH call
# REQUIRES: ssh command-line utility
function linux_exec_ssh
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
typeset _SSH_OPTS="${1}"
typeset _SSH_USER="${2}"
typeset _SSH_HOST="${3}"
typeset _SSH_COMMAND="${4}"

if [[ -z "${_SSH_USER}" || -z "${_SSH_HOST}" || -z "${_SSH_COMMAND}" ]]
then
    return 255
fi
# shellcheck disable=SC2086
ssh ${_SSH_OPTS} -l ${_SSH_USER} ${_SSH_HOST} ${_SSH_COMMAND} 2>>${HC_STDERR_LOG} </dev/null

return $?
}

#******************************************************************************
# END of script
#******************************************************************************
