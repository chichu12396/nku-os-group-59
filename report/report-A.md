### 功能模块：[page_init()]

**负责人：** [2411033-季艾佳]

#### 模块功能描述

**需要实现/修改的函数：**

```c
static void page_init(void);
```

**功能说明：**

- `page_init()` 负责物理内存管理的初始化，为后续页面分配和回收建立基础。它读取设备树提供的物理内存起点和大小，设置虚实地址转换偏移，并结合框架的内存上界确定可管理的完整页面范围。随后，在内核镜像结束位置之后按页对齐放置 `Page` 描述符数组，为每个可管理物理页记录状态。

- 初始化时，函数先将所有页面标记为保留，再将描述符数组之后剩余的完整页面登记为空闲页，确保 OpenSBI、内核和描述符数组占用的页面不会被分配。对于设备树信息无效、地址计算溢出或描述符空间不足等情况，函数调用 `panic()` 终止；如果数组能够放下但没有剩余完整页，则不登记空闲区。

- 该函数由 `pmm_init()` 在物理内存管理器初始化后调用，通过 `get_memory_base()` 和 `get_memory_size()` 获取内存信息，借助 `PADDR()`、`pa2page()` 完成地址与描述符之间的转换，最后通过 `init_memmap()` 将空闲页交给当前选中的分配器。因此，它不依赖具体的分配策略，可以为 First-Fit、Best-Fit 和 Buddy 等页分配器提供统一的初始化基础。

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

---

### 练习：[理解 First-Fit 连续物理内存分配算法]

**负责人：** [2411033-季艾佳]

#### 1. 空闲页的组织方式

实验使用 `free_area` 管理空闲页：

```c
static free_area_t free_area;

#define free_list (free_area.free_list)
#define nr_free   (free_area.nr_free)
```

| 成员或标志 | 含义 |
|---|---|
| `free_list` | 空闲块链表的头节点 |
| `nr_free` | 所有空闲块包含的**总页数** |
| 首页的 `property` | **当前空闲块**包含的页数 |
| `PageProperty` | 标记该页是空闲块首页 |

每个物理页都有一个 `Page` 描述符。代码将**空闲块首页的 `page_link`** 挂入链表，并按地址从低到高排列。

```text
free_list ⇄ A块首页 ⇄ B块首页 ⇄ free_list
             3页        5页

nr_free = 3 + 5 = 8
```

#### 2. 初始化空闲页

**第一步：初始化管理结构。**

利用`default_init()` 建立空链表，将已登记的空闲页总数设为零：

```c
list_init(&free_list);
nr_free = 0;
```

**第二步：登记可用页面。**

在`page_init()` 确定可用范围后，通过 `init_memmap()` 调用 `default_init_memmap(base, n)`来将可用页面添加到空闲链表中。

代码先检查并初始化这段页的描述符：

```c
for (; p != base + n; p++) {
    assert(PageReserved(p));
    p->flags = p->property = 0;
    set_page_ref(p, 0);
}
```

随后，用首页记录整个空闲块，并增加空闲页总数：

```c
base->property = n;
SetPageProperty(base);
nr_free += n;
```

最后，代码将首页按地址顺序插入链表。登记完成后，**这段页面即可参与后续分配**。

#### 3. 分配连续物理页

使用`default_alloc_pages(n)`来将可用页面分配给需要的地方。首先检查申请量：

```c
assert(n > 0);

if (n > nr_free) {
    return NULL;
}
```

总页数充足时，代码从头遍历链表，选择**第一个足够大的块**：

```c
while ((le = list_next(le)) != &free_list) {
    struct Page *p = le2page(le, page_link);

    if (p->property >= n) {
        page = p;
        break;
    }
}
```

这就是 **First-Fit（首次适应）** 的选块规则。

```text
按地址排列：A块3页 → B块8页 → C块5页
申请5页：  跳过A → 选中B，停止查找
```

选中后，代码摘下原节点。块大小超过申请量时，将剩余部分挂回原位置：

```c
struct Page *p = page + n;
p->property = page->property - n;
SetPageProperty(p);
list_add(prev, &(p->page_link));
```

例如，从 8 页块中申请 5 页：

```text
[ 分配出去的5页 ][ 剩余空闲的3页 ]
 ↑               ↑
 page            page + 5
```

最后，代码扣减空闲页总数，清除分配块首页的空闲块标志，并返回描述符指针：

```c
nr_free -= n;
ClearPageProperty(page);
return page;
```

另外**分配成功需要存在足够大的连续块。** 例如，两个块分别有 3 页和 5 页，总量

---




### 功能模块：Best-Fit 连续物理内存分配

**负责人：** [2411033-季艾佳]

#### 模块功能描述

**需要实现/修改的函数：**

```c
// kern/mm/best_fit_pmm.c：实现
static void best_fit_init(void);
static void best_fit_init_memmap(struct Page *base, size_t n);
static struct Page *best_fit_alloc_pages(size_t n);
static void best_fit_free_pages(struct Page *base, size_t n);
static size_t best_fit_nr_free_pages(void);

```

同时定义 `best_fit_pmm_manager`，将上述函数及已有的 `best_fit_check()` 注册到框架中。

**功能说明：**

- **模块作用**

  Best-Fit 负责连续物理页的分配与回收。申请页面时，代码遍历空闲链表，选择满足申请量的最小空闲块，尽量减少本次分配的剩余空间。

- **空闲页初始化**

  `best_fit_init()` 初始化链表和计数。`best_fit_init_memmap()` 接收 `page_init()` 提供的可用页，初始化描述符，并将块首页按地址顺序插入链表。

- **分配与拆分**

  `best_fit_alloc_pages()` 比较各个合适块的大小，更新候选块。遇到大小恰好等于申请量的块时结束查找。选中块较大时，代码分配前面的页面，将剩余部分作为空闲块挂回链表。

- **释放与合并**

  `best_fit_free_pages()` 将释放区域按地址插入链表，再合并前后物理连续的空闲块。`nr_free` 只增加本次释放的页数，合并时保持原值。

- **与其他模块的交互**

  内核通过 `pmm_manager` 调用分配器。完成注册后，`init_pmm_manager()` 的默认分支选择 Best-Fit。
  后续 `alloc_pages()`、`free_pages()` 和分配器自检均通过对应回调执行。

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

---

#### Best-Fit 的改进空间

| 方向 | 当前实现 | 改进思路 |
|---|---|---|
| **查找效率** | 当前最坏情况下遍历全部空闲块，时间复杂度为 `O(k)` | 可以增加按块大小组织的辅助索引，加快最小合适块查找 |
| **碎片控制** | 每次选择最小合适块，可能留下较小的剩余块，同样造成碎片化问题 | 结合不同申请序列，比较碎片数量、最大空闲块及分配成功率，尝试不同算法混用 |
| **代码维护** | 初始化与释放包含重复的有序插入逻辑 | 提取内部辅助函数，统一维护插入操作 |

但是，增加辅助索引需要额外内存和更新操作。现在并不能证明当前的实现不好，**优化时应同时考虑查找开销、维护成本和实际碎片情况**。

### Challenge：获取硬件可用物理内存范围

**负责人：** [2411033-季艾佳]

本实验通过**固件传入的设备树 DTB**获取物理内存信息，使内核能够在启动时确定当前硬件的内存范围。

#### 1. **接收设备树地址**

   OpenSBI 启动内核时，通过 `a1` 寄存器传入设备树的物理地址。`entry.S` 将它保存到 `boot_dtb`：

   ```asm
   la t0, boot_dtb
   sd a1, 0(t0)
   ```

#### 2. **解析内存起点和大小**

   `dtb_init()` 将设备树物理地址转换为内核虚拟地址，检查设备树格式，再查找内存节点的 `reg` 属性：

   ```c
   uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
   ```

   解析代码从该属性中读取物理内存起点和大小：

   ```c
   *mem_base = fdt64_to_cpu(reg_data[0]);
   *mem_size = fdt64_to_cpu(reg_data[1]);
   ```

#### 3. **确定可分配区域**

   `page_init()` 通过接口获取解析结果：

   ```c
   uint64_t mem_base = get_memory_base();
   uint64_t mem_size = get_memory_size();
   ```

   本实验获得的内存起点为 `0x80000000`，大小为 128 MiB。代码在该范围内保留 OpenSBI、内核和页描述符数组占用的空间，再将剩余完整页交给分配器。

因此，**内核可以通过启动时接收并解析设备树，获取当前硬件的物理内存范围，再确定其中可供分配的页面。**
#### 4. **其他主流操作系统的处理方式**

主流操作系统也通过**固件或引导程序提供的内存布局**获取物理内存范围，具体接口取决于硬件平台和启动方式。

**Linux**

- **传统 x86 BIOS 启动**：启动阶段通过 BIOS E820 接口获取内存映射，记录各区域的起点、长度和类型，供内核初始化使用。
- **UEFI 启动**：启动代码通过 `GetMemoryMap()` 获取内存描述符，区分普通内存、固件运行时内存和保留区域。
- **使用设备树的平台**：内核解析 DTB 中的内存节点，确定 RAM 的位置和大小。这与本实验的实现思路相近。

**Windows**

在 UEFI 启动环境中，Windows 的启动加载阶段依据固件内存映射获取物理内存布局。UEFI 通过 `GetMemoryMap()` 提供各区域的地址、页数和类型，供操作系统识别可用内存，并保留固件运行时需要的区域。

这些实现与本实验具有相同的基本流程：
即**固件或引导程序提供内存布局->操作系统读取地址范围和区域属性->保留已占用区域，将可用页面纳入内存管理**



### 练习：对比分页前后的访存路径，理解 QEMU 软件 TLB 与真实 CPU TLB 的逻辑区别

**负责人：** [学号-姓名]

#### 1. 探究目标与方法

本实验重点探究：

> **QEMU 在 Bare 模式和 Sv39 模式下如何处理访存，以及其软件 TLB 与真实 CPU 的地址翻译 TLB 有什么逻辑区别。**

实验选择两条写入指令进行对比，保持访问类型一致：

| 情形 | 被调试的指令 | 写入地址 |
|---|---|---|
| **S 模式，Bare** | `kern_entry` 中的 `sd a0,0(t0)` | `0x80206000` |
| **S 模式，Sv39** | `kern_init` 中的 `sd ra,8(sp)` | `0xffffffffc0204ff8` |

调试采用两个 GDB：RISC-V GDB 控制 ucore 指令执行，普通 GDB 观察 QEMU 的地址处理和软件 TLB 填充过程。

主要观察位置为：
**riscv_cpu_tlb_fill()->get_physical_address()->tlb_set_page()**

#### 2. Bare 模式：地址直接对应，仍然填充软件 TLB

**探究内容：** 未开启虚拟地址翻译时，QEMU 是否仍使用软件 TLB。

实验在 `riscv_cpu_tlb_fill` 设置 S 模式写访问断点：

```gdb
break riscv_cpu_tlb_fill if mmu_idx == 1 && access_type == MMU_DATA_STORE
```

执行 `kern_entry` 中的第一条 `sd` 后，断点捕获对 `0x80206000` 的写入。此时 `satp=0`，处于 Bare 模式。

进入 `get_physical_address()` 后，代码采用直接地址处理：

```c
case VM_1_10_MBARE:
    *physical = addr;
    *prot = PAGE_READ | PAGE_WRITE | PAGE_EXEC;
    return TRANSLATE_SUCCESS;
```

执行赋值后，调试结果为：

![Bare 模式地址相等](<./images/Bare 模式地址相等.png>)

返回 `riscv_cpu_tlb_fill()` 后，日志记录代码继续执行：

```text
472    tlb_set_page(cs, address & TARGET_PAGE_MASK, pa & TARGET_PAGE_MASK,
474    return true;
```

调用前的输出对应：

```text
address = 0x80206000
pa      = 0x80206000
satp    = 0x0
```

**结果说明：Bare 模式省去了页表翻译，但 QEMU 仍将处理结果填入软件 TLB。** 软件 TLB 的作用范围因此超出了客户机虚拟页到物理页的翻译。

#### 3. 同页再次访问：复用已有的软件 TLB 映射

**探究内容：** 第一次填充后，同页访问是否再次进入填充路径。

实验继续执行第二条写入指令：

```asm
0x80200014: sd a1,0(t0)
```

两次写入地址分别为：

```text
第一次：0x80206000
第二次：0x80206008
```

两者属于同一个 4 KiB 页：

```text
0x80206000 >> 12 = 0x80206
0x80206008 >> 12 = 0x80206
```

第二次写入完成后，PC 到达 `0x80200018`，期间终端 2 的填充断点未再次触发。

![同页第二次写入](<./images/同页第二次写入.png>)

**结果说明：** 在两次访问之间没有执行 TLB 刷新的情况下，第二次同页写入完成且未再次进入填充路径，与复用已有软件 TLB 映射的行为一致。

#### 4. Sv39 模式：先查询页表，再填充软件 TLB

**探究内容：** 开启分页后，同类写访问在填充 TLB 之前增加了哪些处理。

实验连续执行启动代码，到达高地址 `kern_init` 后，选择栈写入指令：

```asm
0xffffffffc02000ee: sd ra,8(sp)
```

计算有效地址：

```gdb
p/x $sp + 8
```

结果为：

![分页后的实际指令](<./images/分页后的实际指令.png>)

在 QEMU 断点处检查访问参数和分页状态：

```gdb
p/x address
p access_type
p/x $e->satp
p/x ($e->satp >> 60)
```

结果为：
其中模式字段为 8，表明本次访问使用 **Sv39 地址翻译**。

![Sv39 状态](<./images/Sv39 状态.png>)

进入 `get_physical_address()`，执行到页表项读取完成后，得到：

![页表查询结果](<./images/页表查询结果.png>)

本实验的启动页表在根级设置了大页叶子项，因此本次查询在第一轮就取得映射。

函数返回后的日志记录：

```text
Value returned is $13 = 0
$14 = 0xffffffffc0204ff8
$15 = 0x80204000
```

其中，返回值 0 表示翻译成功，`0x80204000` 是物理页基址。加上原地址的页内偏移，可得实际写入地址：

```text
0x80204000 + 0xff8 = 0x80204ff8
```

随后，代码同样执行 `tlb_set_page()` 并返回成功。

**结果说明：Sv39 模式在软件 TLB 填充前增加了页表查询和权限等检查，成功后仍使用同一套软件 TLB 填充接口。**

#### 5. 调用路径与软件 TLB 保存的信息

日志中的写访问调用栈包含：
**code_gen_buffer->helper_le_stq_mmu->store_helper->tlb_fill->riscv_cpu_tlb_fill**

本次两种模式下，实验都观察到 `riscv_cpu_tlb_fill()` 调用 `get_physical_address()`，成功后执行 `tlb_set_page()`。**区别集中在地址处理函数内部：Bare 直接对应地址，Sv39 查询页表取得映射。**

为了说明软件 TLB 的用途，实验进一步查看 `CPUTLBEntry` 定义：

```c
target_ulong addr_read;
target_ulong addr_write;
target_ulong addr_code;
uintptr_t addend;
```

![软件 TLB 结构](<./images/软件 TLB 结构.png>)

前三个字段保存读、写和取指访问的地址标记及相关标志。源码对 `addend` 的注释为：

```c
/* Addend to virtual address to get host address. */
```

对于适用的 RAM 快速访问路径，其地址计算可以概括为：

```text
宿主机地址 = 客户机虚拟地址 + addend
```

**这说明 QEMU 软件 TLB 还保存了定位宿主机内存所需的信息。** 它服务于模拟器执行客户机访存指令的整个过程。

#### 6. QEMU 软件 TLB 与真实 CPU TLB 的逻辑区别

| 对比内容 | 真实 CPU 的地址翻译 TLB | 本实验中的 QEMU 软件 TLB |
|---|---|---|
| **主要用途** | 加速虚拟地址到物理地址的翻译及权限检查 | 加速客户机访存，包括地址翻译结果与宿主机内存定位 |
| **Bare 模式** | S 模式 Bare 访问直接采用物理地址，省去分页翻译 | 直接取得物理地址后，仍调用软件 TLB 填充接口 |
| **缓存信息** | 虚拟页与物理页的映射、权限等属性 | 读、写、取指标记，以及计算宿主机地址的 `addend` 等 |
| **分页开启后的共同点** | 利用缓存映射减少重复翻译 | 利用缓存结果减少重复的翻译与访存处理 |

**本次实验表明，QEMU 软件 TLB 的逻辑角色覆盖了模拟器的访存加速。** Bare 与 Sv39 两种模式都会使用它；分页是否开启，主要改变填充之前取得物理地址的过程。`addend` 则体现了软件模拟环境特有的客户机地址与宿主机地址之间的联系。