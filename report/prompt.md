### 功能模块：模块一——用户态系统调用

**负责人：** 2411033-季艾佳
#### 最终提示词

以下是最终使用的提示词，与第一次实际执行的输入完全相同：

````markdown
[PROMPT]
我正在实现 RISC-V ucore Lab5 的功能模块一：用户态系统调用。请在独立副本中修改 kern/syscall/syscall.c 和 kern/trap/trap.c，将用户 ecall、系统调用分发和九个系统调用包装函数接通。

实现方式：
- 先读下面列出的参考文件，使用项目真实的字段、编号和函数签名。
- 直接修改实际文件，保留 Lab5 标记、现有中断处理、trap() 的现场管理和退出及调度逻辑。
- 可以增加本文件内部的 static 辅助函数和必要头文件。不要改系统调用号、公开接口、Makefile、用户库、测试或其他成员负责的进程管理函数。
- 本次只做模块一，不实现 COW，也不重新实现已经适配的 RESTORE_ALL。
- 生成后先编译两个目标文件，再执行可用的模块测试，记录真实输出；其他模块未完成导致的链接或运行限制单独说明。

[RELY]
可以依赖的东西：
- 先读 kern/syscall/syscall.c、kern/syscall/syscall.h、kern/trap/trap.c、kern/trap/trap.h、kern/process/proc.h、kern/mm/vmm.h、kern/mm/vmm.c、kern/mm/pmm.h、kern/mm/mmu.h、libs/unistd.h、libs/error.h、user/libs/syscall.c 和 tools/test_lab5.c。
- 本项目 ABI：a0 是系统调用号，a1 到 a5 是参数，返回值写回 a0；不要使用 Linux 的 a7 调用号约定。
- current 指向当前 PCB，current->tf 指向正在处理的中断帧；中断帧使用 gpr、status、epc、tval、cause 字段。
- proc.h 已声明 do_exit(int)、do_fork(uint32_t, uintptr_t, struct trapframe *)、do_wait(int, int *)、do_execve(const char *, size_t, unsigned char *, size_t)、do_yield(void)、do_kill(int)。这些接口由其他模块实现，当前基线可能尚未补齐。
- 可使用 SYS_*、CAUSE_USER_ECALL、SSTATUS_SPP、E_INVAL、E_KILLED、user_mem_check、cputchar、cprintf、print_trapframe、trap_in_kernel，以及现有 Sv39 页表宏。
- 当前 pmm.h 只有 print_pgdir() 声明，没有实现。sys_pgdir 必须真正输出当前页表信息，可以在 syscall.c 内增加只读的 Sv39 遍历辅助函数，不要只打印成功文字或调用未实现的接口。
- proc->pgdir 保存根页表物理地址，访问页表内存需要转换为内核虚拟地址；Sv39 中非叶项与叶项要区分，高层叶项可能映射大页。

[GUARANTEE]
必须交付：
void exception_handler(struct trapframe *tf);
void syscall(void);
static int sys_exit(uint64_t arg[]);
static int sys_fork(uint64_t arg[]);
static int sys_wait(uint64_t arg[]);
static int sys_exec(uint64_t arg[]);
static int sys_yield(uint64_t arg[]);
static int sys_kill(uint64_t arg[]);
static int sys_getpid(uint64_t arg[]);
static int sys_putc(uint64_t arg[]);
static int sys_pgdir(uint64_t arg[]);

确保 syscalls[] 引用静态函数之前已有声明或定义。输出本次完整生成代码、修改位置、实际验证命令及结果，不省略函数体。

[SPECIFICATION]
1. exception_handler
Pre-Condition：tf 是有效中断帧；系统调用路径上 current->tf 已由 trap() 指向 tf。
Post-Condition：异常按类型处理，系统调用完成后能从 ecall 的下一条指令继续执行。
Case 1：CAUSE_USER_ECALL，将 epc 增加 4，然后调用 syscall()，不重复推进返回地址。
Case 2：用户非法指令、非法访存或其他未处理的用户异常，输出诊断并通过 do_exit 终止当前进程，不跳过错误继续执行，不使整个内核 panic。
Case 3：内核断点和非法指令保留原有诊断及按 2/4 字节推进 epc 的行为；其他无法处理的内核异常输出现场并 panic。
Requirements：不要用读取用户故障地址的方式判断错误指令长度；页故障的 COW 扩展留到后续任务。

2. syscall
Pre-Condition：current 和 current->tf 有效，调用号和参数已保存在中断帧中。
Post-Condition：合法请求调用对应表项，并将 int 返回值按 RV64 有符号结果写入 a0。
Case 1：调用号在表内且表项非空，按顺序取 a1 到 a5，调用处理函数。
Case 2：编号越界或表项未实现，返回 -E_INVAL，不越界访问，不 panic。
Requirements：使用中断帧中的原始调用号进行范围判断，调用处理函数前保存好参数。

3. sys_exit、sys_yield、sys_kill、sys_getpid
Pre-Condition：参数数组有效，current 有效。
Post-Condition：sys_exit 传递 arg[0] 的退出码；sys_yield 调用 do_yield；sys_kill 传递 arg[0] 的 PID；sys_getpid 返回 current->pid。需要转接的函数保留下层返回值，正常退出无需构造额外返回路径。

4. sys_fork
Pre-Condition：current->tf 保存父进程的用户执行现场。
Post-Condition：调用 do_fork，clone_flags 为 0，stack 使用当前中断帧保存的用户 sp，中断帧使用 current->tf；不在包装层重复创建或登记进程。

5. sys_wait、sys_exec
Pre-Condition：参数来自用户寄存器，用户地址不可信。
Post-Condition：sys_wait 将 arg[0]、arg[1] 转为 PID 和退出码存储指针；sys_exec 将 arg[0] 到 arg[3] 转为名称、名称长度、二进制地址和大小，交给对应 do_* 接口。
Case 1：wait 的退出码指针为 NULL，允许不接收退出码；非空时必须检查 int 大小的可写范围。
Case 2：exec 在访问用户数据前检查名称和二进制范围可读；参数语义、资源分配和清理由 do_execve 负责。
Case 3：用户内存范围或权限不合法，返回 -E_INVAL，不直接解引用该地址。下层仍须对真正执行的用户内存访问负责，包装层检查不能替代下层检查。

6. sys_putc、sys_pgdir
Pre-Condition：当前进程有效；查看页表时页表结构有效且可由内核访问。
Post-Condition：sys_putc 使用 cputchar 输出 arg[0] 的低 8 位并返回 0；sys_pgdir 只读遍历当前 Sv39 页表，输出实际有效项的级别、虚拟地址范围、物理地址和权限，成功返回 0，不分配、修改或释放映射。
Case 1：页表根不存在时返回 -E_INVAL；有根但无有效项时可以输出根信息并正常结束。
Case 2：非叶项继续向下查，叶项直接输出，包括高层大页映射，虚拟地址按 Sv39 规则符号扩展。

7. 验证
- 使用项目工具链编译 syscall.o 和 trap.o，检查声明、类型和链接依赖。
- 运行现有 test_lab5_syscall，检查 getpid、epc 增加 4、非法编号返回 -E_INVAL；补查参数转接、空表项、用户指针和页表输出。

````

# B 模块最终提示词

> 说明：下面是实际用于生成本次 Lab5 模块二、模块三代码的有效提示词版本。
> 使用时把“现有代码约束”一节中的文件一并提供给模型，并要求只输出待填区域的完整函数。

---

## 角色与目标

你是操作系统内核开发者。请在一个基于 RISC-V Sv39、已经完成 Lab2（物理内存）、Lab3（中断/异常返回）、Lab4（PCB、调度、`do_fork`/`copy_thread`）的 ucore 教学内核上，完成 Lab5 的**模块二（用户程序创建与加载）**和**模块三（用户进程复制）**。

代码基线：`code/` 目录，Lab5 框架已回填 Lab2–4 的实现，B 负责的 `function2`/`function3` 区域仍是 `YOUR CODE`。

## 必须完成的范围

### 模块二：`code/kern/process/proc.c`

1. `alloc_proc`：在 Lab4 基础上初始化 `exit_code`、`wait_state`、`cptr/yptr/optr`；`pgdir` 初始为 `boot_pgdir_pa`。
2. `kernel_thread`：检查/适配内核线程首次运行现场（`s0/s1`、`SPP=1`、`SPIE=1`、`SIE=0`）。
3. `init_main`：创建 `user_main` 内核线程，`do_wait` 回收；用真实的进程树、链表、计数、物理页与内核堆断言做收尾检查。
4. `user_main`：`TEST` 宏存在时 `KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE)`，否则 `KERNEL_EXECVE(exit)`。
5. `kernel_execve`：构造中断帧并经 `forkrets(tf)` 真正返回用户态；不能只调用 `do_execve`。
6. `do_execve`：校验参数、复制进程名、替换地址空间、失败时终止进程。
7. `load_icode`：校验 ELF；建立 VMA、页表和用户栈；加载各段并清零 BSS；设置用户入口、用户栈和 `sstatus`；切换 `satp`；失败时完整清理。
8. `do_wait`：支持 `pid == 0`（任意子进程）与指定 pid；处理睡眠/唤醒/重查、退出码写回、僵尸进程回收；非法目标返回 `-E_BAD_PROC`。

### 模块三

1. `copy_mm`（`proc.c`）：区分无用户 mm、`CLONE_VM`、普通复制；维护 `mm_count`、`pgdir`；失败清理。
2. `dup_mmap`（`kern/mm/vmm.c`）：复制 VMA 区间与属性，调用 `copy_range`。
3. `copy_range`（`kern/mm/pmm.c`）：逐页分配新物理页并复制，保留权限，维护引用计数与错误路径。
4. `do_fork`：核对既有实现与用户 fork 路径（PCB、内核栈、mm、中断帧、pid、哈希/链表、唤醒、失败回滚）。

## 现有代码约束（必须遵守）

- 只修改标记对应的区域，保留 `//lab5 functionN` 注释，把 `YOUR CODE` 替换为学号 `2412102`。
- 复用现有结构、头文件和函数签名，不新增并行接口：
  - `struct proc_struct` / `struct mm_struct` / `struct vma_struct` / `struct trapframe` 保持原样；
  - `do_execve(const char *name, size_t len, unsigned char *binary, size_t size)`；
  - `copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share)`。
- `proc->pgdir` 必须保存**页表根的物理地址**（`PADDR(mm->pgdir)`），因为 `proc_run` 直接用它拼 `satp`；`mm->pgdir` 是内核虚拟地址。
- `RESTORE_ALL` 已由 Lab3 实现：返回用户态时 `SPP=0`，`sscratch` 会设为该中断帧之上的内核栈顶。因此首次进入用户态只要保证 `tf->status`（SPP=0、SPIE=1、SIE=0）、`tf->epc`、`tf->gpr.sp` 正确，并调用 `forkrets(tf)`。
- 用户程序链接在 `0x800020`，用户栈顶 `USTACKTOP = 0x80000000`，`USTACKPAGE = 256`；栈 VMA 最低页由 `user_mem_check` 作为保护页。
- `idt_init` 已设置 `sstatus.SUM`，内核可以直接复制用户内存。
- 内核堆 SLOB 的 arena 页只增不减（上游已知问题，对应 challenge4）。`init_main` 的“内存已恢复”检查应使用 `slob_arena_pages()` 把 SLOB 保留页单独扣除，其余物理页仍要求严格相等。

## spec 要求

对每个函数说明并实现：

1. 输入/输出与返回值；
2. 前置条件与状态约束；
3. 边界条件（`pid` 范围、`code_store == NULL`、ELF 越界、空段、BSS、页对齐、地址范围）；
4. 失败清理（已分配的物理页、页表、mm、内核栈、PCB）；
5. 与其他模块的衔接（`do_exit` 的 `exit_code/PROC_ZOMBIE/WT_CHILD`；`RESTORE_ALL` 的中断帧布局；`do_fork` 的 `copy_thread`）。

## 输出要求

- 给出可直接编译的完整函数实现，不要伪代码；
- 每个函数附简短中文注释，解释关键状态、页表或寄存器处理；
- 在每个函数末尾说明失败路径会释放哪些资源；
- 不要修改不属于本模块的函数。

---

## 验证提示词（追加）

> 请用实验配套 GCC 10.1.0 工具链编译，并用 QEMU 4.1.1 运行：
>
> ```bash
> export PATH=/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin:$PATH
> export QEMU=$HOME/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64
> make
> make qemu        # 默认运行 exit
> make grade       # 13 个用户程序
> ```
>
> 重点观察 `hello`、`yield`、`badarg`、`exit`、`spin`、`forktest` 的输出，尤其是 `exit pass.`、`all user-mode processes have quit.`、`init check memory pass.`。
> 若 `forktest` 报空闲页不相等，请先确认是否只有 SLOB arena 页未归还（用 `slob_arena_pages()` 扣除后再比较），而不是用户映射/页表/内核栈的真实泄漏。


# A 部分最终提示词

> 说明：本文件是 A（2413346-易响）在 Lab5 中使用的**模块四**与**双重 GDB 调试**任务的最终提示词版本。
> 实际下发给助手的是简短任务描述（“负责模块四，先理清思路再完成”“做双重 GDB”）；下面按 lab0.5 的提示词结构整理成可复现的等价版本，其中“现有代码约束”、`spec` 与最终代码、最终调试步骤一一对应。
> 使用时把“现有代码约束”中列出的文件一并提供给模型，并要求只输出指定区域。

---

## 第一部分：模块四——进程退出、让出 CPU 与终止

### 角色与目标

你是 RISC-V ucore 的内核开发者。请在一个基于 RISC-V Sv39、已完成 Lab2（物理内存/页表）、Lab3（中断与异常返回）、Lab4（PCB、调度、`do_fork`/`copy_thread`）的教学内核上，完成 Lab5 的**模块四**：

- `int do_exit(int error_code)`：结束当前进程，回收用户地址空间，进入僵尸态，唤醒父进程，托管子进程，交出 CPU；
- `int do_yield(void)`：主动让出 CPU；
- `int do_kill(int pid)`：向目标进程发送退出意图。

代码基线：`code/`，Lab5 框架已回填 Lab2–4 的实现；`kern/process/proc.c` 的 `//lab5 function4` 区域仍是 `YOUR CODE`，另有一个会 `panic("process exit!!.")` 的 `do_exit` 占位。

### 必须完成的范围

| 函数 | 要求 |
|---|---|
| `do_exit` | 保护 `idleproc`/`initproc`；先离开自己的页表再释放 mm；按 `mm_count` 决定是否 `exit_mmap`/`put_pgdir`/`mm_destroy`；写 `exit_code`、置 `PROC_ZOMBIE`；唤醒 `WT_CHILD` 的父进程；把子进程转交 `initproc`；`schedule()` 后不再返回 |
| `do_yield` | 只设置 `current->need_resched = 1` 并返回 0，不直接 `schedule()` |
| `do_kill` | `find_proc(pid)` 命中且目标合法时置 `PF_EXITING`；目标睡眠则 `wakeup_proc`；非法 pid / `idleproc` / `initproc` / 重复请求 / 僵尸返回 `-E_INVAL` |

### 现有代码约束（必须遵守）

- 只修改 `kern/process/proc.c` 的 `//lab5 function4` 区域，保留标记，把 `YOUR CODE` 替换为学号 `2413346`。
- 删除原有的 `do_exit` panic 桩，但保留其他函数：`do_execve` 失败路径、`do_wait` 睡眠唤醒路径都会调用 `do_exit`。
- 复用既有结构、签名和头文件，不新增并行接口：
  - `struct proc_struct{state,pid,kstack,mm,pgdir,flags,exit_code,wait_state,cptr,yptr,optr,parent,...}`；
  - `mm_count()/mm_count_dec()`、`exit_mmap()`、`put_pgdir()`、`mm_destroy()`；
  - `wakeup_proc()`、`schedule()`、`local_intr_save/restore()`、`find_proc()`。
- 切换页表用本项目写法，不是 x86 的 `lcr3`：

  ```c
  uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                         (boot_pgdir_pa >> RISCV_PGSHIFT);
  write_csr(satp, satp_value);
  asm volatile("sfence.vma" ::: "memory");
  ```

- `exit_mmap()` 内部 `assert(mm_count(mm) == 0)`，所以必须先 `mm_count_dec()` 再调用，不能先释放后减计数。
- `proc->pgdir` 保存**页表根物理地址**，`mm->pgdir` 是内核虚拟地址；退出后把 `current->pgdir` 恢复为 `boot_pgdir_pa`。
- `kernel_thread_entry` 在 `fn` 返回后会执行 `jal do_exit`；`init_main` 正常返回 0，因此 `initproc` 最终会调用 `do_exit(0)`。对 `idleproc`/`initproc` 不能返回错误码（没有有效的返回地址），必须 `panic`。
- `trap()` 在返回用户态前会检查：

  ```c
  if (current->flags & PF_EXITING) do_exit(-E_KILLED);
  if (current->need_resched) schedule();
  ```

  `do_kill`/`do_yield` 只设置标志，切换/退出由这里完成。
- `do_wait()` 的约定：`current->state = PROC_SLEEPING; current->wait_state = WT_CHILD; schedule();` 醒来后若带 `PF_EXITING` 则 `do_exit(-E_KILLED)`；回收僵尸时执行 `unhash_proc → remove_links → put_kstack → kfree(proc)`。因此 `do_exit` 不能提前释放 PCB 和内核栈。
- `set_links()` 的兄弟链语义：`cptr` 为子进程链头，`optr` 指向更年长的兄弟，`yptr` 指回更年轻的兄弟。转交子进程时必须同步维护三向关系，`nr_process` 不变。
- 用 `local_intr_save/restore` 包住父进程唤醒与子进程转交；临界区内不做可能睡眠的分配。
- 测试断言（`tools/test_lab5.c`）：
  `do_yield() == 0 && current->need_resched`；`do_kill(-1) == -E_INVAL`；`do_wait(-1, NULL) == -E_BAD_PROC`。

### spec（逐函数）

#### 1. `do_exit(int error_code)`

- **Pre-Condition**：`current != NULL`；调用者持有有效内核栈；不得是 `idleproc`/`initproc`。
- **Post-Condition**：用户地址空间已释放或 `mm_count` 已减；`exit_code` 已写；状态为 `PROC_ZOMBIE`；父进程被唤醒；子进程已转交 `initproc`；当前进程不再被调度。
- **Case 1**：`current->mm == NULL`（内核线程/加载失败）→ 跳过 mm 处理，直接进入僵尸态。
- **Case 2**：`mm_count_dec(mm) > 0`（`CLONE_VM`/COW 共享）→ 只减计数，不释放 mm。
- **Case 3**：`parent == NULL` → 跳过唤醒；`current->cptr == NULL` → 跳过转交。
- **Requirements**：释放 mm 前先切回内核页表并 `sfence.vma`；不得 `put_kstack`/`kfree(current)`；`schedule()` 后 `panic` 防止意外返回。

#### 2. `do_yield(void)`

- **Pre-Condition**：进程上下文，`current != NULL`。
- **Post-Condition**：`need_resched = 1`，返回 0；不改变进程状态，不直接切换。
- **Requirements**：幂等；切换点留给 `trap()` 返回路径。

#### 3. `do_kill(int pid)`

- **Pre-Condition**：`pid` 为用户提供的目标进程号。
- **Post-Condition**：合法目标置 `PF_EXITING`；若目标 `PROC_SLEEPING` 则唤醒；返回 0。
- **Case 1**：`pid` 不存在（含 `-1`）→ `-E_INVAL`。
- **Case 2**：目标是 `idleproc`/`initproc` → `-E_INVAL`。
- **Case 3**：目标已带 `PF_EXITING` 或已是 `PROC_ZOMBIE` → `-E_INVAL`（重复请求）。
- **Case 4**：目标 `PROC_RUNNABLE` → 只置标志，不唤醒；它在下一个 trap 返回点自行退出。
- **Requirements**：不直接对目标调用 `do_exit`（目标可能正在使用自己的内核栈）；语义是异步终止。

### 输出要求

- 给出可直接编译的完整三个函数，不要伪代码；
- 每个函数附中文注释，解释关键状态、页表和调度处理；
- 说明失败/边界路径（`mm == NULL`、`mm_count > 0`、`parent == NULL`、重复 kill）；
- 不修改 `do_wait`、`set_links`、`copy_mm` 等他人负责的函数。

### 验证提示词（追加）

> 请在本机编译并运行验证，不要只做代码审查：
>
> ```bash
> cd code
> make clean && make                 # 必须 0 错误
> make qemu                          # 默认 exit：exit pass. / init check memory pass.
> make build-hello && make qemu      # hello pass.
> make build-spin && make qemu       # kill returns 0 / wait returns 0 / spin may pass.
> ../report/run_injected_check.sh    # [Test Process Control] PASS 等三条
> ```
>
> 注意：`make` 的 warning（`kmalloc.c` 的 `kva2page`、`testbss.c` 的越界写）是基线/测试程序的预期 warning，不是失败；切换 `make build-<程序>` 后要 `make clean && make` 才能回到默认 `exit` 构建。
> 最后的 `kernel panic: initproc exit.` 是上游 Lab5 的预期收尾，不是模块四的 bug。

---

## 第二部分：双重 GDB 调试系统调用与返回（追加任务）

### 角色与目标

在同一个 ucore Lab5 工程上，用**两个 GDB** 观察一次完整的 U→S→U：

- 客体 GDB（`riscv64-unknown-elf-gdb`）通过 QEMU gdbstub 调试 ucore/用户程序；
- 宿主 GDB（系统 `gdb`）调试 QEMU 进程本身，观察 TCG 生成代码如何调用 C helper 模拟 `ecall`/`sret`。

目标是拿到可复核的寄存器、调用栈、特权级和源码证据，并解释 QEMU 的关键流程与 TCG 的作用，而不是只截一张“跑通”的图。

### 环境与已知事实

- QEMU 4.1.1，源码与调试符号在 `/home/agony/Desktop/qemu-4.1.1`；
- 客体 GDB 10.1，宿主 GDB 12.1，交叉工具链 SiFive GCC 10.2.0；
- 用户程序不是在文件系统里，而是构建时链接进内核镜像；`make debug`/`make gdb` 只加载内核符号，必须手动 `add-symbol-file obj/__user_hello.out`；
- 本机 `hello` 的 `ecall` 在 `0x8000a2`，`exit` 的 `ecall` 在 `0x800104`——**必须用 `objdump` 按自己的构建确认，不要照抄**；
- `__trapret` 的 `sret` 在本机构建为 `0xffffffffc0200f12`，同样要用 `objdump -d bin/kernel | grep -n -B4 sret` 复核；
- Ubuntu 默认 `kernel.yama.ptrace_scope=1`，直接 `gdb -p <qemu-pid>` 可能失败；可让宿主 GDB 直接启动 QEMU，或临时把 `ptrace_scope` 设为 0。
- 调试前先 `make clean && make build-hello`，保证运行的确实是 `hello` 而不是上一次 `TEST` 的残留。

### 必须完成的观测

#### 1. 加载用户符号，选一个会正常返回的系统调用

- 用 `hello`（先 `cprintf` 再 `getpid`），不要只用 `exit`——`exit` 不返回原调用点；
- 说明为什么只加载 `bin/kernel` 找不到 `user/libs/syscall.c`，以及 `add-symbol-file` 为什么不需要指定 text 偏移（`user.ld` 固定链接在 `0x800020`）。

#### 2. 客体侧：停在 `ecall` 与 `sret`

先在一个终端执行 `make debug`（QEMU 带 `-S -s` 启动并等待 gdbstub），再在另一个终端连接：

```text
(gdb) file bin/kernel
(gdb) set arch riscv:rv64
(gdb) target remote localhost:1234
(gdb) add-symbol-file obj/__user_hello.out
(gdb) break *0x8000a2
(gdb) continue
(gdb) info registers pc a0 a1 a2
(gdb) x/4i $pc
(gdb) bt
```

要求记录：`pc=0x8000a2`、`a0=30`（`SYS_putc`）、`a1=0x48`（`'H'`）、`a2=0x800858`，以及 `main → cprintf → vcprintf → vprintfmt → cputch → sys_putc → syscall` 的调用链。

```text
(gdb) break *0xffffffffc0200f12
(gdb) continue
(gdb) info registers pc sp
(gdb) info registers sstatus sepc scause
(gdb) si
(gdb) info registers pc
```

要求记录：`SPP=0`、`SPIE=1`、`SIE=0`、`sepc=0x8000a6`、`sp=0x7ffffe60`（用户栈），`si` 后 `pc=0x8000a6`。

#### 3. QEMU 侧：`helper_raise_exception` 与 `helper_sret`

宿主 GDB 启动 QEMU：

```bash
cd code
gdb -x ../report/gdb/qemu_host.gdb
```

另一个终端（同样在 `code/` 下）让客体跑起来：

```text
make gdb
(gdb) continue
```

要求记录：

- `helper_raise_exception(env, exception=8)`，`env->priv == 0`，`USER-ECALL: priv=0 pc=0x8000a2`；
- `helper_sret` 入口：`priv=1`、`sepc=0x8000a6`、`mstatus` 的 `SPP=0`、`SPIE=1`、`SIE=0`；
- 下一次用户 `ecall` 时 `priv` 回到 0，证明 `sret` 回到了 U 态；
- 调用栈经过 `helper → code_gen_buffer → cpu_tb_exec → cpu_loop_exec_tb → cpu_exec → tcg_cpu_exec`。

注意：ucore 的 `cprintf` 走 SBI，也是 `ecall`（S 态），所以第一个 `helper_raise_exception` 往往是 SBI 调用；必须用条件断点 `if env->priv == 0` 过滤。QEMU 4.1.1 的 `CPURISCVState` 没有 `sstatus` 成员，要打印 `env->mstatus` 再按位解读。

### QEMU 源码阅读要求

对照实际版本解释以下位置（不要泛泛而谈）：

| 阶段 | 源码 |
|---|---|
| `ecall` 翻译 | `target/riscv/insn_trans/trans_privileged.inc.c` 的 `trans_ecall`：`generate_exception(ctx, RISCV_EXCP_U_ECALL); exit_tb(ctx);` |
| 异常入口 | `target/riscv/translate.c` 的 `generate_exception` → `gen_helper_raise_exception` |
| 触发异常 | `target/riscv/op_helper.c` 的 `helper_raise_exception` → `riscv_raise_exception`：写 `exception_index`，`cpu_loop_exit_restore` |
| 异常分发 | `accel/tcg/cpu-exec.c` 的 `cpu_handle_exception` 调用 `cc->do_interrupt` |
| 交付 S 态 | `target/riscv/cpu_helper.c` 的 `riscv_cpu_do_interrupt`：`scause/sepc/stvec`、`SPP=旧 priv`、`priv=S` |
| `sret` 翻译 | `trans_sret`：`gen_helper_sret(cpu_pc, cpu_env, cpu_pc)` |
| `sret` 语义 | `target/riscv/op_helper.c` 的 `helper_sret`：`retpc=sepc`、`SIE=SPIE`、`SPIE=0`、`SPP=U`、`priv=旧 SPP` |
| 生成代码执行 | `accel/tcg/cpu-exec.c`、`code_gen_buffer`、`cpu_tb_exec` |

### TCG 思考要求

- 解释 QEMU 如何把 guest 指令翻译成宿主代码、缓存在 `code_gen_buffer` 中执行；
- 解释为什么 `ecall`/`sret` 在翻译阶段只生成“调用 helper + 结束 TB”的代码，异常/特权切换在 helper 里完成；
- 对比 Lab2 的地址翻译双重调试：同一套双 GDB 方法，Lab2 看 `riscv_cpu_tlb_fill`/`get_physical_address`/`tlb_set_page`，Lab5 看 `helper_raise_exception`/`riscv_cpu_do_interrupt`/`helper_sret`；一个看“地址怎么变”，一个看“特权级怎么变”；
- 说明宿主栈里的 `code_gen_buffer` 帧就是 guest 代码与宿主 C 代码的边界。

### 踩坑与记录要求

至少记录并解释以下真实问题（如果本地遇到别的，也一并写）：

1. `b kern_entry` 不触发：内核链接在 `0xffffffffc0200000`，但上电 PC 是物理 `0x80200000`；
2. `make build-hello` 后直接 `make` 仍跑旧程序：`DEFS` 不是 make 依赖，需要 `make clean && make`；
3. `add-symbol-file` 后地址仍不对：`hello` 与 `exit` 的 `ecall` 地址不同（`0x8000a2` vs `0x800104`）；
4. `gdb -p` 失败：`ptrace_scope=1`，改用宿主 GDB 启动 QEMU；
5. 第一处 `helper_raise_exception` 的 `priv=1`：SBI 的 S 态 ecall；
6. `env->sstatus` 不存在：QEMU 4.1.1 用 `mstatus` 存；
7. 不知道 `sret` 断哪：用 `objdump` 找 `sret` 地址，或 `b __trapret` 后 `si`。

### 输出要求

- 给出完整命令序列、每一步的寄存器/栈/特权级实测值，以及对应源码位置；
- 解释“为什么是这个地址/这个断点条件”，不只贴结果；
- 给出 TCG 与 Lab2 双重调试的联系与差别；
- 记录真实迭代、错误信息、自己的判断和 AI 交互过程，不编造。

