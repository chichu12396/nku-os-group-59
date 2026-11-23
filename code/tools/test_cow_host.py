#!/usr/bin/env python3
"""Check COW memory helpers on a 64-bit Linux host, without booting ucore.

Run from any directory: python3 lab5/code/tools/test_cow_host.py
Requires gcc and its UndefinedBehaviorSanitizer runtime. Actual project C
function bodies and headers are used; allocation, CSR accesses and TLB fences
are simulated. This does not verify real page faults, fork/exec/wait/exit,
RISC-V hardware behavior, or the final make grade results.
"""

from pathlib import Path
import re
import subprocess
import tempfile


def run_checks(root, out):
    (out/'riscv.h').write_text('''#ifndef COW_HOST_RISCV_H
    #define COW_HOST_RISCV_H
    #define SSTATUS_SIE 2
    #define SSTATUS_SPP 0x100
    #define CAUSE_USER_ECALL 8
    #define CAUSE_ILLEGAL_INSTRUCTION 2
    #define CAUSE_BREAKPOINT 3
    #define CAUSE_STORE_PAGE_FAULT 15
    #define CAUSE_LOAD_PAGE_FAULT 13
    #define CAUSE_FETCH_PAGE_FAULT 12
    extern unsigned long long test_sstatus;
    #define read_csr(reg) test_sstatus
    #endif
    ''')
    def extract(relative_path, name):
        source_text = (root / relative_path).read_text()
        pattern = (
            r'(?m)^(?:static\s+(?:inline\s+)?)?'
            r'(?:int|void|bool|pte_t \*|struct Page \*|struct vma_struct \*)\s*'
            + re.escape(name) + r'\('
        )
        match = re.search(pattern, source_text)
        if match is None:
            raise RuntimeError(f"Cannot find {name} in {relative_path}")
        opening = source_text.index('{', match.start())
        depth = 1
        ending = opening + 1
        while depth and ending < len(source_text):
            if source_text[ending] == '{':
                depth += 1
            elif source_text[ending] == '}':
                depth -= 1
            ending += 1
        if depth:
            raise RuntimeError(f"Cannot locate the end of {name}")
        return source_text[match.start():ending] + '\n'
    # Use actual project functions/headers; only emulate CPU registers, allocation,
    # direct physical memory, and TLB invalidation. No fork/exit implementation stub
    # is used as proof of whole-system behavior.
    source='''#include <pmm.h>
    #include <vmm.h>
    #include <proc.h>
    #include <trap.h>
    #include <string.h>
    #include <error.h>
    #include <stdio.h>
    extern long write(int, const void *, unsigned long);
    extern void _exit(int) __attribute__((noreturn));
    unsigned long long test_sstatus = SSTATUS_SIE;
    void intr_enable(void) { test_sstatus |= SSTATUS_SIE; }
    void intr_disable(void) { test_sstatus &= ~SSTATUS_SIE; }
    void __panic(const char *f, int line, const char *fmt, ...) {
        char buf[160];
        int n=snprintf(buf,sizeof(buf),"FAIL %s:%d %s\\n",f,line,fmt);
        write(2,buf,n); _exit(1);
    }
    #define COUNT 128
    static unsigned char memory[COUNT][PGSIZE] __attribute__((aligned(PGSIZE)));
    static struct Page descriptors[COUNT];
    struct Page *pages=descriptors;
    const size_t nbase=0x80000000ULL/PGSIZE;
    size_t npage=0x80000000ULL/PGSIZE+COUNT;
    uint_t va_pa_offset;
    static unsigned char used[COUNT];
    static int budget=-1, allocations, tlbs, checks, full_fences;
    struct Page *alloc_pages(size_t n) {
        assert(n==1);
        if (budget==0) return NULL;
        if (budget>0) budget--;
        for (int i=0;i<COUNT;i++) if (!used[i]) {
            used[i]=1; allocations++; descriptors[i].ref=0;
            memset(memory[i],0,PGSIZE); return &descriptors[i];
        }
        return NULL;
    }
    void free_pages(struct Page *p,size_t n) {
        assert(n==1); int i=p-pages;
        assert(i>=0 && i<COUNT && used[i] && p->ref==0); used[i]=0;
    }
    size_t nr_free_pages(void) {
        size_t n=0; for(int i=0;i<COUNT;i++) n+=!used[i]; return n;
    }
    void tlb_invalidate(pde_t *pgdir,uintptr_t addr) { tlbs++; }
    void cow_test_flush_tlb(void) { full_fences++; }
    struct proc_struct *current;
    int do_exit(int code) { panic("unexpected do_exit"); }
    void syscall(void) { panic("unexpected syscall"); }
    void print_trapframe(struct trapframe *tf) { }
    int cprintf(const char *fmt, ...) { return 0; }
    '''
    for name in ['get_pte','get_page','page_remove_pte','page_insert','page_remove','copy_range','unmap_range','page_table_empty','exit_range']:
     source+=extract('kern/mm/pmm.c',name).replace('flush_tlb();', 'cow_test_flush_tlb();')
    for name in ['find_vma','user_mem_check','do_cow_fault','copy_to_user','exit_mmap']:
     source+=extract('kern/mm/vmm.c',name)
    for name in ['trap_in_kernel','exception_handler']:
     source+=extract('kern/trap/trap.c',name)
    source+='''
    #define CHECK(x) do { checks++; assert(x); } while(0)
    #define VA ((uintptr_t)0x800000)
    static struct mm_struct mms[4];
    static struct vma_struct vmas[4];
    static struct proc_struct proc;
    static void setup(void) {
        memset(used,0,sizeof(used)); memset(descriptors,0,sizeof(descriptors));
        memset(mms,0,sizeof(mms)); memset(vmas,0,sizeof(vmas));
        budget=-1; allocations=tlbs=full_fences=0; test_sstatus=SSTATUS_SIE;
        for(int i=0;i<4;i++) {
            struct Page *root=alloc_page(); CHECK(root!=NULL);
            mms[i].pgdir=page2kva(root);
            mms[i].pgdir[511]=pte_create(0,PTE_R|PTE_W|PTE_X);
            list_init(&mms[i].mmap_list);
            vmas[i].vm_start=VA; vmas[i].vm_end=VA+4*PTSIZE;
            vmas[i].vm_flags=VM_READ|VM_WRITE|VM_EXEC;
            list_add(&mms[i].mmap_list,&vmas[i].list_link);
        }
        current=&proc;
    }
    static struct Page *map(int i,uintptr_t va,uint32_t perm) {
        struct Page *p=alloc_page(); CHECK(p!=NULL);
        memset(page2kva(p),0x5a,PGSIZE);
        CHECK(page_insert(mms[i].pgdir,p,va,perm)==0); return p;
    }
    static pte_t entry(int i,uintptr_t va) {
        pte_t *p=get_pte(mms[i].pgdir,va,0); return p?*p:0;
    }
    static void destroy(int i) {
        pde_t *root=mms[i].pgdir;
        exit_mmap(&mms[i]);
        CHECK(root[0]==0 && root[1]==0);
        CHECK(root[511]==pte_create(0,PTE_R|PTE_W|PTE_X));
        free_page(pa2page((uintptr_t)root-va_pa_offset));
    }
    static void finish(void) {
        for(int i=0;i<4;i++) destroy(i);
        CHECK(nr_free_pages()==COUNT); CHECK(test_sstatus==SSTATUS_SIE);
    }
    int main(void) {
        va_pa_offset=(uintptr_t)memory-0x80000000ULL;
        setup();
        struct Page *p=map(0,VA,PTE_U|PTE_R|PTE_W);
        struct Page *ro=map(0,VA+PGSIZE,PTE_U|PTE_R|PTE_X);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+3*PGSIZE,1)==0);
        CHECK(page_ref(p)==2 && page_ref(ro)==2);
        CHECK((entry(0,VA)&(PTE_COW|PTE_W))==PTE_COW);
        CHECK(entry(0,VA)==entry(1,VA));
        CHECK(!(entry(1,VA+PGSIZE)&(PTE_COW|PTE_W)));
        CHECK(entry(1,VA+2*PGSIZE)==0);
        struct trapframe tf; memset(&tf,0,sizeof(tf));
        tf.cause=CAUSE_STORE_PAGE_FAULT; tf.epc=0x123456; tf.tval=VA+7;
        tf.gpr.a0=0xface; current->mm=&mms[1];
        exception_handler(&tf);
        CHECK(tf.epc==0x123456 && tf.gpr.a0==0xface);
        struct Page *private=get_page(mms[1].pgdir,VA,0);
        CHECK(private!=p && page_ref(private)==1 && page_ref(p)==1);
        CHECK((entry(1,VA)&(PTE_COW|PTE_W))==PTE_W);
        CHECK(memcmp(page2kva(private),page2kva(p),PGSIZE)==0);
        ((unsigned char*)page2kva(private))[7]=0xa5;
        CHECK(((unsigned char*)page2kva(p))[7]==0x5a);
        int before=allocations;
        CHECK(do_cow_fault(&mms[0],VA+8)==0);
        CHECK(allocations==before && get_page(mms[0].pgdir,VA,0)==p);
        CHECK((entry(0,VA)&(PTE_COW|PTE_W))==PTE_W);
        CHECK((entry(0,VA)&(PTE_A|PTE_D))==(PTE_A|PTE_D));
        CHECK(do_cow_fault(&mms[1],VA)==-E_INVAL);
        CHECK(do_cow_fault(&mms[1],VA+PGSIZE)==-E_INVAL);
        CHECK(do_cow_fault(&mms[1],VA+2*PGSIZE)==-E_INVAL);
        CHECK(do_cow_fault(NULL,VA)==-E_INVAL);
        CHECK(do_cow_fault(&mms[1],0)==-E_INVAL);
        CHECK(do_cow_fault(&mms[1],(uintptr_t)-1)==-E_INVAL);
        finish();

        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W|PTE_X);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==0);
        CHECK(copy_range(mms[2].pgdir,mms[1].pgdir,VA,VA+PGSIZE,1)==0);
        CHECK(page_ref(p)==3 && entry(0,VA)==entry(2,VA));
        CHECK(do_cow_fault(&mms[1],VA)==0 && page_ref(p)==2);
        CHECK(do_cow_fault(&mms[0],VA)==0 && page_ref(p)==1);
        before=allocations;
        CHECK(do_cow_fault(&mms[2],VA)==0 && allocations==before);
        CHECK(entry(2,VA)&PTE_X);
        finish();

        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,0)==0);
        CHECK(get_page(mms[1].pgdir,VA,0)!=p && page_ref(p)==1);
        CHECK((entry(1,VA)&(PTE_COW|PTE_W))==PTE_W);
        CHECK(copy_range(mms[2].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==0);
        CHECK(copy_range(mms[3].pgdir,mms[0].pgdir,VA,VA+PGSIZE,0)==0);
        CHECK((entry(3,VA)&(PTE_COW|PTE_W))==PTE_W);
        CHECK((entry(0,VA)&(PTE_COW|PTE_W))==PTE_COW && page_ref(p)==2);
        finish();

        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        pte_t original=entry(0,VA); budget=0;
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==-E_NO_MEM);
        CHECK(entry(0,VA)==original && page_ref(p)==1);
        budget=-1;
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==0);
        original=entry(1,VA); budget=0;
        CHECK(do_cow_fault(&mms[1],VA)==-E_NO_MEM);
        CHECK(entry(1,VA)==original && page_ref(p)==2);
        budget=-1;
        vmas[1].vm_flags=VM_READ;
        CHECK(do_cow_fault(&mms[1],VA)==-E_INVAL);
        vmas[1].vm_flags=VM_READ|VM_WRITE|VM_STACK;
        CHECK(do_cow_fault(&mms[1],VA)==-E_INVAL);
        vmas[1].vm_flags=VM_READ|VM_WRITE;
        *get_pte(mms[1].pgdir,VA,0)&=~PTE_U;
        CHECK(do_cow_fault(&mms[1],VA)==-E_INVAL);
        finish();

        setup(); uintptr_t cross=VA+PTSIZE-PGSIZE;
        p=map(0,cross,PTE_U|PTE_R|PTE_W);
        struct Page *p2=map(0,cross+PGSIZE,PTE_U|PTE_R|PTE_W);
        budget=2;
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,cross,cross+2*PGSIZE,1)==-E_NO_MEM);
        CHECK(page_ref(p)==2 && page_ref(p2)==1);
        CHECK((entry(0,cross)&(PTE_COW|PTE_W))==PTE_COW);
        CHECK((entry(0,cross+PGSIZE)&(PTE_COW|PTE_W))==PTE_W);
        page_remove(mms[1].pgdir,cross);
        budget=-1; before=allocations;
        CHECK(do_cow_fault(&mms[0],cross)==0 && allocations==before);
        finish();

        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        p2=map(1,VA,PTE_U|PTE_R|PTE_W);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==-E_INVAL);
        CHECK(get_page(mms[1].pgdir,VA,0)==p2 && page_ref(p)==1);
        CHECK(copy_range(mms[0].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==-E_INVAL);
        CHECK(copy_range(mms[2].pgdir,mms[0].pgdir,VA+PTSIZE,VA+2*PTSIZE,1)==0);
        CHECK(test_sstatus==SSTATUS_SIE && tlbs>0);
        finish();

        /* Kernel copies cross page boundaries and target a non-active mm. */
        setup();
        p=map(0,VA,PTE_U|PTE_R|PTE_W);
        p2=map(0,VA+PGSIZE,PTE_U|PTE_R|PTE_W);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+2*PGSIZE,1)==0);
        char input[16]; memset(input,0x37,sizeof(input));
        current->mm=&mms[0];
        CHECK(copy_to_user(&mms[1],(void*)(VA+PGSIZE-4),input,12));
        struct Page *c1=get_page(mms[1].pgdir,VA,0);
        struct Page *c2=get_page(mms[1].pgdir,VA+PGSIZE,0);
        CHECK(c1!=p && c2!=p2 && page_ref(p)==1 && page_ref(p2)==1);
        CHECK(memcmp((char*)page2kva(c1)+PGSIZE-4,input,4)==0);
        CHECK(memcmp(page2kva(c2),input+4,8)==0);
        CHECK(((unsigned char*)page2kva(p))[PGSIZE-4]==0x5a);
        CHECK(((unsigned char*)page2kva(p2))[0]==0x5a);
        CHECK(((unsigned char*)page2kva(c1))[PGSIZE-5]==0x5a);
        CHECK(((unsigned char*)page2kva(c2))[8]==0x5a);
        CHECK((entry(1,VA)&(PTE_A|PTE_D))==(PTE_A|PTE_D));
        before=allocations;
        CHECK(copy_to_user(&mms[0],(void*)VA,input,4));
        CHECK(allocations==before && get_page(mms[0].pgdir,VA,0)==p);
        CHECK(copy_to_user(NULL,NULL,NULL,0));
        CHECK(!copy_to_user(&mms[1],(void*)(VA+2*PGSIZE),input,4));
        CHECK(!copy_to_user(&mms[1],(void*)(uintptr_t)-2,input,4));
        CHECK(!copy_to_user(&mms[1],(void*)0,input,4));
        CHECK(!copy_to_user(NULL,(void*)VA,input,4));
        finish();

        /* A failed preparation must not copy a prefix of the source bytes. */
        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        p2=map(0,VA+PGSIZE,PTE_U|PTE_R|PTE_W);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+2*PGSIZE,1)==0);
        budget=1;
        CHECK(!copy_to_user(&mms[1],(void*)(VA+PGSIZE-4),input,12));
        c1=get_page(mms[1].pgdir,VA,0);
        CHECK(c1!=p && get_page(mms[1].pgdir,VA+PGSIZE,0)==p2);
        CHECK(((unsigned char*)page2kva(c1))[PGSIZE-4]==0x5a);
        CHECK(((unsigned char*)page2kva(p2))[0]==0x5a);
        CHECK(page_ref(p)==1 && page_ref(p2)==2);
        budget=-1;
        finish();

        setup(); p=map(0,VA,PTE_U|PTE_R);
        CHECK(!copy_to_user(&mms[0],(void*)VA,input,4));
        CHECK(((unsigned char*)page2kva(p))[0]==0x5a);
        *get_pte(mms[0].pgdir,VA,0)|=PTE_W;
        CHECK(copy_to_user(&mms[0],(void*)VA,input,4));
        CHECK((entry(0,VA)&(PTE_A|PTE_D))==(PTE_A|PTE_D));
        *get_pte(mms[0].pgdir,VA,0)&=~PTE_U;
        CHECK(!copy_to_user(&mms[0],(void*)VA,input,4));
        finish();

        /* Freeing one region must preserve live sibling page tables. */
        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        p2=map(0,VA+PTSIZE,PTE_U|PTE_R|PTE_W);
        pte_t middle=mms[0].pgdir[PDX1(VA)];
        unmap_range(mms[0].pgdir,VA,VA+PGSIZE);
        exit_range(mms[0].pgdir,VA,VA+PGSIZE);
        CHECK(mms[0].pgdir[PDX1(VA)]==middle);
        CHECK(get_page(mms[0].pgdir,VA+PTSIZE,0)==p2 && page_ref(p2)==1);
        CHECK(full_fences>0);
        unmap_range(mms[0].pgdir,VA+PTSIZE,VA+PTSIZE+PGSIZE);
        exit_range(mms[0].pgdir,VA+PTSIZE,VA+PTSIZE+PGSIZE);
        CHECK(mms[0].pgdir[PDX1(VA)]==0);
        finish();

        /* Failed page-table allocation, with no VMA for the partial range. */
        setup(); budget=1;
        CHECK(get_pte(mms[0].pgdir,VA,1)==NULL);
        CHECK(mms[0].pgdir[PDX1(VA)]!=0);
        list_init(&mms[0].mmap_list); budget=-1;
        finish();

        /* All user mappings must be reclaimed even before their VMA is linked. */
        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        list_init(&mms[0].mmap_list);
        finish();

        /* Exit order: a child's removal cannot release the parent's COW page. */
        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==0);
        exit_mmap(&mms[1]);
        CHECK(page_ref(p)==1 && get_page(mms[0].pgdir,VA,0)==p);
        before=allocations;
        CHECK(do_cow_fault(&mms[0],VA)==0 && allocations==before);
        finish();

        /* Parent first, and an initially disabled interrupt state. */
        setup(); p=map(0,VA,PTE_U|PTE_R|PTE_W);
        CHECK(copy_range(mms[1].pgdir,mms[0].pgdir,VA,VA+PGSIZE,1)==0);
        test_sstatus=0;
        exit_mmap(&mms[0]);
        CHECK(test_sstatus==0 && page_ref(p)==1);
        CHECK(copy_to_user(&mms[1],(void*)VA,input,4));
        CHECK(test_sstatus==0);
        test_sstatus=SSTATUS_SIE;
        finish();
        char buf[120];
        int n=snprintf(buf,sizeof(buf),"COW host-isolated checks: %d PASS (CPU/TLB emulated).\\n",checks);
        write(1,buf,n); return 0;
    }
    '''
    (out/'check.c').write_text(source)
    includes = [out, root / 'libs'] + [
        root / 'kern' / directory for directory in
        ['mm', 'debug', 'sync', 'driver', 'schedule', 'process', 'trap', 'syscall']
    ]
    cmd = [
        'gcc', '-O2', '-g', '-std=gnu99', '-fno-builtin', '-D__riscv_xlen=64',
        '-fsanitize=undefined', '-fno-sanitize-recover=all',
        '-Wall', '-Wno-unused', '-Werror',
    ]
    cmd += ['-I' + str(directory) for directory in includes]
    cmd += [str(out / 'check.c'), '-o', str(out / 'check')]
    subprocess.run(cmd, check=True)
    subprocess.run([str(out / 'check')], check=True)


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="lab5-cow-host-") as directory:
        run_checks(root, Path(directory))


if __name__ == "__main__":
    main()
