#!/bin/sh
# Copyright 1999-2025 Gentoo / HiGFXback Authors
# Distributed under the terms of the GNU General Public License v2

NAME="libtool"

# Executes the correct libtool version.
#
# If WANT_LIBTOOL is set (can be a whitespace delimited list of versions):
#  - attempt to find an installed version using those
#  - if magic keyword 'latest' is found, pick the latest version that exists
#  - if nothing found, warn, and proceed as if WANT_LIBTOOL was not set (below)
# If WANT_LIBTOOL is not set:
#  - Try to detect the version of libtool used to generate things (look at
#    ltmain.sh)
#  - If detected version is not found, warn and proceed as if blank slate
#  - Try to locate the latest version of libtool that exists and run it

(set -o posix) 2>/dev/null && set -o posix

_stderr() { printf 'lt-wrapper: %s: %b\n' "${argv0}" "$*" 1>&2; }
warn() { _stderr "warning: $*"; }
err() { _stderr "error: $*"; exit 1; }
unset IFS
which() {
	local p
	IFS=: # we don't use IFS anywhere, so don't bother saving/restoring
	for p in ${PATH} ; do
		p="${p}/$1"
		[ -e "${p}" ] && echo "${p}" && return 0
	done
	unset IFS
	return 1
}

#
# Sanitize argv[0] since it isn't always a full path #385201
#
argv0=${0##*/}
case $0 in
	${argv0})
		# find it in PATH
		if ! full_argv0=$(which "${argv0}") ; then
			err "could not locate ${argv0}; file a bug"
		fi
		;;
	*)
		# re-use full/relative paths
		full_argv0=$0
		;;
esac

#
# Set up bindings between actual version and WANT_LIBTOOL;
# Start with last known versions to speed up lookup process.
#
LAST_KNOWN_LIBTOOL_VER="2.4.7"
vers="2.4.7 2.4.6 2.4.5 2.4.4 2.4.2 2.4 2.2.10 2.2.6b 2.2.6 2.2.4 1.5.24"

#
# Helper to scan for a usable program based on version.
#
binary=
all_vers=
find_binary() {
	local v
	all_vers="${all_vers} $*" # For error messages.
	for v ; do
		if [ -x "${full_argv0}-${v}" ] ; then
			binary="${full_argv0}-${v}"
			binary_ver=${v}
			return 0
		fi
	done
	return 1
}

#
# Try and find a usable libtool version.  First check the WANT_LIBTOOL
# setting (whitespace delimited list), then fallback to the latest.
#
find_latest() {
	if ! find_binary ${vers} ; then
		# Brute force it.
		find_binary ${LAST_KNOWN_LIBTOOL_VER}
	fi
}
for wx in ${WANT_LIBTOOL:-latest} ; do
	if [ "${wx}" = "latest" ] ; then
		find_latest && break
	else
		find_binary ${wx} && break
	fi
done

if [ -z "${binary}" ] && [ -n "${WANT_LIBTOOL}" ] ; then
	warn "could not locate installed version for WANT_LIBTOOL='${WANT_LIBTOOL}'; ignoring"
	unset WANT_LIBTOOL
	find_latest
fi

if [ -z "${binary}" ] ; then
	err "Unable to locate any usable version of ${NAME}.\n" \
	    "\tI tried these versions:${all_vers}\n" \
	    "\tWith a base name of '${full_argv0}'."
fi

#
# autodetect routine
#
if [ -z "${WANT_LIBTOOL}" ] ; then
	auto_vers=
	dir=$(grep AC_CONFIG_AUX_DIR configure.[ai][cn] | sed -n 's/AC_CONFIG_AUX_DIR(\(.*\))/\1/p' | sed 's/\[\(.*\)\]/\1/')
	[[ ! -z ${dir} ]] && ltmain_sh=${dir}/ltmain.sh || ltmain_sh=ltmain.sh
	if [ -r "${ltmain_sh}" ] ; then
		auto_vers=$(sed -n -E 's/^# (libtool|ltmain\.sh) \(GNU libtool\) (.*)/\2/p' ${ltmain_sh})
		if [ -z "${auto_vers}" ] ; then
			auto_vers=1.5.24
		fi
	fi
	# We don't need to set $binary here as it has already been setup for us
	# earlier to the latest available version.
	if [ -n "${auto_vers}" ] ; then
		if ! find_binary ${auto_vers} ; then
			warn "auto-detected versions not found (${auto_vers}); falling back to latest available"
		fi
	fi
fi

if [ -n "${WANT_LTWRAPPER_DEBUG}" ] ; then
	if [ -n "${WANT_LIBTOOL}" ] ; then
		warn "DEBUG: WANT_LIBTOOL is set to ${WANT_LIBTOOL}"
	fi
	warn "DEBUG: will execute <${binary}>"
fi

#
# for further consistency
#
export WANT_LIBTOOL="${binary_ver}"

#
# Now try to run the binary
#
if [ ! -x "${binary}" ] ; then
	# this shouldn't happen
	err "${binary} is missing or not executable.\n" \
	    "\tPlease try installing the correct version of ${NAME}."
fi

exec "${binary}" "$@"
# The shell will error out if `exec` failed.
