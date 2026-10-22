#ifndef __KERN_MM_SLUB_H__
#define __KERN_MM_SLUB_H__

#include <defs.h>

/*
 * Simplified two-layer SLUB allocator.
 *
 *  - layer 1: the physical page allocator (alloc_pages/free_pages)
 *  - layer 2: fixed-size object caches built on top of single pages
 *
 * slub_init()/slub_check() are called from pmm_init() when LAB2_SLUB is
 * defined; slub_alloc()/slub_free() provide arbitrary-size allocation.
 */

void  slub_init(void);
void  slub_check(void);
void *slub_alloc(size_t size);
void  slub_free(void *ptr);

#endif /* !__KERN_MM_SLUB_H__ */
