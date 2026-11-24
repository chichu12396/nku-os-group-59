# A 部分最终提示词

> 说明：本文件是 A（2413346-易响）在 Lab5 中使用的**模块四**与**双重 GDB 调试**任务的最终提示词版本。
> 实际下发给助手的是简短任务描述（“负责模块四，先理清思路再完成”“做双重 GDB”）；下面按 lab0.5 的提示词结构整理成可复现的等价版本，其中“现有代码约束”、`spec` 与最终代码、最终调试步骤一一对应。
> 使用时把“现有代码约束”中列出的文件一并提供给模型，并要求只输出指定区域。

---

## 第一部分：模块四——进程退出、让出 CPU 与终止

### 角色与目标

你是 RISC-V ucore 的内核开发者。请在一个基于 RISC-V Sv39、已完成 Lab2（物理内存/页表）、Lab3（中断与异常返回）、Lab4（PCB、调度、`do_fork`/`copy_thread`）的教学内核上，完成 Lab5 的**模块四**：

- `int do_exit(int error_code)`：结束当前进程，回收用户地址空间，进入僵尸态，唤醒父进程，托管子进程，交出 CPU；
- `int do_yield(void)`：主动让出 CPU；
- `int do_kill(int pid)`：向目标进程发送退出意图。

代码基线：`code/`，Lab5 框架已回填 Lab2–4 的实现；`kern/process/proc.c` 的 `//lab5 function4` 区域仍是 `YOUR CODE`，另有一个会 `panic("process exit!!.")` 的 `do_exit` 占位。

### 必须完成的范围

| 函数 | 要求 |
|---|---|
| `do_exit` | 保护 `idleproc`/`initproc`；先离开自己的页表再释放 mm；按 `mm_count` 决定是否 `exit_mmap`/`put_pgdir`/`mm_destroy`；写 `exit_code`、置 `PROC_ZOMBIE`；唤醒 `WT_CHILD` 的父进程；把子进程转交 `initproc`；`schedule()` 后不再返回 |
| `do_yield` | 只设置 `current->need_resched = 1` 并返回 0，不直接 `schedule()` |
| `do_kill` | `find_proc(pid)` 命中且目标合法时置 `PF_EXITING`；目标睡眠则 `wakeup_proc`；非法 pid / `idleproc` / `initproc` / 重复请求 / 僵尸返回 `-E_INVAL` |

### 现有代码约束（必须遵守）

- 只修改 `kern/process/proc.c` 的 `//lab5 function4` 区域，保留标记，把 `YOUR CODE` 替换为学号 `2413346`。
- 删除原有的 `do_exit` panic 桩，但保留其他函数：`do_execve` 失败路径、`do_wait` 睡眠唤醒路径都会调用 `do_exit`。
- 复用既有结构、签名和头文件，不新增并行接口：
  - `struct proc_struct{state,pid,kstack,mm,pgdir,flags,exit_code,wait_state,cptr,yptr,optr,parent,...}`；
  - `mm_count()/mm_count_dec()`、`exit_mmap()`、`put_pgdir()`、`mm_destroy()`；
  - `wakeup_proc()`、`schedule()`、`local_intr_save/restore()`、`find_proc()`。
- 切换页表用本项目写法，不是 x86 的 `lcr3`：

  ```c
  uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                         (boot_pgdir_pa >> RISCV_PGSHIFT);
  write_csr(satp, satp_value);
  asm volatile("sfence.vma" ::: "memory");
  ```

- `exit_mmap()` 内部 `assert(mm_count(mm) == 0)`，所以必须先 `mm_count_dec()` 再调用，不能先释放后减计数。
- `proc->pgdir` 保存**页表根物理地址**，`mm->pgdir` 是内核虚拟地址；退出后把 `current->pgdir` 恢复为 `boot_pgdir_pa`。
- `kernel_thread_entry` 在 `fn` 返回后会执行 `jal do_exit`；`init_main` 正常返回 0，因此 `initproc` 最终会调用 `do_exit(0)`。对 `idleproc`/`initproc` 不能返回错误码（没有有效的返回地址），必须 `panic`。
- `trap()` 在返回用户态前会检查：

  ```c
  if (current->flags & PF_EXITING) do_exit(-E_KILLED);
  if (current->need_resched) schedule();
  ```

  `do_kill`/`do_yield` 只设置标志，切换/退出由这里完成。
- `do_wait()` 的约定：`current->state = PROC_SLEEPING; current->wait_state = WT_CHILD; schedule();` 醒来后若带 `PF_EXITING` 则 `do_exit(-E_KILLED)`；回收僵尸时执行 `unhash_proc → remove_links → put_kstack → kfree(proc)`。因此 `do_exit` 不能提前释放 PCB 和内核栈。
- `set_links()` 的兄弟链语义：`cptr` 为子进程链头，`optr` 指向更年长的兄弟，`yptr` 指回更年轻的兄弟。转交子进程时必须同步维护三向关系，`nr_process` 不变。
- 用 `local_intr_save/restore` 包住父进程唤醒与子进程转交；临界区内不做可能睡眠的分配。
- 测试断言（`tools/test_lab5.c`）：
  `do_yield() == 0 && current->need_resched`；`do_kill(-1) == -E_INVAL`；`do_wait(-1, NULL) == -E_BAD_PROC`。

### spec（逐函数）

#### 1. `do_exit(int error_code)`

- **Pre-Condition**：`current != NULL`；调用者持有有效内核栈；不得是 `idleproc`/`initproc`。
- **Post-Condition**：用户地址空间已释放或 `mm_count` 已减；`exit_code` 已写；状态为 `PROC_ZOMBIE`；父进程被唤醒；子进程已转交 `initproc`；当前进程不再被调度。
- **Case 1**：`current->mm == NULL`（内核线程/加载失败）→ 跳过 mm 处理，直接进入僵尸态。
- **Case 2**：`mm_count_dec(mm) > 0`（`CLONE_VM`/COW 共享）→ 只减计数，不释放 mm。
- **Case 3**：`parent == NULL` → 跳过唤醒；`current->cptr == NULL` → 跳过转交。
- **Requirements**：释放 mm 前先切回内核页表并 `sfence.vma`；不得 `put_kstack`/`kfree(current)`；`schedule()` 后 `panic` 防止意外返回。

#### 2. `do_yield(void)`

- **Pre-Condition**：进程上下文，`current != NULL`。
- **Post-Condition**：`need_resched = 1`，返回 0；不改变进程状态，不直接切换。
- **Requirements**：幂等；切换点留给 `trap()` 返回路径。

#### 3. `do_kill(int pid)`

- **Pre-Condition**：`pid` 为用户提供的目标进程号。
- **Post-Condition**：合法目标置 `PF_EXITING`；若目标 `PROC_SLEEPING` 则唤醒；返回 0。
- **Case 1**：`pid` 不存在（含 `-1`）→ `-E_INVAL`。
- **Case 2**：目标是 `idleproc`/`initproc` → `-E_INVAL`。
- **Case 3**：目标已带 `PF_EXITING` 或已是 `PROC_ZOMBIE` → `-E_INVAL`（重复请求）。
- **Case 4**：目标 `PROC_RUNNABLE` → 只置标志，不唤醒；它在下一个 trap 返回点自行退出。
- **Requirements**：不直接对目标调用 `do_exit`（目标可能正在使用自己的内核栈）；语义是异步终止。

### 输出要求

- 给出可直接编译的完整三个函数，不要伪代码；
- 每个函数附中文注释，解释关键状态、页表和调度处理；
- 说明失败/边界路径（`mm == NULL`、`mm_count > 0`、`parent == NULL`、重复 kill）；
- 不修改 `do_wait`、`set_links`、`copy_mm` 等他人负责的函数。

### 验证提示词（追加）

> 请在本机编译并运行验证，不要只做代码审查：
>
> ```bash
> cd code
> make clean && make                 # 必须 0 错误
> make qemu                          # 默认 exit：exit pass. / init check memory pass.
> make build-hello && make qemu      # hello pass.
> make build-spin && make qemu       # kill returns 0 / wait returns 0 / spin may pass.
> ../report/run_injected_check.sh    # [Test Process Control] PASS 等三条
> ```
>
> 注意：`make` 的 warning（`kmalloc.c` 的 `kva2page`、`testbss.c` 的越界写）是基线/测试程序的预期 warning，不是失败；切换 `make build-<程序>` 后要 `make clean && make` 才能回到默认 `exit` 构建。
> 最后的 `kernel panic: initproc exit.` 是上游 Lab5 的预期收尾，不是模块四的 bug。

---

## 第二部分：双重 GDB 调试系统调用与返回（追加任务）

### 角色与目标

在同一个 ucore Lab5 工程上，用**两个 GDB** 观察一次完整的 U→S→U：

- 客体 GDB（`riscv64-unknown-elf-gdb`）通过 QEMU gdbstub 调试 ucore/用户程序；
- 宿主 GDB（系统 `gdb`）调试 QEMU 进程本身，观察 TCG 生成代码如何调用 C helper 模拟 `ecall`/`sret`。

目标是拿到可复核的寄存器、调用栈、特权级和源码证据，并解释 QEMU 的关键流程与 TCG 的作用，而不是只截一张“跑通”的图。

### 环境与已知事实

- QEMU 4.1.1，源码与调试符号在 `/home/agony/Desktop/qemu-4.1.1`；
- 客体 GDB 10.1，宿主 GDB 12.1，交叉工具链 SiFive GCC 10.2.0；
- 用户程序不是在文件系统里，而是构建时链接进内核镜像；`make debug`/`make gdb` 只加载内核符号，必须手动 `add-symbol-file obj/__user_hello.out`；
- 本机 `hello` 的 `ecall` 在 `0x8000a2`，`exit` 的 `ecall` 在 `0x800104`——**必须用 `objdump` 按自己的构建确认，不要照抄**；
- `__trapret` 的 `sret` 在本机构建为 `0xffffffffc0200f12`，同样要用 `objdump -d bin/kernel | grep -n -B4 sret` 复核；
- Ubuntu 默认 `kernel.yama.ptrace_scope=1`，直接 `gdb -p <qemu-pid>` 可能失败；可让宿主 GDB 直接启动 QEMU，或临时把 `ptrace_scope` 设为 0。
- 调试前先 `make clean && make build-hello`，保证运行的确实是 `hello` 而不是上一次 `TEST` 的残留。

### 必须完成的观测

#### 1. 加载用户符号，选一个会正常返回的系统调用

- 用 `hello`（先 `cprintf` 再 `getpid`），不要只用 `exit`——`exit` 不返回原调用点；
- 说明为什么只加载 `bin/kernel` 找不到 `user/libs/syscall.c`，以及 `add-symbol-file` 为什么不需要指定 text 偏移（`user.ld` 固定链接在 `0x800020`）。

#### 2. 客体侧：停在 `ecall` 与 `sret`

先在一个终端执行 `make debug`（QEMU 带 `-S -s` 启动并等待 gdbstub），再在另一个终端连接：

```text
(gdb) file bin/kernel
(gdb) set arch riscv:rv64
(gdb) target remote localhost:1234
(gdb) add-symbol-file obj/__user_hello.out
(gdb) break *0x8000a2
(gdb) continue
(gdb) info registers pc a0 a1 a2
(gdb) x/4i $pc
(gdb) bt
```

要求记录：`pc=0x8000a2`、`a0=30`（`SYS_putc`）、`a1=0x48`（`'H'`）、`a2=0x800858`，以及 `main → cprintf → vcprintf → vprintfmt → cputch → sys_putc → syscall` 的调用链。

```text
(gdb) break *0xffffffffc0200f12
(gdb) continue
(gdb) info registers pc sp
(gdb) info registers sstatus sepc scause
(gdb) si
(gdb) info registers pc
```

要求记录：`SPP=0`、`SPIE=1`、`SIE=0`、`sepc=0x8000a6`、`sp=0x7ffffe60`（用户栈），`si` 后 `pc=0x8000a6`。

#### 3. QEMU 侧：`helper_raise_exception` 与 `helper_sret`

宿主 GDB 启动 QEMU：

```bash
cd code
gdb -x ../report/gdb/qemu_host.gdb
```

另一个终端（同样在 `code/` 下）让客体跑起来：

```text
make gdb
(gdb) continue
```

要求记录：

- `helper_raise_exception(env, exception=8)`，`env->priv == 0`，`USER-ECALL: priv=0 pc=0x8000a2`；
- `helper_sret` 入口：`priv=1`、`sepc=0x8000a6`、`mstatus` 的 `SPP=0`、`SPIE=1`、`SIE=0`；
- 下一次用户 `ecall` 时 `priv` 回到 0，证明 `sret` 回到了 U 态；
- 调用栈经过 `helper → code_gen_buffer → cpu_tb_exec → cpu_loop_exec_tb → cpu_exec → tcg_cpu_exec`。

注意：ucore 的 `cprintf` 走 SBI，也是 `ecall`（S 态），所以第一个 `helper_raise_exception` 往往是 SBI 调用；必须用条件断点 `if env->priv == 0` 过滤。QEMU 4.1.1 的 `CPURISCVState` 没有 `sstatus` 成员，要打印 `env->mstatus` 再按位解读。

### QEMU 源码阅读要求

对照实际版本解释以下位置（不要泛泛而谈）：

| 阶段 | 源码 |
|---|---|
| `ecall` 翻译 | `target/riscv/insn_trans/trans_privileged.inc.c` 的 `trans_ecall`：`generate_exception(ctx, RISCV_EXCP_U_ECALL); exit_tb(ctx);` |
| 异常入口 | `target/riscv/translate.c` 的 `generate_exception` → `gen_helper_raise_exception` |
| 触发异常 | `target/riscv/op_helper.c` 的 `helper_raise_exception` → `riscv_raise_exception`：写 `exception_index`，`cpu_loop_exit_restore` |
| 异常分发 | `accel/tcg/cpu-exec.c` 的 `cpu_handle_exception` 调用 `cc->do_interrupt` |
| 交付 S 态 | `target/riscv/cpu_helper.c` 的 `riscv_cpu_do_interrupt`：`scause/sepc/stvec`、`SPP=旧 priv`、`priv=S` |
| `sret` 翻译 | `trans_sret`：`gen_helper_sret(cpu_pc, cpu_env, cpu_pc)` |
| `sret` 语义 | `target/riscv/op_helper.c` 的 `helper_sret`：`retpc=sepc`、`SIE=SPIE`、`SPIE=0`、`SPP=U`、`priv=旧 SPP` |
| 生成代码执行 | `accel/tcg/cpu-exec.c`、`code_gen_buffer`、`cpu_tb_exec` |

### TCG 思考要求

- 解释 QEMU 如何把 guest 指令翻译成宿主代码、缓存在 `code_gen_buffer` 中执行；
- 解释为什么 `ecall`/`sret` 在翻译阶段只生成“调用 helper + 结束 TB”的代码，异常/特权切换在 helper 里完成；
- 对比 Lab2 的地址翻译双重调试：同一套双 GDB 方法，Lab2 看 `riscv_cpu_tlb_fill`/`get_physical_address`/`tlb_set_page`，Lab5 看 `helper_raise_exception`/`riscv_cpu_do_interrupt`/`helper_sret`；一个看“地址怎么变”，一个看“特权级怎么变”；
- 说明宿主栈里的 `code_gen_buffer` 帧就是 guest 代码与宿主 C 代码的边界。

### 踩坑与记录要求

至少记录并解释以下真实问题（如果本地遇到别的，也一并写）：

1. `b kern_entry` 不触发：内核链接在 `0xffffffffc0200000`，但上电 PC 是物理 `0x80200000`；
2. `make build-hello` 后直接 `make` 仍跑旧程序：`DEFS` 不是 make 依赖，需要 `make clean && make`；
3. `add-symbol-file` 后地址仍不对：`hello` 与 `exit` 的 `ecall` 地址不同（`0x8000a2` vs `0x800104`）；
4. `gdb -p` 失败：`ptrace_scope=1`，改用宿主 GDB 启动 QEMU；
5. 第一处 `helper_raise_exception` 的 `priv=1`：SBI 的 S 态 ecall；
6. `env->sstatus` 不存在：QEMU 4.1.1 用 `mstatus` 存；
7. 不知道 `sret` 断哪：用 `objdump` 找 `sret` 地址，或 `b __trapret` 后 `si`。

### 输出要求

- 给出完整命令序列、每一步的寄存器/栈/特权级实测值，以及对应源码位置；
- 解释“为什么是这个地址/这个断点条件”，不只贴结果；
- 给出 TCG 与 Lab2 双重调试的联系与差别；
- 记录真实迭代、错误信息、自己的判断和 AI 交互过程，不编造。

### 截图与交付清单

| 文件 | 内容 |
|---|---|
| `report/images/A_gdb_ecall_ucore.png` | 客体 GDB 停在用户 `ecall`，寄存器与用户调用链 |
| `report/images/A_gdb_sret_ucore.png` | 客体 GDB 停在 `sret`，`SPP=0`、`sepc=0x8000a6`、`si` 后 PC |
| `report/images/A_gdb_ecall_qemu.png` | 宿主 GDB 命中 `helper_raise_exception`，`exception=8`、`priv=0`、`code_gen_buffer` 栈 |
| `report/images/A_gdb_sret_qemu.png` | 宿主 GDB 命中 `helper_sret`，`priv=1`、`SPP=0`，以及下一次 ecall 的 `priv=0` |
| `report/gdb/ucore_lab5.gdb` | 客体侧脚本 |
| `report/gdb/qemu_host.gdb` | 宿主侧脚本 |
