#!/usr/bin/env ksh
#******************************************************************************
# @(#) include_data.sh
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
# @(#) MAIN: include_data
# DOES: helper functions for data (manipulation)
#
# -----------------------------------------------------------------------------
# DO NOT CHANGE THIS FILE UNLESS YOU KNOW WHAT YOU ARE DOING!
#******************************************************************************

# -----------------------------------------------------------------------------
# @(#) FUNCTION: version_include_core()
# DOES: dummy function for version placeholder
# EXPECTS: n/a
# RETURNS: 0
function version_include_data
{
typeset _VERSION="2019-04-20"                               # YYYY-MM-DD

print "INFO: $0: ${_VERSION#version_*}"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_get_lvalue_from_config()
# DOES: get an lvalue from the configuration file
# EXPECTS: parameter to look for [string]
# OUTPUTS: parameter value [string]
# RETURNS: 0=found; 1=not found
# REQUIRES: n/a
function data_get_lvalue_from_config
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _PARAMETER="${1}"
typeset _LVALUE=""
typeset _RC=0

_LVALUE=$(grep -i "^${_PARAMETER} *=" ${_CONFIG_FILE} | cut -f2- -d'=')

if [[ -n "${_LVALUE}" ]]
then
    # do not escape inside quotes
    print -R "$(data_dequote "${_LVALUE}")"
else
    _RC=1
fi

return ${_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_chop()
# DOES: cut last character of input
# EXPECTS: string
# OUTPUTS: string with last character omitted
# RETURNS: 0
# REQUIRES: n/a
function data_chop
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1%?}" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_get_length_string()
# DOES: get length of a string
# EXPECTS: string
# OUTPUTS: length of string [integer]
# RETURNS: 0
# REQUIRES: n/a
function data_get_length_string
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${#1}" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_get_substring()
# DOES: get a substring of a string
# EXPECTS: $1=string; $2=length of substring [integer]
# OUTPUTS: substring [string]
# RETURNS: 0
# REQUIRES: n/a
function data_get_substring
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" | cut -f1-${2} 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_contains_string()
# DOES: checks if a string (haystack) contains a substring (needle).
# EXPECTS: $1=haystack [string]; $2=needle [string]
# OUTPUTS: n/a
# RETURNS: 0=not found; 1=found
# REQUIRES: n/a
function data_contains_string
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

typeset _HAYSTACK="${1}"
typeset _NEEDLE="${2}"
typeset _RC=0

[[ "${_HAYSTACK#*${_NEEDLE}}" = "${_HAYSTACK}" ]] || _RC=1

return ${_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_is_string()
# DOES: checks if a string (haystack) matches a string (needle).
# EXPECTS: $1=haystack [string]; $2=needle [string]
# OUTPUTS: n/a
# RETURNS: 0=not found; 1=found
# REQUIRES: n/a
function data_is_string
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

typeset _HAYSTACK="${1}"
typeset _NEEDLE="${2}"

[[ "${_STRING}" = "${_NEEDLE}" ]] && return 1

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_list_contains_string()
# DOES: checks if a comma-separated list of strings (haystack) contains a substring (needle).
# EXPECTS: $1=haystack [string]; $2=needle [string]
# OUTPUTS: n/a
# RETURNS: 0=not found; 1=found
# REQUIRES: data_contains_string()
function data_list_contains_string
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

typeset _HAYSTACK="${1}"
typeset _NEEDLE="${2}"
typeset _STRING=""

print "${_HAYSTACK}" | tr ',' '\n' 2>/dev/null | while read -r _STRING
do
    data_contains_string "${_STRING}" "${_NEEDLE}" || return 1
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_list_is_string()
# DOES: checks if a comma-separated list of strings (haystack) matches a string (needle).
# EXPECTS: $1=haystack [string]; $2=needle [string]
# OUTPUTS: n/a
# RETURNS: 0=not found; 1=found
# REQUIRES: n/a
function data_list_is_string
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

typeset _HAYSTACK="${1}"
typeset _NEEDLE="${2}"

print "${_HAYSTACK}" | tr ',' '\n' 2>/dev/null | while read -r _STRING
do
    [[ "${_STRING}" = "${_NEEDLE}" ]] && return 1
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_magic_quote()
# DOES: magically quotes a needle in a string (default needle is: %)
# EXPECTS: to be magically quoted [string]; $2=needle [string]
# OUTPUTS: magically quoted [string]
# RETURNS: n/a
# REQUIRES: n/a
function data_magic_quote
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _SEP="${2:-%}"
typeset _MAGIC="${MAGIC:-!_!}"

print -R "${1}" 2>/dev/null | sed "s/${_SEP}/${_MAGIC}/g" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_magic_unquote()
# DOES: magically unquotes a needle in a string (default needle is: %)
# EXPECTS: to be magically unquoted [string]; $2=needle [string]
# OUTPUTS: magically unquoted [string]
# RETURNS: n/a
# REQUIRES: n/a
function data_magic_unquote
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _SEP="${2:-%}"
typeset _MAGIC="${MAGIC:-!_!}"

print -R "${1}" 2>/dev/null | sed "s/${_MAGIC}/${_SEP}/g" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_escape_csv()
# DOES: escapes semi-colons
# EXPECTS: to be escaped [string]
# OUTPUTS: escaped [string]
# RETURNS: n/a
# REQUIRES: n/a
function data_escape_csv
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | sed 's#\([;]\)#\\\1#g' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_escape_json()
# DOES: escapes double quotes and backslashes
# EXPECTS: to be escaped [string]
# OUTPUTS: escaped [string]
# RETURNS: n/a
# REQUIRES: n/a
function data_escape_json
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _NEEDLE='[\"]'

print -R "${1}" 2>/dev/null | sed 's#\(["\]\)#\\\1#g' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_decomma()
# DOES: remove commas
# EXPECTS: [string] with commas
# OUTPUTS: [string] without commas
# RETURNS: 0
# REQUIRES: n/a
function data_decomma
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -d ',' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_decomma_last()
# DOES: remove last comma
# EXPECTS: [string] with a last comma
# OUTPUTS: [string] without last comma
# RETURNS: 0
# REQUIRES: n/a
function data_decomma_last
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1%*,}" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_decomma_first()
# DOES: remove last comma
# EXPECTS: [string] with a last comma
# OUTPUTS: [string] without last comma
# RETURNS: 0
# REQUIRES: n/a
function data_decomma_first
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1#,*}" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_dequote()
# DOES: remove quotes
# EXPECTS: quoted [string]
# OUTPUTS: de-quoted (both double and single, but not escaped) [string]
# RETURNS: 0
# REQUIRES: n/a
function data_dequote
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -d '\"' 2>/dev/null | tr -d "'" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_comma2space()
# DOES: replace commas with a space
# EXPECTS: [string] with commas
# OUTPUTS: [string] with spaces
# RETURNS: 0
# REQUIRES: n/a
function data_comma2space
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr ',' ' ' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_comma2pipe()
# DOES: replace commas with a pipe
# EXPECTS: [string] with commas
# OUTPUTS: [string] with pipes
# RETURNS: 0
# REQUIRES: n/a
function data_comma2pipe
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr ',' '|' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_comma2newline()
# DOES: replace commas with a space
# EXPECTS: [string] with commas
# OUTPUTS: [string] with newlines
# RETURNS: 0
# REQUIRES: n/a
function data_comma2newline
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr ',' '\n' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_newline2comma()
# DOES: replace newlines with a comma
# EXPECTS: [string] with newlines
# OUTPUTS: [string] with commas
# RETURNS: 0
# REQUIRES: n/a
function data_newline2comma
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr '\n' ',' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_newline2hash()
# DOES: replace newlines with a hash
# EXPECTS: [string] with newlines (UNIX)
# OUTPUTS: [string] with hashes (UNIX)
# RETURNS: 0
# REQUIRES: n/a
function data_newline2hash
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr '\r' '#' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_space2comma()
# DOES: replace spaces with a comma
# EXPECTS: [string] with spaces
# OUTPUTS: [string] with commas
# RETURNS: 0
# REQUIRES: n/a
function data_space2comma
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -s ' ' 2>/dev/null | tr ' ' ',' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_pipe2comma()
# DOES: replace pipes with a comma
# EXPECTS: [string] with pipes
# OUTPUTS: [string] with commas
# RETURNS: 0
# REQUIRES: n/a
function data_pipe2comma
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -s '|' 2>/dev/null | tr ' '|',' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_space2hash()
# DOES: replace spaces with a hash
# EXPECTS: [string] with spaces
# OUTPUTS: [string] with hashes
# RETURNS: 0
# REQUIRES: n/a
function data_space2hash
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -s ' ' 2>/dev/null | tr ' ' '#' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_strip_newline()
# DOES: remove newlines
# EXPECTS: [string] with newlines
# OUTPUTS: [string] without newlines
# RETURNS: 0
# REQUIRES: n/a
function data_strip_newline
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -d '\n' 2>/dev/null | tr -d '\r' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_strip_space()
# DOES: remove spaces
# EXPECTS: [string] with spaces (all whitespace)
# OUTPUTS: [string] without spaces (all whitespace)
# RETURNS: 0
# REQUIRES: n/a
function data_strip_space
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr -d '[:space:]' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_strip_leading_space()
# DOES: remove leading spaces
# EXPECTS: [string] with leading spaces (all whitespace)
# OUTPUTS: [string] without leading spaces (all whitespace)
# RETURNS: 0
# REQUIRES: n/a
function data_strip_leading_space
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" | sed 's/^[[:blank:]]*//' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_strip_trailing_space()
# DOES: remove trailing spaces
# EXPECTS: [string] with trailing spaces (all whitespace)
# OUTPUTS: [string] without trailing spaces (all whitespace)
# RETURNS: 0
# REQUIRES: n/a
function data_strip_trailing_space
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" | sed 's/[[:blank:]]*$//' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_strip_outer_space()
# DOES: remove leading + trailing spaces
# EXPECTS: [string] with leading + trailing spaces (all whitespace)
# OUTPUTS: [string] without leading + trailing spaces (all whitespace)
# RETURNS: 0
# REQUIRES: n/a
function data_strip_outer_space
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" | sed 's/^[[:blank:]]*//;s/[[:blank:]]*$//' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_lc()
# DOES: switch to lower case
# EXPECTS: [string]
# OUTPUTS: lower case [string]
# RETURNS: 0
# REQUIRES: n/a
function data_lc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr '[:upper:]' '[:lower:]' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_uc()
# DOES: switch to upper case
# EXPECTS: [string]
# OUTPUTS: upper case [string]
# RETURNS: 0
# REQUIRES: n/a
function data_uc
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

print -R "${1}" 2>/dev/null | tr '[:lower:]' '[:upper:]' 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_is_numeric()
# DOES: check if input is numeric
# EXPECTS: [string]
# OUTPUTS: n/a
# RETURNS: 0=numeric; <>0=not numeric
# REQUIRES: n/a
function data_is_numeric
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"

case "${1}" in
    +([0-9])*(.)*([0-9]))
        # numeric, OK
        ;;
    *)
        # not numeric
        return 1
        ;;
esac

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_encode_url
# DOES: encode URL data
# EXPECTS: text to be encoded [string]
# OUTPUTS: encoded text [string]
# RETURNS: 0
# REQUIRES:
# REFERENCE: added from http://www.shelldorado.com/scripts/cmds/urlencode
function data_encode_url
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _EncodeEOL=0

LANG=C awk '
    BEGIN {
    # We assume an awk implementation that is just plain dumb.
    # We will convert an character to its ASCII value with the
    # table ord[], and produce two-digit hexadecimal output
    # without the printf("%02X") feature.

    EOL = "%0A"     # "end of line" string (encoded)
    split ("1 2 3 4 5 6 7 8 9 A B C D E F", hextab, " ")
    hextab [0] = 0
    for ( i=1; i<=255; ++i ) ord [ sprintf ("%c", i) "" ] = i + 0
    if ("'"$_EncodeEOL"'" == "yes") _EncodeEOL = 1; else _EncodeEOL = 0
    }
    {
    encoded = ""
    for ( i=1; i<=length ($0); ++i ) {
        c = substr ($0, i, 1)
        if ( c ~ /[a-zA-Z0-9.-]/ ) {
        encoded = encoded c     # safe character
        } else if ( c == " " ) {
        encoded = encoded "+"   # special handling
        } else {
        # unsafe character, encode it as a two-digit hex-number
        lo = ord [c] % 16
        hi = int (ord [c] / 16);
        encoded = encoded "%" hextab [hi] hextab [lo]
        }
    }
    if ( _EncodeEOL ) {
        printf ("%s", encoded EOL)
    } else {
        print encoded
    }
    }
    END {
        #if ( _EncodeEOL ) print ""
    }
' "$@"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_dot2ip()
# DOES: converts a dotted-decimal IPv4 address representation to the 32 bit number.
# EXPECTS: dotted-decimal IPv4 address [string]
# OUTPUTS: 32 bit number [string]
# REQUIRES: n/a
# REFERENCE: https://raw.githubusercontent.com/dualbus/tutorial_nmap/master/iprange
function data_dot2ip
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _DOT="${1}"
typeset _IP=0
typeset _OLD_IFS="${IFS}"

IFS="."
set -A _COMPS ${_DOT}
IFS="${_OLD_IFS}"

_IP=$((_IP | ((_COMPS[0] & 255) << 24) ))
_IP=$((_IP | ((_COMPS[1] & 255) << 16) ))
_IP=$((_IP | ((_COMPS[2] & 255) <<  8) ))
_IP=$((_IP | ((_COMPS[3] & 255) <<  0) ))

print "${_IP}" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_ip2dot()
# DOES: converts a 32 bit unsigned integer to dotted-decimal notation.
# EXPECTS: 32 bit unsigned integer [string]
# OUTPUTS: dotted-decimal [string]
# RETURNS: 0
# REQUIRES: n/a
# REFERENCE: https://raw.githubusercontent.com/dualbus/tutorial_nmap/master/iprange
function data_ip2dot
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _IP="${1}"
typeset _W=""
typeset _X=""
typeset _Y=""
typeset _Z=""

_W=$(( (_IP >> 24) & 255 ))
_X=$(( (_IP >> 16) & 255 ))
_Y=$(( (_IP >>  8) & 255 ))
_Z=$(( (_IP >>  0) & 255 ))

print "${_W}.${_X}.${_Y}.${_Z}" 2>/dev/null

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_bits2mask()
# DOES: converts bits notation (prefix) to a dotted-decimal representation
# EXPECTS: netmask in prefix [string]
# OUTPUTS: netmask in dotted decimal notation [string]
# RETURNS: 0
# REQUIRES: n/a
# REFERENCE: https://raw.githubusercontent.com/dualbus/tutorial_nmap/master/iprange
function data_bits2mask
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _BITS=${1}
typeset _MAX=4294967296
typeset _OFFSET=0

case "${_BITS}" in
     0) _OFFSET=${_MAX} ;;
     1) _OFFSET=2147483648 ;;
     2) _OFFSET=1073741824 ;;
     3) _OFFSET=536870912 ;;
     4) _OFFSET=268435456 ;;
     5) _OFFSET=134217728 ;;
     6) _OFFSET=67108864 ;;
     7) _OFFSET=33554432 ;;
     8) _OFFSET=16777216 ;;
     9) _OFFSET=8388608 ;;
    10) _OFFSET=4194304 ;;
    11) _OFFSET=2097152 ;;
    12) _OFFSET=1048576 ;;
    13) _OFFSET=524288 ;;
    14) _OFFSET=262144 ;;
    15) _OFFSET=131072 ;;
    16) _OFFSET=65536 ;;
    17) _OFFSET=32768 ;;
    18) _OFFSET=16384 ;;
    19) _OFFSET=8192 ;;
    20) _OFFSET=4096 ;;
    21) _OFFSET=2048 ;;
    22) _OFFSET=1024 ;;
    23) _OFFSET=512 ;;
    24) _OFFSET=256 ;;
    25) _OFFSET=128 ;;
    26) _OFFSET=64 ;;
    27) _OFFSET=32 ;;
    28) _OFFSET=16 ;;
    29) _OFFSET=8 ;;
    30) _OFFSET=4 ;;
    31) _OFFSET=2 ;;
    32) _OFFSET=1 ;;
esac

data_ip2dot "$(( (_MAX - 1) & ~(_OFFSET - 1) ))"

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_mask2bits()
# DOES: converts decimal netmask to bits notation (prefix)
# EXPECTS: netmask in dotted decimal notation [string]
# OUTPUTS: netmask in prefix [string]
# RETURNS: 0
# REQUIRES: n/a
# REFERENCE: https://raw.githubusercontent.com/dualbus/tutorial_nmap/master/iprange
function data_mask2bits
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _MASK="${1}"
typeset -i _I=32

while (( _I > 0 ))
do
    [[ "${_MASK}" = $(data_bits2mask "${_I}") ]] && print "${_I}" 2>/dev/null
    _I=$(( _I - 1 ))
done

return 0
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_is_IPv4()
# DOES: checks if an IP address is in IPv4 dotted notation
# EXPECTS: IPv4 address in decimal notation [string]
# RETURNS: 0=not IPv4; <>0=IPv4
# REQUIRES: n/a
function data_is_ipv4
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _IP="${1}"
typeset _RC=0

_RC=$(print "${_IP}" | grep -c -E -e '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' 2>/dev/null)

return ${_RC}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_date2epoch()
# DOES: converts a given date into UNIX epoch seconds
# EXPECTS: date formatted as individual parameters (in UTC time):
#          $1 : YYYY
#          $2 : MM
#          $3 : DD
#          $4 : HH
#          $5 : MM
#          $6 : SS
# OUTPUTS: UNIX epoch seconds [number]
# RETURNS: 0
# REQUIRES: n/a
# REFERENCE: https://groups.google.com/forum/#!topic/comp.unix.shell/aPoPzFWP2Og
function data_date2epoch
{
(( ARG_DEBUG > 0 && ARG_DEBUG_LEVEL > 0 )) && set "${DEBUG_OPTS}"
typeset _YEAR="${1}"
typeset _MONTH="${2}"
typeset _DAY="${3}"
typeset _HOUR="${4}"
typeset _MINUTE="${5}"
typeset _SECOND="${6}"
typeset _DAYS_ACC
typeset _YEAR_DAY
typeset _EPOCH
typeset _LEAP_YEARS
set -A _DAYS_ACC 0 0 31 59 90 120 151 181 212 243 273 304 334 365

# calculate day of year (counting from 0)
_YEAR_DAY=$(( (_DAY - 1) + _DAYS_ACC[_MONTH] ))

# calculate number of leap years
_LEAP_YEARS=$(( (_YEAR - 1968) / 4 ))
_LEAP_YEARS=$(( _LEAP_YEARS - _YEAR / 100 + _YEAR / 400 + 15 ))

# adjust if we are still in Jan/Feb of leap year
[[ $((_YEAR % 4)) = 0 && ${_MONTH} -lt 3 ]] && _LEAP_YEARS=$(( _LEAP_YEARS - 1 ))

# calculate the time since epoch
_EPOCH=$(( ((_YEAR - 1970) * 365 + _YEAR_DAY + _LEAP_YEARS) * 86400
           + _HOUR * 3600 + _MINUTE * 60 + _SECOND ))

print ${_EPOCH}
}

# -----------------------------------------------------------------------------
# @(#) FUNCTION: data_epoch2date()
# DOES: converts an UNIX epoch to a human readable format (trying GNU date and
#       and perl). If neither works, then return the UNIX epoch.
# EXPECTS: UNIX epoch [string]
# OUTPUTS: date in human readable format OR UNIX epoch [string]
# RETURNS: 0=conversion OK; 1=conversion failed
# REQUIRES: n/a
function data_epoch2date
{
typeset _UNIX_EPOCH="${1}"
typeset _CONVERT_DATE=""

# try the GNU version of 'date -d'
_CONVERT_DATE=$(date -d @"${_UNIX_EPOCH}" 2>/dev/null)
# shellcheck disable=SC2181
if (( $? > 0 ))
then
    # try the perl way
    _CONVERT_DATE=$(perl -e "print scalar(localtime(${_UNIX_EPOCH}))" 2>/dev/null)
    if (( $? > 0 ))
    then
    # no luck, we just return the UNIX epoch again
    print "${_UNIX_EPOCH}"
    return 1
    else
    print "${_CONVERT_DATE}"
    fi
else
    print "${_CONVERT_DATE}"
fi

return 0
}

#******************************************************************************
# END of script
#******************************************************************************
