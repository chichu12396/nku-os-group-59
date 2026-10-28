# 功能模块一（C 部分）：`__alltraps` 与思考题

**负责人：** 2412102-聂海丽

> 对应指导书「功能模块一：Trap 上下文恢复与 Trap 入口功能」中 C 负责的部分。
> 代码位置：`code/kern/trap/trapentry.S` 的 `__alltraps:` 标签内、`SAVE_ALL` 之后。
> 本文件记录 `__alltraps` 的功能理解、spec 设计、最终提示词、迭代过程与验证，以及 `sync.h` 思考题的答案。

---

## 一、模块功能描述

### 1.1 需要实现/修改的位置

```asm
    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL

    #lab3 function1 2412102
    mv a0, sp
    jal trap
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
    # return from supervisor call
    sret
```

本模块不涉及 C 函数签名，涉及的是汇编入口与 C 函数之间的调用关系：

```c
void trap(struct trapframe *tf);   /* kern/trap/trap.h，不可修改 */
```

### 1.2 功能说明

`__alltraps` 是 S 态 Trap 的统一入口：`idt_init()` 把它的地址写入 `stvec`，硬件在发生中断或异常时把 PC 跳到 `stvec`，于是执行流进入这里。

它要完成的事情只有一件：**把 `SAVE_ALL` 保存好的 Trap frame 地址，按照 RISC-V 调用约定交给 C 语言函数 `trap()`**。

- `SAVE_ALL` 先把陷入前的 `sp` 存入 `sscratch`，再执行 `addi sp, sp, -36 * REGBYTES`，在**当前内核栈**上分配 288 字节的 Trap frame，并逐字保存 32 个通用寄存器和 `sstatus/sepc/sbadaddr/scause` 四个 CSR。
- `SAVE_ALL` 结束后，`sp` 恰好指向这个 Trap frame 的起始地址，而 `struct trapframe` 的字段顺序与之一一对应。所以 `mv a0, sp` 就是把 `struct trapframe *tf` 放进第一个参数寄存器 `a0`。
- `jal trap` 调用 C 函数；`jal` 会把下一条指令的地址写进 `ra`，而 `__trapret` 正好紧跟在后面，因此 `trap()` 返回后会自然落到 `__trapret`，进入 `RESTORE_ALL + sret`。

### 1.3 与 A、B 的接口契约

| 契约 | 内容 | 违反后的现象 |
|---|---|---|
| `sp` 调用前后不变 | `RESTORE_ALL` 完全依靠当前 `sp` 相对偏移读取 Trap frame；`jal trap` 前后不能对 `sp` 做任何加减 | 所有偏移错位，寄存器恢复成错误的值，Test 1 失败或直接跑飞 |
| `a0` 的指向 | `a0` 必须是 `SAVE_ALL` 之后、Trap frame 起始处的 `sp`，不能是陷入前的栈指针 | `trap()` 读到的是旧栈上的随机数据，`tf->cause` 分类错误 |
| `tf->epc` 的修改 | B 的 `exception_handler()` 修改 `tf->epc`；A 的 `RESTORE_ALL` 必须把它写回 `sepc` | `sret` 回到原指令，同一条异常反复触发 |
| `ra` 被覆盖无害 | 被打断代码原来的 `ra` 已被 `SAVE_ALL` 保存在 offset 8；`RESTORE_ALL` 会恢复 | — |
| `a0` 被覆盖无害 | 原来的 `a0` 已被 `SAVE_ALL` 保存在 offset 80；`RESTORE_ALL` 会恢复 | — |

---

## 二、spec 是怎么写的

写提示词之前，先读 `SAVE_ALL`、`struct trapframe`、`trap()` 的签名和 `sret` 的语义，把“输入是什么、必须输出什么、哪些顺序不能变”固定下来，再写成四段式中的 `[SPECIFICATION]`。

| 项目 | 内容 |
|---|---|
| 输入 | 进入 `__alltraps` 时，硬件已把 PC 设为 `stvec`；`sp` 仍是被打断代码的栈指针 |
| 中间状态 | 执行 `SAVE_ALL` 后，`sp` 指向栈上 36 个 64 位字组成的 Trap frame |
| 输出 | `a0` = Trap frame 地址；调用 `trap(a0)`；返回后执行流落到 `__trapret`；`sp` 与调用前相同 |
| 布局来源 | offset 0–31 = `x0`–`x31`，32 = `status`，33 = `epc`，34 = `badvaddr`，35 = `cause`；总大小 288 字节 |
| 调用约定 | 第一个整型参数在 `a0`；`jal` 把返回地址写入 `ra` |
| 关键不变式 | ① `mv a0, sp` 必须在 `SAVE_ALL` 之后；② `jal trap` 前后 `sp` 不变；③ 不能把 `__alltraps` 当作普通函数，做保存 `ra`/`s0` 的 prologue |
| 边界 | 不修改 `SAVE_ALL`、`struct trapframe`、`trap()` 签名；不改 `__trapret` 的结构；不新增符号 |
| 验收 | `make obj/kern/trap/trapentry.o` 通过；`objdump` 中 `SAVE_ALL` 的 36 条 `sd` 之后是 `mv a0, sp` 与 `jal trap`；合并 A、B 后 `make grade` 通过 |

其中两个约束最容易写漏，也最容易被 AI 忽略：

1. **`__alltraps` 不是被 `call` 进来的**。它是硬件经 `stvec` 跳进来的，没有调用者替它准备栈帧，也没有“返回地址”可言；所以不要在入口处添加 `addi sp, sp, -N` / `sd ra, ...` 这种标准函数序言。
2. **`sp` 本身就是 Trap frame 指针**。这段代码不需要从 `sscratch` 里再取旧 `sp`，也不需要把 `sp` 调整到别的位置；`SAVE_ALL` 已经把一切准备好。

---

## 三、最终提示词

以下是经过迭代后最终使用的提示词（四段式）：

````markdown
[PROMPT]
**任务**：修改 `kern/trap/trapentry.S`，在 `__alltraps:` 标签内、`SAVE_ALL` 之后、`# sp should be the same as before "jal trap"` 之前，补全 Trap 入口到 C 函数 `trap()` 的调用关系。完成后，`SAVE_ALL` 构造的 Trap frame 应作为 `struct trapframe *` 传给 `trap(struct trapframe *tf)`，`trap()` 返回后应自然进入 `__trapret`。

**操作要求**：必须直接修改项目中的真实文件，而不是只展示代码；只替换 `#lab3 function1 YOUR CODE` 所在的那一行，保留 `#lab3 function1` 注释前缀并把 `YOUR CODE` 换成 `2412102`；保留 `# sp should be the same as before "jal trap"` 这行注释；不得修改 `SAVE_ALL`、`struct trapframe`、`trap()` 签名、`.align(2)` 以及 `__trapret` 的结构；不要新增函数、全局符号、数据或栈帧操作。

**输出要求**：直接进行文件操作，使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的信息，以工程中的真实代码和布局为准，不要引入与本任务无关的功能。

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
## __alltraps
**Pre-Condition**:
- 进入 `__alltraps` 时，PC 由硬件设为 `stvec`，`sp` 是被打断代码的栈指针。
- 执行到 `SAVE_ALL` 之后时，`sp` 指向一个完整的、由 36 个 64 位字组成的 Trap frame。

**Post-Condition**:
- `a0` 等于 `SAVE_ALL` 之后的 `sp`，即当前 Trap frame 的起始地址。
- 已调用 `trap(a0)`；`trap()` 返回后，下一条被执行的指令位于 `__trapret`。
- 调用 `trap()` 前后 `sp` 的值完全相同，仍指向同一个 Trap frame。
- 不改变 Trap frame 的任何内容（`trap()` 的处理结果除外）。

**Case 1（正常入口）**:
- `SAVE_ALL` 完成后执行 `mv a0, sp`，再执行 `jal trap`，返回后落入 `__trapret`。

**Requirements**:
- 参数必须放在 `a0`，不能放在其他寄存器。
- `mv a0, sp` 必须在 `SAVE_ALL` 之后，不能放在前面，也不能用 `sscratch` 里的旧 `sp`。
- `jal trap` 前后不得对 `sp` 做 `addi`，不得添加任何栈帧操作。
- `ra` 与 `a0` 的覆盖是安全的：原值已由 `SAVE_ALL` 保存，`RESTORE_ALL` 会恢复。
- 必须保留 `#lab3 function1` 注释，并把 `YOUR CODE` 替换为 `2412102`。
- 必须能在本工程的 Makefile 下用 `riscv64-unknown-elf-as` 成功汇编，且不产生警告。
````

---

## 四、实现迭代过程

本模块的代码量只有两条指令，但提示词迭代的重点不在“写出指令”，而在**把隐含约束说清楚**。共经历了三次迭代：

### 第一次迭代：把 `__alltraps` 当成了普通函数

**提示词要点：** “在 `__alltraps` 里调用 `trap()`，把 `sp` 作为参数传进去。”

**AI 生成的代码（示意）：**

```asm
__alltraps:
    SAVE_ALL

    addi sp, sp, -16
    sd   ra, 8(sp)
    mv   a0, sp          # 错误：此时 sp 已被再次减 16
    call trap
    ld   ra, 8(sp)
    addi sp, sp, 16
```

**发现的问题：**

1. `a0` 拿到的是 `Trap frame - 16`，不是 Trap frame 起始地址。`trap()` 会把内核栈上的其他数据当成 `tf->cause`、`tf->epc` 来读，分类必然错误。
2. 虽然 `addi sp, sp, 16` 在返回后把 `sp` 恢复了，但这段 prologue/epilogue 完全没有必要，而且违反了“`sp` 是 Trap frame 指针”的约定。一旦中间任何一步出错，`RESTORE_ALL` 的偏移全部错位。
3. `call` 会展开为 `auipc + jalr`，它同样写 `ra`；虽然在这里不影响正确性，但不如 `jal` 直接。

**问题解决策略：**

- 在 `[SPECIFICATION]` 的 Pre-Condition 中明确写出“执行到 `SAVE_ALL` 之后时，`sp` 已指向完整的 Trap frame”。
- 在 Requirements 中明确禁止“栈帧调整、保存/恢复 `ra` 的 prologue/epilogue”。
- 在 `[PROMPT]` 中加一句：“`__alltraps` 由硬件经 `stvec` 跳入，不是被 `call` 调用，不要添加普通函数的栈帧操作”。

### 第二次迭代：指令对了，但删掉了提交要求的注释

**AI 生成的代码：**

```asm
__alltraps:
    SAVE_ALL

    mv a0, sp
    jal trap

    .globl __trapret
__trapret:
    RESTORE_ALL
    sret
```

**发现的问题：**

- 指令序列正确，但 AI 把 `#lab3 function1 YOUR CODE` 整行删除了，也没有保留 `# sp should be the same as before "jal trap"`。指导书明确要求保留 `lab3` 注释并把 `YOUR CODE` 换成学号，直接提交会不符合规范。
- 这类问题 AI 无法从代码语义中推断出来，属于“提交规范/作业约束”，必须由人写进提示词。

**问题解决策略：**

- 在 `[PROMPT]` 的“操作要求”中逐条写明：只替换哪一行、保留哪个注释前缀、把 `YOUR CODE` 换成哪个学号、保留哪一行注释。
- 在 `[GUARANTEE]` 中写明“不得新增/删除文件中的其他内容”，把修改范围限定为最小。

### 第三次迭代：补充验收标准后定稿

**最终提示词**（见第三节）增加了三条可验证的验收条件：

1. `make obj/kern/trap/trapentry.o` 必须通过且无警告；
2. `objdump` 中 `SAVE_ALL` 的 36 条 `sd` 之后必须恰好是 `mv a0, sp` 和 `jal trap`；
3. 合并 A、B 后 `make grade` 必须通过。

**最终结果：**

- ✅ `make obj/kern/trap/trapentry.o` 编译通过（`+ cc kern/trap/trapentry.S`，无警告）；
- ✅ 反汇编确认：

```asm
  62:  ee52        sd   s4,280(sp)
  64:  850a        mv   a0,sp
  66:  f9bff0ef    jal  ra,0 <__alltraps-0x2>   # 链接后填入 trap 的真实地址
000000000000006a <__trapret>:
```

- ✅ 在临时 worktree 中合并 `lab3-A`（已包含 B 的实现）后，`make grade` 得到 **100/100**（Test 1 35 + Test 2 25 + Test 3 40）。

### 关键改进点总结

1. 在 spec 中补全“`SAVE_ALL` 之后 `sp` 就是 Trap frame 指针”这一中间状态，避免 AI 重新构造参数。
2. 明确“`__alltraps` 不是普通函数”，禁止 prologue/epilogue，把 `sp` 不变量写成硬约束。
3. 把提交规范（保留 `#lab3` 注释、替换学号）写进提示词，而不是指望 AI 自己遵守。
4. 把验收方式（编译、反汇编、`make grade`）写进提示词，让 AI 的输出有可检查的落点。

---

## 五、思考题：`sync.h` 中的 `do {} while (0)`

文件 `code/kern/sync/sync.h`：

```c
#define local_intr_save(x) \
    do {                   \
        x = __intr_save(); \
    } while (0)
#define local_intr_restore(x) __intr_restore(x);
```

### 5.1 宏是文本替换，不是函数

`#define` 做的是预处理阶段的文本替换。宏体里如果有多条语句，直接展开到使用处时，语句的边界就不受控制。`do { ... } while (0)` 的作用，是把宏体包装成语法上的**一条完整语句**：

- `do` 后面必须跟一个语句（复合语句 `{ ... }` 算一条）；
- `while (0)` 让循环体恰好执行一次；
- 末尾的 `while (0)` 后面不需要分号，使用处照常写一个分号即可，看起来和普通函数调用完全一样。

### 5.2 解决 `if/else` 被拆散的问题

假设把宏写成裸的花括号：

```c
#define local_intr_save(x) { x = __intr_save(); }
```

下面这段代码：

```c
if (cond)
    local_intr_save(flag);
else
    do_something();
```

会被展开成：

```c
if (cond)
    { flag = __intr_save(); };   // ← 花括号后多出的分号是一条空语句
else                              // ← else 前面不再是一个完整的 if 语句
    do_something();
```

此时编译器会报 `else without a previous if`。原因是 `if (cond) { ... };` 中的 `;` 是一条独立的空语句，`if` 语句在 `;` 处已经结束，`else` 找不到可匹配的 `if`。

用 `do { ... } while (0)` 包起来后：

```c
if (cond)
    do { flag = __intr_save(); } while (0);
else
    do_something();
```

`do ... while (0);` 整体是一条语句，末尾的分号属于这条 `do-while` 语句，不会额外产生空语句，`else` 可以正确匹配。

### 5.3 `while (0)` 保证只执行一次

`do-while` 是“先执行后判断”的循环。条件为常量 `0`，所以循环体执行一次后立即退出。编译器在优化时会把它消掉，不会带来运行时开销。

### 5.4 本文件里的反例：`local_intr_restore`

`sync.h` 中另一个宏没有使用 `do {} while (0)`：

```c
#define local_intr_restore(x) __intr_restore(x);
```

宏体自带分号。把它放进同样的 `if/else`：

```c
if (cond)
    local_intr_restore(flag);
else
    do_something();
```

展开后是：

```c
if (cond)
    __intr_restore(flag);;   // ← 宏体自带的分号 + 使用处的分号 = 多一条空语句
else
    do_something();
```

同样会导致 `else without a previous if`。这个反例正好说明：**只有把宏体包成 `do {} while (0)`，宏才能安全地出现在 `if/else`、`for/while` 等只接受单条语句的位置**。

### 5.5 进一步讨论

- **宏参数要加括号**：通用规则是 `#define M(x) ((x) + 1)`，防止 `M(a + b) * c` 之类的展开优先级错误。本文件里的 `x` 直接作为赋值左值使用，问题不明显，但仍是好习惯。
- **`do {} while (0)` 不是表达式**：它只能用在“语句”位置。如果需要 `y = MAX(a, b)` 这样的表达式宏，不能用 `do-while`，应使用 `({ ... })` 语句表达式（GCC 扩展）或 `static inline` 函数。
- **本实验中的实际用途**：`kern/mm/pmm.c` 的 `page_init`、`page_alloc`、`page_free` 等函数用 `local_intr_save(intr_flag)` 关中断、`local_intr_restore(intr_flag)` 恢复，保证物理页链表操作的原子性。`local_intr_save` 必须能安全地出现在这些函数体的任意语句位置，这正是 `do {} while (0)` 要解决的问题。
- **为什么 `__intr_save` 返回 `bool`**：它记录“进入临界区前中断是否已经开启”。如果之前已经关闭（嵌套临界区），`__intr_restore(false)` 不会误开启中断，从而支持嵌套。
