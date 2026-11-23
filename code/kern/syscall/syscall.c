#include <unistd.h>
#include <proc.h>
#include <syscall.h>
#include <trap.h>
#include <stdio.h>
#include <pmm.h>
#include <vmm.h>
#include <error.h>
#include <assert.h>

//lab5 function1 2411033

static int sys_exit(uint64_t arg[]) {
    return do_exit((int)arg[0]);
}

static int sys_fork(uint64_t arg[]) {
    struct trapframe *tf = current->tf;

    /*
     * 普通 fork：clone_flags 为 0。
     * 子进程沿用当前用户栈位置，并以当前中断帧为模板。
     * 子进程返回值为 0 的处理由 do_fork/copy_thread 完成。
     */
    return do_fork(0, tf->gpr.sp, tf);
}

static int sys_wait(uint64_t arg[]) {
    int pid = (int)arg[0];
    int *code_store = (int *)(uintptr_t)arg[1];

    /*
     * NULL 表示不接收退出码。
     * 非 NULL 时，目标必须是可写的合法地址。
     */
    if (code_store != NULL &&
        !user_mem_check(current->mm, (uintptr_t)code_store,
                        sizeof(*code_store), 1)) {
        return -E_INVAL;
    }

    return do_wait(pid, code_store);
}

static int sys_exec(uint64_t arg[]) {
    const char *name = (const char *)(uintptr_t)arg[0];
    size_t len = (size_t)arg[1];
    unsigned char *binary = (unsigned char *)(uintptr_t)arg[2];
    size_t size = (size_t)arg[3];

    /*
     * name 和 binary 都来自调用者。
     * 在转交进程管理层前，检查对应内存范围是否可读。
     * ELF 格式和装载错误由 do_execve/load_icode 检查。
     */
    if ((len != 0 &&
         !user_mem_check(current->mm, (uintptr_t)name, len, 0)) ||
        size == 0 ||
        !user_mem_check(current->mm, (uintptr_t)binary, size, 0)) {
        return -E_INVAL;
    }

    return do_execve(name, len, binary, size);
}

static int sys_yield(uint64_t arg[]) {
    return do_yield();
}

static int sys_kill(uint64_t arg[]) {
    return do_kill((int)arg[0]);
}

static int sys_getpid(uint64_t arg[]) {
    return current->pid;
}

static int sys_putc(uint64_t arg[]) {
    cputchar((int)arg[0]);
    return 0;
}

static int sys_pgdir(uint64_t arg[]) {
    /*
     * 用户进程查看自己的页表；
     * 没有用户地址空间的内核线程查看启动页表。
     */
    pde_t *root = current->mm != NULL
                    ? current->mm->pgdir : boot_pgdir_va;

    if (root == NULL) {
        return -E_INVAL;
    }

    /*
     * Sv39 为三级页表，level = 2、1、0。
     * 使用固定大小的数组保存遍历状态，避免递归。
     */
    pde_t *tables[3] = {NULL, NULL, root};
    unsigned int next[3] = {0, 0, 0};
    uintptr_t bases[3] = {0, 0, 0};
    int level = 2;

    cprintf("pgdir: pid=%d, root=%p\n", current->pid, root);

    while (level < 3) {
        /* 当前页表遍历结束，返回上一级。 */
        if (next[level] == NPTEENTRY) {
            level++;
            continue;
        }

        unsigned int index = next[level]++;
        pte_t entry = tables[level][index];

        if (!(entry & PTE_V)) {
            continue;
        }

        unsigned int shift = PGSHIFT + 9 * level;
        uintptr_t va =
            bases[level] | ((uintptr_t)index << shift);

        /*
         * R/W/X 至少有一位非零，表示叶子映射；
         * 同时支持普通页和高层叶子对应的大页。
         */
        if (entry & (PTE_R | PTE_W | PTE_X)) {
            /* Sv39 虚拟地址的第 38 位需要符号扩展。 */
            if (va & ((uintptr_t)1 << 38)) {
                va |= ~(((uintptr_t)1 << 39) - 1);
            }

            cprintf("  L%d VA=0x%016llx -> PA=0x%016llx "
                    "size=0x%llx perm=%c%c%c%c PTE=0x%016llx\n",
                    level,
                    (unsigned long long)va,
                    (unsigned long long)PTE_ADDR(entry),
                    (unsigned long long)((uintptr_t)1 << shift),
                    (entry & PTE_U) ? 'u' : '-',
                    (entry & PTE_R) ? 'r' : '-',
                    (entry & PTE_W) ? 'w' : '-',
                    (entry & PTE_X) ? 'x' : '-',
                    (unsigned long long)entry);
        }
        else if (level > 0) {
            /* 非叶子项指向下一级页表。 */
            tables[level - 1] =
                (pde_t *)KADDR(PTE_ADDR(entry));
            bases[level - 1] = va;
            next[level - 1] = 0;
            level--;
        }
    }

    return 0;
}

/* 放在 sys_* 定义之后，避免使用未声明的函数。 */
static int (*syscalls[])(uint64_t arg[]) = {
    [SYS_exit]   = sys_exit,
    [SYS_fork]   = sys_fork,
    [SYS_wait]   = sys_wait,
    [SYS_exec]   = sys_exec,
    [SYS_yield]  = sys_yield,
    [SYS_kill]   = sys_kill,
    [SYS_getpid] = sys_getpid,
    [SYS_putc]   = sys_putc,
    [SYS_pgdir]  = sys_pgdir,
};

#define NUM_SYSCALLS (sizeof(syscalls) / sizeof(syscalls[0]))

void syscall(void) {
    assert(current != NULL && current->tf != NULL);

    struct trapframe *tf = current->tf;

    /*
     * 本项目 ABI：
     * a0：系统调用号
     * a1～a5：最多五个参数
     * a0：返回值
     *
     * 保留完整宽度，避免过大的调用号截断后变成合法编号。
     */
    uintptr_t num = tf->gpr.a0;

    uint64_t args[5] = {
        tf->gpr.a1,
        tf->gpr.a2,
        tf->gpr.a3,
        tf->gpr.a4,
        tf->gpr.a5
    };

    int ret = -E_INVAL;

    /* 同时检查数组边界和空表项。 */
    if (num < NUM_SYSCALLS && syscalls[num] != NULL) {
        ret = syscalls[num](args);
    }

    /* 将负错误码正确符号扩展到 RV64 寄存器宽度。 */
    tf->gpr.a0 = (uintptr_t)(intptr_t)ret;
}