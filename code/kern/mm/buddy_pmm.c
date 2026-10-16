#include <pmm.h>
#include <memlayout.h>
#include <list.h>
#include <defs.h>
#include <assert.h>
#include <stdio.h>
#include <buddy_pmm.h>

/*
 * 页级 Buddy System（伙伴系统）物理内存管理器。
 *
 * 几个关键设计决定：
 *  1. 空闲块按阶（order）分桶：第 order 阶的空闲块由 2^order 个连续物理页组成，
 *     块首页挂在 buddy_free_area[order] 的链表上，首页的 property 记录块内页数。
 *  2. 伙伴运算是拿"页在 pages 描述符数组里的下标"来做的（下标 = PPN - nbase）：
 *     伙伴下标 = 下标 ^ (1 << order)。因为 DRAM_BASE(0x80000000) 是 2^31 对齐的，
 *     下标的对齐性等价于物理地址的对齐性，所以用下标做伙伴运算与用物理地址等价。
 *  3. 分配与释放用同一个向上取整函数 buddy_order_of()，保证释放时能算回分配时的阶，
 *     否则伙伴会找错、链表会被破坏。
 *  4. 与 First-Fit 不同，Buddy 只能整块回收：free_pages(base, n) 的 base 必须按
 *     向上取整后的块大小对齐，并且回收的正是那一整块（正常用法是 alloc/free 传同一个 n）。
 */

#define MAX_ORDER 15

// 各阶空闲块链表；下标即阶，故不需要另外记录 size
static free_area_t buddy_free_area[MAX_ORDER + 1];
// 所有阶空闲页的总数，供 nr_free_pages() 使用（check 里会与各阶链表求和互查）
static size_t buddy_free_total;

#define buddy_list(order)   (buddy_free_area[(order)].free_list)
#define buddy_nrfree(order) (buddy_free_area[(order)].nr_free)

// 向上取整到 2 的幂，返回对应的阶
static size_t
buddy_order_of(size_t n) {
    size_t order = 0;
    while (((size_t)1 << order) < n) {
        order ++;
    }
    return order;
}

// 页在页描述符数组里的下标
static size_t
buddy_page_idx(struct Page *p) {
    return (size_t)(p - pages);
}

// 各阶空闲链表里的页数总和（供 check 做一致性核对）
static size_t
buddy_sum_free_pages(void) {
    size_t total = 0;
    for (size_t order = 0; order <= MAX_ORDER; order ++) {
        list_entry_t *le = &buddy_list(order);
        while ((le = list_next(le)) != &buddy_list(order)) {
            struct Page *p = le2page(le, page_link);
            total += p->property;
        }
    }
    return total;
}

static void
buddy_init(void) {
    // 注意：本函数在 page_init() 之前被调用，此时全局的 pages 仍为 NULL、npage 仍为 0，
    // 所以这里只能初始化模块自己的链表与计数器，不能访问 pages 数组。
    for (size_t order = 0; order <= MAX_ORDER; order ++) {
        list_init(&buddy_list(order));
        buddy_nrfree(order) = 0;
    }
    buddy_free_total = 0;
}

static void
buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);

    struct Page *p = base;
    for (; p != base + n; p ++) {
        assert(PageReserved(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
    }

    // 这段空闲区的长度和起始页号通常都不是 2 的幂、也不按 2 的幂对齐，
    // 必须拆成若干个"长度为 2 的幂、且起始下标按该幂次对齐"的块，伙伴运算才合法。
    // 这样的拆法是唯一的（对齐的 2 的幂分解），天然满足"同阶伙伴不会同时空闲"。
    size_t done = 0;
    while (done < n) {
        struct Page *cur = base + done;
        size_t idx = buddy_page_idx(cur);
        size_t rem = n - done;
        size_t order = MAX_ORDER;
        while (order > 0 &&
               (((size_t)1 << order) > rem ||
                (idx & (((size_t)1 << order) - 1)) != 0)) {
            order --;
        }
        size_t size = (size_t)1 << order;
        cur->property = size;
        SetPageProperty(cur);
        list_add(&buddy_list(order), &(cur->page_link));
        buddy_nrfree(order) ++;
        buddy_free_total += size;
        done += size;
    }
}

static struct Page *
buddy_alloc_pages(size_t n) {
    if (n == 0 || n > ((size_t)1 << MAX_ORDER)) {
        return NULL;
    }
    size_t order = buddy_order_of(n);

    // 从目标阶往上找第一个有空闲块的阶
    size_t cur = order;
    while (cur <= MAX_ORDER && list_empty(&buddy_list(cur))) {
        cur ++;
    }
    if (cur > MAX_ORDER) {
        return NULL;        // 失败路径不修改任何链表与计数
    }

    list_entry_t *le = list_next(&buddy_list(cur));
    struct Page *block = le2page(le, page_link);
    list_del(&(block->page_link));
    buddy_nrfree(cur) --;
    buddy_free_total -= (size_t)1 << cur;
    ClearPageProperty(block);
    block->property = 0;

    // 逐级对半拆分，把高半块挂进对应阶的空闲链表
    while (cur > order) {
        cur --;
        struct Page *buddy = block + ((size_t)1 << cur);
        buddy->property = (size_t)1 << cur;
        SetPageProperty(buddy);
        set_page_ref(buddy, 0);
        list_add(&buddy_list(cur), &(buddy->page_link));
        buddy_nrfree(cur) ++;
        buddy_free_total += (size_t)1 << cur;
    }
    set_page_ref(block, 0);
    return block;
}

static void
buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0 && n <= ((size_t)1 << MAX_ORDER));
    size_t order = buddy_order_of(n);
    size_t size = (size_t)1 << order;
    // 只能整块回收：块的起始下标必须按块大小对齐
    assert((buddy_page_idx(base) & (size - 1)) == 0);

    struct Page *p = base;
    for (; p != base + size; p ++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = 0;
        set_page_ref(p, 0);
    }

    // 先把这一块挂进它所在阶的空闲链表
    struct Page *block = base;
    block->property = size;
    SetPageProperty(block);
    list_add(&buddy_list(order), &(block->page_link));
    buddy_nrfree(order) ++;
    buddy_free_total += size;

    // 与伙伴逐级合并
    size_t cur = order;
    while (cur < MAX_ORDER) {
        size_t idx = buddy_page_idx(block);
        size_t buddy_idx = idx ^ ((size_t)1 << cur);
        if (buddy_idx >= (size_t)(npage - nbase)) {
            break;              // 伙伴落在可管理区间之外，无法合并
        }
        struct Page *buddy = pages + buddy_idx;
        if (!PageProperty(buddy) || buddy->property != ((size_t)1 << cur)) {
            break;              // 伙伴不是同阶空闲块（正被占用或不属于本阶）
        }

        // 两个同阶块都从链表摘下，合并成高一阶的块（下标较小的那半作新块头）
        list_del(&(block->page_link));
        list_del(&(buddy->page_link));
        buddy_nrfree(cur) -= 2;

        struct Page *merged = (idx & ((size_t)1 << cur)) ? buddy : block;
        ClearPageProperty(block);
        ClearPageProperty(buddy);
        block->property = 0;
        buddy->property = 0;
        merged->property = (size_t)1 << (cur + 1);
        SetPageProperty(merged);
        list_add(&buddy_list(cur + 1), &(merged->page_link));
        buddy_nrfree(cur + 1) ++;
        // 合并前后空闲页总数不变，故 buddy_free_total 不用调整

        block = merged;
        cur ++;
    }
}

static size_t
buddy_nr_free_pages(void) {
    return buddy_free_total;
}

// 扫描全部空闲链表，校验结构不变量，并把各阶空闲块数写进 blocks[]。
// 返回值是所有空闲块的页数总和（应与 nr_free_pages() 相等）。检查项：
//   1. 每个块头都置了 PG_property，且 property 恰好等于它所在阶的块大小；
//   2. 块的整体范围落在可管理的页区间内；
//   3. 块内除首页外不能再出现别的空闲块头（否则说明两块空闲区间重叠）；
//   4. 同一阶的两个伙伴不能同时是空闲块（否则说明该合并的没有合并）。
static size_t
buddy_check_invariants(size_t *blocks) {
    size_t total = 0;
    size_t pages_end = (size_t)(npage - nbase);
    for (size_t order = 0; order <= MAX_ORDER; order ++) {
        blocks[order] = 0;
        list_entry_t *le = &buddy_list(order);
        while ((le = list_next(le)) != &buddy_list(order)) {
            struct Page *head = le2page(le, page_link);
            size_t size = (size_t)1 << order;
            size_t idx = buddy_page_idx(head);

            assert(PageProperty(head));
            assert(head->property == size);
            assert(idx <= pages_end && size <= pages_end - idx);

            for (size_t i = 1; i < size; i ++) {
                assert(!PageProperty(head + i));
            }

            size_t buddy_idx = idx ^ size;
            if (buddy_idx < pages_end) {
                struct Page *buddy = pages + buddy_idx;
                assert(!(PageProperty(buddy) && buddy->property == size));
            }

            blocks[order] ++;
            total += size;
        }
    }
    return total;
}

static int
buddy_same(const size_t *a, const size_t *b) {
    for (size_t i = 0; i <= MAX_ORDER; i ++) {
        if (a[i] != b[i]) {
            return 0;
        }
    }
    return 1;
}

static void
buddy_check(void) {
#ifdef ucore_test
    int score = 0;
    const int sumscore = 7;
#endif
    size_t blocks_before[MAX_ORDER + 1];
    size_t blocks_now[MAX_ORDER + 1];
    size_t free_before = nr_free_pages();
    assert(free_before > 0);
    assert(buddy_check_invariants(blocks_before) == free_before);

    // (1) 分配大小向上取整到 2 的幂
    {
        struct Page *p = alloc_pages(3);
        assert(p != NULL);
        assert(!PageProperty(p));
        for (size_t i = 0; i < 4; i ++) {
            assert(!PageProperty(p + i));       // 分配出去的块内部不能残留块头标记
        }
        assert((buddy_page_idx(p) & 3) == 0);           // 3 页 -> 4 页，且按 4 页对齐
        assert(nr_free_pages() == free_before - 4);     // 请求 3 页却占用 4 页
        free_pages(p, 3);
        assert(nr_free_pages() == free_before);
        assert(buddy_check_invariants(blocks_now) == free_before);
        assert(buddy_same(blocks_now, blocks_before));
    }
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // (2) 强制走拆分路径，并校验拆分/合并的确切形态
    {
        // 找一个阶 k：本级链表为空、但存在更高阶的空闲块 —— 这样的请求必然触发拆分
        size_t k = 0, j = 0;
        int found = 0;
        for (size_t o = 1; o <= MAX_ORDER && !found; o ++) {
            if (!list_empty(&buddy_list(o))) {
                continue;
            }
            for (size_t h = o + 1; h <= MAX_ORDER; h ++) {
                if (!list_empty(&buddy_list(h))) {
                    k = o;
                    j = h;
                    found = 1;
                    break;
                }
            }
        }
        assert(found);      // 初始分布是空闲区的"对齐 2 的幂分解"，必然留有空的低阶

        struct Page *p = alloc_pages((size_t)1 << k);
        assert(p != NULL);
        assert(!PageProperty(p));
        assert(buddy_check_invariants(blocks_now) == free_before - ((size_t)1 << k));
        // 拆分的确切形态：j 阶少 1 块、k..j-1 每阶各多 1 块（拆分出的高半块），其余阶不变
        for (size_t o = 0; o <= MAX_ORDER; o ++) {
            size_t expect = blocks_before[o];
            if (o == j) {
                expect --;
            } else if (o >= k && o < j) {
                expect ++;
            }
            assert(blocks_now[o] == expect);
        }

        free_pages(p, (size_t)1 << k);                  // 释放后必须逐级合并回原状
        assert(nr_free_pages() == free_before);
        assert(buddy_check_invariants(blocks_now) == free_before);
        assert(buddy_same(blocks_now, blocks_before));
    }
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // (3) 释放后可重新分配
    {
        struct Page *a = alloc_pages(2);
        assert(a != NULL);
        size_t buddy_idx = buddy_page_idx(a) ^ 2;         // 2 页块的伙伴下标
        int buddy_busy = (buddy_idx >= (size_t)(npage - nbase)) ||
                         !PageProperty(pages + buddy_idx);
        size_t free_mid = nr_free_pages();
        free_pages(a, 2);
        assert(nr_free_pages() == free_mid + 2);
        struct Page *c = alloc_pages(2);
        assert(c != NULL);
        if (buddy_busy) {
            assert(c == a);                              // 伙伴被占用时，应原样拿回这一块
        }
        free_pages(c, 2);
        assert(nr_free_pages() == free_before);
        assert(buddy_check_invariants(blocks_now) == free_before);
        assert(buddy_same(blocks_now, blocks_before));
    }
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // (4) 分配失败返回 NULL，且失败不留副作用
    {
        assert(alloc_pages(0) == NULL);
        assert(alloc_pages((size_t)1 << (MAX_ORDER + 1)) == NULL);   // 超过最大阶
        assert(alloc_pages(npage) == NULL);                          // 超过全部物理页
        assert(nr_free_pages() == free_before);
    }
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // (5) nr_free_pages() 与各阶空闲链表页数总和一致
    assert(nr_free_pages() == buddy_sum_free_pages());
    assert(buddy_check_invariants(blocks_now) == free_before);
    assert(buddy_same(blocks_now, blocks_before));
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // (6) 边界：最小块、最大块、非 2 的幂页数、按取整后的大小释放
    {
        size_t free_mid;
        struct Page *p = alloc_pages(1);                 // 最小块
        assert(p != NULL);
        assert(!PageProperty(p));
        free_pages(p, 1);
        assert(nr_free_pages() == free_before);

        size_t request[3] = {3, 5, 7};                   // 非 2 的幂
        size_t used[3] = {4, 8, 8};
        for (int i = 0; i < 3; i ++) {
            free_mid = nr_free_pages();
            p = alloc_pages(request[i]);
            assert(p != NULL);
            assert(nr_free_pages() == free_mid - used[i]);
            assert((buddy_page_idx(p) & (used[i] - 1)) == 0);
            free_pages(p, request[i]);
            assert(nr_free_pages() == free_before);
            assert(buddy_check_invariants(blocks_now) == free_before);
            assert(buddy_same(blocks_now, blocks_before));
        }

        // 按取整后的大小释放同样合法：alloc(3) 实际占 4 页，用 4 释放
        p = alloc_pages(3);
        assert(p != NULL);
        free_pages(p, 4);
        assert(nr_free_pages() == free_before);

        size_t order = MAX_ORDER;                        // 最大块
        while (order > 0 && list_empty(&buddy_list(order))) {
            order --;
        }
        p = alloc_pages((size_t)1 << order);
        assert(p != NULL);
        assert((buddy_page_idx(p) & (((size_t)1 << order) - 1)) == 0);
        free_pages(p, (size_t)1 << order);
        assert(nr_free_pages() == free_before);
        assert(buddy_check_invariants(blocks_now) == free_before);
        assert(buddy_same(blocks_now, blocks_before));
    }
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // (7) 碎片与释放顺序
    {
        // 7a) 释放一块不能连带回收仍被占用的邻块
        struct Page *a = alloc_pages(2), *b = alloc_pages(2);
        assert(a != NULL && b != NULL && a != b);
        size_t free_mid = nr_free_pages();
        free_pages(a, 2);
        assert(nr_free_pages() == free_mid + 2);         // 只该回收 2 页
        assert(!PageProperty(b));                        // b 仍被占用
        struct Page *c = alloc_pages(2);
        assert(c != NULL && c != b);                     // 不能分配出与 b 重叠的块
        free_pages(c, 2);
        free_pages(b, 2);
        assert(nr_free_pages() == free_before);

        // 7b) 多种大小混合分配，再按两种不同顺序释放，结果都必须完全复原
        struct Page *hold[12];
        size_t request[12] = {1, 2, 3, 5, 7, 2, 1, 4, 3, 5, 2, 1};
        size_t expect_used = 0;                          // 独立算一遍取整，不用被测代码的辅助函数
        for (int i = 0; i < 12; i ++) {
            size_t s = 1;
            while (s < request[i]) {
                s <<= 1;
            }
            expect_used += s;
        }
        size_t batch_before = nr_free_pages();
        for (int i = 0; i < 12; i ++) {
            hold[i] = alloc_pages(request[i]);
            assert(hold[i] != NULL);
            assert(!PageProperty(hold[i]));
        }
        assert(nr_free_pages() == batch_before - expect_used);
        assert(buddy_check_invariants(blocks_now) == batch_before - expect_used);

        for (int i = 11; i >= 0; i --) {                 // 逆序释放
            free_pages(hold[i], request[i]);
        }
        assert(nr_free_pages() == batch_before);
        assert(buddy_check_invariants(blocks_now) == free_before);
        assert(buddy_same(blocks_now, blocks_before));   // 释放顺序不同，结果必须相同

        for (int i = 0; i < 12; i ++) {                  // 再来一轮：按奇偶分两批释放
            hold[i] = alloc_pages(request[i]);
            assert(hold[i] != NULL);
        }
        for (int i = 0; i < 12; i += 2) {
            free_pages(hold[i], request[i]);
        }
        for (int i = 1; i < 12; i += 2) {
            free_pages(hold[i], request[i]);
        }
        assert(nr_free_pages() == free_before);
        assert(buddy_check_invariants(blocks_now) == free_before);
        assert(buddy_same(blocks_now, blocks_before));
    }
#ifdef ucore_test
    score ++;
    cprintf("grading: %d / %d points\n", score, sumscore);
#endif

    // 全部测试做完，系统状态必须与开始时完全一致
    assert(buddy_check_invariants(blocks_now) == free_before);
    assert(buddy_same(blocks_now, blocks_before));
    assert(nr_free_pages() == free_before);
    assert(free_before == buddy_sum_free_pages());
}

const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};
