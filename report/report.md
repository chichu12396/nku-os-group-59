# 操作系统实验报告

## 实验基本信息

| 项目 | 内容 |
|------|------|
| **实验名称** |  Lab4：进程管理 |
| **小组成员** | 2411033-季艾佳、2412102-聂海丽、2413346-易响 |
| **完成日期** | 2026-11-15 |

### 小组分工

| 成员 | 负责的练习/模块 |
|---|---|
| 2412102-聂海丽 | `kern/mm/pmm.c` 的 `page_insert()`、`page_remove()`（含内部辅助 `page_remove_pte()`）；两道分页思考题；实验目的、环境、整体逻辑、总结等公共章节初稿 |
| 2413346-易响  | `kern/process/proc.c` 的 `alloc_proc()`、`proc_init()`、`kernel_thread()`、`do_fork()`、`copy_thread()`、`copy_mm()` |
|2411033-季艾佳 | `cpu_idle()`、`proc_run()`、`schedule()`、`switch_to()`；开关中断 Challenge；整体验收、最终报告整合与提交版本整理 |

---

## 一、实验目的

本实验的主要目的是：

1. 理解 RISC-V Sv39 多级页表中“线性地址到物理页”的映射建立、更新与撤销过程。
2. 掌握页表项内容、物理页引用计数和 TLB 状态三者一致性的维护方法。
3. 理解内核线程的 PCB、内核栈、中断帧和上下文是如何构造的，以及线程如何被调度执行。
4. 理解 `schedule()` 如何选择就绪线程、`proc_run()` 如何切换页表、`switch_to()` 如何保存和恢复寄存器现场。
5. 体验用 AI 辅助完成操作系统核心代码的 spec 设计、提示词迭代、代码核对和测试验证。

---

## 二、实验环境

| 成员 | AI 编程工具 | 底层模型 | 
|------|------------|---------|
| 2411033-季艾佳 | Cline（VS Code 插件） | GPT-6.1 | 
| 2412102-聂海丽 | Claude Code（终端 Agent） | DeepSeek-V4-Flash | 
| 2413346-易响 | DeepSeek Harness | DeepSeek-V4-Flash | 

**说明：**

- **AI 编程工具**：指具体使用的终端工具、编辑器插件、桌面应用或浏览器界面
- **底层模型**：指该工具使用的大语言模型及版本

---

## 三、实验整体逻辑分析

### 3.1 本章节的逻辑主线

本章围绕“让内核从具备物理内存管理，走到能够创建、调度并运行第一个内核线程”展开。可以把整条主线概括为：

> **先把物理内存和页表准备好，再创建第一个可运行的内核线程，最后让调度器把 CPU 交给它，并通过上下文切换完成首次运行。**

### 3.2 功能的逐步实现与顺序

启动链如下：

```text
kern_init
 → pmm_init          物理内存管理 + 启动页表 + 页映射自检（A）
 → pic_init/idt_init 中断控制器与中断描述符
 → vmm_init          VMA 管理自检
 → proc_init         idleproc / initproc（B）
 → clock_init        时钟中断
 → intr_enable       开中断
 → cpu_idle          need_resched 循环（C）
 → schedule          选择下一个 PROC_RUNNABLE（C）
 → proc_run          切换 current 与页表（C）
 → switch_to         保存/恢复 context（C）
 → forkret/forkrets/__trapret/kernel_thread_entry → 线程函数（B/C 联调）
```

按这个顺序的原因：

1. **先有物理内存管理和页表**：内核栈、PCB、页表页本身都要从物理页分配器中获得；没有页表，内核无法用虚拟地址访问这些结构。
2. **先通过页映射自检**：`pmm_init()` 中的 `check_pgdir()` 和 `check_boot_pgdir()` 会实际调用 A 的 `page_insert/page_remove`，确认 PTE、引用计数和 TLB 行为正确，后续线程的内核栈映射才可靠。
3. **再创建线程**：B 的 `proc_init()` 需要分配 PCB 和内核栈，构造 `idleproc` 与 `initproc`，并设置 `current`。
4. **最后调度与切换**：C 的 `schedule()` 从就绪链表中选线程，`proc_run()` 更新 `current`、切换页表并调用 `switch_to()`；`switch_to()` 恢复的 `context.ra` 指向 `forkret`，从而接上已有的中断帧恢复链。


### 3.4 首次运行的衔接

首次运行不是直接“跳进线程函数”，而是：

```text
switch_to 恢复新线程 context
 → context.ra = forkret
 → forkret(current->tf) → forkrets(current->tf)
 → __trapret 恢复中断帧
 → kernel_thread_entry(fn, arg)
 → 目标线程函数
```

这条链要求`copy_thread()` 正确设置 `context.ra`、`context.sp` 和内核栈上的中断帧， `switch_to()` 严格按 `struct context` 的字段顺序恢复寄存器。页操作不直接参与每次线程创建，但为内核栈和页表提供了可用的内存基础。

---

## 四、实验内容与实现

<!-- 
说明：本部分按照 exercises 文档中的练习顺序组织
每个功能模块或者练习中可能包含多项任务，请根据实际情况调整
-->

### 功能模块一：虚拟内存页操作

**负责人：** 2412102-聂海丽

#### 4.1.1 模块功能描述

**需要实现/修改的函数：**

```c
int page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm);
void page_remove(pde_t *pgdir, uintptr_t la);

// 内部辅助函数
static void page_remove_pte(pde_t *pgdir, uintptr_t la, pte_t *ptep);
```

**模块在系统中的作用：**

本模块在现有多级页表框架上完成最基本的映射维护：

- `page_insert()` 把一个物理页挂到指定线性地址上；如果该地址已有映射，要正确处理“同一页重复映射”和“改映射到另一页”两种情况。
- `page_remove()` 撤销指定地址的映射，并维护物理页引用计数；未映射地址和重复删除都必须安全。
- 二者共同保证“叶子 PTE、物理页引用计数、TLB”三者一致。

**主要场景：**

| 场景 | 期望 |
|---|---|
| 地址未映射，插入新页 | 建立映射，`ref` 加 1 |
| 同一地址重复映射同一页 | 只更新权限，`ref` 不变 |
| 同一地址改映射另一页 | 旧页 `ref` 减 1，新页 `ref` 加 1 |
| 同一物理页映射到多个地址 | 每个地址各计一次引用 |
| 删除已映射地址 | `ref` 减 1，清 PTE，失效 TLB |
| 删除未映射/重复删除 | 静默返回，不 panic |


#### 4.1.2 规格说明（spec）

**1. 目标与位置**

在 `code/kern/mm/pmm.c` 的 `//LAB4 function1` 区域实现上述两个对外函数，并增加 `static page_remove_pte()` 作为内部辅助。

**2. 输入**

- `pgdir`：页表根的内核虚拟地址，调用方保证非空。
- `page`：已经分配的物理页描述符。
- `la`：任意线性地址，不要求页对齐；映射粒度为 4KB。
- `perm`：`PTE_U/PTE_W/PTE_R/PTE_X` 的组合；`PTE_V` 由 `pte_create()` 统一置位。

**3. 输出**

- `page_insert`：成功返回 `0`；`get_pte(create=1)` 失败返回 `-E_NO_MEM`。
- `page_remove`：无返回值；未映射时静默返回。

**4. 状态约束**

- 叶子 PTE 必须为 `pte_create(page2ppn(page), perm)`，权限位**赋值覆盖**而不是按位或。
- 新页引用计数加 1；同一页重复映射同一地址时引用计数不变。
- 同一地址改映射另一页时，旧页引用计数减 1，归零则 `free_page()`。
- 删除映射时引用计数减 1，归零则 `free_page()`，PTE 清 0。
- 每次叶子 PTE 变化后调用 `tlb_invalidate(pgdir, la)`。
- 不释放、不改动中间页表页的引用计数；中间页表由 `get_pte()` 分配并置 `ref = 1`。
- `page_remove` 必须使用 `get_pte(pgdir, la, 0)`，不得为删除而分配页表。

**5. 边界与幂等**

- 删除未映射地址：直接返回，不 panic。
- 重复删除同一地址：第二次为空操作。
- `get_pte` 失败：不写叶子 PTE，不修改 `page` 的引用计数，返回 `-E_NO_MEM`。
- `perm = 0`：生成 `V=1`、`R/W/X=0` 的 PTE；调用方不得访问该地址。

**6. 验收条件**

- `check_pgdir()` 全部断言通过。
- `check_boot_pgdir()` 全部断言通过。
- `test_lab4_pmm_basic()` 输出 `[Test PMM] PASS`。
- `make grade` 的 PMM 组为 `OK`。

#### 4.1.3 最终提示词（prompt）

以下是本次协作使用的最终提示词（由 spec 整理，实际生成时逐条核对）：

````markdown
[ROLE]
你是 ucore/RISC-V Sv39 实验内核的开发者，熟悉三级页表、PTE 权限位、物理页引用计数和 TLB 失效。

[TASK]
在 code/kern/mm/pmm.c 的 `//LAB4 function1 YOUR CODE` 区域实现 page_insert 和 page_remove。
可以增加 static 辅助函数 page_remove_pte。
只修改这一个区域，不要改动文件里的其他函数、头文件和注释。

[CONTEXT]
- get_pte(pgdir, la, create) 返回叶子 PTE 的内核虚拟地址；create=1 时可能分配中间页表页，失败返回 NULL。
- pte_create(ppn, type) 内部已经置 PTE_V。
- page2ppn(page) 返回页号；pte2page(pte) 只对有效 PTE 安全。
- page_ref_inc/page_ref_dec 返回操作后的引用计数；free_page(page) 在引用计数为 0 时调用。
- tlb_invalidate(pgdir, la) 失效对应地址的 TLB 项。
- -E_NO_MEM 定义在 libs/error.h。

[REQUIREMENTS]
page_insert:
1. 先 get_pte(pgdir, la, 1)；为 NULL 时返回 -E_NO_MEM，且不要增加 page 的引用计数。
2. 成功后 page_ref_inc(page)。
3. 若该地址已有有效 PTE：
   - 若旧页 == page：page_ref_dec(page)，只更新权限，引用计数保持不变；
   - 若旧页 != page：调用 page_remove_pte 撤销旧映射（旧页引用计数减一，归零则释放）。
4. 用赋值覆盖叶子 PTE：*ptep = pte_create(page2ppn(page), perm)，不要用 |=。
5. tlb_invalidate(pgdir, la)；返回 0。

page_remove:
1. 用 get_pte(pgdir, la, 0) 纯查找，不得分配页表。
2. ptep 为 NULL 或 *ptep 无效时直接返回，保证幂等。
3. 有效时调用 page_remove_pte。

page_remove_pte:
1. 先判断 *ptep & PTE_V，避免 pte2page 对无效 PTE panic。
2. page_ref_dec(page)，归零才 free_page(page)。
3. *ptep = 0。
4. tlb_invalidate(pgdir, la)。
5. 不要释放中间页表页。

[EDGE CASES]
- 同一物理页被多个地址映射：每个地址各计一次引用。
- 同一地址重复插入同一页：引用计数不变，权限被覆盖。
- 删除未映射地址、重复删除：安全返回。
- get_pte 失败：不留叶子映射，不改数据页引用计数。

[ACCEPTANCE]
- code/kern/mm/pmm.c 能编译。
- check_pgdir()、check_boot_pgdir() 通过。
- test_lab4_pmm_basic() 输出 `[Test PMM] PASS`。
- 不修改 LAB4 标记以外的内容；保留注释，把 YOUR CODE 换成 2412102。

[OUTPUT]
只输出需要插入 pmm.c 的 C 代码，带少量中文注释，不要输出整份文件。
````

**spec 如何落实到提示词：**

- spec 的“状态约束”逐条变成 `[REQUIREMENTS]` 的编号步骤；
- spec 的“边界与幂等”变成 `[EDGE CASES]`；
- spec 的“验收条件”变成 `[ACCEPTANCE]`，并明确写出 `check_pgdir`、`check_boot_pgdir`、`[Test PMM] PASS`；
- 提交规范（保留 `LAB4` 注释、学号 `2412102`）写入 `[ACCEPTANCE]`，避免 AI 删除标记。

#### 4.1.4 核心实现解释

最终实现如下：

```c
//LAB4 function1 2412102

// 删除一个有效的叶子页表项：引用计数减一，归零则释放物理页，
// 清空页表项并失效对应 TLB。
static void
page_remove_pte(pde_t *pgdir, uintptr_t la, pte_t *ptep)
{
    if (!(*ptep & PTE_V))
    {
        return;
    }

    struct Page *page = pte2page(*ptep);
    if (page_ref_dec(page) == 0)
    {
        free_page(page);
    }

    *ptep = 0;
    tlb_invalidate(pgdir, la);
}

// 建立或更新 la 到 page 的映射，权限位设置为 perm。
int
page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm)
{
    pte_t *ptep = get_pte(pgdir, la, 1);
    if (ptep == NULL)
    {
        return -E_NO_MEM;
    }

    page_ref_inc(page);

    if (*ptep & PTE_V)
    {
        struct Page *old = pte2page(*ptep);
        if (old == page)
        {
            // 同一物理页重复映射到同一地址：只更新权限，引用计数保持不变。
            page_ref_dec(page);
        }
        else
        {
            // 该地址原来映射到另一个物理页：撤销旧映射并维护旧页引用计数。
            page_remove_pte(pgdir, la, ptep);
        }
    }

    // pte_create() 内部已经置 PTE_V；这里用赋值覆盖旧权限位。
    *ptep = pte_create(page2ppn(page), perm);
    tlb_invalidate(pgdir, la);
    return 0;
}

// 删除 la 的映射；未映射时静默返回，保证幂等。
void
page_remove(pde_t *pgdir, uintptr_t la)
{
    pte_t *ptep = get_pte(pgdir, la, 0);
    if (ptep != NULL && (*ptep & PTE_V))
    {
        page_remove_pte(pgdir, la, ptep);
    }
}
```

**逐点解释：**

1. **`get_pte(pgdir, la, 1)` 先于 `page_ref_inc`**  
   `get_pte` 可能分配中间页表页，失败时返回 `NULL`。此时直接返回 `-E_NO_MEM`，数据页引用计数保持不变，不留下“加了引用但没有映射”的状态。

2. **先 `page_ref_inc(page)`**  
   `page_insert` 的语义是“这个地址从此映射到 `page`”，所以先给新页加一次引用。随后再根据旧映射情况决定是否抵消或减旧页。

3. **同一页重复映射同一地址**  
   旧 PTE 指向的页就是 `page`，这次操作只是改权限。先加后减，`ref` 净变化为 0；不会误释放，也不会多计引用。

4. **同一地址改映射另一页**  
   旧 PTE 指向 `old`。调用 `page_remove_pte()` 把旧页引用减 1，归零则释放；然后覆盖 PTE 指向新页。旧页的中间页表不动。

5. **赋值覆盖而不是按位或**  
   `*ptep = pte_create(page2ppn(page), perm)` 会完全替换旧 PTE 的权限位。如果写成 `|=`，旧权限（例如 `PTE_U | PTE_W`）会残留，`check_pgdir()` 中 `(*ptep & (PTE_U | PTE_W)) == 0` 的断言会失败。

6. **`tlb_invalidate()` 两次调用**  
   `page_remove_pte()` 在删旧映射时失效一次；`page_insert()` 在写入新 PTE 后再失效一次。重复失效是安全的，保证“旧翻译不会继续命中”。

7. **`page_remove()` 的 `create = 0`**  
   删除是幂等操作，不能因为目标地址没有页表就分配页表。`get_pte(..., 0)` 在中间页表缺失时返回 `NULL`，在叶子 PTE 无效时返回一个无效项；两种情况都由 `ptep != NULL && (*ptep & PTE_V)` 过滤。

8. **为什么不释放中间页表页**  
   中间页表页由 `get_pte()` 分配并置 `ref = 1`，其生命周期属于页表管理逻辑。`check_pgdir()` 最后手工释放中间页表并断言 `page_ref(pde2page(boot_pgdir_va[0])) == 1`；如果 `page_remove()` 擅自释放，会破坏这个约定。

9. **失败路径**  
   `get_pte(..., 1)` 可能已经分配了上层页表、随后在下层失败。此时没有叶子 PTE 写入，数据页引用不变；已分配的中间页表页保留。这是 `get_pte()` 把“查找”和“分配”合在一起的固有限制，也是分页思考题二讨论的内容。

**与测试断言的对应：**

| 测试断言 | 实现如何满足 |
|---|---|
| `page_ref(p1) == 1`（首次插入） | `page_ref_inc` 一次 |
| `page_ref(p1) == 2`（同页映射到两个地址） | 每个地址各 `page_ref_inc` 一次 |
| `page_ref(p2) == 0`（被替换的旧页） | `page_remove_pte` 中 `page_ref_dec` 归零并 `free_page` |
| `(*ptep & (PTE_U \| PTE_W)) == 0` | 赋值覆盖权限 |
| `page_ref(pde2page(boot_pgdir_va[0])) == 1` | 不释放中间页表页 |
| 重复 `page_remove` 不 panic | `PTE_V` 检查 + 幂等返回 |
| `[Test PMM] PASS` | 以上行为全部满足 |

#### 4.1.5 实现迭代过程

**第一次迭代（内核代码）：**

- 按 4.1.3 的 prompt 生成 `page_remove_pte()`、`page_insert()`、`page_remove()`。
- 按 4.1.2 的 spec 逐条核对：引用计数、权限覆盖、TLB 失效、幂等删除、`-E_NO_MEM` 路径、不释放中间页表。
- 编译通过；`check_pgdir()`、`check_boot_pgdir()` 通过；`test_lab4_pmm_basic()` 输出 `[Test PMM] PASS`。

**结果：** 内核代码一次通过，未出现 `page_insert/page_remove` 的逻辑 bug。

**关键改进点（在 prompt 中提前约束，避免返工）：**

1. 明确“同一页重复映射先加后减”，避免引用计数多 1。
2. 明确“权限位赋值覆盖，不要用 `|=`”，避免旧权限残留。
3. 明确“`page_remove` 用 `create=0` 并检查 `PTE_V`”，避免未映射地址 panic。
4. 明确“每次改叶子 PTE 后 `tlb_invalidate`”，避免旧翻译残留。
5. 明确“不释放中间页表页”，避免 `check_pgdir` 最后断言失败。



### 功能模块二 进程创建及初始化

**负责人：** 2413346-易响

#### 4.2.1 模块功能描述

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


#### 4.2.2 规格说明（spec）

 1. 全局约束

- 只填写 `code/kern/process/proc.c` 的 `//LAB4 function2` 区域；保留原有辅助函数和 C 的 `//LAB4 function3` 区域。
- 保留 `LAB4` 标记，把 `YOUR CODE` 替换为学号 `2413346`。
- 不修改 `struct proc_struct`、`struct context`、`struct trapframe` 的字段和顺序；这些结构同时被 C 的汇编和“中断帧恢复链”使用。
- `proc->pgdir` 保存页表根的**物理地址**（`boot_pgdir_pa`），不是内核虚拟地址。
- 所有“把线程暴露给调度器”的动作必须在 `state = PROC_RUNNABLE` 之前完成；状态是最后一道可见性开关。

 2. `alloc_proc()`

| 项目 | 规格 |
|---|---|
| 输入 | 无 |
| 输出 | 成功返回 `struct proc_struct *`；`kmalloc` 失败返回 `NULL` |
| 状态约束 | `state = PROC_UNINIT`、`pid = -1`、`runs = 0`、`kstack = 0`、`need_resched = 0`、`parent = NULL`、`mm = NULL`、`tf = NULL`、`pgdir = boot_pgdir_pa`、`flags = 0`、`name` 全 0、`context` 全 0 |
| 边界 | 不在本函数中分配内核栈、不分配 PID、不挂链表、不设置 `PROC_RUNNABLE` |
| 错误处理 | 分配失败直接返回 `NULL`，不修改任何全局状态 |
| 验收 | `idleproc->tf == NULL`、`idleproc->context.ra == 0`、`idleproc->runs == 0`、`idleproc->flags == 0` |

`list_link`/`hash_link` 不在 `alloc_proc()` 中初始化：`list_add()` 和 `hash_proc()` 会覆盖这两个节点的前后指针，提前把它们指向自己反而容易掩盖“忘记入链”的错误。

 3. `proc_init()`

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

 4. `kernel_thread()`

| 项目 | 规格 |
|---|---|
| 输入 | `fn`：非空的内核函数指针，签名为 `int (*)(void *)`；`arg`：传给 `fn` 的参数；`clone_flags`：克隆标志 |
| 输出 | 成功返回新线程 PID（> 0）；失败返回 `do_fork()` 的负错误码 |
| 现场构造 | 局部 `struct trapframe tf` 先清零；`tf.gpr.s0 = (uintptr_t)fn`；`tf.gpr.s1 = (uintptr_t)arg`；`tf.epc = (uintptr_t)kernel_thread_entry`；`tf.status = (read_csr(sstatus) \| SSTATUS_SPP \| SSTATUS_SPIE) & ~SSTATUS_SIE` |
| 状态位 | `SPP = 1`：`sret` 返回 S 态；`SPIE = 1`：返回后允许中断；`SIE = 0`：构造期间不被中断打断 |
| 边界 | `tf.gpr.sp` 不在本函数中设置，由 `copy_thread()` 根据 `esp` 是否为 0 决定；`tf` 是栈上临时变量，必须在 `do_fork()` 返回前按值复制到新内核栈 |
| 错误处理 | 直接返回 `do_fork()` 的错误码，不吞掉失败 |
| 验收 | 新建线程 `context.ra != 0`、`context.sp != 0`，首次运行进入 `fn` 且 `arg` 正确 |

 5. `do_fork()`

| 项目 | 规格 |
|---|---|
| 输入 | `clone_flags`、`stack`（内核线程传 0）、`tf`（非空模板中断帧） |
| 输出 | 成功返回新线程 PID；进程数超限返回 `-E_NO_FREE_PROC`；内存不足返回 `-E_NO_MEM` |
| 步骤 | ① `alloc_proc()`；② `parent = current`；③ `setup_kstack()`；④ `copy_mm()`；⑤ `copy_thread()`；⑥ 中断保护下 `get_pid()`、`hash_proc()`、`list_add()`、`nr_process++`；⑦ `wakeup_proc()`；⑧ 返回 PID |
| 可见性 | PID、哈希、链表、计数在同一个临界区内完成；`wakeup_proc()` 放在临界区之后、所有资源就绪之后 |
| 失败清理 | PCB 分配失败：直接返回；内核栈失败：`kfree(proc)`；`copy_mm` 失败：`put_kstack(proc)` 后 `kfree(proc)`；`nr_process >= MAX_PROCESS`：不分配直接返回 |
| 边界 | 失败路径不调用 `wakeup_proc()`，不把半成品加入链表；`tf` 为空属于调用者违约 |
| 验收 | `test_lab4_schedule()` 能连续调用两次 `kernel_thread()`，返回正 PID，两个线程都能被调度执行 |

 6. `copy_thread()`

| 项目 | 规格 |
|---|---|
| 输入 | `proc`：已分配 PCB 和内核栈；`esp`：调用者给出的栈（内核线程为 0）；`tf`：模板中断帧 |
| 输出 | 无返回值；写 `proc->tf` 和 `proc->context` |
| 现场约束 | `proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE) - 1`；`*proc->tf = *tf`；`proc->tf->gpr.a0 = 0`；`proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp`；`proc->context.ra = (uintptr_t)forkret`；`proc->context.sp = (uintptr_t)proc->tf` |
| 边界 | 内核线程（`esp == 0`）必须把 `sp` 指向自己的中断帧，否则 `__trapret` 会恢复出 `sp = 0`；`esp != 0` 时保留调用者栈，兼容后续用户进程 |
| 对齐 | `struct trapframe` 为 36×8 = 288 字节，`kstack + KSTACKSIZE` 为 8 字节对齐，减 1 个结构体后仍对齐 |
| 验收 | `initproc->context.sp` 指向其内核栈上的 `tf`，`context.ra` 指向 `forkret`；首次切换后能进入 `init_main` |

 7. `copy_mm()`

| 项目 | 规格 |
|---|---|
| 输入 | `clone_flags`、`proc` |
| 输出 | 成功返回 0；本实验不会失败 |
| 状态约束 | `current->mm == NULL`（内核线程），`proc->mm = NULL` |
| 边界 | 不做用户地址空间复制、不调用页表映射接口；实验五以后才需要扩展 |
| 验收 | `idleproc->mm == NULL`、`initproc->mm == NULL` |

 8. 模块验收条件

- `code/kern/process/proc.c` 编译、链接通过；
- `tools/test_lab4.c` 的 `test_lab4_process_create()` 全部断言通过，输出 `[Test Process Create] PASS`；
- `make qemu` 能看到 `this initproc, pid = 1, name = "init"`、`To U: "Hello world!!".`、`To U: "en.., Bye, Bye. :)"`；
- 与 C 联调后 `make grade` 的 Process Create 组为 `OK`，三组总分 `30/30`；
- 保留 `//LAB4 function2 2413346` 注释。

#### 4.2.3 最终提示词（prompt）

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

#### 4.2.4 核心实现解释

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

 1. `alloc_proc()`：把 PCB 置为“空白且安全”

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

 2. `proc_init()`：idleproc 是“继承现场”，不是 fork 出来的

`idleproc` 的特殊性在于它复用 `kern_init` 启动至今的执行现场：

- `kstack = (uintptr_t)bootstack`：`bootstack` 在 `kern/init/entry.S` 中定义为 `.space KSTACKSIZE` 的数组，`bootstacktop = bootstack + KSTACKSIZE`，启动时的 `sp` 就设在 `bootstacktop`。`kstack` 记录栈底，便于 `put_kstack()` 释放；`test_lab4_process_create()` 也按这个约定检查 `idleproc->kstack == (uintptr_t)bootstack`。
- `need_resched = 1`：让 `cpu_idle()` 第一次检查时立刻调用 `schedule()`，把 CPU 让给 `initproc`。
- `current = idleproc` 必须在 `kernel_thread()` 之前：`do_fork()` 用 `proc->parent = current` 记录父进程，晚设置就会得到错误的父子关系。
- `idleproc` 不加入 `proc_list` 和 `hash_list`：它是调度兜底对象，不是普通链表节点。`schedule()` 在找不到候选线程时直接使用 `idleproc`，而不是从链表头取到它。
- `set_proc_name(idleproc, "idle")` 与 `set_proc_name(initproc, "init")`：后者是 `make grade` 检查字符串 `this initproc, pid = 1, name = "init"` 的一部分。

`initproc` 的 pid 为什么是 1：`get_pid()` 首次调用时从 `MAX_PID` 回绕到 `last_pid = 1`，在 `proc_list` 中查重；此时 `proc_list` 仍是空表（`idleproc` 未入链），没有冲突，所以返回 1。`kernel_thread()` 返回后，`find_proc(pid)` 又能通过 `hash_list` 找到它。

 3. `kernel_thread()`：把函数包装成“第一次从 trap 返回”的现场

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

 4. `do_fork()`：资源顺序、可见性与失败回滚

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

 5. `copy_thread()`：首次运行现场的两个关键指针

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

 6. `copy_mm()`：本阶段的“空实现”也是有约束的接口

```c
assert(current->mm == NULL);
proc->mm = NULL;
return 0;
```

本实验创建的是内核线程：它们共享内核地址空间，`current->mm` 本来就是 `NULL`，所以不需要复制页表。保留 `copy_mm()` 的函数形态和失败返回路径，是为了实验五以后能在这里接入真正的用户地址空间复制；当前阶段它必须“成功返回 0”，否则 `do_fork()` 会走错误清理路径，创建不出线程。


#### 4.2.5 实现迭代过程

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


---

**关键改进点总结：**

1. 在 `do_fork()` 之前补充 `copy_thread`/`copy_mm` 的 `static` 前置声明，使函数定义顺序与声明一致。
2. 构建前执行 `make clean`，避免复用其他路径的旧 `obj/`，保证三人的代码都参与编译。
3. 在 spec 与提示词中显式写出 `context.sp = tf`、`tf->gpr.sp = tf`、`pgdir = boot_pgdir_pa` 三个“现场关键值”，减少首次运行类错误。
4. 用 `[Test Process Create] PASS`、`make qemu` 输出和 `make grade 30/30` 三层证据验证，而不是只看编译通过。


### 功能模块三：进程调度

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


### Challenge分页思考题一：`get_pte()` 的两段代码为何如此相似？

**负责人：** 2412102-聂海丽

**题目：** `get_pte()` 中有两段形式类似的代码，结合 Sv32、Sv39、Sv48 的异同，解释这两段代码为什么如此相像。

**结论：** 这三种分页模式都是多级基数页表，每一级的动作完全相同——“用当前级的虚拟页号索引页表，取出 PTE；无效则按需分配下一级页表页；有效则用 PTE 中的 PPN 找到下一级页表”。`get_pte()` 的两段代码只是把同一动作在两级上展开了两次。

**三种模式对比：**

| 项目 | Sv32 | Sv39 | Sv48 |
|---|---|---|---|
| 虚拟地址宽度 | 32 位 | 39 位 | 48 位 |
| 页表级数 | 2 | 3 | 4 |
| 每级索引位数 | 10 位 | 9 位 | 9 位 |
| 页表项大小 | 4 字节 | 8 字节 | 8 字节 |
| 每张页表项数 | 1024 | 512 | 512 |
| 物理地址宽度 | 34 位 | 56 位（常用 44 位 PPN） | 56 位（常用 50 位 PPN） |
| 页大小 | 4KB | 4KB | 4KB |

**对应到代码：**

- `PDX1(la)`（右移 30 位）= Sv39 的 VPN[2]；
- `PDX0(la)`（右移 21 位）= VPN[1]；
- `PTX(la)`（右移 12 位）= VPN[0]；
- 前两段代码分别处理 VPN[2]、VPN[1] 两级“查找或分配下一级页表”；
- 最后 `return &((pte_t *)KADDR(PDE_ADDR(*pdep0)))[PTX(la)]` 只返回 VPN[0] 对应叶子 PTE 的地址，不再分配。

**为什么相似：**

1. **索引方式相同**：每一级都是 `table[index]`，只是移位和掩码不同。
2. **缺表时分配方式相同**：`alloc_page()` → `set_page_ref(page, 1)` → `memset(KADDR(pa), 0, PGSIZE)` → 写入 `pte_create(page2ppn(page), PTE_U | PTE_V)`。
3. **下一级页表地址取法相同**：`KADDR(PDE_ADDR(*pdep))`。
4. **差异只在级数、索引位宽、PTE 宽度**：Sv32 只有 2 级，Sv39 有 3 级，Sv48 有 4 级；如果写成循环，循环体就是这两段代码的共同部分，循环次数由模式决定。

**补充：** 当前代码把级数写死为 Sv39 的三级，并把页表根 `pgdir` 作为已知输入。如果要做通用多级页表，应把“级数、每级移位、索引掩码、PTE 大小”参数化，用循环替代重复代码。

---

### Challenge分页思考题二：`get_pte()` 把查找和分配合并，好不好？要不要拆？

**负责人：** 2412102-聂海丽

**结论：** 在本实验的规模和调用方式下，合并写法可以接受；从接口设计和错误处理角度看，拆分更清晰、更可测试，但不是本实验必须完成的重构。

**合并写法的优点：**

1. 调用者只需一次调用就能“找到或建立”到叶子 PTE，`page_insert()` 不必自己写多级循环。
2. 中间页表的分配、清零、引用计数初始化集中在一个地方，避免多处重复。
3. `create` 参数已经提供了“纯查找/查找并分配”的开关，`page_remove()` 用 `create=0` 就不会分配。
4. 代码量小，与当前 Sv39 三级结构贴合，容易理解。

**合并写法的缺点：**

1. **返回值语义混淆**：`create=0` 时 `NULL` 表示“页表不存在/未映射”；`create=1` 时 `NULL` 表示“分配失败”。调用者无法区分“正常的未映射”和“内存不足”。
2. **查询带副作用**：一个叫 `get_pte` 的函数会分配内存、修改页表，违反“查询不应改变状态”的直觉；在中断上下文、持锁上下文或需要原子性的场景要特别小心。
3. **错误路径不干净**：上层页表分配成功、下层失败时，已分配的表页留在页表里，没有回滚；`page_insert()` 只能返回 `-E_NO_MEM`，无法告诉调用者“哪一级失败、是否留下垃圾”。
4. **不易单独测试**：想测试“查找”逻辑，必须构造 `create=0`；想测试“分配失败”，又很难注入故障。
5. **不利于扩展**：支持大页、不同分页模式、页表页回收时，查找和分配的策略会分化，合在一起会越来越复杂。

**拆分建议：**

```c
// 纯查找：不分配，找不到返回 NULL
pte_t *walk_pgdir(pde_t *pgdir, uintptr_t la);

// 确保中间页表存在：成功返回 0 并给出叶子 PTE 地址，
// 失败返回 -E_NO_MEM；NULL 只表示“不存在”，不再兼作错误码
int pte_alloc(pde_t *pgdir, uintptr_t la, pte_t **ptep);
```

或者保留一个统一入口，但把返回值改成错误码：

```c
int pgdir_walk(pde_t *pgdir, uintptr_t la, bool alloc, pte_t **ptep);
// 返回 0：成功，*ptep 有效
// 返回 -E_NO_MEM：alloc=true 且分配失败
// 返回 0 且 *ptep == NULL：alloc=false 且未映射
```

这样：

- `page_insert()` 调 `pgdir_walk(..., true, &ptep)`，用错误码区分“未映射”和“内存不足”；
- `page_remove()`、`get_page()` 调 `pgdir_walk(..., false, &ptep)`，纯查找；
- 分配失败时可以只回滚本函数分配的页表页，或者由调用者决定是否接受残留。

**本实验的取舍：** 不改现有 `get_pte()`，因为：

- 接口已被 `boot_map_segment`、`check_pgdir`、`check_boot_pgdir`、`pgdir_alloc_page` 等多处使用；
- 实验的验收点是 `page_insert/page_remove` 的行为，不是页表遍历接口的重构；
- 合并写法在当前单核、无并发回收的场景下不会造成实际错误。

---


## 五、测试与验证

<!-- 根据该实验的具体情况，提供完整的测试运行截图，应包含：
- 编译及运行成功的输出（make qemu），可能有多个
- 测试通过的结果（make grade），只有一个
-->

**测试截图：**

![测试结果截图](./images/make_qemu.png)
![测试结果截图](./images/make_grade.png)
---

## 六、实验总结与收获

### 6.1 对操作系统的理解

**重要知识点与 OS 原理的对应：**

| 本实验知识点 | OS 原理中的概念 | 含义、关系与差异 |
|---|---|---|
| 多级页表、PTE、PPN | 虚拟内存、分页 | 本实验使用 Sv39 三级页表；原理课讲通用多级页表，本实验把级数写死为 3 |
| `page_insert/page_remove` | 页表映射管理 | 本实验只做内核页表的基本映射维护，不做用户地址空间复制、按需分页 |
| 物理页引用计数 | 物理页生命周期 | 本实验用 `Page.ref` 判断何时 `free_page`；原理课还会讲页缓存、共享页、回收 |
| TLB 失效 | 地址翻译缓存 | 本实验用 `sfence.vma`；原理课会讲 ASID、TLB 一致性、多核 shootdown |
| PCB、内核栈、上下文 | 进程/线程控制块 | 本实验是简化版 `proc_struct`，没有完整文件、信号等字段 |
| `schedule/proc_run/switch_to` | 进程调度、上下文切换 | 本实验是简单轮转 + 单核；原理课会讲优先级、多级反馈队列、多核负载均衡 |
| `kernel_thread_entry`/`forkret` | 内核线程启动 | 本实验用中断帧 + `context.ra` 构造首次运行 |

**本实验尚未覆盖的 OS 原理：**

1. 用户进程地址空间隔离与完整的 `copy_mm`。
2. 按需分页、缺页异常处理、页面置换（LRU/Clock 等）。
3. 完整的进程退出与资源回收（本实验 `do_exit()` 仍是 `panic` 占位）。
4. 更完整的调度策略（优先级、多级反馈队列、多核负载均衡）。
5. 进程间通信、文件系统、信号等。
6. 完整的用户态/内核态切换与系统调用路径（本实验重点是内核线程）。

### 6.2 AI 协作开发的经验

1. **先写 spec，再写 prompt。** 把输入、输出、状态约束、边界条件和验收条件写清楚，AI 的返工明显减少。
2. **把验收断言写进 prompt。** 例如“同一页重复映射引用计数不变”“删除要幂等”“必须 TLB 失效”，比泛泛说“正确实现”有效。
3. **限制修改范围。** 明确“只输出插入区域的代码、不要改其他函数、保留注释和学号”，避免 AI 重写整份文件。
4. **AI 生成的代码必须用测试验证。** `check_pgdir()`、`check_boot_pgdir()` 和 `[Test PMM] PASS` 是最直接的证据。
5. **如实记录迭代。** 本次内核代码一次通过，遇到的是构建环境（GCC 版本）和临时自测脚本问题；报告应区分“内核实现问题”和“验证环境问题”，不编造不存在的 bug。


---

