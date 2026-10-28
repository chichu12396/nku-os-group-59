# Lab3 成员 A 提示词记录：`RESTORE_ALL`

> 对应指导书「功能模块一：Trap 上下文恢复与 Trap 入口」中 A 负责的部分。
>
> 代码位置：`code/kern/trap/trapentry.S` 的 `.macro RESTORE_ALL` … `.endm`（第 57–61 行）。
>
> 本文件保存 **spec 的设计思路** 与 **提示词正文**；迭代过程等第 3 步生成代码后再回填。

---

## 一、spec 是怎么设计的

先读 `SAVE_ALL` 和 `struct trapframe`，把「输入是什么、必须输出什么、哪些顺序不能变」固定下来，再写成四段式里的 `[SPECIFICATION]`。

| 项目 | 内容 |
|---|---|
| 输入 | `sp` 指向一个由 `SAVE_ALL` 压好的 trapframe，共 36 个 64 位字 |
| 输出 | 通用寄存器 `x1`、`x3`–`x31`；CSR `sstatus`、`sepc`；最后是 `x2`（陷入前的 sp） |
| 布局来源 | offset 0–31 = `x0`–`x31`，32 = `status`，33 = `epc`，34 = `badvaddr`，35 = `cause` |
| 关键不变式 | 写 CSR 要在恢复通用寄存器之前；`x2` 必须最后恢复，之后不能再访存 |
| 与 B 的契约 | 写回的是 `tf->epc`，异常处理函数可能已经把它改成下一条指令的地址 |
| 边界 | `x0` 不用恢复；`sbadaddr`/`scause` 不恢复；不得清 `SPP`、不得假设返回 U 态 |
| 验收 | 单独汇编通过；`objdump` 顺序正确；Test 1 的寄存器现场与断点返回；Test 3 的持续时钟 |

说明：

- 指导书写的是通用的「`sret` 前把 `SPP` 置 0 返回 U 态」，但本实验的 trap 全部从 S 态触发，`SPP=1`。因此 spec 里明确要求**回写保存的 `sstatus`，不要手工清 SPP**，否则 `sret` 会跳到 U 态。
- 异常返回的 `sepc` 偏移（2 字节 `c.ebreak` / 4 字节非法指令）由 B 的 `exception_handler` 计算，`RESTORE_ALL` 只负责把结果写回 CSR，所以 spec 里禁止在这里做 `+2/+4`。

---

## 二、提示词（v1，运行期验证后定稿）

````markdown
[PROMPT]
**任务**：修改 `kern/trap/trapentry.S`，在 `.macro RESTORE_ALL` 与 `.endm` 之间实现 Trap 上下文恢复宏。它与文件中已有的 `SAVE_ALL` 配对：`SAVE_ALL` 在进入 Trap 时把一个完整的 `struct trapframe` 放到当前内核栈顶，`RESTORE_ALL` 要在 `__trapret` 中被调用，从该 trapframe 恢复处理器状态，使紧随其后的 `sret` 能回到被中断的执行流。只处理本实验的 S 态陷入场景。

**操作要求**：必须直接修改项目中的真实文件，而不只是展示代码；只替换 `#lab3 function1 YOUR CODE` 所在的宏体，保留该 `#lab3` 注释和文件其余全部内容；不得修改 `SAVE_ALL`、`struct trapframe`、`trap()` 签名、`.align(2)` 以及 `__alltraps` / `__trapret` 的结构；不要新增函数、全局符号或数据。

**输出要求**：直接进行文件操作，使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION] 中的信息，以工程中的真实代码和布局为准，不要引入与本任务无关的功能。

[RELY]
// 数据结构（kern/trap/trap.h）
struct pushregs {
    uintptr_t zero, ra, sp, gp, tp, t0, t1, t2, s0, s1,
              a0, a1, a2, a3, a4, a5, a6, a7,
              s2, s3, s4, s5, s6, s7, s8, s9, s10, s11,
              t3, t4, t5, t6;
};
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
    addi sp, sp, -36 * REGBYTES       // 在栈上分配 trapframe
    STORE x0,  0*REGBYTES(sp)
    STORE x1,  1*REGBYTES(sp)
    STORE x3,  3*REGBYTES(sp)
    ...
    STORE x31, 31*REGBYTES(sp)        // 注意：x2 的槽位在下面单独写
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
// 上面的 `...` 表示原文件中 x4 .. x30 的连续 STORE，完整内容以 kern/trap/trapentry.S 为准。

// 可用宏与常量（libs/riscv.h）
// REGBYTES = 8（64 位）；LOAD = ld；STORE = sd

// 调用链
// __alltraps: SAVE_ALL →（C 负责：把 sp 作为 tf 传给 trap）→ __trapret:
// __trapret: RESTORE_ALL → sret
// sp 在调用 trap() 前后保持不变，trap() 返回后 sp 仍指向同一个 trapframe。

// sret 语义
// pc ← sepc；SIE ← SPIE；根据 SPP 选择返回特权级。本实验全部从 S 态陷入，SPP=1。

[GUARANTEE]
必须实现或修改的接口：`.macro RESTORE_ALL` 的宏体（汇编宏，没有 C 函数签名）。
可以添加：宏内部使用的临时寄存器；但不得新增宏、函数、全局符号或数据。

[SPECIFICATION]
## RESTORE_ALL
**Pre-Condition**:
- `sp` 指向一个由 `SAVE_ALL` 构造的完整 trapframe（36 个字）。
- 进入宏时 `sstatus.SIE = 0`、`sstatus.SPP = 1`（本实验均从 S 态陷入）。
- 除 `sp` 外，通用寄存器的内容不可信；CSR 中的 `sstatus`/`sepc` 不一定等于 trapframe 中的值。

**Post-Condition**:
- `sstatus` 被写回为 `tf->status`，`sepc` 被写回为 `tf->epc`；`tf->epc` 是异常处理函数可能已经修改过的值。
- `x1`、`x3` … `x31` 恢复为 trapframe 对应槽位的值。
- `x2` 恢复为 `tf->gpr.sp`（Trap 发生前的 sp）。
- 恢复 `x2` 之后不再访问栈；宏结束时处理器状态可以直接执行 `sret`。
- `x0` 保持 0；`sbadaddr`/`scause` 不要求恢复。

**Case 1（正常恢复）**:
- 先从 trapframe 的高偏移读出 `sepc` 与 `sstatus` 并写回 CSR，再按偏移恢复 `x1`、`x3` … `x31`，最后恢复 `x2`。

**Requirements**:
- 写 CSR 只能借助通用寄存器；所用临时寄存器必须在后续步骤中从 trapframe 恢复，不能破坏最终结果。
- `x2` 必须最后恢复，且之后不得再有任何使用 `sp` 的指令。
- 偏移必须与 `SAVE_ALL` 严格一致（32 = status，33 = epc），不得自行假设其他布局。
- 不得清 `SPP`、不得假设返回到 U 态，也不得改变 `sstatus.SIE` 的保存语义。
- 只把 `tf->epc` 写回 `sepc`，不自行计算 `+2`/`+4`（指令长度由异常处理函数负责）。
- 宏必须能在本工程的 Makefile 下用 `riscv64-unknown-elf-as` 成功汇编。
````

---

## 三、迭代记录

### 第 1 次迭代（提示词 v1）

**提示词版本**：v1（上面第二节，未再修改）

**生成结果**：生成 `.macro RESTORE_ALL` 的完整宏体：

- 先用 `LOAD s1, 32*REGBYTES(sp)` / `LOAD s2, 33*REGBYTES(sp)` 取出 `sstatus`/`sepc` 并 `csrw` 回 CSR；
- 再按 x1、x3 … x31 的顺序恢复 30 个通用寄存器；
- 最后 `LOAD x2, 2*REGBYTES(sp)` 恢复陷入前的 sp。

**验证**：

- `cd code && make obj/kern/trap/trapentry.o` 通过；
- `objdump -d` 中 `__trapret` 的指令顺序为：`ld s1,256(sp)` → `ld s2,264(sp)` → `csrw sstatus,s1` → `csrw sepc,s2` → 30 条 `ld`（偏移 8 … 248）→ `ld sp,16(sp)` → `sret`，与 `SAVE_ALL` 的布局和 spec 完全对应；
- 运行期验证（Test 1 的寄存器现场/断点返回、Test 3 的持续时钟）要等 C 的 `__alltraps` 合入后才能做。

**遇到的问题**：无。v1 一次通过静态检查。

**问题解决策略**：无。提示词已经把「x2 最后恢复、CSR 先写、偏移 32/33 与 SAVE_ALL 一致」写进 Requirements，生成结果没有踩这些坑。

**最终结果**：静态检查通过，运行期待验证。

