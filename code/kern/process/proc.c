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
#include <unistd.h>

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

// 模块二（B）：用户程序入口线程与 ELF 加载。
static int user_main(void *arg);
static int load_icode(unsigned char *binary, size_t size);
int kernel_execve(const char *name, const unsigned char *binary, size_t size);

// copy_mm/do_execve 位于这两个页表辅助函数之前，需要前置声明。
static int setup_pgdir(struct mm_struct *mm);
static void put_pgdir(struct mm_struct *mm);

//lab4 请补充你在lab4中的代码

static int
get_pid(void);
static void
forkret(void);
static void
hash_proc(struct proc_struct *proc);
static int
setup_kstack(struct proc_struct *proc);
static void
put_kstack(struct proc_struct *proc);
static void
copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);
static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc);
static void set_links(struct proc_struct *proc);
int do_exit(int error_code)
{
    panic("process exit!!.\n");
}

static int
init_main(void *arg)
{
    cprintf("this initproc, pid = %d, name = \"%s\"\n", current->pid, get_proc_name(current));
    cprintf("To U: \"%s\".\n", (const char *)arg);

    // 记录进入用户态之前的空闲物理页和内核堆用量，退出后核对全部归还。
    size_t nr_free_pages_store = nr_free_pages();
    size_t kernel_allocated_store = kallocated();
    // SLOB 的 arena 页只增不减，先把当前占用记录下来，最后从“空闲页恢复”中单独扣除。
    size_t slob_pages_store = slob_arena_pages();

    // 创建唯一的用户程序入口线程：user_main 随后通过 kernel_execve 进入用户态。
    int pid = kernel_thread(user_main, NULL, 0);
    if (pid <= 0)
    {
        panic("create user_main failed.\n");
    }
    struct proc_struct *proc = find_proc(pid);
    set_proc_name(proc, "user_main");

    // 等待 user_main 运行完用户程序并退出，回收其 PCB 与内核栈。
    do_wait(pid, NULL);

    // 所有用户进程退出后，进程树、链表与进程计数应只留下 initproc。
    cprintf("all user-mode processes have quit.\n");
    assert(initproc->cptr == NULL && initproc->yptr == NULL && initproc->optr == NULL);
    assert(nr_process == 2);
    assert(list_next(&proc_list) == &(initproc->list_link));
    assert(list_prev(&proc_list) == &(initproc->list_link));

    // 用户进程释放后，除 SLOB arena 保留页外，所有物理页都应回到空闲池。
    // 这样仍能发现用户映射、页表或内核栈的真实泄漏，同时不与 SLOB 的
    // “只增不减”行为冲突（该行为是 ucore 上游已知问题）。
    assert(nr_free_pages() + (slob_arena_pages() - slob_pages_store) ==
           nr_free_pages_store);
    assert(kernel_allocated_store == kallocated());
    cprintf("init check memory pass.\n");
    return 0;
}

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
        proc->exit_code = 0;
        proc->wait_state = 0;
        proc->cptr = NULL;
        proc->yptr = NULL;
        proc->optr = NULL;
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
        set_links(proc);
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

static int
copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    struct mm_struct *mm, *oldmm = current->mm;

    // 没有用户地址空间（内核线程）：子线程也不使用用户地址空间。
    if (oldmm == NULL)
    {
        proc->mm = NULL;
        return 0;
    }

    // CLONE_VM：与父进程共享地址空间，只增加 mm 的引用计数。
    // 父子看到的是同一套页表，退出时由最后一个使用者释放。
    if (clone_flags & CLONE_VM)
    {
        lock_mm(oldmm);
        {
            mm_count_inc(oldmm);
        }
        unlock_mm(oldmm);
        proc->mm = oldmm;
        proc->pgdir = current->pgdir;
        return 0;
    }

    // 普通 fork：为子进程建立独立的 mm 和页表，并复制父进程的所有 VMA。
    int ret = -E_NO_MEM;
    if ((mm = mm_create()) == NULL)
    {
        return -E_NO_MEM;
    }

    lock_mm(oldmm);
    {
        if ((ret = setup_pgdir(mm)) != 0)
        {
            unlock_mm(oldmm);
            mm_destroy(mm);
            return ret;
        }
        // dup_mmap 内部通过 copy_range 逐个物理页复制，父子可写数据相互独立。
        if ((ret = dup_mmap(mm, oldmm)) != 0)
        {
            unlock_mm(oldmm);
            goto bad_mm;
        }
    }
    unlock_mm(oldmm);

    // 新地址空间只由当前新进程持有。
    set_mm_count(mm, 1);
    proc->mm = mm;
    // proc->pgdir 保存页表根的物理地址，proc_run 用它写入 satp。
    proc->pgdir = PADDR(mm->pgdir);
    return 0;

bad_mm:
    // 复制中途失败：回收已经建立的部分映射和页表。
    exit_mmap(mm);
    put_pgdir(mm);
    mm_destroy(mm);
    return ret;
}

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

//lab5 function2 2412102 update alloc_proc


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

// set_links - set the relation links of process
static void
set_links(struct proc_struct *proc)
{
    list_add(&proc_list, &(proc->list_link));
    proc->yptr = NULL;
    if ((proc->optr = proc->parent->cptr) != NULL)
    {
        proc->optr->yptr = proc;
    }
    proc->parent->cptr = proc;
    nr_process++;
}

// remove_links - clean the relation links of process
static void
remove_links(struct proc_struct *proc)
{
    list_del(&(proc->list_link));
    if (proc->optr != NULL)
    {
        proc->optr->yptr = proc->yptr;
    }
    if (proc->yptr != NULL)
    {
        proc->yptr->optr = proc->optr;
    }
    else
    {
        proc->parent->cptr = proc->optr;
    }
    nr_process--;
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

// unhash_proc - delete proc from proc hash_list
static void
unhash_proc(struct proc_struct *proc)
{
    list_del(&(proc->hash_link));
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

//lab5 function2 2412102 update kernel_thread


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

// setup_pgdir - alloc one page as PDT
static int
setup_pgdir(struct mm_struct *mm)
{
    struct Page *page;
    if ((page = alloc_page()) == NULL)
    {
        return -E_NO_MEM;
    }
    pde_t *pgdir = page2kva(page);
    memcpy(pgdir, boot_pgdir_va, PGSIZE);

    mm->pgdir = pgdir;
    return 0;
}

// put_pgdir - free the memory space of PDT
static void
put_pgdir(struct mm_struct *mm)
{
    free_page(kva2page(mm->pgdir));
}

//lab5 function3 2412102 update copy_mm（实现见上方 copy_mm）


//lab5 function2 2412102
// do_execve - 用内存中的 ELF 映像替换当前进程的用户地址空间。
// KERNEL_EXECVE（内核线程首次进入用户态）与用户态 sys_exec 都最终走这里。
int
do_execve(const char *name, size_t len, unsigned char *binary, size_t size)
{
    struct mm_struct *oldmm = current->mm;

    // 基本参数检查：binary 必须指向一段足以容纳 ELF 头的数据。
    if (binary == NULL || size < sizeof(struct elfhdr))
    {
        return -E_INVAL;
    }

    // 调用者仍持有用户地址空间时，name/binary 是用户指针，先验证可读。
    // 内核线程调用（current->mm == NULL）时二者都位于内核镜像中。
    if (oldmm != NULL)
    {
        if (name != NULL && len != 0 &&
            !user_mem_check(oldmm, (uintptr_t)name, len, 0))
        {
            return -E_INVAL;
        }
        if (!user_mem_check(oldmm, (uintptr_t)binary, size, 0))
        {
            return -E_INVAL;
        }
    }

    // 先把进程名复制到内核栈，避免旧地址空间被替换后 name 指针失效。
    char local_name[PROC_NAME_LEN + 1];
    memset(local_name, 0, sizeof(local_name));
    if (name != NULL)
    {
        size_t copy_len = (len > PROC_NAME_LEN) ? PROC_NAME_LEN : len;
        memcpy(local_name, name, copy_len);
    }

    // 先建立并切换到新的用户地址空间；此时旧页表仍然有效，
    // load_icode 可以直接从 binary（可能位于旧用户空间）读取 ELF。
    int ret = load_icode(binary, size);
    if (ret != 0)
    {
        // 加载失败：终止当前进程，避免带着半成品地址空间返回用户态。
        do_exit(ret);
        panic("do_execve: load_icode failed: %d.\n", ret);
    }
    set_proc_name(current, local_name);

    // load_icode 已把 satp 切换到新页表，现在可以安全回收旧地址空间。
    if (oldmm != NULL && oldmm != current->mm)
    {
        if (mm_count_dec(oldmm) == 0)
        {
            exit_mmap(oldmm);
            put_pgdir(oldmm);
            mm_destroy(oldmm);
        }
    }
    return 0;
}

// load_icode - 解析 ELF 映像，建立新的 mm、页表和用户栈，并设置用户入口现场。
// 成功时把 satp 切换到新地址空间；失败时完整回收已建立的部分。
static int
load_icode(unsigned char *binary, size_t size)
{
    if (current->tf == NULL)
    {
        panic("load_icode: current->tf is NULL.\n");
    }

    struct elfhdr *elf = (struct elfhdr *)binary;
    if (size < sizeof(struct elfhdr) || elf->e_magic != ELF_MAGIC)
    {
        return -E_INVAL_ELF;
    }
    if (elf->e_phoff == 0 || elf->e_phnum == 0 ||
        elf->e_phoff + (size_t)elf->e_phnum * sizeof(struct proghdr) > size)
    {
        return -E_INVAL_ELF;
    }

    int ret = -E_NO_MEM;
    struct mm_struct *mm = mm_create();
    if (mm == NULL)
    {
        return -E_NO_MEM;
    }

    lock_mm(mm);
    if (setup_pgdir(mm) != 0)
    {
        unlock_mm(mm);
        mm_destroy(mm);
        return -E_NO_MEM;
    }

    // 1) 逐个装载可执行段：建立 VMA，分配物理页，复制文件内容并清零 BSS。
    struct proghdr *ph = (struct proghdr *)(binary + elf->e_phoff);
    uint32_t i;
    for (i = 0; i < elf->e_phnum; i++, ph++)
    {
        if (ph->p_type != ELF_PT_LOAD || ph->p_memsz == 0)
        {
            continue;
        }
        if (ph->p_filesz > ph->p_memsz ||
            ph->p_offset + ph->p_filesz > size ||
            !USER_ACCESS(ph->p_va, ph->p_va + ph->p_memsz))
        {
            ret = -E_INVAL_ELF;
            goto bad_elf;
        }

        // 段权限：VMA 标志用于 user_mem_check，PTE 权限用于硬件页表。
        uint32_t vm_flags = 0, perm = PTE_U;
        if (ph->p_flags & ELF_PF_R)
        {
            vm_flags |= VM_READ;
            perm |= PTE_R;
        }
        if (ph->p_flags & ELF_PF_W)
        {
            vm_flags |= VM_WRITE;
            perm |= PTE_W;
        }
        if (ph->p_flags & ELF_PF_X)
        {
            vm_flags |= VM_EXEC;
            perm |= PTE_X;
        }

        if ((ret = mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL)) != 0)
        {
            goto bad_elf;
        }

        uintptr_t seg_start = ROUNDDOWN(ph->p_va, PGSIZE);
        uintptr_t seg_end = ROUNDUP(ph->p_va + ph->p_memsz, PGSIZE);
        uintptr_t file_end = ph->p_va + ph->p_filesz;

        for (uintptr_t la = seg_start; la < seg_end; la += PGSIZE)
        {
            struct Page *page = pgdir_alloc_page(mm->pgdir, la, perm);
            if (page == NULL)
            {
                ret = -E_NO_MEM;
                goto bad_elf;
            }
            char *kva = (char *)page2kva(page);
            // 整页清零：p_filesz 之外的 BSS 区域必须为 0。
            memset(kva, 0, PGSIZE);

            // 计算本页中属于文件内容的那一段并复制。
            uintptr_t copy_begin = (la > ph->p_va) ? la : ph->p_va;
            uintptr_t copy_end = (la + PGSIZE < file_end) ? (la + PGSIZE) : file_end;
            if (copy_begin < copy_end)
            {
                memcpy(kva + (copy_begin - la),
                       binary + ph->p_offset + (copy_begin - ph->p_va),
                       copy_end - copy_begin);
            }
        }
    }

    // 2) 建立用户栈的 VMA，并实际映射整个用户栈区域。
    // mm_map 把最低一页作为栈保护页，user_mem_check 会拒绝访问它。
    if ((ret = mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE,
                      VM_READ | VM_WRITE | VM_STACK, NULL)) != 0)
    {
        goto bad_elf;
    }
    for (i = 0; i < USTACKPAGE; i++)
    {
        uintptr_t la = USTACKTOP - (i + 1) * PGSIZE;
        struct Page *page = pgdir_alloc_page(mm->pgdir, la, PTE_U | PTE_R | PTE_W);
        if (page == NULL)
        {
            ret = -E_NO_MEM;
            goto bad_elf;
        }
        memset(page2kva(page), 0, PGSIZE);
    }

    // 3) 地址空间建立完毕，交给当前进程并切换 satp。
    set_mm_count(mm, 1);
    current->mm = mm;
    current->pgdir = PADDR(mm->pgdir);
    unlock_mm(mm);

    // 4) 设置首次进入用户态的现场：用户栈顶、ELF 入口、SPP=0、SPIE=1、SIE=0。
    struct trapframe *tf = current->tf;
    tf->gpr.sp = USTACKTOP;
    tf->gpr.a0 = 0;
    tf->epc = elf->e_entry;
    tf->status = (read_csr(sstatus) & ~(SSTATUS_SPP | SSTATUS_SIE)) | SSTATUS_SPIE;

    uintptr_t satp_value =
        ((uintptr_t)SATP_MODE_SV39 << 60) | (current->pgdir >> RISCV_PGSHIFT);
    write_csr(satp, satp_value);
    asm volatile("sfence.vma" ::: "memory");
    return 0;

bad_elf:
    unlock_mm(mm);
    // mm_count 仍为 0，按 VMA 范围撤销映射并释放页表根和 mm。
    exit_mmap(mm);
    put_pgdir(mm);
    mm_destroy(mm);
    return ret;
}

// do_wait - 等待指定（pid != 0）或任意（pid == 0）子进程退出，
// 取得退出码并回收僵尸进程的内核栈与 PCB。
int
do_wait(int pid, int *code_store)
{
    struct mm_struct *mm = current->mm;

    // 退出码写入位置必须是可写的合法用户地址（NULL 表示不接收）。
    if (code_store != NULL &&
        !user_mem_check(mm, (uintptr_t)code_store, sizeof(int), 1))
    {
        return -E_INVAL;
    }

    bool intr_flag, haskid;
    struct proc_struct *proc;
    list_entry_t *le, *list = &proc_list;
repeat:
    haskid = 0;

    if (pid != 0)
    {
        // 等待指定 pid 的子进程。
        proc = find_proc(pid);
        if (proc != NULL && proc->parent == current)
        {
            haskid = 1;
            if (proc->state == PROC_ZOMBIE)
            {
                goto found;
            }
        }
    }
    else
    {
        // 等待任意一个已经退出的子进程。
        le = list;
        while ((le = list_next(le)) != list)
        {
            proc = le2proc(le, list_link);
            if (proc->parent != current)
            {
                continue;
            }
            haskid = 1;
            if (proc->state == PROC_ZOMBIE)
            {
                goto found;
            }
        }
    }

    if (haskid)
    {
        // 有子进程但尚未退出：睡眠直到子进程退出唤醒或自身被终止。
        current->state = PROC_SLEEPING;
        current->wait_state = WT_CHILD;
        schedule();
        if (current->flags & PF_EXITING)
        {
            do_exit(-E_KILLED);
        }
        goto repeat;
    }
    return -E_BAD_PROC;

found:
    if (proc == idleproc || proc == initproc)
    {
        panic("do_wait: can not wait idleproc or initproc.\n");
    }

    // 交付退出码；目标进程此时仍持有自己的用户地址空间。
    if (code_store != NULL &&
        !copy_to_user(mm, code_store, &proc->exit_code, sizeof(int)))
    {
        return -E_INVAL;
    }

    // 僵尸进程不再被查找或调度，摘除哈希/链表后回收内核栈和 PCB。
    local_intr_save(intr_flag);
    {
        unhash_proc(proc);
        remove_links(proc);
    }
    local_intr_restore(intr_flag);

    put_kstack(proc);
    kfree(proc);
    return 0;
}


//lab5 function3 2412102（copy_mm 已在上方实现）


//lab5 function4 YOUR CODE


#define __KERNEL_EXECVE(name, binary, size) ({           \
    cprintf("kernel_execve: pid = %d, name = \"%s\".\n", \
            current->pid, name);                         \
    kernel_execve(name, binary, (size_t)(size));         \
})

#define KERNEL_EXECVE(x) ({                                    \
    extern unsigned char _binary_obj___user_##x##_out_start[], \
        _binary_obj___user_##x##_out_size[];                   \
    __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,    \
                    _binary_obj___user_##x##_out_size);        \
})

#define __KERNEL_EXECVE2(x, xstart, xsize) ({   \
    extern unsigned char xstart[], xsize[];     \
    __KERNEL_EXECVE(#x, xstart, (size_t)xsize); \
})

#define KERNEL_EXECVE2(x, xstart, xsize) __KERNEL_EXECVE2(x, xstart, xsize)


//lab5 function2 2412102
// user_main - 内核过渡线程入口：装载并运行用户程序。
// 编译时带 TEST 宏则运行指定的测试程序，否则默认运行 exit。
static int
user_main(void *arg)
{
    (void)arg;
#ifdef TEST
    KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
#else
    KERNEL_EXECVE(exit);
#endif
    panic("user_main execve failed.\n");
}

// kernel_execve - 构造返回用户态的中断帧，真正完成 S 态到 U 态的切换。
// 仅调用 do_execve 只完成地址空间替换；必须经由 forkrets/sret 才能进入用户程序。
int
kernel_execve(const char *name, const unsigned char *binary, size_t size)
{
    struct trapframe *tf = current->tf;
    if (tf == NULL)
    {
        panic("kernel_execve: current->tf is NULL.\n");
    }

    // 清空内核线程的初始现场，避免把内核寄存器内容带进用户态。
    memset(tf, 0, sizeof(struct trapframe));

    int ret = do_execve(name, strlen(name), (unsigned char *)binary, size);
    if (ret != 0)
    {
        return ret;
    }

    // load_icode 已切换到新进程页表，并设置好 tf->epc / tf->gpr.sp / tf->status。
    // forkrets 以 tf 为栈执行 __trapret，最后由 sret 返回用户态。
    forkrets(tf);

    // forkrets 不会返回。
    return 0;
}


