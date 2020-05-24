#!/bin/bash

#set -x
set -e -u -o pipefail

cd "$(dirname "$0")"

declare -r BZIMAGE=./build-root/bzImage
declare -r INITRAMFS=./build-root/initramfs.cpio.gz

test \( -f "$BZIMAGE" \) -a \( -f "$INITRAMFS" \)

exec qemu-system-x86_64 -kernel "$BZIMAGE"      \
                        -initrd "$INITRAMFS"    \
                        -nographic              \
                        -append "console=ttyS0" \
                        -enable-kvm
