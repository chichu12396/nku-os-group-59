# Lab4 实验报告（角色 B 交付稿）

> 本文件是 B 负责的“功能模块二：进程创建及初始化”完整章节，可直接并入最终 `report.md` 的第四部分。
> 文末另外提供“五、测试与验证”的创建组材料、“六、实验总结与收获”的 B 部分，以及 B/C 联调所需的首次运行现场约定。
> 文中日志均为本机真实运行记录，原始文件见 `report/images/lab4_B_*.log`；最终整机截图由 C 在合并后的同一版本上统一收集。
> 合并时建议把下面的“## 四、…”整体降为 `### 功能模块二：进程创建及初始化`，4.2.x 降为 `####`，放在最终报告的 `## 四、实验内容与实现` 之下；五、六两节按 C 的统一编号并入。

---

## 四、实验内容与实现：功能模块二 进程创建及初始化

**负责人：** 2413346-易响（B）

### 4.2.1 模块功能描述

**需要实现/修改的函数：**

```c
// kern/process/proc.c，//LAB4 function2 区域
static struct proc_struct *alloc_proc(void);
void proc_init(void);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
static void copy_thread(struct proc_struct *proc, uintptr_t esp, struct trapframe *tf);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
```

**模块在系统中的作用：**

本模块把内核从“已经能运行内核代码”推进到“已经能创建并登记多个内核线程”。具体地说：

- `alloc_proc()` 得到一个字段干净的进程控制块（PCB）；
- `proc_init()` 把当前执行现场包装成 `idleproc`，再创建第一个真正的内核线程 `initproc`；
- `kernel_thread()` 把普通内核函数整理成“首次运行所需的中断帧”，并转交 `do_fork()`；
- `do_fork()` 把 PCB、内核栈、地址空间接口、中断帧、上下文、PID、链表和状态组合成一个可运行实体；
- `copy_thread()` 把中断帧安放到新线程自己的内核栈上，并设置首次切换使用的 `context.ra/sp`；
- `copy_mm()` 在本阶段只维持地址空间处理接口，保持内核线程共享内核地址空间的约定。

本模块的产物正是 C 负责的调度模块的输入：PCB、内核栈、就绪状态、链表成员、`context`、`tf` 和 `pgdir`。没有这些，`schedule()` 没有可选择的线程，`switch_to()` 也没有可恢复的现场。

**六个函数的分工：**

| 函数 | 定位 | 关键产出 |
|---|---|---|
| `alloc_proc()` | 分配与初始化 PCB | `PROC_UNINIT`、`pid = -1`、`pgdir = boot_pgdir_pa`、清零的 `context` |
| `proc_init()` | 建立进程管理全局结构 | 空的 `proc_list`/`hash_list`、`idleproc`、`initproc`、`current = idleproc` |
| `kernel_thread()` | 函数 → 线程的包装 | 临时 `trapframe`：`s0 = fn`、`s1 = arg`、`epc = kernel_thread_entry` |
| `do_fork()` | 创建线程的主体流程 | 完整 PCB、内核栈、PID、哈希/链表挂接、`PROC_RUNNABLE` |
| `copy_thread()` | 首次运行现场 | 内核栈上的 `tf`、`tf->gpr.a0 = 0`、`context.ra = forkret`、`context.sp = tf` |
| `copy_mm()` | 地址空间接口占位 | `proc->mm = NULL`，维持内核线程共享内核空间的约定 |

**主要场景：**

| 场景 | 触发路径 | 期望结果 |
|---|---|---|
| 系统启动 | `kern_init → proc_init` | `idleproc`（pid 0）接管当前现场，`initproc`（pid 1）就绪 |
| 创建 initproc | `proc_init → kernel_thread(init_main, "Hello world!!", 0) → do_fork` | 新内核栈 + 中断帧 + `forkret` 上下文，返回 pid 1 |
| 首次运行 | C 的 `schedule → proc_run → switch_to` | 进入 `forkret → forkrets → __trapret → kernel_thread_entry → init_main` |
| 运行期再创建 | `test_lab4_schedule → kernel_thread(test_lab4_thread, 1/2, 0)` | 依次得到 pid 2、pid 3 的可运行线程 |
| 资源不足 | `alloc_proc`/`setup_kstack`/`copy_mm` 失败 | 按已分配资源逐级回滚，返回负错误码，不留下半个线程 |

**与其他模块的关系：**

- **与 A（虚拟内存页操作）**：本模块不直接调用 `page_insert()`/`page_remove()`。线程创建依赖 A 提供的更底层基础：`pmm_init()` 已经建好内核页表并设置 `boot_pgdir_pa`，`kmalloc()` 可用，`alloc_pages()` 能为内核栈分配 2 个连续物理页。A 的页操作首先服务于 `pmm_init()` 中的 `check_pgdir()`/`check_boot_pgdir()` 自检，是 `proc_init()` 能正常执行的前提。
- **与已有框架**：`get_pid()`、`hash_proc()`、`find_proc()`、`setup_kstack()`、`put_kstack()`、`wakeup_proc()`、`set_proc_name()`、`forkret()`、`forkrets`、`kernel_thread_entry` 都已实现，本模块按它们的约定调用，不重复实现。
- **与 C（进程调度与上下文切换）**：B 准备“可调度对象”和“首次运行现场”，C 使用 `state`、`list_link`、`context`、`pgdir` 完成选择与切换。两模块的接口是 `struct context` 的字段布局、`context.ra = forkret`、`context.sp = tf`、`tf->epc = kernel_thread_entry` 以及 `pgdir` 的物理地址语义。
- **与后续实验**：`copy_mm()` 现在是占位接口；实验五以后才需要真正的用户地址空间复制、`mm_struct` 管理和 `do_exit()` 回收。

**线程状态变化（本模块涉及的部分）：**

```text
alloc_proc:                  PROC_UNINIT
proc_init (idleproc):        PROC_UNINIT → PROC_RUNNABLE
do_fork → wakeup_proc:       PROC_UNINIT → PROC_RUNNABLE
schedule/proc_run:           PROC_RUNNABLE（可能正在 CPU 上运行）
```

### 4.2.2 规格说明（spec）

#### 1. 全局约束

- 只填写 `code/kern/process/proc.c` 的 `//LAB4 function2` 区域；保留原有辅助函数和 C 的 `//LAB4 function3` 区域。
- 保留 `LAB4` 标记，把 `YOUR CODE` 替换为学号 `2413346`。
- 不修改 `struct proc_struct`、`struct context`、`struct trapframe` 的字段和顺序；这些结构同时被 C 的汇编和“中断帧恢复链”使用。
- `proc->pgdir` 保存页表根的**物理地址**（`boot_pgdir_pa`），不是内核虚拟地址。
- 所有“把线程暴露给调度器”的动作必须在 `state = PROC_RUNNABLE` 之前完成；状态是最后一道可见性开关。

#### 2. `alloc_proc()`

| 项目 | 规格 |
|---|---|
| 输入 | 无 |
| 输出 | 成功返回 `struct proc_struct *`；`kmalloc` 失败返回 `NULL` |
| 状态约束 | `state = PROC_UNINIT`、`pid = -1`、`runs = 0`、`kstack = 0`、`need_resched = 0`、`parent = NULL`、`mm = NULL`、`tf = NULL`、`pgdir = boot_pgdir_pa`、`flags = 0`、`name` 全 0、`context` 全 0 |
| 边界 | 不在本函数中分配内核栈、不分配 PID、不挂链表、不设置 `PROC_RUNNABLE` |
| 错误处理 | 分配失败直接返回 `NULL`，不修改任何全局状态 |
| 验收 | `idleproc->tf == NULL`、`idleproc->context.ra == 0`、`idleproc->runs == 0`、`idleproc->flags == 0` |

`list_link`/`hash_link` 不在 `alloc_proc()` 中初始化：`list_add()` 和 `hash_proc()` 会覆盖这两个节点的前后指针，提前把它们指向自己反而容易掩盖“忘记入链”的错误。

#### 3. `proc_init()`

| 项目 | 规格 |
|---|---|
| 输入 | 无；调用时 `pmm_init()`、`vmm_init()` 已完成，`boot_pgdir_pa` 和 `kmalloc` 可用 |
| 输出 | 无返回值；成功后有 `idleproc`、`initproc`，`current == idleproc`，`nr_process == 2` |
| 全局结构 | `proc_list` 与 `hash_list[0..HASH_LIST_SIZE-1]` 都初始化为空表 |
| idleproc | `pid = 0`、`state = PROC_RUNNABLE`、`kstack = (uintptr_t)bootstack`、`need_resched = 1`、`parent = NULL`、`mm = NULL`、`tf = NULL`、名称为 `"idle"`，但不加入 `proc_list`/`hash_list` |
| current | 必须在调用 `kernel_thread()` **之前**设置为 `idleproc`，否则 `do_fork()` 记录的父进程会出错 |
| initproc | 由 `kernel_thread(init_main, "Hello world!!", 0)` 创建，`pid = 1`、`parent = idleproc`、`state = PROC_RUNNABLE`、名称为 `"init"`，并已加入链表和哈希表 |
| 错误处理 | `alloc_proc()` 或 `kernel_thread()` 失败时 `panic`；初始化阶段无法继续启动 |
| 验收 | `current == idleproc`，`idleproc->pid == 0`，`initproc->pid == 1`，`initproc->parent == idleproc` |

为什么 `idleproc` 不加入 `proc_list`：它不是“被 fork 出来的普通线程”，而是当前执行现场的包装；调度器在找不到其他候选线程时直接用它兜底。`get_pid()` 因此也从 `proc_list` 中看不到 pid 0，`initproc` 能拿到 pid 1。

#### 4. `kernel_thread()`

| 项目 | 规格 |
|---|---|
| 输入 | `fn`：非空的内核函数指针，签名为 `int (*)(void *)`；`arg`：传给 `fn` 的参数；`clone_flags`：克隆标志 |
| 输出 | 成功返回新线程 PID（> 0）；失败返回 `do_fork()` 的负错误码 |
| 现场构造 | 局部 `struct trapframe tf` 先清零；`tf.gpr.s0 = (uintptr_t)fn`；`tf.gpr.s1 = (uintptr_t)arg`；`tf.epc = (uintptr_t)kernel_thread_entry`；`tf.status = (read_csr(sstatus) \| SSTATUS_SPP \| SSTATUS_SPIE) & ~SSTATUS_SIE` |
| 状态位 | `SPP = 1`：`sret` 返回 S 态；`SPIE = 1`：返回后允许中断；`SIE = 0`：构造期间不被中断打断 |
| 边界 | `tf.gpr.sp` 不在本函数中设置，由 `copy_thread()` 根据 `esp` 是否为 0 决定；`tf` 是栈上临时变量，必须在 `do_fork()` 返回前按值复制到新内核栈 |
| 错误处理 | 直接返回 `do_fork()` 的错误码，不吞掉失败 |
| 验收 | 新建线程 `context.ra != 0`、`context.sp != 0`，首次运行进入 `fn` 且 `arg` 正确 |

#### 5. `do_fork()`

| 项目 | 规格 |
|---|---|
| 输入 | `clone_flags`、`stack`（内核线程传 0）、`tf`（非空模板中断帧） |
| 输出 | 成功返回新线程 PID；进程数超限返回 `-E_NO_FREE_PROC`；内存不足返回 `-E_NO_MEM` |
| 步骤 | ① `alloc_proc()`；② `parent = current`；③ `setup_kstack()`；④ `copy_mm()`；⑤ `copy_thread()`；⑥ 中断保护下 `get_pid()`、`hash_proc()`、`list_add()`、`nr_process++`；⑦ `wakeup_proc()`；⑧ 返回 PID |
| 可见性 | PID、哈希、链表、计数在同一个临界区内完成；`wakeup_proc()` 放在临界区之后、所有资源就绪之后 |
| 失败清理 | PCB 分配失败：直接返回；内核栈失败：`kfree(proc)`；`copy_mm` 失败：`put_kstack(proc)` 后 `kfree(proc)`；`nr_process >= MAX_PROCESS`：不分配直接返回 |
| 边界 | 失败路径不调用 `wakeup_proc()`，不把半成品加入链表；`tf` 为空属于调用者违约 |
| 验收 | `test_lab4_schedule()` 能连续调用两次 `kernel_thread()`，返回正 PID，两个线程都能被调度执行 |

#### 6. `copy_thread()`

| 项目 | 规格 |
|---|---|
| 输入 | `proc`：已分配 PCB 和内核栈；`esp`：调用者给出的栈（内核线程为 0）；`tf`：模板中断帧 |
| 输出 | 无返回值；写 `proc->tf` 和 `proc->context` |
| 现场约束 | `proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1`；`*proc->tf = *tf`；`proc->tf->gpr.a0 = 0`；`proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp`；`proc->context.ra = (uintptr_t)forkret`；`proc->context.sp = (uintptr_t)proc->tf` |
| 边界 | 内核线程（`esp == 0`）必须把 `sp` 指向自己的中断帧，否则 `__trapret` 会恢复出 `sp = 0`；`esp != 0` 时保留调用者栈，兼容后续用户进程 |
| 对齐 | `struct trapframe` 为 36×8 = 288 字节，`kstack + KSTACKSIZE` 为 8 字节对齐，减 1 个结构体后仍对齐 |
| 验收 | `initproc->context.sp` 指向其内核栈上的 `tf`，`context.ra` 指向 `forkret`；首次切换后能进入 `init_main` |

#### 7. `copy_mm()`

| 项目 | 规格 |
|---|---|
| 输入 | `clone_flags`、`proc` |
| 输出 | 成功返回 0；本实验不会失败 |
| 状态约束 | `current->mm == NULL`（内核线程），`proc->mm = NULL` |
| 边界 | 不做用户地址空间复制、不调用页表映射接口；实验五以后才需要扩展 |
| 验收 | `idleproc->mm == NULL`、`initproc->mm == NULL` |

#### 8. 模块验收条件

- `code/kern/process/proc.c` 编译、链接通过；
- `tools/test_lab4.c` 的 `test_lab4_process_create()` 全部断言通过，输出 `[Test Process Create] PASS`；
- `make qemu` 能看到 `this initproc, pid = 1, name = "init"`、`To U: "Hello world!!".`、`To U: "en.., Bye, Bye. :)"`；
- 与 C 联调后 `make grade` 的 Process Create 组为 `OK`，三组总分 `30/30`；
- 保留 `//LAB4 function2 2413346` 注释。

### 4.2.3 最终提示词（prompt）

以下是本模块最终使用的提示词。它与 spec 一一对应，并在第一次构建失败后补充了“辅助函数前置声明”和“先 `make clean` 再构建”两条约束。

````markdown
[PROMPT]
我正在完成 RISC-V 教学操作系统 ucore 的 Lab4，负责功能模块二：进程创建及初始化。
请在独立工作副本中直接修改 code/kern/process/proc.c，只填写 //LAB4 function2 区域，
实现 alloc_proc()、proc_init()、kernel_thread()、do_fork()、copy_thread()、copy_mm() 六个函数。

实现方式：
- 先读 proc.h、pmm.h、memlayout.h、sched.h、trap.h、error.h、entry.S、trapentry.S、switch.S、
  init.c、tools/test_lab4.c 和 tools/inject.py，按真实字段、符号和调用链实现，不要凭记忆猜接口。
- 保留 //LAB4 function2 注释，把 YOUR CODE 换成 2413346；不改动已有辅助函数、公共结构和
  C 负责的 //LAB4 function3 区域。
- 六个函数按文档顺序给出：alloc_proc、proc_init、kernel_thread、do_fork、copy_thread、copy_mm。
  其中 copy_thread/copy_mm 定义在 do_fork 之后，必须在区域开头提供 static 前置声明。
- 输出完整函数实现，不省略；关键状态、资源和寄存器处理写成中文注释。
- 代码完成后执行 make clean && make 构建，再用 QEMU 和注入测试验证，不要只做静态检查。

[RELY]
可以依赖的东西：
- struct proc_struct 定义于 kern/process/proc.h，字段包括 state、pid、runs、kstack、need_resched、
  parent、mm、context、tf、pgdir、flags、name、list_link、hash_link。
- struct context 依次为 ra、sp、s0～s11，共 14 个 uintptr_t。
- struct trapframe 包含 pushregs gpr（zero/ra/sp/gp/tp/t0～t6/s0～s11/a0～a7）以及
  status、epc、badvaddr、cause，共 36 个机器字。
- 全局变量：proc_list、hash_list[HASH_LIST_SIZE]、idleproc、initproc、current、nr_process。
- 现成接口：kmalloc/kfree、alloc_pages/free_pages、page2kva、KSTACKPAGE/KSTACKSIZE、
  bootstack、boot_pgdir_pa、set_proc_name、find_proc、get_pid、hash_proc、setup_kstack、
  put_kstack、wakeup_proc、list_init、list_add、le2proc、local_intr_save/local_intr_restore。
- 汇编与恢复链符号：kernel_thread_entry、forkret、forkrets、__trapret。
- 状态与错误码：PROC_UNINIT/PROC_RUNNABLE、MAX_PROCESS、CLONE_VM、E_NO_MEM、E_NO_FREE_PROC。
- sstatus 位：SSTATUS_SIE、SSTATUS_SPIE、SSTATUS_SPP；read_csr/write_csr 来自 libs/riscv.h。
- get_pid() 遍历 proc_list；idleproc 不加入 proc_list，所以 initproc 能得到 pid 1。
- init_main 的原型为 static int init_main(void *arg)。

[GUARANTEE]
必须交付：
1. 六个函数的完整实现，签名与 proc.h 一致。
2. 区域开头的两条 static 前置声明，保证 do_fork 能调用定义在其后的 copy_thread/copy_mm。
3. 保留 LAB4 注释、学号、已有辅助函数和 C 的区域。
4. 说明 context.ra/context.sp/tf/pgdir/state/链表与 C 的 switch_to/schedule 的衔接。
5. 真实构建与运行记录，不要编造测试结果。

[SPECIFICATION]
alloc_proc():
  Pre：kmalloc 已初始化。
  Post：返回 PCB 或 NULL；字段为“空白安全状态”：PROC_UNINIT、pid=-1、runs=0、kstack=0、
        need_resched=0、parent=NULL、mm=NULL、tf=NULL、pgdir=boot_pgdir_pa、flags=0、
        context 全 0、name 全 0。
  Case：kmalloc 失败 → NULL，且不改任何全局状态。
  Requirement：不分配内核栈、不分配 PID、不入链表、不置 RUNNABLE。

proc_init():
  Pre：pmm_init/vmm_init 已完成，boot_pgdir_pa 与 kmalloc 可用。
  Post：proc_list 与 hash_list 为空表；idleproc pid=0、RUNNABLE、kstack=bootstack、
        need_resched=1、名称为 "idle"、不入链表；current=idleproc；
        initproc pid=1、parent=idleproc、RUNNABLE、名称为 "init"、已入链表和哈希表。
  Case：alloc_proc 失败或 kernel_thread 返回 <= 0 → panic。
  Requirement：current 必须在创建 initproc 之前设置为 idleproc。

kernel_thread():
  Pre：fn 非空；调用者允许创建内核线程。
  Post：返回正 PID 或负错误码；临时 trapframe 清零后设置 s0=fn、s1=arg、
        epc=kernel_thread_entry、status=(sstatus|SPP|SPIE)&~SIE。
  Case：do_fork 失败 → 原样返回其错误码。
  Requirement：tf 是局部变量，必须由 do_fork→copy_thread 按值复制后才能返回。

do_fork():
  Pre：tf 非空；current 有效；进程数未超限。
  Post：成功时新 PCB 有唯一 PID、内核栈、tf、context、父进程，已入哈希表和 proc_list，
        nr_process 加 1，state=RUNNABLE，返回 PID。
  Case 1：nr_process >= MAX_PROCESS → -E_NO_FREE_PROC，不分配。
  Case 2：alloc_proc 失败 → -E_NO_MEM。
  Case 3：setup_kstack 失败 → kfree(proc)，返回 -E_NO_MEM。
  Case 4：copy_mm 失败 → put_kstack(proc) + kfree(proc)，返回错误码。
  Requirement：PID/哈希/链表/计数在 local_intr_save/restore 保护的同一临界区内完成；
               wakeup_proc 最后调用；失败路径不把半成品暴露给调度器。

copy_thread():
  Pre：proc->kstack 已分配；tf 非空。
  Post：proc->tf 位于 kstack+KSTACKSIZE-sizeof(trapframe)；*proc->tf=*tf；
        tf->gpr.a0=0；tf->gpr.sp=(esp==0)?tf:esp；
        context.ra=forkret；context.sp=tf。
  Requirement：内核线程 esp==0 时 sp 必须指向自己的中断帧，不能为 0。

copy_mm():
  Pre：current->mm == NULL。
  Post：proc->mm=NULL，返回 0。
  Requirement：本实验不做用户地址空间复制；不调用 page_insert/page_remove。

验收：
- make clean && make 成功；
- [Test Process Create] PASS；
- make qemu 输出 pid=1、name="init" 与三条问候；
- make grade 的 Process Create 为 OK，三组 30/30。
````

**spec 如何落实到提示词：**

- spec 的“全局约束”变成 `[PROMPT]` 的修改范围和“保留注释/学号”要求；
- `alloc_proc` 的字段清单直接变成 `[SPECIFICATION]` 的 Post 条件，避免漏字段；
- `proc_init` 的“current 必须在创建 initproc 之前设置”写成 Requirement，这是父子关系正确的前提；
- `kernel_thread` 的 `status` 位运算、`epc`、`s0/s1` 写成可核对的表达式，而不是“构造中断帧”这种模糊描述；
- `do_fork` 的七个步骤、四种失败路径和临界区要求逐条列出，并明确 `wakeup_proc` 最后调用；
- `copy_thread` 的 `context.sp = tf` 和 `tf->gpr.sp = tf` 是两个最容易被写错、且会直接导致首次运行崩溃的点，因此在 spec 中单独强调；
- 验收条件写入 `[SPECIFICATION]` 末尾，并明确 `make clean`、`[Test Process Create] PASS`、`30/30`，防止只做静态检查。

> 按单个函数拆分的提示词与逐函数迭代记录见 [prompt-B.md](prompt-B.md)，格式与 `prompt-C.md` 一致，可直接作为报告附录。

### 4.2.4 核心实现解释

最终实现如下（与 `code/kern/process/proc.c` 的 `//LAB4 function2 2413346` 区域一致）：

```c
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
```

#### 1. `alloc_proc()`：把 PCB 置为“空白且安全”

PCB 里的每个字段都对应一类资源或状态，初始化时必须让后续代码“即使读到了也不会误用”：

- `state = PROC_UNINIT`、`pid = -1`：表示“已创建、未登记、未运行”。调度器只选 `PROC_RUNNABLE`，所以在 `do_fork()` 完成之前，这个 PCB 即使意外出现在链表里也不会被选中。
- `kstack = 0`：内核栈由 `setup_kstack()` 单独分配；这里清零可以在调试时区分“还没分配栈”和“分配了地址 0”。
- `context` 全 0：保证 `context.ra` 在第一次真正设置前为 0，`test_lab4_process_create()` 正是用它检查 `idleproc` 没有伪造上下文。
- `tf = NULL`：`idleproc` 不走 `forkret` 恢复链；只有被 fork 出来的线程才会在 `copy_thread()` 中得到 `tf`。
- `parent = NULL`、`mm = NULL`：内核线程没有用户地址空间；`idleproc` 是进程树的根。
- `pgdir = boot_pgdir_pa`：内核线程共享内核页表。这里保存的是**物理地址**，因为 C 的 `proc_run()` 要把它写入 `satp`：

  ```c
  uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) | (proc->pgdir >> RISCV_PGSHIFT);
  write_csr(satp, satp_value);
  ```

  如果这里误存 `boot_pgdir_va`（内核虚拟地址），`satp` 的 PPN 就会错误，切换页表后立即跑飞。
- `flags = 0`、`name` 全 0：避免未初始化字段影响后续判断和输出。

`list_link`/`hash_link` 故意不初始化：`list_add()`/`hash_proc()` 会完整重写这两个节点的前后指针；提前自环反而会掩盖“忘记入链”的问题。

#### 2. `proc_init()`：idleproc 是“继承现场”，不是 fork 出来的

`idleproc` 的特殊性在于它复用 `kern_init` 启动至今的执行现场：

- `kstack = (uintptr_t)bootstack`：`bootstack` 在 `kern/init/entry.S` 中定义为 `.space KSTACKSIZE` 的数组，`bootstacktop = bootstack + KSTACKSIZE`，启动时的 `sp` 就设在 `bootstacktop`。`kstack` 记录栈底，便于 `put_kstack()` 释放；`test_lab4_process_create()` 也按这个约定检查 `idleproc->kstack == (uintptr_t)bootstack`。
- `need_resched = 1`：让 `cpu_idle()` 第一次检查时立刻调用 `schedule()`，把 CPU 让给 `initproc`。
- `current = idleproc` 必须在 `kernel_thread()` 之前：`do_fork()` 用 `proc->parent = current` 记录父进程，晚设置就会得到错误的父子关系。
- `idleproc` 不加入 `proc_list` 和 `hash_list`：它是调度兜底对象，不是普通链表节点。`schedule()` 在找不到候选线程时直接使用 `idleproc`，而不是从链表头取到它。
- `set_proc_name(idleproc, "idle")` 与 `set_proc_name(initproc, "init")`：后者是 `make grade` 检查字符串 `this initproc, pid = 1, name = "init"` 的一部分。

`initproc` 的 pid 为什么是 1：`get_pid()` 首次调用时从 `MAX_PID` 回绕到 `last_pid = 1`，在 `proc_list` 中查重；此时 `proc_list` 仍是空表（`idleproc` 未入链），没有冲突，所以返回 1。`kernel_thread()` 返回后，`find_proc(pid)` 又能通过 `hash_list` 找到它。

#### 3. `kernel_thread()`：把函数包装成“第一次从 trap 返回”的现场

`kernel_thread()` 不直接调用 `fn`，而是构造一个“看起来刚从 trap 返回”的中断帧：

- `tf.gpr.s0 = fn`、`tf.gpr.s1 = arg`：`kernel_thread_entry` 的汇编是

  ```asm
  kernel_thread_entry:
      move a0, s1
      jalr s0
  ```

  因此 `s0` 是入口函数，`s1` 是参数，进入函数前把 `s1` 搬到 `a0`。
- `tf.epc = kernel_thread_entry`：`sret` 后从内核线程入口开始执行。
- `tf.status = (sstatus | SPP | SPIE) & ~SIE`：
  - `SPP = 1`：`sret` 返回到 S 态（内核线程只运行在内核态）；
  - `SPIE = 1`：`sret` 会把 `SPIE` 复制到 `SIE`，线程开始执行后中断是开启的；
  - `SIE = 0`：构造现场期间不响应中断，避免“现场还没复制完就被调度”。
- `do_fork(clone_flags | CLONE_VM, 0, &tf)`：内核线程共享内核地址空间，所以补上 `CLONE_VM`；`stack = 0` 是给 `copy_thread()` 的信号——“使用新线程自己的内核栈”。
- `tf` 是栈上局部变量：`do_fork()` 通过 `copy_thread()` 做 `*proc->tf = *tf` 的按值复制，因此 `kernel_thread()` 返回后局部变量销毁不会影响新线程。

#### 4. `do_fork()`：资源顺序、可见性与失败回滚

`do_fork()` 的顺序是“先分配、再构造、最后登记”：

1. **PCB**：`alloc_proc()`；失败返回 `-E_NO_MEM`。
2. **父进程**：`proc->parent = current`。
3. **内核栈**：`setup_kstack()` 分配 `KSTACKPAGE = 2` 个连续物理页，`kstack = page2kva(page)`；失败时只释放 PCB。
4. **地址空间**：`copy_mm()` 本实验恒返回 0；失败时释放内核栈和 PCB。
5. **现场**：`copy_thread()` 在**新线程自己的**内核栈上放 `tf`，并写 `context`。
6. **登记**：`get_pid()`、`hash_proc()`、`list_add()`、`nr_process++` 放在 `local_intr_save/restore` 的同一个临界区里。原因有三点：
   - `get_pid()` 要遍历 `proc_list` 查重，若中途被调度打断，可能分配出重复 PID；
   - 哈希表和链表必须同时可见，否则 `find_proc(pid)` 可能找不到已经出现在链表里的线程；
   - `nr_process` 与链表长度要保持一致。
7. **就绪**：`wakeup_proc(proc)` 把状态从 `PROC_UNINIT` 改为 `PROC_RUNNABLE`，放在临界区之后。这样即使中断在登记后、唤醒前发生，调度器看到的也只是一个 `PROC_UNINIT` 节点，不会选中它。

失败路径用标签自然串联：

```text
alloc_proc 失败 ───────────────→ fork_out
setup_kstack 失败 → bad_fork_cleanup_proc → kfree(proc) → fork_out
copy_mm 失败     → bad_fork_cleanup_kstack → put_kstack → kfree → fork_out
```

`bad_fork_cleanup_kstack` 故意“贯穿”到 `bad_fork_cleanup_proc`，保证内核栈和 PCB 都被释放；而 `setup_kstack` 失败时直接跳到 `kfree`，避免释放一个从未分配的栈。

#### 5. `copy_thread()`：首次运行现场的两个关键指针

```c
proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1;
*(proc->tf) = *tf;
proc->tf->gpr.a0 = 0;
proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;
proc->context.ra = (uintptr_t)forkret;
proc->context.sp = (uintptr_t)(proc->tf);
```

- **`tf` 的位置**：`kstack + KSTACKSIZE` 是栈顶，减去一个 `struct trapframe`（288 字节）就是中断帧基址。中断帧之上没有其他数据，之下才是线程函数可用的栈空间。
- **`a0 = 0`**：`fork()` 在父进程返回子 PID，在子进程返回 0；这里通过中断帧把新线程的 `a0` 设为 0。
- **`tf->gpr.sp = tf`（`esp == 0` 时）**：这是最关键的一行。`__trapret` 的 `RESTORE_ALL` 最后会执行 `LOAD x2, 2*REGBYTES(sp)` 恢复 `sp`；如果不设置，`sp` 会是 0，`sret` 后进入 `kernel_thread_entry` 立刻踩空。设置成 `tf` 后，线程函数在 `tf` 之下正常使用内核栈。
- **`context.sp = tf`**：`switch_to()` 恢复 `sp = tf` 后执行 `ret` 跳到 `context.ra = forkret`。`forkret` 是普通 C 函数，它的栈帧会向 `tf` 之下增长，不会覆盖中断帧。如果把 `context.sp` 设成 `kstack + KSTACKSIZE`，`forkret` 的栈帧就会落在 `tf` 所在的最后 288 字节内，覆盖 `status/epc` 等字段，导致恢复出错。
- **`context.ra = forkret`**：`switch_to()` 的 `ret` 直接进入 `forkret()`，后者调用 `forkrets(current->tf)`，把 `sp` 设为中断帧并跳到 `__trapret`，从而接上完整恢复链。

#### 6. `copy_mm()`：本阶段的“空实现”也是有约束的接口

```c
assert(current->mm == NULL);
proc->mm = NULL;
return 0;
```

本实验创建的是内核线程：它们共享内核地址空间，`current->mm` 本来就是 `NULL`，所以不需要复制页表。保留 `copy_mm()` 的函数形态和失败返回路径，是为了实验五以后能在这里接入真正的用户地址空间复制；当前阶段它必须“成功返回 0”，否则 `do_fork()` 会走错误清理路径，创建不出线程。

#### 7. 与 C 的接口对照

| B 写出的字段 | C 的使用方式 | 约束 |
|---|---|---|
| `state = PROC_RUNNABLE` | `schedule()` 只选 `PROC_RUNNABLE` | 必须最后设置 |
| `list_link` 已入 `proc_list` | `schedule()` 用 `list_next()` 遍历 | `idleproc` 不入链 |
| `hash_link` + `pid` | `find_proc()` 按 pid 查找 | `pid` 在临界区内分配 |
| `pgdir = boot_pgdir_pa` | `proc_run()` 写 `satp` | 必须是物理地址 |
| `context.ra = forkret` | `switch_to()` 的 `ret` 目标 | 地址不能错 |
| `context.sp = tf` | `switch_to()` 恢复的栈 | 不能是栈顶 |
| `tf->epc = kernel_thread_entry` | `__trapret` 的 `sret` 目标 | 汇编符号必须一致 |
| `tf->gpr.s0/s1` | `kernel_thread_entry` 的 `jalr s0` / `move a0,s1` | 参数传递约定 |
| `tf->gpr.sp = tf` | `RESTORE_ALL` 恢复 `sp` | 不能为 0 |
| `tf->status` 的 SPP/SPIE/SIE | `sret` 的特权级与中断状态 | SPP=1、SPIE=1、SIE=0 |

### 4.2.5 实现迭代过程

本模块的六个函数共完成 1 次代码生成，随后经历 2 次构建迭代。功能逻辑一次成型，两次修正都发生在“声明/构建”层面，没有出现运行期的状态机或现场构造错误。

---

##### 第一次迭代

**生成内容：**

按文档顺序生成 `alloc_proc()`、`proc_init()`、`kernel_thread()`、`do_fork()`、`copy_thread()`、`copy_mm()` 六个函数，保留 `//LAB4 function2` 标记并填写学号 `2413346`。

**遇到的问题：**

- 问题 1：`make` 编译 `proc.c` 时报

  ```text
  warning: implicit declaration of function 'copy_mm'
  warning: implicit declaration of function 'copy_thread'
  error: static declaration of 'copy_thread' follows non-static declaration
  error: static declaration of 'copy_mm' follows non-static declaration
  ```

  原因：`copy_thread()`/`copy_mm()` 是 `static` 辅助函数，按文档顺序定义在 `do_fork()` 之后，而骨架中没有为它们提供前置声明；编译器在 `do_fork()` 中先看到隐式声明（默认外部链接），随后又看到 `static` 定义，链接属性冲突。

- 问题 2：修正声明后再次 `make`，链接报

  ```text
  undefined reference to `page_insert'
  undefined reference to `page_remove'
  undefined reference to `schedule'
  ```

  原因：仓库里的 `obj/` 残留了从其他工作目录（日志中为 `/home/a/OS/lab4/code`）带来的旧目标文件，`make` 认为它们是最新的，只重新编译了 `proc.c`，没有重新编译 A 的 `pmm.c` 和 C 的 `sched.c`。这不是代码逻辑错误，而是构建缓存问题。

**问题解决策略：**

- 针对问题 1：在 `//LAB4 function2` 区域开头增加两条 `static` 前置声明，保留文档要求的函数定义顺序。
- 针对问题 2：执行 `make clean && make`，强制所有源文件重新编译；之后不再复用旧 `obj/`。
- 提示词同步补充：
  - `[PROMPT]` 增加“copy_thread/copy_mm 定义在 do_fork 之后，必须在区域开头提供 static 前置声明”；
  - `[PROMPT]` 的验证步骤明确“执行 `make clean && make`，不要复用旧 obj”；
  - `[SPECIFICATION]` 的验收条件保留 `[Test Process Create] PASS`、`make qemu` 三条输出和 `30/30`。

**结果：**

修正后 `proc.c` 编译通过，`make clean && make` 完成链接，仅有框架自带的 `kern/mm/kmalloc.c:92` 的 `-Wint-conversion` 警告（该警告来自已有代码，与本模块无关）。

---

##### 第二次迭代

**验证内容：**

在干净构建的基础上执行：

```bash
make clean
make
timeout 18 qemu-system-riscv64 -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000
```

**结果：**

- 内核正常启动，`check_pgdir()`、`check_boot_pgdir()`、`check_vmm()` 全部通过；
- 输出 `this initproc, pid = 1, name = "init"`，说明 `idleproc`/`initproc` 创建成功，首次切换进入 `init_main`；
- 输出两条 `To U:` 问候，说明参数 `"Hello world!!"` 通过 `s1 → a0` 正确传递；
- `init_main` 返回后进入 `do_exit()` 的 `panic("process exit!!.")`。这是框架保留的占位实现，属于本阶段预期行为，不是创建模块的缺陷。

**评分验证：**

```bash
make grade
```

输出：

```text
  -check PMM:                                OK
  -check Process Create:                     OK
  -check Schedule:                           OK
Total Score: 30/30
```

其中 `check Process Create` 对应本模块。注入测试的完整运行还额外打印了 `[Test Process Create] PASS` 和 `[Test Schedule] PASS`（见 `report/images/lab4_B_process_create.log`）。

---

**关键改进点总结：**

1. 在 `do_fork()` 之前补充 `copy_thread`/`copy_mm` 的 `static` 前置声明，使函数定义顺序与声明一致。
2. 构建前执行 `make clean`，避免复用其他路径的旧 `obj/`，保证 A/B/C 三人的代码都参与编译。
3. 在 spec 与提示词中显式写出 `context.sp = tf`、`tf->gpr.sp = tf`、`pgdir = boot_pgdir_pa` 三个“现场关键值”，减少首次运行类错误。
4. 用 `[Test Process Create] PASS`、`make qemu` 输出和 `make grade 30/30` 三层证据验证，而不是只看编译通过。

### 4.2.6 验证情况

#### 1. 检查项与结果

| 检查项 | 命令/方法 | 预期 | 实际 | 证据 |
|---|---|---|---|---|
| 编译与链接 | `make clean && make` | 成功，无本模块错误 | 成功，仅 `kmalloc.c` 既有警告 | `bin/kernel` 生成 |
| 正常启动 | QEMU 加载 `bin/ucore.img` | 通过 PMM/VMM 自检 | 通过 | `images/lab4_B_qemu.log` |
| initproc 创建 | QEMU 输出 | `pid = 1`、`name = "init"` | 一致 | 同上 |
| 参数传递 | QEMU 输出 | `Hello world!!` | 一致 | 同上 |
| 创建组测试 | 注入 `test_lab4_process_create()` | `[Test Process Create] PASS` | 通过 | `images/lab4_B_process_create.log` |
| 调度联调 | 注入 `test_lab4_schedule()` | `[Test Schedule] PASS` | 通过 | 同上 |
| 评分 | `make grade` | 三组 OK、30/30 | 一致 | `images/lab4_B_grade.log` |

#### 2. 创建组测试的断言覆盖

`tools/test_lab4.c` 的 `test_lab4_process_create()` 在本模块完成后检查：

```c
assert(current == idleproc);
assert(idleproc != NULL && idleproc->pid == 0);
assert(idleproc->state == PROC_RUNNABLE);
assert(idleproc->kstack == (uintptr_t)bootstack);
assert(idleproc->parent == NULL && idleproc->mm == NULL);
assert(idleproc->tf == NULL && idleproc->runs == 0);
assert(idleproc->flags == 0 && idleproc->context.ra == 0);

assert(initproc != NULL && initproc->pid == 1);
assert(initproc->state == PROC_RUNNABLE);
assert(initproc->parent == idleproc && initproc->mm == NULL);
assert(initproc->context.ra != 0 && initproc->context.sp != 0);
```

这些断言正好覆盖本模块最容易出错的状态：

- `current == idleproc`：`proc_init()` 的赋值顺序；
- `idleproc->pid == 0`、`initproc->pid == 1`：PID 分配与 `get_pid()` 的链表遍历；
- `idleproc->kstack == bootstack`：idleproc 复用启动栈；
- `tf == NULL`、`context.ra == 0`：`alloc_proc()` 的空白初始化；
- `initproc->parent == idleproc`：`do_fork()` 中 `parent = current` 的时机；
- `initproc->context.ra != 0 && sp != 0`：`copy_thread()` 的首次运行现场已建立。

#### 3. 实际运行输出

正常启动（节选，完整见 `images/lab4_B_qemu.log`）：

```text
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded!
check_vmm() succeeded.
++ setup timer interrupts
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
kernel panic at kern/process/proc.c:208:
    process exit!!.
```

注入测试（节选，完整见 `images/lab4_B_process_create.log`）：

```text
[Test PMM] PASS
check_vma_struct() succeeded!
check_vmm() succeeded.
[Test Process Create] PASS
++ setup timer interrupts
[Test Schedule] PASS
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
kernel panic at kern/process/proc.c:209:
    process exit!!.
```

评分（完整见 `images/lab4_B_grade.log`）：

```text
lab4 injection complete
...
  -check PMM:                                OK
  -check Process Create:                     OK
  -check Schedule:                           OK
Total Score: 30/30
```

> 说明：普通启动日志中的 panic 位于 `proc.c:208`，注入测试中的 panic 位于 `proc.c:209`，差异来自注入脚本在文件头部增加了一行 `#include`，不是代码不同。

#### 4. 仍需 C 在最终版本确认的内容

- 在合并 A、B、C 后的**同一份**代码上重新执行 `make qemu` 和 `make grade`，保存最终截图；本报告的日志来自 B 完成后的当前工作版本（A、C 代码已合入），建议 C 以最终提交版本为准更新证据。
- 首次运行现场（`context.ra/sp`、`tf`、`pgdir`）已按第 4.2.7 节与 C 的 `switch_to()`/`proc_run()` 对齐，最终以 `[Test Schedule] PASS` 和 `initproc` 输出作为联合验证。
- `make grade` 会临时注入 `kern/test`，最终提交的仓库应保持无 `kern/test`、无旧 `obj/` 的干净状态。

### 4.2.7 首次运行现场与 C 的衔接约定

本节是 B 交付给 C 的“现场说明”，也是两人联调时排查首次运行问题的对照表。

#### 1. 两个线程的最终现场

| 字段 | `idleproc` | `initproc` |
|---|---|---|
| `pid` | 0 | 1 |
| `state` | `PROC_RUNNABLE` | `PROC_RUNNABLE`（`wakeup_proc` 设置） |
| `kstack` | `(uintptr_t)bootstack` | `page2kva(alloc_pages(2))` |
| `parent` | `NULL` | `idleproc` |
| `mm` | `NULL` | `NULL` |
| `pgdir` | `boot_pgdir_pa` | `boot_pgdir_pa` |
| `tf` | `NULL` | `(kstack + KSTACKSIZE) - sizeof(struct trapframe)` |
| `context.ra` | 0 | `forkret` |
| `context.sp` | 0 | `tf` |
| `need_resched` | 1 | 0（需要让出 CPU 时由线程自身置 1） |
| `runs` | 0 | 0（首次调度后增加） |
| `flags` | 0 | 0 |
| `name` | `"idle"` | `"init"` |
| `proc_list`/`hash_list` | 不加入 | 均加入 |

`initproc` 的中断帧内容：

| 中断帧字段 | 值 | 用途 |
|---|---|---|
| `gpr.s0` | `init_main` | `kernel_thread_entry` 的 `jalr s0` 目标 |
| `gpr.s1` | 指向 `"Hello world!!"` | `kernel_thread_entry` 搬到 `a0` 的参数 |
| `gpr.a0` | 0 | 子线程的“fork 返回值” |
| `gpr.sp` | `tf` 自身地址 | `__trapret` 恢复的栈指针 |
| `epc` | `kernel_thread_entry` | `sret` 的返回地址 |
| `status` | `(sstatus \| SPP \| SPIE) & ~SIE` | 返回 S 态、返回后开中断 |
| 其余 GPR | 0 | 清零，避免残留 |

#### 2. 首次运行的完整衔接链

```text
C: schedule()
   └─ 选择 initproc（PROC_RUNNABLE，已在 proc_list 中）
C: proc_run(initproc)
   ├─ current = initproc
   ├─ satp = (SATP_MODE_SV39 << 60) | (initproc->pgdir >> 12)
   ├─ sfence.vma
   └─ switch_to(&idleproc->context, &initproc->context)
         ├─ 保存 idleproc 的 ra/sp/s0-s11
         └─ 恢复 initproc 的 ra=forkret、sp=tf、s0-s11
C: ret（在 switch_to 末尾）
   └─ 跳到 B 设置的 context.ra = forkret
B/框架: forkret()
   └─ forkrets(current->tf)
         ├─ move sp, a0   （sp = tf）
         └─ j __trapret
框架: __trapret / RESTORE_ALL
   ├─ csrw sstatus, tf->status
   ├─ csrw sepc, tf->epc
   ├─ 恢复 x1、x3-x31（含 s0=init_main、s1=arg、a0=0）
   ├─ 最后恢复 x2（sp = tf）
   └─ sret
B/框架: kernel_thread_entry
   ├─ move a0, s1    （a0 = "Hello world!!"）
   └─ jalr s0        （调用 init_main）
B: init_main("Hello world!!")
   └─ 打印 pid/name/问候，返回 0
   └─ jal do_exit → panic（本阶段占位）
```

#### 3. B/C 的责任边界

| 约定项 | B 负责准备 | C 负责使用/恢复 |
|---|---|---|
| `proc_struct`、`context` | 沿用字段含义，不修改布局 | `switch.S` 偏移严格对应 14 个字段 |
| `context.ra` | 首次运行设为 `forkret` | `switch_to` 末尾 `ret` 跳到该地址 |
| `context.sp` | 设为 `tf`（不是栈顶） | 恢复 `sp` 后 `forkret` 的栈帧不覆盖 `tf` |
| `tf` 与 `tf->gpr.sp` | 放在内核栈顶下方，`gpr.sp = tf` | `__trapret` 恢复 `sp`、`sret` 返回 |
| 中断帧入口/参数 | `epc = kernel_thread_entry`、`s0/s1` | 恢复后进入入口并传参 |
| `pgdir` | 存 `boot_pgdir_pa`（物理地址） | `satp` 写入 `(8<<60) \| (pgdir>>12)`，`sfence.vma` |
| `state`/链表 | 所有资源就绪后置 `PROC_RUNNABLE` | 只选 `PROC_RUNNABLE`，处理回绕与 `idleproc` 兜底 |
| `need_resched` | `idleproc` 初始置 1 | `schedule()` 清除并处理调度 |

#### 4. 联调时最容易出现的四类错误

1. **`tf->gpr.sp` 没设置**：`RESTORE_ALL` 恢复出 `sp = 0`，`sret` 后 `kernel_thread_entry` 立即访存异常。现象是首次切换后立刻 trap/panic。
2. **`context.sp` 设成 `kstack + KSTACKSIZE`**：`forkret` 的栈帧覆盖 `tf` 尾部的 `status/epc/badvaddr/cause`，`__trapret` 恢复出错误的 `sstatus` 或 `sepc`。现象是第一次 `sret` 跳到错误地址或特权级异常。
3. **`pgdir` 存了虚拟地址**：`satp` 的 PPN 错误，`proc_run()` 写 `satp` 后下一条指令取指失败。现象是切换页表后 QEMU 无输出或反复异常。
4. **先置 `PROC_RUNNABLE` 再入链表/分配 PID**：调度器可能选中一个 `pid = -1`、尚未入哈希表的半成品。现象是 `find_proc()` 找不到、`schedule()` 行为异常，或 `get_pid()` 重复。

以上四点均已在本实现中按“资源就绪 → 登记 → 最后唤醒”的顺序规避，并通过 `[Test Process Create] PASS`、`[Test Schedule] PASS` 和 `initproc` 输出验证。

---

## 五、测试与验证（B 提供材料，供 C 并入）

### 5.B.1 创建组检查覆盖的内容

上传代码的 `make grade` 把 Lab4 分成 PMM、Process Create、Schedule 三组，每组 10 分。B 负责的 Process Create 组由 `tools/inject.py` 在 `proc_init()` 末尾注入 `test_lab4_process_create()`，检查：

1. `current == idleproc`；
2. `idleproc->pid == 0`、`state == PROC_RUNNABLE`、`kstack == bootstack`；
3. `idleproc->parent == NULL`、`mm == NULL`、`tf == NULL`、`runs == 0`、`flags == 0`、`context.ra == 0`；
4. `initproc->pid == 1`、`state == PROC_RUNNABLE`；
5. `initproc->parent == idleproc`、`mm == NULL`；
6. `initproc->context.ra != 0`、`context.sp != 0`。

评分脚本检查的字符串：

```text
[Test Process Create] PASS
```

### 5.B.2 检查命令与真实记录

```bash
cd code
make clean && make
make grade
```

`make grade` 会自动完成“复制到临时目录 → 注入测试 → 构建 → 运行一次 QEMU 并收集输出 → 用同一份输出做三组正则检查”，最终输出：

```text
  -check PMM:                                OK
  -check Process Create:                     OK
  -check Schedule:                           OK
Total Score: 30/30
```

B 另外保存了三份原始日志：

| 文件 | 内容 |
|---|---|
| `report/images/lab4_B_qemu.log` | 普通 `make qemu` 启动输出（未注入测试） |
| `report/images/lab4_B_process_create.log` | 注入测试后的完整输出，含 `[Test Process Create] PASS` |
| `report/images/lab4_B_grade.log` | `make grade` 完整评分日志 |

> 交付前，B 又把 `code/` 复制到全新目录，执行 `make clean && make && make grade` 复验，结果同为 `30/30`，确认结果不依赖旧 `obj/` 或本机残留文件。

### 5.B.3 交给 C 的合并注意

- 最终报告中的截图应来自 A/B/C 合并后的同一版本；B 的日志可作为“创建组已通过”的过程证据，但不能替代最终版本的 `make grade` 截图。
- 若 C 重新运行 `make grade`，请先确认仓库没有残留 `kern/test/` 和旧 `obj/`；`make grade` 自己会在临时目录注入测试，不需要手工保留。
- 合并 `report_A.md` 时，把“功能模块二（B 负责）”的占位段落替换为本文件第 4.2.1～4.2.7 节；编号可按 C 的统一格式调整。
- `make qemu` 末尾的 `panic("process exit!!.")` 是本实验 `do_exit()` 的占位行为；不要把它误判为创建失败。判断依据是 panic 之前已经打印了 `initproc, pid = 1` 和两条 `To U:`。

---

## 六、实验总结与收获（B 提供部分）

### 6.B.1 对操作系统的理解（PCB、内核栈与线程创建）

**本实验知识点与 OS 原理的对应：**

| 本实验知识点 | OS 原理中的概念 | 含义、关系与差异 |
|---|---|---|
| `struct proc_struct` | 进程控制块（PCB） | 本实验用简化 PCB 统一表示线程/进程；原理课的 PCB 还包含文件表、信号、记账、权限等 |
| `kstack` + `bootstack` | 内核栈 / 特权级栈 | 每个线程有独立内核栈，trap 时切换到内核栈；本实验只有 2 页，且内核线程直接用它运行 |
| `struct trapframe` | 中断/异常现场 | 本实验用它保存 36 个机器字，并作为首次运行的“模板”；原理课还会区分用户现场与内核现场 |
| `struct context` | 上下文切换现场 | 只保存 callee-saved 的 `ra/sp/s0-s11`；caller-saved 由编译器在调用点保存 |
| `fork`/`do_fork` | 进程复制 | 本实验是“复制现场 + 共享内核地址空间”的简化 fork；原理课还会讲写时复制、独立地址空间 |
| `kernel_thread` | 内核线程创建 | 本实验用中断帧 + `kernel_thread_entry` 构造首次运行；原理课常用内核栈上的启动例程 |
| `idleproc`/`initproc` | 空闲进程 / 1 号进程 | 本实验 `idleproc` 复用启动现场，`initproc` 是第一个 fork 出来的线程 |
| `get_pid` + 哈希表 + 链表 | PID 分配与进程组织 | 本实验用线性链表 + 哈希表；原理课还会讲 PID 位图、命名空间、多核锁 |
| `PROC_UNINIT/RUNNABLE/...` | 进程状态机 | 本实验只有四态；原理课还会讲创建、终止、挂起、等待、换出等更细状态 |

**本实验尚未覆盖的 OS 原理：**

1. 用户进程的独立地址空间与真正的 `copy_mm()`（本实验 `mm` 恒为 `NULL`）。
2. 写时复制（COW）、按需分页、缺页异常与页面置换。
3. 完整的进程退出、父子回收、僵尸态处理和资源归还（本实验 `do_exit()` 仍是 `panic` 占位）。
4. 优先级调度、多级反馈队列、多核负载均衡与实时调度。
5. 进程间通信、信号、文件描述符表、权限与安全。
6. 完整的用户态/内核态切换与系统调用路径（本实验重点是内核线程）。

### 6.B.2 AI 协作开发的经验（B）

1. **先读骨架，再写提示词。** 本模块的函数签名、结构体字段、汇编符号都已在仓库里固定；把 `proc.h`、`trapentry.S`、`switch.S`、`entry.S` 读清楚后，提示词才能写出准确的 `context.ra/sp`、`tf->gpr.s0/s1` 约定，而不是泛泛地说“实现 fork”。
2. **把“顺序”和“可见性”写进 spec。** 例如“`current` 必须在创建 `initproc` 之前设置”“`PROC_RUNNABLE` 必须最后设置”“PID/哈希/链表在同一个临界区完成”。这些约束比“正确实现”更能防止并发和初始化顺序错误。
3. **把最容易崩的寄存器值写成可核对的表达式。** `context.sp = tf`、`tf->gpr.sp = tf`、`pgdir = boot_pgdir_pa` 是本模块的三个“生死值”；在提示词中直接写出表达式，比让 AI 自行推断更可靠。
4. **区分“代码 bug”和“构建环境问题”。** 本次两次失败分别是“缺前置声明”和“复用了其他路径的旧 `obj/`”，都不是运行期逻辑错误。报告如实记录这两类问题，并给出 `make clean` 的复现/修复步骤，比编造一个“现场构造 bug”更有参考价值。
5. **验证要分层。** 编译通过只说明语法和链接；`make qemu` 证明创建和首次切换真的发生；注入测试证明字段断言成立；`make grade 30/30` 证明评分脚本认可。四层证据缺一不可。
6. **保留原始日志。** 把 `make qemu`、注入测试和 `make grade` 的输出原样保存，既方便 C 合并，也能在结果不一致时快速定位是“代码变了”还是“环境变了”。

---

## 附录：B 的关键日志文件

- `report/images/lab4_B_qemu.log`：普通启动，含 `initproc` 输出与 `do_exit` 占位 panic。
- `report/images/lab4_B_process_create.log`：注入测试，含 `[Test Process Create] PASS`、`[Test Schedule] PASS`。
- `report/images/lab4_B_grade.log`：`make grade`，含三组 `OK` 与 `Total Score: 30/30`。
- `report/prompt-B.md`：本模块六个函数的最终提示词与逐函数迭代记录（与 `prompt-C.md` 同格式）。

---

## 附录 B：B 的基本信息与环境（供 A/C 填入公共章节）

| 项目 | 内容 |
|---|---|
| 姓名-学号 | 2413346-易响（B） |
| 负责模块 | 功能模块二：进程创建及初始化（`kern/process/proc.c` 的 `//LAB4 function2`） |
| AI 编程工具 | DeepSeek Harness（终端 Agent） |
| 底层模型 | DeepSeek-V4-Flash（deepseek-flash） |
| 验证日期 | 2026-11-13 |

**B 的编译与运行环境：**

| 项目 | 配置 |
|---|---|
| 操作系统 | Ubuntu 22.04.5 LTS（Linux 6.8.0-138-generic） |
| 交叉编译器 | `riscv64-unknown-elf-gcc` 10.2.0（SiFive GCC-Metal 10.2.0-2020.12.8） |
| 编译器路径 | `/home/agony/riscv/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/bin` |
| 模拟器 | QEMU 4.1.1（`/home/agony/Desktop/qemu-4.1.1/riscv64-softmmu/qemu-system-riscv64`，已通过 `~/.local/bin` 加入 PATH） |
| 构建工具 | GNU make |
| 辅助脚本 | Python 3.10.12（`make grade` 的 `tools/inject.py`） |
| 硬件体系 | RISC-V 64 位，Sv39 分页，QEMU `virt` 机器 |

B 使用的验证命令：

```bash
cd code
make clean && make
make grade
```

> 合并提示：`report_A.md` 中的 `[B 学号-姓名]` 应替换为 `2413346-易响`；`report_A.md` 的“AI 工具与模型”表中 B 的行应替换为 `DeepSeek Harness / DeepSeek-V4-Flash`。  
> 若 C 使用的 QEMU 不是 4.1.1，需先统一版本再截图；本报告的日志来自 QEMU 4.1.1。
