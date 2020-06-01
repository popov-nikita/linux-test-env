#!/bin/bash

#set -x
set -e -u -o pipefail

declare -r LINUX_TAR=latest-linux.tar.xz
declare -r BUSYBOX_TAR=latest-busybox.tar.bz2

check_deps() {
	declare -g -a -r DEPS=(
		bc
		bison
		coreutils
		cpio
		curl
		findutils
		flex
		gcc
		gzip
		libc-dev
		libncurses-dev
		make
		mawk
		qemu-system-x86
		sed
		tar
		xz-utils
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

declare -r MK_INC_BASENAME='Makefile.inc'
declare -r MK_INC_PATH="../../${MK_INC_BASENAME}"
declare -r KBUILD_INC='./scripts/Kbuild.include'

printf '3: Preparing %s\n' "$LINUX_TAR"
do_action "(tar -x -f \"${LINUX_TAR}\";                                  \
            cd linux-*;                                                  \
            ln -s -f \"${MK_INC_PATH}\" \".\";                           \
            _this_mk_inc=\"\$(readlink -f \"${MK_INC_BASENAME}\")\";     \
            sed -i.orig -e 's/if_changed/___tmp_\0/g' \"${KBUILD_INC}\"; \
            sed -i -e \"\\\$ainclude \$_this_mk_inc\" \"${KBUILD_INC}\"; \
            unset -v _this_mk_inc;                                       \
            make mrproper;                                               \
            cp ../../kernel-config .config;                              \
            make olddefconfig;                                           \
            make \"-j\$(nproc)\" all;                                    \
            _bzimage_path=arch/x86_64/boot/bzImage;                      \
            cp -f -L -t .. \"\$_bzimage_path\";                          \
            unset -v _bzimage_path) >/dev/null 2>&1"                     \
          'Compiling kernel...'

printf '4: Preparing %s\n' "$BUSYBOX_TAR"
do_action "(tar -x -f \"${BUSYBOX_TAR}\";                                \
            cd busybox-*;                                                \
            ln -s -f \"${MK_INC_PATH}\" \".\";                           \
            _this_mk_inc=\"\$(readlink -f \"${MK_INC_BASENAME}\")\";     \
            sed -i.orig -e 's/if_changed/___tmp_\0/g' \"${KBUILD_INC}\"; \
            sed -i -e \"\\\$ainclude \$_this_mk_inc\" \"${KBUILD_INC}\"; \
            unset -v _this_mk_inc;                                       \
            make mrproper;                                               \
            cp ../../busybox-config .config;                             \
            make silentoldconfig;                                        \
            make \"-j\$(nproc)\" all;                                    \
            make install) >/dev/null 2>&1"                               \
          'Compiling busybox...'

declare -r -a INITRAMFS_DIRS=(
	bin
	sbin
	etc
	proc
	sys
	usr/bin
	usr/sbin
	usr/include
	usr/local/bin
)

printf '5: Packing initramfs.cpio.gz\n'
cat <<-'EOF' >__init__
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys

PATH='/usr/local/bin:/bin:/sbin:/usr/bin:/usr/sbin'
export PATH

exec /bin/sh
EOF
do_action "(cd busybox-*/_install;                                       \
            mkdir -p ${INITRAMFS_DIRS[*]};                               \
            make -C ../../linux-* headers;                               \
            cp -r ../../linux-*/usr/include/* usr/include;               \
            find usr/include \( -name '.*' -o -name Makefile \) -delete; \
            mv -T ../../__init__ ./init;                                 \
            chmod 755 init;                                              \
            make -C ../../../extensions \"R=\$(pwd)\" all;               \
            find . -print0 |                                             \
            cpio --null -ov --format=newc |                              \
            gzip -9 > ../../initramfs.cpio.gz) >/dev/null 2>&1"          \
          'Creating initramfs...'

exit 0
