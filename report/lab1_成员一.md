# Lab1 实验报告分工说明

> 三人都需要独立完成练习1、练习2的实际操作（读代码 + 跑通GDB调试），
> 报告只是按下面分工各写各的部分，最后由负责整合的同学拼成一份完整的 report.md。

---



## 四、实验内容与实现（练习1）

### 1. 实验目的
阅读 kern/init/entry.S内容代码，结合操作系统内核启动流程， 理解内核启动中的程序入口操作

### 2. 调试过程与现象记录

```c
#include <mmu.h>
#include <memlayout.h>

    .section .text,"ax",%progbits
    .globl kern_entry
kern_entry:
    la sp, bootstacktop

    tail kern_init

.section .data
    # .align 2^12
    .align PGSHIFT
    .global bootstack
bootstack:
    .space KSTACKSIZE
    .global bootstacktop
bootstacktop:
```



#### （1）解释指令 la sp, bootstacktop 

`la` 是 RISC-V 汇编中的伪指令，其作用是将符号 `bootstacktop` 的地址加载到寄存器中。因此这条指令可以理解为：sp    ← bootstacktop，就是将内核启动栈的栈顶地址设置到栈指针寄存器 `sp` 中。  

这样做的目的，是为后续执行 C 语言代码建立一个可用的内核栈环境。OpenSBI 将控制权交给内核时，内核刚刚开始执行，此时还没有准备好自己的 C 语言运行环境，而函数调用、局部变量以及寄存器保存等操作都需要依赖栈。因此，内核必须先设置好 `sp`，才能安全地进入后续的 `kern_init()` 函数。  

#### （2）解释指令 tail kern_init  
`tail kern_init` 的作用是：将处理器的控制权从内核启动入口 `kern_entry` 直接转移到 C 语言编写的 `kern_init()` 函数。

这里的 `tail` 可以理解为一种**尾调用（tail call）**。和普通的函数调用不同，它不需要为当前函数保留一个等待返回的调用现场，而是直接跳转到目标函数。也就是说，内核启动流程可以理解为：

```
OpenSBI
   ↓
0x80200000
   ↓
kern_entry
   ↓
设置 sp
   ↓
tail kern_init
   ↓
kern_init()
```

这里采用 `tail` 形式而不是普通函数调用，是因为 `kern_init()` 不会返回，其内部最终进入无限循环，因此没有必要保留返回到 `kern_entry` 的调用关系。换言之，`tail kern_init` 的主要目的是在内核栈初始化完成后，将执行流程正式交给内核的 C 语言初始化代码

---

## 五、测试与验证

![](屏幕截图 2026-09-30 170442.png)

为了验证 `entry.S` 中两条指令的实际执行效果，使用 QEMU 和 RISC-V GDB 对内核启动过程进行单步调试。

### 1. 验证 `la sp, bootstacktop`

首先启动 QEMU 调试模式，并使用 GDB 连接：

```gdb
set arch riscv:rv64
target remote localhost:1234
```

连接成功后，GDB 显示：

```text
0x0000000000001000 in ?? ()
```

随后设置内核入口断点：

```gdb
b *0x80200000
continue
```

程序停在：

```text
Breakpoint 1, kern_entry () at kern/init/entry.S:7
7    la sp, bootstacktop
```

此时查看 `bootstacktop`：

```gdb
p/x &bootstacktop
```

得到：

```text
$2 = 0x80203000
```

在执行 `la sp, bootstacktop` 之前查看 `sp`：

```gdb
info registers sp
```

得到：

```text
sp = 0x80017ee0
```

然后执行单步：

```gdb
si
```

再次查看 `sp`：

```gdb
info registers sp
```

得到：

```text
sp = 0x80203000
```

再次查看：

```gdb
p/x &bootstacktop
```

结果为：

```text
$3 = 0x80203000
```

因此本次实验实际观察到：

```text
执行前：
sp           = 0x80017ee0
bootstacktop = 0x80203000

执行 la 后：
sp           = 0x80203000
bootstacktop = 0x80203000
```

说明执行 `la sp, bootstacktop` 后，`sp` 的值发生了变化，并与 `bootstacktop` 的地址一致。



进一步查看 `kern_entry` 的反汇编：

```gdb
x/4i 0x80200000
```

得到：

```text
0x80200000 <kern_entry>:    auipc sp,0x3
0x80200004 <kern_entry+4>:  mv    sp,sp
0x80200008 <kern_entry+8>:  j     0x8020000a <kern_init>
0x8020000a <kern_init>:     auipc a0,0x3
```

可以看到 `la sp, bootstacktop` 对应的实际机器指令位于 `0x80200000` 和 `0x80200004`。

------

### 2. 验证 `tail kern_init`

在执行完 `la sp, bootstacktop` 后，继续使用 GDB 单步执行。



执行：

```gdb
si
```

此时 GDB 停在：

```text
0x0000000080200008 in kern_entry () at kern/init/entry.S:9
9    tail kern_init
```

查看当前 PC：

```gdb
p/x $pc
```

得到：

```text
$4 = 0x80200008
```

查看当前指令：

```gdb
x/i $pc
```

得到：

```text
=> 0x80200008 <kern_entry+8>:    j 0x8020000a <kern_init>
```

再次执行：

```gdb
si
```

GDB 进入：

```text
kern_init () at kern/init/init.c:8
8    memset(edata, 0, end - edata);
```

此时查看 PC：

```gdb
p/x $pc
```

得到：

```text
$5 = 0x8020000a
```

查看当前指令：

```gdb
x/4i $pc
```

得到：

```text
0x8020000a <kern_init>:    auipc a0,0x3
0x8020000e <kern_init+4>:  addi  a0,a0,-2
0x80200012 <kern_init+8>:  auipc a2,0x3
0x80200016 <kern_init+12>: addi  a2,a2,-10
```

因此实际执行过程为：

```text
PC = 0x80200008
        ↓
j 0x8020000a
        ↓
PC = 0x8020000a
        ↓
进入 kern_init()
```

由 GDB 单步结果可以确认，执行 `tail kern_init` 对应的跳转指令后，程序从 `kern_entry` 进入了 `kern_init()`。

------

### 3. 验证结果

本次调试得到的关键结果如下：

| 验证内容            | 实际结果      |
| ------------------- | ------------- |
| `bootstacktop` 地址 | `0x80203000`  |
| `la` 执行前 `sp`    | `0x80017ee0`  |
| `la` 执行后 `sp`    | `0x80203000`  |
| `tail` 执行前 PC    | `0x80200008`  |
| `tail` 执行后 PC    | `0x8020000a`  |
| `tail` 后所在函数   | `kern_init()` |

因此，本次实验通过 GDB 对 `entry.S` 中两条关键指令进行了实际单步验证，并观察到了寄存器和程序计数器在执行前后的变化。

---

## Prompt 记录（与chatgpt对话）

#### prompt1：

请结合 `kern/init/entry.S` 以及 `bootstack`、`bootstacktop` 的定义，说明内核启动栈是如何定义的，`bootstacktop` 表示什么，以及为什么进入 `kern_init()` 之前必须先设置 sp。

回答：

```
在 `kern/init/entry.S` 中，内核启动栈定义为：

​```asm
.section .data

.align PGSHIFT
.global bootstack
bootstack:
    .space KSTACKSIZE

.global bootstacktop
bootstacktop:
```

其中 `bootstack` 是启动栈的起始位置，通过 `.space KSTACKSIZE` 为内核预留一段连续的栈空间；`bootstacktop` 位于这段空间之后，表示启动栈的栈顶地址。

本实验中：

```
#define PGSIZE 4096
#define KSTACKPAGE 2
#define KSTACKSIZE (KSTACKPAGE * PGSIZE)
```

因此启动栈大小为：

```
KSTACKSIZE = 2 × 4096 = 8192 bytes = 8 KB
```

内核进入 `kern_entry` 后，通过：

```
la sp, bootstacktop
```

将 `bootstacktop` 的地址设置到栈指针寄存器 `sp` 中。本次实验中通过 GDB 实际观察到：

```
&bootstacktop = 0x80203000
```

执行 `la sp, bootstacktop` 前：

```
sp = 0x80017ee0
```

执行后：

```
sp = 0x80203000
```

因此可以验证 `sp` 已经被设置为启动栈顶地址。

之所以在进入 `kern_init()` 之前必须先设置 `sp`，是因为 `kern_init()` 是 C 语言函数，而 C 语言函数执行需要使用栈来支持函数调用、局部变量等操作。因此，内核必须先建立自己的栈环境，再通过：

```
tail kern_init
```

进入 C 语言编写的内核初始化函数。



#### prompt2：

GDB 实际输出如下：

```
&bootstacktop = 0x80203000

执行前：
sp = 0x80017ee0

执行 `si` 后：
sp = 0x80203000

再次查看：
&bootstacktop = 0x80203000
```

请根据这个实际结果说明 `la sp, bootstacktop` 是否执行正确，以及如何把这个结果作为实验验证。



回答：

根据 GDB 的实际输出：

```
&bootstacktop = 0x80203000
```

说明当前内核启动栈顶地址为 `0x80203000`。

在执行 `la sp, bootstacktop` 之前：

```
sp = 0x80017ee0
```

执行：

```
si
```

单步执行后，`sp` 变为：

```
sp = 0x80203000
```

再次查看：

```
&bootstacktop = 0x80203000
```

可以得到：

```
sp = 0x80203000 = &bootstacktop
```

因此，根据寄存器 `sp` 在执行指令前后的实际变化，可以确认 `la sp, bootstacktop` **执行正确**。这次实验验证表明，该指令执行后，`sp` 已经被设置为 `bootstacktop` 的地址。



#### Prompt3：

GDB 反汇编得到：

```
0x80200000 <kern_entry>:    auipc sp,0x3
0x80200004 <kern_entry+4>:  mv sp,sp
0x80200008 <kern_entry+8>:  j 0x8020000a <kern_init>
```

请解释源码中的：

```
la sp, bootstacktop
```

为什么会对应多条机器指令，以及如何结合 `bootstacktop = 0x80203000` 和当前 PC `0x80200000` 来理解这段反汇编结果。



回答：

 `a sp, bootstacktop` 是 RISC-V 汇编伪指令，需要由多条真实机器指令实现。根据 GDB 反汇编结果，它被展开为 `auipc sp,0x3` 和 `mv sp,sp`。当前 `PC` 为 `0x80200000`，而 `bootstacktop` 为 `0x80203000`，两者相差 `0x3000`。执行 `auipc sp,0x3` 时，立即数 `0x3` 左移 12 位得到 `0x3000`，再与当前 PC `0x80200000` 相加，得到 `0x80203000`。由于低 12 位偏移为 0，第二条指令等价于 `addi sp,sp,0`，不会改变地址。因此最终 `sp` 被设置为 `0x80203000`，即 `bootstacktop` 的地址。这与 GDB 实际观察到的结果一致。 