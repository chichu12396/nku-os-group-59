# B 模块最终提示词

> 说明：下面是实际用于生成本次 Lab5 模块二、模块三代码的有效提示词版本。
> 使用时把“现有代码约束”一节中的文件一并提供给模型，并要求只输出待填区域的完整函数。

---

## 角色与目标

你是操作系统内核开发者。请在一个基于 RISC-V Sv39、已经完成 Lab2（物理内存）、Lab3（中断/异常返回）、Lab4（PCB、调度、`do_fork`/`copy_thread`）的 ucore 教学内核上，完成 Lab5 的**模块二（用户程序创建与加载）**和**模块三（用户进程复制）**。

代码基线：`code/` 目录，Lab5 框架已回填 Lab2–4 的实现，B 负责的 `function2`/`function3` 区域仍是 `YOUR CODE`。

## 必须完成的范围

### 模块二：`code/kern/process/proc.c`

1. `alloc_proc`：在 Lab4 基础上初始化 `exit_code`、`wait_state`、`cptr/yptr/optr`；`pgdir` 初始为 `boot_pgdir_pa`。
2. `kernel_thread`：检查/适配内核线程首次运行现场（`s0/s1`、`SPP=1`、`SPIE=1`、`SIE=0`）。
3. `init_main`：创建 `user_main` 内核线程，`do_wait` 回收；用真实的进程树、链表、计数、物理页与内核堆断言做收尾检查。
4. `user_main`：`TEST` 宏存在时 `KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE)`，否则 `KERNEL_EXECVE(exit)`。
5. `kernel_execve`：构造中断帧并经 `forkrets(tf)` 真正返回用户态；不能只调用 `do_execve`。
6. `do_execve`：校验参数、复制进程名、替换地址空间、失败时终止进程。
7. `load_icode`：校验 ELF；建立 VMA、页表和用户栈；加载各段并清零 BSS；设置用户入口、用户栈和 `sstatus`；切换 `satp`；失败时完整清理。
8. `do_wait`：支持 `pid == 0`（任意子进程）与指定 pid；处理睡眠/唤醒/重查、退出码写回、僵尸进程回收；非法目标返回 `-E_BAD_PROC`。

### 模块三

1. `copy_mm`（`proc.c`）：区分无用户 mm、`CLONE_VM`、普通复制；维护 `mm_count`、`pgdir`；失败清理。
2. `dup_mmap`（`kern/mm/vmm.c`）：复制 VMA 区间与属性，调用 `copy_range`。
3. `copy_range`（`kern/mm/pmm.c`）：逐页分配新物理页并复制，保留权限，维护引用计数与错误路径。
4. `do_fork`：核对既有实现与用户 fork 路径（PCB、内核栈、mm、中断帧、pid、哈希/链表、唤醒、失败回滚）。

## 现有代码约束（必须遵守）

- 只修改标记对应的区域，保留 `//lab5 functionN` 注释，把 `YOUR CODE` 替换为学号 `2412102`。
- 复用现有结构、头文件和函数签名，不新增并行接口：
  - `struct proc_struct` / `struct mm_struct` / `struct vma_struct` / `struct trapframe` 保持原样；
  - `do_execve(const char *name, size_t len, unsigned char *binary, size_t size)`；
  - `copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share)`。
- `proc->pgdir` 必须保存**页表根的物理地址**（`PADDR(mm->pgdir)`），因为 `proc_run` 直接用它拼 `satp`；`mm->pgdir` 是内核虚拟地址。
- `RESTORE_ALL` 已由 Lab3 实现：返回用户态时 `SPP=0`，`sscratch` 会设为该中断帧之上的内核栈顶。因此首次进入用户态只要保证 `tf->status`（SPP=0、SPIE=1、SIE=0）、`tf->epc`、`tf->gpr.sp` 正确，并调用 `forkrets(tf)`。
- 用户程序链接在 `0x800020`，用户栈顶 `USTACKTOP = 0x80000000`，`USTACKPAGE = 256`；栈 VMA 最低页由 `user_mem_check` 作为保护页。
- `idt_init` 已设置 `sstatus.SUM`，内核可以直接复制用户内存。
- 内核堆 SLOB 的 arena 页只增不减（上游已知问题，对应 challenge4）。`init_main` 的“内存已恢复”检查应使用 `slob_arena_pages()` 把 SLOB 保留页单独扣除，其余物理页仍要求严格相等。

## spec 要求

对每个函数说明并实现：

1. 输入/输出与返回值；
2. 前置条件与状态约束；
3. 边界条件（`pid` 范围、`code_store == NULL`、ELF 越界、空段、BSS、页对齐、地址范围）；
4. 失败清理（已分配的物理页、页表、mm、内核栈、PCB）；
5. 与其他模块的衔接（`do_exit` 的 `exit_code/PROC_ZOMBIE/WT_CHILD`；`RESTORE_ALL` 的中断帧布局；`do_fork` 的 `copy_thread`）。

## 输出要求

- 给出可直接编译的完整函数实现，不要伪代码；
- 每个函数附简短中文注释，解释关键状态、页表或寄存器处理；
- 在每个函数末尾说明失败路径会释放哪些资源；
- 不要修改不属于本模块的函数。

---

## 验证提示词（追加）

> 请用实验配套 GCC 10.1.0 工具链编译，并用 QEMU 4.1.1 运行：
>
> ```bash
> export PATH=/opt/riscv/riscv64-unknown-elf-gcc-10.1.0-2020.08.2-x86_64-linux-ubuntu14/bin:$PATH
> export QEMU=$HOME/qemu-src/qemu-4.1.1-inst/bin/qemu-system-riscv64
> make
> make qemu        # 默认运行 exit
> make grade       # 13 个用户程序
> ```
>
> 重点观察 `hello`、`yield`、`badarg`、`exit`、`spin`、`forktest` 的输出，尤其是 `exit pass.`、`all user-mode processes have quit.`、`init check memory pass.`。
> 若 `forktest` 报空闲页不相等，请先确认是否只有 SLOB arena 页未归还（用 `slob_arena_pages()` 扣除后再比较），而不是用户映射/页表/内核栈的真实泄漏。
