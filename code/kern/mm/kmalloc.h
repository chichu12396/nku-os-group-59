#ifndef __KERN_MM_KMALLOC_H__
#define __KERN_MM_KMALLOC_H__

#include <defs.h>

#define KMALLOC_MAX_ORDER 10

void kmalloc_init(void);

void *kmalloc(size_t n);
void kfree(void *objp);

size_t kallocated(void);

// SLOB arena 当前占用（且不会归还）的物理页数。
// init_main 用它把堆保留页从“空闲页恢复”检查中单独扣除。
size_t slob_arena_pages(void);

#endif /* !__KERN_MM_KMALLOC_H__ */
