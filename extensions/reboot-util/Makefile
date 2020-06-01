all:
clean:
.PHONY: all clean

ifneq ($(origin R),command line)
    $(error Please, specify initramfs root in R variable of command line flavor)
endif

src := reboot-util.S
obj := $(patsubst %.S,%.o,$(src))
exe := $(patsubst %.S,%,$(firstword $(src)))

_syscall_2_nr = printf '\#include "./usr/include/asm/unistd_64.h"\n$(1)\n' | gcc -E -P -x c -o /dev/stdout -
syscall_2_nr  = $(shell cd '$(R)'; $(_syscall_2_nr))

all: $(exe)
	cp -f $< $(R)/usr/local/bin

$(exe): $(obj)
	ld -e start -s -o $@ $^

$(obj): %.o: %.S
	as --64 --defsym .L__NR_reboot=$(call syscall_2_nr,__NR_reboot) \
                --defsym .L__NR_exit=$(call syscall_2_nr,__NR_exit) \
                -o $@ $<

$(src):

clean:
	rm -f $(obj) $(exe)
