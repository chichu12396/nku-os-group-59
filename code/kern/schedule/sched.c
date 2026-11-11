#include <list.h>
#include <sync.h>
#include <proc.h>
#include <sched.h>
#include <assert.h>

void
wakeup_proc(struct proc_struct *proc) {
    assert(proc->state != PROC_ZOMBIE && proc->state != PROC_RUNNABLE);
    proc->state = PROC_RUNNABLE;
}

//LAB4 function3 2411033
void schedule(void)
{
    bool intr_flag;
    local_intr_save(intr_flag);

    // 本次开始处理调度请求。
    current->need_resched = 0;

    // 找不到可运行线程时，使用空闲线程兜底。
    struct proc_struct *next = idleproc;

    // idle 从链表头之后开始找，其他线程从自身的下一个节点开始找。
    list_entry_t *start = (current == idleproc)
                             ? &proc_list
                             : &current->list_link;
    list_entry_t *le = start;

    do
    {
        le = list_next(le);

        // 链表头只是哨兵节点，不对应线程。
        if (le != &proc_list)
        {
            struct proc_struct *proc = le2proc(le, list_link);

            if (proc->state == PROC_RUNNABLE)
            {
                next = proc;
                break;
            }
        }
    } while (le != start);

    // 记录目标线程被调度选中的次数。
    next->runs++;

    // 选中当前线程时，不需要切换现场。
    if (next != current)
    {
        proc_run(next);
    }

    local_intr_restore(intr_flag);
}

