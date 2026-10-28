#include <riscv.h>

    .macro SAVE_ALL

    csrw sscratch, sp

    addi sp, sp, -36 * REGBYTES
    # save x registers
    STORE x0, 0*REGBYTES(sp)
    STORE x1, 1*REGBYTES(sp)
    STORE x3, 3*REGBYTES(sp)
    STORE x4, 4*REGBYTES(sp)
    STORE x5, 5*REGBYTES(sp)
    STORE x6, 6*REGBYTES(sp)
    STORE x7, 7*REGBYTES(sp)
    STORE x8, 8*REGBYTES(sp)
    STORE x9, 9*REGBYTES(sp)
    STORE x10, 10*REGBYTES(sp)
    STORE x11, 11*REGBYTES(sp)
    STORE x12, 12*REGBYTES(sp)
    STORE x13, 13*REGBYTES(sp)
    STORE x14, 14*REGBYTES(sp)
    STORE x15, 15*REGBYTES(sp)
    STORE x16, 16*REGBYTES(sp)
    STORE x17, 17*REGBYTES(sp)
    STORE x18, 18*REGBYTES(sp)
    STORE x19, 19*REGBYTES(sp)
    STORE x20, 20*REGBYTES(sp)
    STORE x21, 21*REGBYTES(sp)
    STORE x22, 22*REGBYTES(sp)
    STORE x23, 23*REGBYTES(sp)
    STORE x24, 24*REGBYTES(sp)
    STORE x25, 25*REGBYTES(sp)
    STORE x26, 26*REGBYTES(sp)
    STORE x27, 27*REGBYTES(sp)
    STORE x28, 28*REGBYTES(sp)
    STORE x29, 29*REGBYTES(sp)
    STORE x30, 30*REGBYTES(sp)
    STORE x31, 31*REGBYTES(sp)

    # get sr, epc, badvaddr, cause
    # Set sscratch register to 0, so that if a recursive exception
    # occurs, the exception vector knows it came from the kernel
    csrrw s0, sscratch, x0
    csrr s1, sstatus
    csrr s2, sepc
    csrr s3, sbadaddr
    csrr s4, scause

    STORE s0, 2*REGBYTES(sp)
    STORE s1, 32*REGBYTES(sp)
    STORE s2, 33*REGBYTES(sp)
    STORE s3, 34*REGBYTES(sp)
    STORE s4, 35*REGBYTES(sp)
    .endm

    .macro RESTORE_ALL

    #lab3 function1 2413346

    # 1) 先写回 sstatus / sepc。s1、s2 只是临时寄存器，
    #    后面会用 trapframe 中 x9、x18 的保存值覆盖它们。
    LOAD s1, 32*REGBYTES(sp)        # tf->status
    LOAD s2, 33*REGBYTES(sp)        # tf->epc
    csrw sstatus, s1
    csrw sepc, s2

    # 2) 恢复除 sp 以外的通用寄存器
    LOAD x1, 1*REGBYTES(sp)         # ra
    LOAD x3, 3*REGBYTES(sp)         # gp
    LOAD x4, 4*REGBYTES(sp)         # tp
    LOAD x5, 5*REGBYTES(sp)         # t0
    LOAD x6, 6*REGBYTES(sp)         # t1
    LOAD x7, 7*REGBYTES(sp)         # t2
    LOAD x8, 8*REGBYTES(sp)         # s0/fp
    LOAD x9, 9*REGBYTES(sp)         # s1
    LOAD x10, 10*REGBYTES(sp)       # a0
    LOAD x11, 11*REGBYTES(sp)       # a1
    LOAD x12, 12*REGBYTES(sp)       # a2
    LOAD x13, 13*REGBYTES(sp)       # a3
    LOAD x14, 14*REGBYTES(sp)       # a4
    LOAD x15, 15*REGBYTES(sp)       # a5
    LOAD x16, 16*REGBYTES(sp)       # a6
    LOAD x17, 17*REGBYTES(sp)       # a7
    LOAD x18, 18*REGBYTES(sp)       # s2
    LOAD x19, 19*REGBYTES(sp)       # s3
    LOAD x20, 20*REGBYTES(sp)       # s4
    LOAD x21, 21*REGBYTES(sp)       # s5
    LOAD x22, 22*REGBYTES(sp)       # s6
    LOAD x23, 23*REGBYTES(sp)       # s7
    LOAD x24, 24*REGBYTES(sp)       # s8
    LOAD x25, 25*REGBYTES(sp)       # s9
    LOAD x26, 26*REGBYTES(sp)       # s10
    LOAD x27, 27*REGBYTES(sp)       # s11
    LOAD x28, 28*REGBYTES(sp)       # t3
    LOAD x29, 29*REGBYTES(sp)       # t4
    LOAD x30, 30*REGBYTES(sp)       # t5
    LOAD x31, 31*REGBYTES(sp)       # t6

    # 3) sp 最后恢复：上面的 LOAD 都依赖当前 sp 寻址
    LOAD x2, 2*REGBYTES(sp)         # 陷入前的 sp

    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL

    #lab3 function1 YOUR CODE
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
    # return from supervisor call
    sret
