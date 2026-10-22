# Lab2 提示词汇总（成员 C）

> 本文件收录成员 C 负责模块的最终提示词（lab0.5 四段式：`[PROMPT]` / `[RELY]` / `[GUARANTEE]` / `[SPECIFICATION]`）。

## 1. SLUB 实现（Challenge）

````markdown
[PROMPT]
**任务**：修改 ucore lab2 工程，新建 `kern/mm/slub.c` 和 `kern/mm/slub.h`，实现一个简化的两层 SLUB 内存分配器。第一层复用现有物理页分配器 `alloc_pages/free_pages`；第二层在同一物理页内按固定对象大小切分对象，从而支持任意大小（1 字节 ~ 4096 字节）的分配与释放，并提供自检函数 `slub_check()`。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。新建 `kern/mm/slub.h` 和 `kern/mm/slub.c`；`.c` 文件会被 Makefile 的通配符自动加入编译。禁止修改 `pmm.c`、`pmm.h`、`memlayout.h`、`Makefile`、`tools/` 下的任何文件——`pmm.c` 已经在 `#ifdef LAB2_SLUB` 下调用 `slub_init()` 和 `slub_check()`，你的实现必须与这两个调用点对齐。工程没有标准 C 库，代码必须能通过 `-Wall -Werror` 编译。

**输出要求**：直接进行文件操作。生成代码后应能通过 `make` 编译，并在 `make qemu DEFS="-DLAB2_SLUB"` 下运行 `slub_check()` 全部通过。

[RELY]

// 宏定义（与工程代码一致）
- `PGSIZE = 4096`，`PGSHIFT = 12`
- `PPN(la)  (((uintptr_t)(la)) >> PGSHIFT)`
- `ROUNDUP(a, n)` / `ROUNDDOWN(a, n)`：向上 / 向下按 n 取整
- `NULL  ((void *)0)`
- 类型：`size_t`（即 `uintptr_t`）、`uintptr_t`、`bool`

// 数据结构（kern/mm/memlayout.h）
```c
struct Page {
    int ref;                // 页引用计数
    uint64_t flags;         // 状态位：PG_reserved = 0，PG_property = 1
    unsigned int property;  // 空闲块大小；页面被 alloc_pages 取走后，该字段可由调用者自由使用
    list_entry_t page_link; // 空闲链表节点
};
```
```c
#define le2page(le, member)  to_struct((le), struct Page, member)  // 由链表节点得到 Page
#define offsetof(type, member) ((size_t)(&((type *)0)->member))
```

// 链表操作（libs/list.h）
`list_init(list)`、`list_add(listelm, elm)`、`list_add_before(listelm, elm)`、`list_add_after(listelm, elm)`、`list_del(listelm)`、`list_del_init(listelm)`、`list_empty(list)`、`list_next(listelm)`、`list_prev(listelm)`

// 物理页分配接口（kern/mm/pmm.h，即第一层）
```c
struct Page *alloc_pages(size_t n);            // 分配连续 n 页，失败返回 NULL
void free_pages(struct Page *base, size_t n);  // 归还从 base 开始的 n 页
size_t nr_free_pages(void);                    // 当前空闲页数
#define alloc_page()   alloc_pages(1)
#define free_page(page) free_pages(page, 1)
```

// 地址与 Page 的转换
```c
extern struct Page *pages;      // Page 描述符数组基址
extern size_t npage;            // 物理页总数
extern const size_t nbase;      // 起始物理页号
extern uint64_t va_pa_offset;   // 内核虚拟地址 = 物理地址 + va_pa_offset
static inline uintptr_t page2pa(struct Page *page);   // Page -> 物理地址
static inline struct Page *pa2page(uintptr_t pa);     // 物理地址 -> Page（越界会 panic）
#define PADDR(kva)  ...         // 内核虚拟地址 -> 物理地址（kva < KERNBASE 会 panic）
```

// 调试与输出
```c
#define assert(x)      // 条件不成立时 panic
#define panic(...)     // 打印并终止内核
#define warn(...)      // 仅打印警告，不终止
int cprintf(const char *fmt, ...);
```

// 重要约束
- 工程没有 malloc/free，没有标准 C 库；只能使用上述接口。
- 每个 `struct Page` 描述一个 4KB 物理页；页内存在内核直接映射区可访问，一页的虚拟地址 = `page2pa(page) + va_pa_offset`。
- `Page.property` 在页面被 `alloc_pages` 取走后不再被页分配器使用；归还页面前必须把它清零，并且把 `page->flags` 清零，否则页分配器的 free 路径断言会失败。

[GUARANTEE]
必须实现或修改的接口（`kern/mm/slub.h` 中声明，`kern/mm/slub.c` 中实现）：
```c
void  slub_init(void);
void  slub_check(void);
void *slub_alloc(size_t size);
void  slub_free(void *ptr);
```
你可以根据需要添加：
- 辅助函数（必须设为 `static`，只在本模块内部使用，不得改变公开接口）
- 模块内部的宏定义、静态变量（大小类表、slab 描述符表等）

[SPECIFICATION]

## slub_init
**Pre-Condition**:
- 在 `pmm_init()` 中、`check_alloc_page()` 之后被调用，此时页分配器已可用（`alloc_pages/free_pages` 可调用）。

**Post-Condition**:
- 所有大小类的缓存结构初始化完毕，没有任何 slab 被创建；记录当前 `nr_free_pages()` 作为基线，供 `slub_check()` 使用。

**Case 1**:
- 首次调用时，清空全部大小类的空闲链表、当前 slab 指针和 slab 描述符表，记录空闲页基线。

**Requirements**:
- 重复调用应当是幂等的（清空状态即可），且不得为此分配物理页。

## slub_alloc
**Pre-Condition**:
- 已调用过 `slub_init()`；`size` 为请求的字节数。

**Post-Condition**:
- 成功时返回一个至少 `size` 字节、按 8 字节对齐、可读写的内核虚拟地址，且该地址在下一次 `slub_free()` 之前不会被重复分配；失败返回 `NULL`。

**大小类规则**:
- 把 `size` 向上取整到 2 的幂，最小 8、最大 `PGSIZE`，即 8/16/32/64/128/256/512/1024/2048/4096 十个大小类。
- 每个大小类对应一个 cache，对象步长 `stride` = 该大小类的值（≥ 8，保证能放下 8 字节空闲指针），一页内的对象个数 = `PGSIZE / stride`。

**Case 1（非法参数）**:
- `size == 0` 或 `size > PGSIZE` 时返回 `NULL`，不改变任何状态。

**Case 2（快路径）**:
- 对应 cache 的当前 slab 存在且 freelist 非空时，从 freelist 摘下一个对象返回，slab 的 inuse 加一。

**Case 3（慢路径 · 复用）**:
- 当前 slab 的 freelist 为空，但该 cache 的 partial 链表上有可用 slab 时，取出一个作为当前 slab，再按 Case 2 返回对象。

**Case 4（慢路径 · 新建）**:
- 当前 slab 与 partial 链表都没有可用对象时，调用 `alloc_pages(1)` 取一页：失败则返回 `NULL`；成功则初始化一个 slab 描述符，把该页切分成该 cache 的对象，并用每个空闲对象的前 8 字节串成 freelist，然后返回第一个对象。

**Requirements**:
- freelist 中每个空闲对象的前 8 字节存放"下一个空闲对象"的指针（空闲对象的内容本来就不被使用）；不额外占用页内空间。
- 每个 slab 必须能由它内部的对象指针反查到：用 `Page.property` 记录该 slab 在全局 slab 描述符表中的下标 + 1（0 表示该页不是 SLUB 的 slab），并由 `pa2page(物理地址)` 取得该页的页描述符。
- 返回的对象地址必须位于内核可访问的虚拟地址（`page2pa(page) + va_pa_offset + 偏移`）。

## slub_free
**Pre-Condition**:
- `ptr` 要么是 `NULL`，要么是之前 `slub_alloc()` 返回且尚未释放的指针。

**Post-Condition**:
- 该对象被归还到它所属 slab 的空闲链表，slab 的 inuse 减一；所有对象都释放后页面最终归还给页分配器（允许保留缓存）。

**Case 1（NULL）**:
- `ptr == NULL` 时直接返回，不做任何操作。

**Case 2（非法指针）**:
- `ptr` 不属于任何 SLUB slab（页的 `property` 为 0），或对象偏移不是 `stride` 的整数倍时，打印 `warn` 并直接返回，不破坏任何数据结构。

**Case 3（普通释放）**:
- 通过页描述符找到 slab，把对象头插到 freelist，inuse 减一；如果该 slab 从"满"变为"有空洞"，把它挂回该 cache 的 partial 链表（若尚未挂上）。

**Case 4（整 slab 释放）**:
- inuse 降为 0 且该 cache 已有其它 slab 时，把该 slab 归还：从 partial 链表摘除（若它就是当前 slab，把当前指针置空）；清零该页的 `flags` 与 `property`，再调用 `free_page(page)`。
- inuse 为 0 但它是该 cache 唯一的 slab 时，保留它（挂在 partial 链表上，供下次分配复用）。

**Requirements**:
- 释放页面前必须先清零页面描述符的 `flags` 与 `property`，再调用 `free_pages/free_page`。

## slub_check
**Pre-Condition**:
- 在 `slub_init()` 之后调用，页分配器可用。

**Post-Condition**:
- 逐项打印测试通过情况，全部通过后打印 `SLUB check passed!`。

**必须覆盖的测试**（每项独立输出一行结果）:
1. 多种大小：分别分配 8、64、100、1024、4000、4096 字节各 2 个对象，写入不同数据后读回校验，再全部释放。
2. 同一大小反复分配/释放：分配、释放、再分配同一大小，验证新分配得到可用内存（复用）。
3. 接近一页与非法请求：`slub_alloc(4096)` 正常返回；`slub_alloc(0)`、`slub_alloc(PGSIZE + 1)` 返回 `NULL`；`slub_free(NULL)` 不崩溃。
4. 页数守恒：全部释放后打印 `nr_free_pages()` 与基线的差值（允许差值 ≤ 用过的 cache 数量，保留缓存页属正常）。
5. 交叉大小：交替分配不同大小对象后统一释放，再分配验证无交叉破坏。

**Requirements**:
- 不依赖具体页分配器（只用 `alloc_pages/free_pages/nr_free_pages`）。
- 失败时用 `panic` 或明确的 `FAILED` 输出并给出原因。
````

## 2. SLUB 测试

````markdown
[PROMPT]
**任务**：在 ucore lab2 工程中，为 `kern/mm/slub.c` 里已实现的简化 SLUB 分配器（由提示词①生成）设计测试函数，并集成进 `slub_check()`。测试要覆盖不同大小内存对象的分配与释放是否正确，以及边界情况。

**操作要求**：你必须在项目中修改实际文件（`kern/mm/slub.c`），保留现有代码。**不得修改分配器实现**（`slub_init`、`slub_alloc`、`slub_free` 以及内部辅助函数保持原样），只在文件中新增 `static` 测试函数，并让 `slub_check()` 依次调用它们。测试代码与实现位于同一编译单元，可访问模块内部静态变量，但应优先只使用公开接口和 `nr_free_pages()`。

**输出要求**：直接进行文件操作。生成代码必须通过 `-Wall -Werror` 编译，并在 `make qemu DEFS="-DLAB2_SLUB"` 下让 `slub_check()` 全部通过。

[RELY]

// 待测接口（kern/mm/slub.h）
```c
void  slub_init(void);
void  slub_check(void);
void *slub_alloc(size_t size);
void  slub_free(void *ptr);
```

// 待测实现的设计约定（提示词①已确定）
- 大小类为 2 的幂：8 / 16 / 32 / 64 / 128 / 256 / 512 / 1024 / 2048 / 4096，共 10 个
- 每个 slab 恰好是一页（4KB），对象步长 = 大小类，一页内对象数 = PGSIZE / 步长
- 空闲对象的前 8 字节存放 freepointer；返回的对象地址按 8 字节对齐
- `size == 0` 或 `size > PGSIZE` 时 `slub_alloc` 返回 `NULL`
- 每个缓存保留 1 个当前 slab 作为缓存，其余空 slab 归还页分配器

// 可用的调试与系统接口
```c
int cprintf(const char *fmt, ...);
#define panic(...)      // 打印并终止内核
#define assert(x)       // 失败 panic
#define warn(...)       // 打印警告
size_t nr_free_pages(void);   // 当前空闲物理页数
#define PGSIZE 4096
```

// 模块内部可用的静态变量
- `static size_t free_pages_base;` —— `slub_init()` 记录的空闲页基线，测试可直接读取

// 重要约束
- 工程没有标准 C 库；不能调用 malloc/free/printf。
- 内核是单线程、无中断，测试可以顺序执行，不需要考虑并发。

[GUARANTEE]
必须修改的接口：
```c
void slub_check(void);   // 唯一测试入口，pmm.c 在 LAB2_SLUB 下调用它
```
你可以根据需要添加：
- `static` 测试函数与 `static` 辅助函数（如填充/校验内存模式）
- `static` 数组（用于保存待测指针，大小有界）
- 模块内部的宏定义

禁止修改：`slub_init`、`slub_alloc`、`slub_free` 及其内部辅助函数。

[SPECIFICATION]

## 测试 1：全大小类、对齐与内容正确性
**Pre-Condition**: 已完成 `slub_init()`。

**Post-Condition**: 每个被测大小的对象都能成功分配、内容可完整读写、释放后不残留。

**Case**:
- 遍历代表性大小：1、7、8、9、16、31、32、33、64、100、127、128、200、255、256、511、512、1000、1024、2047、2048、4000、4095、4096，每个大小：分配 1 个对象 → 检查非 `NULL` → 检查地址 8 字节对齐 → 用与大小相关的模式填满 `size` 字节 → 读回校验 → 释放。
- 任意一步失败：打印 `[SLUB] <测试名>: FAILED` 并 `panic`。

## 测试 2：同大小多对象同时存活（跨 slab）
**Pre-Condition**: 无。

**Post-Condition**: 64 个 128 字节对象同时存活（超过单页 32 个对象，必然跨 2 个 slab），各自内容互不干扰，全部释放后无残留。

**Case**:
- 连续分配 64 个 128 字节对象，保存指针；每个对象填入与序号相关的独特模式。
- 逐个读回校验全部 64 个对象；统一释放。

## 测试 3：freelist 跨页衔接与对象不重叠
**Pre-Condition**: 无。

**Post-Condition**: 700 个 8 字节对象（单页最多 512 个，必然跨越 slab 边界）全部可分配、内容可校验、可全部释放。

**Case**:
- 连续分配 700 个 8 字节对象，保存指针；每个对象写入 8 字节唯一值（如 `0x1234567800000000 + 序号`）。
- 逐个读回校验：若 freelist 跨页衔接出错或对象重叠，唯一值会被破坏。
- 全部释放。

## 测试 4：复用与页数不增长
**Pre-Condition**: 无。

**Post-Condition**: 反复分配/释放同一大小 200 轮后，空闲页数不减少（对象被复用，没有为每轮新分配页面）。

**Case**:
- 先分配并释放 1 个 256 字节对象（确保该大小类已建好缓存 slab），记录 `nr_free_pages()` 为 `before`。
- 循环 200 次：分配 256 字节 → 写入唯一值 → 读回校验 → 释放。
- 循环结束后 `nr_free_pages()` 必须等于 `before`，否则判失败。

## 测试 5：交叉大小隔离与乱序释放
**Pre-Condition**: 无。

**Post-Condition**: 不同大小类的对象互不干扰；乱序释放不会破坏其它存活对象。

**Case**:
- 依次分配 8、128、1024、2048 字节对象各一个，写入不同模式。
- 先释放 1024 和 8 字节对象（乱序），再校验 128 和 2048 字节对象内容完好。
- 释放剩余对象。

## 测试 6：整页对象（4096）
**Pre-Condition**: 无。

**Post-Condition**: 4096 字节对象可分配、页对齐、可整页读写、释放后可再次分配复用。

**Case**:
- 分配 4096 字节对象，检查非 `NULL` 且地址按 4096 对齐；填满整页读回校验；释放。
- 再次分配 4096 字节对象，填另一模式读回校验；释放。

## 测试 7：非法输入
**Pre-Condition**: 无。

**Post-Condition**: 非法请求被拒绝且不破坏状态。

**Case**:
- `slub_alloc(0)` 返回 `NULL`。
- `slub_alloc(PGSIZE + 1)` 返回 `NULL`。
- `slub_free(NULL)` 不崩溃、不改变状态。

## 测试 8：页数守恒
**Pre-Condition**: 前 7 项测试已完成且全部释放。

**Post-Condition**: 空闲页数与 `slub_init()` 时的基线相比，差值不超过大小类总数（允许每个用过的缓存保留 1 页）；打印 `base`、`now`、`delta`。

**Requirements**:
- 每个测试失败时立即输出失败原因并 `panic`，便于定位。
- 每个测试结束时必须释放自己分配的所有对象。
- 测试总内存占用有界（不超过几 MB）。

## slub_check
**Pre-Condition**: `slub_init()` 已调用、页分配器可用。

**Post-Condition**: 依次执行测试 1~8，逐行打印 `passed`；全部通过后打印 `SLUB check passed!`。

**Case**:
- 按顺序调用测试 1 到 8；任意测试 panic 即终止。

**Requirements**:
- 保持 `slub_check()` 作为唯一对外测试入口，`pmm.c` 的钩子不需要改动。
````
