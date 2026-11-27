### 功能模块：模块一——用户态系统调用

**负责人：** 2411033-季艾佳
#### 最终提示词

以下是最终使用的提示词，与第一次实际执行的输入完全相同：

````markdown
[PROMPT]
我正在实现 RISC-V ucore Lab5 的功能模块一：用户态系统调用。请在独立副本中修改 kern/syscall/syscall.c 和 kern/trap/trap.c，将用户 ecall、系统调用分发和九个系统调用包装函数接通。

实现方式：
- 先读下面列出的参考文件，使用项目真实的字段、编号和函数签名。
- 直接修改实际文件，保留 Lab5 标记、现有中断处理、trap() 的现场管理和退出及调度逻辑。
- 可以增加本文件内部的 static 辅助函数和必要头文件。不要改系统调用号、公开接口、Makefile、用户库、测试或其他成员负责的进程管理函数。
- 本次只做模块一，不实现 COW，也不重新实现已经适配的 RESTORE_ALL。
- 生成后先编译两个目标文件，再执行可用的模块测试，记录真实输出；其他模块未完成导致的链接或运行限制单独说明。

[RELY]
可以依赖的东西：
- 先读 kern/syscall/syscall.c、kern/syscall/syscall.h、kern/trap/trap.c、kern/trap/trap.h、kern/process/proc.h、kern/mm/vmm.h、kern/mm/vmm.c、kern/mm/pmm.h、kern/mm/mmu.h、libs/unistd.h、libs/error.h、user/libs/syscall.c 和 tools/test_lab5.c。
- 本项目 ABI：a0 是系统调用号，a1 到 a5 是参数，返回值写回 a0；不要使用 Linux 的 a7 调用号约定。
- current 指向当前 PCB，current->tf 指向正在处理的中断帧；中断帧使用 gpr、status、epc、tval、cause 字段。
- proc.h 已声明 do_exit(int)、do_fork(uint32_t, uintptr_t, struct trapframe *)、do_wait(int, int *)、do_execve(const char *, size_t, unsigned char *, size_t)、do_yield(void)、do_kill(int)。这些接口由其他模块实现，当前基线可能尚未补齐。
- 可使用 SYS_*、CAUSE_USER_ECALL、SSTATUS_SPP、E_INVAL、E_KILLED、user_mem_check、cputchar、cprintf、print_trapframe、trap_in_kernel，以及现有 Sv39 页表宏。
- 当前 pmm.h 只有 print_pgdir() 声明，没有实现。sys_pgdir 必须真正输出当前页表信息，可以在 syscall.c 内增加只读的 Sv39 遍历辅助函数，不要只打印成功文字或调用未实现的接口。
- proc->pgdir 保存根页表物理地址，访问页表内存需要转换为内核虚拟地址；Sv39 中非叶项与叶项要区分，高层叶项可能映射大页。

[GUARANTEE]
必须交付：
void exception_handler(struct trapframe *tf);
void syscall(void);
static int sys_exit(uint64_t arg[]);
static int sys_fork(uint64_t arg[]);
static int sys_wait(uint64_t arg[]);
static int sys_exec(uint64_t arg[]);
static int sys_yield(uint64_t arg[]);
static int sys_kill(uint64_t arg[]);
static int sys_getpid(uint64_t arg[]);
static int sys_putc(uint64_t arg[]);
static int sys_pgdir(uint64_t arg[]);

确保 syscalls[] 引用静态函数之前已有声明或定义。输出本次完整生成代码、修改位置、实际验证命令及结果，不省略函数体。

[SPECIFICATION]
1. exception_handler
Pre-Condition：tf 是有效中断帧；系统调用路径上 current->tf 已由 trap() 指向 tf。
Post-Condition：异常按类型处理，系统调用完成后能从 ecall 的下一条指令继续执行。
Case 1：CAUSE_USER_ECALL，将 epc 增加 4，然后调用 syscall()，不重复推进返回地址。
Case 2：用户非法指令、非法访存或其他未处理的用户异常，输出诊断并通过 do_exit 终止当前进程，不跳过错误继续执行，不使整个内核 panic。
Case 3：内核断点和非法指令保留原有诊断及按 2/4 字节推进 epc 的行为；其他无法处理的内核异常输出现场并 panic。
Requirements：不要用读取用户故障地址的方式判断错误指令长度；页故障的 COW 扩展留到后续任务。

2. syscall
Pre-Condition：current 和 current->tf 有效，调用号和参数已保存在中断帧中。
Post-Condition：合法请求调用对应表项，并将 int 返回值按 RV64 有符号结果写入 a0。
Case 1：调用号在表内且表项非空，按顺序取 a1 到 a5，调用处理函数。
Case 2：编号越界或表项未实现，返回 -E_INVAL，不越界访问，不 panic。
Requirements：使用中断帧中的原始调用号进行范围判断，调用处理函数前保存好参数。

3. sys_exit、sys_yield、sys_kill、sys_getpid
Pre-Condition：参数数组有效，current 有效。
Post-Condition：sys_exit 传递 arg[0] 的退出码；sys_yield 调用 do_yield；sys_kill 传递 arg[0] 的 PID；sys_getpid 返回 current->pid。需要转接的函数保留下层返回值，正常退出无需构造额外返回路径。

4. sys_fork
Pre-Condition：current->tf 保存父进程的用户执行现场。
Post-Condition：调用 do_fork，clone_flags 为 0，stack 使用当前中断帧保存的用户 sp，中断帧使用 current->tf；不在包装层重复创建或登记进程。

5. sys_wait、sys_exec
Pre-Condition：参数来自用户寄存器，用户地址不可信。
Post-Condition：sys_wait 将 arg[0]、arg[1] 转为 PID 和退出码存储指针；sys_exec 将 arg[0] 到 arg[3] 转为名称、名称长度、二进制地址和大小，交给对应 do_* 接口。
Case 1：wait 的退出码指针为 NULL，允许不接收退出码；非空时必须检查 int 大小的可写范围。
Case 2：exec 在访问用户数据前检查名称和二进制范围可读；参数语义、资源分配和清理由 do_execve 负责。
Case 3：用户内存范围或权限不合法，返回 -E_INVAL，不直接解引用该地址。下层仍须对真正执行的用户内存访问负责，包装层检查不能替代下层检查。

6. sys_putc、sys_pgdir
Pre-Condition：当前进程有效；查看页表时页表结构有效且可由内核访问。
Post-Condition：sys_putc 使用 cputchar 输出 arg[0] 的低 8 位并返回 0；sys_pgdir 只读遍历当前 Sv39 页表，输出实际有效项的级别、虚拟地址范围、物理地址和权限，成功返回 0，不分配、修改或释放映射。
Case 1：页表根不存在时返回 -E_INVAL；有根但无有效项时可以输出根信息并正常结束。
Case 2：非叶项继续向下查，叶项直接输出，包括高层大页映射，虚拟地址按 Sv39 规则符号扩展。

7. 验证
- 使用项目工具链编译 syscall.o 和 trap.o，检查声明、类型和链接依赖。
- 运行现有 test_lab5_syscall，检查 getpid、epc 增加 4、非法编号返回 -E_INVAL；补查参数转接、空表项、用户指针和页表输出。

````

### 功能模块：模块二、三——用户程序创建与加载、用户进程复制

**负责人：** 2412102-聂海丽
#### 最终提示词

以下是最终使用的提示词：

````markdown
[PROMPT]
我正在实现 RISC-V ucore Lab5 的功能模块二：用户程序创建与加载，以及功能模块三：用户进程复制。请在独立副本中修改 kern/process/proc.c、kern/mm/vmm.c 和 kern/mm/pmm.c，把 B 负责的 //lab5 function2、function3 区域接通。

实现方式：
- 先读下面列出的参考文件，使用项目真实的字段、编号和函数签名。
- 直接修改实际文件，只填写 //lab5 function2、function3 标记的区域，保留 Lab5 标记，把 YOUR CODE 替换为学号 2412102。
- 复用现有结构、头文件和函数签名，不新增并行接口；不要修改属于其他成员负责的函数、Makefile、用户库和测试。
- 输出可直接编译的完整函数，不要伪代码；每个函数附简短中文注释，说明关键状态、页表或寄存器处理。
- 在每个函数末尾说明失败路径会释放哪些资源。
- 生成后先编译，再运行可用的模块测试与用户程序，记录真实输出；其他模块未完成导致的链接或运行限制单独说明。
- 使用时把 [RELY] 中列出的参考文件一并提供给模型，并要求只输出待填区域的完整函数。

[RELY]
可以依赖的东西：
- 先读 kern/process/proc.c、kern/process/proc.h、kern/process/entry.S、kern/mm/vmm.c、kern/mm/vmm.h、kern/mm/pmm.c、kern/mm/pmm.h、kern/mm/mmu.h、kern/trap/trap.c、kern/trap/trapentry.S、kern/schedule/sched.h、libs/riscv.h、libs/elf.h、libs/error.h 和 tools/test_lab5.c。
- 代码基线是 code/ 目录：Lab5 框架已回填 Lab2–4 的实现，B 负责的 function2/function3 区域仍为 YOUR CODE。
- struct proc_struct、struct mm_struct、struct vma_struct、struct trapframe 保持原样；do_execve(const char *name, size_t len, unsigned char *binary, size_t size) 和 copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share) 使用现有签名。
- proc->pgdir 必须保存页表根的物理地址（PADDR(mm->pgdir)），因为 proc_run 直接用它拼 satp；mm->pgdir 是内核虚拟地址。
- RESTORE_ALL 已由 Lab3 实现：返回用户态时 SPP=0，sscratch 会设为该中断帧之上的内核栈顶。因此首次进入用户态只要保证 tf->status（SPP=0、SPIE=1、SIE=0）、tf->epc、tf->gpr.sp 正确，并调用 forkrets(tf)。
- 用户程序链接在 0x800020，用户栈顶 USTACKTOP = 0x80000000，USTACKPAGE = 256；栈 VMA 最低页由 user_mem_check 作为保护页。
- idt_init 已设置 sstatus.SUM，内核可以直接复制用户内存。
- 内核堆 SLOB 的 arena 页只增不减（上游已知问题，对应 challenge4）。init_main 的“内存已恢复”检查应使用 slob_arena_pages() 把 SLOB 保留页单独扣除，其余物理页仍要求严格相等。
- kernel_thread_entry 用 s0 作入口、s1 作参数；init_main 正常返回 0，fn 返回后由 entry.S 执行 jal do_exit。
- do_exit/do_wait 通过 PROC_ZOMBIE、exit_code、WT_CHILD 与父/子/兄弟指针配套；do_wait 负责最后回收僵尸进程的 PCB 与内核栈。

[GUARANTEE]
必须交付：
static struct proc_struct *alloc_proc(void);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
static int init_main(void *arg);
static int user_main(void *arg);
int kernel_execve(const char *name, const unsigned char *binary, size_t size);
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size);
static int load_icode(unsigned char *binary, size_t size);
int do_wait(int pid, int *code_store);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
int dup_mmap(struct mm_struct *to, struct mm_struct *from);
int copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);

确保各函数在首次引用前已有声明或定义。输出本次完整生成代码、修改位置、实际验证命令及结果，不省略函数体。

[SPECIFICATION]
1. alloc_proc
Pre-Condition：无；从 kmalloc 获取一块 struct proc_struct 内存。
Post-Condition：PCB 所有字段有确定初值，state = PROC_UNINIT、pid = -1、kstack = 0、need_resched = 0、parent/mm/tf = NULL、pgdir = boot_pgdir_pa、flags = 0、name 清零；Lab5 新增的 exit_code、wait_state、cptr/yptr/optr 一并初始化；context 清零。
Case 1：kmalloc 失败返回 NULL，不持有其他资源。
Requirements：pgdir 保存启动页表根的物理地址，供 proc_run 拼 satp；不得遗漏 Lab4 已有字段的初始化。

2. kernel_thread
Pre-Condition：fn 为内核线程入口，arg 为参数，clone_flags 来自调用者。
Post-Condition：构造内核态 trapframe，s0 = fn、s1 = arg，status 置 SPP=1、SPIE=1、SIE=0，epc = kernel_thread_entry；以 do_fork(clone_flags | CLONE_VM, 0, &tf) 创建线程，返回新线程 pid 或负错误码。
Case 1：clone_flags 不含 CLONE_VM 时强制加上，内核线程共享内核地址空间。
Requirements：trapframe 先清零再填字段；PCB 与内核栈由 do_fork 分配，本函数不自行创建。

3. init_main、user_main
Pre-Condition：init_main 由 kernel_thread 创建，arg 为问候串；user_main 由 init_main 创建。
Post-Condition：init_main 用 kernel_thread(user_main, NULL, 0) 创建子线程并 do_wait(pid, NULL) 回收；结束时用真实的进程树、链表、计数、物理页与内核堆断言核对全部归还，输出 init check memory pass.；user_main 在 TEST 宏存在时执行 KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE)，否则执行 KERNEL_EXECVE(exit)。
Case 1：user_main 的 kernel_execve 失败时 panic，不静默返回。
Case 2：init_main 核对空闲物理页时先用 slob_arena_pages() 扣除 SLOB 保留页，其余物理页要求严格相等。
Requirements：断言必须是真实检查，不得用打印“通过”文字替代；nr_process、proc_list 以及 initproc->cptr/yptr/optr 的关系须与 do_wait/do_exit 的回收语义一致。

4. kernel_execve、do_execve
Pre-Condition：kernel_execve 的 binary 指向内核镜像中的 ELF，current->tf 非空；do_execve 的名称与映像来自可信内核调用。
Post-Condition：kernel_execve 清空 current->tf，调用 do_execve(name, strlen(name), binary, size)，成功后在当前线程上下文执行 forkrets(tf)，经 __trapret/RESTORE_ALL/sret 真正返回用户态；do_execve 校验参数、复制进程名并调用 load_icode，加载成功后替换地址空间。
Case 1：名称长度截断到 PROC_NAME_LEN；旧 mm 的释放放在新 mm 建立并切换 satp 之后，按 mm_count_dec 的结果决定 exit_mmap/put_pgdir/mm_destroy。
Case 2：load_icode 失败时 do_execve 调用 do_exit(ret)，不返回用户态。
Requirements：kernel_execve 不能只调用 do_execve，那只替换地址空间、进程仍在内核态；do_execve 必须先建新、再拆旧，避免旧 satp 指向已释放的页表根。

5. load_icode
Pre-Condition：binary/size 是有效 ELF 映像；current->tf 非空。
Post-Condition：校验 ELF_MAGIC 与 e_phoff/e_phnum 范围；mm_create + setup_pgdir 建立新页表根并复制内核映射；对每个 ELF_PT_LOAD 段校验 p_filesz <= p_memsz、文件偏移不越界、USER_ACCESS 合法，按 p_flags 生成 VMA 标志与含 PTE_U 的 PTE 权限，mm_map 登记 VMA，并从段起始页到结束页逐页 pgdir_alloc_page、整页清零后复制文件内容；建立用户栈 VMA [USTACKTOP-USTACKSIZE, USTACKTOP) 并逐页映射清零；写入 current->mm、current->pgdir，切换 satp 并 sfence.vma；设置 tf->gpr.sp = USTACKTOP、tf->gpr.a0 = 0、tf->epc = e_entry、tf->status 置 SPP=0、SPIE=1、SIE=0。
Case 1：ELF 非法、段越界、权限非法或分配失败，走 bad_elf，按 VMA 范围 exit_mmap，再释放页表根与 mm。
Case 2：整页清零发生在复制文件内容之前，保证 p_filesz 之外的 BSS 为 0，testbss 依赖这一点。
Requirements：切换后内核地址空间仍可见；失败不得留下半成品 mm、页表或映射；用户栈最低一页由 user_mem_check 作为保护页。

6. do_wait
Pre-Condition：pid 来自用户参数，code_store 为 NULL 或用户可写地址。
Post-Condition：pid == 0 时遍历 proc_list 找任意 parent == current 的僵尸子进程；pid != 0 时 find_proc 后确认 proc->parent == current；找到僵尸后用 copy_to_user 写回 exit_code（NULL 不写），在关中断区完成 unhash_proc + remove_links，再 put_kstack + kfree；有子进程但都未退出时置 PROC_SLEEPING、wait_state = WT_CHILD 并 schedule()，被唤醒后重查，若自身带 PF_EXITING 则 do_exit(-E_KILLED)；没有子进程返回 -E_BAD_PROC。
Case 1：code_store 非空但不可写，返回 -E_INVAL，不直接解引用该地址。
Case 2：目标是 idleproc/initproc 或不是自己的子进程，返回 -E_BAD_PROC。
Requirements：回收顺序是先摘哈希与链表、再释放内核栈与 PCB；退出码写回、PROC_ZOMBIE 与 WT_CHILD 的语义必须与 do_exit 严格配套。

7. copy_mm、dup_mmap、copy_range
Pre-Condition：copy_mm 的 proc 是新 PCB；普通 fork 时 current->mm 有效。
Post-Condition：current->mm == NULL 时子进程 mm = NULL 并返回 0；CLONE_VM 时 mm_count_inc 并共享 mm 与 pgdir；普通复制时 mm_create、setup_pgdir 复制内核映射、dup_mmap 复制全部 VMA，成功后 set_mm_count(mm, 1)，proc->pgdir = PADDR(mm->pgdir)。dup_mmap 逐个 VMA 用 vma_create 复制区间与属性，insert_vma_struct 登记后调用 copy_range。copy_range 只处理 4 KiB 有效用户叶映射，get_pte(from, start, 0) 只查询、get_pte(to, start, 1) 按需建表，目标地址不得已映射，保留源 PTE 权限，alloc_page + memcpy 后 page_insert。
Case 1：dup_mmap/copy_range 失败返回 -E_NO_MEM 或 -E_INVAL，copy_mm 走 bad_mm：exit_mmap 撤销已复制映射，再 put_pgdir、mm_destroy。
Case 2：没有二级页表的 2 MiB 区间直接跳过。
Requirements：share 参数在本基线固定传 false，COW 由后续任务扩展；proc->pgdir 存物理地址、mm->pgdir 存内核虚拟地址；失败时不得留下半成品地址空间。

8. do_fork
Pre-Condition：do_fork 由 Lab4 提供，本模块只需核对其与用户 fork 路径的衔接；clone_flags、stack、tf 来自 kernel_thread 或 sys_fork。
Post-Condition：nr_process >= MAX_PROCESS 返回 -E_NO_FREE_PROC；alloc_proc 后置 parent，依次 setup_kstack、copy_mm、copy_thread；在关中断区完成 get_pid、hash_proc、set_links；wakeup_proc 后返回 proc->pid。
Case 1：setup_kstack 失败回滚 PCB。
Case 2：copy_mm 失败回滚内核栈；mm 由 copy_mm 自行清理。
Requirements：PID 分配、哈希、链表与计数在同一关中断区内完成，不能让调度器看到半个进程；失败按相反顺序回滚；不修改 Lab4 既有的结构性约定。

9. 验证
- 使用实验配套 GCC 10.1.0 工具链编译，并用 QEMU 4.1.1 运行：设置 `PATH=/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin:$PATH`、`QEMU=$HOME/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64`，依次执行 `make`、`make qemu`（默认运行 exit）、`make grade`（13 个用户程序）。
- 重点观察 `hello`、`yield`、`badarg`、`exit`、`spin`、`forktest` 的输出，尤其是 `exit pass.`、`all user-mode processes have quit.`、`init check memory pass.`。
- 若 `forktest` 报空闲页不相等，先确认是否只有 SLOB arena 页未归还（用 `slob_arena_pages()` 扣除后再比较），而不是用户映射/页表/内核栈的真实泄漏。

````

### 功能模块四：进程退出、让出 CPU 与终止

**负责人：** 2413346-易响

> 本节记录功能模块四三个函数实际使用的最终提示词与迭代过程，供 C 整合报告时核对。
> 三个函数位于 `kern/process/proc.c` 的同一个 `//lab5 function4` 区域，因此下面按函数分别给出提示词，最后补充模块级的构建与验证说明。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

1. `do_exit()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 RISC-V 教学操作系统 ucore 的 Lab5，负责功能模块四：进程退出、让出 CPU 与终止。
现在实现 kern/process/proc.c 中的 do_exit()，并删除文件前部原有的 panic 占位。

实现方式：
- 先读 proc.c、proc.h、pmm.h、vmm.h、sched.h、trap.c、trapentry.S 和 tools/test_lab5.c，
  确认进程状态、页表切换、等待/唤醒和回收约定。
- 在独立工作副本中修改实际文件，只填写 //lab5 function4 区域中的 do_exit()，
  并删除 `panic("process exit!!.\n")` 桩。
- 保留 do_wait、do_execve、copy_mm 等他人负责的函数和 Lab5 标记。
- 按“保护内核常驻进程 → 离开页表并按 mm_count 回收 → 写退出码并进入僵尸态 →
  唤醒父进程 → 转交子进程 → schedule”的顺序实现。
- 输出完整函数，并逐段说明为什么 PCB 和内核栈不能在这里释放。

[RELY]
可以依赖的东西：
- global current、idleproc、initproc，struct proc_struct 定义于 kern/process/proc.h。
- proc_struct 字段：state、pid、kstack、need_resched、parent、mm、context、tf、pgdir、
  flags、exit_code、wait_state、cptr、yptr、optr。
- PROC_ZOMBIE、PF_EXITING、WT_CHILD、WT_INTERRUPTED 定义于 proc.h；错误码 -E_KILLED、-E_INVAL。
- mm_count_dec(struct mm_struct *)、exit_mmap(struct mm_struct *)、put_pgdir(struct mm_struct *)、
  mm_destroy(struct mm_struct *)；exit_mmap() 内部 assert(mm_count(mm) == 0)。
- extern uintptr_t boot_pgdir_pa；SATP_MODE_SV39、RISCV_PGSHIFT、write_csr()、
  read_csr() 来自 libs/riscv.h；TLB 用 sfence.vma 失效。
- wakeup_proc(struct proc_struct *)、schedule(void)、local_intr_save/local_intr_restore。
- set_links() 的关系语义：parent->cptr 是子进程链头，optr 指向更年长的兄弟，
  yptr 指回更年轻的兄弟；nr_process 是全局进程数。
- kernel_thread_entry 的汇编：fn 返回后执行 `jal do_exit`；init_main 正常返回 0。
- trap() 在返回用户态前检查 PF_EXITING 和 need_resched；do_wait() 在睡眠醒来后检查
  PF_EXITING，并在回收僵尸时执行 unhash_proc → remove_links → put_kstack → kfree。
- do_execve() 加载失败时调用 do_exit(ret)，因此 do_exit() 必须能被内核线程安全调用
  （current->mm == NULL 的情况）。

[GUARANTEE]
必须交付：
1. 完整的 int do_exit(int error_code)。
2. idleproc/initproc 退出直接 panic，不返回错误码。
3. 释放用户地址空间前先把 satp 切回内核启动页表并执行 sfence.vma；
   mm_count_dec() 之后才按 0 判断是否 exit_mmap/put_pgdir/mm_destroy。
4. 写 exit_code、置 PROC_ZOMBIE 放在唤醒父进程之前。
5. 把 current->cptr 链上的子进程全部转交 initproc，并同步维护 optr/yptr。
6. schedule() 后 panic，防止僵尸进程意外返回；不调用 put_kstack()/kfree(current)。
7. 保留 //lab5 function4 注释，把 YOUR CODE 换成 2413346。

[SPECIFICATION]
do_exit(error_code)

  Pre-Condition：
  - current != NULL，调用者持有有效内核栈。
  - current 不是 idleproc，也不是 initproc。
  - 退出码由调用者给出；本函数不校验其范围。

  Post-Condition：
  - 若 current->mm != NULL：satp 已指向 boot_pgdir，current->mm = NULL，
    current->pgdir = boot_pgdir_pa；mm_count 已减，最后一个使用者负责释放 mm。
  - current->exit_code = error_code，current->state = PROC_ZOMBIE。
  - parent 若处于 WT_CHILD，已被唤醒。
  - current 的所有子进程已转交 initproc，current->cptr == NULL。
  - current 不再被调度；PCB 和内核栈仍有效，等待 do_wait() 回收。

  Case 1：current->mm == NULL（内核线程或 exec 失败）。
  - 跳过页表和 mm 处理，直接进入僵尸态。

  Case 2：mm_count_dec(mm) > 0（CLONE_VM/COW 共享）。
  - 只减引用计数，不调用 exit_mmap/put_pgdir/mm_destroy。

  Case 3：parent == NULL。
  - 跳过父进程唤醒；仍然完成僵尸态和子进程转交。

  Requirements：
  - 不能先释放 mm 再 mm_count_dec()，否则 exit_mmap() 的断言失败。
  - 不能在释放 mm 后继续用当前 satp 运行，必须先切回内核页表。
  - 子进程转交只用 current->cptr 链，不遍历 proc_list，不改变 nr_process。
  - 不得直接 kfree(current) 或 put_kstack(current)：
    本函数仍运行在自己的内核栈上，这两项由 do_wait() 完成。
  - schedule() 之后接 panic("do_exit will not return!!\n")。
````

#### 实现迭代过程

本函数经历了 2 次修订：第一次写出主体，第二次修正 `idleproc`/`initproc` 的退出方式。

---

##### 第一次迭代

**遇到的问题：**

- 上游 x86 ucore 用 `lcr3(boot_cr3)` 切换页表，本项目是 RV64/Sv39，必须写 `satp` 并执行 `sfence.vma`；直接照搬会编译不过或切换错页表。
- `exit_mmap()` 内部有 `assert(mm_count(mm) == 0)`，如果先释放再减计数，会直接断言失败。
- 保护 `idleproc`/`initproc` 的第一版写成 `return -E_INVAL`。

**问题解决策略：**

- 用本项目的写法切换页表：

  ```c
  uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                         (boot_pgdir_pa >> RISCV_PGSHIFT);
  write_csr(satp, satp_value);
  asm volatile("sfence.vma" ::: "memory");
  ```

- 先 `mm_count_dec(mm)`，只有结果为 0 时才 `exit_mmap(mm)`、`put_pgdir(mm)`、`mm_destroy(mm)`；
  同时把 `current->mm = NULL`、`current->pgdir = boot_pgdir_pa`。
- 读到 `kernel_thread_entry` 在 `fn` 返回后执行 `jal do_exit`，而 `init_main` 正常返回 0，
  说明 `initproc` 最终会调用 `do_exit(0)`；如果这里返回错误码，函数末尾没有有效返回地址，
  执行流会落到 `.text` 的未知位置。因此把保护改成 `panic("idleproc exit.\n")` /
  `panic("initproc exit.\n")`，与上游和入口约定一致。

##### 第二次迭代

**遇到的问题：**

- 需要确认“先唤醒父进程还是先置僵尸态”。如果先唤醒、后置状态，父进程可能在 `do_wait()`
  里看不到 `PROC_ZOMBIE`，继续睡眠。
- 子进程转交如果只改 `parent`，不维护 `optr/yptr`，兄弟链会断裂。

**问题解决策略：**

- 顺序固定为：写 `exit_code` → 置 `PROC_ZOMBIE` → 关中断 → 唤醒 `WT_CHILD` 的父进程 →
  转交子进程 → 开中断 → `schedule()`。
- 转交时从 `current->cptr` 链头逐个摘下：`current->cptr = p->optr`，新的链头 `yptr = NULL`；
  挂到 `initproc` 链头时反向维护 `p->optr->yptr = p`，最后 `initproc->cptr = p`。
  `nr_process` 保持不变。

**最终结果：**

- 编译通过；
- 默认 `exit` 程序输出 `exit pass.`、`all user-mode processes have quit.`、`init check memory pass.`；
- 结束时 `panic("initproc exit.")` 是上游 Lab5 的预期收尾，不是本函数的 bug。

2. `do_yield()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab5 的功能模块四，现在实现 kern/process/proc.c 中的 do_yield()。
先读 trap.c 中返回用户态前的检查和 tools/test_lab5.c 的断言，确认“让出”是请求而不是立即切换。
在独立副本中只填写 //lab5 function4 区域的 do_yield()，保留其他函数和 Lab5 标记。
输出完整函数，并说明为什么这里不直接调用 schedule()。

[RELY]
可以依赖的东西：
- global current、current->need_resched，定义于 kern/process/proc.h。
- trap() 在 `!in_kernel` 返回用户态前执行：
  `if (current->need_resched) schedule();`
- test_lab5_process_control 的断言：do_yield() == 0 && current->need_resched。
- schedule() 会清除 current->need_resched，并选择下一个 PROC_RUNNABLE。

[GUARANTEE]
必须交付：
1. 完整的 int do_yield(void)。
2. 只设置 need_resched = 1，返回 0。
3. 不改变进程状态，不直接调用 schedule()。
4. 保留 //lab5 function4 注释和学号 2413346。

[SPECIFICATION]
do_yield(void)

  Pre-Condition：
  - 在进程上下文中调用，current != NULL。

  Post-Condition：
  - current->need_resched == 1。
  - 返回值 0。

  Case 1：重复调用。
  - 幂等，仍然只置位 need_resched。

  Requirements：
  - 不设置 PROC_SLEEPING，不修改 wait_state。
  - 不直接 schedule()：当前正处在系统调用的内核路径上，
    把切换点统一留给 trap() 的返回路径更简单。
  - 验收：yield 程序多次让出后仍能继续运行并输出 `yield pass.`。
````

#### 实现迭代过程

本函数经历了 1 次代码生成，未发生提示词修订，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 1 次代码生成，本函数目前：

- 设置 `current->need_resched = 1`，返回 0；
- 未改变进程状态，未直接调用 `schedule()`；
- 编译结果：编译成功；
- 验证结果：注入版 `[Test Process Control] PASS`；`yield` 程序输出 `yield pass.`。

3. `do_kill()`

以下是根据本次实现过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 ucore Lab5 的功能模块四，现在实现 kern/process/proc.c 中的 do_kill()。
先读 find_proc()、trap() 的 PF_EXITING 检查、do_wait() 的醒来检查和 user/spin.c，
确认“终止”是异步请求，不能直接对目标调用 do_exit()。
在独立副本中只填写 //lab5 function4 区域的 do_kill()，保留其他函数和 Lab5 标记。
输出完整函数，并说明非法 pid、重复请求、睡眠目标和僵尸目标分别怎么处理。

[RELY]
可以依赖的东西：
- struct proc_struct *find_proc(int pid)，按 pid 在 hash_list 中查找。
- PF_EXITING 定义于 proc.h；proc->flags 用于记录退出意图。
- 进程状态：PROC_UNINIT、PROC_SLEEPING、PROC_RUNNABLE、PROC_ZOMBIE。
- wakeup_proc(struct proc_struct *) 会把睡眠进程置为 PROC_RUNNABLE 并清 wait_state。
- trap() 在返回用户态前检查 PF_EXITING，命中则执行 do_exit(-E_KILLED)。
- do_wait() 在 schedule() 醒来后检查 PF_EXITING，命中则执行 do_exit(-E_KILLED)。
- 错误码 -E_INVAL，来自 libs/error.h。
- spin 程序的期望输出：`kill returns 0`、`wait returns 0`、`spin may pass.`。

[GUARANTEE]
必须交付：
1. 完整的 int do_kill(int pid)。
2. 非法 pid（含 -1）、idleproc、initproc、已带 PF_EXITING、已经是 PROC_ZOMBIE 的目标
   返回 -E_INVAL。
3. 合法目标置 PF_EXITING；只有 PROC_SLEEPING 的目标才唤醒。
4. 不直接对目标调用 do_exit()，不修改目标的内核栈或页表。
5. 保留 //lab5 function4 注释和学号 2413346。

[SPECIFICATION]
do_kill(pid)

  Pre-Condition：
  - pid 来自用户系统调用参数，可能是非法值。

  Post-Condition：
  - 合法目标：flags 置 PF_EXITING，必要时被唤醒；返回 0。
  - 非法目标：不修改任何进程，返回 -E_INVAL。

  Case 1：find_proc(pid) == NULL（含 pid = -1）。
  - 返回 -E_INVAL。

  Case 2：目标是 idleproc 或 initproc。
  - 返回 -E_INVAL，保护内核常驻进程。

  Case 3：目标已带 PF_EXITING，或 state == PROC_ZOMBIE。
  - 返回 -E_INVAL，避免重复请求和唤醒僵尸。

  Case 4：目标 state == PROC_SLEEPING。
  - 置 PF_EXITING 后 wakeup_proc()，让它在 do_wait() 的醒来检查中退出。

  Case 5：目标 state == PROC_RUNNABLE。
  - 只置 PF_EXITING，不唤醒；它在下一个 trap 返回点自行退出。

  Requirements：
  - 不直接调用 do_exit(target)：目标可能正在使用自己的内核栈。
  - 不修改目标的状态为 PROC_ZOMBIE，不释放目标资源。
  - 验收：do_kill(-1) == -E_INVAL；spin 程序 `kill returns 0`、`wait returns 0`。
````

#### 实现迭代过程

本函数经历了 2 次修订：第一次只做置位与唤醒，第二次补齐拒绝条件和重复请求处理。

---

##### 第一次迭代

**遇到的问题：**

- 第一版只要 `find_proc(pid)` 成功就置 `PF_EXITING` 并返回 0；
- 重复 `kill` 同一个进程会一直返回成功，不符合“重复请求应拒绝”的约定；
- 对 `idleproc`/`initproc` 也没有保护。

**问题解决策略：**

- 增加拒绝条件：`proc == NULL || proc == idleproc || proc == initproc` 时返回 `-E_INVAL`；
- 记录需要和 `PF_EXITING` 的已有值配合判断，避免重复置位。

##### 第二次迭代

**遇到的问题：**

- 对已经 `PROC_ZOMBIE` 的目标做 `wakeup_proc()` 会触发 `assert(proc->state != PROC_ZOMBIE)`；
- 需要区分“睡眠目标”和“可运行目标”：前者必须唤醒，后者不能主动切换。

**问题解决策略：**

- 把拒绝条件扩展为：
  `(proc->flags & PF_EXITING) || proc->state == PROC_ZOMBIE` → `-E_INVAL`；
- 只有 `proc->state == PROC_SLEEPING` 才调用 `wakeup_proc()`；
- 置位用 `proc->flags |= PF_EXITING`，不在包装层做额外状态修改。

**最终结果：**

- 编译通过；
- 注入版 `[Test Process Control] PASS`，其中 `do_kill(-1) == -E_INVAL`；
- `spin` 程序输出 `kill returns 0`、`wait returns 0`、`spin may pass.`，被终止的子进程能被父进程回收。

---

#### 模块整体构建迭代补充

三个函数的逻辑按上面的迭代定型；构建和合并阶段遇到两个问题，记录如下。

1. **`undefined reference to dup_mmap`**

   链接时报：

   ```text
   obj/kern/process/proc.o: in function `setup_pgdir':
   kern/process/proc.c:598: undefined reference to `dup_mmap'
   ```

   `dup_mmap()` 本身在 `kern/mm/vmm.c` 中，但 C 的 `do_cow_fault()` 后半段被插到了
   B 的 `dup_mmap()` 之后，导致 `do_cow_fault` 没有闭合，`dup_mmap` 变成 GCC 的嵌套函数，
   只在本文件内可见。解决：把 `do_cow_fault()` 的后半段移回它自己的函数体内，
   在 `dup_mmap()` 之前闭合；只做结构复位，不改 `share`、引用计数或 COW 语义。

2. **切换用户程序后 `make` 仍跑旧程序**

   `make build-hello` 通过 `DEFS+=-DTEST=...` 改变编译宏，但 `DEFS` 不是 make 的依赖，
   直接 `make` 可能不会重编 `proc.o`，运行的还是上一次的 `TEST`。解决：切换程序用
   `make build-<程序名>`，回到默认构建用 `make clean && make`。

**最终验证：**

```text
[Test Process Create] PASS
[Test Syscall] PASS
[Test Process Control] PASS
exit pass.
all user-mode processes have quit.
init check memory pass.
```

另逐一运行了 13 个用户程序（`hello`、`exit`、`yield`、`spin`、`badarg`、`forktest`、
`badsegment`、`divzero`、`softint`、`testbss`、`pgdir`、`faultread`、`faultreadkernel`），
均到达 `init check memory pass.`；截图与日志见 `report/report.md` 的 4.4.6 与第五节。

---

### 分支任务：双重 GDB 调试系统调用与返回

**负责人：** 2413346-易响

> 本分支任务独立于 COW，也不替代 C 的最终测试截图。本节记录这次双重 GDB 任务实际使用的最终提示词与迭代过程。

#### 最终提示词

以下是根据本次调试过程整理的最终提示词：

````markdown
[PROMPT]
我正在完成 RISC-V ucore Lab5 的分支任务：用双重 GDB 观察一次完整的 U→S→U。
目标是停在用户程序的 ecall 之前，观察 QEMU 如何处理 ecall；再停在 sret 之前，
观察它如何返回用户态，并对照 QEMU 源码解释关键流程与 TCG 的作用。

实现方式：
- 先读用户库的 syscall 封装、trapentry.S、trap.c、syscall.c，确认 ecall/sret 的位置。
- 用 objdump 确认本次构建的用户 ecall 地址和内核 sret 地址，不照抄指导书。
- 客体 GDB 通过 QEMU gdbstub 调试 ucore/用户程序；宿主 GDB 调试 QEMU 进程本身。
- 先做客体侧断点，再做 QEMU 侧 helper 断点；两边分开记录，避免两个 GDB 互相打断。
- 输出每一步的命令、寄存器/栈/特权级实测值，以及对应的 QEMU 源码位置。

[RELY]
可以依赖的东西：
- QEMU 4.1.1，源码和调试符号在 /home/agony/Desktop/qemu-4.1.1。
- 客体 riscv64-unknown-elf-gdb 10.1；宿主 gdb 12.1；交叉工具链 SiFive GCC 10.2.0。
- make debug 用 `-S -s` 启动 QEMU，make gdb 连接 localhost:1234；
  两者只加载 bin/kernel，用户符号要 add-symbol-file obj/__user_hello.out。
- 用户程序链接在 0x800020；本机构建 hello 的 ecall 在 0x8000a2，exit 在 0x800104；
  __trapret 的 sret 在 0xffffffffc0200f12。
- 用户 trapframe 的 gpr.sp、epc、status；RESTORE_ALL 按 SPP 选择用户 sp 或内核 sp。
- QEMU 源码：target/riscv/insn_trans/trans_privileged.inc.c 的 trans_ecall/trans_sret；
  target/riscv/translate.c 的 generate_exception；target/riscv/op_helper.c 的
  helper_raise_exception/helper_sret；target/riscv/cpu_helper.c 的
  riscv_cpu_do_interrupt；accel/tcg/cpu-exec.c 与 code_gen_buffer。
- 宿主 GDB 的辅助脚本 report/gdb/ucore_lab5.gdb、report/gdb/qemu_host.gdb。

[GUARANTEE]
必须交付：
1. 客体侧停在 ecall 的寄存器（pc、a0、a1、a2）和用户调用链。
2. 客体侧停在 sret 的 sstatus（SPP/SPIE/SIE）、sepc、sp，以及 si 后的 pc。
3. 宿主侧 helper_raise_exception（exception=8、priv=0）和 helper_sret
   （priv=1、sepc=0x8000a6、SPP=0）的实测值，以及下一次 ecall 的 priv=0。
4. 对照 QEMU 源码解释 ecall/sret 的翻译和执行流程。
5. TCG 与 Lab2 地址翻译双重调试的联系与差别。
6. 真实踩坑记录和 AI 协作过程；4 张截图，见 report/images/A_gdb_*.png。

[SPECIFICATION]
1. 观测点选择
   - 用 hello（先 cprintf 再 getpid），不要只用 exit；exit 不返回原调用点。
   - 每条命令前用 objdump 确认地址；不照抄指导书的 0x800104。

2. 客体侧 ecall
   Pre-Condition：make build-hello 已执行，make debug 已启动，gdb 已连接。
   Post-Condition：停在 ecall 之前，pc=0x8000a2，a0=30（SYS_putc）、a1=0x48（'H'）、
   a2=0x800858；bt 显示 main→cprintf→vcprintf→vprintfmt→cputch→sys_putc→syscall。

3. 客体侧 sret
   Post-Condition：停在 __trapret 的 sret，sstatus 的 SPP=0、SPIE=1、SIE=0，
   sepc=0x8000a6，sp=0x7ffffe60；si 后 pc=0x8000a6。

4. QEMU 侧
   - helper_raise_exception：exception=8、env->priv=0、pc=0x8000a2；
     调用栈含 code_gen_buffer→cpu_tb_exec→cpu_loop_exec_tb→cpu_exec→tcg_cpu_exec。
   - helper_sret：priv=1、sepc=0x8000a6、mstatus 的 SPP=0、SPIE=1、SIE=0；
     下一次用户 ecall 时 priv=0。
   - ucore 自身的 SBI 输出也是 ecall（S 态），必须用条件断点 if env->priv == 0 过滤。
   - QEMU 4.1.1 的 CPURISCVState 没有 sstatus，打印 env->mstatus 后按位解读。

5. 约束
   - 不把 b kern_entry 当成入口断点：内核链接在 0xffffffffc0200000，上电 PC 是 0x80200000。
   - 不用 gdb -p 直接 attach 兄弟 QEMU：ptrace_scope=1 会失败；让宿主 GDB 启动 QEMU，
     或临时把 ptrace_scope 设为 0。
   - 不把“用户 panic”“SBI ecall”当成系统调用返回的证据。
````

#### 实现迭代过程

本次调试经历了 3 轮修订，前两轮都是断点/连接问题。

---

##### 第一次迭代

**遇到的问题：**

- `break kern_entry` 永远不触发；
- 执行 `make build-hello` 后再 `make`，跑的仍是上一次的 `TEST` 程序；
- 照指导书的 0x800104 下断点，hello 根本不经过那里。

**问题解决策略：**

- 用 `break *0x80200000` 停在上电入口，或直接断在页表打开后的 `trap`/`syscall`；
- 切换程序统一用 `make clean && make build-hello`，避免 `DEFS` 不是依赖导致的旧对象；
- 用 `objdump -d obj/__user_hello.out` 确认 hello 的 ecall 在 0x8000a2，改用地址断点。

##### 第二次迭代

**遇到的问题：**

- 宿主 GDB `gdb -p <qemu-pid>` 报：
  `Could not attach to process ... ptrace: Inappropriate ioctl for device`；
- Ubuntu 默认 `kernel.yama.ptrace_scope=1`，只能 ptrace 自己的后代进程。

**问题解决策略：**

- 改用“宿主 GDB 直接启动 QEMU”的方式：`gdb -x report/gdb/qemu_host.gdb`，
  QEMU 是 GDB 的子进程，不需要 attach；
- 另一个终端用 `make gdb` 连接 gdbstub 并 `continue`，让客体开始执行。

##### 第三次迭代

**遇到的问题：**

- 第一次命中 `helper_raise_exception` 时 `priv=1`，不是用户程序：ucore 的 `cprintf`
  走 SBI，也是 S 态 ecall；
- 打印 `env->sstatus` 报 `There is no member named sstatus`；
- 不知道 `sret` 断在哪里。

**问题解决策略：**

- 条件断点 `break helper_raise_exception if env->priv == 0`，只停在用户态 ecall；
- QEMU 4.1.1 用 `env->mstatus` 存，`SPP=bit8`、`SPIE=bit5`、`SIE=bit1`；
- `objdump -d bin/kernel | grep -n -B4 sret` 找到 0xffffffffc0200f12。

**最终结果：**

```text
USER-ECALL: exception=8 priv=0 sepc=0x800020 pc=0x8000a2
USER-SRET:  priv=1 sepc=0x8000a6 mstatus=0x8000000000046020 SPP=0 SPIE=1 SIE=0
NEXT-USER-ECALL: exception=8 priv=0 pc=0x8000a2
```

4 张截图与完整会话原图见 `report/images/`；客体侧与宿主侧命令见
`report/report.md` 的 4.5 节和 `report/gdb/` 下的两个脚本。
