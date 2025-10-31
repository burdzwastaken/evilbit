KDIR ?= /lib/modules/$(shell uname -r)/build

obj-m := evilbit.o

export RUST_LIB_SRC ?= $(shell --print sysroot)/lib/rustlib/src/rust/library

.PHONY: all clean install uninstall test load logs capture reload help

## all: build the kernel module
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

## clean: clean build artifacts
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

## install: insert the compiled module into the kernel
install: all
	sudo insmod evilbit.ko

## uninstall: remove the installed module
uninstall:
	sudo rmmod evilbit || true

## test: test the installed module
test: install
	dmesg | tail -n 20
	@echo "\n=== Testing Evil Bit ==="
	@echo "sending a test packet..."
	ping -c 1 8.8.8.8 || true
	@echo "\nchecking dmesg for evil bit messages..."
	dmesg | grep -i evil | tail -n 5

## load: module with logging
load: install
	dmesg | grep -i evil | tail -n 10

## logs: view kernel logs
logs:
	dmesg | grep -i evil | tail -n 20

## capture: capture packets to verify evil bit is set
capture:
	@echo "capture packets on all interfaces to verify evil bit..."
	@echo "the evil bit should be visible in the IP flags field"
	sudo tcpdump -i any -c 10 -vvv ip

## reload: reload the module
reload: uninstall install
	@echo "evilbit reloaded"

## help: print this help message
help:
	@printf 'usage:\n'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'
