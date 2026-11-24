# QEMU 侧 GDB 脚本（对象是“模拟器进程本身”，观察 TCG 生成的代码如何调用 C helper）
#
# 为什么不用 gdb -p：Ubuntu 默认 kernel.yama.ptrace_scope=1，普通用户只能
# ptrace 自己的后代进程，直接 attach 兄弟进程会报
#   ptrace: Inappropriate ioctl for device / Could not attach to process
# 这里采用“让 host gdb 直接启动 QEMU”的方式，QEMU 是 gdb 的子进程，不需要 attach。
# 另一种办法是 sudo sysctl -w kernel.yama.ptrace_scope=0 后 gdb -p <pid>。
#
# 用法（在 code 目录下）：
#   make build-hello
#   gdb -x ../report/gdb/qemu_host.gdb        # 终端 A：启动 QEMU（-S -s，等 ucore gdb）
#   make gdb                                  # 终端 B：连接到 QEMU 的 gdbstub，continue
#
# 说明：
# 1) QEMU 源码路径按本机实际构建目录填写；没有调试符号时先重新 configure/make。
# 2) ucore 自身用 SBI ecall 输出字符（S 态 ecall），所以 helper_raise_exception
#    会先在 S 态命中。用条件断点 env->priv == 0 只停在用户态 ecall。
# 3) QEMU 4.1.1 的 CPURISCVState 没有 sstatus 成员，sstatus 是 mstatus 的视图，
#    打印 env->mstatus 后按位解读：SPP=bit8，SPIE=bit5，SIE=bit1。

set pagination off
set confirm off
file /home/agony/Desktop/qemu-4.1.1/riscv64-softmmu/qemu-system-riscv64

# 改成自己的绝对/相对路径，必须与 make debug 的参数一致。
set args -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000 -s -S

# ecall：只停用户态（特权级 U = 0）。
break helper_raise_exception if env->priv == 0
run
printf "USER-ECALL: exception=%d priv=%ld sepc=%#lx pc=%#lx\n", \
    exception, env->priv, env->sepc, env->pc
info registers pc
bt 6

# sret：停在 helper_sret 入口，观察 SPP（返回后特权级）、sepc（返回地址）。
delete 1
break helper_sret
continue
printf "USER-SRET: priv=%ld sepc=%#lx mstatus=%#lx SPP=%ld SPIE=%ld SIE=%ld\n", \
    env->priv, env->sepc, env->mstatus, \
    (env->mstatus >> 8) & 1, (env->mstatus >> 5) & 1, (env->mstatus >> 1) & 1
bt 6

# 再抓下一次用户态 ecall：此时 env->priv 应为 0，说明 sret 已回到 U 态。
delete 2
break helper_raise_exception if env->priv == 0
continue
printf "NEXT-USER-ECALL: exception=%d priv=%ld pc=%#lx\n", \
    exception, env->priv, env->pc
