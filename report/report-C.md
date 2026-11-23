### 功能模块：模块一——用户态系统调用


**负责人：** 2411033-季艾佳

#### 模块功能描述

本模块连接用户态的 `ecall` 请求与内核服务：异常入口推进返回地址，系统调用分发器从中断帧中提取调用号和参数，各个包装函数调用对应的内核接口，最后将返回值写回 `a0`。

需要实现或修改的函数：

```c
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
```

各函数的作用如下：

- `exception_handler()`：识别用户系统调用异常，推进返回地址并进入系统调用分发；处理不可恢复的用户异常。
- `syscall()`：检查调用号，提取参数，查表调用处理函数，并写回返回值。
- `sys_exit()`、`sys_fork()`、`sys_wait()`、`sys_exec()`、`sys_yield()`、`sys_kill()`：提取参数并调用对应的进程管理接口。
- `sys_getpid()`：返回当前进程的 PID。
- `sys_putc()`：向控制台输出字符。
- `sys_pgdir()`：遍历并打印当前进程的 Sv39 页表。

退出、复制、等待和程序加载的具体逻辑由其他模块实现。本节不包含另列的 `RESTORE_ALL` 适配和 COW Challenge。

说明：本材料属于实验完成后的补充复现，由同一助手实际执行提示词，不代表原始开发过程。复现使用 `lab5` 分支的基础适配版本 `e464aa37ce0f10a818d7650059956353b075a47f`，在独立副本中生成和验证，未覆盖原工作区，也未提交或推送修改。该基线尚未包含用户提到的模块一成品，本次生成结果没有使用成品代码冒充。

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

#### 实现迭代过程

本模块实际经历了 **1 次提示词生成迭代**，过程如下。

---

##### 第一次迭代


**最终结果：**

经过 [1] 次迭代，该模块最终：

- **编译结果：** 模块一两个目标文件编译通过，增加 `-Werror` 后也通过；隔离测试镜像链接通过。完整基线构建仍受 `kmalloc.c` 类型错误阻断。
- **本模块相关测试：** 原有 `test_lab5_syscall()` 通过；QEMU RV64 隔离测试执行 85 个断言，失败数为 0。
- **已验证的功能：** 异常入口分流、系统调用编号检查、参数提取、返回值写回、九个包装函数、用户地址范围检查及实际页表输出。


**关键改进点总结：**

本次未发生提示词修订。

第一版已经明确项目 ABI、非法编号处理、静态函数声明顺序、用户指针检查，以及缺失页表打印接口的处理方式。这些要求并非后续迭代才增加。实际编译与边界检查通过，因此保留第一次执行的提示词作为最终版本。