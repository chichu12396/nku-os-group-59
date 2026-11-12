#ifndef __KERN_PROCESS_PROC_H__
#define __KERN_PROCESS_PROC_H__

#include <defs.h>
#include <list.h>
#include <trap.h>
#include <memlayout.h>

// process's state in his life cycle
enum proc_state
{
    PROC_UNINIT = 0, // uninitialized	PCB 已创建，还没有完成初始化
    PROC_SLEEPING,   // sleeping	等待某个条件，暂时不能运行
    PROC_RUNNABLE,   // runnable(maybe running)可以运行，包括正在运行和等待 CPU 的线程
    PROC_ZOMBIE,     // almost dead, and wait parent proc to reclaim his resource已结束执行，等待回收资源
};

struct context
{
    uintptr_t ra;
    uintptr_t sp;
    uintptr_t s0;
    uintptr_t s1;
    uintptr_t s2;
    uintptr_t s3;
    uintptr_t s4;
    uintptr_t s5;
    uintptr_t s6;
    uintptr_t s7;
    uintptr_t s8;
    uintptr_t s9;
    uintptr_t s10;
    uintptr_t s11;
};

#define PROC_NAME_LEN 15
#define MAX_PROCESS 4096
#define MAX_PID (MAX_PROCESS * 2)

extern list_entry_t proc_list;

struct proc_struct //进程控制块 PCB
{
    enum proc_state state;        // Process state线程的生命周期状态
    int pid;                      // Process ID 线程的身份编号用于区分不同线程、查找 PCB。
    int runs;                     // the running times of Proces被调度选中的次数
    uintptr_t kstack;             // Process kernel stack内核栈的起始地址
    volatile bool need_resched;   // bool value: need to be rescheduled to release CPU?是否请求重新调度
    struct proc_struct *parent;   // the parent process 父线程的 PCB 指针
    struct mm_struct *mm;         // Process's memory management field用户虚拟地址空间的管理信息
    struct context context;       // Switch here to run process线程切换时保存的现场
    struct trapframe *tf;         // Trap frame for current interrupt指向 Trap 现场的指针
    uintptr_t pgdir;              // the base addr of Page Directroy Table(PDT)页表根的物理地址=boot_pgdir_pa
    uint32_t flags;               // Process flag附加标志位(没用)
    char name[PROC_NAME_LEN + 1]; // Process name线程名称
    list_entry_t list_link;       // Process link list连接到进程总链表的节点
    list_entry_t hash_link;       // Process hash list连接到 PID 哈希表的节点
};

#define le2proc(le, member) \
    to_struct((le), struct proc_struct, member)

extern struct proc_struct *idleproc, *initproc, *current;//空闲线程，第一个内核线程，正在运行的线程

void proc_init(void);
void proc_run(struct proc_struct *proc);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);

char *set_proc_name(struct proc_struct *proc, const char *name);
char *get_proc_name(struct proc_struct *proc);
void cpu_idle(void) __attribute__((noreturn));

struct proc_struct *find_proc(int pid);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
int do_exit(int error_code);

#endif /* !__KERN_PROCESS_PROC_H__ */
