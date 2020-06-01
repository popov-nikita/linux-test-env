all:
.PHONY: all

ifneq ($(origin R),command line)
    $(error Please, specify initramfs root in R variable of command line flavor)
endif

ifneq ($(shell set +e; test \( -d '$(R)' \); echo $$?),0)
    $(error $(R) does not exist)
endif

extensions := reboot-util
.PHONY: $(extensions)

# No extensions for initramfs for now
all: $(extensions)

$(extensions):
	$(MAKE) -C $@ 'R=$(R)' all
