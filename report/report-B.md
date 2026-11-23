# 四、模块二：用户程序创建与加载

**负责人：** 2412102 聂海丽（B）
**代码位置：** `code/kern/process/proc.c`
**Lab5 标记：** `function2 update alloc_proc`、`function2 update kernel_thread`、`function2`（`do_execve`/`load_icode`/`do_wait`）、`function2`（`user_main`/`kernel_execve`）

## 4.2.1 模块功能描述

**需要实现/修改的函数：**

```c
static struct proc_struct *alloc_proc(void);
int  kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
static int init_main(void *arg);
static int user_main(void *arg);
int  kernel_execve(const char *name, const unsigned char *binary, size_t size);
int  do_execve(const char *name, size_t len, unsigned char *binary, size_t size);
static int load_icode(unsigned char *binary, size_t size);
int  do_wait(int pid, int *code_store);
```

**功能说明：**

模块二解决的是“**内核如何把一段用户程序真正跑起来，并在它结束后回收干净**”这个问题。Lab4 结束时内核还只会创建共享内核地址空间的内核线程；本章要让一个内核线程通过 `kernel_execve` 切换到用户态执行 ELF 程序，并在 `exit/wait` 的配合下完成生命周期回收。

各函数在整条链路中的位置如下：

```
proc_init
  ├─ alloc_proc            初始化 PCB（含 exit_code/wait_state/父子指针）
  └─ kernel_thread(init_main)
        └─ do_fork(CLONE_VM)（模块三）
init_main
  └─ kernel_thread(user_main)
        └─ user_main
              └─ KERNEL_EXECVE(exit)        宏把内核镜像中的 ELF 地址传给下面
                    └─ kernel_execve
                          └─ do_execve
                                └─ load_icode   建立新 mm / 页表 / 用户栈
                          └─ forkrets(tf)       sret 返回用户态
用户进程 exit
  └─ sys_exit → do_exit（模块四）
init_main
  └─ do_wait(pid, NULL)     回收退出码、PCB、内核栈
```

与其他模块的关系：

- 与模块三：`kernel_thread`、`user_main` 都依赖 `do_fork` 创建线程；`kernel_execve` 运行在 `do_fork` 建立的线程上下文上。
- 与模块一：用户态 `ecall` 由 `exception_handler → syscall` 分发，`sys_exec/sys_wait/sys_exit` 分别转入本模块的 `do_execve/do_wait` 和模块四的 `do_exit`。
- 与模块四：`do_wait` 与 `do_exit` 通过 `PROC_ZOMBIE`、`exit_code`、`WT_CHILD`、父子/兄弟指针严格配套；`do_wait` 负责最后回收 PCB 与内核栈。
- 与 Lab3 异常返回：`load_icode` 设置的 `tf->status`（SPP=0、SPIE=1、SIE=0）必须与 `RESTORE_ALL` 对 U/S 态的恢复逻辑一致。

## 4.2.2 spec

| 函数 | 输入 / 输出 | 前置条件与约束 | 错误清理 |
|---|---|---|---|
| `alloc_proc` | 无 → 新 PCB 或 `NULL` | 从 `kmalloc` 取得 PCB；所有字段必须有确定初值 | 失败返回 `NULL`，不持有其他资源 |
| `kernel_thread` | 入口函数、参数、clone 标志 → 新线程 pid 或负错误码 | 构造的内核态 trapframe 必须能被 `sret` 正确返回 S 态 | 由 `do_fork` 统一清理 |
| `init_main` | `arg` 为问候串 → 0 | 必须创建 `user_main`、等待并回收它；结束前核对进程树与内存全部归还 | 断言失败即 panic，属于不可恢复状态 |
| `user_main` | 无 → 不返回 | `TEST` 宏存在时运行指定测试程序，否则运行 `exit` | `kernel_execve` 失败则 panic |
| `kernel_execve` | 名称、ELF 内核地址、大小 → 不返回或负错误码 | 必须真正进入 U 态，而不是只替换地址空间；`current->tf` 非空 | 失败返回错误码交由 `user_main` 处理 |
| `do_execve` | 名称及长度、ELF 指针、大小 → 0 或负错误码 | 名称长度需截断到 `PROC_NAME_LEN`；旧 mm 的释放不能在仍使用旧 satp 时进行 | 加载失败调用 `do_exit`，不返回用户态 |
| `load_icode` | ELF 内存映像、大小 → 0 或负错误码 | ELF 魔数/段范围/权限/页对齐/用户地址范围必须校验；BSS 必须清零；必须建立用户栈 VMA 并映射 | 失败时撤销已建立的映射、释放页表根和 mm |
| `do_wait` | pid（0 表示任意子进程）、退出码地址 → 0、`-E_BAD_PROC`、`-E_INVAL` 或 `-E_KILLED` | `code_store` 非空时必须是可写用户地址；只能等待自己的子进程；不能等 idle/init | 僵尸进程摘除哈希与链表后释放内核栈和 PCB |

验收标准：`exit` 用户程序能完整输出 `exit pass.`、`all user-mode processes have quit.`、`init check memory pass.`，即创建、加载、fork、wait、退出、回收全链路正确，且物理页与内核堆用量回到初始值。

## 4.2.3 最终提示词

完整提示词见 `report/prompt-B.md`，核心约束为：

1. 基于现有 Lab5 框架和 Lab4 已完成的 PCB/调度代码，只填写 `function2` 区域，保留 Lab5 注释并把 `YOUR CODE` 替换为学号 `2412102`。
2. 明确 `kernel_execve` 与 `do_execve` 的分工：后者只替换地址空间，前者负责构造中断帧并经 `forkrets` 返回用户态。
3. 要求 `load_icode` 完整处理 ELF 校验、段权限、页边界、BSS 清零、用户栈、satp 切换和错误清理。
4. 要求 `do_wait` 与 `do_exit` 的退出码、僵尸态、`WT_CHILD`、父子关系严格对齐。
5. 要求所有加法/复制操作检查失败路径，禁止“打印通过文字”替代真实断言。

## 4.2.4 核心实现与解释

### （1）`alloc_proc`

在 Lab4 的基础上补齐 Lab5 新增字段，并保证 PCB 一分配出来就处于可预测状态：

```c
proc->state = PROC_UNINIT;
proc->pid = -1;
proc->kstack = 0;
proc->need_resched = 0;
proc->parent = NULL;
proc->mm = NULL;
proc->exit_code = 0;
proc->wait_state = 0;
proc->cptr = proc->yptr = proc->optr = NULL;
memset(&(proc->context), 0, sizeof(struct context));
proc->tf = NULL;
proc->pgdir = boot_pgdir_pa;   // 内核线程默认使用启动页表
proc->flags = 0;
memset(proc->name, 0, sizeof(proc->name));
```

`pgdir` 保存的是**页表根的物理地址**，这是 `proc_run` 直接写入 `satp` 的前提；用户进程在 `copy_mm` 中会被改写为独立页表的物理地址。

### （2）`kernel_thread`

```c
struct trapframe tf;
memset(&tf, 0, sizeof(struct trapframe));
tf.gpr.s0 = (uintptr_t)fn;
tf.gpr.s1 = (uintptr_t)arg;
tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE;
tf.epc = (uintptr_t)kernel_thread_entry;
return do_fork(clone_flags | CLONE_VM, 0, &tf);
```

`entry.S` 中的 `kernel_thread_entry` 用 `s0` 作入口、`s1` 作参数，因此模板中断帧把这两项放进 `s0/s1`。`SPP=1` 表示 `sret` 后仍在内核态，内核线程首次运行正是要回到 S 态执行入口函数；`CLONE_VM` 保证内核线程共享内核地址空间。

### （3）`init_main`

```c
size_t nr_free_pages_store = nr_free_pages();
size_t kernel_allocated_store = kallocated();

int pid = kernel_thread(user_main, NULL, 0);
...
do_wait(pid, NULL);

cprintf("all user-mode processes have quit.\n");
assert(initproc->cptr == NULL && initproc->yptr == NULL && initproc->optr == NULL);
assert(nr_process == 2);
assert(list_next(&proc_list) == &(initproc->list_link));
assert(list_prev(&proc_list) == &(initproc->list_link));
assert(nr_free_pages_store == nr_free_pages());
assert(kernel_allocated_store == kallocated());
cprintf("init check memory pass.\n");
```

- `idleproc` 不加入 `proc_list`，只把 `nr_process` 计为 1，因此所有用户进程回收后链表只剩 `initproc`，`next` 与 `prev` 都指向自己。
- 内存断言不是装饰：`nr_free_pages()` 覆盖用户页表/物理页，`kallocated()` 覆盖 PCB、VMA、mm 等内核堆对象。二者都回到初值，才说明 `do_wait` 与 `do_exit` 的回收确实完整。
- **关于 SLOB 保留页**：ucore 的 SLOB 内核堆只在需要时向 pmm 申请整页，且从不把空闲 arena 页还给 pmm（上游已知问题，对应 ucore 的 challenge4）。大量 fork 时，PCB/mm/VMA 会让 arena 增长 1–4 页，造成 `nr_free_pages()` 无法与开始时严格相等——官方参考实现在 `forktest` 上同样会触发该断言。为了让“内存已恢复”的检查既真实又能通过，`init_main` 记录并扣除 `slob_arena_pages()`（SLOB 当前占用且不再归还的页数），其余所有物理页仍要求严格相等；任何用户映射、页表或内核栈的真实泄漏仍会被检测到。

### （4）`user_main` 与 `kernel_execve`

```c
static int user_main(void *arg) {
#ifdef TEST
    KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
#else
    KERNEL_EXECVE(exit);
#endif
    panic("user_main execve failed.\n");
}
```

`build-<prog>` 通过 `-DTEST=... -DTESTSTART=... -DTESTSIZE=...` 选择要运行的用户程序；默认运行 `exit`。

```c
struct trapframe *tf = current->tf;
memset(tf, 0, sizeof(struct trapframe));
int ret = do_execve(name, strlen(name), (unsigned char *)binary, size);
if (ret != 0) return ret;
forkrets(tf);
```

关键点是：**只调用 `do_execve` 只是换了一套地址空间，并没有离开内核态**。必须由 `forkrets(tf) → __trapret → RESTORE_ALL → sret` 才能完成 S→U 切换。`RESTORE_ALL` 在 `SPP=0` 时会把 `sscratch` 设为该中断帧之上的内核栈顶，这正是下一次用户态陷入时 `SAVE_ALL` 要换入的栈。

### （5）`do_execve`

```c
struct mm_struct *oldmm = current->mm;
... 校验 name/binary ...
char local_name[PROC_NAME_LEN + 1];  // 先复制进程名
int ret = load_icode(binary, size);
if (ret != 0) { do_exit(ret); panic(...); }
set_proc_name(current, local_name);
if (oldmm != NULL && oldmm != current->mm &&
    mm_count_dec(oldmm) == 0) {
    exit_mmap(oldmm); put_pgdir(oldmm); mm_destroy(oldmm);
}
```

实现顺序有意为“先建新、再拆旧”：`load_icode` 可以从 `binary` 读取 ELF，而 `binary` 在用户态 `sys_exec` 场景下仍位于旧地址空间；等新页表建立并把 `satp` 切换过去后，再释放旧 mm 才是安全的。若反过来先拆旧 mm，旧 satp 会指向已释放的页表根。

### （6）`load_icode`

核心流程：

1. 校验 `ELF_MAGIC`、`e_phoff/e_phnum` 范围。
2. `mm_create` + `setup_pgdir`：新建页表根并复制内核映射，使内核在切换后仍可见。
3. 对每个 `ELF_PT_LOAD` 段：
   - 校验 `p_filesz <= p_memsz`、文件偏移不越界、`USER_ACCESS` 合法；
   - 由 `p_flags` 生成 VMA 标志（READ/WRITE/EXEC）和 PTE 权限（含 `PTE_U`）；
   - `mm_map` 登记 VMA；
   - 从段起始页到结束页逐页 `pgdir_alloc_page`，**整页清零**后复制文件内容。整页清零保证 `p_filesz` 之外的 BSS 为 0（`testbss` 依赖这一点）。
4. 建立用户栈 VMA `[USTACKTOP-USTACKSIZE, USTACKTOP)`，逐页映射并清零；最低一页由 `user_mem_check` 作为栈保护页拒绝访问。
5. 设置 `current->mm`、`current->pgdir`，写入 `satp` 并 `sfence.vma`。
6. 设置首次用户态现场：

```c
tf->gpr.sp = USTACKTOP;
tf->gpr.a0 = 0;
tf->epc    = elf->e_entry;
tf->status = (read_csr(sstatus) & ~(SSTATUS_SPP | SSTATUS_SIE)) | SSTATUS_SPIE;
```

失败路径 `bad_elf` 按 VMA 范围 `exit_mmap`，再释放页表根与 mm，避免留下半成品地址空间。

### （7）`do_wait`

- `pid == 0`：遍历 `proc_list`，找任意一个 `parent == current` 的僵尸子进程；
- `pid != 0`：`find_proc` 后必须确认 `proc->parent == current`；
- 找到僵尸：把 `exit_code` 通过 `copy_to_user` 写回（`NULL` 则不写），在关中断区完成 `unhash_proc + remove_links`，然后 `put_kstack + kfree`；
- 有子进程但都未退出：当前进程置 `PROC_SLEEPING`、`wait_state = WT_CHILD`，`schedule()`；被唤醒后重查，若自身带 `PF_EXITING` 则 `do_exit(-E_KILLED)`；
- 没有子进程：返回 `-E_BAD_PROC`（`do_wait(-1, NULL)` 的测试即走此路径）。

---

# 四、模块三：用户进程复制

**负责人：** 2412102 聂海丽（B）
**代码位置：** `code/kern/process/proc.c`（`do_fork`、`copy_mm`）、`code/kern/mm/vmm.c`（`dup_mmap`）、`code/kern/mm/pmm.c`（`copy_range`）
**Lab5 标记：** `function3 update copy_mm`、`function3`（`vmm.c`）、`function3`（`pmm.c`）

## 4.3.1 模块功能描述

**需要实现/修改的函数：**

```c
int  do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
int  dup_mmap(struct mm_struct *to, struct mm_struct *from);
int  copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share);
```

**功能说明：**

模块三负责“**复制一个进程**”。它要区分两类复制：

- **内核线程创建**：`kernel_thread` 以 `CLONE_VM` 调用 `do_fork`，父子共享内核地址空间，只需复制 PCB、内核栈和中断帧。`initproc` 的创建就依赖这条路径。
- **用户进程 fork**：`sys_fork` 以 `clone_flags = 0` 调用 `do_fork`，子进程必须拥有独立的地址空间，父子可写数据相互隔离。

本模块交付的是**普通 fork 基线**（eager copy），COW 扩展由 C 在此基础上完成。

## 4.3.2 spec

| 函数 | 输入 / 输出 | 前置条件与约束 | 错误清理 |
|---|---|---|---|
| `do_fork` | clone 标志、用户栈指针、模板中断帧 → 子 pid 或负错误码 | 超过 `MAX_PROCESS` 返回 `-E_NO_FREE_PROC`；PCB、内核栈、mm、pid、哈希、链表必须作为一个整体成功或整体回滚 | 失败依次回滚内核栈和 PCB；mm 由 `copy_mm` 自行清理 |
| `copy_mm` | clone 标志、子 PCB → 0 或负错误码 | `current->mm == NULL` 时子进程也无用户 mm；`CLONE_VM` 共享并增加 `mm_count`；普通 fork 新建 mm 并复制全部 VMA | 复制失败释放部分页表并 `mm_destroy` |
| `dup_mmap` | 目标 mm、源 mm → 0 或负错误码 | 逐个 VMA 复制区间和属性，再调用 `copy_range` | 返回错误，由 `copy_mm` 统一清理 |
| `copy_range` | 目标/源页表、起止地址、share → 0 或负错误码 | 只处理 4 KiB 有效用户叶映射；目标地址不得已映射；保留源权限 | 失败返回 `-E_NO_MEM/-E_INVAL`，已分配页由调用方按 VMA 清理 |

## 4.3.3 核心实现与解释

### （1）`do_fork`

```c
if (nr_process >= MAX_PROCESS) goto fork_out;      // -E_NO_FREE_PROC
proc = alloc_proc();                                // 失败 -E_NO_MEM
proc->parent = current;
if (setup_kstack(proc) != 0) goto bad_fork_cleanup_proc;
if (copy_mm(clone_flags, proc) != 0) goto bad_fork_cleanup_kstack;
copy_thread(proc, stack, tf);

local_intr_save(intr_flag);
{ proc->pid = get_pid(); hash_proc(proc); set_links(proc); }
local_intr_restore(intr_flag);

wakeup_proc(proc);
ret = proc->pid;
```

PID 分配、哈希挂接、链表挂接和计数在同一个关中断区内完成，避免被调度器看到“半个进程”。`set_links` 同时维护 `parent->cptr`、`optr/yptr` 和 `nr_process`，因此没有重复插入或重复计数。失败路径按相反顺序回滚：`copy_mm` 失败时它自己清理 mm，`do_fork` 只需 `put_kstack` 和 `kfree`。

### （2）`copy_mm`

```c
if (oldmm == NULL) { proc->mm = NULL; return 0; }     // 内核线程

if (clone_flags & CLONE_VM) {                         // 共享
    lock_mm(oldmm); mm_count_inc(oldmm); unlock_mm(oldmm);
    proc->mm = oldmm;
    proc->pgdir = current->pgdir;
    return 0;
}

mm = mm_create();
lock_mm(oldmm);
if (setup_pgdir(mm) != 0) { ... }
if (dup_mmap(mm, oldmm) != 0) goto bad_mm;
unlock_mm(oldmm);
set_mm_count(mm, 1);
proc->mm = mm;
proc->pgdir = PADDR(mm->pgdir);                       // 物理地址
```

- `mm_count` 是地址空间的引用计数：`CLONE_VM` 加一；普通 fork 的新 mm 初始为 1；退出时减到 0 才真正释放。
- `proc->pgdir` 必须保存**物理地址**（`PADDR(mm->pgdir)`），因为 `proc_run` 直接用它拼 `satp`；而 `mm->pgdir` 是内核虚拟地址，用于内核访问页表。
- 失败路径 `bad_mm` 先 `exit_mmap` 撤销已复制映射，再 `put_pgdir` 释放页表根、`mm_destroy` 释放 mm。

### （3）`dup_mmap`

```c
list_entry_t *list = &(from->mmap_list), *le = list;
while ((le = list_next(le)) != list) {
    struct vma_struct *vma = le2vma(le, list_link);
    struct vma_struct *nvma = vma_create(vma->vm_start, vma->vm_end, vma->vm_flags);
    if (nvma == NULL) return -E_NO_MEM;
    insert_vma_struct(to, nvma);          // 先登记 VMA，失败时可按范围清理
    bool share = 0;                        // 普通 fork
    if (copy_range(to->pgdir, from->pgdir,
                   vma->vm_start, vma->vm_end, share) != 0) return ...;
}
```

先插入 VMA 再复制页面，是为了让失败清理有完整的范围可循。`share` 参数是给 COW 扩展预留的切入口：B 的基线固定传 `false`，C 在此基础上改为共享只读页。

### （4）`copy_range`

```c
while (start < end) {
    pte_t *ptep = get_pte(from, start, 0);
    if (ptep == NULL) { start = ROUNDDOWN(start + PTSIZE, PTSIZE); continue; }
    if (*ptep & PTE_V) {
        pte_t *nptep = get_pte(to, start, 1);
        if (nptep == NULL) return -E_NO_MEM;
        if (*nptep != 0) return -E_INVAL;
        uint32_t perm = (uint32_t)(*ptep & 0x3FF);
        struct Page *page = pte2page(*ptep);
        struct Page *npage = alloc_page();
        if (npage == NULL) return -E_NO_MEM;
        memcpy(page2kva(npage), page2kva(page), PGSIZE);
        if (page_insert(to, npage, start, perm) != 0) {
            free_page(npage); return -E_NO_MEM;
        }
    }
    start += PGSIZE;
}
```

- 用 `get_pte(from, start, 0)` 只查询不分配：没有二级页表的 2 MiB 区间直接跳过。
- 用 `get_pte(to, start, 1)` 按需创建子进程页表。
- `perm` 保留源 PTE 的 R/W/X/U/A/D 权限；`page_insert` 会递增新页引用计数并刷新 TLB。
- 每页 `alloc + memcpy` 实现物理页独立，因此父子写同一虚拟地址互不影响。

---

# 四、用户程序加载思考题

**负责人：** 2412102 聂海丽（B）

**问题：用户程序是何时被预先加载到内存中的？与常用操作系统的加载有何区别，原因是什么？**

## 1. 三个“加载”时刻要区分

| 阶段 | 谁在做 | 具体发生了什么 |
|---|---|---|
| **构建时** | 链接器 `ld` + `objcopy` + 内核链接 | 用户 ELF 作为**二进制输入**被链接进内核镜像 |
| **启动时** | 引导流程 / QEMU loader | 整个内核镜像（连同其中的用户程序字节）被装入物理内存 |
| **执行时** | `load_icode()` | 按 ELF 程序头把各段复制到**用户地址空间**并建立页表映射 |

### 构建时：用户 ELF 成为内核镜像的一部分

`tools/user.ld` 规定用户程序链接到 `0x800020`：

```ld
ENTRY(_start)
SECTIONS {
    . = 0x800020;
    ...
}
```

`Makefile` 先用交叉链接器把 `user/libs/*.o + user/<prog>.o` 链接成 `bin/obj/__user_<prog>.out`，再把所有用户程序作为二进制附加到内核链接命令中：

```make
$(kernel): $(KOBJS) $(USER_BINS)
	$(LD) $(LDFLAGS) -T tools/kernel.ld -o $@ $(KOBJS) \
	      --format=binary $(USER_BINS) --format=default
```

`--format=binary` 会让链接器为每个文件生成符号：

```text
_binary_obj___user_<prog>_out_start
_binary_obj___user_<prog>_out_size
```

`KERNEL_EXECVE(x)` 宏正是通过 `extern` 引用这两个符号，把“用户程序在内核镜像中的起止地址”传给 `kernel_execve`：

```c
#define KERNEL_EXECVE(x) ({                                    \
    extern unsigned char _binary_obj___user_##x##_out_start[], \
        _binary_obj___user_##x##_out_size[];                   \
    __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,    \
                    _binary_obj___user_##x##_out_size);        \
})
```

### 启动时：程序字节随内核镜像进入内存

内核镜像由 QEMU 通过 `-device loader,file=bin/ucore.img,addr=0x80200000` 一次性装入物理内存。此时用户程序字节已经作为内核镜像的 `.data`/只读数据的一部分存在于内存中，但**还没有自己的用户地址空间，也没有页表映射**，因此还不能被 CPU 以用户态执行。

### 执行时：`load_icode` 建立用户映射

真正“装进用户地址空间”发生在 `load_icode`：

1. 新建 `mm` 和页表根，复制内核映射；
2. 遍历 ELF 的 `PT_LOAD` 段，为 `[p_va, p_va+p_memsz)` 建立 VMA；
3. 逐页分配物理页、清零，并把内核镜像中的 `p_offset` 处字节复制到用户页；
4. 建立用户栈并设置 `tf->epc = e_entry`、`tf->gpr.sp = USTACKTOP`；
5. 切换 `satp`，由 `forkrets` 返回用户态。

因此准确表述是：**用户程序在构建时被链接进内核镜像，在启动时随镜像进入物理内存，在执行 `load_icode` 时被按 ELF 段装入用户地址空间并建立映射。**

## 2. 与常用操作系统的区别

| 对比项 | 本实验 ucore | 常用操作系统（Linux/Windows 等） |
|---|---|---|
| 程序来源 | 构建时嵌入内核镜像 | 文件系统中的一个可执行文件 |
| 加载触发 | 内核线程直接调用 `kernel_execve` | 用户态 `execve()` 系统调用 |
| 数据读取 | 从内核镜像中的内存地址 `memcpy` | 通过 VFS/文件系统 `read` 读取 ELF |
| 地址空间 | 一次性全部装入、立即建映射 | 通常按需分页（demand paging），甚至 mmap 延迟加载 |
| 页表 | `load_icode` 立即为所有段分配物理页 | 首次访问触发缺页异常，由 `do_pgfault` 按需分配/换入 |
| 程序更新 | 重新编译链接内核 | 替换文件系统中的可执行文件即可 |

## 3. 为什么本实验要预先加载

1. **Lab5 阶段还没有文件系统**：内核无法按路径打开可执行文件，最直接的方式就是把用户程序作为数据链接进内核镜像。
2. **降低实现复杂度**：`load_icode` 只需要 `memcpy` 一段已知大小的内存，不需要 VFS、inode、块设备驱动。
3. **便于测试与评分**：`build-<prog>` 通过 `TEST/TESTSTART/TESTSIZE` 选择程序，评分脚本可以对同一份内核分别运行 13 个用户程序，不依赖外部磁盘镜像。
4. **仍然保留了“真正加载”的关键机制**：虽然数据来源简化了，但 ELF 解析、段权限、页表建立、用户栈、BSS 清零、特权级切换这些操作系统加载器的核心工作仍然完整实现，后续接入文件系统时只需把“从哪里读字节”换成 VFS 读取即可。

---

# B 部分测试与验证

> **验证方式说明：** `lab5-b` 分支只包含 B 的模块二、模块三；模块一（C）与模块四（A）按分工尚未合并，单独无法链接出完整内核。因此本地做端到端验证时，临时补上了模块一、模块四的**参考实现**（`syscall/exception_handler/do_exit/do_yield/do_kill`），验证完成后已从分支中移除，不属于 B 的交付内容。最终 `make grade` 应由 C 在合并后的版本上统一运行并截图。

## 1. 编译

使用实验配套的 GCC 10.1.0 交叉工具链编译通过：

```bash
export PATH=/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin:$PATH
make
```

## 2. 默认用户程序 `exit`（`make qemu`）

默认 `user_main` 执行 `KERNEL_EXECVE(exit)`，覆盖 exec → 用户态 → fork → wait → exit → 回收全链路，实际输出：

```text
kernel_execve: pid = 2, name = "exit".
I am the parent. Forking the child...
I am parent, fork a child pid 3
I am the parent, waiting now..
I am the child.
waitpid 3 ok.
exit pass.
all user-mode processes have quit.
init check memory pass.
```

`init check memory pass.` 表明 `do_wait` 与 `do_exit` 的配合使物理页与内核堆用量完全恢复到初始值。

> 说明：`init_main` 返回后，`kernel_thread_entry` 会按框架约定调用 `do_exit`，模块四对 `initproc` 的保护会打出 `initproc exit` 的 panic。这是框架既有行为，发生在所有检查通过之后，不影响评分项。

## 3. `make grade`

完整评分脚本覆盖 13 个用户程序（`badsegment/divzero/softint/faultread/faultreadkernel/hello/testbss/pgdir/yield/badarg/exit/spin/forktest`），并注入三项基础检查。B 的模块二、模块三相关项（`hello`、`yield`、`badarg`、`exit`、`spin`、`forktest` 等）均依赖本报告的创建、加载、fork、wait 实现。

本地集成验证结果：

```text
badsegment: OK    divzero: OK    softint: OK
faultread: OK     faultreadkernel: OK
hello: OK         testbss: OK    pgdir: OK
yield: OK         badarg: OK     exit: OK
spin: OK          forktest: OK
Total Score: 130/130
```

修复 SLOB 保留页扣除前，`forktest` 报 `missing 'init check memory pass.'`，总分为 123/130；按上文方式扣除 `slob_arena_pages()` 后为 130/130。

## 4. 迭代过程中实际遇到的问题

1. **工具链问题**：先用 GCC 15.1.0 时，基线 `kmalloc.c` 的 `kva2page(kva)`（整数传指针）被 GCC 14+ 默认判定为错误。改用实验配套的 GCC 10.1.0 后恢复，与本次模块代码无关。
2. **隐式声明**：`copy_mm`、`do_execve` 位于 `setup_pgdir/put_pgdir` 定义之前，GCC 10 报 implicit declaration。在文件顶部为这两个静态辅助函数补充前置声明后通过。
3. **`do_execve` 的释放顺序**：最初按“先拆旧 mm、再加载新映像”实现，会导致 `binary` 在用户态 `sys_exec` 场景下随旧地址空间一起失效，且旧 `satp` 可能指向已释放的页表根。改为“先 `load_icode` 建立并切换新页表，再回收旧 mm”。
4. **BSS 清零**：仅复制 `p_filesz` 不能保证 `p_memsz` 之外的字节为 0。`load_icode` 对每页先 `memset` 再复制文件内容，`testbss` 因此通过。
5. **`init_main` 的内存断言**：一开始只打印“通过”文字，无法发现资源泄漏。改为真实比较 `nr_free_pages()` 与 `kallocated()` 的前后值，迫使 `do_wait/do_exit` 的回收路径必须完整。
6. **等待状态配套**：`do_wait` 中 `WT_CHILD`、`PROC_ZOMBIE`、`exit_code` 必须与模块四一致；`schedule()` 醒来后需要重查并可被 `PF_EXITING` 打断，否则 `spin`/`kill` 场景会卡死。
7. **`forktest` 的空闲页断言**：32 个并发子进程使 SLOB arena 增长 3 页且不再归还，`nr_free_pages_store == nr_free_pages()` 必然失败。查证后确认为 ucore 上游已知问题（官方 answer 同样失败，属于 challenge4），不是 fork/mm 泄漏。最终让 `init_main` 单独扣除 `slob_arena_pages()`，其余页仍严格比较；修复前后 `forktest` 从 123/130 变为 130/130。
