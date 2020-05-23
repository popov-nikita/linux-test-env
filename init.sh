#!/bin/bash

#set -x
set -e -u -o pipefail

declare -r LINUX_TXZ=latest-linux.tar.xz

check_deps() {
	declare -g -a -r DEPS=(
		qemu-system-x86_64
		curl
		sed
		sleep
		dirname
		tar
		unlink
	)
	local dep

	for dep in "${DEPS[@]}"; do
		if ! type -t "$dep" >/dev/null 2>&1; then
			printf '"%s" is missing\n' "$dep" >&2
			return 1
		fi
	done

	return 0
}

get_linux_link() {
	curl -s -H 'User-Agent:' -H 'Accept: text/html' https://www.kernel.org/ | sed -n -e '/<td[[:blank:]]*id[[:blank:]]*=[[:blank:]]*"latest_link"/,/<\/td>/s/^.*href="\([^"]\+\)".*$/\1/p'

	return 0
}

do_action() {
	local cmd="$1"
	local msg="$2"
	local pid
	local c

	eval "$cmd" &
	pid="$!"
	c=0
	printf '%s\n' "$msg"
	while kill -n 0 "$pid" >/dev/null 2>&1; do
		if test \( $c -eq 0 \) -o \( $c -eq 4 \); then
			printf '\r|'
		elif test \( $c -eq 1 \) -o \( $c -eq 5 \); then
			printf '\r/'
		elif test \( $c -eq 2 \) -o \( $c -eq 6 \); then
			printf '\r-'
		elif test \( $c -eq 3 \) -o \( $c -eq 7 \); then
			printf '\r\\'
		fi
		c=$(($c + 1))
		if test $c -ge 8; then
			c=0
		fi
		sleep 1s
	done
	wait "$pid"
	unset -v pid
	printf '\rDone\n'

	return 0
}

check_deps

cd "$(dirname "$0")/build-root"

on_exit() {
	if test -f "$LINUX_TXZ"; then
		unlink "$LINUX_TXZ"
	fi
}
trap on_exit EXIT

declare -r LINUX_LINK="$(get_linux_link)"
if test -z "$LINUX_LINK"; then
	printf "WARNING: www.kernel.org has been altered! Couldn't obtain download link\n" >&2
	exit 1
fi
printf '1: Downloading %s\n' "$LINUX_LINK"
do_action "curl -s -H 'User-Agent:' -H 'Accept: application/x-xz' -o \"$LINUX_TXZ\" \"$LINUX_LINK\"" 'Fetching data...'

exit 0
