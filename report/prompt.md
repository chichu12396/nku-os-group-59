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

### 功能模块四：进程退出、让出 CPU 与终止

**负责人：** 2413346-易响
#### 4.4.3 最终提示词

说明：本模块由 AI 助手在现有工作区直接实现。实际下发的是一段简短的任务描述（“负责模块四，先理清思路再完成”），为了让报告可复现，下面按 lab0.5 的提示词模板整理成等价的完整版本；`RELY`、`SPEC` 部分与代码中的实际约束一一对应。

```markdown
[ROLE]
你是 riscv64-ucore Lab5 的内核开发者，熟悉 RISC-V Sv39、trapframe、
进程状态机与 ucore 的进程/内存管理接口。

[CONTEXT]
项目位于 code/，已完成 Lab2~Lab4。Lab5 已有 sys_exit/sys_yield/sys_kill
（kern/syscall/syscall.c）和 do_wait（kern/process/proc.c），
且 trap() 在返回用户态前会检查 PF_EXITING 和 need_resched。
当前 task：补全 kern/process/proc.c 的 function4 区域。

[RELY]
- current / idleproc / initproc / proc_struct{state, exit_code, wait_state,
  flags, mm, pgdir, cptr, optr, yptr, parent}
- PROC_ZOMBIE、PF_EXITING、WT_CHILD、E_INVAL/E_KILLED
- mm_count_dec()/mm_count()、exit_mmap()、put_pgdir()、mm_destroy()
- wakeup_proc()、schedule()、local_intr_save/restore()
- satp 写入方式 boot_pgdir_pa >> RISCV_PGSHIFT，SATP_MODE_SV39，
  sfence.vma
- 父子/兄弟链语义由 set_links() 定义（cptr 为链头，optr 更年长，
  yptr 更年轻）
- kernel_thread_entry 在 fn 返回后执行 jal do_exit

[SPEC]
1) do_exit(error_code) 不得让 idleproc/initproc 退出；
2) 退出前必须离开自己的页表，再按 mm_count 决定是否释放 mm；
3) 退出码、PROC_ZOMBIE、唤醒父进程、把子进程托管给 initproc，
   然后 schedule()，永不返回；
4) 不释放自己的 PCB 和内核栈（父进程 do_wait 负责）；
5) do_yield() 只设 need_resched=1 并返回 0，不直接 schedule；
6) do_kill(pid)：非法 pid / idle / init / 重复请求 / 僵尸 → -E_INVAL；
   合法则置 PF_EXITING，睡眠目标要唤醒；返回 0。

[CONSTRAINTS]
- 只修改 function4 区域，保留 //lab5 function4 注释，把 YOUR CODE
  替换为 2413346；
- 沿用既有函数签名与头文件；不要改 do_wait/set_links 的语义；
- 临界区内只做链表/状态更新，不做可能睡眠的分配；
- 用现有的 panic/cprintf 风格输出，注释用中文解释关键状态。

[OUTPUT]
三份实现 + 每个函数的关键点说明 + 边界条件说明 + 与 do_wait 的
对齐点；最后给出可编译、可在 QEMU 中验证的结论。
```
