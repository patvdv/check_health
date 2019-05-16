#!/usr/bin/env ksh
#******************************************************************************
# @(#) include_exadata.sh
#******************************************************************************
# @(#) Copyright (C) 2019 by KUDOS BVBA (info@kudos.be).  All rights reserved.
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
# @(#) MAIN: include_exadata
# DOES: helper functions for Exadata related functions
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
# @(#) FUNCTION: version_include_core()
# DOES: dummy function for version placeholder
# EXPECTS: n/a
# RETURNS: 0
function version_include_exadata
{
typeset _VERSION="2019-05-14"                               # YYYY-MM-DD

print "INFO: $0: ${_VERSION#version_*}"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: exadata_exec_dcli()
# DOES: execute a command via dcli
# EXPECTS: 1=options [string], 2=user [string], 3=host(s) [string],
#          4=SSH options [string], 5=command [string]
# RETURNS: exit code of remote command
# OUTPUTS: STDOUT from DCLI call
# REQUIRES: dcli command-line utility
function exadata_exec_dcli
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set ${DEBUG_OPTS}
typeset _DCLI_OPTS="${1}"
typeset _DCLI_USER="${2}"
typeset _DCLI_HOSTS="${3}"
typeset _SSH_OPTS="${4}"
typeset _DCLI_COMMAND="${5}"
typeset _DCLI_BIN=""

if [[ -z "${_DCLI_USER}" || -z "${_DCLI_HOSTS}" || -z "${_DCLI_COMMAND}" ]]
then
    return 255
fi

# find dcli
_DCLI_BIN="$(command -v dcli 2>>${HC_STDERR_LOG})"
if [[ -z "${_DCLI_BIN}" || ! -x ${_DCLI_BIN} ]]
then
    # don't spoil STDOUT
    ARG_VERBOSE=0 warn "could not determine location for {dcli} (or it is not installed here)"
    return 255
fi

# execute dcli
if [[ -z "${_SSH_OPTS}" ]]
then
    ${_DCLI_BIN} ${_DCLI_OPTS} -l ${_DCLI_USER} -c "${_DCLI_HOSTS}" "${_DCLI_COMMAND}" 2>>${HC_STDERR_LOG} </dev/null
else
    ${_DCLI_BIN} ${_DCLI_OPTS} -l ${_DCLI_USER} -c "${_DCLI_HOSTS}" -s ${_SSH_OPTS} "${_DCLI_COMMAND}" 2>>${HC_STDERR_LOG} </dev/null
fi

return $?
}

#******************************************************************************
# END of script
#******************************************************************************
