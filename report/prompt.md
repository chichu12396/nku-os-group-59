### 功能模块一：虚拟内存页操作

**负责人：** 2412102-聂海丽
#### 4.1.3 最终提示词（prompt）

以下是本次协作使用的最终提示词（由 spec 整理，实际生成时逐条核对）：

````markdown
[ROLE]
你是 ucore/RISC-V Sv39 实验内核的开发者，熟悉三级页表、PTE 权限位、物理页引用计数和 TLB 失效。

[TASK]
在 code/kern/mm/pmm.c 的 `//LAB4 function1 YOUR CODE` 区域实现 page_insert 和 page_remove。
可以增加 static 辅助函数 page_remove_pte。
只修改这一个区域，不要改动文件里的其他函数、头文件和注释。

[CONTEXT]
- get_pte(pgdir, la, create) 返回叶子 PTE 的内核虚拟地址；create=1 时可能分配中间页表页，失败返回 NULL。
- pte_create(ppn, type) 内部已经置 PTE_V。
- page2ppn(page) 返回页号；pte2page(pte) 只对有效 PTE 安全。
- page_ref_inc/page_ref_dec 返回操作后的引用计数；free_page(page) 在引用计数为 0 时调用。
- tlb_invalidate(pgdir, la) 失效对应地址的 TLB 项。
- -E_NO_MEM 定义在 libs/error.h。

[REQUIREMENTS]
page_insert:
1. 先 get_pte(pgdir, la, 1)；为 NULL 时返回 -E_NO_MEM，且不要增加 page 的引用计数。
2. 成功后 page_ref_inc(page)。
3. 若该地址已有有效 PTE：
   - 若旧页 == page：page_ref_dec(page)，只更新权限，引用计数保持不变；
   - 若旧页 != page：调用 page_remove_pte 撤销旧映射（旧页引用计数减一，归零则释放）。
4. 用赋值覆盖叶子 PTE：*ptep = pte_create(page2ppn(page), perm)，不要用 |=。
5. tlb_invalidate(pgdir, la)；返回 0。

page_remove:
1. 用 get_pte(pgdir, la, 0) 纯查找，不得分配页表。
2. ptep 为 NULL 或 *ptep 无效时直接返回，保证幂等。
3. 有效时调用 page_remove_pte。

page_remove_pte:
1. 先判断 *ptep & PTE_V，避免 pte2page 对无效 PTE panic。
2. page_ref_dec(page)，归零才 free_page(page)。
3. *ptep = 0。
4. tlb_invalidate(pgdir, la)。
5. 不要释放中间页表页。

[EDGE CASES]
- 同一物理页被多个地址映射：每个地址各计一次引用。
- 同一地址重复插入同一页：引用计数不变，权限被覆盖。
- 删除未映射地址、重复删除：安全返回。
- get_pte 失败：不留叶子映射，不改数据页引用计数。

[ACCEPTANCE]
- code/kern/mm/pmm.c 能编译。
- check_pgdir()、check_boot_pgdir() 通过。
- test_lab4_pmm_basic() 输出 `[Test PMM] PASS`。
- 不修改 LAB4 标记以外的内容；保留注释，把 YOUR CODE 换成 2412102。

[OUTPUT]
只输出需要插入 pmm.c 的 C 代码，带少量中文注释，不要输出整份文件。
````

### 功能模块：进程创建及初始化

**负责人：** 2413346-易响

> 本文件记录功能模块二六个函数实际使用的最终提示词与迭代过程，供 C 整合报告时核对。
> 六个函数位于 `kern/process/proc.c` 的同一个 `//LAB4 function2` 区域，因此下面按函数分别给出提示词，最后补充模块级的构建迭代说明。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

1. `alloc_proc()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 RISC-V 教学操作系统 ucore 的 Lab4，负责功能模块二：进程创建及初始化。
现在实现 kern/process/proc.c 中的 alloc_proc()。

实现方式：
- 先读 proc.h、pmm.h、memlayout.h，确认 struct proc_struct 的字段、boot_pgdir_pa 和 PROC_UNINIT。
- 在独立工作副本中修改实际文件，只填写 //LAB4 function2 区域中的 alloc_proc()。
- 保留本区域的其他函数、已有辅助函数和 C 负责的 //LAB4 function3 区域。
- 输出完整函数，不省略；每个字段的初始值写成中文注释。
- 完成后执行 make clean && make，确认 proc.c 能编译。

[RELY]
可以依赖的东西：
- struct proc_struct 定义于 kern/process/proc.h，字段包括 state、pid、runs、kstack、
  need_resched、parent、mm、context、tf、pgdir、flags、name、list_link、hash_link。
- struct context 依次为 ra、sp、s0～s11，共 14 个 uintptr_t。
- void *kmalloc(size_t n) 和 void kfree(void *objp)，声明于 kern/mm/kmalloc.h。
- extern uintptr_t boot_pgdir_pa，在 pmm_init() 中设置为内核页表根的物理地址。
- PROC_UNINIT 定义于 proc.h；memset 来自 libs/string.h。
- alloc_proc() 的调用者只有 proc_init() 和 do_fork()。
- 骨架中没有 alloc_proc() 的前置声明，它定义在 proc_init() 之前即可。

[GUARANTEE]
必须交付：
1. 完整的 static struct proc_struct *alloc_proc(void)。
2. 只做 PCB 分配和字段初始化，不分配内核栈、不分配 PID、不挂链表、不置 PROC_RUNNABLE。
3. 保留 //LAB4 function2 注释，把 YOUR CODE 换成 2413346。
4. 对 context、name、pgdir 三个关键初值给出注释。

[SPECIFICATION]
alloc_proc(void)
  Pre-Condition：
  - kmalloc 已由 pmm_init() 中的 kmalloc_init() 初始化。
  - boot_pgdir_pa 已经指向内核页表根。

  Post-Condition：
  - 成功时返回一个可继续初始化的 PCB；失败时返回 NULL。
  - state = PROC_UNINIT、pid = -1、runs = 0、kstack = 0、need_resched = 0。
  - parent = NULL、mm = NULL、tf = NULL。
  - pgdir = boot_pgdir_pa（物理地址，不是内核虚拟地址）。
  - flags = 0、name 全 0、context 全 0。

  Case 1：kmalloc 返回 NULL。
  - 直接返回 NULL，不修改任何全局状态。

  Requirements：
  - 不调用 setup_kstack()、get_pid()、list_add()、hash_proc()。
  - 不把 list_link/hash_link 指向自己：它们会在 list_add()/hash_proc() 中被完整重写。
  - 不写死内核栈地址，不设置 PROC_RUNNABLE。
  - 验收：idleproc->tf == NULL、idleproc->context.ra == 0、idleproc->runs == 0、idleproc->flags == 0。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：

- 使用 `kmalloc(sizeof(struct proc_struct))` 分配 PCB，失败返回 `NULL`。
- 将 `state`、`pid`、`runs`、`kstack`、`need_resched`、`parent`、`mm`、`tf`、`pgdir`、`flags`、`name`、`context` 全部初始化。
- `pgdir` 使用 `boot_pgdir_pa`，保证 C 的 `proc_run()` 写入 `satp` 时拿到物理地址。
- 未初始化 `list_link`/`hash_link`，留给 `list_add()`/`hash_proc()`。
- 编译结果：编译成功。

2. `proc_init()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块二，现在实现 kern/process/proc.c 中的 proc_init()。

实现方式：
- 先读 proc.c、proc.h、sched.h、pmm.h、init.c 和 tools/test_lab4.c，确认全局结构和启动顺序。
- 在独立工作副本中修改实际文件，只填写 //LAB4 function2 区域中的 proc_init()。
- 保留 alloc_proc()、kernel_thread()、do_fork()、copy_thread()、copy_mm() 和 C 的 function3 区域。
- 按“初始化链表/哈希表 → idleproc → current → initproc”的顺序实现。
- 输出完整函数，并说明 current 为什么必须在 kernel_thread() 之前设置。

[RELY]
可以依赖的东西：
- 全局变量：list_entry_t proc_list、hash_list[HASH_LIST_SIZE]、idleproc、initproc、current、nr_process。
- list_init(list_entry_t *elm)，定义于 libs/list.h。
- alloc_proc()、kernel_thread()、find_proc()、set_proc_name()、init_main()。
- extern char bootstack[]、bootstacktop[]，定义于 kern/init/entry.S，KSTACKSIZE = 2 * PGSIZE。
- 状态 PROC_RUNNABLE；panic()、assert() 来自 kern/debug/assert.h。
- init_main 的原型是 static int init_main(void *arg)，由 kernel_thread() 包装。
- idleproc 不作为普通节点加入 proc_list；get_pid() 因此看不到 pid 0，initproc 能得到 pid 1。

[GUARANTEE]
必须交付：
1. 完整的 void proc_init(void)。
2. proc_list 与 hash_list 全部初始化为空表。
3. idleproc 的 pid、状态、kstack、need_resched、名称。
4. current 在 kernel_thread() 之前指向 idleproc。
5. initproc 的创建、find_proc() 查找和命名；失败时 panic。

[SPECIFICATION]
proc_init(void)
  Pre-Condition：
  - pmm_init()、vmm_init() 已完成，boot_pgdir_pa、bootstack、kmalloc 可用。
  - current 尚未设置。

  Post-Condition：
  - proc_list 和 hash_list[0..HASH_LIST_SIZE-1] 均为空表。
  - idleproc->pid = 0、state = PROC_RUNNABLE、kstack = (uintptr_t)bootstack、
    need_resched = 1、parent = NULL、mm = NULL、tf = NULL、name = "idle"。
  - idleproc 不加入 proc_list/hash_list。
  - current == idleproc。
  - initproc->pid = 1、parent = idleproc、state = PROC_RUNNABLE、name = "init"，
    已加入 proc_list 和 hash_list。
  - nr_process == 2。

  Case 1：idleproc 分配失败。
  - panic("cannot alloc idleproc.\n")。

  Case 2：kernel_thread() 返回 <= 0。
  - panic("create init_main failed.\n")。

  Requirements：
  - current 必须在 kernel_thread(init_main, "Hello world!!", 0) 之前设置。
  - initproc 用 find_proc(pid) 从哈希表取回，不要直接用局部变量。
  - 不把 idleproc 加入链表，不设置 idleproc->tf，不初始化 idleproc->context。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：

- 用 `list_init(&proc_list)` 和循环初始化 1024 个哈希桶。
- 创建 `idleproc`，设置 pid 0、`PROC_RUNNABLE`、`bootstack`、`need_resched = 1`、名称 `"idle"`。
- 在创建 `initproc` 之前设置 `current = idleproc`，保证父子关系正确。
- 通过 `kernel_thread(init_main, "Hello world!!", 0)` 创建 `initproc`，`find_proc()` 取回并命名 `"init"`。
- 编译与运行结果：`[Test Process Create] PASS`，`initproc, pid = 1`。

3. `kernel_thread()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块二，现在实现 kern/process/proc.c 中的 kernel_thread()。

实现方式：
- 先读 proc.h、trap.h、entry.S、trapentry.S、riscv.h 和 proc.c，确认 trapframe 布局与恢复链。
- 在独立工作副本中修改实际文件，只填写 //LAB4 function2 区域中的 kernel_thread()。
- 保留 alloc_proc()、proc_init()、do_fork()、copy_thread()、copy_mm() 及 C 的 function3。
- 用局部 struct trapframe 构造首次运行现场，然后交给 do_fork()。
- 输出完整函数，并逐位解释 status 的 SPP/SPIE/SIE 处理。

[RELY]
可以依赖的东西：
- struct trapframe：struct pushregs gpr（含 s0、s1、a0、sp 等）以及 status、epc、badvaddr、cause。
- kernel_thread_entry 的汇编：move a0, s1; jalr s0；因此 s0 放函数、s1 放参数。
- SSTATUS_SIE、SSTATUS_SPIE、SSTATUS_SPP 和 read_csr()，来自 libs/riscv.h（经 sync.h 引入）。
- int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)。
- CLONE_VM 定义于 kern/mm/pmm.h。
- kernel_thread() 的返回类型是 int，失败时直接透传 do_fork() 的错误码。

[GUARANTEE]
必须交付：
1. 完整的 int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)。
2. 局部 trapframe 先 memset 清零，再设置 s0、s1、epc、status。
3. status 必须保留原 sstatus 的其他位，只处理 SPP/SPIE/SIE。
4. 保留 LAB4 注释和学号 2413346。

[SPECIFICATION]
kernel_thread(fn, arg, clone_flags)
  Pre-Condition：
  - fn 非空，签名与 int (*)(void *) 一致。
  - 调用者允许创建内核线程。

  Post-Condition：
  - 返回正 PID 或 do_fork() 的负错误码。
  - 临时 trapframe：gpr.s0 = fn、gpr.s1 = arg、epc = kernel_thread_entry。
  - status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE。

  Case 1：do_fork() 失败。
  - 直接返回其错误码，不吞掉失败。

  Requirements：
  - 不在这里设置 tf.gpr.sp；由 copy_thread() 根据 esp 是否为 0 决定。
  - 不在这里复制 trapframe 到内核栈；copy_thread() 会按值复制。
  - 不在这里调用 fn，不手动分配内核栈。
  - SPP = 1（sret 返回 S 态）、SPIE = 1（返回后开中断）、SIE = 0（构造期间关中断）。
  - 传 stack = 0，并补上 CLONE_VM，表示内核线程共享内核地址空间。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：

- 用 `memset(&tf, 0, sizeof(struct trapframe))` 清零临时中断帧。
- 设置 `tf.gpr.s0 = (uintptr_t)fn`、`tf.gpr.s1 = (uintptr_t)arg`、`tf.epc = (uintptr_t)kernel_thread_entry`。
- `tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE`。
- 调用 `do_fork(clone_flags | CLONE_VM, 0, &tf)` 并返回其 PID。
- 运行结果：`init_main` 收到 `"Hello world!!"`，两条 `To U:` 输出正确。

4. `do_fork()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块二，现在实现 kern/process/proc.c 中的 do_fork()。

实现方式：
- 先读 proc.c、proc.h、pmm.h、sched.h、sync.h 和 tools/test_lab4.c，确认创建流程和失败路径。
- 在独立工作副本中修改实际文件，只填写 //LAB4 function2 区域中的 do_fork()。
- 保留 alloc_proc()、proc_init()、kernel_thread()、copy_thread()、copy_mm() 及 C 的 function3。
- 按“PCB → 父进程 → 内核栈 → 地址空间 → 现场 → 登记 → 就绪”的顺序实现。
- 输出完整函数，并画出失败清理的标签跳转关系。

[RELY]
可以依赖的东西：
- 全局变量：current、nr_process、proc_list、hash_list。
- alloc_proc()、setup_kstack()、put_kstack()、copy_mm()、copy_thread()。
- get_pid()、hash_proc()、list_add()、wakeup_proc()。
- local_intr_save(flag)、local_intr_restore(flag)（kern/sync/sync.h）。
- MAX_PROCESS、E_NO_MEM、E_NO_FREE_PROC（proc.h、libs/error.h）。
- struct proc_struct 的 state、pid、parent、kstack、mm、context、tf、list_link、hash_link。
- copy_thread()/copy_mm() 定义在 do_fork() 之后，因此需要在区域开头补 static 前置声明。

[GUARANTEE]
必须交付：
1. 完整的 int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)。
2. 七个步骤齐全：alloc_proc、parent、setup_kstack、copy_mm、copy_thread、
   PID/哈希/链表/计数、wakeup_proc。
3. PID/哈希/链表/计数在同一个中断保护临界区内完成，wakeup_proc 放在最后。
4. 失败路径按已分配资源逐级回滚。

[SPECIFICATION]
do_fork(clone_flags, stack, tf)
  Pre-Condition：
  - tf 非空；current 有效；进程数未超限。

  Post-Condition：
  - 成功时新 PCB 有唯一 PID、内核栈、tf、context、父进程。
  - 已入 hash_list 和 proc_list，nr_process 加 1，state = PROC_RUNNABLE。
  - 返回新线程 PID。

  Case 1：nr_process >= MAX_PROCESS。
  - 返回 -E_NO_FREE_PROC，不分配任何资源。

  Case 2：alloc_proc() 返回 NULL。
  - 返回 -E_NO_MEM。

  Case 3：setup_kstack() 失败。
  - kfree(proc)，返回 -E_NO_MEM。

  Case 4：copy_mm() 失败。
  - put_kstack(proc) 后 kfree(proc)，返回错误码。

  Requirements：
  - 失败路径不调用 wakeup_proc()，不把半成品加入链表。
  - 不在临界区外分配 PID，不让调度器看到 pid = -1 的节点。
  - 不在 do_fork() 中直接更新 current 或写 satp。
  - 验收：test_lab4_schedule() 连续两次 kernel_thread() 都返回正 PID，两个线程都能被调度。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，随后因模块级编译问题补充了前置声明；功能逻辑未变。

---

##### 第一次迭代

**遇到的问题：**

- 按文档顺序把 `copy_thread`/`copy_mm` 放在 `do_fork()` 之后，但骨架没有前置声明，编译报：

  ```text
  warning: implicit declaration of function 'copy_mm'
  warning: implicit declaration of function 'copy_thread'
  error: static declaration of 'copy_thread' follows non-static declaration
  error: static declaration of 'copy_mm' follows non-static declaration
  ```

- 原因：`do_fork()` 先看到隐式声明（默认外部链接），随后又看到 `static` 定义，链接属性冲突。

**问题解决策略：**

- 在 `//LAB4 function2` 区域开头补两条 `static` 前置声明：

  ```c
  static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);
  static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
  ```

- 另外执行 `make clean && make`，避免 `obj/` 中其他路径的旧目标文件导致链接错误。

**最终结果：**

经过修正，本函数目前：

- 按七个步骤完成创建流程。
- 失败路径通过 `bad_fork_cleanup_kstack` → `bad_fork_cleanup_proc` 逐级释放。
- `wakeup_proc()` 最后调用，半成品不会被调度。
- 运行结果：`[Test Process Create] PASS`、`[Test Schedule] PASS`。

5. `copy_thread()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块二，现在实现 kern/process/proc.c 中的 copy_thread()。

实现方式：
- 先读 proc.h、trap.h、trapentry.S、switch.S 和 proc.c，确认内核栈布局与恢复链。
- 在独立工作副本中修改实际文件，只填写 //LAB4 function2 区域中的 copy_thread()。
- 保留其他创建函数和 C 的 function3 区域。
- 说明 tf 为什么放在 kstack + KSTACKSIZE 下方、context.sp 为什么不能设成栈顶。
- 输出完整函数和恢复链说明。

[RELY]
可以依赖的东西：
- struct proc_struct 的 kstack、tf、context。
- KSTACKSIZE = KSTACKPAGE * PGSIZE = 2 * 4096 = 8192。
- struct trapframe 为 36 个机器字，RV64 下 288 字节。
- static void forkret(void)：调用 forkrets(current->tf)。
- struct context 依次为 ra、sp、s0～s11。
- do_fork() 传入的 esp：内核线程为 0，用户进程场景为非 0。
- copy_thread() 定义在 do_fork() 之后，需要 static 前置声明。

[GUARANTEE]
必须交付：
1. 完整的 static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf)。
2. 中断帧放在新线程内核栈顶下方，按值复制模板。
3. tf->gpr.a0 = 0、tf->gpr.sp = (esp == 0) ? tf : esp。
4. context.ra = forkret、context.sp = tf。
5. 解释与 forkrets、__trapret、kernel_thread_entry 的衔接。

[SPECIFICATION]
copy_thread(proc, esp, tf)
  Pre-Condition：
  - proc->kstack 已由 setup_kstack() 分配。
  - tf 非空。

  Post-Condition：
  - proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1。
  - *proc->tf = *tf。
  - proc->tf->gpr.a0 = 0。
  - proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp。
  - proc->context.ra = (uintptr_t)forkret。
  - proc->context.sp = (uintptr_t)proc->tf。

  Case 1：esp == 0（内核线程）。
  - sp 指向自己的中断帧，不能为 0。

  Case 2：esp != 0（后续用户进程场景）。
  - 沿用调用者给出的栈。

  Requirements：
  - 不把 context.sp 设成 kstack + KSTACKSIZE，否则 forkret 的栈帧会覆盖 tf 的尾部。
  - 不在这里调用 fn，不写 satp，不修改 C 的 context 字段布局。
  - 验收：initproc->context.ra != 0、context.sp != 0，首次切换能进入 init_main。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生逻辑修订；因定义位置在 do_fork() 之后，补充了 static 前置声明。

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：

- `tf` 放在 `kstack + KSTACKSIZE - sizeof(struct trapframe)`。
- `a0 = 0`、`sp = tf`（esp == 0 时）。
- `context.ra = forkret`、`context.sp = tf`。
- 运行结果：首次切换进入 `forkret → forkrets → __trapret → kernel_thread_entry → init_main`，
  `[Test Schedule] PASS`。

6. `copy_mm()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块二，现在实现 kern/process/proc.c 中的 copy_mm()。

实现方式：
- 先读 proc.c、proc.h、pmm.h，确认本实验只创建内核线程、current->mm 为 NULL。
- 在独立工作副本中修改实际文件，只填写 //LAB4 function2 区域中的 copy_mm()。
- 保留其他创建函数和 C 的 function3 区域。
- 保持函数形态完整，为实验五以后扩展用户地址空间复制留出位置。
- 输出完整函数，并说明为什么本阶段不能调用 page_insert/page_remove。

[RELY]
可以依赖的东西：
- struct proc_struct 的 mm 字段。
- 全局 current；本实验 current->mm 恒为 NULL。
- assert() 来自 kern/debug/assert.h。
- 内核线程共享内核地址空间，不需要为每个线程复制页表。
- copy_mm() 定义在 do_fork() 之后，需要 static 前置声明。

[GUARANTEE]
必须交付：
1. 完整的 static int copy_mm(uint32_t clone_flags, struct proc_struct *proc)。
2. 断言 current->mm == NULL，设置 proc->mm = NULL，返回 0。
3. 不调用页表映射接口，不做用户地址空间复制。
4. 保留 LAB4 注释和学号 2413346。

[SPECIFICATION]
copy_mm(clone_flags, proc)
  Pre-Condition：
  - 当前创建的是内核线程，current->mm == NULL。

  Post-Condition：
  - proc->mm = NULL。
  - 返回 0，表示地址空间处理成功。

  Case 1：本实验所有创建路径。
  - 恒返回 0；若返回非 0，do_fork() 会走 put_kstack/kfree 清理。

  Requirements：
  - 不调用 page_insert()/page_remove()。
  - 不分配 mm_struct，不复制页表。
  - 不改变 clone_flags 的语义，为后续实验保留参数。
  - 验收：idleproc->mm == NULL、initproc->mm == NULL。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生逻辑修订；因定义位置在 do_fork() 之后，补充了 static 前置声明。

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：

- `assert(current->mm == NULL)`。
- `proc->mm = NULL`，返回 0。
- 未调用任何页表接口。
- 编译结果：编译成功；`[Test Process Create] PASS` 中的 `idleproc->mm == NULL`、`initproc->mm == NULL` 均已验证。

---

#### 模块整体构建迭代补充

六个函数的逻辑均一次成型，构建阶段遇到两个问题，已记录在 `report_B.md` 的 4.2.5 节：

1. **缺少 static 前置声明**：`copy_thread()`/`copy_mm()` 定义在 `do_fork()` 之后，骨架未提供声明。解决：在 `//LAB4 function2` 区域开头补两条声明。
2. **旧 `obj/` 导致链接错误**：仓库 `obj/` 残留其他路径（`/home/a/OS/lab4/code`）的目标文件，`make` 只重编 `proc.c`，未重编 A 的 `pmm.c` 和 C 的 `sched.c`，链接报 `page_insert`/`page_remove`/`schedule` 未定义。解决：`make clean && make`。

最终验证：

```text
[Test PMM] PASS
[Test Process Create] PASS
[Test Schedule] PASS
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
```

`make grade`：`check PMM / check Process Create / check Schedule` 全 `OK`，`Total Score: 30/30`。

### 功能模块：进程调度

**负责人：** 2411033-季艾佳
#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：
1. cpu_idle():
以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 RISC-V 教学操作系统 ucore 的 Lab4，负责功能模块三：进程调度与上下文切换。现在先实现 kern/process/proc.c 中的 cpu_idle()。

实现方式：
- 先读 proc.h、proc.c、sched.h 和 kern/init/init.c，确认 current、调度标志和调用关系。
- 在独立工作副本中修改实际文件，只填写 LAB4 function3 区域中的 cpu_idle()。
- 保留 B 负责的 LAB4 function2 区域、已有辅助函数和本区域的其他实现。
- 使用现有 schedule() 接口发起调度，不在这里实现线程选择和寄存器切换。
- 先说明函数职责，再给出完整函数，不省略实现。
- 当前只进行静态检查，不运行编译或测试；说明后续验证方法即可。

[RELY]
可以依赖的东西：
- struct proc_struct 定义于 kern/process/proc.h，其中 need_resched 为 volatile bool。
- 全局变量 current 和 idleproc，类型为 struct proc_struct *。
- void schedule(void)，声明于 kern/schedule/sched.h。
- cpu_idle() 在 proc.h 中声明为：
  void cpu_idle(void) __attribute__((noreturn));
- kern_init() 在 proc_init()、clock_init()、intr_enable() 之后调用 cpu_idle()。
- B 的 proc_init() 应设置 current == idleproc，并将 idleproc->need_resched 置为 1。
- proc.c 已包含 proc.h 和 sched.h。

[GUARANTEE]
必须交付：
1. 完整的 void cpu_idle(void)，签名与现有声明一致。
2. 保留 LAB4 function3 注释，不修改公共结构、初始化流程或其他成员的函数。
3. 说明与 B 的初始化约定，区分静态检查与实际运行验证。

[SPECIFICATION]
cpu_idle(void)
  Pre-Condition：
  - 进程管理结构已经初始化，current 指向有效的 idleproc。
  - 完整集成版本已提供可用的调度器和上下文切换实现。

  Post-Condition：
  - 函数持续运行，不返回调用者。
  - 需要重调度时调用 schedule()。
  - 本执行流重新获得 CPU、调度调用返回后，继续检查调度标志。
  - 不改变进程链表、线程状态和寄存器上下文。

  Case 1：need_resched 为 0。
  - 保持空闲循环，不主动调用 schedule()。

  Case 2：need_resched 非零。
  - 调用 schedule() 处理调度请求，返回后继续循环。

  Requirements：
  - 不在这里清除 need_resched，该动作由 schedule() 负责。
  - 不在整个空闲循环中关闭中断。
  - 不额外分配资源，不在循环中不断打印日志。
  - 不将函数改成只检查一次后返回。
  - 后续可单独编译 proc.o；完整运行需要 A、B、C 的代码齐全，再检查首次调度。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**
经过 1 次代码生成，本函数:
- 生成了持续检查 `current->need_resched` 的空闲循环：标志非零时调用 `schedule()`，返回后继续检查，没有在本函数中清除标志或关闭整个循环的中断。
- 已给出完整实现，并核对接口与控制流程。
- 编译结果：编译成功。

2. schedule()
以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块三，现在实现 kern/schedule/sched.c 中的 schedule()。

实现方式：
- 先读 sched.c、sched.h、proc.h、sync.h 和 list.h，按真实的循环双向链表接口实现。
- 在独立工作副本中修改实际文件，只填写 LAB4 function3 区域中的 schedule()。
- 保留已有 wakeup_proc()，不修改进程结构、B 的创建函数或其他调度函数。
- 按链表顺序循环选择可运行线程，实际切换交给 proc_run()。
- 输出完整函数，并解释空链表、链表回绕和仅当前线程可运行时的行为。
- 当前只进行静态检查，不运行编译或测试。

[RELY]
可以依赖的东西：
- struct proc_struct，本函数使用 state、runs、need_resched、list_link。
- 线程状态 PROC_RUNNABLE。
- 全局变量 proc_list、current、idleproc。
- proc_list 是带哨兵头节点的循环双向链表，普通线程通过 list_link 入链。
- idleproc 不作为普通线程节点加入 proc_list；其他当前线程已经在该链表中。
- 链表接口：list_entry_t、list_next()、le2proc(le, list_link)。
- 切换接口：void proc_run(struct proc_struct *proc)。
- 中断接口：local_intr_save(flag)、local_intr_restore(flag)。
- B 负责初始化线程状态、链表成员、runs 等字段。
- sched.c 已包含所需头文件。

[GUARANTEE]
必须交付：
1. 完整的 void schedule(void)。
2. 在中断保护下处理调度请求、选择目标、更新运行次数并按需触发切换。
3. 保留 wakeup_proc()、公开接口和 Lab4 注释。
4. 使用现有 proc_list，不新增调度队列或资源分配逻辑。

[SPECIFICATION]
schedule(void)
  Pre-Condition：
  - current、idleproc 有效，idleproc 可作为兜底运行线程。
  - proc_list 已初始化，普通线程的链表节点和状态一致。
  - 当前普通线程位于 proc_list 中。
  - proc_run() 在集成后能够切换线程。

  Post-Condition：
  - 清除调用线程的本次重调度标志。
  - 选中可运行线程；没有普通候选线程时选中 idleproc。
  - 目标线程的 runs 增加一次，包括再次选中当前线程的情况。
  - 目标不同于当前线程时调用 proc_run()。
  - 原调用线程恢复执行并返回本函数时，恢复本次调用前的中断开关状态。

  Case 1：当前线程为 idleproc。
  - 从链表头之后开始寻找第一个可运行线程。

  Case 2：当前线程为普通线程。
  - 从它的下一个节点开始循环查找，跳过哨兵节点，最多遍历一圈。
  - 支持跨过链表尾回到开头。
  - 一圈后允许再次选中仍可运行的当前线程。

  Case 3：链表为空，或没有可运行的候选线程。
  - 使用 idleproc 兜底，不把哨兵头节点转换为 PCB。

  Case 4：选中的目标就是当前线程。
  - 更新运行次数，但不重复切换寄存器现场。

  Requirements：
  - 只选择 PROC_RUNNABLE 线程，遍历必须能够结束。
  - 调度选择和触发切换期间保持中断保护。
  - 支持调用者原来就关闭中断的情况，不提前打开中断。
  - 不在这里直接更新 current、写 satp 或保存寄存器。
  - 后续可单独编译 sched.o；集成后检查空闲兜底、多线程主动调度及 Schedule 评分项。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：
- 关闭中断并清除当前调度请求。
- 从当前线程之后开始查找；当前为 idle 时，从链表头之后开始。
- 跳过哨兵节点，只选择 `PROC_RUNNABLE` 线程。
- 没有候选线程时使用 `idleproc`。
- 更新目标线程的 `runs`，目标不同于当前线程时调用 `proc_run()`。
- 已给出完整实现，并检查关键边界路径。
- 编译结果：以编译确认。

---

3. proc_run()

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块三，现在实现 kern/process/proc.c 中的 proc_run()。

实现方式：
- 先读 proc.c、proc.h、sync.h、riscv.h，并参考 pmm.c 中对 satp 的使用。
- 在独立工作副本中修改实际文件，只补 LAB4 function3 区域中的 proc_run()。
- 保留已经实现的 cpu_idle() 和 B 负责的 LAB4 function2 区域。
- 在中断保护下更新当前线程、切换页表并调用 switch_to()。
- 当前目标为 RV64/Sv39。先核对 lsatp()，不能直接使用仅适配 Sv32 的旧实现。
- 不修改公共 riscv.h，在本函数内部构造正确的 Sv39 satp 编码。
- 输出完整函数，解释物理地址、物理页号和 satp 的关系。
- 当前只进行静态检查，不运行编译或测试。

[RELY]
可以依赖的东西：
- struct proc_struct 中的 context 和 pgdir。
- pgdir 保存页表根的物理字节地址。
- 全局变量 struct proc_struct *current。
- void switch_to(struct context *from, struct context *to)，proc.c 已有声明。
- local_intr_save(flag)、local_intr_restore(flag)。
- write_csr(satp, value)。
- SATP_MODE_SV39=8，RISCV_PGSHIFT=12。
- RV64 satp 的 MODE 位位于 63:60，本实验使用 Sv39，ASID 使用 0。
- 当前 riscv.h 的 lsatp(unsigned int pgdir) 使用 SATP32_MODE，不适用于当前 RV64 切换。
- 可以使用带 memory clobber 的 sfence.vma 内联汇编处理本 hart 的地址翻译缓存。
- 内核线程共享内核地址空间，切换前后的内核代码、栈和 PCB 均具有有效映射。
- B 负责构造有效的目标 context、内核栈和首次运行现场。

[GUARANTEE]
必须交付：
1. 完整的 void proc_run(struct proc_struct *proc)。
2. 正确保留旧线程指针并更新 current。
3. 使用 RV64/Sv39 编码设置 satp，处理 TLB，然后调用 switch_to()。
4. 保持公开接口不变，不修改 B 的创建逻辑和公共头文件。
5. 不重复修改调度次数和重调度标志。

[SPECIFICATION]
proc_run(struct proc_struct *proc)
  Pre-Condition：
  - current 和 proc 均为有效 PCB，目标线程已经可以运行。
  - proc->pgdir 为有效、按页对齐的页表根物理地址。
  - pgdir 不是虚拟地址，也不是已经编码好的 satp 值。
  - 目标 context 和内核栈已准备好，switch_to() 在集成后可用。

  Post-Condition：
  - 目标不同于当前线程时，将旧线程现场保存到其 context，并恢复目标线程现场。
  - 目标运行时，current 指向目标 PCB，satp 使用目标页表，旧翻译缓存经过处理。
  - 原线程以后重新获得 CPU 并继续本次调用时，按进入临界区前的状态恢复中断。

  Case 1：proc 等于 current。
  - 直接结束，不切换页表或寄存器现场。

  Case 2：proc 不等于 current。
  - 在临界区内保留旧线程指针、更新 current、设置目标页表并切换 context。
  - 使用 Sv39 模式和页表根物理页号构造 satp，避免以 32 位常量完成高位移位。
  - 写入 satp 后执行 sfence.vma，再进行寄存器上下文切换。

  Requirements：
  - 不把物理字节地址原样写入 satp。
  - 支持外层 schedule() 已经关闭中断的情况，内层不能提前打开中断。
  - 不在这里增加 runs，由 schedule() 维护调度次数。
  - 不分配 PCB、内核栈或页表，不改变线程管理链表。
  - 后续可单独编译 proc.o；集成后验证首次线程启动、已有线程恢复及 Schedule 评分项。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数：

- 目标为当前线程时直接结束。
- 保存中断状态并关闭中断。
- 保留旧线程指针，更新 `current`。
- 使用 Sv39 模式和目标页表根物理页号构造 `satp`。
- 写入 `satp` 后执行 `sfence.vma`。
- 调用 `switch_to()` 保存旧 context、恢复目标 context。
- 原线程以后恢复执行时，再恢复本次调用前的中断状态。
- 已给出完整实现。
- 已静态核对页表地址编码、TLB 处理、参数顺序和嵌套中断保护。

---

4. switch_to()

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab4 的功能模块三，现在实现 kern/process/switch.S 中的 switch_to()。

实现方式：
- 先读 proc.h 中的 struct context、riscv.h 中的寄存器宽度宏，以及 proc.c 的调用声明。
- 在独立工作副本中修改实际 switch.S 文件，保留 LAB4 function3 注释。
- 按现有 context 布局保存旧线程、恢复目标线程的 ra、sp、s0 至 s11。
- 使用已有 STORE、LOAD、REGBYTES 宏，保留大写 .S 后缀。
- 使用普通函数返回，首次运行入口由 B 构造的 context 决定。
- 输出完整汇编文件，解释偏移、参数和返回位置。
- 当前只进行静态检查，不运行编译或测试。

[RELY]
可以依赖的东西：
- 函数声明：
  void switch_to(struct context *from, struct context *to);
- RISC-V 调用约定：a0 指向 from，a1 指向 to。
- struct context 按以下顺序定义：
  uintptr_t ra;
  uintptr_t sp;
  uintptr_t s0;
  uintptr_t s1;
  uintptr_t s2;
  uintptr_t s3;
  uintptr_t s4;
  uintptr_t s5;
  uintptr_t s6;
  uintptr_t s7;
  uintptr_t s8;
  uintptr_t s9;
  uintptr_t s10;
  uintptr_t s11;
- RV64 下 uintptr_t 为 8 字节，REGBYTES=8，STORE 为 sd，LOAD 为 ld。
- 14 个字段的字节偏移依次为 0、8、16，直到 104。
- proc_run() 负责中断保护、更新 current 和切换页表。
- B 为新线程设置 context.ra 指向 forkret，并提供有效的 context.sp。
- 已有首次运行恢复链为：
  forkret -> forkrets -> __trapret -> kernel_thread_entry。

[GUARANTEE]
必须交付：
1. 对外可链接的 switch_to 汇编符号，对应现有两个 context 指针参数。
2. 完整保存和恢复 14 个寄存器。
3. 正确的代码段、对齐及函数符号声明。
4. 保留 Lab4 标记，不修改 proc.h、trapentry.S、测试或 B 的首次现场构造。
5. 不新增调度策略、公共结构字段或资源分配逻辑。

[SPECIFICATION]
switch_to(struct context *from, struct context *to)
  Pre-Condition：
  - from 和 to 指向有效、互不重叠的 context。
  - from 可写，to 已初始化。
  - 调用方已保护切换临界区。
  - 目标内核栈和 context 在当前地址空间中可访问。
  - 当前使用符合项目约定的 RISC-V 调用 ABI。

  Post-Condition：
  - from 保存本次切换点的 ra、sp、s0 至 s11。
  - CPU 恢复 to 中对应寄存器，使用目标栈并转到恢复后的返回地址。
  - 保存和恢复的偏移严格对应现有结构的字段顺序和宽度。

  Case 1：切换到运行过的线程。
  - 使用它先前保存的返回地址和栈，继续之前的切换调用。

  Case 2：切换到首次运行的新线程。
  - 使用预先构造的 context 返回到 forkret，再进入已有 Trap 现场恢复链。
  - 不在本函数中调用目标线程函数或构造 trapframe。

  Requirements：
  - 先保存全部旧现场，再恢复目标现场。
  - 不提前覆盖访问 context 所需的 a0、a1。
  - 恢复时使用 a1 作为基址，恢复 sp 后仍能访问其余字段。
  - 这是普通函数调用边界，保存规定的 callee-saved 寄存器及 ra、sp。
  - 不保存整个 trapframe，不修改 CSR，不使用 sret 代替 ret。
  - 不新增栈帧，不遗漏恢复目标 sp。
  - 后续可单独汇编 switch.o；集成后验证首次启动、重复切换和寄存器现场恢复。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代


**最终结果：**

经过 1 次代码生成，本函数目前：

- 使用 `a0` 指向旧线程的 context，依次保存 `ra`、`sp`、`s0～s11`。
- 使用 `a1` 指向目标线程的 context，按相同布局恢复寄存器。
- 使用项目中的 `STORE`、`LOAD` 和 `REGBYTES`。
- 通过 `ret` 跳转到目标 context 中保存的 `ra`。
- 添加代码段、对齐、全局符号和函数类型声明。
- 已给出完整汇编实现，并核对字段偏移及调用约定。
- 汇编与链接结果：已实际构建确认。
