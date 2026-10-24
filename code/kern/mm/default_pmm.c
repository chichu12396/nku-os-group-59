/*
 * 实验二：连续物理内存管理，First-Fit（首次适应）算法。
 * 参考 oslab2.pdf 中“物理内存管理的设计思路”和“页面分配算法”的说明。
 *
 * 管理单位是物理页；struct Page 是页描述符，不是物理页中的实际数据。
 * 同一 pages 数组中相邻的描述符对应相邻物理页，因此 base + n 表示向后 n 页。
 * free_list 按物理地址递增组织空闲块，每个块仅把首页的 page_link 挂入链表。
 * 首页的 property 记录该块包含的连续空闲页数，PG_property 标志其首页身份。
 * PageProperty(p) 为假并不一定表示已分配，也可能是空闲块中的非首页。
 * nr_free 统计空闲页总数，不是空闲块数，也不是字节数。
 *
 * 初始化：把可用页段登记为空闲块；分配：找到首个足够大的块，必要时拆分；
 * 回收：按地址插入链表，再合并物理上相邻的前后空闲块，以减少外部碎片。
 */
#include <pmm.h>
#include <list.h>
#include <string.h>
#include <default_pmm.h>

// 本分配器的内部状态：空闲块链表头和空闲页总数。
static free_area_t free_area;

// 用宏简化对 free_area 两个成员的访问。
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)

// 初始化空闲链表
static void
default_init(void) {
    // 建立带哨兵头节点的空双向循环链表，哨兵本身不代表物理页。
    list_init(&free_list);
    // 当前尚未登记任何可用页。
    nr_free = 0;
}

/*
 * 登记以 base 为首描述符、包含 n 个连续物理页的可用页段。
 */
static void
default_init_memmap(struct Page *base, size_t n) {
    // 不接受空页段。
    assert(n > 0);
    struct Page *p = base;
    // 逐页解除初始化时的保留状态，并清空页描述符中的管理信息。
    for (; p != base + n; p ++) {
        // 待登记页面应仍带有初始化阶段设置的保留标志。
        assert(PageReserved(p));
        // 清零 flags 也就清除了 PG_reserved；各页的 property 先置零。
        p->flags = p->property = 0;
        // 初始引用计数为零，表示尚未被引用。
        set_page_ref(p, 0);
    }
    // 只在空闲块首页记录连续页数，并设置空闲块首页标志。
    base->property = n;  //这个空闲块有多少页
    SetPageProperty(base);  //这一页现在是不是空闲块的头页
    // 新增 n 个可分配的物理页。
    nr_free += n;
    // 链表为空时，直接把该块首页挂到哨兵之后。
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        // 非空时从低地址到高地址查找插入位置，保持链表有序。
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            // 从嵌入 Page 的 page_link 成员指针反推出 Page 描述符指针。
            struct Page* page = le2page(le, page_link);
            // 遇到首个地址更大的块，将新块插在其前面。
            if (base < page) {
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                // 已到末尾且新块地址更大时，接到当前尾节点之后。
                list_add(le, &(base->page_link));
            }
        }
    }
}

/*
 * 分配 n 个物理地址连续的页，成功返回首页描述符，失败返回 NULL。
 * First-Fit 的关键是遇到第一个足够大的块便停止搜索。
 */
static struct Page *
default_alloc_pages(size_t n) {
    assert(n > 0);
    // 总空闲页数不足时直接失败；总量足够也仍可能因碎片而分配失败。
    if (n > nr_free) {
        return NULL;
    }
    // 未找到合适连续块时，page 保持 NULL。
    struct Page *page = NULL;
    list_entry_t *le = &free_list;
    // 从空闲链表头部开始依次检查各块的连续页数。
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        // 首个满足请求的块即为分配目标，不继续寻找更小的合适块。
        if (p->property >= n) {
            page = p;
            break;
        }
    }
    if (page != NULL) {
        // 记住原位置后摘下整块的首页节点，便于将拆分余块放回原处。
        list_entry_t* prev = list_prev(&(page->page_link));
        list_del(&(page->page_link));
        // 块大于请求时，从低地址端取走 n 页，把高地址端保留为空闲块。
        if (page->property > n) {
            // p 是余块的新首页
            struct Page *p = page + n;  
            // 余块长度等于原块长度减去已分配页数。
            p->property = page->property - n;
            SetPageProperty(p);
            // list_add 插在 prev 之后，使余块仍处在原块的地址排序位置。
            list_add(prev, &(p->page_link));
        }
        // 恰好匹配时无需余块；两种情况都只扣除实际分配的 n 页。
        nr_free -= n;
        // 已分配块的首页不再标记为空闲块首页。
        ClearPageProperty(page);
    }
    // 链表中没有足够大的连续块时，即使总空闲页数足够，也返回 NULL。
    return page;
}

/*
 * 回收以 base 为起点的 n 个连续物理页。
 */
static void
default_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    struct Page *p = base;
    // 清理本次回收范围内各页的状态与引用计数。
    for (; p != base + n; p ++) {
        // 页面不能是保留页，也不能带有空闲块首页标志。
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }
    // 先将整个回收范围描述为一个新的空闲块。
    base->property = n;
    SetPageProperty(base);
    // 只在此处增加空闲页数；后面的合并不改变空闲页总数。
    nr_free += n;

    // 与初始化登记时相同，按地址递增顺序插入新块的首页节点。
    if (list_empty(&free_list)) {
        list_add(&free_list, &(base->page_link));
    } else {
        list_entry_t* le = &free_list;
        while ((le = list_next(le)) != &free_list) {
            struct Page* page = le2page(le, page_link);
            if (base < page) {
                // 插在首个地址更大的空闲块之前。
                list_add_before(le, &(base->page_link));
                break;
            } else if (list_next(le) == &free_list) {
                // 新块位于现有所有块之后时，插到链表尾部。
                list_add(le, &(base->page_link));
            }
        }
    }

    // 先检查地址更小的前驱块；哨兵不能用 le2page 转换为 Page。
    list_entry_t* le = list_prev(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        // 前驱块起点加其页数恰好等于 base，才说明两块物理连续。
        if (p + p->property == base) {
            // 合并后保留低地址的 p 作为首页，并累加两块的页数。
            p->property += base->property;
            // 原 base 变为块内普通页，清除首页标志并摘下其链表节点。
            ClearPageProperty(base);
            list_del(&(base->page_link));
            // 更新 base，使接下来的后继合并基于扩大后的块。
            base = p;
        }
    }

    // 再检查后继块，从而支持一次回收同时合并左右两侧的空闲块。
    le = list_next(&(base->page_link));
    if (le != &free_list) {
        p = le2page(le, page_link);
        // 当前块的末端与后继块起点一致，说明两者物理连续。
        if (base + base->property == p) {
            base->property += p->property;
            // 后继首页并入当前块，取消其首页身份并从链表中移除。
            ClearPageProperty(p);
            list_del(&(p->page_link));
        }
    }
}

// 返回当前可分配的空闲物理页总数，单位为页。
static size_t
default_nr_free_pages(void) {
    return nr_free;
}

// 单页分配与回收的基础检查；以下仅补充注释，保留所有原有测试语句。
static void
basic_check(void) {
    struct Page *p0, *p1, *p2;
    p0 = p1 = p2 = NULL;
    // 连续申请三次单页分配，三次都应成功。
    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    // 验证三页互不重复，且刚分配页面的引用计数仍为零。
    assert(p0 != p1 && p0 != p2 && p1 != p2);
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);

    // 将描述符转换为物理地址，检查其没有达到或超过可管理的物理上界。
    assert(page2pa(p0) < npage * PGSIZE);
    assert(page2pa(p1) < npage * PGSIZE);
    assert(page2pa(p2) < npage * PGSIZE);

    // 暂存原空闲链表头，再用空链表隔离测试，避免其余空闲页参与。
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));

    // 同样保存并清零计数，模拟没有任何可分配页的状态。
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // 无空闲页时必须分配失败。
    assert(alloc_page() == NULL);

    // 归还刚才申请的三页，此时隔离的空闲区恰好有三页。
    free_page(p0);
    free_page(p1);
    free_page(p2);
    assert(nr_free == 3);

    // 这三页应能再次全部分配，之后继续申请必须失败。
    assert((p0 = alloc_page()) != NULL);
    assert((p1 = alloc_page()) != NULL);
    assert((p2 = alloc_page()) != NULL);

    assert(alloc_page() == NULL);

    // 单独归还 p0，空闲链表应重新变为非空。
    free_page(p0);
    assert(!list_empty(&free_list));

    // 隔离区中只有这一页可用，下一次分配必须取回原来的 p0。
    struct Page *p;
    assert((p = alloc_page()) == p0);
    assert(alloc_page() == NULL);

    // 测试页已全部取走，恢复原空闲链表和原计数。
    assert(nr_free == 0);
    free_list = free_list_store;
    nr_free = nr_free_store;

    // 将仍由测试持有的三页归还，恢复进入测试前的可用内存。
    free_page(p);
    free_page(p1);
    free_page(p2);
}

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
/*
 * First-Fit 综合检查：验证链表统计、连续分配、拆分、合并和状态恢复。
 * 以下同样仅增加注释，不修改原有测试逻辑。
 */
static void
default_check(void) {
    // 保存测试前空闲块数 count 和空闲页数 total，作为最终核对的基准。
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        // 链表中的每个节点都应代表一个空闲块的首页。
        assert(PageProperty(p));
        count ++, total += p->property;
    }
    // 各块长度之和应等于管理器报告的空闲页数。
    assert(total == nr_free_pages());

    // 先执行单页基础测试。
    basic_check();

    // 申请连续五页，已分配的首页必须不再带空闲块首页标志。
    struct Page *p0 = alloc_pages(5), *p1, *p2;
    assert(p0 != NULL);
    assert(!PageProperty(p0));

    // 保存其余空闲区并隔离；此刻即使原计数尚未清零，空链表也无法分配。
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // 把最初五页记作 A0～A4，先释放 A2～A4，得到长度为 3 的空闲块。
    // 申请四页失败；申请三页成功，且必须从 A2 开始。
    free_pages(p0 + 2, 3);
    assert(alloc_pages(4) == NULL);
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
    assert((p1 = alloc_pages(3)) != NULL);
    assert(alloc_page() == NULL);
    assert(p0 + 2 == p1);

    // p2 指向仍占用的 A1；释放 A0 及 A2～A4 后，形成长度为 1 和 3 的两块。
    // A1 将它们隔开，所以这两块暂时不能合并。
    p2 = p0 + 1;
    free_page(p0);
    free_pages(p1, 3);
    assert(PageProperty(p0) && p0->property == 1);
    assert(PageProperty(p1) && p1->property == 3);

    // 单页分配应先命中低地址的 A0，验证 First-Fit 从链表前端开始搜索。
    assert((p0 = alloc_page()) == p2 - 1);
    free_page(p0);
    // A0 只有一页，申请两页应跳过它，取 A2、A3，并留下余块 A4。
    assert((p0 = alloc_pages(2)) == p2 + 1);

    // 归还 A2、A3 后可与 A4 合并；再归还 A1，应同时连接左右两侧，
    // 最终恢复从 A0 开始的五页连续空闲块。
    free_pages(p0, 2);
    free_page(p2);

    // 五页应可整体再次分配，随后隔离区中不应再有可分配页。
    assert((p0 = alloc_pages(5)) != NULL);
    assert(alloc_page() == NULL);

    // 恢复原计数和原空闲链表，再归还测试占用的连续五页。
    assert(nr_free == 0);
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);

    // 用恢复后的统计抵消最初记录，检查空闲块数和空闲页数都已恢复。
    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
    }
    assert(count == 0);
    assert(total == 0);
}

/*
 * 向物理内存管理框架提供统一的 pmm_manager 接口。
 * 上层选中本管理器后，通过这些函数指针调用具体的 First-Fit 实现。
 */
const struct pmm_manager default_pmm_manager = {
    .name = "default_pmm_manager",
    // 初始化内部链表与计数。
    .init = default_init,
    // 登记初始化阶段发现的可用连续页段。
    .init_memmap = default_init_memmap,
    // 连续页分配、连续页回收、空闲页数查询和自检入口。
    .alloc_pages = default_alloc_pages,
    .free_pages = default_free_pages,
    .nr_free_pages = default_nr_free_pages,
    .check = default_check,
};
