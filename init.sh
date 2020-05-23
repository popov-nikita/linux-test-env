#!/bin/bash

#set -x
set -e -u -o pipefail

declare -r LINUX_TAR=latest-linux.tar.xz
declare -r BUSYBOX_TAR=latest-busybox.tar.bz2

check_deps() {
	declare -g -a -r DEPS=(
		xz-utils
		make
		gcc
		libc-dev
		flex
		bison
		libncurses-dev
		qemu-system-x86
		curl
		mawk
		coreutils
		tar
	)
	local dep

	if ! type -t 'dpkg-query' >/dev/null 2>&1; then
		printf 'Sorry, only debian-based distros are supported :(\n' >&2
		return 1
	fi

	for dep in "${DEPS[@]}"; do
		if ! dpkg-query -W -f '${Status}\n' "$dep" >/dev/null 2>&1; then
			printf 'Package "%s" is missing\n' "$dep" >&2
			return 1
		fi
	done

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
		c=$((($c + 1) & 0x7))
		sleep 1s
	done
	wait "$pid"
	unset -v pid
	printf '\rDone\n'

	return 0
}

check_deps

cd "$(dirname "$0")"
declare -r AWK_SCRIPT="$(realpath get-latest-link)"

get_linux_link() {
	URL=https://www.kernel.org/ mawk -f "$AWK_SCRIPT" - 2>/dev/null
	return 0
}

get_busybox_link() {
	URL=https://busybox.net/downloads/ mawk -f "$AWK_SCRIPT" - 2>/dev/null
	return 0
}

cd build-root/

on_exit() {
	if test -f "$BUSYBOX_TAR"; then
		unlink "$BUSYBOX_TAR"
	fi
	if test -f "$LINUX_TAR"; then
		unlink "$LINUX_TAR"
	fi
}
trap on_exit EXIT

declare -r LINUX_LINK="$(get_linux_link)"
if test -z "$LINUX_LINK"; then
	printf "WARNING: www.kernel.org has been altered! Couldn't obtain download link\n" >&2
	exit 1
fi
printf '1: Downloading %s\n' "$LINUX_LINK"
do_action "curl -s -H 'User-Agent:' -H 'Accept: application/x-xz' -o \"$LINUX_TAR\" \"$LINUX_LINK\"" 'Fetching data...'

declare -r BUSYBOX_LINK="$(get_busybox_link)"
if test -z "$BUSYBOX_LINK"; then
	printf "WARNING: https://busybox.net/downloads/ has been altered! Couldn't obtain download link\n" >&2
	exit 1
fi
printf '2: Downloading %s\n' "$BUSYBOX_LINK"
do_action "curl -s -H 'User-Agent:' -H 'Accept: application/x-bzip2' -o \"$BUSYBOX_TAR\" \"$BUSYBOX_LINK\"" 'Fetching data...'

shopt -s failglob

#printf '2: Compiling %s\n' "$LINUX_TAR"
#(
#	tar -x -f "$LINUX_TAR"
#	cd linux-*
#	make mrproper
#	cp "../../kernel-config .config
#	make olddefconfig
#	make "-j$(nproc)" all
#)

exit 0
