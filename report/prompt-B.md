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
