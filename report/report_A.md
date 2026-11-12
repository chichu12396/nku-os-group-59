# Lab4 实验报告（角色 A 交付稿）

> 本文件是 A 的章节初稿，供 C 合并到最终 `report.md`。  
> B/C 负责的模块、中断 Challenge、最终 `make qemu` / `make grade` 截图由对应负责人补充；文中用“待 B 补充”“待 C 补充”标出。

---

## 实验基本信息

| 项目 | 内容 |
|---|---|
| **实验名称** | Lab4：进程管理（虚拟内存页操作、进程创建与初始化、进程调度与上下文切换） |
| **小组成员** | 2412102-聂海丽（A）、[B 学号-姓名]、[C 学号-姓名] |
| **完成日期** | 2026-11-10（A 初稿；最终日期由 C 按实际提交时间填写） |

### 小组分工

| 成员 | 负责的练习/模块 |
|---|---|
| 2412102-聂海丽（A） | `kern/mm/pmm.c` 的 `page_insert()`、`page_remove()`（含内部辅助 `page_remove_pte()`）；两道分页思考题；实验目的、环境、整体逻辑、总结等公共章节初稿 |
| [B 学号-姓名] | `kern/process/proc.c` 的 `alloc_proc()`、`proc_init()`、`kernel_thread()`、`do_fork()`、`copy_thread()`、`copy_mm()` |
| [C 学号-姓名] | `cpu_idle()`、`proc_run()`、`schedule()`、`switch_to()`；开关中断 Challenge；整体验收、最终报告整合与提交版本整理 |

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

### 2.1 AI 工具与模型

| 成员 | AI 编程工具 | 底层模型 | 备注 |
|---|---|---|---|
| 2412102-聂海丽（A） | Claude Code（终端 Agent） | DeepSeek-V4-Flash（1M 上下文） | 按本次协作会话实际使用填写 |
| [B 学号-姓名] | 待 B 补充 | 待 B 补充 | 待 B 补充 |
| [C 学号-姓名] | 待 C 补充 | 待 C 补充 | 待 C 补充 |

### 2.2 编译与运行环境

| 项目 | 配置 |
|---|---|
| 操作系统 | WSL2 Ubuntu |
| 交叉编译器 | `riscv64-unknown-elf-gcc` 10.1.0（`/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin`） |
| 模拟器 | QEMU 4.1.1（`/home/niehaili/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64`） |
| 构建工具 | GNU make |
| 辅助脚本 | Python 3.12.3（`make grade` 的 `tools/inject.py`） |
| 硬件体系 | RISC-V 64 位，Sv39 分页，QEMU `virt` 机器 |

> **环境说明：** 本机 `compiler-lab/riscv-elf-toolchains/bin` 中的 GCC 15.1.0 会在框架自带的 `kern/mm/kmalloc.c:92` 报 `-Wint-conversion` 硬错误（`kva2page(kva)` 传入 `uintptr_t`），与 A 的 `pmm.c` 代码无关。改用 GCC 10.1.0 后编译通过。  
> QEMU 也必须显式使用 4.1.1：本机 PATH 中可能有 7.0/8.2，裸 `make qemu` 会静默使用错误版本，通常表现为内核无输出。

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

### 3.3 “开发可并行、运行有依赖”

- **开发可以并行**：A/B/C 修改不同文件或不同函数，接口由头文件固定。A 只动 `pmm.c`，B/C 动 `proc.c`、`sched.c`、`switch.S`，彼此不会频繁冲突。
- **运行有依赖**：整机启动必须按上面的顺序。A 的页映射自检先于 B 的 `proc_init`；B 构造的 PCB、内核栈、`context.ra/sp` 先于 C 的 `schedule/proc_run/switch_to`；首次运行还需要 B/C 共同确认中断帧与上下文布局。
- 因此，代码可以并行写，但正式整机验证要等三人实现合齐；A 在 B/C 未完成时用 `/tmp` 临时桩只验证 PMM 子功能，不改变仓库结构。

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

这条链要求 B 的 `copy_thread()` 正确设置 `context.ra`、`context.sp` 和内核栈上的中断帧，C 的 `switch_to()` 严格按 `struct context` 的字段顺序恢复寄存器。A 的页操作不直接参与每次线程创建，但为内核栈和页表提供了可用的内存基础。

---

## 四、实验内容与实现

### 功能模块一：虚拟内存页操作

**负责人：** 2412102-聂海丽（A）

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

**与其他模块的关系：**

- 依赖 `get_pte()` 完成三级页表查找与中间页表分配；
- 依赖 `pte_create()` 生成 PTE，依赖 `page_ref_inc/dec`、`free_page()` 管理物理页；
- 依赖 `tlb_invalidate()` 失效翻译缓存；
- B 的内核线程共享内核页表，线程创建不会频繁直接调用本模块；A 的作用主要体现在启动自检和内存基础。

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
6. 明确“保留 `LAB4` 注释、替换学号”，避免提交规范问题。

**验证环境迭代（不属于内核代码 bug，但如实记录）：**

1. 最初用 `compiler-lab/riscv-elf-toolchains/bin` 的 GCC 15.1.0 构建，框架自带的 `kern/mm/kmalloc.c:92` 报 `-Wint-conversion` 硬错误。原因是 GCC 15 对 `kva2page(uintptr_t)` 这类隐式整数到指针转换更严格；改用 GCC 10.1.0 后编译通过。这个问题与 A 的 `pmm.c` 无关。
2. A 在 B/C 代码未完成时，用 `/tmp` 副本加最小桩自测。最初临时脚本把 Makefile 路径变量用错（读取/写入了错误文件），导致 `pmm_init not found`；修正脚本后自测正常。这是验证脚本问题，不是内核实现问题。

#### 4.1.6 验证情况

**编译：**

```bash
export PATH=/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin:$PATH
make clean
make
```

结果：编译通过。

**自测方式：**

由于 B/C 的 `proc_init()`、`kernel_thread()`、`schedule()` 等尚未完成，仓库整体暂时无法链接。A 在 `/tmp/lab4-A-selftest` 副本中加入最小桩，并在 `pmm_init()` 末尾调用 `test_lab4_pmm_basic()`，用 QEMU 4.1.1 运行：

```bash
timeout 25 qemu-system-riscv64 \
    -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000
```

**实际输出（节选）：**

```text
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
[Test PMM] PASS
check_vma_struct() succeeded!
check_vmm() succeeded.
```

**验证结论：**

- [x] `check_pgdir()` 通过。
- [x] `check_boot_pgdir()` 通过。
- [x] `[Test PMM] PASS`。
- [ ] 最终整机 `make qemu` / `make grade` 的 PMM 组结果待 C 在合齐版本上确认。

> A 的 `/tmp` 自测只用于开发期验证 PMM 子功能；报告第五部分的最终截图应使用 C 合齐后的同一版本，不能把临时桩日志当作最终验收证据。

---

### 分页思考题一：`get_pte()` 的两段代码为何如此相似？

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

### 分页思考题二：`get_pte()` 把查找和分配合并，好不好？要不要拆？

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

### 功能模块二：进程创建及初始化（B 负责）

> 待 B 补充：`alloc_proc()`、`proc_init()`、`kernel_thread()`、`do_fork()`、`copy_thread()`、`copy_mm()` 的功能描述、spec、最终 prompt、核心实现解释、迭代记录和验证情况。

### 功能模块三：进程调度与上下文切换（C 负责）

> 待 C 补充：`cpu_idle()`、`proc_run()`、`schedule()`、`switch_to()` 的功能描述、spec、最终 prompt、核心实现解释、迭代记录和验证情况。

### 中断 Challenge：`local_intr_save/restore`（C 负责）

> 待 C 补充：结合 `sync.h`、`intr.c` 说明 `local_intr_save()` 和 `local_intr_restore()` 如何保存中断使能状态、关闭中断、按原状态恢复，并联系调度临界区说明用途。

---

## 五、测试与验证

### 5.1 PMM 组检查内容（A 提供）

上传代码中的评分脚本检查三组，每组 10 分。PMM 组由 A 负责，核心测试是 `tools/test_lab4.c` 的 `test_lab4_pmm_basic()`，它覆盖：

1. 新映射建立后 `ref == 1`，`pte2page(*ptep) == p1`。
2. 同一地址改映射另一页后，旧页 `ref == 0`，新页 `ref == 2`。
3. 权限位被完全覆盖：`(*ptep & (PTE_U | PTE_W)) == 0`。
4. 同一页重复映射同一地址只改权限，`ref` 保持 1，空闲页数不变。
5. 删除映射后 `ref` 归零。
6. 重复删除同一地址安全。
7. 最终 `p1/p2/p3` 的引用计数均为 0。

评分脚本检查的字符串：

```text
[Test PMM] PASS
```

### 5.2 A 的自测结果

```text
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
[Test PMM] PASS
check_vma_struct() succeeded!
check_vmm() succeeded.
```

### 5.3 最终整机验证

> 待 C 在合齐 A/B/C 代码后的同一版本上运行：

```bash
make qemu QEMU=/home/niehaili/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64
make grade QEMU=/home/niehaili/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64
```

预期：

```text
check PMM:                OK
check Process Create:     OK
check Schedule:           OK

Total Score: 30/30
```

最终截图（`make qemu`、`make grade`）由 C 统一收集，放入 `report/images/`。

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

A 的经验：

1. **先写 spec，再写 prompt。** 把输入、输出、状态约束、边界条件和验收条件写清楚，AI 的返工明显减少。
2. **把验收断言写进 prompt。** 例如“同一页重复映射引用计数不变”“删除要幂等”“必须 TLB 失效”，比泛泛说“正确实现”有效。
3. **限制修改范围。** 明确“只输出插入区域的代码、不要改其他函数、保留注释和学号”，避免 AI 重写整份文件。
4. **AI 生成的代码必须用测试验证。** `check_pgdir()`、`check_boot_pgdir()` 和 `[Test PMM] PASS` 是最直接的证据。
5. **如实记录迭代。** 本次内核代码一次通过，遇到的是构建环境（GCC 版本）和临时自测脚本问题；报告应区分“内核实现问题”和“验证环境问题”，不编造不存在的 bug。

> B/C 的 AI 协作经验待本人补充，由 A 汇总为初稿。

---

## 附录：PMM 自测日志（节选）

```text
OpenSBI v0.4 ...
(THU.CST) os is loading ...

Special kernel symbols:
  entry  0xc020004a (virtual)
  ...
memory management: default_pmm_manager
physical memory map:
  memory: 0x0000000008000000, [0x0000000080000000, 0x0000000087ffffff].
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
[Test PMM] PASS
check_vma_struct() succeeded!
check_vmm() succeeded.
++ setup timer interrupts
100 ticks
...
qemu-system-riscv64: terminating on signal 15 from pid ... (timeout)
```

自测命令：

```bash
export PATH=/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin:$PATH
make clean && make
timeout 25 /home/niehaili/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64 \
    -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000
```
