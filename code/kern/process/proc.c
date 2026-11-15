#include <proc.h>
#include <kmalloc.h>
#include <string.h>
#include <sync.h>
#include <pmm.h>
#include <error.h>
#include <sched.h>
#include <elf.h>
#include <vmm.h>
#include <trap.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

/* ------------- process/thread mechanism design&implementation -------------
(an simplified Linux process/thread mechanism )
introduction:
  ucore implements a simple process/thread mechanism. process contains the independent memory sapce, at least one threads
for execution, the kernel data(for management), processor state (for context switch), files(in lab6), etc. ucore needs to
manage all these details efficiently. In ucore, a thread is just a special kind of process(share process's memory).
------------------------------
process state       :     meaning               -- reason
    PROC_UNINIT     :   uninitialized           -- alloc_proc
    PROC_SLEEPING   :   sleeping                -- try_free_pages, do_wait, do_sleep
    PROC_RUNNABLE   :   runnable(maybe running) -- proc_init, wakeup_proc,
    PROC_ZOMBIE     :   almost dead             -- do_exit

-----------------------------
process state changing:

  alloc_proc                                 RUNNING
      +                                   +--<----<--+
      +                                   + proc_run +
      V                                   +-->---->--+
PROC_UNINIT -- proc_init/wakeup_proc --> PROC_RUNNABLE -- try_free_pages/do_wait/do_sleep --> PROC_SLEEPING --
                                           A      +                                                           +
                                           |      +--- do_exit --> PROC_ZOMBIE                                +
                                           +                                                                  +
                                           -----------------------wakeup_proc----------------------------------
-----------------------------
process relations
parent:           proc->parent  (proc is children)
children:         proc->cptr    (proc is parent)
older sibling:    proc->optr    (proc is younger sibling)
younger sibling:  proc->yptr    (proc is older sibling)
-----------------------------
related syscall for process:
SYS_exit        : process exit,                           -->do_exit
SYS_fork        : create child process, dup mm            -->do_fork-->wakeup_proc
SYS_wait        : wait process                            -->do_wait
SYS_exec        : after fork, process execute a program   -->load a program and refresh the mm
SYS_clone       : create child thread                     -->do_fork-->wakeup_proc
SYS_yield       : process flag itself need resecheduling, -- proc->need_sched=1, then scheduler will rescheule this process
SYS_sleep       : process sleep                           -->do_sleep
SYS_kill        : kill process                            -->do_kill-->proc->flags |= PF_EXITING
                                                                 -->wakeup_proc-->do_wait-->do_exit
SYS_getpid      : get the process's pid

*/

// the process set's list
list_entry_t proc_list;

#define HASH_SHIFT 10
#define HASH_LIST_SIZE (1 << HASH_SHIFT)
#define pid_hashfn(x) (hash32(x, HASH_SHIFT))

// has list for process set based on pid
static list_entry_t hash_list[HASH_LIST_SIZE];

// idle proc
struct proc_struct *idleproc = NULL;
// init proc
struct proc_struct *initproc = NULL;
// current proc
struct proc_struct *current = NULL;

static int nr_process = 0;

void kernel_thread_entry(void);
void forkrets(struct trapframe *tf);
void switch_to(struct context *from, struct context *to);

// set_proc_name - set the name of proc
char *
set_proc_name(struct proc_struct *proc, const char *name)
{
    memset(proc->name, 0, sizeof(proc->name));
    return memcpy(proc->name, name, PROC_NAME_LEN);
}

// get_proc_name - get the name of proc
char *
get_proc_name(struct proc_struct *proc)
{
    static char name[PROC_NAME_LEN + 1];
    memset(name, 0, sizeof(name));
    return memcpy(name, proc->name, PROC_NAME_LEN);
}

// get_pid - alloc a unique pid for process
static int
get_pid(void)
{
    static_assert(MAX_PID > MAX_PROCESS);
    struct proc_struct *proc;
    list_entry_t *list = &proc_list, *le;
    static int next_safe = MAX_PID, last_pid = MAX_PID;
    if (++last_pid >= MAX_PID)
    {
        last_pid = 1;
        goto inside;
    }
    if (last_pid >= next_safe)
    {
    inside:
        next_safe = MAX_PID;
    repeat:
        le = list;
        while ((le = list_next(le)) != list)
        {
            proc = le2proc(le, list_link);
            if (proc->pid == last_pid)
            {
                if (++last_pid >= next_safe)
                {
                    if (last_pid >= MAX_PID)
                    {
                        last_pid = 1;
                    }
                    next_safe = MAX_PID;
                    goto repeat;
                }
            }
            else if (proc->pid > last_pid && next_safe > proc->pid)
            {
                next_safe = proc->pid;
            }
        }
    }
    return last_pid;
}


// forkret -- the first kernel entry point of a new thread/process
// NOTE: the addr of forkret is setted in copy_thread function
//       after switch_to, the current proc will execute here.
static void
forkret(void)
{
    forkrets(current->tf);
}

// hash_proc - add proc into proc hash_list
static void
hash_proc(struct proc_struct *proc)
{
    list_add(hash_list + pid_hashfn(proc->pid), &(proc->hash_link));
}

// find_proc - find proc frome proc hash_list according to pid
struct proc_struct *
find_proc(int pid)
{
    if (0 < pid && pid < MAX_PID)
    {
        list_entry_t *list = hash_list + pid_hashfn(pid), *le = list;
        while ((le = list_next(le)) != list)
        {
            struct proc_struct *proc = le2proc(le, hash_link);
            if (proc->pid == pid)
            {
                return proc;
            }
        }
    }
    return NULL;
}


// setup_kstack - alloc pages with size KSTACKPAGE as process kernel stack
static int
setup_kstack(struct proc_struct *proc)
{
    struct Page *page = alloc_pages(KSTACKPAGE);
    if (page != NULL)
    {
        proc->kstack = (uintptr_t)page2kva(page);
        return 0;
    }
    return -E_NO_MEM;
}

// put_kstack - free the memory space of process kernel stack
static void
put_kstack(struct proc_struct *proc)
{
    free_pages(kva2page((void *)(proc->kstack)), KSTACKPAGE);
}


// do_exit - called by sys_exit
//   1. call exit_mmap & put_pgdir & mm_destroy to free the almost all memory space of process
//   2. set process' state as PROC_ZOMBIE, then call wakeup_proc(parent) to ask parent reclaim itself.
//   3. call scheduler to switch to other process
int do_exit(int error_code)
{
    panic("process exit!!.\n");
}

// init_main - the second kernel thread used to create user_main kernel threads
static int
init_main(void *arg)
{
    cprintf("this initproc, pid = %d, name = \"%s\"\n", current->pid, get_proc_name(current));
    cprintf("To U: \"%s\".\n", (const char *)arg);
    cprintf("To U: \"en.., Bye, Bye. :)\"\n");
    return 0;
}

//LAB4 function2 2413346

// 两个内部辅助函数在 do_fork 之后定义，先给出前置声明。
static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);

// alloc_proc - 分配并初始化一个进程控制块。
// 这里只把 PCB 置为安全的“空白”状态，身份（pid）、内核栈和现场由后续步骤填写。
static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(struct proc_struct));
    if (proc != NULL)
    {
        // 刚创建、尚未进入调度。
        proc->state = PROC_UNINIT;
        proc->pid = -1;
        proc->runs = 0;
        proc->kstack = 0;
        proc->need_resched = 0;
        proc->parent = NULL;
        proc->mm = NULL;
        // 上下文和中断帧都清零，避免首次切换时恢复出残留的寄存器值。
        memset(&(proc->context), 0, sizeof(struct context));
        proc->tf = NULL;
        // 内核线程共享内核地址空间，pgdir 保存页表根的物理地址。
        proc->pgdir = boot_pgdir_pa;
        proc->flags = 0;
        memset(proc->name, 0, sizeof(proc->name));
    }
    return proc;
}

// proc_init - 初始化进程管理结构，建立 idleproc 和 initproc
void proc_init(void)
{
    int i;

    // 进程链表和按 pid 索引的哈希表都从空表开始。
    list_init(&proc_list);
    for (i = 0; i < HASH_LIST_SIZE; i++)
    {
        list_init(hash_list + i);
    }

    // 第 0 个内核线程 idleproc：直接复用当前的执行现场（bootstack）。
    if ((idleproc = alloc_proc()) == NULL)
    {
        panic("cannot alloc idleproc.\n");
    }
    idleproc->pid = 0;
    idleproc->state = PROC_RUNNABLE;
    idleproc->kstack = (uintptr_t)bootstack;
    idleproc->need_resched = 1;
    set_proc_name(idleproc, "idle");
    nr_process++;

    // 从此刻起 current 指向 idleproc，后续 do_fork 以它为父进程。
    current = idleproc;

    // 第 1 个内核线程 initproc：由 kernel_thread 构造首次运行现场后创建。
    int pid = kernel_thread(init_main, "Hello world!!", 0);
    if (pid <= 0)
    {
        panic("create init_main failed.\n");
    }

    initproc = find_proc(pid);
    set_proc_name(initproc, "init");

    assert(idleproc != NULL && idleproc->pid == 0);
    assert(initproc != NULL && initproc->pid == 1);
}

// kernel_thread - 用内核函数 fn(arg) 创建一个内核线程
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
{
    struct trapframe tf;
    memset(&tf, 0, sizeof(struct trapframe));

    // kernel_thread_entry 用 s0 作入口、s1 传参数。
    tf.gpr.s0 = (uintptr_t)fn;
    tf.gpr.s1 = (uintptr_t)arg;
    // SPP：sret 返回 S 态；SPIE：返回后保持中断使能；SIE 清零：构造期间不被打断。
    tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE;
    tf.epc = (uintptr_t)kernel_thread_entry;

    // 内核线程共享内核地址空间，传入 CLONE_VM；stack = 0 表示使用新线程自己的内核栈。
    return do_fork(clone_flags | CLONE_VM, 0, &tf);
}

// do_fork - 复制当前线程的执行现场，产生一个新的内核线程
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    int ret = -E_NO_FREE_PROC;
    struct proc_struct *proc;

    if (nr_process >= MAX_PROCESS)
    {
        goto fork_out;
    }
    ret = -E_NO_MEM;

    // 1. 分配 PCB 并记录父进程。
    if ((proc = alloc_proc()) == NULL)
    {
        goto fork_out;
    }
    proc->parent = current;

    // 2. 分配内核栈。
    if (setup_kstack(proc) != 0)
    {
        goto bad_fork_cleanup_proc;
    }
    // 3. 地址空间处理：本实验为内核线程，共享内核地址空间。
    if (copy_mm(clone_flags, proc) != 0)
    {
        goto bad_fork_cleanup_kstack;
    }
    // 4. 构造新线程的中断帧和首次切换使用的上下文。
    copy_thread(proc, stack, tf);

    // 5. pid 分配、哈希表/链表挂接和计数必须作为一个整体完成。
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        proc->pid = get_pid();
        hash_proc(proc);
        list_add(&proc_list, &(proc->list_link));
        nr_process++;
    }
    local_intr_restore(intr_flag);

    // 6. 资源、现场、身份都准备好之后才置为就绪态。
    wakeup_proc(proc);

    // 7. 返回新线程的 pid。
    ret = proc->pid;

fork_out:
    return ret;

bad_fork_cleanup_kstack:
    put_kstack(proc);
bad_fork_cleanup_proc:
    kfree(proc);
    goto fork_out;
}

// copy_thread - 在新线程内核栈上安放中断帧，并设置首次切换的上下文
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf)
{
    // 在新线程自己的内核栈顶为中断帧留出空间，并把模板中断帧复制过去。
    proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1;
    *(proc->tf) = *tf;

    // a0 = 0：从 fork 的角度看，新线程的返回值为 0。
    proc->tf->gpr.a0 = 0;
    // 内核线程（esp == 0）首次运行的 sp 指向自己的中断帧；
    // 若调用者给出了栈（如用户进程 fork），则沿用该栈。
    proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;

    // switch_to 恢复该上下文后进入 forkret，再经 forkrets 接上中断帧恢复链。
    proc->context.ra = (uintptr_t)forkret;
    proc->context.sp = (uintptr_t)(proc->tf);
}

// copy_mm - 本阶段只维护地址空间接口：内核线程共享内核地址空间
static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    // 当前创建的都是内核线程，current->mm 本来就是 NULL。
    assert(current->mm == NULL);
    proc->mm = NULL;
    return 0;
}


//LAB4 function3 2411033
void cpu_idle(void)
{
    while (1)
    {
        if (current->need_resched)
        {
            schedule();
        }
    }
}
void proc_run(struct proc_struct *proc)
{
    if (proc != current)
    {
        bool intr_flag;
        local_intr_save(intr_flag);

        // 保留旧线程，稍后将它的寄存器现场保存到 context。
        struct proc_struct *prev = current;

        // 更新当前线程指针。
        current = proc;

        // pgdir 是页表根的物理地址。
        // RV64 satp：高 4 位为模式，低位保存页表根的物理页号。
        uintptr_t satp_value =
            ((uintptr_t)SATP_MODE_SV39 << 60) |
            (proc->pgdir >> RISCV_PGSHIFT);

        write_csr(satp, satp_value);

        // 切换页表后，清除旧的地址翻译缓存。
        asm volatile("sfence.vma" ::: "memory");

        // 保存旧线程的 context，恢复目标线程的 context。
        switch_to(&prev->context, &proc->context);

        local_intr_restore(intr_flag);
    }
}