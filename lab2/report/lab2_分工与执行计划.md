# Lab2 三人分工与执行计划

> 目标：三人**并行不互等**、工作量接近、**合并冲突最小**；A 的代码与实验工作最重，报告只占约 1h（整体逻辑分析 + 拼接）。
> 工时为 AI 辅助下的粗略估计，仅用于均衡，不是承诺。各模块工时已包含写该模块报告片段（提示词、迭代过程）的时间；"报告"一栏只统计宏观部分。

---

## 0. 一页纸总览

| 成员 | 代码 / 实验工作 | 报告工作 | 预计工时 |
|---|---|---|---|
| **A**（基础设施 + 最少的报告） | ① `page_init()` ★必须最先；② First-Fit 思考题；③ Best-Fit + 切换管理器；⑥ Challenge 思考题；`pmm.c` 钩子；⑤ GDB 的**丙部分**（TLB 差异）；最终集成与 `make grade` | **实验整体逻辑分析** + 基本信息/目的 + 拼接（约 1h） | 代码 7.3h + 报告 1h ≈ **8.3h** |
| **B** | ④ Buddy System（新文件 `buddy_pmm.c/.h`）；⑤ GDB 的**甲部分**（调用路径 + 页表遍历） | 总结·**对操作系统的理解**（约 1h） | 代码 6.8h + 报告 1h ≈ **7.8h** |
| **C** | ⑦ SLUB（新文件 `slub.c/.h`，选做）；⑤ GDB 的**乙部分**（TLB 查找代码） | 总结·**AI 协作经验**（约 1h） | 代码 6.8h + 报告 1h ≈ **7.8h** |

编号 ①–⑦ 对应上一轮列出的 7 项：① page_init、② First-Fit 理解、③ Best-Fit、④ Buddy、⑤ GDB 分支任务、⑥ Challenge 思考题、⑦ SLUB。

> ⑤ 在指导书中没有标注选做，这里按必做安排，并拆成三份：B 做调用路径与页表遍历，C 做 TLB 查找代码，A 做 TLB 差异。各自在自己机器上编译调试版 QEMU，互不依赖。建议向助教确认。
> 若时间紧，优先舍弃 ⑦ 和 ⑥（二者均为选做加分项）。

---

## 1. 先后关系：什么必须先写

```
                ┌─────────────── 其余全部并行，互不等待 ───────────────┐
 ★ M0  A: ① page_init + pmm.c 钩子   ← 唯一的"必须最先"（约 1.5h）
        │
        ├─→ B: ④ Buddy 能"跑起来"测试（之前可写提示词、生成代码、编译，但链接不过）
        ├─→ C: ⑦ SLUB 能"跑起来"测试（同上）
        └─→ A/B/C 的 ⑤：需要 ucore 能构建出来（编译 QEMU 本身不依赖，可提前）
 M1  A: ③ Best-Fit + 切换 init_pmm_manager（B、C 不依赖它）
```

| 依赖 | 原因 | 如何避免等待 |
|---|---|---|
| ① → 所有"需要运行内核"的工作 | `pmm_init()` 先调 `page_init()` 再调检查函数；没有它连链接都过不了 | B、C 在 M0 之前先做：写提示词、后台编译调试版 QEMU、读资料、生成并**只编译**代码。M0 到了再运行 |
| ② → ③ | 指导书要求参考 First-Fit 设计 Best-Fit 提示词 | 都在 A 手里，按顺序做即可 |
| ④/⑦ 内部：提示词①（生成实现）→ 提示词②（生成测试） | 测试是针对第一份提示词生成的实现设计的 | 同一个人顺序完成 |
| ⑦ 依赖页级分配 | SLUB 第一层调用 `alloc_pages/free_pages` | 只依赖这套 API，不依赖具体是 First-Fit 还是 Best-Fit，所以 M0 之后即可开始 |
| 报告最后整合 | 需要各人的片段 | 片段文件分开写，A 只做拼接，见第 5 节 |

**M0 的最低要求**：`make` 能链接成功，`[Test 1] Page Init` 逻辑通过，`pmm.c` 钩子就位。此时默认管理器仍是原来的 `default_pmm_manager`，B、C 的工作不受影响。

---

## 2. 防冲突规则（全员必读）

### 2.1 文件所有权（单写者原则）

| 文件 / 目录 | 唯一修改者 | 说明 |
|---|---|---|
| `kern/mm/pmm.c` | **A** | 包括 `page_init`、管理器选择、SLUB 钩子 |
| `kern/mm/best_fit_pmm.c` | **A** | 两个检查函数不得改动 |
| `kern/mm/buddy_pmm.c`、`buddy_pmm.h`（新建） | **B** | 测试函数也放在这里的 `.check` 里 |
| `kern/mm/slub.c`、`slub.h`（新建） | **C** | |
| `report/` 下各片段 | 各自负责人 | 见第 5 节 |
| `report.md`（最终报告） | **A** | |
| `Makefile`、`tools/*`、`memlayout.h`、`pmm.h`、`default_pmm.c`、`kern/init/*` | **谁都不改** | 见 2.3 |

### 2.2 `pmm.c` 单点钩子（A 在 M0 一次性写好，B/C 不碰 `pmm.c`）

A 在 `pmm.c` 里按下面的结构加入**默认关闭**的编译开关，这样 B、C 的头文件即使还不存在，默认构建也不会出错：

```c
// 追加在原有 #include 之后（不要再写一次 #include <pmm.h>）
#ifdef PMM_USE_BUDDY
#include <buddy_pmm.h>        // B 提供：extern const struct pmm_manager buddy_pmm_manager;
#endif
#ifdef LAB2_SLUB
#include <slub.h>             // C 提供：void slub_init(void); void slub_check(void);
#endif

static void init_pmm_manager(void) {
#if defined(PMM_USE_BUDDY)
    pmm_manager = &buddy_pmm_manager;
#else
    pmm_manager = &default_pmm_manager;      // M1：A 改成 &best_fit_pmm_manager
#endif
    cprintf("memory management: %s\n", pmm_manager->name);
    pmm_manager->init();
}

// pmm_init() 里，check_alloc_page() 之后追加：
#ifdef LAB2_SLUB
    slub_init();
    slub_check();
#endif
```

使用方式（`Makefile` 里 `CFLAGS` 已包含 `$(DEFS)`，无需修改 Makefile）：

| 谁 | 命令 | 作用 |
|---|---|---|
| B 测 Buddy | `make clean && make qemu DEFS="-DPMM_USE_BUDDY"` | 把管理器切到 Buddy，运行它的 `check` |
| C 测 SLUB | `make clean && make qemu DEFS="-DLAB2_SLUB"` | 在页分配器之上运行 SLUB 测试 |
| 最终提交 | `make qemu` / `make grade` | 默认 Best-Fit，**不得**留成 Buddy |

> 为什么最终必须是 Best-Fit：`tools/test_lab2.c` 的 Test 2 检查 `pmm_manager == &best_fit_pmm_manager`，否则 `make grade` 扣 10 分。

### 2.3 其他约束

- **不要改共享头文件**（`memlayout.h`、`pmm.h`）。Buddy 需要记录阶数时，复用 `Page.property` / `flags`，或用模块内私有数组。确实要改，找 A 统一改。
- **不要修改 `Makefile`**：新增的 `.c` 放进 `kern/mm/` 会被通配符自动编译；而且 `tools/inject.py` 要求 Makefile 里不能出现 `kern/test`。
- 所有**非 static** 符号加模块前缀：Buddy 用 `buddy_`，SLUB 用 `slub_`。宏（如 `free_list`）只写在 `.c` 里，不写进头文件，避免互相冲突。
- 代码需通过 `-Wall -Werror`。AI 生成的代码常有未声明函数、格式串类型不匹配等问题，先本地 `make` 通过再提交。
- Git：每人一个分支（`feat/A-pmm`、`feat/B-buddy`、`feat/C-slub`），只提交自己名下的文件，A 负责合入 `main`。M0 合入后 B、C 立即 `git merge main`。
- `YOUR CODE` 注释：A 的两处标记保留 `lab2` 字样并替换为学号。三人小组写谁的学号，指导书没说明，建议问助教。

---

## 3. 各成员详细任务

### 成员 A：基础设施 + 报告

#### 代码 / 实验工作（约 7.3h）

| 顺序 | 任务 | 完成标准 | 备注 |
|---|---|---|---|
| 1 ★ | **① `page_init()`**（`pmm.c`，标记 `function1`）+ 第 2.2 节钩子；同时**后台开始编译**调试版 QEMU | `make` 链接通过；输出物理内存范围；`[Test 1] Page Init` 通过 | **必须最先**，推送 M0 |
| 2 | **② First-Fit 思考题**：读 `default_init / default_init_memmap / default_alloc_pages / default_free_pages` | 产出文字：初始化空闲页、分配连续页、回收、合并相邻块；回答"first-fit 是否有改进空间" | 无代码；为 ③ 的提示词做准备 |
| 3 | **③ Best-Fit**（`best_fit_pmm.c`，标记 `function2-2`）+ 把 `init_pmm_manager()` 切换为 `best_fit_pmm_manager` | `check_alloc_page() succeeded!`，`[Test 2] Best-Fit: PASS` | 推送 M1。回答"Best-Fit 是否有改进空间" |
| 4 | **⑥ Challenge 思考题**：OS 无法提前知道可用物理内存范围时如何获取 | 一段文字回答 | 随时可做，可填补等待时间 |
| 5 | **⑤ 丙部分**：调试要求④：对比**未开启分页**（`kern_entry` 开头、写 `satp` 之前的访存/取指）与**开启分页之后**的访存在 QEMU 中的调用路径，说明 QEMU 的 TLB 与真实 CPU 的 TLB 在逻辑上有什么区别 | 有断点记录和文字说明 | 实验本身不依赖 C 的结论；写结论时可参考 C 的片段 |
| 6 | **集成**：合入 B、C 的分支；去掉 `LAB2_SLUB` 守卫使 SLUB 默认运行；跑 `make qemu` 与 `make grade` | `make grade` 总分 20/20；截图 | M4 |

`page_init()` 要点（指导书约束）：
- 必须区分虚拟地址、物理地址、物理页号和 `Page` 描述符地址。
- 设备树信息无效时要 `panic` 终止；没有可用完整页时不得调用 `init_memmap()`。
- 描述符数组覆盖 `[nbase, npage)`，起点在 `end` 之后并按页对齐。先把所有页标成保留，再只把完整的空闲页交给 `init_memmap()`。
- `va_pa_offset` 要在第一次用 `PADDR` 之前设置。

#### 报告工作（约 1h，只含宏观部分）

- 撰写：基本信息、小组分工、实验目的、**实验整体逻辑分析**（见第 5.2 节，约 0.5h）。
- 把各片段按模板顺序拼成 `report.md`，汇总环境表（B、C 各给一行），贴上测试截图（截图随 M4 集成一起完成）。约 0.5h。
- 自己模块的片段（①、③ 的提示词与迭代过程，② 与 ⑥ 的回答，⑤ 丙）已计入上面的代码工时，不再单算。
- **不写**"实验总结"：知识点对应由 B 写，AI 协作经验由 C 写。

---

### 成员 B：Buddy System + GDB 甲部分

#### 代码 / 实验工作（约 6.8h）

| 阶段 | 任务 | 完成标准 |
|---|---|---|
| M0 之前（不需运行内核） | 读参考资料（coolshell 的伙伴分配器）；设计 **Buddy 提示词①**（生成实现并接入 `pmm_manager`）；**后台开始编译**带 `--enable-debug` 的 QEMU 4.1.1（不要 `make install`） | 提示词定稿；QEMU 在后台编译 |
| M0 之后 | 让 AI 生成 `buddy_pmm.c/.h`，导出 `buddy_pmm_manager`；设计 **提示词②**（生成测试函数，写进 `.check`）；`make qemu DEFS="-DPMM_USE_BUDDY"` 调通 | 输出 `check_alloc_page() succeeded!` 且管理器名为 buddy；测试覆盖核心行为与边界 |
| 之后 | **⑤ 甲部分**：调试要求①②：给出访存虚拟地址如何被 QEMU 翻译成物理地址的**关键调用路径与关键分支**；**单步调试页表遍历**并解释流程 | 有可复现的断点/条件断点记录和文字说明 |

Buddy 测试至少应覆盖：分配大小向上取整到 2 的幂、拆分与合并（伙伴合并）、释放后可重新分配、分配失败返回 `NULL`、`nr_free_pages` 的一致性、边界（最小块、最大块、非 2 的幂页数）。

> ⑤ 的起点（以你们实际的 QEMU 4.1.1 源码为准）：`target/riscv/cpu_helper.c` 里与 `tlb_fill`、`get_physical_address` 相关的函数。可以先在 QEMU 里设条件断点，只在目标地址被翻译时停下，这是指导书"思考"一节推荐的做法。

#### 报告工作

写入 `report/B_buddy.md`、`report/B_gdb_part1.md`、`report/B_summary.md`：
- Buddy：负责人、函数签名、两份**最终提示词**、**迭代过程**（每次出现的 bug 与改法）、测试覆盖说明（为什么能有效检验）。
- ⑤ 甲：调用路径、关键分支、单步过程、有趣细节、与大模型交互的记录。
- **总结·对操作系统的理解**（约 1h）：列出本实验的重要知识点及对应的 OS 原理知识点（含义、关系、差异）；列出 OS 原理中重要、但本实验没有对应上的知识点。可向 A、C 收集各自觉得重要的点。
- 一行"AI 工具 / 底层模型"信息，供 A 填入环境表。

---

### 成员 C：SLUB + GDB 乙部分

#### 代码 / 实验工作（约 6.8h）

| 阶段 | 任务 | 完成标准 |
|---|---|---|
| M0 之前（不需运行内核） | 读 Linux SLUB 资料，确定简化设计；设计 **SLUB 提示词①**（两层：页级 + 任意大小对象）；**后台开始编译**带调试信息的 QEMU 4.1.1 | 提示词定稿；QEMU 在后台编译 |
| M0 之后 | 让 AI 生成 `slub.c/.h`，导出 `slub_init()`、`slub_check()` 以及分配/释放接口；设计 **提示词②**（生成测试）；`make qemu DEFS="-DLAB2_SLUB"` 调通 | `slub_check()` 通过；不同大小对象的分配与释放均正确 |
| 之后 | **⑤ 乙部分**：调试要求③：找到 QEMU 模拟 **TLB 查找**的 C 代码，并通过调试说明细节（要求④ 的 TLB 差异由 A 负责） | 有断点记录和文字说明 |

SLUB 只通过 `alloc_pages/free_pages` 取页，不要依赖具体是哪种页分配器，这样不管 A 何时切换到 Best-Fit，都不受影响。

测试至少应覆盖：多种大小（含很小和接近一页）、同一大小反复分配与释放后复用、跨页增长、释放后的复用、非法释放或释放 `NULL`、与页分配器的页数守恒。

#### 报告工作

写入 `report/C_slub.md`、`report/C_gdb_part2.md`、`report/C_ai_experience.md`，前两个结构同 B。
- **总结·AI 协作经验**（约 1h）：汇总三人在提示词设计、AI 生成代码的 bug 与修复、调试中使用大模型等方面的实际收获，可向 A、B 收集。

---

## 4. 时间线

截止日期未知，用相对天数表示，**最后一天留给集成与报告**。

| 阶段 | A | B | C |
|---|---|---|---|
| **D1 前 2h** | ① `page_init()` + 钩子 → **★M0 推送**；后台编译 QEMU | Buddy 提示词①；后台编译 QEMU | SLUB 提示词①；后台编译 QEMU |
| **D1 后段** | ② 读 First-Fit 并写答案 | 合入 M0；生成并调试 Buddy | 合入 M0；生成并调试 SLUB |
| **D2** | ③ Best-Fit + 切换 → **M1 推送**；⑥ | Buddy 提示词② + 测试迭代 → **M2 推送** | SLUB 提示词② + 测试迭代 → **M3 推送** |
| **D2–D3** | ⑤ 丙（调试 + 记录）；**整体逻辑分析**初稿 | ⑤ 甲（调试 + 记录）；总结·对操作系统的理解 | ⑤ 乙（调试 + 记录）；总结·AI 协作经验 |
| **D3 末** | **提交自己的报告片段** | **提交报告片段** | **提交报告片段** |
| **D4（最后一天）** | **M4**：合入 B、C，去掉 SLUB 守卫，`make grade` 20/20，截图；拼接 `report.md`；全员过一遍检查清单 | 协助复现问题 | 协助复现问题 |

里程碑：

| 里程碑 | 内容 | 谁 |
|---|---|---|
| ★ M0 | `page_init` + 钩子，默认仍 First-Fit | A |
| M1 | Best-Fit 完成并切换为默认 | A |
| M2 | Buddy 完成（`DEFS=-DPMM_USE_BUDDY` 下通过） | B |
| M3 | SLUB 完成（`DEFS=-DLAB2_SLUB` 下通过） | C |
| M4 | 集成 + `make grade` 20/20 + 报告整合 | A |

---

## 5. 实验报告：结构、拆分与整合

### 5.1 片段文件与整合方式

为避免多人同时改一个 `report.md` 产生冲突，**每人只写自己的片段文件**，A 按模板顺序拼接：

```
report/
├── A_head.md              # A：基本信息、目的、环境、整体逻辑分析、测试与验证
├── A_page_init.md         # A：① 的提示词与迭代过程
├── A_first_fit.md         # A：② 思考题
├── A_best_fit.md          # A：③ 的提示词、迭代过程、改进空间
├── A_challenge_mem.md     # A：⑥ 思考题
├── A_gdb_part3.md         # A：⑤ 丙
├── B_buddy.md             # B：④
├── B_gdb_part1.md         # B：⑤ 甲
├── B_summary.md           # B：总结·对操作系统的理解
├── C_slub.md              # C：⑦
├── C_gdb_part2.md         # C：⑤ 乙
├── C_ai_experience.md     # C：总结·AI 协作经验
└── images/                # 截图，文件名加前缀：A_xxx.png / B_xxx.png / C_xxx.png
```

- 片段内部的标题层级**直接按模板**写（功能模块用 `###`，其下用 `####` / `#####`），A 拼接时不用改层级。
- 每个片段都包含：负责人、最终提示词、迭代过程（遇到的问题 + 解决策略）。
- B、C 把自己的"AI 工具 / 底层模型"各写一行放在片段开头，A 汇总进环境表。
- 提示词用 ```` ````markdown ```` 四个反引号包裹（模板如此），避免内部代码块破坏格式。

### 5.2 A 负责的"实验整体逻辑分析"写作提纲

用自己的话写，下面只是要点，不是成稿（指导书要求说明自己的理解）。

**主线（对应模板"逻辑主线"）**
- 本章围绕"让内核能发现、组织并分配物理内存"展开。
- 实现链：`pmm_init() → init_pmm_manager() → page_init() → init_memmap() → alloc_pages()/free_pages()`。

**逐步实现及原因（对应模板"功能的逐步实现"）**
1. **启动页表与物理内存探测**（`entry.S` 保存 hartid 与 dtb，开启 Sv39；`dtb_init` 读出内存起点和大小）：不知道内存范围就无法管理内存，所以最先。
2. **`page_init()`**：把探测结果转成 `Page` 描述符数组，保留 OpenSBI、内核、描述符数组，把剩余完整页交给管理器。它是所有分配算法的共同前提。
3. **First-Fit（读懂）**：作为基线，理解 `pmm_manager` 接口和空闲链表如何工作。
4. **Best-Fit**：在同一接口下换一种选块策略，验证框架可插拔，并把管理器切换过去。
5. **Buddy System**：另一类页级算法，用 2 的幂块换取更快的拆分与合并。
6. **SLUB（选做）**：在页级分配之上增加任意大小对象的第二层，解决"页太大"的问题。
7. **GDB 调试 QEMU**：从软件层面观察硬件完成的地址翻译与 TLB，把"启动页表"与"虚拟内存访问"连起来。

**模板小问题**：模板里"三、实验整体逻辑分析"下的小节编号写成了 `2.1 / 2.2`，A 整合时顺手改成 `3.1 / 3.2`。

### 5.3 模板各节对应表

| 模板章节 | 内容来源 |
|---|---|
| 基本信息 / 小组分工 / 目的 / 环境 | A（B、C 提供各自的 AI 工具行） |
| 整体逻辑分析 | A |
| 功能模块：page_init | A |
| 功能模块：Best-Fit | A |
| 功能模块：Buddy | B |
| 练习：First-Fit 理解 | A |
| 练习：GDB 调试 QEMU | B（甲）+ C（乙）+ A（丙），A 只拼接 |
| Challenge：硬件内存范围 | A |
| Challenge：SLUB | C |
| 测试与验证 | A（`make qemu` 多张 + `make grade` 一张） |
| 总结·对操作系统的理解 | B（A、C 提供素材） |
| 总结·AI 协作经验 | C（A、B 提供素材） |

可直接粘贴到报告的"小组分工"表：

| 成员 | 负责的练习/模块 |
|---|---|
| A | 物理内存探测与 `page_init`；First-Fit 理解；Best-Fit；Challenge 思考题；GDB 调试 QEMU 丙（TLB 差异）；集成测试；报告整体逻辑与拼接 |
| B | Buddy System；GDB 调试 QEMU 甲（调用路径与页表遍历）；报告总结·对操作系统的理解 |
| C | SLUB（Challenge）；GDB 调试 QEMU 乙（TLB 查找代码）；报告总结·AI 协作经验 |

---

## 6. 提交前检查清单

- [ ] `make grade` 总分 20/20（Test 1 与 Test 2 都 PASS）
- [ ] 最终默认管理器是 `best_fit_pmm_manager`；没有任何 `-D` 开关也能正常构建
- [ ] `LAB2_SLUB` 守卫已在 M4 去掉，且 SLUB 测试在默认构建下通过
- [ ] `Makefile`、`tools/*`、共享头文件未被改动；`pmm.c` 没有重复的 `#include <pmm.h>`
- [ ] 两处 `lab2` / `YOUR CODE` 注释保留，并替换为学号
- [ ] 三份提示词材料齐全：page_init、Best-Fit、Buddy×2（实现、测试）、SLUB×2
- [ ] 报告含：整体逻辑、每个功能的核心函数理解、每个练习的 spec 与 prompt、AI 生成代码的 bug 及解决、知识点对应与未对应的知识点
- [ ] ⑤ 的六条调试要求都有对应内容（甲：①②，乙：③，丙：④，⑤⑥ 由三人各自记录）；② ③ 的"改进空间"、⑥ 的回答、Buddy/SLUB 的测试覆盖说明都已写
- [ ] 报告（markdown）放在 lab2 目录，代码与报告已 push 到 gitee / github
