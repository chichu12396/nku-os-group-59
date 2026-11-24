# 仓库根目录的便捷入口：真正的构建规则在 code/Makefile。
# 这样在 lab5/ 根目录直接 `make`、`make qemu`、`make clean`、`make build-hello`
# 都会转发到 code/，避免因为当前目录不对而报
#   make: *** No targets specified and no makefile found.  Stop.
.DEFAULT_GOAL := all

.PHONY: all
all:
	$(MAKE) -C code

%:
	$(MAKE) -C code $@
