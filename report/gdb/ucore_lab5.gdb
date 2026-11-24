# ucore 侧 GDB 脚本（对象是“跑在 QEMU 里的 ucore + 用户程序”）
#
# 用法（在 code 目录下）：
#   make build-hello
#   make debug                      # 终端 1：启动 QEMU，-S -s
#   riscv64-unknown-elf-gdb -x ../report/gdb/ucore_lab5.gdb    # 终端 2
#
# 地址来自本机 hello 构建，换程序/换构建后必须重新用 objdump 确认：
#   riscv64-unknown-elf-objdump -d obj/__user_hello.out | sed -n '/<syscall>:/,/ret/p'
#   riscv64-unknown-elf-objdump -d bin/kernel | grep -n -B2 'sret'
#
# hello 的本机构建：用户 syscall 在 0x800076，ecall 在 0x8000a2，
# 下一条（返回点）在 0x8000a6；内核 __trapret 的 sret 在 0xffffffffc0200f12。

set pagination off
set confirm off
file bin/kernel
set arch riscv:rv64
target remote localhost:1234

# 用户程序符号必须手动加载：make debug 只加载内核 ELF。
add-symbol-file obj/__user_hello.out

# 观测点 1：hello 第一次 cprintf -> sys_putc 的 ecall 之前。
# 用地址而不是行号，避免 add-symbol-file 的行号重叠。
break *0x8000a2
continue
info registers pc a0 a1 a2
x/4i $pc
bt

# 观测点 2：系统调用返回用户态前的 sret。
break *0xffffffffc0200f12
continue
info registers pc sp
info registers sstatus sepc scause
x/2i $pc

# 单步执行 sret：PC 应变为 sepc 的值（0x8000a6），特权级回到 U。
si
info registers pc
