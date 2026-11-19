#ifndef __KERN_MM_MMU_H__
#define __KERN_MM_MMU_H__

#ifndef __ASSEMBLER__
#include <defs.h>
#endif /* !__ASSEMBLER__ */

// A linear address 'la' has a three-part structure as follows:
//
// +--------10------+-------10-------+---------12----------+
// | Page Directory |   Page Table   | Offset within Page  |
// |      Index     |     Index      |                     |
// +----------------+----------------+---------------------+
//  \--- PDX(la) --/ \--- PTX(la) --/ \---- PGOFF(la) ----/
//  \----------- PPN(la) -----------/
//
//  38           30 29           21 20           12 11          0
// ┌───────────────┬───────────────┬───────────────┬──────────────┐
// │  VPN[2]，9位  │  VPN[1]，9位   │  VPN[0]，9位  │ 页内偏移12位  │
// └───────────────┴───────────────┴───────────────┴──────────────┘
//     PDX1(la)        PDX0(la)         PTX(la)        PGOFF(la)
// The PDX, PTX, PGOFF, and PPN macros decompose linear addresses as shown.
// To construct a linear address la from PDX(la), PTX(la), and PGOFF(la),
// use PGADDR(PDX(la), PTX(la), PGOFF(la)).
//物理页号 PPN 位于页表项的 第 53～10 位；
// RISC-V uses 32-bit virtual address to access 34-bit physical address!
// Sv32 page table entry:
// +---------12----------+--------10-------+---2----+-------8-------+
// |       PPN[1]        |      PPN[0]     |Reserved|D|A|G|U|X|W|R|V|
// +---------12----------+-----------------+--------+---------------+

// page directory index页目录索引
#define PDX1(la) ((((uintptr_t)(la)) >> PDX1SHIFT) & 0x1FF)
#define PDX0(la) ((((uintptr_t)(la)) >> PDX0SHIFT) & 0x1FF)

// page table index页表索引
#define PTX(la) ((((uintptr_t)(la)) >> PTXSHIFT) & 0x1FF)

// page number field of address提取地址中的页号部分。
#define PPN(la) (((uintptr_t)(la)) >> PTXSHIFT)

// offset in page提取页内偏移
#define PGOFF(la) (((uintptr_t)(la)) & 0xFFF)

// construct linear address from indexes and offset提取页内偏移
#define PGADDR(d1, d0, t, o) ((uintptr_t)((d1) << PDX1SHIFT |(d0) << PDX0SHIFT | (t) << PTXSHIFT | (o)))

// address in page table or page directory entry提取页表项或页目录项中记录的地址
// 提取出来的地址可能指向：
// - 下一级页表，如果当前项是非叶子项；
// - 实际映射的物理页基址，如果当前项是叶子项。
#define PTE_ADDR(pte)   (((uintptr_t)(pte) & ~0x3FF) << (PTXSHIFT - PTE_PPN_SHIFT))
#define PDE_ADDR(pde)   PTE_ADDR(pde)
// 物理页基址 = PTE_ADDR(*ptep);
// 最终物理地址 = PTE_ADDR(*ptep) + PGOFF(la);
/* page directory and page table constants */
#define NPDEENTRY       512                    // page directory entries per page directory
#define NPTEENTRY       512                    // page table entries per page table

#define PGSIZE          4096                    // bytes mapped by a page
#define PGSHIFT         12                      // log2(PGSIZE)
#define PTSIZE          (PGSIZE * NPTEENTRY)    // bytes mapped by a page directory entry
#define PTSHIFT         21                      // log2(PTSIZE)

#define PTXSHIFT        12                      // offset of PTX in a linear address
#define PDX0SHIFT       21                      // offset of PDX in a linear address
#define PDX1SHIFT		30
#define PTE_PPN_SHIFT   10                      // offset of PPN in a physical address

// page table entry (PTE) fields页表项中的权限和状态标志。
#define PTE_V     0x001 // Valid
#define PTE_R     0x002 // Read
#define PTE_W     0x004 // Write
#define PTE_X     0x008 // Execute
#define PTE_U     0x010 // User
#define PTE_G     0x020 // Global
#define PTE_A     0x040 // Accessed
#define PTE_D     0x080 // Dirty
#define PTE_SOFT  0x300 // Reserved for Software
// 最后的宏是常用权限组合。
#define PAGE_TABLE_DIR (PTE_V)
#define READ_ONLY (PTE_R | PTE_V)
#define READ_WRITE (PTE_R | PTE_W | PTE_V)
#define EXEC_ONLY (PTE_X | PTE_V)
#define READ_EXEC (PTE_R | PTE_X | PTE_V)
#define READ_WRITE_EXEC (PTE_R | PTE_W | PTE_X | PTE_V)

#define PTE_USER (PTE_R | PTE_W | PTE_X | PTE_U | PTE_V)

#endif /* !__KERN_MM_MMU_H__ */
