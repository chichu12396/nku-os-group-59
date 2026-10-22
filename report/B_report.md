# 任务 B 实验报告（Buddy System / GDB 调试 QEMU·甲 / 对操作系统的理解）

**负责人：** 2412102-聂海丽

**AI 工具 / 底层模型：** Claude Code（终端 Agent） / DeepSeek-V4.1-Flash 



---

## 四、实验内容与实现

### 功能模块：Buddy System（伙伴系统）

**负责人：** 2412102-（姓名）


---

#### 模块功能描述

**需要实现/修改的函数（新建文件 `kern/mm/buddy_pmm.h` + `kern/mm/buddy_pmm.c`）：**

```c
extern const struct pmm_manager buddy_pmm_manager;   // 供 pmm.c 在 PMM_USE_BUDDY 下选用

static void        buddy_init(void);
static void        buddy_init_memmap(struct Page *base, size_t n);
static struct Page *buddy_alloc_pages(size_t n);
static void        buddy_free_pages(struct Page *base, size_t n);
static size_t      buddy_nr_free_pages(void);
static void        buddy_check(void);
```

**功能说明：**

Buddy System 是本实验里与 First-Fit / Best-Fit 并列的另一种**页级**物理内存分配算法，通过 `struct pmm_manager` 这个函数指针表接入 ucore 的内存管理框架：内核只调用 `alloc_pages / free_pages / nr_free_pages`，具体策略由被选中的管理器实现。本模块把空闲物理页按**阶（order）**组织：第 order 阶的一个空闲块由 `2^order` 个连续物理页组成，块首页挂在 `buddy_free_area[order]` 链表上，首页的 `Page.property` 记录块内页数。

它解决的问题是**外部碎片的可控化**：First-Fit 把空闲区切成任意长度后，长期分配/释放会留下大量难以复用的小碎片；Buddy 把块大小限制为 2 的幂、并要求块按自身大小对齐，换来的是"释放时能以 O(log n) 逐级合并回大块"，代价是**内部碎片**（申请 3 页要占 4 页）。

与其他模块的交互：`page_init()` 把"内核与页描述符数组之后的完整空闲页"交给 `init_memmap()`，本模块负责把它拆成对齐的 2 的幂块；此后 `alloc_pages / free_pages` 供内核（以及 C 的 SLUB）使用；`check()` 由框架在 `pmm_init()` 末尾通过 `check_alloc_page()` 调用。模块内所有非 static 符号统一加 `buddy_` 前缀，宏只写在 `.c` 里，不碰任何共享头文件。

**四个关键设计决定（First-Fit 的习惯写法不能直接搬到 Buddy 上）：**

1. **伙伴运算用"页数组下标"而不是物理地址**：伙伴下标 = `下标 ^ (1 << order)`。因为 `DRAM_BASE = 0x80000000` 是 2³¹ 对齐的，下标的对齐性等价于物理地址的对齐性，用下标运算既简单又不会漏掉 `nbase` 偏移。
2. **初始空闲区必须"对齐拆分"**：`init_memmap()` 拿到的区间长度和起始页号通常都不是 2 的幂、也不按 2 的幂对齐（实测约 31929 页），必须拆成若干个"长度为 2 的幂、起始下标按该幂次对齐"的块。这个分解是唯一的，天然满足"同阶伙伴不会同时空闲"这一不变量——`check()` 的两条强断言正是建立在它之上。
3. **`free` 只能整块回收**（与 First-Fit 最大的行为差异）：`base` 必须按 `round_up(n)` 的块大小对齐，回收的正是那一整块。First-Fit 那种 `free_pages(p0 + 1, 2)`（想把哪一段还回去就还哪一段）在 Buddy 上不成立，代码里用 `assert` 明确拦住了。
4. **`buddy_init()` 里不能访问 `pages` / `npage`**：框架调用顺序是 `init_pmm_manager()`（先调 `init()`）→ `page_init()`，所以 `init()` 执行时 `pages` 还是 `NULL`、`npage` 还是 0，只能初始化模块自己的链表与计数器。

`MAX_ORDER` 取 15（128MB = 32768 页 = 2¹⁵，留足余量）。

---

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

---

### 练习：GDB 调试 QEMU（甲：调用路径与页表遍历）

**负责人：** 2412102-（姓名）


本部分对应调试要求 ①（给出访存的虚拟地址如何被 QEMU 翻译成物理地址的**关键调用路径与关键分支**）与 ②（**单步调试页表遍历**并解释流程）。完整原始会话记录见 `report/gdb_rst.md`。

---

#### 0. 调试环境与准备

| 项 | 值 |
|---|---|
| QEMU | **4.1.1**（自建：`~/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64`；`--target-list=riscv64-softmmu --enable-debug`） |
| 编译优化 | **-O0 -g**（`--enable-debug` 关闭优化并保留调试信息，变量不会被优化掉，适合单步） |
| 宿主 gdb | GNU gdb (Ubuntu 15.1) |
| 被调试对象 | 内核 `bin/ucore.img`（`-device loader,file=...,addr=0x80200000`） |

> **说明：为什么必须先解决 QEMU 版本问题。** 本 lab 的内核在当前环境（QEMU 7.0/8.2）下**完全起不来**：`-bios default` 在新版 QEMU 上是 `fw_dynamic` 固件，配 Makefile 的 `-device loader` 时 OpenSBI 打印 `Domain0 Next Address : 0x0` 并跳到 0；即便让它跳到 `0x80200000`，内核也会在 `kern/init/entry.S` 启用分页后立刻陷入 `exec_page_fault`（`epc = tval = 0x80200000`）的死循环。根因见第 5 节"有趣的细节"。因此我们自建了 QEMU 4.1.1 用于本实验与调试。

调试入口是 `bin/kernel` 里 `kern_init` 的地址——**这个地址每次重新编译都可能变化**，所以每次都从符号表现取，不硬编码：

```bash
grep -E " kern_init$" obj/kernel.sym
# ffffffffc02000d8 kern_init      ← 本次调试取到的值
```

---

#### 一、要求①：关键调用路径

##### 1.1 分层结构

一次访存/取指要拿到物理地址，QEMU 里跨了两层：**与架构无关的通用 TCG 层**（软件 MMU 的通用框架）和**RISC-V 专属层**（页表遍历本体）。两条路径最终在通用层的 `tlb_fill()` 汇合，再由函数指针 `cc->tlb_fill` 进入 RISC-V 的实现。

##### 1.2 取指路径（实测 `bt`，条件断点命中时）

```
#0  get_physical_address     target/riscv/cpu_helper.c:158   ← RISC-V 翻译本体
#1  riscv_cpu_tlb_fill       target/riscv/cpu_helper.c:451   ← 由 cc->tlb_fill 调用
#2  tlb_fill                 accel/tcg/cputlb.c:878          ← 通用 TCG 层收口
#3  get_page_addr_code       accel/tcg/cputlb.c:1032         ← 取指专用入口
#4  tb_htable_lookup         accel/tcg/cpu-exec.c:339
#5  tb_lookup__cpu_state     include/exec/tb-lookup.h:43
#6  helper_lookup_tb_ptr     accel/tcg/tcg-runtime.c:154
#7  code_gen_buffer                                          ← JIT 生成的宿主代码
```

##### 1.3 访存路径（把条件断点换成一条**数据访问**地址后实测）

数据访问的地址不能硬编码（内核一重新编译，`.data`/栈的地址就会移位），做法是先从 `-d mmu` 日志里挑一条 `rw 1`（store）或 `rw 0`（load）的地址，再拿它设条件断点：

```bash
# 1) 先抓一份翻译日志，从里面挑一条数据访问地址
$LAB2_QEMU -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000 -monitor null -no-reboot \
    -d mmu -D /tmp/mmu.log
grep "rw 1" /tmp/mmu.log | head        # 挑一条，例如 ad ffffffffc0204ff8 rw 1（栈上的写）

# 2) 用它设条件断点，再取调用链
(gdb) break get_physical_address if addr == <上一步挑到的地址>
```

实测得到的调用链：

```
#0  get_physical_address     target/riscv/cpu_helper.c:158
#1  riscv_cpu_tlb_fill       target/riscv/cpu_helper.c:451
#2  tlb_fill                 accel/tcg/cputlb.c:878          ← 与取指同一个收口
#3  store_helper             accel/tcg/cputlb.c:1522         ← 数据访问专用入口
#4  helper_le_stq_mmu        accel/tcg/cputlb.c:1672         ← 8 字节 store 的软 MMU helper
#5  code_gen_buffer
#6  cpu_tb_exec              accel/tcg/cpu-exec.c:173
#7  cpu_loop_exec_tb         accel/tcg/cpu-exec.c:621
```

##### 1.4 结论

**取指与访存在 `tlb_fill()` 处分叉、又在 `tlb_fill()` 处汇合**：

- **取指**走的是"**TB 查找**"这条线（`helper_lookup_tb_ptr` → `tb_lookup__cpu_state` → `tb_htable_lookup` → `get_page_addr_code`）。因为 QEMU 要先把这个虚拟地址翻译成物理地址、取出指令，才能生成/执行下一个翻译块（TB）。
- **数据访问**走的是"**软 MMU helper**"这条线（`helper_le_stq_mmu` → `store_helper`），即由 JIT 代码在遇到未命中的访存时调用 helper。
- 两者进入 `tlb_fill()`（`cputlb.c:878`）后路径完全相同：`cc->tlb_fill` → `riscv_cpu_tlb_fill()`（`cpu_helper.c:435/451`）→ `get_physical_address()`（`cpu_helper.c:155`）→ 成功后 `tlb_set_page()`（`cpu_helper.c:472`）把结果**回填进 QEMU 的 TLB**。

---

#### 二、要求①：关键分支

以 QEMU 4.1.1 源码为准（`~/qemu-src/qemu-4.1.1/`）。这些分支决定了翻译走哪条路、成功还是失败，也就是"关键调用路径上会改变结果的判断点"。

| # | 位置（文件:行） | 分支 / 判断 | 结果 |
|---|---|---|---|
| 1 | `cpu_helper.c:163-175` | `mode == PRV_M` 或未启用 MMU | 直接恒等映射，`*physical = addr`，返回成功（M 模式的访存不翻译） |
| 2 | `cpu_helper.c:183-186` | 取 `base = satp.PPN << 12`、`vm = satp.MODE` | 决定页表根地址与分页模式 |
| 3 | `cpu_helper.c:187-202` | `switch (vm)`：SV32/SV39/SV48/SV57 → 定 `levels/ptidxbits/ptesize`（Sv39 → 3/9/8）；**`VM_1_10_MBARE` → 恒等映射直接返回** | 关键分支，启动阶段走的就是 MBARE 这一条（见 4.1 节日志） |
| 4 | `cpu_helper.c:224-229` | 高位地址与规范地址检查 | 非法 VA → `TRANSLATE_FAIL` |
| 5 | `cpu_helper.c:237-239` | 主循环 `for (i = 0; i < levels; i++, ptshift -= ptidxbits)`，`idx = (addr >> (12 + ptshift)) & 0x1FF` | 决定每一级取的是 VPN[2]/VPN[1]/VPN[0] 中的哪一个 |
| 6 | `cpu_helper.c:242` | `pte_addr = base + idx * ptesize` | 本轮 PTE 的物理地址 |
| 7 | `cpu_helper.c:244-248` | PMP 是否允许访问该 PTE 所在物理地址 | 不允许 → `TRANSLATE_PMP_FAIL` |
| 8 | `cpu_helper.c:256-258` | **`!(pte & PTE_V)`** | 无效 PTE → `TRANSLATE_FAIL`（"未映射"就是这一条） |
| 9 | `cpu_helper.c:259-261` | `!(pte & (PTE_R\|PTE_W\|PTE_X))`：是**非叶子** PTE | `base = ppn << 12`，**继续下一级遍历**（这是"三级遍历"能走下去的原因） |
| 10 | `cpu_helper.c:262-275` | 保留的叶标志组合（W、W\|X）、`PTE_U` 与特权级/`mstatus.SUM` 是否匹配 | 不合法 → `TRANSLATE_FAIL` |
| 11 | `cpu_helper.c:276-278` | 大页 PPN 对齐检查 `ppn & ((1 << ptshift) - 1)` | 不对齐 → `TRANSLATE_FAIL`；通过则认定为**大页叶子** |
| 12 | `cpu_helper.c:279-288` | 按访问类型查权限：LOAD 要 `PTE_R`（或 `PTE_X && mstatus.MXR`）、STORE 要 `PTE_W`、INST_FETCH 要 `PTE_X` | 权限不足 → `TRANSLATE_FAIL` |
| 13 | `cpu_helper.c:289-329` | 需要时**原子更新 PTE 的 A/D 位**（RAM 里用 `atomic_cmpxchg`；PTE 在 ROM/IO 空间则失败）；CAS 失败则 `goto restart` 重新遍历 | 这是 QEMU 与真实硬件的一个实现差异（硬件由 MMU 自动置位） |
| 14 | `cpu_helper.c:331-334` | 大页合成：`*physical = (ppn \| (vpn & ((1 << ptshift) - 1))) << 12` | 得到最终物理地址（**按页对齐**） |
| 15 | `cpu_helper.c:337-349` | 由 PTE 的 R/W/X 位算出 `*prot`（`PAGE_READ/WRITE/EXEC`） | 成功返回 `TRANSLATE_SUCCESS` |
| 16 | `cpu_helper.c:352` | 三级走完仍未遇叶子 | `TRANSLATE_FAIL` |
| 17 | `cpu_helper.c:355-374` | 失败时选异常号：SATPG 模式非 MBARE 且非 PMP 违例 → 按访问类型报 **INST/LOAD/STORE PAGE_FAULT**，否则报 **ACCESS_FAULT** | 决定 guest 收到哪种异常 |
| 18 | `cpu_helper.c:463-480` | 最后再做一次 PMP 检查；成功则 `tlb_set_page()` 回填 TLB，失败则 `raise_mmu_exception()` + `riscv_raise_exception()` 抛给 guest；（`probe=true` 时只探测不写 TLB） | 路径终点 |

关键常量（`target/riscv/cpu.h:85-87`、`cpu_bits.h:454-473`、`include/qom/cpu.h:66-70`）：`TRANSLATE_SUCCESS 0 / FAIL 1 / PMP_FAIL 2`；`VM_1_10_MBARE 0 / SV39 8`；`PTE_V 0x1 R 0x2 W 0x4 X 0x8 U 0x10 G 0x20 A 0x40 D 0x80`，`PTE_PPN_SHIFT 10`；`MMUAccessType`：`MMU_DATA_LOAD 0 / MMU_DATA_STORE 1 / MMU_INST_FETCH 2`。

---

#### 三、要求②：单步调试页表遍历

##### 3.1 断点脚本

用条件断点只在**目标虚拟地址被翻译时**停下（否则启动过程上千次翻译会把调试淹没）。地址取自 `obj/kernel.sym` 的 `kern_init`：

```bash
gdb --args $LAB2_QEMU -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000 -monitor null -no-reboot

(gdb) set pagination off
(gdb) break get_physical_address if addr == 0xffffffffc02000d8   # 条件断点
(gdb) run
(gdb) bt 8                       # 调用路径（见第一节）
(gdb) break cpu_helper.c:242     # 循环体内，此时 idx 已算好
(gdb) continue
(gdb) print i                    # 第几级
(gdb) print/x idx                # 本级的页表索引
(gdb) next
(gdb) print/x pte_addr           # 本级 PTE 的物理地址
(gdb) break cpu_helper.c:256     # 此时 pte 已从内存读出
(gdb) continue
(gdb) print/x pte
(gdb) print/x ppn
(gdb) break cpu_helper.c:337     # 物理地址已在 331-334 行算好
(gdb) continue
(gdb) print levels / ptidxbits / ptesize / vm / base / vpn / *physical
(gdb) break cpu_helper.c:349
(gdb) continue
(gdb) print/x *prot
```

> **踩过的坑（重要）**：行断点停在"**该行还没执行**"的位置。如果在 `cpu_helper.c:254` 处直接 `print/x ppn`，拿到的是未初始化的栈垃圾值（我们实测拿到过 `0x555555e22d10` 这种宿主地址）。要读某个变量的值，必须在**它的下一条语句**处设断点。

##### 3.2 实测会话（节选自 `report/gdb_rst.md`）

```
Thread 3 "qemu-system-ris" hit Breakpoint 1, get_physical_address (
    env=0x555556558110, physical=0x7ffff4ffd1f0, prot=0x7ffff4ffd1e4,
    addr=18446744072637907160, access_type=2, mmu_idx=1)          ← addr = 0xffffffffc02000d8
    at .../target/riscv/cpu_helper.c:158
(gdb) print i
$1 = 0
(gdb) print/x idx
$2 = 0x1ff
(gdb) next
244             if (riscv_feature(env, RISCV_FEATURE_PMP) &&
(gdb) print/x pte_addr
$3 = 0x80205ff8
(gdb) print/x pte
$4 = 0x200000cf
(gdb) print/x ppn
$5 = 0x80000
(gdb) print levels          $6 = 3
(gdb) print ptidxbits       $7 = 9
(gdb) print ptesize         $8 = 8
(gdb) print vm              $9 = 8
(gdb) print/x base          $10 = 0x80205000
(gdb) print/x vpn           $11 = 0xffffffffc0200
(gdb) print/x *physical     $12 = 0x80200000
(gdb) print/x *prot         $13 = 0x7
```

##### 3.3 数值汇总与逐级解释

| 变量 | 实测值 | 含义 |
|---|---|---|
| `addr` | `0xffffffffc02000d8` | 被翻译的虚拟地址（`kern_init` 第一条指令的取指） |
| `access_type` | `2` = `MMU_INST_FETCH` | 这是一次**取指**翻译 |
| `mmu_idx` | `1` | 特权级 = **S 模式**（`cpu_mmu_index` 就是特权级：1=S、3=M） |
| `base` | `0x80205000` | 页表根物理地址（= `satp.PPN << 12`，与启动后打印的 `satp physical address: 0x0000000080205000` 一致） |
| `vm` / `levels` / `ptidxbits` / `ptesize` | `8` / `3` / `9` / `8` | 分页模式 Sv39 → 三级，每级 9 位索引，PTE 8 字节 |
| `i` | `0` | 当前在第 0 级（最高级，取 VPN[2]） |
| `idx` | `0x1ff` | `(addr >> 30) & 0x1ff` = VPN[2] = 511 |
| `pte_addr` | `0x80205ff8` | `base + idx * ptesize = 0x80205000 + 511*8`，即页表第 511 项的物理地址 |
| `pte` | `0x200000cf` | 读出的 PTE 原始值，与 `entry.S` 里 `.quad (0x80000 << 10) \| 0xcf` 完全对应 |
| `ppn` | `0x80000` | `pte >> 10`，物理页号 → 大页基址 `0x80000000` |
| `vpn` | `0xffffffffc0200` | `addr >> 12` |
| `*physical` | `0x80200000` | 翻译结果（**按页对齐**，页内偏移 0xd8 由 TLB 的记录方式另行处理） |
| `*prot` | `0x7` | `PAGE_READ \| PAGE_WRITE \| PAGE_EXEC` |

**逐级解释（这一例只走了一级，原因见下）：**

1. 第 0 级（i=0，ptshift=18）：`idx = (addr >> 30) & 0x1FF = 511`，`pte_addr = 0x80205000 + 511*8 = 0x80205FF8`，读出 `pte = 0x200000CF`。
2. 判 `PTE_V` 置位 ✔；再判 `PTE_R|PTE_W|PTE_X`：`0xCF & 0xE = 0xE ≠ 0`，说明**这是一个叶子 PTE**，不需要再往下走。
3. 大页对齐检查：`ppn & ((1 << ptshift) - 1) = 0x80000 & 0x3FFFF = 0` ✔，通过——因此这个 PTE 被认定为合法的 **1GB 大页**（2^18 页）。
4. 权限检查：本次是取指（`access_type = 2`），要求 `PTE_X` 置位；`pte & PTE_X = 8` ✔。
5. 计算物理地址：`*physical = (ppn | (vpn & ((1 << 18) - 1))) << 12`，即把 `vpn` 的低 18 位并进 `ppn`，得到 `0x80200 << 12 = 0x80200000`。
6. 回到 `riscv_cpu_tlb_fill()`，`prot = 0x7`，调用 `tlb_set_page()` 把这条映射回填进 QEMU 的 TLB，并返回成功。

**为什么只走了一级？** 因为启动页表 `boot_page_table_sv39` 只填了第 511 项（`.zero 8 * 511` 之后一个 `.quad`），把 `0xFFFFFFFFC0000000` 起的 1GB 空间整体映射到 `0x80000000`。所以内核在启动页表下的每一次翻译都是"第 0 级就命中大页叶子"，不会走到第 1、2 级。这也是报告里一个值得写下来的观察：**"三级页表遍历"在本实验的启动阶段只执行了一级**。

---

#### 四、补充实验：`-d mmu` 翻译日志

除了 gdb 打断点，QEMU 自带的 `-d mmu` 日志能把**全部**地址翻译流水打出来（源码里 `cpu_helper.c:448/459` 两处 `qemu_log_mask(CPU_LOG_MMU, ...)`），适合先用它锁定"要看的那个地址"，再用条件断点精确停下：

```bash
$LAB2_QEMU -machine virt -nographic -bios default \
    -device loader,file=bin/ucore.img,addr=0x80200000 \
    -monitor null -no-reboot -d mmu -D /tmp/mmu.log
```

实测输出（1016 行）中的关键片段（示例取自某一次构建；其中与内核镜像布局相关的地址会随重新编译变化，判断结论不受影响）：

```
riscv_cpu_tlb_fill ad 80200000 rw 2 mmu_idx 1              ← 第 1 条 S 模式翻译：bare 模式下取指
riscv_cpu_tlb_fill address=80200000 ret 0 physical 0000000080200000 prot 7
riscv_cpu_tlb_fill ad 80206000 rw 1 mmu_idx 1              ← 写 boot_hartid（仍是 bare）
riscv_cpu_tlb_fill ad ffffffffc02000d8 rw 2 mmu_idx 1      ← 第 1 条 Sv39 翻译（jr 之后取 kern_init）
riscv_cpu_tlb_fill address=ffffffffc02000d8 ret 0 physical 0000000080200000 prot 7
```

**判读方法**：`ret` 0=成功 / 1=失败 / 2=PMP 失败；`rw` 0=load、1=store、2=取指（`MMUAccessType`）；`mmu_idx` 是特权级（1=S、3=M）；`physical` 已按页对齐；`prot` 7=R\|W\|X。实测分布：S 模式 454 条、M 模式 54 条；取指 24 条、读 120 条、写 364 条。

**这条日志与 gdb 结论互相印证**：启用分页**之前**，S 模式取指 `0x80200000` 走的是**恒等映射**（即第二节分支 3 的 `VM_1_10_MBARE` 提前返回）；`entry.S` 里 `jr` 跳到虚拟地址之后，**第一条 Sv39 翻译**就把 `0xFFFFFFFFC02000D8` 映射成了 `0x80200000`——正是第三节单步得到的同一条结论。

---

#### 五、细节部分


1. **1GB 大页与"伪造的叶 PTE"。** 启动页表把整个 1GB 空间塞进一个 PTE，所以本实验的启动阶段只用到三级遍历中的第一级；`cpu_helper.c:331-334` 用 `(ppn | (vpn & ((1 << ptshift) - 1))) << 12` 把虚拟地址的低位并回物理地址——这解释了为什么 `-d mmu` 日志里的 `physical` 总是页对齐的。
2. **`mmu_idx` 就是特权级。** `target/riscv/cpu.h:273` 把 `cpu_mmu_index` 重定向到 `riscv_cpu_mmu_index`，而它返回 `env->priv`；这个值还会进入 TB 的 flags（`cpu_get_tb_cpu_state`，`cpu.h:293-303`），也就是说**特权级是翻译块的键的一部分**。用它可以给 `-d mmu` 日志分段：M 模式（OpenSBI）54 条、S 模式（内核）454 条。
3. **PTE 的 A/D 位由 QEMU 软件更新，而且更新失败会导致重新遍历。** `cpu_helper.c:289-329` 在需要时用 `atomic_cmpxchg` 原子地把 `PTE_A`（以及 store 时的 `PTE_D`）写回内存；如果 CAS 失败（说明别的 vCPU 改过），会 `goto restart` **重新走一遍页表**。真实硬件上这一步是 MMU 自动完成的，软件看不到。

---

#### 六、与大模型的交互记录

**有效的部分：**

- 让 AI 先给出"通用 TCG 层 → RISC-V 层"的分层和两条路径的分叉点，实测 `bt` 证实了它的判断（`tlb_fill` 收口、取指走 `get_page_addr_code`、访存走 `store_helper`）——这部分直接变成了第一节的结论。
- 让 AI 逐条列出 `get_physical_address()` 里的关键分支并标注行号，再自己到源码里核对，效率比通读 200 行 C 代码高很多。

**AI 出错 / 需要人工纠正的部分（都已修正）：**

| 问题 | 表现 | 纠正方式 |
|---|---|---|
| **行号是别的版本的** | AI 一开始给的行号来自 QEMU 7.0（我们机器上恰好有它的源码），与 4.1.1 对不上 | 所有行号都回到 `~/qemu-src/qemu-4.1.1/` 里重新 grep 核对，凡引用必标注版本 |
| **条件断点的地址写错** | AI 给的 `kern_init` 地址是 `0xffffffffc02000d6`，实际是 `0xffffffffc02000d8`，断点打不中、gdb 一直卡住 | 改为**每次从 `obj/kernel.sym` 现读**；并意识到该地址会随重新编译变化，不能硬编码 |
| **`print` 的时机不对** | 按 AI 给的顺序在 `cpu_helper.c:254` 处 `print/x ppn`，得到 `0x555555e22d10` 这种宿主栈地址 | 理解"行断点停在语句执行**之前**"，改成在**下一条语句**处设断点再取值（见 3.1 的提示） |
| **QEMU 版本前提缺失** | AI 最初没有指出"这套内核在 QEMU 7.0/8.2 上根本起不来"，导致前期大量时间花在"为什么没有输出"上 | 通过 `-d int`（看异常）与 `-d in_asm`（看翻译块边界）自行定位，最终在源码层面对比 `write_satp()` 确认根因，并自建 QEMU 4.1.1 |

**体会：** AI 在"给出结构化线索、缩小阅读范围"上非常高效，但**它给的行号、地址、时序细节必须逐条到源码里核对**——尤其是跨越多个版本的项目，"版本对不对"比"逻辑对不对"更容易出问题。

---

## 六、实验总结与收获

### 对操作系统的理解

**负责人：** 2412102-（姓名）

>
> 说明：本节的素材由三人共同提供，Buddy / 页表翻译部分由本人整理，First-Fit、Best-Fit 与 `page_init` 部分参考了 A 的实现笔记，SLUB 部分参考了 C 的实现笔记。

---

#### 一、本实验的重要知识点，及其对应的 OS 原理知识点

| # | 本实验的知识点 | 对应的 OS 原理知识点 | 二者的关系与差异 |
|---|---|---|---|
| 1 | **从设备树（DTB）探测物理内存**：`get_memory_base()` / `get_memory_size()` 得到 `[0x80000000, 0x88000000)` | 启动阶段的内存发现（BIOS/UEFI 的 E820 内存图、设备树 `/memory` 节点） | **关系**：都属于"OS 无法假设内存布局，必须由固件/硬件描述告知"这一类问题。**差异**：真实 PC 上内存图里会有**多个可用区间和空洞**（保留给 MMIO、ACPI 等），本实验只处理了一个连续区间；真实的 OS 还要处理内存热插拔、NUMA 节点等。 |
| 2 | **`page_init()` 与 `struct Page` 描述符数组**：把所有物理页建成一个描述符数组，保留 OpenSBI、内核镜像、描述符数组自身，把剩下的完整页交给分配器 | 物理内存管理、**页框（page frame）管理**、`struct page` / PFN 数据库 | **关系**：Linux 的 `struct page`（mem_map）与本实验的 `struct Page` 是同一个思路——用"每页一个描述符"来记录页的状态（引用计数、标志、空闲链表指针）。**差异**：本实验的描述符是**静态数组**、只描述一段连续物理内存；Linux 用 `vmemmap`、支持稀疏内存（sparse memory），描述符字段也丰富得多（映射、反向映射、LRU 链等）。 |
| 3 | **First-Fit / Best-Fit**：按空闲链表的顺序找第一块/最合适的一块，切走所需部分，释放时与相邻空闲块合并 | 连续内存分配算法（首次适配、最佳适配、最坏适配）、**外部碎片** | **关系**：这就是教科书里"动态分区分配"的两种经典策略，本实验用 `pmm_manager` 把它做成了可插拔的。**差异**：教科书通常讨论"分区长度任意"，本实验以**页**为最小单位；而且真实内核很少单独用 First-Fit 管理物理页（它更适合 `kmalloc` 这类小对象分配器，如 SLAB）。 |
| 4 | **Buddy System（伙伴系统）**：空闲块按阶分桶，只能分配 2 的幂大小、且块按自身大小对齐的块；释放时按 `伙伴下标 = 当前下标 XOR (1 << order)` 逐级合并 | **伙伴系统**、外部碎片的可控化、`order`（阶） | **关系**：本实验实现的正是 Linux 物理页分配器（`alloc_pages` / `free_pages` / `free_area[MAX_ORDER]`）的核心算法。**差异**：Linux 在每个阶里再按 **migrate type**（可移动/不可移动/可回收）分成多个链表，以减少碎片；并且用 `zone` 把内存分区（DMA/Normal/HighMem），本实验只有一条链表数组。 |
| 5 | **Buddy 与 First-Fit 的行为差异**：Buddy 只能"整块回收"（`base` 必须按取整后的块大小对齐），First-Fit 可以只还回任意一段 | 分配器的**接口语义与不变式**、内部/外部碎片的权衡 | **关系**：两者都要维护"空闲区不重叠、可被再次分配"这一不变式。**差异**：First-Fit 的碎片是**外部碎片**（空闲总量够但凑不出连续大块）；Buddy 把它转成了**内部碎片**（申请 3 页必占 4 页）——这是一次典型的"用空间浪费换合并效率"的工程折中。本实验里这一点直接体现为：同一个 `alloc_pages(3)`，First-Fit 只扣 3 页、Buddy 扣 4 页。 |
| 6 | **SLUB（选做，C 负责）**：在页级分配之上再实现一层"任意大小对象"的分配器 | **slab 分配器**、内核小对象缓存、对象复用 | **关系**：Linux 的 SLUB 同样是"向页分配器要页，再切成固定大小的对象"的两层结构。**差异**：Linux 的 SLUB 有 per-CPU 缓存、partial slab 链表、对象构造/析构、slab 合并等机制；本实验只保留了"页 → 对象"的核心骨架。它解决的是"页太大"的问题：内核里大量对象只有几十字节，按页分配会浪费一个数量级的空间。 |
| 7 | **启动页表 `boot_page_table_sv39`、页表遍历与 TLB**：`entry.S` 写 `satp` 开启 Sv39，用 1GB 大页把内核映射到高半区；QEMU 在 `get_physical_address()` 里逐级查表，命中后把结果写进 TLB | **虚拟内存、分页、地址翻译、TLB、大页** | **关系**：本实验调试的 `get_physical_address()` 就是"软件实现的 MMU"，它做的事情和真实 CPU 的页表遍历逐位对应：取 `satp` 的根地址 → 逐级用 VPN 索引 → 检查 `PTE_V` / 权限 / 大页对齐 → 拼出物理地址。**差异**：①真实硬件的遍历对软件透明，A/D 位由硬件自动置位，而 QEMU 是用 `atomic_cmpxchg` 在软件里更新的（`cpu_helper.c:289-329`）；②真实 CPU 的 TLB 有 ASID/VMID、有更复杂的替换策略，而 QEMU 的 TLB 是宿主机地址的缓存；③本实验的映射是**静态的、内核一启动就建好**的固定映射，没有缺页中断。 |
| 8 | **`struct pmm_manager` 的策略抽象**：内核只调用 `alloc_pages / free_pages / nr_free_pages`，具体算法由函数指针表提供，通过编译开关切换 | 内核的**可配置性与抽象层**（如 Linux 的 `allocator` 抽象、内核启动参数选分配器） | **关系**：同一个接口下可以替换实现，这是内核工程里非常常见的做法（VFS、调度器 class、`struct file_operations` …）。**差异**：真实内核在运行时（甚至热插拔时）切换分配器要处理并发与已分配内存的迁移，本实验只是编译期换一个函数指针表，简单得多。 |
| 9 | **不变式与断言驱动的调试**：`nr_free_pages()` 必须恒等于各阶链表页数之和；"同阶伙伴不能同时空闲"；"空闲块内不能有别的块头" | 内核**不变式（invariant）**、断言、可测试性设计 | **关系**：内核代码的可靠性建立在一组可检查的不变式上，"每次操作后全量校验"是发现自己 bug 的最有效手段之一。**差异**：真实内核不会在每个操作后跑 O(内存大小) 的校验（性能不允许），而是靠精心设计的数据结构 + `CONFIG_DEBUG_*` 的调试版本（如 Linux 的 `CONFIG_DEBUG_PAGEALLOC`、`slub_debug`）在需要时才打开——本实验的 `check()` 正相当于"打开调试开关"的那一版。 |
| 10 | **用 GDB 调试 QEMU 本身**：在宿主的 C 代码里设条件断点、单步观察地址翻译 | **模拟器/虚拟化**：硬件的行为可以由软件精确复现；VMM/模拟器的分层（TCG、软 MMU） | **关系**：QEMU 用 TCG 把 guest 指令翻译成宿主指令，用 `tlb_fill` + `get_physical_address` 在软件里实现 MMU——这让我们能"看见"平时完全不可观测的硬件动作。**差异**：真实 CPU 的翻译在硅片上完成，无法单步；而模拟器里的行为依赖实现的取舍（例如 QEMU 4.1.1 与 7.0 对 `satp` 写入是否刷 TLB 的处理不同，就直接决定了本 lab 的内核能否启动）。这从反面说明：**"硬件语义"在模拟器里是一份实现，必须核对版本与细节**。 |

---


