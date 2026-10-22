#include <assert.h>
#include <defs.h>
#include <list.h>
#include <memlayout.h>
#include <pmm.h>
#include <slub.h>
#include <stdio.h>

/*
 * Simplified SLUB allocator.
 *
 * Layer 1 uses the physical page allocator directly: every slab is exactly
 * one 4KB page obtained with alloc_pages(1) and released with free_page().
 * Layer 2 splits a page into fixed-size objects; the size classes are the
 * powers of two from 8 to PGSIZE, like kmalloc's caches.
 *
 * Free objects are chained through the first 8 bytes of the object itself
 * (an object's content is dead while it is on the freelist), which is the
 * "freepointer overlaps the object" idea of Linux SLUB.  A slab descriptor
 * can be found from any object pointer: its page descriptor stores the slab
 * index + 1 in Page.property (0 means "not a slub slab").
 */

#define SLUB_MIN_BUCKET   3                          /* 2^3  = 8 bytes   */
#define SLUB_MAX_BUCKET   12                         /* 2^12 = 4096 bytes */
#define SLUB_NBUCKETS     (SLUB_MAX_BUCKET - SLUB_MIN_BUCKET + 1)
#define SLUB_MAX_SLABS    512

struct slub_slab {
    void *freelist;             /* free object list, link stored in object[0] */
    uintptr_t base;             /* page base, kernel virtual address */
    struct Page *page;          /* page descriptor of this slab */
    unsigned int inuse;         /* allocated objects */
    unsigned int objects;       /* total objects in this slab */
    int bucket;                 /* size class index, -1 if unused */
    int on_partial;             /* linked into cache->partial ? */
    list_entry_t link;          /* partial list node */
};

struct slub_cache {
    unsigned int size;          /* object stride (power of two, >= 8) */
    unsigned int objects;       /* objects per page */
    struct slub_slab *current;  /* slab we allocate from first */
    list_entry_t partial;       /* slabs that still have free objects */
};

static struct slub_slab slabs[SLUB_MAX_SLABS];
static struct slub_cache caches[SLUB_NBUCKETS];
static size_t free_pages_base;

#define slab_from_link(le)  to_struct((le), struct slub_slab, link)

/* Round a request up to its size class; -1 means "not supported". */
static int
size_to_bucket(size_t size)
{
    int bits = 0;
    size_t v;

    if (size == 0 || size > PGSIZE) {
        return -1;
    }

    v = size - 1;
    while (v != 0) {
        v >>= 1;
        bits++;
    }
    if (bits < SLUB_MIN_BUCKET) {
        bits = SLUB_MIN_BUCKET;
    }
    return bits;
}

static struct slub_slab *
slab_desc_alloc(void)
{
    int i;

    for (i = 0; i < SLUB_MAX_SLABS; i++) {
        if (slabs[i].bucket < 0) {
            return &slabs[i];
        }
    }
    return NULL;
}

/* Take one page from the page allocator and split it into objects. */
static struct slub_slab *
slab_build(struct slub_cache *cache, int bucket)
{
    struct Page *page;
    struct slub_slab *s;
    uintptr_t base;
    unsigned int i;

    page = alloc_pages(1);
    if (page == NULL) {
        return NULL;
    }
    s = slab_desc_alloc();
    if (s == NULL) {
        free_page(page);
        return NULL;
    }

    base = page2pa(page) + va_pa_offset;

    s->freelist = NULL;
    s->base = base;
    s->page = page;
    s->inuse = 0;
    s->objects = cache->objects;
    s->bucket = bucket;
    s->on_partial = 0;
    list_init(&s->link);

    for (i = cache->objects; i > 0; i--) {
        void *obj = (void *)(base + (uintptr_t)(i - 1) * cache->size);

        *(void **)obj = s->freelist;
        s->freelist = obj;
    }

    ClearPageProperty(page);
    page->property = (unsigned int)(s - slabs) + 1;

    return s;
}

/* Give a slab's page back to the page allocator. */
static void
slab_release(struct slub_slab *s)
{
    struct Page *page = s->page;

    if (s->on_partial) {
        list_del_init(&s->link);
        s->on_partial = 0;
    }
    s->bucket = -1;
    s->page = NULL;
    s->freelist = NULL;
    s->inuse = 0;

    page->flags = 0;
    page->property = 0;
    free_page(page);
}

static void *
slab_pop(struct slub_slab *s)
{
    void *obj = s->freelist;

    s->freelist = *(void **)obj;
    s->inuse++;
    return obj;
}

static void
slab_push(struct slub_slab *s, void *obj)
{
    *(void **)obj = s->freelist;
    s->freelist = obj;
    s->inuse--;
}

void
slub_init(void)
{
    int i;

    for (i = 0; i < SLUB_NBUCKETS; i++) {
        caches[i].size = 1u << (SLUB_MIN_BUCKET + i);
        caches[i].objects = PGSIZE / caches[i].size;
        caches[i].current = NULL;
        list_init(&caches[i].partial);
    }
    for (i = 0; i < SLUB_MAX_SLABS; i++) {
        slabs[i].freelist = NULL;
        slabs[i].base = 0;
        slabs[i].page = NULL;
        slabs[i].inuse = 0;
        slabs[i].objects = 0;
        slabs[i].bucket = -1;
        slabs[i].on_partial = 0;
        list_init(&slabs[i].link);
    }
    free_pages_base = nr_free_pages();
}

void *
slub_alloc(size_t size)
{
    int bucket = size_to_bucket(size);
    struct slub_cache *cache;
    struct slub_slab *s;
    list_entry_t *le;

    if (bucket < 0) {
        return NULL;
    }
    cache = &caches[bucket - SLUB_MIN_BUCKET];

    /* fast path: allocate from the current slab */
    s = cache->current;
    if (s != NULL && s->freelist != NULL) {
        return slab_pop(s);
    }

    /* slow path 1: reuse a slab from the partial list */
    le = list_next(&cache->partial);
    while (le != &cache->partial) {
        struct slub_slab *ps = slab_from_link(le);

        if (ps->freelist != NULL) {
            list_del_init(&ps->link);
            ps->on_partial = 0;
            cache->current = ps;
            return slab_pop(ps);
        }
        le = list_next(le);
    }

    /* slow path 2: build a new slab from the page allocator */
    s = slab_build(cache, bucket);
    if (s == NULL) {
        return NULL;
    }
    cache->current = s;
    return slab_pop(s);
}

void
slub_free(void *ptr)
{
    uintptr_t va, pa, page_base, off;
    struct Page *page;
    struct slub_slab *s;
    struct slub_cache *cache;
    unsigned int idx;

    if (ptr == NULL) {
        return;
    }

    va = (uintptr_t)ptr;
    if (va < va_pa_offset) {
        warn("slub_free: 0x%lx is not a kernel address", va);
        return;
    }
    pa = va - va_pa_offset;
    if (pa < ((uintptr_t)nbase << PGSHIFT) ||
        pa >= ((uintptr_t)npage << PGSHIFT)) {
        warn("slub_free: 0x%lx is out of managed memory", va);
        return;
    }

    page = pa2page(pa);
    idx = page->property;
    if (idx == 0 || idx > SLUB_MAX_SLABS) {
        warn("slub_free: 0x%lx is not a slub object", va);
        return;
    }
    s = &slabs[idx - 1];
    page_base = va & ~((uintptr_t)PGSIZE - 1);
    if (s->bucket < 0 || s->page != page || s->base != page_base) {
        warn("slub_free: 0x%lx is not a slub object", va);
        return;
    }

    cache = &caches[s->bucket - SLUB_MIN_BUCKET];
    off = va - s->base;
    if (off % cache->size != 0 ||
        off >= (uintptr_t)s->objects * cache->size) {
        warn("slub_free: 0x%lx is not an object start", va);
        return;
    }

    slab_push(s, ptr);

    if (s == cache->current) {
        return;
    }
    if (s->inuse == 0) {
        slab_release(s);
        return;
    }
    if (!s->on_partial) {
        list_add(&cache->partial, &s->link);
        s->on_partial = 1;
    }
}

/* ------------------------------------------------------------------ */
/* self test                                                          */
/* ------------------------------------------------------------------ */

static void
slub_fail(const char *what)
{
    cprintf("[SLUB] %s: FAILED\n", what);
    panic("slub_check failed: %s", what);
}

static void
slub_pass(const char *what)
{
    cprintf("[SLUB] %s: passed\n", what);
}

static void
fill_pattern(void *p, size_t n, unsigned char seed)
{
    unsigned char *b = (unsigned char *)p;
    size_t i;

    for (i = 0; i < n; i++) {
        b[i] = (unsigned char)(seed + (unsigned char)(i * 7));
    }
}

static int
check_pattern(void *p, size_t n, unsigned char seed)
{
    unsigned char *b = (unsigned char *)p;
    size_t i;

    for (i = 0; i < n; i++) {
        if (b[i] != (unsigned char)(seed + (unsigned char)(i * 7))) {
            return 0;
        }
    }
    return 1;
}

/* pointers used by the cross-slab test */
static void *slub_test_ptrs[700];

/* Test 1: every size class, alignment and content. */
static void
slub_test_size_classes(void)
{
    static const size_t sizes[] = {
        1, 7, 8, 9, 16, 31, 32, 33, 64, 100, 127, 128,
        200, 255, 256, 511, 512, 1000, 1024, 2047,
        2048, 4000, 4095, 4096,
    };
    int i;

    for (i = 0; i < (int)(sizeof(sizes) / sizeof(sizes[0])); i++) {
        void *p = slub_alloc(sizes[i]);

        if (p == NULL) {
            slub_fail("size classes alloc");
        }
        if (((uintptr_t)p & 7u) != 0) {
            slub_fail("size classes alignment");
        }
        fill_pattern(p, sizes[i], (unsigned char)(i + 1));
        if (!check_pattern(p, sizes[i], (unsigned char)(i + 1))) {
            slub_fail("size classes content");
        }
        slub_free(p);
    }
    slub_pass("size classes 1..4096, alignment and content");
}

/* Test 2: 64 live 128B objects, spanning two slabs. */
static void
slub_test_many_same_size(void)
{
    enum { N = 64 };
    void *p[N];
    int i;

    for (i = 0; i < N; i++) {
        p[i] = slub_alloc(128);
        if (p[i] == NULL) {
            slub_fail("many same size alloc");
        }
        fill_pattern(p[i], 128, (unsigned char)(i + 1));
    }
    for (i = 0; i < N; i++) {
        if (!check_pattern(p[i], 128, (unsigned char)(i + 1))) {
            slub_fail("many same size content");
        }
    }
    for (i = 0; i < N; i++) {
        slub_free(p[i]);
    }
    slub_pass("64 x 128B objects across two slabs");
}

/* Test 3: 700 x 8B objects cross a slab boundary. */
static void
slub_test_cross_slab(void)
{
    enum { N = 700 };
    int i;

    if (N > (int)(sizeof(slub_test_ptrs) / sizeof(slub_test_ptrs[0]))) {
        slub_fail("cross slab table size");
    }
    for (i = 0; i < N; i++) {
        slub_test_ptrs[i] = slub_alloc(8);
        if (slub_test_ptrs[i] == NULL) {
            slub_fail("cross slab alloc");
        }
        *(unsigned long *)slub_test_ptrs[i] =
            0x1234567800000000UL + (unsigned long)i;
    }
    for (i = 0; i < N; i++) {
        if (*(unsigned long *)slub_test_ptrs[i] !=
            0x1234567800000000UL + (unsigned long)i) {
            slub_fail("cross slab content");
        }
    }
    for (i = 0; i < N; i++) {
        slub_free(slub_test_ptrs[i]);
    }
    slub_pass("700 x 8B objects crossing a slab boundary");
}

/* Test 4: repeated alloc/free must reuse objects, not pages. */
static void
slub_test_reuse_stress(void)
{
    size_t before;
    void *p0;
    int i;

    p0 = slub_alloc(256);
    if (p0 == NULL) {
        slub_fail("stress warmup alloc");
    }
    slub_free(p0);
    before = nr_free_pages();

    for (i = 0; i < 200; i++) {
        void *p = slub_alloc(256);
        unsigned long v = (unsigned long)i * 2654435761UL;

        if (p == NULL) {
            slub_fail("stress alloc");
        }
        *(unsigned long *)p = v;
        if (*(unsigned long *)p != v) {
            slub_fail("stress content");
        }
        slub_free(p);
    }
    if (nr_free_pages() != before) {
        slub_fail("stress page growth");
    }
    slub_pass("200 alloc/free cycles without page growth");
}

/* Test 5: cross size isolation with reordered frees. */
static void
slub_test_isolation(void)
{
    void *a = slub_alloc(8);
    void *b = slub_alloc(128);
    void *c = slub_alloc(1024);
    void *d = slub_alloc(2048);

    if (a == NULL || b == NULL || c == NULL || d == NULL) {
        slub_fail("isolation alloc");
    }
    fill_pattern(a, 8, 1);
    fill_pattern(b, 128, 2);
    fill_pattern(c, 1024, 3);
    fill_pattern(d, 2048, 4);

    slub_free(c);
    slub_free(a);
    if (!check_pattern(b, 128, 2) || !check_pattern(d, 2048, 4)) {
        slub_fail("isolation content");
    }
    slub_free(d);
    slub_free(b);
    slub_pass("cross size isolation with reordered frees");
}

/* Test 6: whole page object (4096). */
static void
slub_test_page_size(void)
{
    void *p;

    p = slub_alloc(PGSIZE);
    if (p == NULL) {
        slub_fail("page size alloc");
    }
    if (((uintptr_t)p & (PGSIZE - 1)) != 0) {
        slub_fail("page size alignment");
    }
    fill_pattern(p, PGSIZE, 0x5a);
    if (!check_pattern(p, PGSIZE, 0x5a)) {
        slub_fail("page size content");
    }
    slub_free(p);

    p = slub_alloc(PGSIZE);
    if (p == NULL) {
        slub_fail("page size realloc");
    }
    fill_pattern(p, PGSIZE, 0xa5);
    if (!check_pattern(p, PGSIZE, 0xa5)) {
        slub_fail("page size realloc content");
    }
    slub_free(p);
    slub_pass("whole-page object (4096) alloc/free/realloc");
}

/* Test 7: invalid requests. */
static void
slub_test_invalid(void)
{
    if (slub_alloc(0) != NULL) {
        slub_fail("invalid alloc size 0");
    }
    if (slub_alloc(PGSIZE + 1) != NULL) {
        slub_fail("invalid alloc size > PGSIZE");
    }
    slub_free(NULL);
    slub_pass("invalid requests (0, >PGSIZE, NULL free)");
}

/* Test 8: page conservation. */
static void
slub_test_conservation(void)
{
    size_t now = nr_free_pages();
    size_t delta = (now < free_pages_base) ? (free_pages_base - now) : 0;

    cprintf("[SLUB] page conservation: base=%lu now=%lu delta=%lu (<= %d)\n",
            free_pages_base, now, delta, SLUB_NBUCKETS);
    if (delta > (size_t)SLUB_NBUCKETS) {
        slub_fail("page conservation");
    }
    slub_pass("page conservation after releasing everything");
}

void
slub_check(void)
{
    cprintf("[SLUB] slub_check start, size classes 8..4096\n");
    slub_test_size_classes();
    slub_test_many_same_size();
    slub_test_cross_slab();
    slub_test_reuse_stress();
    slub_test_isolation();
    slub_test_page_size();
    slub_test_invalid();
    slub_test_conservation();
    cprintf("SLUB check passed!\n");
}
