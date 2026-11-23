#include <defs.h>
#include <mmu.h>
#include <memlayout.h>
#include <clock.h>
#include <trap.h>
#include <riscv.h>
#include <stdio.h>
#include <assert.h>
#include <console.h>
#include <vmm.h>
#include <kdebug.h>
#include <unistd.h>
#include <syscall.h>
#include <error.h>
#include <sched.h>
#include <sync.h>
#include <sbi.h>

#define TICK_NUM 100

static void print_ticks()
{
    cprintf("%d ticks\n", TICK_NUM);
#ifdef DEBUG_GRADE
    cprintf("End of Test.\n");
    panic("EOT: kernel seems ok.");
#endif
}

/* idt_init - initialize IDT to each of the entry points in kern/trap/vectors.S */
void idt_init(void)
{
    extern void __alltraps(void);
    /* Set sscratch register to 0, indicating to exception vector that we are
     * presently executing in the kernel */
    write_csr(sscratch, 0);
    /* Set the exception vector address */
    write_csr(stvec, &__alltraps);
    /* Allow kernel to access user memory */
    set_csr(sstatus, SSTATUS_SUM);
}

/* trap_in_kernel - test if trap happened in kernel */
bool trap_in_kernel(struct trapframe *tf)
{
    return (tf->status & SSTATUS_SPP) != 0;
}

void print_trapframe(struct trapframe *tf)
{
    cprintf("trapframe at %p\n", tf);
    // cprintf("trapframe at 0x%x\n", tf);
    print_regs(&tf->gpr);
    cprintf("  status   0x%08x\n", tf->status);
    cprintf("  epc      0x%08x\n", tf->epc);
    cprintf("  tval 0x%08x\n", tf->tval);
    cprintf("  cause    0x%08x\n", tf->cause);
}

void print_regs(struct pushregs *gpr)
{
    cprintf("  zero     0x%08x\n", gpr->zero);
    cprintf("  ra       0x%08x\n", gpr->ra);
    cprintf("  sp       0x%08x\n", gpr->sp);
    cprintf("  gp       0x%08x\n", gpr->gp);
    cprintf("  tp       0x%08x\n", gpr->tp);
    cprintf("  t0       0x%08x\n", gpr->t0);
    cprintf("  t1       0x%08x\n", gpr->t1);
    cprintf("  t2       0x%08x\n", gpr->t2);
    cprintf("  s0       0x%08x\n", gpr->s0);
    cprintf("  s1       0x%08x\n", gpr->s1);
    cprintf("  a0       0x%08x\n", gpr->a0);
    cprintf("  a1       0x%08x\n", gpr->a1);
    cprintf("  a2       0x%08x\n", gpr->a2);
    cprintf("  a3       0x%08x\n", gpr->a3);
    cprintf("  a4       0x%08x\n", gpr->a4);
    cprintf("  a5       0x%08x\n", gpr->a5);
    cprintf("  a6       0x%08x\n", gpr->a6);
    cprintf("  a7       0x%08x\n", gpr->a7);
    cprintf("  s2       0x%08x\n", gpr->s2);
    cprintf("  s3       0x%08x\n", gpr->s3);
    cprintf("  s4       0x%08x\n", gpr->s4);
    cprintf("  s5       0x%08x\n", gpr->s5);
    cprintf("  s6       0x%08x\n", gpr->s6);
    cprintf("  s7       0x%08x\n", gpr->s7);
    cprintf("  s8       0x%08x\n", gpr->s8);
    cprintf("  s9       0x%08x\n", gpr->s9);
    cprintf("  s10      0x%08x\n", gpr->s10);
    cprintf("  s11      0x%08x\n", gpr->s11);
    cprintf("  t3       0x%08x\n", gpr->t3);
    cprintf("  t4       0x%08x\n", gpr->t4);
    cprintf("  t5       0x%08x\n", gpr->t5);
    cprintf("  t6       0x%08x\n", gpr->t6);
}

extern struct mm_struct *check_mm_struct;

//lab3 请补充你在lab3中的代码

void interrupt_handler(struct trapframe *tf) {
    // static unsigned int print_count = 0;  //统计发生多少次中断，只初始化一次

    // 去掉 scause 最高位的中断标志，取得中断编号。
    uintptr_t cause = tf->cause &
        ~((uintptr_t)1 << (sizeof(uintptr_t) * 8 - 1));

    switch (cause) {
    case IRQ_U_SOFT:
        cprintf("User software interrupt\n");
        break;

    case IRQ_S_SOFT:
        cprintf("Supervisor software interrupt\n");
        break;

    case IRQ_H_SOFT:
        cprintf("Hypervisor software interrupt\n");
        break;

    case IRQ_M_SOFT:
        cprintf("Machine software interrupt\n");
        break;

    case IRQ_U_TIMER:
        cprintf("User timer interrupt\n");
        break;

    case IRQ_S_TIMER:
        clock_set_next_event();
        ticks++;

        if (ticks % TICK_NUM == 0)
        {
            if (current != NULL)
            {
                current->need_resched = 1;
            }
        }
        break;

    case IRQ_H_TIMER:
        cprintf("Hypervisor timer interrupt\n");
        break;

    case IRQ_M_TIMER:
        cprintf("Machine timer interrupt\n");
        break;

    case IRQ_U_EXT:
        cprintf("User external interrupt\n");
        break;

    case IRQ_S_EXT:
        cprintf("Supervisor external interrupt\n");
        break;

    case IRQ_H_EXT:
        cprintf("Hypervisor external interrupt\n");
        break;

    case IRQ_M_EXT:
        cprintf("Machine external interrupt\n");
        break;

    default:
        cprintf("Unknown interrupt: cause %lu\n",
                (unsigned long)cause);
        print_trapframe(tf);
        break;
    }
}

//lab5 function1 2411033 update exception_handler

void exception_handler(struct trapframe *tf) {
    switch (tf->cause) {
    case CAUSE_USER_ECALL:
        /*
         * ecall 固定为 4 字节。
         * 先推进返回地址，避免返回用户态后再次执行 ecall。
         */
        tf->epc += 4;
        syscall();
        return;

    case CAUSE_ILLEGAL_INSTRUCTION:
    case CAUSE_BREAKPOINT:
        /*
         * 保留此前 Lab3 中内核态测试异常的处理方式。
         * 用户态触发这两类异常则进入下面的进程终止路径。
         */
        if (trap_in_kernel(tf)) {
            cprintf("%s at 0x%016llx\n",
                    tf->cause == CAUSE_BREAKPOINT
                        ? "Breakpoint" : "Illegal instruction",
                    (unsigned long long)tf->epc);

            uint16_t instruction =
                *(const volatile uint16_t *)tf->epc;

            /* 区分 2 字节压缩指令和 4 字节普通指令。 */
            tf->epc += ((instruction & 0x3) == 0x3) ? 4 : 2;
            return;
        }
        break;

    case CAUSE_STORE_PAGE_FAULT:
        /* COW Challenge 2411033: retry the same store after fixing its PTE.
         * Kernel-to-user writes will be adapted separately; do not turn an
         * arbitrary kernel page fault into a successful user COW fault.
         */
        if (!trap_in_kernel(tf) && current != NULL && current->mm != NULL &&
            do_cow_fault(current->mm, tf->tval) == 0) {
            return;
        }
        break;

    case CAUSE_FETCH_PAGE_FAULT:
    case CAUSE_LOAD_PAGE_FAULT:
        break;

    default:
        break;
    }

    print_trapframe(tf);

    /* 用户错误只终止对应进程，避免拖垮内核。 */
    if (!trap_in_kernel(tf) && current != NULL) {
        cprintf("Unhandled user exception, kill pid %d.\n",
                current->pid);
        do_exit(-E_KILLED);
        panic("do_exit returned unexpectedly");
    }

    /* 无法处理的内核异常不能直接跳过。 */
    panic("Unhandled kernel exception");
}

static inline void trap_dispatch(struct trapframe *tf)
{
    if ((intptr_t)tf->cause < 0)
    {
        // interrupts
        interrupt_handler(tf);
    }
    else
    {
        // exceptions
        exception_handler(tf);
    }
}

/* *
 * trap - handles or dispatches an exception/interrupt. if and when trap() returns,
 * the code in kern/trap/trapentry.S restores the old CPU state saved in the
 * trapframe and then uses the iret instruction to return from the exception.
 * */
void trap(struct trapframe *tf)
{
    // dispatch based on what type of trap occurred
    //    cputs("some trap");
    if (current == NULL)
    {
        trap_dispatch(tf);
    }
    else
    {
        struct trapframe *otf = current->tf;
        current->tf = tf;

        bool in_kernel = trap_in_kernel(tf);

        trap_dispatch(tf);

        current->tf = otf;
        if (!in_kernel)
        {
            if (current->flags & PF_EXITING)
            {
                do_exit(-E_KILLED);
            }
            if (current->need_resched)
            {
                schedule();
            }
        }
    }
}
