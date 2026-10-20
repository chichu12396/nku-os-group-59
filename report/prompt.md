### 功能模块：page_init()

**负责人：** 2411033-季艾佳
#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown
[PROMPT]
你在为 RISC-V 架构的教学操作系统 ucore（lab2）实现物理内存初始化功能。
内核已经从设备树中读出了内存起点和大小，现在需要建立 Page 描述符数组，
把内核和描述符数组占用的空间保留下来，再把剩余的完整页交给物理内存管理器。
请修改 kern/mm/pmm.c，在 lab2 function1 标记下面实现 page_init()。

实现方式：
  - 先读 pmm.h、memlayout.h、dtb.h 和 default_pmm.c，按现有接口写，
    保持 cprintf 打印、panic 报错和 list.h 链表节点初始化的代码风格。
  - 使用设备树给出的物理内存范围，不要直接把内存大小写死。
  - Page 数组放在内核 end 之后，起点按页对齐，数组本身占用的页也要保留。
  - 先把所有可管理页标成保留，再把剩余完整页交给 init_memmap()。
  - 直接修改实际文件，只补这个函数，不改 pmm.h、memlayout.h、entry.S、Makefile 和测试。
  - 保留已有 Buddy、SLUB 开关，默认仍用 First-Fit，不要在这里切换 Best-Fit。
请先说明地址怎么转换、描述符数组放在哪里、空闲区怎么计算，再给代码。
最后输出完整的 page_init()，不要省略，也不要写“其余同上”。

[RELY]
可以依赖的东西：
- 设备树接口：get_memory_base()、get_memory_size()，返回物理内存起点和字节数。
- 数据结构：struct Page（kern/mm/memlayout.h），字段为 ref / flags / property / page_link。
- 全局变量：pages / npage / nbase / va_pa_offset；链接符号 end 是内核结束的虚拟地址。
- 地址宏：DRAM_BASE=0x80000000，KERNEL_BEGIN_PADDR=0x80200000，
  PHYSICAL_MEMORY_END=0x88000000，PHYSICAL_MEMORY_OFFSET=0xFFFFFFFF40000000。
- 页大小：PGSIZE=4096，PGSHIFT=12；可以用 PPN / ROUNDUP / ROUNDDOWN。
- 地址转换：PADDR、pa2page；页面操作：SetPageReserved、set_page_ref、list_init。
- 已有函数：init_memmap、panic、cprintf。
- 参考 default_init_memmap()：输入页必须是 Reserved 状态，它负责清除保留状态并登记空闲页。

注意：pages[i] 对应物理页号 nbase+i，数组长度是 npage-nbase，不是 npage。
PADDR 会减去 va_pa_offset，使用前要先设置偏移。不要使用项目没有提供的 MIN 或 KADDR。

[GUARANTEE]
必须交付：
1. kern/mm/pmm.c 中完整的 static void page_init(void)。
2. 正确设置 va_pa_offset、npage 和 pages，输出探测到的物理内存范围。
3. 描述符覆盖 [nbase, npage) 内的物理页，只把剩余完整空闲页交给当前管理器。
4. 保留 lab2 function1 注释和其他已有代码，不新增对外接口，不重新实现已有函数。

[SPECIFICATION]
page_init(void)
  Pre-Condition：
  - entry.S 已建立固定映射并开启分页，设备树初始化已经执行。
  - pmm_manager 已经初始化，当前默认使用 First-Fit。

  Post-Condition：
  - Page 数组从内核 end 之后的页边界开始，完整放在可管理内存中。
  - OpenSBI、内核和 Page 数组占用的页保持保留，剩余完整页登记为空闲页。

  Case 1：内存信息有效，而且还有完整空闲页。
  - 管理上界取设备树结束地址和 PHYSICAL_MEMORY_END 中较小的值，再向下按页对齐。
  - npage 是这个上界对应的物理页号，描述符数量是 npage-nbase。
  - 先检查数组能否放下，再初始化 ref / flags / property / page_link，并设置 Reserved。
  - 数组结束地址向上按页对齐后就是空闲区起点，用 pa2page() 转成描述符指针，
    把剩余完整页一次性交给 init_memmap()。

  Case 2：设备树信息无效。
  - 起点或大小为零、起点加大小溢出时，panic 终止。
  - 起点低于 DRAM_BASE、起点高于 KERNEL_BEGIN_PADDR，或结束地址不超过
    KERNEL_BEGIN_PADDR，也要终止，不能继续写描述符或登记空闲页。

  Case 3：没有可管理页，或者放不下描述符数组。
  - panic 终止。容量检查必须放在写数组之前，检查时避免地址加法溢出。

  Case 4：描述符数组放得下，但是没有完整空闲页。
  - 完成描述符初始化并保留这些页，直接返回，不调用 init_memmap(..., 0)。

全局约束
  - 先设置 va_pa_offset，再使用 PADDR；分清虚拟地址、物理地址、物理页号和描述符指针。
  - 内存末尾不足一页的部分不能登记为空闲页。打印末地址时用结束地址减一。
  - 代码按现有 gnu99、-Wall、-Werror 编译，不修改测试，也不自行打印测试通过的信息。
  - 用 make 检查编译，make qemu 检查 First-Fit 自检，make grade 检查 Page Init。
    M0 阶段 Best-Fit 尚未完成，10/20 是预期结果。
````

#### 实现迭代过程

本模块的实现经历了 [1] 次迭代，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次提示词生成迭代，该模块最终：

- ✅ RISC-V 交叉编译、链接通过。
- ✅ 适配后的 QEMU 验证副本中，First-Fit 自检及官方 Page Init 评分项通过。
- ✅ 12 项补充主机模拟检查通过。
- ✅ 已验证行为符合本次规格；主机模拟不证明真实 MMU 行为，也不覆盖所有可能硬件布局。
- 当前完整评分为 10/20；Best-Fit 不在本次完成范围。


**关键改进点总结（如有）：**
1. 在 [RELY] 中使用真实工程名称及地址关系，明确没有 MIN 和可用 KADDR，减少 API 猜测。
2. 在 [SPECIFICATION] 中区分无效范围、数组空间不足、没有完整空闲页三类边界，而不只描述正常路径。
3. 明确数组覆盖 `[nbase,npage)`，避免把物理页号上界误当成描述符数量。
4. 明确先设置地址偏移、先检查数组容量、先保留全部页面的时序，避免越界写或误释放内核内存。
5. 将阶段验收定义为 Page Init 通过，避免为获得 Best-Fit 分数而越界修改其他模块。

### 功能模块：Best-Fit 连续物理内存分配

**负责人：** 2411033-季艾佳
#### 最终提示词

本次使用以下提示词生成实现，随后完成管理器切换和运行验证。

````markdown
[PROMPT]
我正在完成 RISC-V 教学操作系统 ucore 的 lab2。
目前 page_init() 已完成，默认 First-Fit 可以运行。现在请修改 kern/mm/best_fit_pmm.c，
实现 Best-Fit 连续物理页分配器。

实现方式：
  - 先读 default_pmm.c，参考它的初始化、块拆分、页面回收和相邻块合并方式。
  - 空闲链表仍按地址从低到高排列。
  - 分配时遍历空闲链表，选择能满足申请的最小块。
  - 遇到大小恰好等于申请量的块时，可以结束查找。
  - 文件里目前有 M0 临时骨架，请将它补成真实实现，移除未实现时的 panic 入口。
  - 保留 basic_check() 和 best_fit_check()，两个测试函数的内容保持原样。
  - 本次只修改 best_fit_pmm.c，管理器切换随后单独完成。

请直接修改实际文件。先说明设计，再给出完整实现，最后检查编译结果。

[RELY]
可以依赖的东西：
- 框架接口：struct pmm_manager（pmm.h），成员为 name / init / init_memmap /
  alloc_pages / free_pages / nr_free_pages / check。
- 数据结构：struct Page，字段为 ref / flags / property / page_link；
  free_area_t，成员为 free_list 和 nr_free。
- 页面操作：PageReserved / SetPageProperty / ClearPageProperty / PageProperty /
  set_page_ref。
- 链表操作：list_init / list_empty / list_next / list_prev / list_add /
  list_add_before / list_del，以及 le2page。
- 已有函数：assert、cprintf。
- 参考实现：default_pmm.c 中的对应管理函数。
- 已有测试：本文件中的 basic_check() 和 best_fit_check()。

测试函数直接使用 free_list 和 nr_free。请保留或补齐模块内的 free_area，
以及对应的两个宏，保持测试所需的状态约定。

[GUARANTEE]
必须实现：
1. best_fit_init(void)
2. best_fit_init_memmap(struct Page *base, size_t n)
3. best_fit_alloc_pages(size_t n)
4. best_fit_free_pages(struct Page *base, size_t n)
5. best_fit_nr_free_pages(void)

上述管理函数均设为 static。
定义 const struct pmm_manager best_fit_pmm_manager，将管理函数注册到对应成员，
.check 指向已有的 best_fit_check，.name 为 "best_fit_pmm_manager"。

[SPECIFICATION]
best_fit_init(void)
  - 初始化本模块的空闲链表，将空闲页总数设为0。
  - 此时 page_init() 尚未执行，只初始化管理结构。

best_fit_init_memmap(struct Page *base, size_t n)
  - 检查 n 大于0，输入页处于 Reserved 状态。
  - 初始化页面状态和引用计数，设置首页的 property 和 PageProperty 标志。
  - 增加空闲页总数，按地址顺序将块首页插入链表。

best_fit_alloc_pages(size_t n)
  - 检查 n 大于0。
  - 遍历空闲块，选择 property 大于等于 n 且最小的块。
  - 同样大小的块选择先遇到的一个；找到恰好 n 页的块时结束查找。
  - 找到后摘下原节点，块大小超过 n 时，将剩余部分作为新空闲块挂回原位置。
  - 空闲页总数减去 n，清除分配块首页的 PageProperty，返回首页描述符。
  - 找不到合适块时返回 NULL，链表和计数保持原样。

best_fit_free_pages(struct Page *base, size_t n)
  - 参考 default_free_pages() 检查页面状态并初始化释放区域。
  - 按地址插入链表，与前后物理连续的空闲块合并。
  - 更新块长度、首页标志和链表节点；空闲页总数只增加本次释放的 n 页。

best_fit_nr_free_pages(void)
  - 返回当前空闲页总数。

全局约束
  - 保持现有头文件和公开接口，通过项目的 gnu99、-Wall、-Werror 编译。
  - 保留 lab2 function2-2 注释，保留已有两个测试函数。
  - 当前默认管理器仍是 First-Fit；本次编译通过后，还需要切换管理器，
    才能通过内核启动流程执行 Best-Fit 自检。
````

#### 实现迭代过程

本模块经历了 **1 次代码生成迭代**，随后完成管理器切换和本机验证。

---

##### 第一次迭代

**生成结果：**

- 补齐五个管理函数及 `best_fit_pmm_manager` 注册结构。
- 保留模块内的 `free_area`、`free_list` 和 `nr_free`。
- 将 First-Fit 的首次匹配逻辑调整为最小合适块选择。
- 保持两个已有检查函数的内容原样。

**编译与运行验证：**

将生成代码写入 `best_fit_pmm.c`，并在 `pmm.c` 中选择 Best-Fit 后，执行：

```bash
make qemu
```

运行输出：

```text
memory management: best_fit_pmm_manager
check_alloc_page() succeeded!
```

这表明内核选择了 Best-Fit，且其 `basic_check()`、`best_fit_check()` 执行通过。

随后执行：

```bash
make grade
```

评分结果：

```text
-check page init:                          OK
-check best fit:                           OK
Total Score: 20/20
```

**最终结果：**

经过 1 次代码生成迭代，该模块达到以下结果：

- ✅ 编译、链接通过。
- ✅ Best-Fit 内置检查通过。
- ✅ 官方评分达到 20/20。
- ✅ 完成默认管理器切换。

**实现要点：**

1. 保持空闲链表按地址排序，方便释放时合并相邻块。
2. 分配时比较块大小，选择最小合适块；相同大小保留先遇到的块。
3. 保留已有测试所依赖的状态约定，使生成实现能够接入现有检查流程。

本次生成后即通过上述验证，提示词保持原样。


### 功能模块：Buddy System（伙伴系统）

**负责人：** 2412102-聂海丽
#### 最终提示词

**提示词①**

````markdown
[PROMPT]
你在为一个 RISC-V 架构的教学操作系统 ucore（lab2）实现页级物理内存管理器。
本 lab 把"物理页分配算法"抽象成可插拔的 struct pmm_manager，内核只通过 pmm_manager->xxx
回调使用它。请**新建**两个文件，实现一个页级 Buddy System（伙伴系统）管理器并接入该框架：
  - 新建 kern/mm/buddy_pmm.c
  - 新建 kern/mm/buddy_pmm.h
实现方式：
  - 先读 kern/mm/default_pmm.c（现成的 First-Fit 参考实现）与 kern/mm/best_fit_pmm.h，
    保持同样的代码风格：cprintf 打印、assert 断言、list.h 双向链表。
  - 空闲块按阶（order）组织：模块内一个 static 的 free_area_t 数组，下标即阶，
    最大阶用宏 MAX_ORDER 表示（取 15）。这类宏只写在 .c 里，不要放进头文件。
  - 分配：块大小向上取整到 2 的幂；若目标阶没有空闲块就向上找更大的阶，取到后逐级对半拆分，
    把拆出的另一半挂到对应阶的空闲链表。
  - 释放：按"伙伴下标 = 当前块下标 XOR (1 << 当前阶)"逐级合并，直到不可合并。
  - 不要修改任何已有文件（尤其 pmm.h / memlayout.h / pmm.c / Makefile）。
请先说明你的设计（阶数怎么记录、初始空闲区怎么拆、合并循环的终止条件），再给代码。
最后输出两份**完整**文件内容（buddy_pmm.h 和 buddy_pmm.c），不要省略、不要写"…其余同上"。

[RELY]
可以依赖的东西：
- 框架接口：struct pmm_manager（kern/mm/pmm.h），成员为 name / init / init_memmap /
  alloc_pages / free_pages / nr_free_pages / check。
- 数据结构：struct Page（kern/mm/memlayout.h，字段 ref / flags / property / page_link）、
  free_area_t{ list_entry_t free_list; unsigned int nr_free; }；
  页标志宏 SetPageReserved / ClearPageReserved / PageReserved / SetPageProperty /
  ClearPageProperty / PageProperty。
- 链表工具：list.h 的 list_init / list_add / list_del / list_empty / list_next 和 le2page。
- 已有函数：cprintf（stdio.h）、assert（assert.h）、memset（string.h）、
  page2pa / pa2page / page_ref / set_page_ref（pmm.h）。
- 参考实现：default_pmm.c 里的 default_init、default_init_memmap、default_alloc_pages、
  default_free_pages、default_nr_free_pages、basic_check，请对照它写。
- 允许 #include 的只有：<pmm.h> <memlayout.h> <list.h> <defs.h> <assert.h> <stdio.h> <string.h>。

[GUARANTEE]
必须交付：
1. kern/mm/buddy_pmm.h —— 仿照 best_fit_pmm.h：include guard + #include <pmm.h>
   + 只导出一行 extern const struct pmm_manager buddy_pmm_manager;
2. kern/mm/buddy_pmm.c —— 定义 const struct pmm_manager buddy_pmm_manager，六个成员
   一个都不能是 NULL：
     .name          = "buddy_pmm_manager"
     .init          = buddy_init
     .init_memmap   = buddy_init_memmap
     .alloc_pages   = buddy_alloc_pages
     .free_pages    = buddy_free_pages
     .nr_free_pages = buddy_nr_free_pages
     .check         = buddy_check
3. 所有非 static 符号一律加 buddy_ 前缀（避免与 default_pmm.c / best_fit_pmm.c 重名）；
   不新增任何导出的全局变量；不修改任何已有文件。

[SPECIFICATION]
每个函数的行为规格：

buddy_init(void)
  - 只初始化你自己的各阶空闲链表与空闲页计数器（模块内 static 数据）。
  - **关键约束**：框架调用顺序是 init_pmm_manager()（先调 pmm_manager->init()）→ page_init()
    → check_alloc_page()。也就是说 buddy_init() 执行时全局变量 pages 仍是 NULL、npage 仍是 0，
    因此这里**不能**遍历 pages 数组，也不能使用 npage。

buddy_init_memmap(struct Page *base, size_t n)
  - 输入区间 [base, base+n) 是"内核与页描述符数组之后、全部可用的完整物理页"，其长度与起始
    页号通常都不是 2 的幂、也不按 2 的幂对齐。
  - 必须把它拆成**若干对齐的 2 的幂块**再挂到对应阶的空闲链表：从区间起点开始，在"不超过剩余
    长度"且"不越过按 2^k 对齐的边界"两个约束下取尽可能大的 k，挂一个块，推进指针，重复到结束。
  - 进入本函数时区间内的页是 Reserved 状态（框架 page_init 先把所有页标为保留，再把这段空闲区
    交给你）。请按 default_init_memmap 的约定：先 assert(PageReserved(p))，然后清零
    flags / property / ref，并统计 nr_free。区间之外的页绝对不要碰。

buddy_alloc_pages(size_t n)
  - 分配 n 页**连续**内存，块大小向上取整到 2 的幂（把该幂次记为阶 k）。
  - 若第 k 阶没有空闲块，就向上找更大的阶，取一块后逐级对半拆分，把拆出的另一半挂到对应阶的
    空闲链表，直到剩下第 k 阶的块并返回。
  - 返回块首页的 struct Page *；分配出去的块要 ClearPageProperty，并扣减空闲页计数。
  - 找不到足够大的块时返回 NULL，**且不得改动任何链表和计数**（失败路径不能有副作用）。

buddy_free_pages(struct Page *base, size_t n)
  - 先按与 alloc **完全相同**的规则把 n 向上取整到 2 的幂，得到阶 k。
  - 然后循环合并：伙伴下标 = 当前块下标 XOR (1 << 当前阶)；若伙伴是同阶空闲块（在同一阶空闲
    链表里）就合并成高一阶的块并继续尝试，直到伙伴不可合并或到达 MAX_ORDER。
  - 合并后更新块的 property 与该阶链表，并增加空闲页计数。
  - 注意：alloc 与 free 的取整必须由同一个函数（或完全一致的规则）实现。

buddy_nr_free_pages(void)
  - 返回所有阶空闲链表里空闲页数的总和。

buddy_check(void)
  - 自测函数，用 assert 判定（失败即 panic），并用 #ifdef ucore_test … #endif 包裹进度打印，
    格式 cprintf("grading: %d / %d points\n", score, sumscore);（便于 make test 观察）。
  - 结束时必须把系统状态恢复原样（保存/恢复 nr_free 与各阶链表）。
  - 至少覆盖：分配大小向上取整到 2 的幂、拆分与伙伴合并、释放后可重新分配、分配失败返回 NULL、
    nr_free_pages 的一致性、边界（最小块 1 页、最大块、非 2 的幂页数）。

全局约束
  - 代码必须通过 -Wall -Werror（发行工具链是 GCC 15，隐式函数声明是硬错误）。
  - cprintf 的格式串必须与参数类型严格匹配：size_t 用 %lu，int 用 %d，地址用 0x%016lx。
````

**提示词②**

````markdown
[PROMPT]
根据我刚生成的 kern/mm/buddy_pmm.c 完整实现。框架要求每个管理器提供一个
check() 自测函数，内核在 pmm_init() 末尾通过 check_alloc_page() 调用它。
请为它写 buddy_check()，并把 pmm_manager 里的 .check 指向它。

[RELY]
- 可用 assert（assert.h）、cprintf（stdio.h）、list.h 的宏（list_next / le2page）、
  PageProperty 等页标志宏（memlayout.h）、alloc_pages / free_pages / nr_free_pages（pmm.h）。
- 可以参考 kern/mm/best_fit_pmm.c 里 best_fit_check 的组织方式：保存状态 → 分段测试 →
  恢复状态 → 遍历空闲链表核对计数。
- 注意：buddy 用的是模块内 static 的各阶空闲链表，不能照抄 best_fit_check 里的
  free_list / nr_free 宏用法，请按 buddy 自己的实现来遍历。

[GUARANTEE]
- 交付完整的 buddy_check() 函数代码（不要省略、不要写"…其余同理"）。
- 该函数要能直接赋给 pmm_manager.check；不需要额外导出其它符号，
  除 buddy_pmm.c 之外不要修改任何文件。

[SPECIFICATION]
1. 只用 assert 做判定，失败即 panic（这是 ucore 的风格，不要用 printf 报告失败）。
2. 用 #ifdef ucore_test … #endif 包裹进度打印，格式：
   cprintf("grading: %d / %d points\n", score, sumscore);
   每完成一类测试打印一次。
3. 必须覆盖以下 7 类：
   (1) 分配大小向上取整到 2 的幂
   (2) 拆分与伙伴合并（释放后能重新拿到同样大小的块）
   (3) 释放后可重新分配（alloc → free → alloc 得到同一个 Page*）
   (4) 分配失败返回 NULL（请求超过最大阶），且失败后 nr_free 不变
   (5) nr_free_pages() 与各阶空闲链表页数总和一致
   (6) 边界：1 页（最小块）、最大阶的块、非 2 的幂页数（3 / 5 / 7 页）
   (7) 碎片场景：分配 A B C 三块，只释放中间的，验证不会错误合并相邻的不同阶块
4. 遍历空闲链表时用 list.h 的宏，并对每个空闲块 assert(PageProperty(p))。
5. 测试结束前把系统状态（各阶链表与空闲页计数）还原原样，避免影响后续内核流程。
````

---

#### 实现迭代过程

本模块经历了 **2 次迭代**（第一轮生成实现，第二轮重新生成并加强测试），另有 1 次**变异测试**用于验证测试本身的有效性。

---

##### 第一次迭代

**做法：** 用提示词①生成 `buddy_pmm.h`（8 行）与 `buddy_pmm.c`（398 行），接入 `pmm_manager`；生成后按计划只做编译，不跑内核。

**结果：**

- ✅ 默认构建 `make` 与 Buddy 构建 `make DEFS="-DPMM_USE_BUDDY"` 均 0 error / 0 warning（GCC 15 的 `-Wall -Werror`）
- ✅ 符号表检查：`obj/kernel.sym` 中新增的非 static 符号只有 `buddy_pmm_manager`，符合"非 static 符号一律加 `buddy_` 前缀"的约束
- ✅ 运行 `make qemu DEFS="-DPMM_USE_BUDDY"` 一次通过：

```
memory management: buddy_pmm_manager
physical memory map:
  memory: 0x0000000008000000, [0x0000000080000000, 0x0000000087ffffff].
check_alloc_page() succeeded!
```

**这一轮没有出现问题**，原因是我们把三条最容易踩的坑**事先写进了提示词的 `[SPECIFICATION]`**，而不是等 AI 生成后再修：

1. **取整规则不对称**（最常见的 bug）：如果 alloc 按 2 的幂取整、free 按原始 `n` 找阶，释放时算出的阶就与分配时不同，伙伴地址随之算错，链表会被破坏。提示词里明确要求"alloc 与 free 的取整必须由同一个函数（或完全一致的规则）实现"，代码里两者都走 `buddy_order_of()`。
2. **初始空闲区被当成一整块**：`init_memmap()` 收到的区间长度（实测约 31929 页）与起始页号都不是 2 的幂，直接当成一个块挂上去会让后续所有伙伴运算失效。提示词里明确要求"拆成若干对齐的 2 的幂块"。
3. **在 `init()` 里遍历 `pages` / 使用 `npage`**：框架的调用顺序决定了此时两者还不可用。提示词里把这一点标为"关键约束"，代码里也留了注释。

**关键改进点总结（迭代前的提示词设计）：**

1. 在 `[RELY]` 里**穷举了可依赖的宏与函数**，避免 AI 自己去猜接口或造轮子；
2. 在 `[SPECIFICATION]` 里**按函数逐条写规格**（而不是按"分配/释放"这种维度），保证 `nr_free_pages` 这类小函数不会被漏掉；
3. 显式写出**框架调用时序**（`init()` 早于 `page_init()`）这一条隐含约定——这是读 `pmm.c` 才能发现的信息，不写进提示词 AI 必然会踩。

---

##### 第二次迭代

**做法：** 用提示词②重新生成测试套件，替换第一次自带的 7 类基础测试；生成后编译并运行。

**这一轮把测试加强了三个地方**（第一次的自测只有"逐条断言"，颗粒度偏粗）：

| 增强 | 内容 | 为什么需要 |
|---|---|---|
| ① 全局结构不变量扫描 | 用 `buddy_check_invariants()` 取代原来的简单统计，在每个阶段后都扫描全部空闲链表：块头标记与 `property` 是否自洽、整块是否落在可管理区间内、**块内除首页外不能出现别的空闲块头**、**同阶伙伴不能同时空闲** | 前两条抓"阶数记错/块越界"，后两条抓"空闲区间重叠（会导致双重分配）"和"该合并的没合并（碎片泄漏）"——这些是逐条断言难以覆盖的结构性错误 |
| ② 拆分形态的精确断言 | 先找一个"本级链表为空、但更高阶有空闲块"的阶 k（这样的请求**必然**触发拆分），分配后逐阶核对块数变化：`j` 阶 −1、`k..j−1` 每阶 +1、其余阶不变 | 原来的 (2) 只断言"分布确实变了"，但其实拿的是整块、可能根本没触发拆分；现在把"拆分"从"应该发生了"变成"确切的形态" |
| ③ 乱序释放压力测试 | 12 个不同大小的块（含 3/5/7 等非 2 的幂），按"逆序释放"和"奇偶分两批释放"两种顺序各跑一轮，结果都必须与初始分布完全一致 | 不同释放顺序会走不同的合并路径，能暴露只在特定合并顺序下才出现的错误 |

另外每个阶段后都补了 **"各阶空闲块分布完全复原"** 的断言（比只比较 `nr_free` 强得多），并在 (1)(6) 增加了"分配出去的块内部不能残留块头标记""按取整后大小释放也合法（`alloc(3)` 之后用 `free(p, 4)`）"两项。

**结果：**

- ✅ 编译 0 error / 0 warning；运行 `check_alloc_page() succeeded!`，7 类测试全部通过
- ✅ `make test DEFS="-DPMM_USE_BUDDY"` 可以看到 7 次 `grading: x / 7 points` 进度打印

**变异测试（验证"测试本身是否有效"）：**

只报告"测试通过"并不能说明测试有没有杀伤力，所以我们做了一个反向实验：**故意在 `buddy_free_pages()` 的合并循环前插入一句 `return;`，即释放时完全不与伙伴合并**，再跑同一套测试：

```
kernel panic at kern/mm/buddy_pmm.c:241:
    assertion failed: !(PageProperty(buddy) && buddy->property == size)
```

报错的正是 `buddy_check_invariants()` 里"同阶伙伴不能同时空闲"那一条（对应源码第 240 行），而且是在**第一次不变量扫描**就抓住了。这证明这套测试确实能识别"漏合并"这一类错误。实验后已把注入的代码还原并重新编译运行，确认恢复正常。

---

#### 测试覆盖说明

`buddy_check()` 共 7 类测试，除 (4) 外每一类结束时都会额外断言"各阶空闲块分布完全复原"，因此任何"该合并没合并"或"错误合并了不该合并的块"都会被立即发现。

| 测试 | 具体做法 | 能抓住什么 bug |
|---|---|---|
| (1) 向上取整到 2 的幂 | `alloc_pages(3)` 后断言 `nr_free` 恰好减少 **4**、返回块按 4 页对齐、块内 4 页均无 `PG_property` | 取整规则不对称；块内部残留块头标记（合并时漏 `ClearPageProperty`） |
| (2) 拆分与伙伴合并 | 强制走拆分路径后，逐阶核对块数变化（`j` 阶 −1、`k..j−1` 每阶 +1）；释放后分布必须**完全复原** | 拆分时高半块没挂进链表、阶数算错；合并没有逐级向上、或合并后没更新 `property` 与链表 |
| (3) 释放后可重新分配 | 记录分配块的伙伴是否被占用，释放后重新分配；若伙伴被占用则必须**原样拿回同一块** | 释放后块没有真正回到空闲链表、或把仍被占用的邻块也回收了 |
| (4) 失败路径 | 请求 `0` 页、超过最大阶、超过全部物理页，都必须返回 `NULL` 且 `nr_free` 不变 | 失败时已经改动了链表或计数（例如拆了一半才发现不够） |
| (5) 计数一致性 | `nr_free_pages()` 与各阶链表页数总和、以及不变量扫描的累计值三者相等 | "扣了计数没摘链表"这类记账错误 |
| (6) 边界 | 最小块（1 页）、非 2 的幂（3/5/7 页，分别按 4/8/8 页计）、按取整后大小释放（`alloc(3)` → `free(p,4)`）、最大块（取当前最高阶的块） | 1 页走的是"从最大阶一路拆到最后"的最长拆分链；最大阶验证 `MAX_ORDER` 边界；取整后大小释放验证 `free` 的取整与 `alloc` 一致 |
| (7) 碎片与释放顺序 | 7a：分配 A、B 后只释放 A，断言只回收 2 页且再分配不会与 B 重叠；7b：12 个不同大小的块按两种顺序释放，分布都必须复原 | 错误地把仍被占用的邻块合并进来（内存重叠 → 后续双重分配）；只在特定释放顺序下才出现的合并路径错误 |

**为什么这套测试能有效检验**，除了逐条覆盖之外，还有三点结构性保证：

1. **每类测试都用真实操作序列驱动**，不直接摆弄内部链表，因此测的是"框架看到的接口行为"，而不是"实现内部的私货"；
2. **每次操作后都做全量不变量扫描**（而不是只看返回值），把"返回值正确但内部结构已经坏了"的情况也纳入检查；
3. **变异测试给出了反向证据**：注入"释放不合并"这一典型错误后，测试在第一次扫描就 panic，说明断言确实卡在了关键不变量上。

