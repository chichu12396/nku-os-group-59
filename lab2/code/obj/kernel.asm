
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	67450513          	addi	a0,a0,1652 # ffffffffc02016c0 <etext>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	67e50513          	addi	a0,a0,1662 # ffffffffc02016e0 <etext+0x20>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	65258593          	addi	a1,a1,1618 # ffffffffc02016c0 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	68a50513          	addi	a0,a0,1674 # ffffffffc0201700 <etext+0x40>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	69650513          	addi	a0,a0,1686 # ffffffffc0201720 <etext+0x60>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	fe258593          	addi	a1,a1,-30 # ffffffffc0206078 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	6a250513          	addi	a0,a0,1698 # ffffffffc0201740 <etext+0x80>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00006597          	auipc	a1,0x6
ffffffffc02000ae:	3cd58593          	addi	a1,a1,973 # ffffffffc0206477 <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	69450513          	addi	a0,a0,1684 # ffffffffc0201760 <etext+0xa0>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00006517          	auipc	a0,0x6
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0206018 <free_area>
ffffffffc02000e0:	00006617          	auipc	a2,0x6
ffffffffc02000e4:	f9860613          	addi	a2,a2,-104 # ffffffffc0206078 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	5be010ef          	jal	ra,ffffffffc02016ae <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	69450513          	addi	a0,a0,1684 # ffffffffc0201790 <etext+0xd0>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	6ed000ef          	jal	ra,ffffffffc0200ff8 <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	158010ef          	jal	ra,ffffffffc0201298 <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	122010ef          	jal	ra,ffffffffc0201298 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00006317          	auipc	t1,0x6
ffffffffc02001c6:	e6e30313          	addi	t1,t1,-402 # ffffffffc0206030 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	5be50513          	addi	a0,a0,1470 # ffffffffc02017b0 <etext+0xf0>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	58050513          	addi	a0,a0,1408 # ffffffffc0201788 <etext+0xc8>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	3fe0106f          	j	ffffffffc020161a <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	5ae50513          	addi	a0,a0,1454 # ffffffffc02017d0 <etext+0x110>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00006597          	auipc	a1,0x6
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	59050513          	addi	a0,a0,1424 # ffffffffc02017e0 <etext+0x120>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00006417          	auipc	s0,0x6
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0206008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	58a50513          	addi	a0,a0,1418 # ffffffffc02017f0 <etext+0x130>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	59250513          	addi	a0,a0,1426 # ffffffffc0201808 <etext+0x148>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9e75>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	52890913          	addi	s2,s2,1320 # ffffffffc0201858 <etext+0x198>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	51248493          	addi	s1,s1,1298 # ffffffffc0201850 <etext+0x190>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	53e50513          	addi	a0,a0,1342 # ffffffffc02018d0 <etext+0x210>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	56a50513          	addi	a0,a0,1386 # ffffffffc0201908 <etext+0x248>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	44a50513          	addi	a0,a0,1098 # ffffffffc0201828 <etext+0x168>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	248010ef          	jal	ra,ffffffffc0201634 <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	28e010ef          	jal	ra,ffffffffc0201688 <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	1da010ef          	jal	ra,ffffffffc020166a <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	3bc50513          	addi	a0,a0,956 # ffffffffc0201860 <etext+0x1a0>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	30e50513          	addi	a0,a0,782 # ffffffffc0201880 <etext+0x1c0>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	31450513          	addi	a0,a0,788 # ffffffffc0201898 <etext+0x1d8>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	32250513          	addi	a0,a0,802 # ffffffffc02018b8 <etext+0x1f8>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	36650513          	addi	a0,a0,870 # ffffffffc0201908 <etext+0x248>
        memory_base = mem_base;
ffffffffc02005aa:	00006797          	auipc	a5,0x6
ffffffffc02005ae:	a887b723          	sd	s0,-1394(a5) # ffffffffc0206038 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00006797          	auipc	a5,0x6
ffffffffc02005b6:	a967b723          	sd	s6,-1394(a5) # ffffffffc0206040 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00006517          	auipc	a0,0x6
ffffffffc02005c0:	a7c53503          	ld	a0,-1412(a0) # ffffffffc0206038 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00006517          	auipc	a0,0x6
ffffffffc02005ca:	a7a53503          	ld	a0,-1414(a0) # ffffffffc0206040 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005d0:	00006797          	auipc	a5,0x6
ffffffffc02005d4:	a4878793          	addi	a5,a5,-1464 # ffffffffc0206018 <free_area>
ffffffffc02005d8:	e79c                	sd	a5,8(a5)
ffffffffc02005da:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc02005dc:	0007a823          	sw	zero,16(a5)
}
ffffffffc02005e0:	8082                	ret

ffffffffc02005e2 <best_fit_nr_free_pages>:
}

static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02005e2:	00006517          	auipc	a0,0x6
ffffffffc02005e6:	a4656503          	lwu	a0,-1466(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc02005ea:	8082                	ret

ffffffffc02005ec <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc02005ec:	c145                	beqz	a0,ffffffffc020068c <best_fit_alloc_pages+0xa0>
    if (n > nr_free) {
ffffffffc02005ee:	00006597          	auipc	a1,0x6
ffffffffc02005f2:	a2a58593          	addi	a1,a1,-1494 # ffffffffc0206018 <free_area>
ffffffffc02005f6:	0105a883          	lw	a7,16(a1)
ffffffffc02005fa:	862a                	mv	a2,a0
ffffffffc02005fc:	02089793          	slli	a5,a7,0x20
ffffffffc0200600:	9381                	srli	a5,a5,0x20
ffffffffc0200602:	08a7e363          	bltu	a5,a0,ffffffffc0200688 <best_fit_alloc_pages+0x9c>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200606:	659c                	ld	a5,8(a1)
    struct Page *page = NULL;
ffffffffc0200608:	4501                	li	a0,0
    while ((le = list_next(le)) != &free_list) {
ffffffffc020060a:	06b78e63          	beq	a5,a1,ffffffffc0200686 <best_fit_alloc_pages+0x9a>
        if (p->property >= n &&
ffffffffc020060e:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200612:	02071693          	slli	a3,a4,0x20
ffffffffc0200616:	9281                	srli	a3,a3,0x20
ffffffffc0200618:	00c6eb63          	bltu	a3,a2,ffffffffc020062e <best_fit_alloc_pages+0x42>
ffffffffc020061c:	c509                	beqz	a0,ffffffffc0200626 <best_fit_alloc_pages+0x3a>
            (page == NULL || p->property < page->property)) {
ffffffffc020061e:	01052803          	lw	a6,16(a0)
ffffffffc0200622:	01077663          	bgeu	a4,a6,ffffffffc020062e <best_fit_alloc_pages+0x42>
        struct Page *p = le2page(le, page_link);
ffffffffc0200626:	fe878513          	addi	a0,a5,-24
            if (p->property == n) {
ffffffffc020062a:	00c68663          	beq	a3,a2,ffffffffc0200636 <best_fit_alloc_pages+0x4a>
ffffffffc020062e:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200630:	fcb79fe3          	bne	a5,a1,ffffffffc020060e <best_fit_alloc_pages+0x22>
    if (page != NULL) {
ffffffffc0200634:	c929                	beqz	a0,ffffffffc0200686 <best_fit_alloc_pages+0x9a>
        if (page->property > n) {
ffffffffc0200636:	01052803          	lw	a6,16(a0)
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc020063a:	6d18                	ld	a4,24(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc020063c:	7114                	ld	a3,32(a0)
ffffffffc020063e:	02081793          	slli	a5,a6,0x20
ffffffffc0200642:	9381                	srli	a5,a5,0x20
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200644:	e714                	sd	a3,8(a4)
    next->prev = prev;
ffffffffc0200646:	e298                	sd	a4,0(a3)
            p->property = page->property - n;
ffffffffc0200648:	0006031b          	sext.w	t1,a2
        if (page->property > n) {
ffffffffc020064c:	02f67563          	bgeu	a2,a5,ffffffffc0200676 <best_fit_alloc_pages+0x8a>
            struct Page *p = page + n;
ffffffffc0200650:	00261793          	slli	a5,a2,0x2
ffffffffc0200654:	97b2                	add	a5,a5,a2
ffffffffc0200656:	078e                	slli	a5,a5,0x3
ffffffffc0200658:	97aa                	add	a5,a5,a0
            SetPageProperty(p);
ffffffffc020065a:	6790                	ld	a2,8(a5)
            p->property = page->property - n;
ffffffffc020065c:	4068083b          	subw	a6,a6,t1
ffffffffc0200660:	0107a823          	sw	a6,16(a5)
            SetPageProperty(p);
ffffffffc0200664:	00266613          	ori	a2,a2,2
ffffffffc0200668:	e790                	sd	a2,8(a5)
            list_add(prev, &(p->page_link));
ffffffffc020066a:	01878613          	addi	a2,a5,24
    prev->next = next->prev = elm;
ffffffffc020066e:	e290                	sd	a2,0(a3)
ffffffffc0200670:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0200672:	f394                	sd	a3,32(a5)
    elm->prev = prev;
ffffffffc0200674:	ef98                	sd	a4,24(a5)
        ClearPageProperty(page);
ffffffffc0200676:	651c                	ld	a5,8(a0)
        nr_free -= n;
ffffffffc0200678:	406888bb          	subw	a7,a7,t1
ffffffffc020067c:	0115a823          	sw	a7,16(a1)
        ClearPageProperty(page);
ffffffffc0200680:	9bf5                	andi	a5,a5,-3
ffffffffc0200682:	e51c                	sd	a5,8(a0)
ffffffffc0200684:	8082                	ret
}
ffffffffc0200686:	8082                	ret
        return NULL;
ffffffffc0200688:	4501                	li	a0,0
ffffffffc020068a:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc020068c:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc020068e:	00001697          	auipc	a3,0x1
ffffffffc0200692:	29268693          	addi	a3,a3,658 # ffffffffc0201920 <etext+0x260>
ffffffffc0200696:	00001617          	auipc	a2,0x1
ffffffffc020069a:	29260613          	addi	a2,a2,658 # ffffffffc0201928 <etext+0x268>
ffffffffc020069e:	03400593          	li	a1,52
ffffffffc02006a2:	00001517          	auipc	a0,0x1
ffffffffc02006a6:	29e50513          	addi	a0,a0,670 # ffffffffc0201940 <etext+0x280>
best_fit_alloc_pages(size_t n) {
ffffffffc02006aa:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02006ac:	b17ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02006b0 <best_fit_check>:
    free_page(p1);
    free_page(p2);
}

static void
best_fit_check(void) {
ffffffffc02006b0:	715d                	addi	sp,sp,-80
ffffffffc02006b2:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc02006b4:	00006417          	auipc	s0,0x6
ffffffffc02006b8:	96440413          	addi	s0,s0,-1692 # ffffffffc0206018 <free_area>
ffffffffc02006bc:	641c                	ld	a5,8(s0)
ffffffffc02006be:	e486                	sd	ra,72(sp)
ffffffffc02006c0:	fc26                	sd	s1,56(sp)
ffffffffc02006c2:	f84a                	sd	s2,48(sp)
ffffffffc02006c4:	f44e                	sd	s3,40(sp)
ffffffffc02006c6:	f052                	sd	s4,32(sp)
ffffffffc02006c8:	ec56                	sd	s5,24(sp)
ffffffffc02006ca:	e85a                	sd	s6,16(sp)
ffffffffc02006cc:	e45e                	sd	s7,8(sp)
ffffffffc02006ce:	e062                	sd	s8,0(sp)
    int score = 0, sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006d0:	26878963          	beq	a5,s0,ffffffffc0200942 <best_fit_check+0x292>
    int count = 0, total = 0;
ffffffffc02006d4:	4481                	li	s1,0
ffffffffc02006d6:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc02006d8:	ff07b703          	ld	a4,-16(a5)
ffffffffc02006dc:	8b09                	andi	a4,a4,2
ffffffffc02006de:	26070663          	beqz	a4,ffffffffc020094a <best_fit_check+0x29a>
        count++, total += p->property;
ffffffffc02006e2:	ff87a703          	lw	a4,-8(a5)
ffffffffc02006e6:	679c                	ld	a5,8(a5)
ffffffffc02006e8:	2905                	addiw	s2,s2,1
ffffffffc02006ea:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc02006ec:	fe8796e3          	bne	a5,s0,ffffffffc02006d8 <best_fit_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc02006f0:	89a6                	mv	s3,s1
ffffffffc02006f2:	0fb000ef          	jal	ra,ffffffffc0200fec <nr_free_pages>
ffffffffc02006f6:	33351a63          	bne	a0,s3,ffffffffc0200a2a <best_fit_check+0x37a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02006fa:	4505                	li	a0,1
ffffffffc02006fc:	0d9000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc0200700:	8a2a                	mv	s4,a0
ffffffffc0200702:	36050463          	beqz	a0,ffffffffc0200a6a <best_fit_check+0x3ba>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200706:	4505                	li	a0,1
ffffffffc0200708:	0cd000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc020070c:	89aa                	mv	s3,a0
ffffffffc020070e:	32050e63          	beqz	a0,ffffffffc0200a4a <best_fit_check+0x39a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200712:	4505                	li	a0,1
ffffffffc0200714:	0c1000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc0200718:	8aaa                	mv	s5,a0
ffffffffc020071a:	2c050863          	beqz	a0,ffffffffc02009ea <best_fit_check+0x33a>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc020071e:	253a0663          	beq	s4,s3,ffffffffc020096a <best_fit_check+0x2ba>
ffffffffc0200722:	24aa0463          	beq	s4,a0,ffffffffc020096a <best_fit_check+0x2ba>
ffffffffc0200726:	24a98263          	beq	s3,a0,ffffffffc020096a <best_fit_check+0x2ba>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc020072a:	000a2783          	lw	a5,0(s4)
ffffffffc020072e:	24079e63          	bnez	a5,ffffffffc020098a <best_fit_check+0x2da>
ffffffffc0200732:	0009a783          	lw	a5,0(s3)
ffffffffc0200736:	24079a63          	bnez	a5,ffffffffc020098a <best_fit_check+0x2da>
ffffffffc020073a:	411c                	lw	a5,0(a0)
ffffffffc020073c:	24079763          	bnez	a5,ffffffffc020098a <best_fit_check+0x2da>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200740:	00006797          	auipc	a5,0x6
ffffffffc0200744:	9107b783          	ld	a5,-1776(a5) # ffffffffc0206050 <pages>
ffffffffc0200748:	40fa0733          	sub	a4,s4,a5
ffffffffc020074c:	870d                	srai	a4,a4,0x3
ffffffffc020074e:	00002597          	auipc	a1,0x2
ffffffffc0200752:	9525b583          	ld	a1,-1710(a1) # ffffffffc02020a0 <error_string+0x38>
ffffffffc0200756:	02b70733          	mul	a4,a4,a1
ffffffffc020075a:	00002617          	auipc	a2,0x2
ffffffffc020075e:	94e63603          	ld	a2,-1714(a2) # ffffffffc02020a8 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200762:	00006697          	auipc	a3,0x6
ffffffffc0200766:	8e66b683          	ld	a3,-1818(a3) # ffffffffc0206048 <npage>
ffffffffc020076a:	06b2                	slli	a3,a3,0xc
ffffffffc020076c:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc020076e:	0732                	slli	a4,a4,0xc
ffffffffc0200770:	22d77d63          	bgeu	a4,a3,ffffffffc02009aa <best_fit_check+0x2fa>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200774:	40f98733          	sub	a4,s3,a5
ffffffffc0200778:	870d                	srai	a4,a4,0x3
ffffffffc020077a:	02b70733          	mul	a4,a4,a1
ffffffffc020077e:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200780:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200782:	3ed77463          	bgeu	a4,a3,ffffffffc0200b6a <best_fit_check+0x4ba>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200786:	40f507b3          	sub	a5,a0,a5
ffffffffc020078a:	878d                	srai	a5,a5,0x3
ffffffffc020078c:	02b787b3          	mul	a5,a5,a1
ffffffffc0200790:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200792:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200794:	3ad7fb63          	bgeu	a5,a3,ffffffffc0200b4a <best_fit_check+0x49a>
    assert(alloc_page() == NULL);
ffffffffc0200798:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020079a:	00043c03          	ld	s8,0(s0)
ffffffffc020079e:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc02007a2:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc02007a6:	e400                	sd	s0,8(s0)
ffffffffc02007a8:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc02007aa:	00006797          	auipc	a5,0x6
ffffffffc02007ae:	8607af23          	sw	zero,-1922(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc02007b2:	023000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02007b6:	36051a63          	bnez	a0,ffffffffc0200b2a <best_fit_check+0x47a>
    free_page(p0);
ffffffffc02007ba:	4585                	li	a1,1
ffffffffc02007bc:	8552                	mv	a0,s4
ffffffffc02007be:	023000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    free_page(p1);
ffffffffc02007c2:	4585                	li	a1,1
ffffffffc02007c4:	854e                	mv	a0,s3
ffffffffc02007c6:	01b000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    free_page(p2);
ffffffffc02007ca:	4585                	li	a1,1
ffffffffc02007cc:	8556                	mv	a0,s5
ffffffffc02007ce:	013000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    assert(nr_free == 3);
ffffffffc02007d2:	4818                	lw	a4,16(s0)
ffffffffc02007d4:	478d                	li	a5,3
ffffffffc02007d6:	32f71a63          	bne	a4,a5,ffffffffc0200b0a <best_fit_check+0x45a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02007da:	4505                	li	a0,1
ffffffffc02007dc:	7f8000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02007e0:	89aa                	mv	s3,a0
ffffffffc02007e2:	30050463          	beqz	a0,ffffffffc0200aea <best_fit_check+0x43a>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02007e6:	4505                	li	a0,1
ffffffffc02007e8:	7ec000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02007ec:	8aaa                	mv	s5,a0
ffffffffc02007ee:	2c050e63          	beqz	a0,ffffffffc0200aca <best_fit_check+0x41a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02007f2:	4505                	li	a0,1
ffffffffc02007f4:	7e0000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02007f8:	8a2a                	mv	s4,a0
ffffffffc02007fa:	2a050863          	beqz	a0,ffffffffc0200aaa <best_fit_check+0x3fa>
    assert(alloc_page() == NULL);
ffffffffc02007fe:	4505                	li	a0,1
ffffffffc0200800:	7d4000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc0200804:	28051363          	bnez	a0,ffffffffc0200a8a <best_fit_check+0x3da>
    free_page(p0);
ffffffffc0200808:	4585                	li	a1,1
ffffffffc020080a:	854e                	mv	a0,s3
ffffffffc020080c:	7d4000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200810:	641c                	ld	a5,8(s0)
ffffffffc0200812:	1a878c63          	beq	a5,s0,ffffffffc02009ca <best_fit_check+0x31a>
    assert((p = alloc_page()) == p0);
ffffffffc0200816:	4505                	li	a0,1
ffffffffc0200818:	7bc000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc020081c:	52a99763          	bne	s3,a0,ffffffffc0200d4a <best_fit_check+0x69a>
    assert(alloc_page() == NULL);
ffffffffc0200820:	4505                	li	a0,1
ffffffffc0200822:	7b2000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc0200826:	50051263          	bnez	a0,ffffffffc0200d2a <best_fit_check+0x67a>
    assert(nr_free == 0);
ffffffffc020082a:	481c                	lw	a5,16(s0)
ffffffffc020082c:	4c079f63          	bnez	a5,ffffffffc0200d0a <best_fit_check+0x65a>
    free_page(p);
ffffffffc0200830:	854e                	mv	a0,s3
ffffffffc0200832:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200834:	01843023          	sd	s8,0(s0)
ffffffffc0200838:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc020083c:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200840:	7a0000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    free_page(p1);
ffffffffc0200844:	4585                	li	a1,1
ffffffffc0200846:	8556                	mv	a0,s5
ffffffffc0200848:	798000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    free_page(p2);
ffffffffc020084c:	4585                	li	a1,1
ffffffffc020084e:	8552                	mv	a0,s4
ffffffffc0200850:	790000ef          	jal	ra,ffffffffc0200fe0 <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200854:	4515                	li	a0,5
ffffffffc0200856:	77e000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc020085a:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc020085c:	48050763          	beqz	a0,ffffffffc0200cea <best_fit_check+0x63a>
    assert(!PageProperty(p0));
ffffffffc0200860:	651c                	ld	a5,8(a0)
ffffffffc0200862:	8b89                	andi	a5,a5,2
ffffffffc0200864:	46079363          	bnez	a5,ffffffffc0200cca <best_fit_check+0x61a>
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200868:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc020086a:	00043b03          	ld	s6,0(s0)
ffffffffc020086e:	00843a83          	ld	s5,8(s0)
ffffffffc0200872:	e000                	sd	s0,0(s0)
ffffffffc0200874:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200876:	75e000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc020087a:	42051863          	bnez	a0,ffffffffc0200caa <best_fit_check+0x5fa>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc020087e:	4589                	li	a1,2
ffffffffc0200880:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc0200884:	01042b83          	lw	s7,16(s0)
    free_pages(p0 + 4, 1);
ffffffffc0200888:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc020088c:	00005797          	auipc	a5,0x5
ffffffffc0200890:	7807ae23          	sw	zero,1948(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0200894:	74c000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0200898:	8562                	mv	a0,s8
ffffffffc020089a:	4585                	li	a1,1
ffffffffc020089c:	744000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc02008a0:	4511                	li	a0,4
ffffffffc02008a2:	732000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02008a6:	3e051263          	bnez	a0,ffffffffc0200c8a <best_fit_check+0x5da>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc02008aa:	0309b783          	ld	a5,48(s3)
ffffffffc02008ae:	8b89                	andi	a5,a5,2
ffffffffc02008b0:	3a078d63          	beqz	a5,ffffffffc0200c6a <best_fit_check+0x5ba>
ffffffffc02008b4:	0389a703          	lw	a4,56(s3)
ffffffffc02008b8:	4789                	li	a5,2
ffffffffc02008ba:	3af71863          	bne	a4,a5,ffffffffc0200c6a <best_fit_check+0x5ba>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc02008be:	4505                	li	a0,1
ffffffffc02008c0:	714000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02008c4:	8a2a                	mv	s4,a0
ffffffffc02008c6:	38050263          	beqz	a0,ffffffffc0200c4a <best_fit_check+0x59a>
    assert(alloc_pages(2) != NULL);
ffffffffc02008ca:	4509                	li	a0,2
ffffffffc02008cc:	708000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02008d0:	34050d63          	beqz	a0,ffffffffc0200c2a <best_fit_check+0x57a>
    assert(p0 + 4 == p1);
ffffffffc02008d4:	334c1b63          	bne	s8,s4,ffffffffc0200c0a <best_fit_check+0x55a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc02008d8:	854e                	mv	a0,s3
ffffffffc02008da:	4595                	li	a1,5
ffffffffc02008dc:	704000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02008e0:	4515                	li	a0,5
ffffffffc02008e2:	6f2000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02008e6:	89aa                	mv	s3,a0
ffffffffc02008e8:	30050163          	beqz	a0,ffffffffc0200bea <best_fit_check+0x53a>
    assert(alloc_page() == NULL);
ffffffffc02008ec:	4505                	li	a0,1
ffffffffc02008ee:	6e6000ef          	jal	ra,ffffffffc0200fd4 <alloc_pages>
ffffffffc02008f2:	2c051c63          	bnez	a0,ffffffffc0200bca <best_fit_check+0x51a>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc02008f6:	481c                	lw	a5,16(s0)
ffffffffc02008f8:	2a079963          	bnez	a5,ffffffffc0200baa <best_fit_check+0x4fa>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc02008fc:	4595                	li	a1,5
ffffffffc02008fe:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc0200900:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc0200904:	01643023          	sd	s6,0(s0)
ffffffffc0200908:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc020090c:	6d4000ef          	jal	ra,ffffffffc0200fe0 <free_pages>
    return listelm->next;
ffffffffc0200910:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200912:	00878963          	beq	a5,s0,ffffffffc0200924 <best_fit_check+0x274>
        struct Page *p = le2page(le, page_link);
        count--, total -= p->property;
ffffffffc0200916:	ff87a703          	lw	a4,-8(a5)
ffffffffc020091a:	679c                	ld	a5,8(a5)
ffffffffc020091c:	397d                	addiw	s2,s2,-1
ffffffffc020091e:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200920:	fe879be3          	bne	a5,s0,ffffffffc0200916 <best_fit_check+0x266>
    }
    assert(count == 0);
ffffffffc0200924:	26091363          	bnez	s2,ffffffffc0200b8a <best_fit_check+0x4da>
    assert(total == 0);
ffffffffc0200928:	e0ed                	bnez	s1,ffffffffc0200a0a <best_fit_check+0x35a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
}
ffffffffc020092a:	60a6                	ld	ra,72(sp)
ffffffffc020092c:	6406                	ld	s0,64(sp)
ffffffffc020092e:	74e2                	ld	s1,56(sp)
ffffffffc0200930:	7942                	ld	s2,48(sp)
ffffffffc0200932:	79a2                	ld	s3,40(sp)
ffffffffc0200934:	7a02                	ld	s4,32(sp)
ffffffffc0200936:	6ae2                	ld	s5,24(sp)
ffffffffc0200938:	6b42                	ld	s6,16(sp)
ffffffffc020093a:	6ba2                	ld	s7,8(sp)
ffffffffc020093c:	6c02                	ld	s8,0(sp)
ffffffffc020093e:	6161                	addi	sp,sp,80
ffffffffc0200940:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200942:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200944:	4481                	li	s1,0
ffffffffc0200946:	4901                	li	s2,0
ffffffffc0200948:	b36d                	j	ffffffffc02006f2 <best_fit_check+0x42>
        assert(PageProperty(p));
ffffffffc020094a:	00001697          	auipc	a3,0x1
ffffffffc020094e:	00e68693          	addi	a3,a3,14 # ffffffffc0201958 <etext+0x298>
ffffffffc0200952:	00001617          	auipc	a2,0x1
ffffffffc0200956:	fd660613          	addi	a2,a2,-42 # ffffffffc0201928 <etext+0x268>
ffffffffc020095a:	0d000593          	li	a1,208
ffffffffc020095e:	00001517          	auipc	a0,0x1
ffffffffc0200962:	fe250513          	addi	a0,a0,-30 # ffffffffc0201940 <etext+0x280>
ffffffffc0200966:	85dff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc020096a:	00001697          	auipc	a3,0x1
ffffffffc020096e:	07e68693          	addi	a3,a3,126 # ffffffffc02019e8 <etext+0x328>
ffffffffc0200972:	00001617          	auipc	a2,0x1
ffffffffc0200976:	fb660613          	addi	a2,a2,-74 # ffffffffc0201928 <etext+0x268>
ffffffffc020097a:	09e00593          	li	a1,158
ffffffffc020097e:	00001517          	auipc	a0,0x1
ffffffffc0200982:	fc250513          	addi	a0,a0,-62 # ffffffffc0201940 <etext+0x280>
ffffffffc0200986:	83dff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc020098a:	00001697          	auipc	a3,0x1
ffffffffc020098e:	08668693          	addi	a3,a3,134 # ffffffffc0201a10 <etext+0x350>
ffffffffc0200992:	00001617          	auipc	a2,0x1
ffffffffc0200996:	f9660613          	addi	a2,a2,-106 # ffffffffc0201928 <etext+0x268>
ffffffffc020099a:	09f00593          	li	a1,159
ffffffffc020099e:	00001517          	auipc	a0,0x1
ffffffffc02009a2:	fa250513          	addi	a0,a0,-94 # ffffffffc0201940 <etext+0x280>
ffffffffc02009a6:	81dff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009aa:	00001697          	auipc	a3,0x1
ffffffffc02009ae:	0a668693          	addi	a3,a3,166 # ffffffffc0201a50 <etext+0x390>
ffffffffc02009b2:	00001617          	auipc	a2,0x1
ffffffffc02009b6:	f7660613          	addi	a2,a2,-138 # ffffffffc0201928 <etext+0x268>
ffffffffc02009ba:	0a100593          	li	a1,161
ffffffffc02009be:	00001517          	auipc	a0,0x1
ffffffffc02009c2:	f8250513          	addi	a0,a0,-126 # ffffffffc0201940 <etext+0x280>
ffffffffc02009c6:	ffcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc02009ca:	00001697          	auipc	a3,0x1
ffffffffc02009ce:	10e68693          	addi	a3,a3,270 # ffffffffc0201ad8 <etext+0x418>
ffffffffc02009d2:	00001617          	auipc	a2,0x1
ffffffffc02009d6:	f5660613          	addi	a2,a2,-170 # ffffffffc0201928 <etext+0x268>
ffffffffc02009da:	0ba00593          	li	a1,186
ffffffffc02009de:	00001517          	auipc	a0,0x1
ffffffffc02009e2:	f6250513          	addi	a0,a0,-158 # ffffffffc0201940 <etext+0x280>
ffffffffc02009e6:	fdcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02009ea:	00001697          	auipc	a3,0x1
ffffffffc02009ee:	fde68693          	addi	a3,a3,-34 # ffffffffc02019c8 <etext+0x308>
ffffffffc02009f2:	00001617          	auipc	a2,0x1
ffffffffc02009f6:	f3660613          	addi	a2,a2,-202 # ffffffffc0201928 <etext+0x268>
ffffffffc02009fa:	09c00593          	li	a1,156
ffffffffc02009fe:	00001517          	auipc	a0,0x1
ffffffffc0200a02:	f4250513          	addi	a0,a0,-190 # ffffffffc0201940 <etext+0x280>
ffffffffc0200a06:	fbcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == 0);
ffffffffc0200a0a:	00001697          	auipc	a3,0x1
ffffffffc0200a0e:	1fe68693          	addi	a3,a3,510 # ffffffffc0201c08 <etext+0x548>
ffffffffc0200a12:	00001617          	auipc	a2,0x1
ffffffffc0200a16:	f1660613          	addi	a2,a2,-234 # ffffffffc0201928 <etext+0x268>
ffffffffc0200a1a:	11200593          	li	a1,274
ffffffffc0200a1e:	00001517          	auipc	a0,0x1
ffffffffc0200a22:	f2250513          	addi	a0,a0,-222 # ffffffffc0201940 <etext+0x280>
ffffffffc0200a26:	f9cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200a2a:	00001697          	auipc	a3,0x1
ffffffffc0200a2e:	f3e68693          	addi	a3,a3,-194 # ffffffffc0201968 <etext+0x2a8>
ffffffffc0200a32:	00001617          	auipc	a2,0x1
ffffffffc0200a36:	ef660613          	addi	a2,a2,-266 # ffffffffc0201928 <etext+0x268>
ffffffffc0200a3a:	0d300593          	li	a1,211
ffffffffc0200a3e:	00001517          	auipc	a0,0x1
ffffffffc0200a42:	f0250513          	addi	a0,a0,-254 # ffffffffc0201940 <etext+0x280>
ffffffffc0200a46:	f7cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a4a:	00001697          	auipc	a3,0x1
ffffffffc0200a4e:	f5e68693          	addi	a3,a3,-162 # ffffffffc02019a8 <etext+0x2e8>
ffffffffc0200a52:	00001617          	auipc	a2,0x1
ffffffffc0200a56:	ed660613          	addi	a2,a2,-298 # ffffffffc0201928 <etext+0x268>
ffffffffc0200a5a:	09b00593          	li	a1,155
ffffffffc0200a5e:	00001517          	auipc	a0,0x1
ffffffffc0200a62:	ee250513          	addi	a0,a0,-286 # ffffffffc0201940 <etext+0x280>
ffffffffc0200a66:	f5cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a6a:	00001697          	auipc	a3,0x1
ffffffffc0200a6e:	f1e68693          	addi	a3,a3,-226 # ffffffffc0201988 <etext+0x2c8>
ffffffffc0200a72:	00001617          	auipc	a2,0x1
ffffffffc0200a76:	eb660613          	addi	a2,a2,-330 # ffffffffc0201928 <etext+0x268>
ffffffffc0200a7a:	09a00593          	li	a1,154
ffffffffc0200a7e:	00001517          	auipc	a0,0x1
ffffffffc0200a82:	ec250513          	addi	a0,a0,-318 # ffffffffc0201940 <etext+0x280>
ffffffffc0200a86:	f3cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200a8a:	00001697          	auipc	a3,0x1
ffffffffc0200a8e:	02668693          	addi	a3,a3,38 # ffffffffc0201ab0 <etext+0x3f0>
ffffffffc0200a92:	00001617          	auipc	a2,0x1
ffffffffc0200a96:	e9660613          	addi	a2,a2,-362 # ffffffffc0201928 <etext+0x268>
ffffffffc0200a9a:	0b700593          	li	a1,183
ffffffffc0200a9e:	00001517          	auipc	a0,0x1
ffffffffc0200aa2:	ea250513          	addi	a0,a0,-350 # ffffffffc0201940 <etext+0x280>
ffffffffc0200aa6:	f1cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200aaa:	00001697          	auipc	a3,0x1
ffffffffc0200aae:	f1e68693          	addi	a3,a3,-226 # ffffffffc02019c8 <etext+0x308>
ffffffffc0200ab2:	00001617          	auipc	a2,0x1
ffffffffc0200ab6:	e7660613          	addi	a2,a2,-394 # ffffffffc0201928 <etext+0x268>
ffffffffc0200aba:	0b500593          	li	a1,181
ffffffffc0200abe:	00001517          	auipc	a0,0x1
ffffffffc0200ac2:	e8250513          	addi	a0,a0,-382 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ac6:	efcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200aca:	00001697          	auipc	a3,0x1
ffffffffc0200ace:	ede68693          	addi	a3,a3,-290 # ffffffffc02019a8 <etext+0x2e8>
ffffffffc0200ad2:	00001617          	auipc	a2,0x1
ffffffffc0200ad6:	e5660613          	addi	a2,a2,-426 # ffffffffc0201928 <etext+0x268>
ffffffffc0200ada:	0b400593          	li	a1,180
ffffffffc0200ade:	00001517          	auipc	a0,0x1
ffffffffc0200ae2:	e6250513          	addi	a0,a0,-414 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ae6:	edcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200aea:	00001697          	auipc	a3,0x1
ffffffffc0200aee:	e9e68693          	addi	a3,a3,-354 # ffffffffc0201988 <etext+0x2c8>
ffffffffc0200af2:	00001617          	auipc	a2,0x1
ffffffffc0200af6:	e3660613          	addi	a2,a2,-458 # ffffffffc0201928 <etext+0x268>
ffffffffc0200afa:	0b300593          	li	a1,179
ffffffffc0200afe:	00001517          	auipc	a0,0x1
ffffffffc0200b02:	e4250513          	addi	a0,a0,-446 # ffffffffc0201940 <etext+0x280>
ffffffffc0200b06:	ebcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 3);
ffffffffc0200b0a:	00001697          	auipc	a3,0x1
ffffffffc0200b0e:	fbe68693          	addi	a3,a3,-66 # ffffffffc0201ac8 <etext+0x408>
ffffffffc0200b12:	00001617          	auipc	a2,0x1
ffffffffc0200b16:	e1660613          	addi	a2,a2,-490 # ffffffffc0201928 <etext+0x268>
ffffffffc0200b1a:	0b100593          	li	a1,177
ffffffffc0200b1e:	00001517          	auipc	a0,0x1
ffffffffc0200b22:	e2250513          	addi	a0,a0,-478 # ffffffffc0201940 <etext+0x280>
ffffffffc0200b26:	e9cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200b2a:	00001697          	auipc	a3,0x1
ffffffffc0200b2e:	f8668693          	addi	a3,a3,-122 # ffffffffc0201ab0 <etext+0x3f0>
ffffffffc0200b32:	00001617          	auipc	a2,0x1
ffffffffc0200b36:	df660613          	addi	a2,a2,-522 # ffffffffc0201928 <etext+0x268>
ffffffffc0200b3a:	0ac00593          	li	a1,172
ffffffffc0200b3e:	00001517          	auipc	a0,0x1
ffffffffc0200b42:	e0250513          	addi	a0,a0,-510 # ffffffffc0201940 <etext+0x280>
ffffffffc0200b46:	e7cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200b4a:	00001697          	auipc	a3,0x1
ffffffffc0200b4e:	f4668693          	addi	a3,a3,-186 # ffffffffc0201a90 <etext+0x3d0>
ffffffffc0200b52:	00001617          	auipc	a2,0x1
ffffffffc0200b56:	dd660613          	addi	a2,a2,-554 # ffffffffc0201928 <etext+0x268>
ffffffffc0200b5a:	0a300593          	li	a1,163
ffffffffc0200b5e:	00001517          	auipc	a0,0x1
ffffffffc0200b62:	de250513          	addi	a0,a0,-542 # ffffffffc0201940 <etext+0x280>
ffffffffc0200b66:	e5cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200b6a:	00001697          	auipc	a3,0x1
ffffffffc0200b6e:	f0668693          	addi	a3,a3,-250 # ffffffffc0201a70 <etext+0x3b0>
ffffffffc0200b72:	00001617          	auipc	a2,0x1
ffffffffc0200b76:	db660613          	addi	a2,a2,-586 # ffffffffc0201928 <etext+0x268>
ffffffffc0200b7a:	0a200593          	li	a1,162
ffffffffc0200b7e:	00001517          	auipc	a0,0x1
ffffffffc0200b82:	dc250513          	addi	a0,a0,-574 # ffffffffc0201940 <etext+0x280>
ffffffffc0200b86:	e3cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(count == 0);
ffffffffc0200b8a:	00001697          	auipc	a3,0x1
ffffffffc0200b8e:	06e68693          	addi	a3,a3,110 # ffffffffc0201bf8 <etext+0x538>
ffffffffc0200b92:	00001617          	auipc	a2,0x1
ffffffffc0200b96:	d9660613          	addi	a2,a2,-618 # ffffffffc0201928 <etext+0x268>
ffffffffc0200b9a:	11100593          	li	a1,273
ffffffffc0200b9e:	00001517          	auipc	a0,0x1
ffffffffc0200ba2:	da250513          	addi	a0,a0,-606 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ba6:	e1cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200baa:	00001697          	auipc	a3,0x1
ffffffffc0200bae:	f6668693          	addi	a3,a3,-154 # ffffffffc0201b10 <etext+0x450>
ffffffffc0200bb2:	00001617          	auipc	a2,0x1
ffffffffc0200bb6:	d7660613          	addi	a2,a2,-650 # ffffffffc0201928 <etext+0x268>
ffffffffc0200bba:	10600593          	li	a1,262
ffffffffc0200bbe:	00001517          	auipc	a0,0x1
ffffffffc0200bc2:	d8250513          	addi	a0,a0,-638 # ffffffffc0201940 <etext+0x280>
ffffffffc0200bc6:	dfcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200bca:	00001697          	auipc	a3,0x1
ffffffffc0200bce:	ee668693          	addi	a3,a3,-282 # ffffffffc0201ab0 <etext+0x3f0>
ffffffffc0200bd2:	00001617          	auipc	a2,0x1
ffffffffc0200bd6:	d5660613          	addi	a2,a2,-682 # ffffffffc0201928 <etext+0x268>
ffffffffc0200bda:	10000593          	li	a1,256
ffffffffc0200bde:	00001517          	auipc	a0,0x1
ffffffffc0200be2:	d6250513          	addi	a0,a0,-670 # ffffffffc0201940 <etext+0x280>
ffffffffc0200be6:	ddcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200bea:	00001697          	auipc	a3,0x1
ffffffffc0200bee:	fee68693          	addi	a3,a3,-18 # ffffffffc0201bd8 <etext+0x518>
ffffffffc0200bf2:	00001617          	auipc	a2,0x1
ffffffffc0200bf6:	d3660613          	addi	a2,a2,-714 # ffffffffc0201928 <etext+0x268>
ffffffffc0200bfa:	0ff00593          	li	a1,255
ffffffffc0200bfe:	00001517          	auipc	a0,0x1
ffffffffc0200c02:	d4250513          	addi	a0,a0,-702 # ffffffffc0201940 <etext+0x280>
ffffffffc0200c06:	dbcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 + 4 == p1);
ffffffffc0200c0a:	00001697          	auipc	a3,0x1
ffffffffc0200c0e:	fbe68693          	addi	a3,a3,-66 # ffffffffc0201bc8 <etext+0x508>
ffffffffc0200c12:	00001617          	auipc	a2,0x1
ffffffffc0200c16:	d1660613          	addi	a2,a2,-746 # ffffffffc0201928 <etext+0x268>
ffffffffc0200c1a:	0f700593          	li	a1,247
ffffffffc0200c1e:	00001517          	auipc	a0,0x1
ffffffffc0200c22:	d2250513          	addi	a0,a0,-734 # ffffffffc0201940 <etext+0x280>
ffffffffc0200c26:	d9cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(2) != NULL);
ffffffffc0200c2a:	00001697          	auipc	a3,0x1
ffffffffc0200c2e:	f8668693          	addi	a3,a3,-122 # ffffffffc0201bb0 <etext+0x4f0>
ffffffffc0200c32:	00001617          	auipc	a2,0x1
ffffffffc0200c36:	cf660613          	addi	a2,a2,-778 # ffffffffc0201928 <etext+0x268>
ffffffffc0200c3a:	0f600593          	li	a1,246
ffffffffc0200c3e:	00001517          	auipc	a0,0x1
ffffffffc0200c42:	d0250513          	addi	a0,a0,-766 # ffffffffc0201940 <etext+0x280>
ffffffffc0200c46:	d7cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200c4a:	00001697          	auipc	a3,0x1
ffffffffc0200c4e:	f4668693          	addi	a3,a3,-186 # ffffffffc0201b90 <etext+0x4d0>
ffffffffc0200c52:	00001617          	auipc	a2,0x1
ffffffffc0200c56:	cd660613          	addi	a2,a2,-810 # ffffffffc0201928 <etext+0x268>
ffffffffc0200c5a:	0f500593          	li	a1,245
ffffffffc0200c5e:	00001517          	auipc	a0,0x1
ffffffffc0200c62:	ce250513          	addi	a0,a0,-798 # ffffffffc0201940 <etext+0x280>
ffffffffc0200c66:	d5cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200c6a:	00001697          	auipc	a3,0x1
ffffffffc0200c6e:	ef668693          	addi	a3,a3,-266 # ffffffffc0201b60 <etext+0x4a0>
ffffffffc0200c72:	00001617          	auipc	a2,0x1
ffffffffc0200c76:	cb660613          	addi	a2,a2,-842 # ffffffffc0201928 <etext+0x268>
ffffffffc0200c7a:	0f300593          	li	a1,243
ffffffffc0200c7e:	00001517          	auipc	a0,0x1
ffffffffc0200c82:	cc250513          	addi	a0,a0,-830 # ffffffffc0201940 <etext+0x280>
ffffffffc0200c86:	d3cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200c8a:	00001697          	auipc	a3,0x1
ffffffffc0200c8e:	ebe68693          	addi	a3,a3,-322 # ffffffffc0201b48 <etext+0x488>
ffffffffc0200c92:	00001617          	auipc	a2,0x1
ffffffffc0200c96:	c9660613          	addi	a2,a2,-874 # ffffffffc0201928 <etext+0x268>
ffffffffc0200c9a:	0f200593          	li	a1,242
ffffffffc0200c9e:	00001517          	auipc	a0,0x1
ffffffffc0200ca2:	ca250513          	addi	a0,a0,-862 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ca6:	d1cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200caa:	00001697          	auipc	a3,0x1
ffffffffc0200cae:	e0668693          	addi	a3,a3,-506 # ffffffffc0201ab0 <etext+0x3f0>
ffffffffc0200cb2:	00001617          	auipc	a2,0x1
ffffffffc0200cb6:	c7660613          	addi	a2,a2,-906 # ffffffffc0201928 <etext+0x268>
ffffffffc0200cba:	0e600593          	li	a1,230
ffffffffc0200cbe:	00001517          	auipc	a0,0x1
ffffffffc0200cc2:	c8250513          	addi	a0,a0,-894 # ffffffffc0201940 <etext+0x280>
ffffffffc0200cc6:	cfcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200cca:	00001697          	auipc	a3,0x1
ffffffffc0200cce:	e6668693          	addi	a3,a3,-410 # ffffffffc0201b30 <etext+0x470>
ffffffffc0200cd2:	00001617          	auipc	a2,0x1
ffffffffc0200cd6:	c5660613          	addi	a2,a2,-938 # ffffffffc0201928 <etext+0x268>
ffffffffc0200cda:	0dd00593          	li	a1,221
ffffffffc0200cde:	00001517          	auipc	a0,0x1
ffffffffc0200ce2:	c6250513          	addi	a0,a0,-926 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ce6:	cdcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != NULL);
ffffffffc0200cea:	00001697          	auipc	a3,0x1
ffffffffc0200cee:	e3668693          	addi	a3,a3,-458 # ffffffffc0201b20 <etext+0x460>
ffffffffc0200cf2:	00001617          	auipc	a2,0x1
ffffffffc0200cf6:	c3660613          	addi	a2,a2,-970 # ffffffffc0201928 <etext+0x268>
ffffffffc0200cfa:	0dc00593          	li	a1,220
ffffffffc0200cfe:	00001517          	auipc	a0,0x1
ffffffffc0200d02:	c4250513          	addi	a0,a0,-958 # ffffffffc0201940 <etext+0x280>
ffffffffc0200d06:	cbcff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200d0a:	00001697          	auipc	a3,0x1
ffffffffc0200d0e:	e0668693          	addi	a3,a3,-506 # ffffffffc0201b10 <etext+0x450>
ffffffffc0200d12:	00001617          	auipc	a2,0x1
ffffffffc0200d16:	c1660613          	addi	a2,a2,-1002 # ffffffffc0201928 <etext+0x268>
ffffffffc0200d1a:	0c000593          	li	a1,192
ffffffffc0200d1e:	00001517          	auipc	a0,0x1
ffffffffc0200d22:	c2250513          	addi	a0,a0,-990 # ffffffffc0201940 <etext+0x280>
ffffffffc0200d26:	c9cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d2a:	00001697          	auipc	a3,0x1
ffffffffc0200d2e:	d8668693          	addi	a3,a3,-634 # ffffffffc0201ab0 <etext+0x3f0>
ffffffffc0200d32:	00001617          	auipc	a2,0x1
ffffffffc0200d36:	bf660613          	addi	a2,a2,-1034 # ffffffffc0201928 <etext+0x268>
ffffffffc0200d3a:	0be00593          	li	a1,190
ffffffffc0200d3e:	00001517          	auipc	a0,0x1
ffffffffc0200d42:	c0250513          	addi	a0,a0,-1022 # ffffffffc0201940 <etext+0x280>
ffffffffc0200d46:	c7cff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200d4a:	00001697          	auipc	a3,0x1
ffffffffc0200d4e:	da668693          	addi	a3,a3,-602 # ffffffffc0201af0 <etext+0x430>
ffffffffc0200d52:	00001617          	auipc	a2,0x1
ffffffffc0200d56:	bd660613          	addi	a2,a2,-1066 # ffffffffc0201928 <etext+0x268>
ffffffffc0200d5a:	0bd00593          	li	a1,189
ffffffffc0200d5e:	00001517          	auipc	a0,0x1
ffffffffc0200d62:	be250513          	addi	a0,a0,-1054 # ffffffffc0201940 <etext+0x280>
ffffffffc0200d66:	c5cff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200d6a <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc0200d6a:	1141                	addi	sp,sp,-16
ffffffffc0200d6c:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200d6e:	14058c63          	beqz	a1,ffffffffc0200ec6 <best_fit_free_pages+0x15c>
    for (; p != base + n; p++) {
ffffffffc0200d72:	00259693          	slli	a3,a1,0x2
ffffffffc0200d76:	96ae                	add	a3,a3,a1
ffffffffc0200d78:	068e                	slli	a3,a3,0x3
ffffffffc0200d7a:	96aa                	add	a3,a3,a0
ffffffffc0200d7c:	87aa                	mv	a5,a0
ffffffffc0200d7e:	00d50e63          	beq	a0,a3,ffffffffc0200d9a <best_fit_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200d82:	6798                	ld	a4,8(a5)
ffffffffc0200d84:	8b0d                	andi	a4,a4,3
ffffffffc0200d86:	12071063          	bnez	a4,ffffffffc0200ea6 <best_fit_free_pages+0x13c>
        p->flags = 0;
ffffffffc0200d8a:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200d8e:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200d92:	02878793          	addi	a5,a5,40
ffffffffc0200d96:	fed796e3          	bne	a5,a3,ffffffffc0200d82 <best_fit_free_pages+0x18>
    SetPageProperty(base);
ffffffffc0200d9a:	00853883          	ld	a7,8(a0)
    nr_free += n;
ffffffffc0200d9e:	00005697          	auipc	a3,0x5
ffffffffc0200da2:	27a68693          	addi	a3,a3,634 # ffffffffc0206018 <free_area>
ffffffffc0200da6:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200da8:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200daa:	0028e613          	ori	a2,a7,2
    return list->next == list;
ffffffffc0200dae:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200db0:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200db2:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200db4:	9f2d                	addw	a4,a4,a1
ffffffffc0200db6:	ca98                	sw	a4,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200db8:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200dbc:	0ad78b63          	beq	a5,a3,ffffffffc0200e72 <best_fit_free_pages+0x108>
            struct Page *page = le2page(le, page_link);
ffffffffc0200dc0:	fe878713          	addi	a4,a5,-24
ffffffffc0200dc4:	0006b303          	ld	t1,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0200dc8:	4801                	li	a6,0
            if (base < page) {
ffffffffc0200dca:	00e56a63          	bltu	a0,a4,ffffffffc0200dde <best_fit_free_pages+0x74>
    return listelm->next;
ffffffffc0200dce:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200dd0:	06d70563          	beq	a4,a3,ffffffffc0200e3a <best_fit_free_pages+0xd0>
    for (; p != base + n; p++) {
ffffffffc0200dd4:	87ba                	mv	a5,a4
            struct Page *page = le2page(le, page_link);
ffffffffc0200dd6:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200dda:	fee57ae3          	bgeu	a0,a4,ffffffffc0200dce <best_fit_free_pages+0x64>
ffffffffc0200dde:	00080463          	beqz	a6,ffffffffc0200de6 <best_fit_free_pages+0x7c>
ffffffffc0200de2:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200de6:	0007b803          	ld	a6,0(a5)
    prev->next = next->prev = elm;
ffffffffc0200dea:	e390                	sd	a2,0(a5)
ffffffffc0200dec:	00c83423          	sd	a2,8(a6)
    elm->next = next;
ffffffffc0200df0:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200df2:	01053c23          	sd	a6,24(a0)
    if (le != &free_list) {
ffffffffc0200df6:	02d80463          	beq	a6,a3,ffffffffc0200e1e <best_fit_free_pages+0xb4>
        if (p + p->property == base) {
ffffffffc0200dfa:	ff882e03          	lw	t3,-8(a6)
        p = le2page(le, page_link);
ffffffffc0200dfe:	fe880313          	addi	t1,a6,-24
        if (p + p->property == base) {
ffffffffc0200e02:	020e1613          	slli	a2,t3,0x20
ffffffffc0200e06:	9201                	srli	a2,a2,0x20
ffffffffc0200e08:	00261713          	slli	a4,a2,0x2
ffffffffc0200e0c:	9732                	add	a4,a4,a2
ffffffffc0200e0e:	070e                	slli	a4,a4,0x3
ffffffffc0200e10:	971a                	add	a4,a4,t1
ffffffffc0200e12:	02e50e63          	beq	a0,a4,ffffffffc0200e4e <best_fit_free_pages+0xe4>
    if (le != &free_list) {
ffffffffc0200e16:	00d78f63          	beq	a5,a3,ffffffffc0200e34 <best_fit_free_pages+0xca>
ffffffffc0200e1a:	fe878713          	addi	a4,a5,-24
        if (base + base->property == p) {
ffffffffc0200e1e:	490c                	lw	a1,16(a0)
ffffffffc0200e20:	02059613          	slli	a2,a1,0x20
ffffffffc0200e24:	9201                	srli	a2,a2,0x20
ffffffffc0200e26:	00261693          	slli	a3,a2,0x2
ffffffffc0200e2a:	96b2                	add	a3,a3,a2
ffffffffc0200e2c:	068e                	slli	a3,a3,0x3
ffffffffc0200e2e:	96aa                	add	a3,a3,a0
ffffffffc0200e30:	04d70863          	beq	a4,a3,ffffffffc0200e80 <best_fit_free_pages+0x116>
}
ffffffffc0200e34:	60a2                	ld	ra,8(sp)
ffffffffc0200e36:	0141                	addi	sp,sp,16
ffffffffc0200e38:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200e3a:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200e3c:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200e3e:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200e40:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200e42:	02d70463          	beq	a4,a3,ffffffffc0200e6a <best_fit_free_pages+0x100>
    prev->next = next->prev = elm;
ffffffffc0200e46:	8332                	mv	t1,a2
ffffffffc0200e48:	4805                	li	a6,1
    for (; p != base + n; p++) {
ffffffffc0200e4a:	87ba                	mv	a5,a4
ffffffffc0200e4c:	b769                	j	ffffffffc0200dd6 <best_fit_free_pages+0x6c>
            p->property += base->property;
ffffffffc0200e4e:	01c585bb          	addw	a1,a1,t3
ffffffffc0200e52:	feb82c23          	sw	a1,-8(a6)
            ClearPageProperty(base);
ffffffffc0200e56:	ffd8f893          	andi	a7,a7,-3
ffffffffc0200e5a:	01153423          	sd	a7,8(a0)
    prev->next = next;
ffffffffc0200e5e:	00f83423          	sd	a5,8(a6)
    next->prev = prev;
ffffffffc0200e62:	0107b023          	sd	a6,0(a5)
            base = p;
ffffffffc0200e66:	851a                	mv	a0,t1
ffffffffc0200e68:	b77d                	j	ffffffffc0200e16 <best_fit_free_pages+0xac>
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200e6a:	883e                	mv	a6,a5
ffffffffc0200e6c:	e290                	sd	a2,0(a3)
ffffffffc0200e6e:	87b6                	mv	a5,a3
ffffffffc0200e70:	b769                	j	ffffffffc0200dfa <best_fit_free_pages+0x90>
}
ffffffffc0200e72:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200e74:	e390                	sd	a2,0(a5)
ffffffffc0200e76:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200e78:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200e7a:	ed1c                	sd	a5,24(a0)
ffffffffc0200e7c:	0141                	addi	sp,sp,16
ffffffffc0200e7e:	8082                	ret
            base->property += p->property;
ffffffffc0200e80:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc0200e84:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200e88:	0007b803          	ld	a6,0(a5)
ffffffffc0200e8c:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc0200e8e:	9db5                	addw	a1,a1,a3
ffffffffc0200e90:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc0200e92:	9b75                	andi	a4,a4,-3
ffffffffc0200e94:	fee7b823          	sd	a4,-16(a5)
}
ffffffffc0200e98:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc0200e9a:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc0200e9e:	01063023          	sd	a6,0(a2)
ffffffffc0200ea2:	0141                	addi	sp,sp,16
ffffffffc0200ea4:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200ea6:	00001697          	auipc	a3,0x1
ffffffffc0200eaa:	d7268693          	addi	a3,a3,-654 # ffffffffc0201c18 <etext+0x558>
ffffffffc0200eae:	00001617          	auipc	a2,0x1
ffffffffc0200eb2:	a7a60613          	addi	a2,a2,-1414 # ffffffffc0201928 <etext+0x268>
ffffffffc0200eb6:	06200593          	li	a1,98
ffffffffc0200eba:	00001517          	auipc	a0,0x1
ffffffffc0200ebe:	a8650513          	addi	a0,a0,-1402 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ec2:	b00ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200ec6:	00001697          	auipc	a3,0x1
ffffffffc0200eca:	a5a68693          	addi	a3,a3,-1446 # ffffffffc0201920 <etext+0x260>
ffffffffc0200ece:	00001617          	auipc	a2,0x1
ffffffffc0200ed2:	a5a60613          	addi	a2,a2,-1446 # ffffffffc0201928 <etext+0x268>
ffffffffc0200ed6:	05e00593          	li	a1,94
ffffffffc0200eda:	00001517          	auipc	a0,0x1
ffffffffc0200ede:	a6650513          	addi	a0,a0,-1434 # ffffffffc0201940 <etext+0x280>
ffffffffc0200ee2:	ae0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200ee6 <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc0200ee6:	1141                	addi	sp,sp,-16
ffffffffc0200ee8:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200eea:	c5f1                	beqz	a1,ffffffffc0200fb6 <best_fit_init_memmap+0xd0>
    for (; p != base + n; p++) {
ffffffffc0200eec:	00259693          	slli	a3,a1,0x2
ffffffffc0200ef0:	96ae                	add	a3,a3,a1
ffffffffc0200ef2:	068e                	slli	a3,a3,0x3
ffffffffc0200ef4:	96aa                	add	a3,a3,a0
ffffffffc0200ef6:	87aa                	mv	a5,a0
ffffffffc0200ef8:	00d50f63          	beq	a0,a3,ffffffffc0200f16 <best_fit_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0200efc:	6798                	ld	a4,8(a5)
ffffffffc0200efe:	8b05                	andi	a4,a4,1
ffffffffc0200f00:	cf41                	beqz	a4,ffffffffc0200f98 <best_fit_init_memmap+0xb2>
        p->flags = p->property = 0;
ffffffffc0200f02:	0007a823          	sw	zero,16(a5)
ffffffffc0200f06:	0007b423          	sd	zero,8(a5)
ffffffffc0200f0a:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200f0e:	02878793          	addi	a5,a5,40
ffffffffc0200f12:	fed795e3          	bne	a5,a3,ffffffffc0200efc <best_fit_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0200f16:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0200f18:	00005697          	auipc	a3,0x5
ffffffffc0200f1c:	10068693          	addi	a3,a3,256 # ffffffffc0206018 <free_area>
ffffffffc0200f20:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200f22:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0200f24:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc0200f28:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0200f2a:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0200f2c:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0200f2e:	9db9                	addw	a1,a1,a4
ffffffffc0200f30:	ca8c                	sw	a1,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0200f32:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0200f36:	04d78a63          	beq	a5,a3,ffffffffc0200f8a <best_fit_init_memmap+0xa4>
            struct Page *page = le2page(le, page_link);
ffffffffc0200f3a:	fe878713          	addi	a4,a5,-24
ffffffffc0200f3e:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0200f42:	4581                	li	a1,0
            if (base < page) {
ffffffffc0200f44:	00e56a63          	bltu	a0,a4,ffffffffc0200f58 <best_fit_init_memmap+0x72>
    return listelm->next;
ffffffffc0200f48:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0200f4a:	02d70263          	beq	a4,a3,ffffffffc0200f6e <best_fit_init_memmap+0x88>
    for (; p != base + n; p++) {
ffffffffc0200f4e:	87ba                	mv	a5,a4
            struct Page *page = le2page(le, page_link);
ffffffffc0200f50:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0200f54:	fee57ae3          	bgeu	a0,a4,ffffffffc0200f48 <best_fit_init_memmap+0x62>
ffffffffc0200f58:	c199                	beqz	a1,ffffffffc0200f5e <best_fit_init_memmap+0x78>
ffffffffc0200f5a:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200f5e:	6398                	ld	a4,0(a5)
}
ffffffffc0200f60:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0200f62:	e390                	sd	a2,0(a5)
ffffffffc0200f64:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0200f66:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200f68:	ed18                	sd	a4,24(a0)
ffffffffc0200f6a:	0141                	addi	sp,sp,16
ffffffffc0200f6c:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0200f6e:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f70:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0200f72:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0200f74:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0200f76:	00d70663          	beq	a4,a3,ffffffffc0200f82 <best_fit_init_memmap+0x9c>
    prev->next = next->prev = elm;
ffffffffc0200f7a:	8832                	mv	a6,a2
ffffffffc0200f7c:	4585                	li	a1,1
    for (; p != base + n; p++) {
ffffffffc0200f7e:	87ba                	mv	a5,a4
ffffffffc0200f80:	bfc1                	j	ffffffffc0200f50 <best_fit_init_memmap+0x6a>
}
ffffffffc0200f82:	60a2                	ld	ra,8(sp)
ffffffffc0200f84:	e290                	sd	a2,0(a3)
ffffffffc0200f86:	0141                	addi	sp,sp,16
ffffffffc0200f88:	8082                	ret
ffffffffc0200f8a:	60a2                	ld	ra,8(sp)
ffffffffc0200f8c:	e390                	sd	a2,0(a5)
ffffffffc0200f8e:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200f90:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200f92:	ed1c                	sd	a5,24(a0)
ffffffffc0200f94:	0141                	addi	sp,sp,16
ffffffffc0200f96:	8082                	ret
        assert(PageReserved(p));
ffffffffc0200f98:	00001697          	auipc	a3,0x1
ffffffffc0200f9c:	ca868693          	addi	a3,a3,-856 # ffffffffc0201c40 <etext+0x580>
ffffffffc0200fa0:	00001617          	auipc	a2,0x1
ffffffffc0200fa4:	98860613          	addi	a2,a2,-1656 # ffffffffc0201928 <etext+0x268>
ffffffffc0200fa8:	45e5                	li	a1,25
ffffffffc0200faa:	00001517          	auipc	a0,0x1
ffffffffc0200fae:	99650513          	addi	a0,a0,-1642 # ffffffffc0201940 <etext+0x280>
ffffffffc0200fb2:	a10ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200fb6:	00001697          	auipc	a3,0x1
ffffffffc0200fba:	96a68693          	addi	a3,a3,-1686 # ffffffffc0201920 <etext+0x260>
ffffffffc0200fbe:	00001617          	auipc	a2,0x1
ffffffffc0200fc2:	96a60613          	addi	a2,a2,-1686 # ffffffffc0201928 <etext+0x268>
ffffffffc0200fc6:	45d5                	li	a1,21
ffffffffc0200fc8:	00001517          	auipc	a0,0x1
ffffffffc0200fcc:	97850513          	addi	a0,a0,-1672 # ffffffffc0201940 <etext+0x280>
ffffffffc0200fd0:	9f2ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200fd4 <alloc_pages>:

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n)
{
    return pmm_manager->alloc_pages(n);
ffffffffc0200fd4:	00005797          	auipc	a5,0x5
ffffffffc0200fd8:	0847b783          	ld	a5,132(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc0200fdc:	6f9c                	ld	a5,24(a5)
ffffffffc0200fde:	8782                	jr	a5

ffffffffc0200fe0 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n)
{
    pmm_manager->free_pages(base, n);
ffffffffc0200fe0:	00005797          	auipc	a5,0x5
ffffffffc0200fe4:	0787b783          	ld	a5,120(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc0200fe8:	739c                	ld	a5,32(a5)
ffffffffc0200fea:	8782                	jr	a5

ffffffffc0200fec <nr_free_pages>:

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void)
{
    return pmm_manager->nr_free_pages();
ffffffffc0200fec:	00005797          	auipc	a5,0x5
ffffffffc0200ff0:	06c7b783          	ld	a5,108(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc0200ff4:	779c                	ld	a5,40(a5)
ffffffffc0200ff6:	8782                	jr	a5

ffffffffc0200ff8 <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0200ff8:	00001797          	auipc	a5,0x1
ffffffffc0200ffc:	c7078793          	addi	a5,a5,-912 # ffffffffc0201c68 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201000:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(free_begin), (managed_end - free_begin) / PGSIZE);
    }
}
/* pmm_init - initialize the physical memory management */
void pmm_init(void)
{
ffffffffc0201002:	7179                	addi	sp,sp,-48
ffffffffc0201004:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201006:	00001517          	auipc	a0,0x1
ffffffffc020100a:	c9a50513          	addi	a0,a0,-870 # ffffffffc0201ca0 <best_fit_pmm_manager+0x38>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc020100e:	00005417          	auipc	s0,0x5
ffffffffc0201012:	04a40413          	addi	s0,s0,74 # ffffffffc0206058 <pmm_manager>
{
ffffffffc0201016:	f406                	sd	ra,40(sp)
ffffffffc0201018:	e84a                	sd	s2,16(sp)
ffffffffc020101a:	ec26                	sd	s1,24(sp)
ffffffffc020101c:	e44e                	sd	s3,8(sp)
ffffffffc020101e:	e052                	sd	s4,0(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0201020:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201022:	92aff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc0201026:	601c                	ld	a5,0(s0)
ffffffffc0201028:	679c                	ld	a5,8(a5)
ffffffffc020102a:	9782                	jalr	a5
    uint64_t mem_base = get_memory_base();
ffffffffc020102c:	d90ff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0201030:	892a                	mv	s2,a0
    uint64_t mem_size = get_memory_size();
ffffffffc0201032:	d94ff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_base == 0 || mem_size == 0 ||
ffffffffc0201036:	16090e63          	beqz	s2,ffffffffc02011b2 <pmm_init+0x1ba>
ffffffffc020103a:	8a2a                	mv	s4,a0
ffffffffc020103c:	16050b63          	beqz	a0,ffffffffc02011b2 <pmm_init+0x1ba>
        mem_size > (uint64_t)-1 - mem_base)
ffffffffc0201040:	fff94793          	not	a5,s2
    if (mem_base == 0 || mem_size == 0 ||
ffffffffc0201044:	16a7e763          	bltu	a5,a0,ffffffffc02011b2 <pmm_init+0x1ba>
    if (mem_base < DRAM_BASE || mem_base > KERNEL_BEGIN_PADDR ||
ffffffffc0201048:	800007b7          	lui	a5,0x80000
ffffffffc020104c:	97ca                	add	a5,a5,s2
ffffffffc020104e:	00200737          	lui	a4,0x200
    uint64_t mem_end = mem_base + mem_size;
ffffffffc0201052:	00a909b3          	add	s3,s2,a0
    if (mem_base < DRAM_BASE || mem_base > KERNEL_BEGIN_PADDR ||
ffffffffc0201056:	14f76263          	bltu	a4,a5,ffffffffc020119a <pmm_init+0x1a2>
ffffffffc020105a:	40100793          	li	a5,1025
ffffffffc020105e:	07d6                	slli	a5,a5,0x15
ffffffffc0201060:	1337fd63          	bgeu	a5,s3,ffffffffc020119a <pmm_init+0x1a2>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201064:	57f5                	li	a5,-3
ffffffffc0201066:	07fa                	slli	a5,a5,0x1e
ffffffffc0201068:	00005497          	auipc	s1,0x5
ffffffffc020106c:	00848493          	addi	s1,s1,8 # ffffffffc0206070 <va_pa_offset>
    cprintf("physical memory map:\n");
ffffffffc0201070:	00001517          	auipc	a0,0x1
ffffffffc0201074:	cb850513          	addi	a0,a0,-840 # ffffffffc0201d28 <best_fit_pmm_manager+0xc0>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201078:	e09c                	sd	a5,0(s1)
    cprintf("physical memory map:\n");
ffffffffc020107a:	8d2ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n",
ffffffffc020107e:	fff98693          	addi	a3,s3,-1
ffffffffc0201082:	864a                	mv	a2,s2
ffffffffc0201084:	85d2                	mv	a1,s4
ffffffffc0201086:	00001517          	auipc	a0,0x1
ffffffffc020108a:	cba50513          	addi	a0,a0,-838 # ffffffffc0201d40 <best_fit_pmm_manager+0xd8>
ffffffffc020108e:	8beff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uintptr_t managed_end = mem_end < PHYSICAL_MEMORY_END
ffffffffc0201092:	47c5                	li	a5,17
ffffffffc0201094:	07ee                	slli	a5,a5,0x1b
ffffffffc0201096:	0d37ee63          	bltu	a5,s3,ffffffffc0201172 <pmm_init+0x17a>
    managed_end = ROUNDDOWN(managed_end, PGSIZE);
ffffffffc020109a:	77fd                	lui	a5,0xfffff
ffffffffc020109c:	00f9f5b3          	and	a1,s3,a5
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02010a0:	00006697          	auipc	a3,0x6
ffffffffc02010a4:	fd768693          	addi	a3,a3,-41 # ffffffffc0207077 <end+0xfff>
ffffffffc02010a8:	8efd                	and	a3,a3,a5
    npage = PPN(managed_end);
ffffffffc02010aa:	00c5d893          	srli	a7,a1,0xc
ffffffffc02010ae:	00005797          	auipc	a5,0x5
ffffffffc02010b2:	f917bd23          	sd	a7,-102(a5) # ffffffffc0206048 <npage>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02010b6:	00005797          	auipc	a5,0x5
ffffffffc02010ba:	f8d7bd23          	sd	a3,-102(a5) # ffffffffc0206050 <pages>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02010be:	c02007b7          	lui	a5,0xc0200
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02010c2:	8536                	mv	a0,a3
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02010c4:	12f6ec63          	bltu	a3,a5,ffffffffc02011fc <pmm_init+0x204>
ffffffffc02010c8:	0004b803          	ld	a6,0(s1)
    size_t descriptor_bytes = (npage - nbase) * sizeof(struct Page);
ffffffffc02010cc:	00289713          	slli	a4,a7,0x2
ffffffffc02010d0:	9746                	add	a4,a4,a7
ffffffffc02010d2:	070e                	slli	a4,a4,0x3
ffffffffc02010d4:	fec007b7          	lui	a5,0xfec00
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02010d8:	41068633          	sub	a2,a3,a6
    size_t descriptor_bytes = (npage - nbase) * sizeof(struct Page);
ffffffffc02010dc:	00f70333          	add	t1,a4,a5
    if (pages_pa >= managed_end ||
ffffffffc02010e0:	0eb67563          	bgeu	a2,a1,ffffffffc02011ca <pmm_init+0x1d2>
        descriptor_bytes > managed_end - pages_pa)
ffffffffc02010e4:	40d80833          	sub	a6,a6,a3
ffffffffc02010e8:	982e                	add	a6,a6,a1
    if (pages_pa >= managed_end ||
ffffffffc02010ea:	0e686063          	bltu	a6,t1,ffffffffc02011ca <pmm_init+0x1d2>
    for (size_t i = 0; i < npage - nbase; i++)
ffffffffc02010ee:	97b6                	add	a5,a5,a3
ffffffffc02010f0:	973e                	add	a4,a4,a5
        SetPageReserved(&pages[i]);
ffffffffc02010f2:	4805                	li	a6,1
        pages[i].property = 0;
ffffffffc02010f4:	01868793          	addi	a5,a3,24
ffffffffc02010f8:	0006a823          	sw	zero,16(a3)
ffffffffc02010fc:	0006a023          	sw	zero,0(a3)
    elm->prev = elm->next = elm;
ffffffffc0201100:	f29c                	sd	a5,32(a3)
ffffffffc0201102:	ee9c                	sd	a5,24(a3)
        SetPageReserved(&pages[i]);
ffffffffc0201104:	0106b423          	sd	a6,8(a3)
    for (size_t i = 0; i < npage - nbase; i++)
ffffffffc0201108:	02868693          	addi	a3,a3,40
ffffffffc020110c:	fee694e3          	bne	a3,a4,ffffffffc02010f4 <pmm_init+0xfc>
    uintptr_t free_begin = ROUNDUP(pages_pa + descriptor_bytes, PGSIZE);
ffffffffc0201110:	6785                	lui	a5,0x1
ffffffffc0201112:	17fd                	addi	a5,a5,-1
ffffffffc0201114:	963e                	add	a2,a2,a5
ffffffffc0201116:	961a                	add	a2,a2,t1
ffffffffc0201118:	77fd                	lui	a5,0xfffff
ffffffffc020111a:	8e7d                	and	a2,a2,a5
    if (free_begin < managed_end)
ffffffffc020111c:	04b66d63          	bltu	a2,a1,ffffffffc0201176 <pmm_init+0x17e>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void)
{
    pmm_manager->check();
ffffffffc0201120:	601c                	ld	a5,0(s0)
ffffffffc0201122:	7b9c                	ld	a5,48(a5)
ffffffffc0201124:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0201126:	00001517          	auipc	a0,0x1
ffffffffc020112a:	cd250513          	addi	a0,a0,-814 # ffffffffc0201df8 <best_fit_pmm_manager+0x190>
ffffffffc020112e:	81eff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t *)boot_page_table_sv39;
ffffffffc0201132:	00004597          	auipc	a1,0x4
ffffffffc0201136:	ece58593          	addi	a1,a1,-306 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc020113a:	00005797          	auipc	a5,0x5
ffffffffc020113e:	f2b7b723          	sd	a1,-210(a5) # ffffffffc0206068 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201142:	c02007b7          	lui	a5,0xc0200
ffffffffc0201146:	08f5ee63          	bltu	a1,a5,ffffffffc02011e2 <pmm_init+0x1ea>
ffffffffc020114a:	6090                	ld	a2,0(s1)
}
ffffffffc020114c:	7402                	ld	s0,32(sp)
ffffffffc020114e:	70a2                	ld	ra,40(sp)
ffffffffc0201150:	64e2                	ld	s1,24(sp)
ffffffffc0201152:	6942                	ld	s2,16(sp)
ffffffffc0201154:	69a2                	ld	s3,8(sp)
ffffffffc0201156:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201158:	40c58633          	sub	a2,a1,a2
ffffffffc020115c:	00005797          	auipc	a5,0x5
ffffffffc0201160:	f0c7b223          	sd	a2,-252(a5) # ffffffffc0206060 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201164:	00001517          	auipc	a0,0x1
ffffffffc0201168:	cb450513          	addi	a0,a0,-844 # ffffffffc0201e18 <best_fit_pmm_manager+0x1b0>
}
ffffffffc020116c:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020116e:	fdffe06f          	j	ffffffffc020014c <cprintf>
    uintptr_t managed_end = mem_end < PHYSICAL_MEMORY_END
ffffffffc0201172:	89be                	mv	s3,a5
ffffffffc0201174:	b71d                	j	ffffffffc020109a <pmm_init+0xa2>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0201176:	00c65793          	srli	a5,a2,0xc
ffffffffc020117a:	0917fd63          	bgeu	a5,a7,ffffffffc0201214 <pmm_init+0x21c>
    pmm_manager->init_memmap(base, n);
ffffffffc020117e:	6014                	ld	a3,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc0201180:	fff80737          	lui	a4,0xfff80
ffffffffc0201184:	973e                	add	a4,a4,a5
ffffffffc0201186:	00271793          	slli	a5,a4,0x2
ffffffffc020118a:	97ba                	add	a5,a5,a4
ffffffffc020118c:	6a98                	ld	a4,16(a3)
        init_memmap(pa2page(free_begin), (managed_end - free_begin) / PGSIZE);
ffffffffc020118e:	8d91                	sub	a1,a1,a2
ffffffffc0201190:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0201192:	81b1                	srli	a1,a1,0xc
ffffffffc0201194:	953e                	add	a0,a0,a5
ffffffffc0201196:	9702                	jalr	a4
}
ffffffffc0201198:	b761                	j	ffffffffc0201120 <pmm_init+0x128>
        panic("DTB memory does not cover the kernel memory layout");
ffffffffc020119a:	00001617          	auipc	a2,0x1
ffffffffc020119e:	b5660613          	addi	a2,a2,-1194 # ffffffffc0201cf0 <best_fit_pmm_manager+0x88>
ffffffffc02011a2:	06300593          	li	a1,99
ffffffffc02011a6:	00001517          	auipc	a0,0x1
ffffffffc02011aa:	b3a50513          	addi	a0,a0,-1222 # ffffffffc0201ce0 <best_fit_pmm_manager+0x78>
ffffffffc02011ae:	814ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("invalid physical memory range from DTB");
ffffffffc02011b2:	00001617          	auipc	a2,0x1
ffffffffc02011b6:	b0660613          	addi	a2,a2,-1274 # ffffffffc0201cb8 <best_fit_pmm_manager+0x50>
ffffffffc02011ba:	05d00593          	li	a1,93
ffffffffc02011be:	00001517          	auipc	a0,0x1
ffffffffc02011c2:	b2250513          	addi	a0,a0,-1246 # ffffffffc0201ce0 <best_fit_pmm_manager+0x78>
ffffffffc02011c6:	ffdfe0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("not enough memory for physical page descriptors");
ffffffffc02011ca:	00001617          	auipc	a2,0x1
ffffffffc02011ce:	bce60613          	addi	a2,a2,-1074 # ffffffffc0201d98 <best_fit_pmm_manager+0x130>
ffffffffc02011d2:	08000593          	li	a1,128
ffffffffc02011d6:	00001517          	auipc	a0,0x1
ffffffffc02011da:	b0a50513          	addi	a0,a0,-1270 # ffffffffc0201ce0 <best_fit_pmm_manager+0x78>
ffffffffc02011de:	fe5fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02011e2:	86ae                	mv	a3,a1
ffffffffc02011e4:	00001617          	auipc	a2,0x1
ffffffffc02011e8:	b8c60613          	addi	a2,a2,-1140 # ffffffffc0201d70 <best_fit_pmm_manager+0x108>
ffffffffc02011ec:	0aa00593          	li	a1,170
ffffffffc02011f0:	00001517          	auipc	a0,0x1
ffffffffc02011f4:	af050513          	addi	a0,a0,-1296 # ffffffffc0201ce0 <best_fit_pmm_manager+0x78>
ffffffffc02011f8:	fcbfe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02011fc:	00001617          	auipc	a2,0x1
ffffffffc0201200:	b7460613          	addi	a2,a2,-1164 # ffffffffc0201d70 <best_fit_pmm_manager+0x108>
ffffffffc0201204:	07b00593          	li	a1,123
ffffffffc0201208:	00001517          	auipc	a0,0x1
ffffffffc020120c:	ad850513          	addi	a0,a0,-1320 # ffffffffc0201ce0 <best_fit_pmm_manager+0x78>
ffffffffc0201210:	fb3fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc0201214:	00001617          	auipc	a2,0x1
ffffffffc0201218:	bb460613          	addi	a2,a2,-1100 # ffffffffc0201dc8 <best_fit_pmm_manager+0x160>
ffffffffc020121c:	06a00593          	li	a1,106
ffffffffc0201220:	00001517          	auipc	a0,0x1
ffffffffc0201224:	bc850513          	addi	a0,a0,-1080 # ffffffffc0201de8 <best_fit_pmm_manager+0x180>
ffffffffc0201228:	f9bfe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020122c <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc020122c:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201230:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201232:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201236:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201238:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020123c:	f022                	sd	s0,32(sp)
ffffffffc020123e:	ec26                	sd	s1,24(sp)
ffffffffc0201240:	e84a                	sd	s2,16(sp)
ffffffffc0201242:	f406                	sd	ra,40(sp)
ffffffffc0201244:	e44e                	sd	s3,8(sp)
ffffffffc0201246:	84aa                	mv	s1,a0
ffffffffc0201248:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc020124a:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc020124e:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0201250:	03067e63          	bgeu	a2,a6,ffffffffc020128c <printnum+0x60>
ffffffffc0201254:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0201256:	00805763          	blez	s0,ffffffffc0201264 <printnum+0x38>
ffffffffc020125a:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc020125c:	85ca                	mv	a1,s2
ffffffffc020125e:	854e                	mv	a0,s3
ffffffffc0201260:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201262:	fc65                	bnez	s0,ffffffffc020125a <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201264:	1a02                	slli	s4,s4,0x20
ffffffffc0201266:	00001797          	auipc	a5,0x1
ffffffffc020126a:	bf278793          	addi	a5,a5,-1038 # ffffffffc0201e58 <best_fit_pmm_manager+0x1f0>
ffffffffc020126e:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201272:	9a3e                	add	s4,s4,a5
}
ffffffffc0201274:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201276:	000a4503          	lbu	a0,0(s4)
}
ffffffffc020127a:	70a2                	ld	ra,40(sp)
ffffffffc020127c:	69a2                	ld	s3,8(sp)
ffffffffc020127e:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201280:	85ca                	mv	a1,s2
ffffffffc0201282:	87a6                	mv	a5,s1
}
ffffffffc0201284:	6942                	ld	s2,16(sp)
ffffffffc0201286:	64e2                	ld	s1,24(sp)
ffffffffc0201288:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020128a:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc020128c:	03065633          	divu	a2,a2,a6
ffffffffc0201290:	8722                	mv	a4,s0
ffffffffc0201292:	f9bff0ef          	jal	ra,ffffffffc020122c <printnum>
ffffffffc0201296:	b7f9                	j	ffffffffc0201264 <printnum+0x38>

ffffffffc0201298 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201298:	7119                	addi	sp,sp,-128
ffffffffc020129a:	f4a6                	sd	s1,104(sp)
ffffffffc020129c:	f0ca                	sd	s2,96(sp)
ffffffffc020129e:	ecce                	sd	s3,88(sp)
ffffffffc02012a0:	e8d2                	sd	s4,80(sp)
ffffffffc02012a2:	e4d6                	sd	s5,72(sp)
ffffffffc02012a4:	e0da                	sd	s6,64(sp)
ffffffffc02012a6:	fc5e                	sd	s7,56(sp)
ffffffffc02012a8:	f06a                	sd	s10,32(sp)
ffffffffc02012aa:	fc86                	sd	ra,120(sp)
ffffffffc02012ac:	f8a2                	sd	s0,112(sp)
ffffffffc02012ae:	f862                	sd	s8,48(sp)
ffffffffc02012b0:	f466                	sd	s9,40(sp)
ffffffffc02012b2:	ec6e                	sd	s11,24(sp)
ffffffffc02012b4:	892a                	mv	s2,a0
ffffffffc02012b6:	84ae                	mv	s1,a1
ffffffffc02012b8:	8d32                	mv	s10,a2
ffffffffc02012ba:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012bc:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc02012c0:	5b7d                	li	s6,-1
ffffffffc02012c2:	00001a97          	auipc	s5,0x1
ffffffffc02012c6:	bcaa8a93          	addi	s5,s5,-1078 # ffffffffc0201e8c <best_fit_pmm_manager+0x224>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02012ca:	00001b97          	auipc	s7,0x1
ffffffffc02012ce:	d9eb8b93          	addi	s7,s7,-610 # ffffffffc0202068 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012d2:	000d4503          	lbu	a0,0(s10)
ffffffffc02012d6:	001d0413          	addi	s0,s10,1
ffffffffc02012da:	01350a63          	beq	a0,s3,ffffffffc02012ee <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc02012de:	c121                	beqz	a0,ffffffffc020131e <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc02012e0:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012e2:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc02012e4:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02012e6:	fff44503          	lbu	a0,-1(s0)
ffffffffc02012ea:	ff351ae3          	bne	a0,s3,ffffffffc02012de <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02012ee:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc02012f2:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc02012f6:	4c81                	li	s9,0
ffffffffc02012f8:	4881                	li	a7,0
        width = precision = -1;
ffffffffc02012fa:	5c7d                	li	s8,-1
ffffffffc02012fc:	5dfd                	li	s11,-1
ffffffffc02012fe:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201302:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201304:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201308:	0ff5f593          	zext.b	a1,a1
ffffffffc020130c:	00140d13          	addi	s10,s0,1
ffffffffc0201310:	04b56263          	bltu	a0,a1,ffffffffc0201354 <vprintfmt+0xbc>
ffffffffc0201314:	058a                	slli	a1,a1,0x2
ffffffffc0201316:	95d6                	add	a1,a1,s5
ffffffffc0201318:	4194                	lw	a3,0(a1)
ffffffffc020131a:	96d6                	add	a3,a3,s5
ffffffffc020131c:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc020131e:	70e6                	ld	ra,120(sp)
ffffffffc0201320:	7446                	ld	s0,112(sp)
ffffffffc0201322:	74a6                	ld	s1,104(sp)
ffffffffc0201324:	7906                	ld	s2,96(sp)
ffffffffc0201326:	69e6                	ld	s3,88(sp)
ffffffffc0201328:	6a46                	ld	s4,80(sp)
ffffffffc020132a:	6aa6                	ld	s5,72(sp)
ffffffffc020132c:	6b06                	ld	s6,64(sp)
ffffffffc020132e:	7be2                	ld	s7,56(sp)
ffffffffc0201330:	7c42                	ld	s8,48(sp)
ffffffffc0201332:	7ca2                	ld	s9,40(sp)
ffffffffc0201334:	7d02                	ld	s10,32(sp)
ffffffffc0201336:	6de2                	ld	s11,24(sp)
ffffffffc0201338:	6109                	addi	sp,sp,128
ffffffffc020133a:	8082                	ret
            padc = '0';
ffffffffc020133c:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc020133e:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201342:	846a                	mv	s0,s10
ffffffffc0201344:	00140d13          	addi	s10,s0,1
ffffffffc0201348:	fdd6059b          	addiw	a1,a2,-35
ffffffffc020134c:	0ff5f593          	zext.b	a1,a1
ffffffffc0201350:	fcb572e3          	bgeu	a0,a1,ffffffffc0201314 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201354:	85a6                	mv	a1,s1
ffffffffc0201356:	02500513          	li	a0,37
ffffffffc020135a:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc020135c:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201360:	8d22                	mv	s10,s0
ffffffffc0201362:	f73788e3          	beq	a5,s3,ffffffffc02012d2 <vprintfmt+0x3a>
ffffffffc0201366:	ffed4783          	lbu	a5,-2(s10)
ffffffffc020136a:	1d7d                	addi	s10,s10,-1
ffffffffc020136c:	ff379de3          	bne	a5,s3,ffffffffc0201366 <vprintfmt+0xce>
ffffffffc0201370:	b78d                	j	ffffffffc02012d2 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201372:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0201376:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020137a:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc020137c:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201380:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201384:	02d86463          	bltu	a6,a3,ffffffffc02013ac <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0201388:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc020138c:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201390:	0186873b          	addw	a4,a3,s8
ffffffffc0201394:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201398:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc020139a:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc020139e:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc02013a0:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc02013a4:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02013a8:	fed870e3          	bgeu	a6,a3,ffffffffc0201388 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc02013ac:	f40ddce3          	bgez	s11,ffffffffc0201304 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc02013b0:	8de2                	mv	s11,s8
ffffffffc02013b2:	5c7d                	li	s8,-1
ffffffffc02013b4:	bf81                	j	ffffffffc0201304 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc02013b6:	fffdc693          	not	a3,s11
ffffffffc02013ba:	96fd                	srai	a3,a3,0x3f
ffffffffc02013bc:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013c0:	00144603          	lbu	a2,1(s0)
ffffffffc02013c4:	2d81                	sext.w	s11,s11
ffffffffc02013c6:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02013c8:	bf35                	j	ffffffffc0201304 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc02013ca:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013ce:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc02013d2:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013d4:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc02013d6:	bfd9                	j	ffffffffc02013ac <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc02013d8:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02013da:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02013de:	01174463          	blt	a4,a7,ffffffffc02013e6 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc02013e2:	1a088e63          	beqz	a7,ffffffffc020159e <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc02013e6:	000a3603          	ld	a2,0(s4)
ffffffffc02013ea:	46c1                	li	a3,16
ffffffffc02013ec:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc02013ee:	2781                	sext.w	a5,a5
ffffffffc02013f0:	876e                	mv	a4,s11
ffffffffc02013f2:	85a6                	mv	a1,s1
ffffffffc02013f4:	854a                	mv	a0,s2
ffffffffc02013f6:	e37ff0ef          	jal	ra,ffffffffc020122c <printnum>
            break;
ffffffffc02013fa:	bde1                	j	ffffffffc02012d2 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc02013fc:	000a2503          	lw	a0,0(s4)
ffffffffc0201400:	85a6                	mv	a1,s1
ffffffffc0201402:	0a21                	addi	s4,s4,8
ffffffffc0201404:	9902                	jalr	s2
            break;
ffffffffc0201406:	b5f1                	j	ffffffffc02012d2 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201408:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020140a:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020140e:	01174463          	blt	a4,a7,ffffffffc0201416 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201412:	18088163          	beqz	a7,ffffffffc0201594 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201416:	000a3603          	ld	a2,0(s4)
ffffffffc020141a:	46a9                	li	a3,10
ffffffffc020141c:	8a2e                	mv	s4,a1
ffffffffc020141e:	bfc1                	j	ffffffffc02013ee <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201420:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201424:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201426:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201428:	bdf1                	j	ffffffffc0201304 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc020142a:	85a6                	mv	a1,s1
ffffffffc020142c:	02500513          	li	a0,37
ffffffffc0201430:	9902                	jalr	s2
            break;
ffffffffc0201432:	b545                	j	ffffffffc02012d2 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201434:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201438:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020143a:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020143c:	b5e1                	j	ffffffffc0201304 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc020143e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201440:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201444:	01174463          	blt	a4,a7,ffffffffc020144c <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201448:	14088163          	beqz	a7,ffffffffc020158a <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc020144c:	000a3603          	ld	a2,0(s4)
ffffffffc0201450:	46a1                	li	a3,8
ffffffffc0201452:	8a2e                	mv	s4,a1
ffffffffc0201454:	bf69                	j	ffffffffc02013ee <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0201456:	03000513          	li	a0,48
ffffffffc020145a:	85a6                	mv	a1,s1
ffffffffc020145c:	e03e                	sd	a5,0(sp)
ffffffffc020145e:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201460:	85a6                	mv	a1,s1
ffffffffc0201462:	07800513          	li	a0,120
ffffffffc0201466:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201468:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc020146a:	6782                	ld	a5,0(sp)
ffffffffc020146c:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc020146e:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201472:	bfb5                	j	ffffffffc02013ee <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201474:	000a3403          	ld	s0,0(s4)
ffffffffc0201478:	008a0713          	addi	a4,s4,8
ffffffffc020147c:	e03a                	sd	a4,0(sp)
ffffffffc020147e:	14040263          	beqz	s0,ffffffffc02015c2 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201482:	0fb05763          	blez	s11,ffffffffc0201570 <vprintfmt+0x2d8>
ffffffffc0201486:	02d00693          	li	a3,45
ffffffffc020148a:	0cd79163          	bne	a5,a3,ffffffffc020154c <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020148e:	00044783          	lbu	a5,0(s0)
ffffffffc0201492:	0007851b          	sext.w	a0,a5
ffffffffc0201496:	cf85                	beqz	a5,ffffffffc02014ce <vprintfmt+0x236>
ffffffffc0201498:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020149c:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02014a0:	000c4563          	bltz	s8,ffffffffc02014aa <vprintfmt+0x212>
ffffffffc02014a4:	3c7d                	addiw	s8,s8,-1
ffffffffc02014a6:	036c0263          	beq	s8,s6,ffffffffc02014ca <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc02014aa:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02014ac:	0e0c8e63          	beqz	s9,ffffffffc02015a8 <vprintfmt+0x310>
ffffffffc02014b0:	3781                	addiw	a5,a5,-32
ffffffffc02014b2:	0ef47b63          	bgeu	s0,a5,ffffffffc02015a8 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc02014b6:	03f00513          	li	a0,63
ffffffffc02014ba:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02014bc:	000a4783          	lbu	a5,0(s4)
ffffffffc02014c0:	3dfd                	addiw	s11,s11,-1
ffffffffc02014c2:	0a05                	addi	s4,s4,1
ffffffffc02014c4:	0007851b          	sext.w	a0,a5
ffffffffc02014c8:	ffe1                	bnez	a5,ffffffffc02014a0 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc02014ca:	01b05963          	blez	s11,ffffffffc02014dc <vprintfmt+0x244>
ffffffffc02014ce:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc02014d0:	85a6                	mv	a1,s1
ffffffffc02014d2:	02000513          	li	a0,32
ffffffffc02014d6:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc02014d8:	fe0d9be3          	bnez	s11,ffffffffc02014ce <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02014dc:	6a02                	ld	s4,0(sp)
ffffffffc02014de:	bbd5                	j	ffffffffc02012d2 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02014e0:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02014e2:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc02014e6:	01174463          	blt	a4,a7,ffffffffc02014ee <vprintfmt+0x256>
    else if (lflag) {
ffffffffc02014ea:	08088d63          	beqz	a7,ffffffffc0201584 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc02014ee:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc02014f2:	0a044d63          	bltz	s0,ffffffffc02015ac <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc02014f6:	8622                	mv	a2,s0
ffffffffc02014f8:	8a66                	mv	s4,s9
ffffffffc02014fa:	46a9                	li	a3,10
ffffffffc02014fc:	bdcd                	j	ffffffffc02013ee <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc02014fe:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201502:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201504:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201506:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc020150a:	8fb5                	xor	a5,a5,a3
ffffffffc020150c:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201510:	02d74163          	blt	a4,a3,ffffffffc0201532 <vprintfmt+0x29a>
ffffffffc0201514:	00369793          	slli	a5,a3,0x3
ffffffffc0201518:	97de                	add	a5,a5,s7
ffffffffc020151a:	639c                	ld	a5,0(a5)
ffffffffc020151c:	cb99                	beqz	a5,ffffffffc0201532 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc020151e:	86be                	mv	a3,a5
ffffffffc0201520:	00001617          	auipc	a2,0x1
ffffffffc0201524:	96860613          	addi	a2,a2,-1688 # ffffffffc0201e88 <best_fit_pmm_manager+0x220>
ffffffffc0201528:	85a6                	mv	a1,s1
ffffffffc020152a:	854a                	mv	a0,s2
ffffffffc020152c:	0ce000ef          	jal	ra,ffffffffc02015fa <printfmt>
ffffffffc0201530:	b34d                	j	ffffffffc02012d2 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201532:	00001617          	auipc	a2,0x1
ffffffffc0201536:	94660613          	addi	a2,a2,-1722 # ffffffffc0201e78 <best_fit_pmm_manager+0x210>
ffffffffc020153a:	85a6                	mv	a1,s1
ffffffffc020153c:	854a                	mv	a0,s2
ffffffffc020153e:	0bc000ef          	jal	ra,ffffffffc02015fa <printfmt>
ffffffffc0201542:	bb41                	j	ffffffffc02012d2 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201544:	00001417          	auipc	s0,0x1
ffffffffc0201548:	92c40413          	addi	s0,s0,-1748 # ffffffffc0201e70 <best_fit_pmm_manager+0x208>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020154c:	85e2                	mv	a1,s8
ffffffffc020154e:	8522                	mv	a0,s0
ffffffffc0201550:	e43e                	sd	a5,8(sp)
ffffffffc0201552:	0fc000ef          	jal	ra,ffffffffc020164e <strnlen>
ffffffffc0201556:	40ad8dbb          	subw	s11,s11,a0
ffffffffc020155a:	01b05b63          	blez	s11,ffffffffc0201570 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc020155e:	67a2                	ld	a5,8(sp)
ffffffffc0201560:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201564:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0201566:	85a6                	mv	a1,s1
ffffffffc0201568:	8552                	mv	a0,s4
ffffffffc020156a:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020156c:	fe0d9ce3          	bnez	s11,ffffffffc0201564 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201570:	00044783          	lbu	a5,0(s0)
ffffffffc0201574:	00140a13          	addi	s4,s0,1
ffffffffc0201578:	0007851b          	sext.w	a0,a5
ffffffffc020157c:	d3a5                	beqz	a5,ffffffffc02014dc <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020157e:	05e00413          	li	s0,94
ffffffffc0201582:	bf39                	j	ffffffffc02014a0 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201584:	000a2403          	lw	s0,0(s4)
ffffffffc0201588:	b7ad                	j	ffffffffc02014f2 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc020158a:	000a6603          	lwu	a2,0(s4)
ffffffffc020158e:	46a1                	li	a3,8
ffffffffc0201590:	8a2e                	mv	s4,a1
ffffffffc0201592:	bdb1                	j	ffffffffc02013ee <vprintfmt+0x156>
ffffffffc0201594:	000a6603          	lwu	a2,0(s4)
ffffffffc0201598:	46a9                	li	a3,10
ffffffffc020159a:	8a2e                	mv	s4,a1
ffffffffc020159c:	bd89                	j	ffffffffc02013ee <vprintfmt+0x156>
ffffffffc020159e:	000a6603          	lwu	a2,0(s4)
ffffffffc02015a2:	46c1                	li	a3,16
ffffffffc02015a4:	8a2e                	mv	s4,a1
ffffffffc02015a6:	b5a1                	j	ffffffffc02013ee <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc02015a8:	9902                	jalr	s2
ffffffffc02015aa:	bf09                	j	ffffffffc02014bc <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc02015ac:	85a6                	mv	a1,s1
ffffffffc02015ae:	02d00513          	li	a0,45
ffffffffc02015b2:	e03e                	sd	a5,0(sp)
ffffffffc02015b4:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc02015b6:	6782                	ld	a5,0(sp)
ffffffffc02015b8:	8a66                	mv	s4,s9
ffffffffc02015ba:	40800633          	neg	a2,s0
ffffffffc02015be:	46a9                	li	a3,10
ffffffffc02015c0:	b53d                	j	ffffffffc02013ee <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc02015c2:	03b05163          	blez	s11,ffffffffc02015e4 <vprintfmt+0x34c>
ffffffffc02015c6:	02d00693          	li	a3,45
ffffffffc02015ca:	f6d79de3          	bne	a5,a3,ffffffffc0201544 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc02015ce:	00001417          	auipc	s0,0x1
ffffffffc02015d2:	8a240413          	addi	s0,s0,-1886 # ffffffffc0201e70 <best_fit_pmm_manager+0x208>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02015d6:	02800793          	li	a5,40
ffffffffc02015da:	02800513          	li	a0,40
ffffffffc02015de:	00140a13          	addi	s4,s0,1
ffffffffc02015e2:	bd6d                	j	ffffffffc020149c <vprintfmt+0x204>
ffffffffc02015e4:	00001a17          	auipc	s4,0x1
ffffffffc02015e8:	88da0a13          	addi	s4,s4,-1907 # ffffffffc0201e71 <best_fit_pmm_manager+0x209>
ffffffffc02015ec:	02800513          	li	a0,40
ffffffffc02015f0:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02015f4:	05e00413          	li	s0,94
ffffffffc02015f8:	b565                	j	ffffffffc02014a0 <vprintfmt+0x208>

ffffffffc02015fa <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc02015fa:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc02015fc:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201600:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201602:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201604:	ec06                	sd	ra,24(sp)
ffffffffc0201606:	f83a                	sd	a4,48(sp)
ffffffffc0201608:	fc3e                	sd	a5,56(sp)
ffffffffc020160a:	e0c2                	sd	a6,64(sp)
ffffffffc020160c:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc020160e:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201610:	c89ff0ef          	jal	ra,ffffffffc0201298 <vprintfmt>
}
ffffffffc0201614:	60e2                	ld	ra,24(sp)
ffffffffc0201616:	6161                	addi	sp,sp,80
ffffffffc0201618:	8082                	ret

ffffffffc020161a <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc020161a:	4781                	li	a5,0
ffffffffc020161c:	00005717          	auipc	a4,0x5
ffffffffc0201620:	9f473703          	ld	a4,-1548(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201624:	88ba                	mv	a7,a4
ffffffffc0201626:	852a                	mv	a0,a0
ffffffffc0201628:	85be                	mv	a1,a5
ffffffffc020162a:	863e                	mv	a2,a5
ffffffffc020162c:	00000073          	ecall
ffffffffc0201630:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201632:	8082                	ret

ffffffffc0201634 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201634:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201638:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc020163a:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc020163c:	cb81                	beqz	a5,ffffffffc020164c <strlen+0x18>
        cnt ++;
ffffffffc020163e:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201640:	00a707b3          	add	a5,a4,a0
ffffffffc0201644:	0007c783          	lbu	a5,0(a5)
ffffffffc0201648:	fbfd                	bnez	a5,ffffffffc020163e <strlen+0xa>
ffffffffc020164a:	8082                	ret
    }
    return cnt;
}
ffffffffc020164c:	8082                	ret

ffffffffc020164e <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc020164e:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201650:	e589                	bnez	a1,ffffffffc020165a <strnlen+0xc>
ffffffffc0201652:	a811                	j	ffffffffc0201666 <strnlen+0x18>
        cnt ++;
ffffffffc0201654:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201656:	00f58863          	beq	a1,a5,ffffffffc0201666 <strnlen+0x18>
ffffffffc020165a:	00f50733          	add	a4,a0,a5
ffffffffc020165e:	00074703          	lbu	a4,0(a4)
ffffffffc0201662:	fb6d                	bnez	a4,ffffffffc0201654 <strnlen+0x6>
ffffffffc0201664:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201666:	852e                	mv	a0,a1
ffffffffc0201668:	8082                	ret

ffffffffc020166a <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020166a:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020166e:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201672:	cb89                	beqz	a5,ffffffffc0201684 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201674:	0505                	addi	a0,a0,1
ffffffffc0201676:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201678:	fee789e3          	beq	a5,a4,ffffffffc020166a <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020167c:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201680:	9d19                	subw	a0,a0,a4
ffffffffc0201682:	8082                	ret
ffffffffc0201684:	4501                	li	a0,0
ffffffffc0201686:	bfed                	j	ffffffffc0201680 <strcmp+0x16>

ffffffffc0201688 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201688:	c20d                	beqz	a2,ffffffffc02016aa <strncmp+0x22>
ffffffffc020168a:	962e                	add	a2,a2,a1
ffffffffc020168c:	a031                	j	ffffffffc0201698 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc020168e:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201690:	00e79a63          	bne	a5,a4,ffffffffc02016a4 <strncmp+0x1c>
ffffffffc0201694:	00b60b63          	beq	a2,a1,ffffffffc02016aa <strncmp+0x22>
ffffffffc0201698:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc020169c:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020169e:	fff5c703          	lbu	a4,-1(a1)
ffffffffc02016a2:	f7f5                	bnez	a5,ffffffffc020168e <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02016a4:	40e7853b          	subw	a0,a5,a4
}
ffffffffc02016a8:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02016aa:	4501                	li	a0,0
ffffffffc02016ac:	8082                	ret

ffffffffc02016ae <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc02016ae:	ca01                	beqz	a2,ffffffffc02016be <memset+0x10>
ffffffffc02016b0:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc02016b2:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc02016b4:	0785                	addi	a5,a5,1
ffffffffc02016b6:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc02016ba:	fec79de3          	bne	a5,a2,ffffffffc02016b4 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc02016be:	8082                	ret
