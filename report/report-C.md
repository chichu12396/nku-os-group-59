### 功能模块：进程调度

**负责人：** 2411033-季艾佳

#### 模块功能描述

**需要实现/修改的函数：**

```c
// 列出本模块涉及的所有函数签名
void cpu_idle(void);
void schedule(void);
void proc_run(struct proc_struct *proc);
void switch_to(struct context *from, struct context *to);
```

**功能说明：**

本模块负责内核线程的调度与上下文切换，使已经创建的线程能够轮流使用 CPU，处理首次运行、线程切换以及没有其他可运行线程时的空闲执行。
- cpu_idle()：空闲线程的执行主体，持续检查 current->need_resched，需要重调度时调用 schedule()。
- schedule()：在中断保护下清除调度标志，沿进程链表循环寻找 PROC_RUNNABLE 线程；找不到时使用 idleproc。更新目标线程的运行次数，并按需调用 proc_run()。
- proc_run()：在中断保护下保存旧线程指针、更新 current，设置目标线程的 Sv39 页表并刷新 TLB，然后调用 switch_to()。
- switch_to()：按照 struct context 的布局保存旧线程的 ra、`sp`、`s0～s11`，恢复目标线程的对应寄存器，通过 ret 继续目标线程的执行。
本模块依赖内存管理模块提供内核栈和页表支持，并使用进程创建模块准备的 PCB、就绪状态和初始上下文。新线程首次运行时，经 forkret → forkrets → __trapret 恢复预先构造的现场，最终进入线程函数。

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

### Challenge：中断状态的保存、屏蔽与恢复

**负责人：** 2411033-季艾佳

`local_intr_save(intr_flag)` 和 `local_intr_restore(intr_flag)` 用于保护临界区。前者记录进入临界区之前的中断使能状态，并关闭中断；后者根据记录恢复原状态，避免无条件开启中断。

**1. 保存状态并关闭中断**

`local_intr_save()` 最终调用 `__intr_save()`：

```c
static inline bool __intr_save(void)
{
    if (read_csr(sstatus) & SSTATUS_SIE)
    {
        intr_disable();
        return 1;
    }
    return 0;
}
```

函数读取 `sstatus`，通过 `SSTATUS_SIE` 掩码检查 S 态中断使能位：

- 原来允许中断：调用 `intr_disable()`，返回 `1`。
- 原来已经关闭中断：保持关闭，返回 `0`。

`intr_disable()` 通过清除 `sstatus.SIE` 屏蔽相应的中断：

```c
void intr_disable(void)
{
    clear_csr(sstatus, SSTATUS_SIE);
}
```

因此，`intr_flag` 保存的是原来的中断开关状态，并非整个 `sstatus`。

**2. 按原状态恢复中断**

`local_intr_restore()` 最终调用：

```c
static inline void __intr_restore(bool flag)
{
    if (flag)
    {
        intr_enable();
    }
}
```

只有进入临界区前允许中断，函数才调用 `intr_enable()`，重新设置 `sstatus.SIE`。如果之前已经关闭中断，则继续保持关闭。

这种方式可以配合嵌套的临界区。以外层调用前中断开启为例：

| 操作 | 保存的状态 | 操作后的 SIE |
|---|---:|---:|
| 外层保存并关闭中断 | 外层 flag = 1 | 0 |
| 内层保存并关闭中断 | 内层 flag = 0 | 0 |
| 内层恢复 | 根据内层 flag 保持关闭 | 0 |
| 外层恢复 | 根据外层 flag 重新开启 | 1 |

内层退出时不会提前打开中断，外层临界区仍受到保护。

**3. 在本实验调度中的作用**

`schedule()` 需要读取线程状态、选择目标线程并更新调度信息；`proc_run()` 需要更新 `current`、切换页表并恢复目标上下文。这些操作需要保持一致，避免中断处理代码观察到只完成一部分的切换状态。

因此，两者均在关键区域使用：

```c
bool intr_flag;
local_intr_save(intr_flag);

/* 调度或上下文切换的关键操作 */

local_intr_restore(intr_flag);
```

当 `schedule()` 调用 `proc_run()` 时，中断已经关闭，内层保存到的状态为 `0`，不会提前开启中断。如果执行中切换到了其他线程，原线程需要等到再次获得 CPU 后，才继续完成自身调用链中的中断恢复。

**4. `do { ... } while (0)` 的作用**

```c
#define local_intr_save(x) \
    do {                   \
        x = __intr_save(); \
    } while (0)
```

这里的循环只执行一次，作用是把宏包装成一条完整语句，方便在 `if...else` 等位置使用，并为以后增加多条语句保留安全的语法结构。它本身不负责关闭中断，关闭动作由 `__intr_save()` 调用的 `intr_disable()` 完成。

这种保护只影响当前 CPU 上相应的可屏蔽中断，不能阻止同步异常，也不能单独解决多核 CPU 之间的并发访问问题。