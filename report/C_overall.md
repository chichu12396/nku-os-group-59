# 三、实验整体逻辑分析

> 本章回答两个问题：这一章按照什么主线展开；各个功能为什么要按这个顺序实现。

## 3.1 本章节的逻辑主线

### 3.1.1 一句话概括

本章围绕“**让内核能够响应突发事件**”展开。Lab2 让内核能够管理物理内存，但内核仍然是一条“从 `kern_init` 一直往下执行”的直线；本章要让它具备在任意时刻被硬件打断、保存现场、进入 C 语言处理、处理完再**正确回到被打断的位置**继续执行的能力。

这条主线可以拆成五个环节：

```
能产生 Trap → 能保存上下文 → 能进入 C 处理 → 能恢复上下文 → 能正确返回
```

任何一个环节缺失，后面的环节都无法验证：没有保存就无法恢复；没有恢复就无法返回；没有正确的 `epc` 就会反复触发同一条异常。

### 3.1.2 完整链路

```
kern_init()
  ├─ idt_init()          stvec = __alltraps；sscratch = 0
  ├─ pmm_init()          Lab2 的物理内存管理就绪
  ├─ idt_init()          再次确保 Trap 入口有效
  ├─ clock_init()        sie.STIE = 1；sbi_set_timer(now + 100000)；ticks = 0
  └─ intr_enable()       sstatus.SIE = 1
          │
          │  约 10 ms 后，定时器到期
          ▼
硬件（S 态 Trap 响应）
  ├─ sepc     ← 被打断指令的地址
  ├─ scause   ← 0x8000000000000005（最高位 1 表示中断，低 63 位 5 表示 S 态定时器）
  ├─ sstatus.SPP  ← 陷入前的特权级（本实验为 S，即 1）
  ├─ sstatus.SPIE ← 陷入前的 SIE
  ├─ sstatus.SIE  ← 0（进入 Trap 后先关中断）
  └─ pc       ← stvec = __alltraps
          │
          ▼
__alltraps（C 负责的入口）
  ├─ SAVE_ALL：sp -= 288，把 x0..x31（x2 单独处理）和 sstatus/sepc/sbadaddr/scause
  │             按 struct trapframe 的布局写入内核栈
  ├─ mv a0, sp        // a0 = Trap frame 地址
  └─ jal trap         // 调用 C 函数；ra = __trapret 的地址
          │
          ▼
trap(tf)
  └─ trap_dispatch(tf)
       ├─ (intptr_t)tf->cause < 0  → interrupt_handler(tf)
       └─ (intptr_t)tf->cause ≥ 0  → exception_handler(tf)
          │
          ▼
__trapret
  └─ RESTORE_ALL（A 负责）
       ├─ sstatus ← tf->status；sepc ← tf->epc
       ├─ 恢复 x1、x3..x31
       └─ 最后恢复 x2（陷入前的 sp）
          │
          ▼
sret
  ├─ pc    ← sepc
  ├─ 特权级 ← SPP
  └─ SIE   ← SPIE
```

### 3.1.3 为什么是这几个 CSR

| CSR | 在本实验中的作用 | 不这样做会怎样 |
|---|---|---|
| `stvec` | Trap 入口地址，`idt_init()` 写入 `__alltraps` | 硬件不知道跳到哪里，Trap 无法进入内核 |
| `sepc` | 保存被打断/触发异常的指令地址；`sret` 从它恢复 PC | 无法回到原执行流；handler 修改 `epc` 也失去意义 |
| `scause` | 说明 Trap 原因；最高位区分中断/异常 | 无法分类处理，只能一律 panic |
| `sstatus.SIE` | S 态中断总开关 | 为 0 时硬件不会响应可屏蔽中断 |
| `sstatus.SPIE` | 进入 Trap 时保存旧的 SIE；`sret` 时恢复到 SIE | 返回后中断使能状态错误，可能丢中断或意外开中断 |
| `sstatus.SPP` | 记录陷入前的特权级 | `sret` 可能返回到错误的特权级 |
| `sscratch` | `SAVE_ALL` 用它暂存陷入前的 `sp`，随后清零 | 没有临时寄存器保存旧 `sp`；清零后还能识别“Trap 发生在内核态”的递归异常 |
| `sret` | 与上述 CSR 成对出现，完成返回 | 只能用 `mret` 或手工跳转，语义不正确 |

这些 CSR 不是孤立存在的：**硬件在进入 Trap 时写一组，`SAVE_ALL` 把它们抄到栈上，C 代码通过 Trap frame 读写，`RESTORE_ALL` 再写回 CSR，最后 `sret` 消费它们**。整个实验的“上下文管理”就是围绕这组寄存器展开的。

### 3.1.4 `scause` 最高位是中断/异常的分水岭

RISC-V 规定：`scause` 最高位为 1 表示**中断**（异步），为 0 表示**异常**（同步）。因此：

- `0x8000000000000005`：最高位 1，低 63 位 5 → S 态定时器中断；
- `0x0000000000000003`：最高位 0，低 63 位 3 → 断点异常；
- `0x0000000000000002`：非法指令异常。

`trap_dispatch()` 用 `(intptr_t)tf->cause < 0` 来判断：把无符号数转成有符号数后，最高位为 1 就是负数。B 的 `interrupt_handler()` 再用 `cause & ~(1 << 63)` 取出真正的中断号。这个“最高位”设计把中断和异常放在同一个 CSR 里，硬件只需要一个原因寄存器。

### 3.1.5 Trap frame 是三方共享的唯一契约

Trap frame 是本章最重要的数据结构。它由三部分代码共同遵守：

1. **汇编保存**：`SAVE_ALL` 规定布局，并把寄存器写进去；
2. **C 处理**：`trap()`、`interrupt_handler()`、`exception_handler()` 通过 `struct trapframe *` 读写；
3. **汇编恢复**：`RESTORE_ALL` 按同一布局读出来，写回寄存器和 CSR。

布局如下（RV64，`REGBYTES = 8`）：

| 偏移（字节） | 内容 | 偏移（字节） | 内容 |
|---|---|---|---|
| 0 | `x0/zero` | 152–248 | `s3`..`t6` |
| 8 | `x1/ra` | 256 | `sstatus` |
| 16 | `x2/sp`（来自 `sscratch`） | 264 | `sepc` |
| 24–248 | `x3`..`x31` | 272 | `sbadaddr` |
| — | — | 280 | `scause` |

总大小 36 × 8 = **288 字节**，与 `SAVE_ALL` 的 `addi sp, sp, -36 * REGBYTES` 完全一致。

两个容易出错的细节：

- **`x2(sp)` 与其他寄存器不同**：`SAVE_ALL` 先把陷入前的 `sp` 存进 `sscratch`，等 32 个通用寄存器都存完后，再用 `csrrw s0, sscratch, x0` 把它取出来存到 offset 16。因此 `RESTORE_ALL` 也必须**最后**恢复 `sp`，因为此前所有 `LOAD` 都要用当前 `sp` 寻址。
- **`sstatus` 与 `sepc` 要写回 CSR，而不是只恢复通用寄存器**：B 的异常处理会修改 `tf->epc`（让 PC 前进到下一条指令），A 的 `RESTORE_ALL` 必须把修改后的值写回 `sepc`；否则 `sret` 仍回到原指令，异常无限循环。

### 3.1.6 时钟中断为什么必须“重新上弦”

`clock_init()` 做了两件事：

```c
set_csr(sie, MIP_STIP);          // 允许 S 态定时器中断
clock_set_next_event();          // sbi_set_timer(rdtime() + 100000)
```

`sie.STIE` 只是“允许”这类中断，它本身不会产生事件；真正决定“下一次什么时候触发”的是 `sbi_set_timer()`。硬件在定时器到期时产生一次中断，但**不会自动安排下一次**。所以 `interrupt_handler()` 每处理一次时钟中断，都必须再调用一次 `clock_set_next_event()`，否则系统只会收到一次时钟中断。

`timebase = 100000`，QEMU 的 `timebase` 是 10 MHz，所以 100000 个周期 = 10 ms，即 100 次/秒；`TICK_NUM = 100`，所以每 100 次（约 1 秒）打印一行 `100 ticks`。`ticks` 被声明为 `volatile size_t`，因为它在中断处理函数里被修改、在主循环里被读取，编译器不能把它缓存在寄存器里。

### 3.1.7 本章与 Lab2 的衔接

Lab2 的物理内存管理已经就绪：`pmm_init()` 建立页分配器，`alloc_pages()`/`free_pages()` 维护空闲链表。这些操作必须是原子的，否则中断可能插在“取出链表头”和“更新链表头”之间，破坏数据结构。框架用 `local_intr_save()`/`local_intr_restore()` 在临界区内关中断：

```c
local_intr_save(intr_flag);   // 若 SIE=1，则关中断并记录 flag=1
/* 操作空闲链表 */
local_intr_restore(intr_flag); // 仅当之前是开的，才重新开中断
```

这正是本章“Trap 机制”与 Lab2“内存管理”的交汇点：**Trap 让内核能响应外部事件，而临界区让内核在响应事件时不被另一件事打断**。

---

## 3.2 功能的逐步实现

### 3.2.1 第一步：先读懂 `SAVE_ALL` 与 `struct trapframe`

**做了什么**：读 `SAVE_ALL` 的 36 条 `STORE`，对照 `struct trapframe` 的字段顺序，确认每个偏移的含义。

**为什么先做这个**：Trap frame 是汇编保存、C 处理、汇编恢复三方共享的契约。布局理解错了，后面写的每一行代码都建立在错误的前提上。特别是 `x2` 的特殊处理（来自 `sscratch`、必须最后恢复）和四个 CSR 字段的位置（32/33/34/35），是后面所有代码的“地基”。

**不做的后果**：`RESTORE_ALL` 会按错误偏移取值，Test 1 的寄存器现场全部错乱；`__alltraps` 可能把错误的地址传给 `trap()`。

### 3.2.2 第二步：实现 `RESTORE_ALL` 与 `__alltraps`，搭起闭环

**做了什么**：

- `__alltraps`（C）：`SAVE_ALL` 之后执行 `mv a0, sp` 和 `jal trap`，把 Trap frame 指针按调用约定传给 `trap()`；
- `RESTORE_ALL`（A）：先写回 `sstatus`/`sepc`，再恢复 `x1`、`x3`..`x31`，最后恢复 `x2`。

**为什么先做这个**：没有“进入 → 保存 → 调用 C → 恢复 → 返回”的闭环，任何 handler 都无法被验证。即使 `interrupt_handler()` 写得完全正确，如果 `RESTORE_ALL` 没有恢复 `sp` 或没有写回 `sepc`，系统也回不到被打断的代码，测试根本跑不完。

**两个必须守住的不变量**：

1. `__alltraps` 中 `jal trap` 前后 `sp` 不变。`RESTORE_ALL` 完全依靠 `sp` 相对偏移寻址；`sp` 一旦改变，所有 `LOAD` 都会读错位置。
2. `RESTORE_ALL` 必须把 `tf->epc` 写回 `sepc`。B 的 handler 修改的是栈上的 `tf->epc`，不写回 CSR 就等于没改。

**如果不这样做的后果**：

- `sp` 被改动：Trap frame 偏移全部错位，寄存器恢复成垃圾值，可能直接跑飞；
- `sepc` 没写回：`sret` 回到触发异常的指令，再次触发同一个异常，形成死循环、串口刷屏。

### 3.2.3 第三步：实现 `interrupt_handler()` 与 `exception_handler()`

**做了什么**：

- `interrupt_handler()`：按 `cause & ~(1 << 63)` 区分中断号。时钟中断先 `clock_set_next_event()` 重新上弦，再 `ticks++`；每 `TICK_NUM` 次打印统计；累计打印达到 `SHUTDOWN_AFTER` 后关机。其他中断按类型输出提示；未知中断用 `print_trapframe(tf)` 兜底。
- `exception_handler()`：`CAUSE_ILLEGAL_INSTRUCTION` 和 `CAUSE_BREAKPOINT` 输出规定格式的信息，并让 `tf->epc` 前进该指令的长度；其他异常用 `print_trapframe(tf)` 兜底。

**为什么接着做这个**：有了闭环，才能“处理并返回”。时钟中断是唯一能周期性触发的 Trap，是验证闭环最方便的手段；异常则验证“修改 `epc` 后能否正确返回”。

**关键点**：

- 时钟中断不重新上弦 → 只收到一次，Test 3 无法达到 200 ticks；
- 异常不推进 `epc` → 返回后重复执行同一条指令，死循环；
- 异常推进长度错误 → 跳过或落入指令中间，Test 1/2 失败。

### 3.2.4 第四步：用三种场景验证，并理解 `epc` 的步长

**做了什么**：用时钟中断、断点、非法指令三类 Trap 验证整个机制。

| 测试 | 触发的 Trap | 覆盖的能力 | `epc` 前进量 |
|---|---|---|---|
| Test 1 | `ebreak`（被汇编为 2 字节的 `c.ebreak`） | 26 个寄存器的保存/恢复、断点返回 | **2 字节** |
| Test 2 | `.word 0x0000007b`（4 字节非法指令） | 非法指令处理、handler 兜底 | **4 字节** |
| Test 3 | S 态定时器中断 | 持续中断、重新上弦、Trap 反复返回 | 不涉及（中断返回原指令） |

**为什么不能固定加 4**：RISC-V 的压缩指令（C 扩展）是 16 位，普通指令是 32 位。`ebreak` 在默认工具链下被汇编成 `c.ebreak`（机器码 `0x9002`，2 字节），而测试里的非法指令 `.word 0x0000007b` 是 4 字节。如果统一加 4，断点测试会跳过 `ebreak` 后面的一条指令，导致 Test 1 失败。

**正确的判断方法**：读取 `epc` 处指令的低两位：

```c
uint16_t insn = *(const volatile uint16_t *)tf->epc;
tf->epc += ((insn & 0x3) == 0x3) ? 4 : 2;
```

低两位 `11` 表示 32 位指令；否则是 16 位压缩指令。

**如果不这样做的后果**：

- 固定加 4：Test 1 的 `li a0, 0x105` 被跳过，后续 `bne` 比较失败，返回 `1`，测试报 `FAIL (register context)`；
- 固定加 2：非法指令只前进了半个指令，下一次取指会落在指令中间，产生新的非法指令，可能无限异常。

### 3.2.5 第五步：理解关中断、临界区与原子性

**做了什么**：看 `pmm.c` 里的 `local_intr_save/restore` 如何保护空闲链表操作。

**为什么最后理解这个**：它不参与“一次 Trap 的闭环”，但解释了“为什么 Trap 机制必须和同步原语配合”。在单核上，关中断是最小粒度的互斥：只要 `SIE = 0`，当前 hart 就不会响应可屏蔽中断，临界区内的多条指令就能原子完成。`__intr_save()` 返回“之前是否开着中断”，使临界区可以嵌套：内层恢复时不会误开中断。

**与本章的关系**：Trap 是“打断”的来源，临界区是“暂时不接受打断”的手段。两者一开一关，构成内核并发控制的最基础一对概念。

### 3.2.6 为什么必须是这个顺序

```
读懂布局 ──→ 保存/恢复/入口闭环 ──→ handler 处理 ──→ 三类场景验证 ──→ 临界区与并发
   (地基)          (骨架)              (血肉)            (验收)             (延伸)
```

后一步都依赖前一步：没有布局就无法写恢复；没有闭环就无法验证 handler；没有 handler 就无法产生可观测的输出；没有验证就无法确认步长、重新上弦这些细节。反过来，如果先写 handler 再补 `RESTORE_ALL`，handler 的输出可能根本回不到原执行流，调试信号会被“系统跑飞”淹没。

---

## 3.3 一次异常与一次中断的对比

| 维度 | 异常（如断点、非法指令） | 中断（如时钟） |
|---|---|---|
| 触发方式 | 同步：由当前指令引起 | 异步：由外部定时器引起 |
| `sepc` 指向 | 触发异常的指令本身 | 被打断的指令（下一次继续执行它） |
| 返回后 | 必须跳过异常指令，否则重复触发 | 必须回到原指令继续执行 |
| `epc` 处理 | handler 按指令长度前进 2/4 字节 | 不修改 `epc` |
| 典型验证 | Test 1、Test 2 | Test 3 |
| 失败表现 | 死循环、刷屏、跳过指令 | 只收到一次中断、`ticks` 不增长 |

这张表解释了为什么 `exception_handler()` 要推进 `epc`，而 `interrupt_handler()` 不能推进 `epc`：两者的“返回语义”不同。

---

## 3.4 小结

本章的逻辑可以概括为：

1. **硬件**负责在 Trap 发生时记录 `sepc`、`scause`、`sstatus` 并跳到 `stvec`；
2. **`SAVE_ALL` + `__alltraps`** 负责把现场固化成 Trap frame，并按调用约定交给 C；
3. **`trap_dispatch` + 两个 handler** 负责按 `scause` 分类处理，必要时修改 `tf->epc`、重新上弦定时器；
4. **`RESTORE_ALL` + `sret`** 负责把 Trap frame 写回处理器状态，回到正确的执行流；
5. **临界区**负责在需要原子性的代码段暂时关闭这套机制。

理解了这五步，就理解了“内核如何从一条直线执行流，变成能够被随时打断、又能正确恢复的可抢占执行流”。
