### 功能模块一：`RESTORE_ALL`
**负责人：** 2413346-易响
#### 最终提示词

````markdown
[PROMPT]
任务：修改 `kern/trap/trapentry.S`，在 `.macro RESTORE_ALL` 与 `.endm` 之间实现 Trap 上下文恢复宏。它与文件中已有的 `SAVE_ALL` 配对：`SAVE_ALL` 在进入 Trap 时把一个完整的 `struct trapframe` 放到当前内核栈顶，`RESTORE_ALL` 要在 `__trapret` 中被调用，从该 trapframe 恢复处理器状态，使紧随其后的 `sret` 能回到被中断的执行流。只处理本实验的 S 态陷入场景。

操作要求：必须直接修改项目中的真实文件，而不是只展示代码；只替换 `#lab3 function1 YOUR CODE` 所在的宏体，保留该 `#lab3` 注释并把 `YOUR CODE` 换成 `2413346`；不得修改 `SAVE_ALL`、`struct trapframe`、`trap()` 签名、`.align(2)` 以及 `__alltraps` / `__trapret` 的结构；不要新增函数、全局符号或数据。

输出要求：直接进行文件操作，使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的信息，以工程中的真实代码和布局为准，不要引入与本任务无关的功能。

[RELY]
// 数据结构（kern/trap/trap.h）
struct trapframe {
    struct pushregs gpr;   // offset 0 .. 31，共 32 个字
    uintptr_t status;      // offset 32 = sstatus
    uintptr_t epc;         // offset 33 = sepc
    uintptr_t badvaddr;    // offset 34 = sbadaddr
    uintptr_t cause;       // offset 35 = scause
};

// 已有的保存逻辑（kern/trap/trapentry.S，不能修改）
.macro SAVE_ALL
    csrw sscratch, sp                 // 旧 sp 暂存到 sscratch
    addi sp, sp, -36 * REGBYTES       // 在栈上分配 Trap frame
    STORE x0,  0*REGBYTES(sp)
    STORE x1,  1*REGBYTES(sp)
    STORE x3,  3*REGBYTES(sp)
    ...
    STORE x31, 31*REGBYTES(sp)
    csrrw s0, sscratch, x0            // s0 = 旧 sp，同时 sscratch = 0
    csrr s1, sstatus
    csrr s2, sepc
    csrr s3, sbadaddr
    csrr s4, scause
    STORE s0, 2*REGBYTES(sp)          // offset 2 保存的是陷入前的 sp
    STORE s1, 32*REGBYTES(sp)
    STORE s2, 33*REGBYTES(sp)
    STORE s3, 34*REGBYTES(sp)
    STORE s4, 35*REGBYTES(sp)
.endm

// 可用宏与常量（libs/riscv.h）
// REGBYTES = 8（64 位）；LOAD = ld；STORE = sd

// 调用链
// __alltraps: SAVE_ALL →（C 负责：把 sp 作为 tf 传给 trap）→ __trapret
// __trapret: RESTORE_ALL → sret
// sp 在调用 trap() 前后保持不变，trap() 返回后 sp 仍指向同一个 trapframe。

// sret 语义
// pc ← sepc；SIE ← SPIE；根据 SPP 选择返回特权级。本实验全部从 S 态陷入，SPP=1。

[GUARANTEE]
必须实现或修改的接口：`.macro RESTORE_ALL` 的宏体（汇编宏，没有 C 函数签名）。
可以添加：宏内部使用的临时寄存器；但不得新增宏、函数、全局符号或数据。

[SPECIFICATION]
RESTORE_ALL:
Pre-Condition:
- `sp` 指向一个由 `SAVE_ALL` 构造的完整 trapframe（36 个字）。
- 进入宏时 `sstatus.SIE = 0`、`sstatus.SPP = 1`（本实验均从 S 态陷入）。
- 除 `sp` 外，通用寄存器的内容不可信；CSR 中的 `sstatus`/`sepc` 不一定等于 trapframe 中的值。

Post-Condition:
- `sstatus` 被写回为 `tf->status`，`sepc` 被写回为 `tf->epc`；`tf->epc` 是异常处理函数可能已经修改过的值。
- `x1`、`x3` … `x31` 恢复为 trapframe 对应槽位的值。
- `x2` 恢复为 `tf->gpr.sp`（Trap 发生前的 sp）。
- 恢复 `x2` 之后不再访问栈；宏结束时处理器状态可以直接执行 `sret`。
- `x0` 保持 0；`sbadaddr`/`scause` 不要求恢复。

Case 1（正常恢复）:
- 先从 trapframe 的高偏移读出 `sepc` 与 `sstatus` 并写回 CSR，再按偏移恢复 `x1`、`x3` … `x31`，最后恢复 `x2`。

Requirements:
- 写 CSR 只能借助通用寄存器；所用临时寄存器必须在后续步骤中从 trapframe 恢复，不能破坏最终结果。
- `x2` 必须最后恢复，且之后不得再有任何使用 `sp` 的指令。
- 偏移必须与 `SAVE_ALL` 严格一致（32 = status，33 = epc），不得自行假设其他布局。
- 不得清 `SPP`、不得假设返回到 U 态，也不得改变 `sstatus.SIE` 的保存语义。
- 只把 `tf->epc` 写回 `sepc`，不自行计算 `+2`/`+4`（指令长度由异常处理函数负责）。
- 宏必须能在本工程的 Makefile 下用 `riscv64-unknown-elf-as` 成功汇编。
````

### 功能模块一：Trap 入口 `__alltraps`
**负责人：** 2412102-聂海丽
#### 最终提示词

以下是经过迭代后最终使用的提示词：

````markdown
[PROMPT]
任务：修改 `kern/trap/trapentry.S`，在 `__alltraps:` 标签内、`SAVE_ALL` 之后、`# sp should be the same as before "jal trap"` 之前，补全 Trap 入口到 C 函数 `trap()` 的调用关系。完成后，`SAVE_ALL` 构造的 Trap frame 应作为 `struct trapframe *` 传给 `trap(struct trapframe *tf)`，`trap()` 返回后应自然进入 `__trapret`。

操作要求：必须直接修改项目中的真实文件，而不是只展示代码；只替换 `#lab3 function1 YOUR CODE` 所在的那一行，保留 `#lab3 function1` 注释前缀并把 `YOUR CODE` 换成 `2412102`；保留 `# sp should be the same as before "jal trap"` 这行注释；不得修改 `SAVE_ALL`、`struct trapframe`、`trap()` 签名、`.align(2)` 以及 `__trapret` 的结构；不要新增函数、全局符号、数据或栈帧操作。

输出要求：直接进行文件操作，使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的信息，以工程中的真实代码和布局为准，不要引入与本任务无关的功能。

[RELY]
// 已有的保存逻辑（kern/trap/trapentry.S，不能修改）
.macro SAVE_ALL
    csrw sscratch, sp                 // 陷入前的 sp 暂存到 sscratch
    addi sp, sp, -36 * REGBYTES       // 在内核栈上分配 36 个 64 位字的 Trap frame
    STORE x0,  0*REGBYTES(sp)
    STORE x1,  1*REGBYTES(sp)
    STORE x3,  3*REGBYTES(sp)
    ...
    STORE x31, 31*REGBYTES(sp)
    csrrw s0, sscratch, x0            // s0 = 陷入前的 sp，同时 sscratch = 0
    csrr s1, sstatus
    csrr s2, sepc
    csrr s3, sbadaddr
    csrr s4, scause
    STORE s0, 2*REGBYTES(sp)          // offset 2 保存陷入前的 sp
    STORE s1, 32*REGBYTES(sp)         // status
    STORE s2, 33*REGBYTES(sp)         // epc
    STORE s3, 34*REGBYTES(sp)         // badvaddr
    STORE s4, 35*REGBYTES(sp)         // cause
.endm

// 数据结构（kern/trap/trap.h）
struct trapframe {
    struct pushregs gpr;   // offset 0 .. 31
    uintptr_t status;      // offset 32
    uintptr_t epc;         // offset 33
    uintptr_t badvaddr;    // offset 34
    uintptr_t cause;       // offset 35
};

// 调用链
// __alltraps: SAVE_ALL →（本任务：a0 = sp；jal trap）→ __trapret
// __trapret: RESTORE_ALL → sret
// RESTORE_ALL 依靠当前 sp 相对偏移读取 Trap frame，因此调用 trap() 前后 sp 必须不变。

// RISC-V 调用约定
// 第一个整型参数放在 a0；jal 把下一条指令的地址写入 ra。

// sret 语义
// pc ← sepc；SIE ← SPIE；根据 SPP 选择返回特权级。本实验全部从 S 态陷入，SPP=1。

[GUARANTEE]
必须实现或修改的接口：`__alltraps` 标签内、`SAVE_ALL` 之后的两条汇编指令。
可以添加：无（最多使用 a0 与 ra）。
不得新增：栈帧调整、保存/恢复 ra 的 prologue/epilogue、函数、宏、全局符号或数据。

[SPECIFICATION]
 __alltraps:
Pre-Condition:
- 进入 `__alltraps` 时，PC 由硬件设为 `stvec`，`sp` 是被打断代码的栈指针。
- 执行到 `SAVE_ALL` 之后时，`sp` 指向一个完整的、由 36 个 64 位字组成的 Trap frame。

Post-Condition:
- `a0` 等于 `SAVE_ALL` 之后的 `sp`，即当前 Trap frame 的起始地址。
- 已调用 `trap(a0)`；`trap()` 返回后，下一条被执行的指令位于 `__trapret`。
- 调用 `trap()` 前后 `sp` 的值完全相同，仍指向同一个 Trap frame。
- 不改变 Trap frame 的任何内容（`trap()` 的处理结果除外）。

Case 1（正常入口）:
- `SAVE_ALL` 完成后执行 `mv a0, sp`，再执行 `jal trap`，返回后落入 `__trapret`。

Requirements:
- 参数必须放在 `a0`，不能放在其他寄存器。
- `mv a0, sp` 必须在 `SAVE_ALL` 之后，不能放在前面，也不能用 `sscratch` 里的旧 `sp`。
- `jal trap` 前后不得对 `sp` 做 `addi`，不得添加任何栈帧操作。
- `ra` 与 `a0` 的覆盖是安全的：原值已由 `SAVE_ALL` 保存，`RESTORE_ALL` 会恢复。
- 必须保留 `#lab3 function1` 注释，并把 `YOUR CODE` 替换为 `2412102`。
- 必须能在本工程的 Makefile 下用 `riscv64-unknown-elf-as` 成功汇编，且不产生警告。
````
### 功能模块二：中断与异常处理
**负责人：** 2411033-季艾佳
#### 最终提示词

````markdown
[PROMPT]
任务：修改 `kern/trap/trap.c`，在 `//lab3 function2 YOUR CODE` 所在位置实现 `interrupt_handler(struct trapframe *tf)` 与 `exception_handler(struct trapframe *tf)`。这两个函数由 `trap_dispatch()` 调用，分别处理中断和异常，处理完成后返回到统一的 Trap 返回流程。只实现本实验要求的处理逻辑，不要修改 `trap_dispatch()`、`trap()`、`print_trapframe()` 等其他函数。

操作要求：必须直接修改项目中的真实文件，而不是只展示代码；只替换 `//lab3 function2 YOUR CODE` 所在位置，保留 `lab3` 注释并把 `YOUR CODE` 换成 `2411033`；不得修改两个函数的签名；两个函数不能是 `static`（`tools/test_lab3.c` 用 `extern` 引用它们）；需要定义 `SHUTDOWN_AFTER`，并保证 `sbi_shutdown` 有声明；代码必须在本工程 `-Werror` 下编译通过。

输出要求：直接进行文件操作，使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的信息，以工程中的真实代码和测试脚本为准，不要引入与本任务无关的功能。

[RELY]
// 数据结构（kern/trap/trap.h）
struct trapframe {
    struct pushregs gpr;
    uintptr_t status;      // sstatus
    uintptr_t epc;         // sepc，异常处理可以修改它
    uintptr_t badvaddr;
    uintptr_t cause;       // scause，最高位 1 = 中断，0 = 异常
};

// 分派逻辑（kern/trap/trap.c，不能修改）
static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
        interrupt_handler(tf);
    } else {
        exception_handler(tf);
    }
}

// 可用接口与常量
// clock_set_next_event(void)：sbi_set_timer(rdtime() + 100000)
// ticks：volatile size_t，每收到一次时钟中断加一
// TICK_NUM = 100：每 100 次时钟中断打印一行 "100 ticks"
// IRQ_S_TIMER = 5，IRQ_S_SOFT = 1，CAUSE_ILLEGAL_INSTRUCTION = 2，CAUSE_BREAKPOINT = 3
// print_trapframe(tf)：打印完整 Trap frame
// sbi_shutdown(void)：关机（需要包含 <sbi.h> 或提供声明）
// SHUTDOWN_AFTER：框架没有定义，需要自己定义；取值至少为 3，建议 10

// tools/grade.sh 会 grep 以下子串，输出格式必须完全匹配：
// "Breakpoint at"
// "Illegal instruction at"
// "Supervisor software interrupt"
// "Unknown interrupt: cause 15"
// "cause    0x00000014"
// "100 ticks"
// "ticks=200"

[GUARANTEE]
必须实现或修改的接口：`interrupt_handler()`、`exception_handler()` 两个函数，以及 `SHUTDOWN_AFTER` 的定义。
可以添加：必要的 `#include <sbi.h>` 和局部变量。
不得修改：两个函数的签名、`trap_dispatch()`、`trap()`、`print_trapframe()`、`print_ticks()` 等其他函数；不得把两个 handler 声明为 `static`。

[SPECIFICATION]
interrupt_handler
Pre-Condition:
- `tf->cause` 的最高位为 1（中断）。
- `ticks` 是易失变量，当前值可能不为 0。

Post-Condition:
- `IRQ_S_TIMER`：已经安排了下一次时钟事件；`ticks` 增加 1；若 `ticks % TICK_NUM == 0`，已经调用 `print_ticks()` 并累计打印次数；累计达到 `SHUTDOWN_AFTER` 时已经调用 `sbi_shutdown()`。
- 其他已知中断：已经输出对应提示。
- 未知中断：已经输出 `Unknown interrupt: cause N` 并调用 `print_trapframe(tf)`。
- 不修改 `tf->epc`。

Case 1（时钟中断）:
- `cause = tf->cause & ~((uintptr_t)1 << 63)`；`case IRQ_S_TIMER:` 先 `clock_set_next_event()`，再 `ticks++`，再判断是否打印/关机。

Case 2（软件中断）:
- `IRQ_S_SOFT` 必须输出 `Supervisor software interrupt`。

Case 3（未知中断）:
- 默认分支输出 `Unknown interrupt: cause %lu`，并 `print_trapframe(tf)`。

Requirements:
- 每次时钟中断都必须重新调用 `clock_set_next_event()`，否则只会收到一次中断。
- `ticks` 每收到一次时钟中断必须增加一次；`print_ticks()` 只在 `ticks % TICK_NUM == 0` 时调用。
- `SHUTDOWN_AFTER` 必须 >= 3（本实验取 10），否则 Test 3 可能在观察到 `ticks=200` 前就关机。
- 比较中断号前必须先屏蔽 `cause` 的最高位。
- 不得修改 `tf->epc`。

exception_handler:
Pre-Condition:
- `tf->cause` 的最高位为 0（异常）。
- `tf->epc` 指向触发异常的指令。

Post-Condition:
- `CAUSE_ILLEGAL_INSTRUCTION`：已经输出 `Illegal instruction at 0x...`，`tf->epc` 已前进该指令的长度。
- `CAUSE_BREAKPOINT`：已经输出 `Breakpoint at 0x...`，`tf->epc` 已前进该指令的长度。
- 其他异常：已经调用 `print_trapframe(tf)`，`tf->epc` 保持不变（不做无意义的推进）。

Case 1（断点 / 非法指令）:
- 读取 `tf->epc` 处的 16 位指令：若 `(insn & 0x3) == 0x3`，说明是 32 位指令，`epc += 4`；否则是 16 位压缩指令，`epc += 2`。

Requirements:
- 不能固定 `+4`：`ebreak` 在本工具链下是 2 字节的 `c.ebreak`，而测试里的非法指令是 4 字节。
- 只有真正处理过的异常才推进 `epc`；默认分支打印后直接返回，不推进。
- 输出格式必须与 `tools/grade.sh` 的 grep 字符串一致。
````