
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid  当前硬件线程的编号，即 hart ID
    # a1: dtb physical address  设备树 DTB 的物理地址
    # save hartid and dtb address
    la t0, boot_hartid  # 加载boot_hartid到t0
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)   #写入8位
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
ffffffffc0200050:	67450513          	addi	a0,a0,1652 # ffffffffc02016c0 <etext+0x2>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	67e50513          	addi	a0,a0,1662 # ffffffffc02016e0 <etext+0x22>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	65058593          	addi	a1,a1,1616 # ffffffffc02016be <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	68a50513          	addi	a0,a0,1674 # ffffffffc0201700 <etext+0x42>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	69650513          	addi	a0,a0,1686 # ffffffffc0201720 <etext+0x62>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	fe258593          	addi	a1,a1,-30 # ffffffffc0206078 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	6a250513          	addi	a0,a0,1698 # ffffffffc0201740 <etext+0x82>
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
ffffffffc02000d0:	69450513          	addi	a0,a0,1684 # ffffffffc0201760 <etext+0xa2>
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
ffffffffc02000f0:	1b4010ef          	jal	ra,ffffffffc02012a4 <memset>
    dtb_init();
ffffffffc02000f4:	122000ef          	jal	ra,ffffffffc0200216 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	4ce000ef          	jal	ra,ffffffffc02005c6 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	69450513          	addi	a0,a0,1684 # ffffffffc0201790 <etext+0xd2>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	4e8000ef          	jal	ra,ffffffffc02005f4 <pmm_init>

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
ffffffffc020011a:	4ae000ef          	jal	ra,ffffffffc02005c8 <cons_putc>
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
ffffffffc0200140:	1e2010ef          	jal	ra,ffffffffc0201322 <vprintfmt>
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
ffffffffc0200176:	1ac010ef          	jal	ra,ffffffffc0201322 <vprintfmt>
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
ffffffffc0200198:	430000ef          	jal	ra,ffffffffc02005c8 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	41a000ef          	jal	ra,ffffffffc02005c8 <cons_putc>
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
ffffffffc02001f6:	5be50513          	addi	a0,a0,1470 # ffffffffc02017b0 <etext+0xf2>
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
ffffffffc020020c:	58050513          	addi	a0,a0,1408 # ffffffffc0201788 <etext+0xca>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200216:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200218:	00001517          	auipc	a0,0x1
ffffffffc020021c:	5b850513          	addi	a0,a0,1464 # ffffffffc02017d0 <etext+0x112>
void dtb_init(void) {
ffffffffc0200220:	fc86                	sd	ra,120(sp)
ffffffffc0200222:	f8a2                	sd	s0,112(sp)
ffffffffc0200224:	e8d2                	sd	s4,80(sp)
ffffffffc0200226:	f4a6                	sd	s1,104(sp)
ffffffffc0200228:	f0ca                	sd	s2,96(sp)
ffffffffc020022a:	ecce                	sd	s3,88(sp)
ffffffffc020022c:	e4d6                	sd	s5,72(sp)
ffffffffc020022e:	e0da                	sd	s6,64(sp)
ffffffffc0200230:	fc5e                	sd	s7,56(sp)
ffffffffc0200232:	f862                	sd	s8,48(sp)
ffffffffc0200234:	f466                	sd	s9,40(sp)
ffffffffc0200236:	f06a                	sd	s10,32(sp)
ffffffffc0200238:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc020023a:	f13ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc020023e:	00006597          	auipc	a1,0x6
ffffffffc0200242:	dc25b583          	ld	a1,-574(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc0200246:	00001517          	auipc	a0,0x1
ffffffffc020024a:	59a50513          	addi	a0,a0,1434 # ffffffffc02017e0 <etext+0x122>
ffffffffc020024e:	effff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200252:	00006417          	auipc	s0,0x6
ffffffffc0200256:	db640413          	addi	s0,s0,-586 # ffffffffc0206008 <boot_dtb>
ffffffffc020025a:	600c                	ld	a1,0(s0)
ffffffffc020025c:	00001517          	auipc	a0,0x1
ffffffffc0200260:	59450513          	addi	a0,a0,1428 # ffffffffc02017f0 <etext+0x132>
ffffffffc0200264:	ee9ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200268:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc020026c:	00001517          	auipc	a0,0x1
ffffffffc0200270:	59c50513          	addi	a0,a0,1436 # ffffffffc0201808 <etext+0x14a>
    if (boot_dtb == 0) {
ffffffffc0200274:	120a0463          	beqz	s4,ffffffffc020039c <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200278:	57f5                	li	a5,-3
ffffffffc020027a:	07fa                	slli	a5,a5,0x1e
ffffffffc020027c:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc0200280:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200282:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200286:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200288:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020028c:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200294:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200298:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029c:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029e:	8ec9                	or	a3,a3,a0
ffffffffc02002a0:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002a4:	1b7d                	addi	s6,s6,-1
ffffffffc02002a6:	0167f7b3          	and	a5,a5,s6
ffffffffc02002aa:	8dd5                	or	a1,a1,a3
ffffffffc02002ac:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002ae:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002b2:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002b4:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9e75>
ffffffffc02002b8:	10f59163          	bne	a1,a5,ffffffffc02003ba <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002bc:	471c                	lw	a5,8(a4)
ffffffffc02002be:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002c0:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002c2:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002c6:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002ca:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ce:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002d2:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d6:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002da:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002de:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e2:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e6:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ea:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002ec:	01146433          	or	s0,s0,a7
ffffffffc02002f0:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002f4:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f8:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002fa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002fe:	8c49                	or	s0,s0,a0
ffffffffc0200300:	0166f6b3          	and	a3,a3,s6
ffffffffc0200304:	00ca6a33          	or	s4,s4,a2
ffffffffc0200308:	0167f7b3          	and	a5,a5,s6
ffffffffc020030c:	8c55                	or	s0,s0,a3
ffffffffc020030e:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200312:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200314:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200316:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200318:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200320:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc0200324:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200326:	00001917          	auipc	s2,0x1
ffffffffc020032a:	53290913          	addi	s2,s2,1330 # ffffffffc0201858 <etext+0x19a>
ffffffffc020032e:	49bd                	li	s3,15
        switch (token) {
ffffffffc0200330:	4d91                	li	s11,4
ffffffffc0200332:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200334:	00001497          	auipc	s1,0x1
ffffffffc0200338:	51c48493          	addi	s1,s1,1308 # ffffffffc0201850 <etext+0x192>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc020033c:	000a2703          	lw	a4,0(s4)
ffffffffc0200340:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200344:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200348:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020034c:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200350:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200354:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200358:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0087171b          	slliw	a4,a4,0x8
ffffffffc0200362:	8fd5                	or	a5,a5,a3
ffffffffc0200364:	00eb7733          	and	a4,s6,a4
ffffffffc0200368:	8fd9                	or	a5,a5,a4
ffffffffc020036a:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc020036c:	09778c63          	beq	a5,s7,ffffffffc0200404 <dtb_init+0x1ee>
ffffffffc0200370:	00fbea63          	bltu	s7,a5,ffffffffc0200384 <dtb_init+0x16e>
ffffffffc0200374:	07a78663          	beq	a5,s10,ffffffffc02003e0 <dtb_init+0x1ca>
ffffffffc0200378:	4709                	li	a4,2
ffffffffc020037a:	00e79763          	bne	a5,a4,ffffffffc0200388 <dtb_init+0x172>
ffffffffc020037e:	4c81                	li	s9,0
ffffffffc0200380:	8a56                	mv	s4,s5
ffffffffc0200382:	bf6d                	j	ffffffffc020033c <dtb_init+0x126>
ffffffffc0200384:	ffb78ee3          	beq	a5,s11,ffffffffc0200380 <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200388:	00001517          	auipc	a0,0x1
ffffffffc020038c:	54850513          	addi	a0,a0,1352 # ffffffffc02018d0 <etext+0x212>
ffffffffc0200390:	dbdff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc0200394:	00001517          	auipc	a0,0x1
ffffffffc0200398:	57450513          	addi	a0,a0,1396 # ffffffffc0201908 <etext+0x24a>
}
ffffffffc020039c:	7446                	ld	s0,112(sp)
ffffffffc020039e:	70e6                	ld	ra,120(sp)
ffffffffc02003a0:	74a6                	ld	s1,104(sp)
ffffffffc02003a2:	7906                	ld	s2,96(sp)
ffffffffc02003a4:	69e6                	ld	s3,88(sp)
ffffffffc02003a6:	6a46                	ld	s4,80(sp)
ffffffffc02003a8:	6aa6                	ld	s5,72(sp)
ffffffffc02003aa:	6b06                	ld	s6,64(sp)
ffffffffc02003ac:	7be2                	ld	s7,56(sp)
ffffffffc02003ae:	7c42                	ld	s8,48(sp)
ffffffffc02003b0:	7ca2                	ld	s9,40(sp)
ffffffffc02003b2:	7d02                	ld	s10,32(sp)
ffffffffc02003b4:	6de2                	ld	s11,24(sp)
ffffffffc02003b6:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003b8:	bb51                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003ba:	7446                	ld	s0,112(sp)
ffffffffc02003bc:	70e6                	ld	ra,120(sp)
ffffffffc02003be:	74a6                	ld	s1,104(sp)
ffffffffc02003c0:	7906                	ld	s2,96(sp)
ffffffffc02003c2:	69e6                	ld	s3,88(sp)
ffffffffc02003c4:	6a46                	ld	s4,80(sp)
ffffffffc02003c6:	6aa6                	ld	s5,72(sp)
ffffffffc02003c8:	6b06                	ld	s6,64(sp)
ffffffffc02003ca:	7be2                	ld	s7,56(sp)
ffffffffc02003cc:	7c42                	ld	s8,48(sp)
ffffffffc02003ce:	7ca2                	ld	s9,40(sp)
ffffffffc02003d0:	7d02                	ld	s10,32(sp)
ffffffffc02003d2:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003d4:	00001517          	auipc	a0,0x1
ffffffffc02003d8:	45450513          	addi	a0,a0,1108 # ffffffffc0201828 <etext+0x16a>
}
ffffffffc02003dc:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	b3bd                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003e0:	8556                	mv	a0,s5
ffffffffc02003e2:	649000ef          	jal	ra,ffffffffc020122a <strlen>
ffffffffc02003e6:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003e8:	4619                	li	a2,6
ffffffffc02003ea:	85a6                	mv	a1,s1
ffffffffc02003ec:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003ee:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f0:	68f000ef          	jal	ra,ffffffffc020127e <strncmp>
ffffffffc02003f4:	e111                	bnez	a0,ffffffffc02003f8 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc02003f6:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc02003f8:	0a91                	addi	s5,s5,4
ffffffffc02003fa:	9ad2                	add	s5,s5,s4
ffffffffc02003fc:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200400:	8a56                	mv	s4,s5
ffffffffc0200402:	bf2d                	j	ffffffffc020033c <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200404:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200408:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020040c:	0087d71b          	srliw	a4,a5,0x8
ffffffffc0200410:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200414:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200418:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041c:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200420:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200424:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200428:	0087979b          	slliw	a5,a5,0x8
ffffffffc020042c:	00eaeab3          	or	s5,s5,a4
ffffffffc0200430:	00fb77b3          	and	a5,s6,a5
ffffffffc0200434:	00faeab3          	or	s5,s5,a5
ffffffffc0200438:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020043a:	000c9c63          	bnez	s9,ffffffffc0200452 <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc020043e:	1a82                	slli	s5,s5,0x20
ffffffffc0200440:	00368793          	addi	a5,a3,3
ffffffffc0200444:	020ada93          	srli	s5,s5,0x20
ffffffffc0200448:	9abe                	add	s5,s5,a5
ffffffffc020044a:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020044e:	8a56                	mv	s4,s5
ffffffffc0200450:	b5f5                	j	ffffffffc020033c <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200452:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200456:	85ca                	mv	a1,s2
ffffffffc0200458:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020045a:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020045e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200462:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200466:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020046a:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020046e:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200470:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200478:	8d59                	or	a0,a0,a4
ffffffffc020047a:	00fb77b3          	and	a5,s6,a5
ffffffffc020047e:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc0200480:	1502                	slli	a0,a0,0x20
ffffffffc0200482:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200484:	9522                	add	a0,a0,s0
ffffffffc0200486:	5db000ef          	jal	ra,ffffffffc0201260 <strcmp>
ffffffffc020048a:	66a2                	ld	a3,8(sp)
ffffffffc020048c:	f94d                	bnez	a0,ffffffffc020043e <dtb_init+0x228>
ffffffffc020048e:	fb59f8e3          	bgeu	s3,s5,ffffffffc020043e <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc0200492:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc0200496:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc020049a:	00001517          	auipc	a0,0x1
ffffffffc020049e:	3c650513          	addi	a0,a0,966 # ffffffffc0201860 <etext+0x1a2>
           fdt32_to_cpu(x >> 32);
ffffffffc02004a2:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004a6:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004aa:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ae:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004b2:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b6:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ba:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004be:	0187d693          	srli	a3,a5,0x18
ffffffffc02004c2:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004c6:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004ca:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ce:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004d2:	010f6f33          	or	t5,t5,a6
ffffffffc02004d6:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004da:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004de:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004e2:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e6:	0186f6b3          	and	a3,a3,s8
ffffffffc02004ea:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004ee:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004f2:	0107581b          	srliw	a6,a4,0x10
ffffffffc02004f6:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004fa:	8361                	srli	a4,a4,0x18
ffffffffc02004fc:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200500:	0105d59b          	srliw	a1,a1,0x10
ffffffffc0200504:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200508:	00cb7633          	and	a2,s6,a2
ffffffffc020050c:	0088181b          	slliw	a6,a6,0x8
ffffffffc0200510:	0085959b          	slliw	a1,a1,0x8
ffffffffc0200514:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200518:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020051c:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200520:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200524:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200528:	011b78b3          	and	a7,s6,a7
ffffffffc020052c:	005eeeb3          	or	t4,t4,t0
ffffffffc0200530:	00c6e733          	or	a4,a3,a2
ffffffffc0200534:	006c6c33          	or	s8,s8,t1
ffffffffc0200538:	010b76b3          	and	a3,s6,a6
ffffffffc020053c:	00bb7b33          	and	s6,s6,a1
ffffffffc0200540:	01d7e7b3          	or	a5,a5,t4
ffffffffc0200544:	016c6b33          	or	s6,s8,s6
ffffffffc0200548:	01146433          	or	s0,s0,a7
ffffffffc020054c:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc020054e:	1702                	slli	a4,a4,0x20
ffffffffc0200550:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200552:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200554:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200556:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	0167eb33          	or	s6,a5,s6
ffffffffc0200560:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200562:	bebff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200566:	85a2                	mv	a1,s0
ffffffffc0200568:	00001517          	auipc	a0,0x1
ffffffffc020056c:	31850513          	addi	a0,a0,792 # ffffffffc0201880 <etext+0x1c2>
ffffffffc0200570:	bddff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200574:	014b5613          	srli	a2,s6,0x14
ffffffffc0200578:	85da                	mv	a1,s6
ffffffffc020057a:	00001517          	auipc	a0,0x1
ffffffffc020057e:	31e50513          	addi	a0,a0,798 # ffffffffc0201898 <etext+0x1da>
ffffffffc0200582:	bcbff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200586:	008b05b3          	add	a1,s6,s0
ffffffffc020058a:	15fd                	addi	a1,a1,-1
ffffffffc020058c:	00001517          	auipc	a0,0x1
ffffffffc0200590:	32c50513          	addi	a0,a0,812 # ffffffffc02018b8 <etext+0x1fa>
ffffffffc0200594:	bb9ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc0200598:	00001517          	auipc	a0,0x1
ffffffffc020059c:	37050513          	addi	a0,a0,880 # ffffffffc0201908 <etext+0x24a>
        memory_base = mem_base;
ffffffffc02005a0:	00006797          	auipc	a5,0x6
ffffffffc02005a4:	a887bc23          	sd	s0,-1384(a5) # ffffffffc0206038 <memory_base>
        memory_size = mem_size;
ffffffffc02005a8:	00006797          	auipc	a5,0x6
ffffffffc02005ac:	a967bc23          	sd	s6,-1384(a5) # ffffffffc0206040 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005b0:	b3f5                	j	ffffffffc020039c <dtb_init+0x186>

ffffffffc02005b2 <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005b2:	00006517          	auipc	a0,0x6
ffffffffc02005b6:	a8653503          	ld	a0,-1402(a0) # ffffffffc0206038 <memory_base>
ffffffffc02005ba:	8082                	ret

ffffffffc02005bc <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005bc:	00006517          	auipc	a0,0x6
ffffffffc02005c0:	a8453503          	ld	a0,-1404(a0) # ffffffffc0206040 <memory_size>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc02005c6:	8082                	ret

ffffffffc02005c8 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc02005c8:	0ff57513          	zext.b	a0,a0
ffffffffc02005cc:	0d80106f          	j	ffffffffc02016a4 <sbi_console_putchar>

ffffffffc02005d0 <alloc_pages>:

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n)
{
    return pmm_manager->alloc_pages(n);
ffffffffc02005d0:	00006797          	auipc	a5,0x6
ffffffffc02005d4:	a887b783          	ld	a5,-1400(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc02005d8:	6f9c                	ld	a5,24(a5)
ffffffffc02005da:	8782                	jr	a5

ffffffffc02005dc <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n)
{
    pmm_manager->free_pages(base, n);
ffffffffc02005dc:	00006797          	auipc	a5,0x6
ffffffffc02005e0:	a7c7b783          	ld	a5,-1412(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc02005e4:	739c                	ld	a5,32(a5)
ffffffffc02005e6:	8782                	jr	a5

ffffffffc02005e8 <nr_free_pages>:

// nr_free_pages - call pmm->nr_free_pages to get the size (nr*PAGESIZE)
// of current free memory
size_t nr_free_pages(void)
{
    return pmm_manager->nr_free_pages();
ffffffffc02005e8:	00006797          	auipc	a5,0x6
ffffffffc02005ec:	a707b783          	ld	a5,-1424(a5) # ffffffffc0206058 <pmm_manager>
ffffffffc02005f0:	779c                	ld	a5,40(a5)
ffffffffc02005f2:	8782                	jr	a5

ffffffffc02005f4 <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc02005f4:	00002797          	auipc	a5,0x2
ffffffffc02005f8:	82c78793          	addi	a5,a5,-2004 # ffffffffc0201e20 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02005fc:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(free_begin), (managed_end - free_begin) / PGSIZE);
    }
}
/* pmm_init - initialize the physical memory management */
void pmm_init(void)
{
ffffffffc02005fe:	7179                	addi	sp,sp,-48
ffffffffc0200600:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200602:	00001517          	auipc	a0,0x1
ffffffffc0200606:	31e50513          	addi	a0,a0,798 # ffffffffc0201920 <etext+0x262>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc020060a:	00006417          	auipc	s0,0x6
ffffffffc020060e:	a4e40413          	addi	s0,s0,-1458 # ffffffffc0206058 <pmm_manager>
{
ffffffffc0200612:	f406                	sd	ra,40(sp)
ffffffffc0200614:	e84a                	sd	s2,16(sp)
ffffffffc0200616:	ec26                	sd	s1,24(sp)
ffffffffc0200618:	e44e                	sd	s3,8(sp)
ffffffffc020061a:	e052                	sd	s4,0(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc020061c:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc020061e:	b2fff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc0200622:	601c                	ld	a5,0(s0)
ffffffffc0200624:	679c                	ld	a5,8(a5)
ffffffffc0200626:	9782                	jalr	a5
    uint64_t mem_base = get_memory_base();
ffffffffc0200628:	f8bff0ef          	jal	ra,ffffffffc02005b2 <get_memory_base>
ffffffffc020062c:	892a                	mv	s2,a0
    uint64_t mem_size = get_memory_size();
ffffffffc020062e:	f8fff0ef          	jal	ra,ffffffffc02005bc <get_memory_size>
    if (mem_base == 0 || mem_size == 0 ||
ffffffffc0200632:	16090d63          	beqz	s2,ffffffffc02007ac <pmm_init+0x1b8>
ffffffffc0200636:	8a2a                	mv	s4,a0
ffffffffc0200638:	16050a63          	beqz	a0,ffffffffc02007ac <pmm_init+0x1b8>
        mem_size > (uint64_t)-1 - mem_base)
ffffffffc020063c:	fff94793          	not	a5,s2
    if (mem_base == 0 || mem_size == 0 ||
ffffffffc0200640:	16a7e663          	bltu	a5,a0,ffffffffc02007ac <pmm_init+0x1b8>
    if (mem_base < DRAM_BASE || mem_base > KERNEL_BEGIN_PADDR ||
ffffffffc0200644:	800007b7          	lui	a5,0x80000
ffffffffc0200648:	97ca                	add	a5,a5,s2
ffffffffc020064a:	00200737          	lui	a4,0x200
    uint64_t mem_end = mem_base + mem_size;
ffffffffc020064e:	00a909b3          	add	s3,s2,a0
    if (mem_base < DRAM_BASE || mem_base > KERNEL_BEGIN_PADDR ||
ffffffffc0200652:	14f76163          	bltu	a4,a5,ffffffffc0200794 <pmm_init+0x1a0>
ffffffffc0200656:	40100793          	li	a5,1025
ffffffffc020065a:	07d6                	slli	a5,a5,0x15
ffffffffc020065c:	1337fc63          	bgeu	a5,s3,ffffffffc0200794 <pmm_init+0x1a0>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200660:	57f5                	li	a5,-3
ffffffffc0200662:	07fa                	slli	a5,a5,0x1e
ffffffffc0200664:	00006497          	auipc	s1,0x6
ffffffffc0200668:	a0c48493          	addi	s1,s1,-1524 # ffffffffc0206070 <va_pa_offset>
    cprintf("physical memory map:\n");
ffffffffc020066c:	00001517          	auipc	a0,0x1
ffffffffc0200670:	33c50513          	addi	a0,a0,828 # ffffffffc02019a8 <etext+0x2ea>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200674:	e09c                	sd	a5,0(s1)
    cprintf("physical memory map:\n");
ffffffffc0200676:	ad7ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n",
ffffffffc020067a:	fff98693          	addi	a3,s3,-1
ffffffffc020067e:	864a                	mv	a2,s2
ffffffffc0200680:	85d2                	mv	a1,s4
ffffffffc0200682:	00001517          	auipc	a0,0x1
ffffffffc0200686:	33e50513          	addi	a0,a0,830 # ffffffffc02019c0 <etext+0x302>
ffffffffc020068a:	ac3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uintptr_t managed_end = mem_end < PHYSICAL_MEMORY_END
ffffffffc020068e:	47c5                	li	a5,17
ffffffffc0200690:	07ee                	slli	a5,a5,0x1b
ffffffffc0200692:	0d37ed63          	bltu	a5,s3,ffffffffc020076c <pmm_init+0x178>
    managed_end = ROUNDDOWN(managed_end, PGSIZE);
ffffffffc0200696:	77fd                	lui	a5,0xfffff
ffffffffc0200698:	00f9f5b3          	and	a1,s3,a5
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020069c:	00007697          	auipc	a3,0x7
ffffffffc02006a0:	9db68693          	addi	a3,a3,-1573 # ffffffffc0207077 <end+0xfff>
ffffffffc02006a4:	8efd                	and	a3,a3,a5
    npage = PPN(managed_end);
ffffffffc02006a6:	00c5d893          	srli	a7,a1,0xc
ffffffffc02006aa:	00006797          	auipc	a5,0x6
ffffffffc02006ae:	9917bf23          	sd	a7,-1634(a5) # ffffffffc0206048 <npage>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02006b2:	00006797          	auipc	a5,0x6
ffffffffc02006b6:	98d7bf23          	sd	a3,-1634(a5) # ffffffffc0206050 <pages>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02006ba:	c02007b7          	lui	a5,0xc0200
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc02006be:	8536                	mv	a0,a3
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02006c0:	12f6eb63          	bltu	a3,a5,ffffffffc02007f6 <pmm_init+0x202>
ffffffffc02006c4:	0004b803          	ld	a6,0(s1)
    size_t descriptor_bytes = (npage - nbase) * sizeof(struct Page);
ffffffffc02006c8:	00289713          	slli	a4,a7,0x2
ffffffffc02006cc:	9746                	add	a4,a4,a7
ffffffffc02006ce:	070e                	slli	a4,a4,0x3
ffffffffc02006d0:	fec007b7          	lui	a5,0xfec00
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02006d4:	41068633          	sub	a2,a3,a6
    size_t descriptor_bytes = (npage - nbase) * sizeof(struct Page);
ffffffffc02006d8:	00f70333          	add	t1,a4,a5
    if (pages_pa >= managed_end ||
ffffffffc02006dc:	0eb67463          	bgeu	a2,a1,ffffffffc02007c4 <pmm_init+0x1d0>
        descriptor_bytes > managed_end - pages_pa)
ffffffffc02006e0:	40d80833          	sub	a6,a6,a3
ffffffffc02006e4:	982e                	add	a6,a6,a1
    if (pages_pa >= managed_end ||
ffffffffc02006e6:	0c686f63          	bltu	a6,t1,ffffffffc02007c4 <pmm_init+0x1d0>
    for (size_t i = 0; i < npage - nbase; i++)
ffffffffc02006ea:	97b6                	add	a5,a5,a3
ffffffffc02006ec:	973e                	add	a4,a4,a5
        SetPageReserved(&pages[i]);
ffffffffc02006ee:	4805                	li	a6,1
        pages[i].property = 0;
ffffffffc02006f0:	01868793          	addi	a5,a3,24
ffffffffc02006f4:	0006a823          	sw	zero,16(a3)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc02006f8:	0006a023          	sw	zero,0(a3)
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02006fc:	f29c                	sd	a5,32(a3)
ffffffffc02006fe:	ee9c                	sd	a5,24(a3)
        SetPageReserved(&pages[i]);
ffffffffc0200700:	0106b423          	sd	a6,8(a3)
    for (size_t i = 0; i < npage - nbase; i++)
ffffffffc0200704:	02868693          	addi	a3,a3,40
ffffffffc0200708:	fee694e3          	bne	a3,a4,ffffffffc02006f0 <pmm_init+0xfc>
    uintptr_t free_begin = ROUNDUP(pages_pa + descriptor_bytes, PGSIZE);
ffffffffc020070c:	6785                	lui	a5,0x1
ffffffffc020070e:	17fd                	addi	a5,a5,-1
ffffffffc0200710:	963e                	add	a2,a2,a5
ffffffffc0200712:	961a                	add	a2,a2,t1
ffffffffc0200714:	77fd                	lui	a5,0xfffff
ffffffffc0200716:	8e7d                	and	a2,a2,a5
    if (free_begin < managed_end)
ffffffffc0200718:	04b66c63          	bltu	a2,a1,ffffffffc0200770 <pmm_init+0x17c>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void)
{
    pmm_manager->check();
ffffffffc020071c:	601c                	ld	a5,0(s0)
ffffffffc020071e:	7b9c                	ld	a5,48(a5)
ffffffffc0200720:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0200722:	00001517          	auipc	a0,0x1
ffffffffc0200726:	35650513          	addi	a0,a0,854 # ffffffffc0201a78 <etext+0x3ba>
ffffffffc020072a:	a23ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t *)boot_page_table_sv39;
ffffffffc020072e:	00005597          	auipc	a1,0x5
ffffffffc0200732:	8d258593          	addi	a1,a1,-1838 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc0200736:	00006797          	auipc	a5,0x6
ffffffffc020073a:	92b7b923          	sd	a1,-1742(a5) # ffffffffc0206068 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc020073e:	c02007b7          	lui	a5,0xc0200
ffffffffc0200742:	08f5ed63          	bltu	a1,a5,ffffffffc02007dc <pmm_init+0x1e8>
ffffffffc0200746:	6090                	ld	a2,0(s1)
}
ffffffffc0200748:	7402                	ld	s0,32(sp)
ffffffffc020074a:	70a2                	ld	ra,40(sp)
ffffffffc020074c:	64e2                	ld	s1,24(sp)
ffffffffc020074e:	6942                	ld	s2,16(sp)
ffffffffc0200750:	69a2                	ld	s3,8(sp)
ffffffffc0200752:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0200754:	40c58633          	sub	a2,a1,a2
ffffffffc0200758:	00006797          	auipc	a5,0x6
ffffffffc020075c:	90c7b423          	sd	a2,-1784(a5) # ffffffffc0206060 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200760:	00001517          	auipc	a0,0x1
ffffffffc0200764:	33850513          	addi	a0,a0,824 # ffffffffc0201a98 <etext+0x3da>
}
ffffffffc0200768:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020076a:	b2cd                	j	ffffffffc020014c <cprintf>
    uintptr_t managed_end = mem_end < PHYSICAL_MEMORY_END
ffffffffc020076c:	89be                	mv	s3,a5
ffffffffc020076e:	b725                	j	ffffffffc0200696 <pmm_init+0xa2>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0200770:	00c65793          	srli	a5,a2,0xc
ffffffffc0200774:	0917fd63          	bgeu	a5,a7,ffffffffc020080e <pmm_init+0x21a>
    pmm_manager->init_memmap(base, n);
ffffffffc0200778:	6014                	ld	a3,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020077a:	fff80737          	lui	a4,0xfff80
ffffffffc020077e:	973e                	add	a4,a4,a5
ffffffffc0200780:	00271793          	slli	a5,a4,0x2
ffffffffc0200784:	97ba                	add	a5,a5,a4
ffffffffc0200786:	6a98                	ld	a4,16(a3)
        init_memmap(pa2page(free_begin), (managed_end - free_begin) / PGSIZE);
ffffffffc0200788:	8d91                	sub	a1,a1,a2
ffffffffc020078a:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc020078c:	81b1                	srli	a1,a1,0xc
ffffffffc020078e:	953e                	add	a0,a0,a5
ffffffffc0200790:	9702                	jalr	a4
}
ffffffffc0200792:	b769                	j	ffffffffc020071c <pmm_init+0x128>
        panic("DTB memory does not cover the kernel memory layout");
ffffffffc0200794:	00001617          	auipc	a2,0x1
ffffffffc0200798:	1dc60613          	addi	a2,a2,476 # ffffffffc0201970 <etext+0x2b2>
ffffffffc020079c:	06300593          	li	a1,99
ffffffffc02007a0:	00001517          	auipc	a0,0x1
ffffffffc02007a4:	1c050513          	addi	a0,a0,448 # ffffffffc0201960 <etext+0x2a2>
ffffffffc02007a8:	a1bff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("invalid physical memory range from DTB");
ffffffffc02007ac:	00001617          	auipc	a2,0x1
ffffffffc02007b0:	18c60613          	addi	a2,a2,396 # ffffffffc0201938 <etext+0x27a>
ffffffffc02007b4:	05d00593          	li	a1,93
ffffffffc02007b8:	00001517          	auipc	a0,0x1
ffffffffc02007bc:	1a850513          	addi	a0,a0,424 # ffffffffc0201960 <etext+0x2a2>
ffffffffc02007c0:	a03ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("not enough memory for physical page descriptors");
ffffffffc02007c4:	00001617          	auipc	a2,0x1
ffffffffc02007c8:	25460613          	addi	a2,a2,596 # ffffffffc0201a18 <etext+0x35a>
ffffffffc02007cc:	08000593          	li	a1,128
ffffffffc02007d0:	00001517          	auipc	a0,0x1
ffffffffc02007d4:	19050513          	addi	a0,a0,400 # ffffffffc0201960 <etext+0x2a2>
ffffffffc02007d8:	9ebff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02007dc:	86ae                	mv	a3,a1
ffffffffc02007de:	00001617          	auipc	a2,0x1
ffffffffc02007e2:	21260613          	addi	a2,a2,530 # ffffffffc02019f0 <etext+0x332>
ffffffffc02007e6:	0aa00593          	li	a1,170
ffffffffc02007ea:	00001517          	auipc	a0,0x1
ffffffffc02007ee:	17650513          	addi	a0,a0,374 # ffffffffc0201960 <etext+0x2a2>
ffffffffc02007f2:	9d1ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02007f6:	00001617          	auipc	a2,0x1
ffffffffc02007fa:	1fa60613          	addi	a2,a2,506 # ffffffffc02019f0 <etext+0x332>
ffffffffc02007fe:	07b00593          	li	a1,123
ffffffffc0200802:	00001517          	auipc	a0,0x1
ffffffffc0200806:	15e50513          	addi	a0,a0,350 # ffffffffc0201960 <etext+0x2a2>
ffffffffc020080a:	9b9ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc020080e:	00001617          	auipc	a2,0x1
ffffffffc0200812:	23a60613          	addi	a2,a2,570 # ffffffffc0201a48 <etext+0x38a>
ffffffffc0200816:	06a00593          	li	a1,106
ffffffffc020081a:	00001517          	auipc	a0,0x1
ffffffffc020081e:	24e50513          	addi	a0,a0,590 # ffffffffc0201a68 <etext+0x3aa>
ffffffffc0200822:	9a1ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200826 <best_fit_init>:
ffffffffc0200826:	00005797          	auipc	a5,0x5
ffffffffc020082a:	7f278793          	addi	a5,a5,2034 # ffffffffc0206018 <free_area>
ffffffffc020082e:	e79c                	sd	a5,8(a5)
ffffffffc0200830:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc0200832:	0007a823          	sw	zero,16(a5)
}
ffffffffc0200836:	8082                	ret

ffffffffc0200838 <best_fit_nr_free_pages>:
}

static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc0200838:	00005517          	auipc	a0,0x5
ffffffffc020083c:	7f056503          	lwu	a0,2032(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc0200840:	8082                	ret

ffffffffc0200842 <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc0200842:	c145                	beqz	a0,ffffffffc02008e2 <best_fit_alloc_pages+0xa0>
    if (n > nr_free) {
ffffffffc0200844:	00005597          	auipc	a1,0x5
ffffffffc0200848:	7d458593          	addi	a1,a1,2004 # ffffffffc0206018 <free_area>
ffffffffc020084c:	0105a883          	lw	a7,16(a1)
ffffffffc0200850:	862a                	mv	a2,a0
ffffffffc0200852:	02089793          	slli	a5,a7,0x20
ffffffffc0200856:	9381                	srli	a5,a5,0x20
ffffffffc0200858:	08a7e363          	bltu	a5,a0,ffffffffc02008de <best_fit_alloc_pages+0x9c>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc020085c:	659c                	ld	a5,8(a1)
    struct Page *page = NULL;
ffffffffc020085e:	4501                	li	a0,0
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200860:	06b78e63          	beq	a5,a1,ffffffffc02008dc <best_fit_alloc_pages+0x9a>
        if (p->property >= n &&
ffffffffc0200864:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200868:	02071693          	slli	a3,a4,0x20
ffffffffc020086c:	9281                	srli	a3,a3,0x20
ffffffffc020086e:	00c6eb63          	bltu	a3,a2,ffffffffc0200884 <best_fit_alloc_pages+0x42>
ffffffffc0200872:	c509                	beqz	a0,ffffffffc020087c <best_fit_alloc_pages+0x3a>
            (page == NULL || p->property < page->property)) {
ffffffffc0200874:	01052803          	lw	a6,16(a0)
ffffffffc0200878:	01077663          	bgeu	a4,a6,ffffffffc0200884 <best_fit_alloc_pages+0x42>
        struct Page *p = le2page(le, page_link);
ffffffffc020087c:	fe878513          	addi	a0,a5,-24
            if (p->property == n) {
ffffffffc0200880:	00c68663          	beq	a3,a2,ffffffffc020088c <best_fit_alloc_pages+0x4a>
ffffffffc0200884:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200886:	fcb79fe3          	bne	a5,a1,ffffffffc0200864 <best_fit_alloc_pages+0x22>
    if (page != NULL) {
ffffffffc020088a:	c929                	beqz	a0,ffffffffc02008dc <best_fit_alloc_pages+0x9a>
        if (page->property > n) {
ffffffffc020088c:	01052803          	lw	a6,16(a0)
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc0200890:	6d18                	ld	a4,24(a0)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200892:	7114                	ld	a3,32(a0)
ffffffffc0200894:	02081793          	slli	a5,a6,0x20
ffffffffc0200898:	9381                	srli	a5,a5,0x20
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc020089a:	e714                	sd	a3,8(a4)
    next->prev = prev;
ffffffffc020089c:	e298                	sd	a4,0(a3)
            p->property = page->property - n;
ffffffffc020089e:	0006031b          	sext.w	t1,a2
        if (page->property > n) {
ffffffffc02008a2:	02f67563          	bgeu	a2,a5,ffffffffc02008cc <best_fit_alloc_pages+0x8a>
            struct Page *p = page + n;
ffffffffc02008a6:	00261793          	slli	a5,a2,0x2
ffffffffc02008aa:	97b2                	add	a5,a5,a2
ffffffffc02008ac:	078e                	slli	a5,a5,0x3
ffffffffc02008ae:	97aa                	add	a5,a5,a0
            SetPageProperty(p);
ffffffffc02008b0:	6790                	ld	a2,8(a5)
            p->property = page->property - n;
ffffffffc02008b2:	4068083b          	subw	a6,a6,t1
ffffffffc02008b6:	0107a823          	sw	a6,16(a5)
            SetPageProperty(p);
ffffffffc02008ba:	00266613          	ori	a2,a2,2
ffffffffc02008be:	e790                	sd	a2,8(a5)
            list_add(prev, &(p->page_link));
ffffffffc02008c0:	01878613          	addi	a2,a5,24
    prev->next = next->prev = elm;
ffffffffc02008c4:	e290                	sd	a2,0(a3)
ffffffffc02008c6:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc02008c8:	f394                	sd	a3,32(a5)
    elm->prev = prev;
ffffffffc02008ca:	ef98                	sd	a4,24(a5)
        ClearPageProperty(page);
ffffffffc02008cc:	651c                	ld	a5,8(a0)
        nr_free -= n;
ffffffffc02008ce:	406888bb          	subw	a7,a7,t1
ffffffffc02008d2:	0115a823          	sw	a7,16(a1)
        ClearPageProperty(page);
ffffffffc02008d6:	9bf5                	andi	a5,a5,-3
ffffffffc02008d8:	e51c                	sd	a5,8(a0)
ffffffffc02008da:	8082                	ret
}
ffffffffc02008dc:	8082                	ret
        return NULL;
ffffffffc02008de:	4501                	li	a0,0
ffffffffc02008e0:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc02008e2:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc02008e4:	00001697          	auipc	a3,0x1
ffffffffc02008e8:	1f468693          	addi	a3,a3,500 # ffffffffc0201ad8 <etext+0x41a>
ffffffffc02008ec:	00001617          	auipc	a2,0x1
ffffffffc02008f0:	1f460613          	addi	a2,a2,500 # ffffffffc0201ae0 <etext+0x422>
ffffffffc02008f4:	03400593          	li	a1,52
ffffffffc02008f8:	00001517          	auipc	a0,0x1
ffffffffc02008fc:	20050513          	addi	a0,a0,512 # ffffffffc0201af8 <etext+0x43a>
best_fit_alloc_pages(size_t n) {
ffffffffc0200900:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200902:	8c1ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200906 <best_fit_check>:
    free_page(p1);
    free_page(p2);
}

static void
best_fit_check(void) {
ffffffffc0200906:	715d                	addi	sp,sp,-80
ffffffffc0200908:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc020090a:	00005417          	auipc	s0,0x5
ffffffffc020090e:	70e40413          	addi	s0,s0,1806 # ffffffffc0206018 <free_area>
ffffffffc0200912:	641c                	ld	a5,8(s0)
ffffffffc0200914:	e486                	sd	ra,72(sp)
ffffffffc0200916:	fc26                	sd	s1,56(sp)
ffffffffc0200918:	f84a                	sd	s2,48(sp)
ffffffffc020091a:	f44e                	sd	s3,40(sp)
ffffffffc020091c:	f052                	sd	s4,32(sp)
ffffffffc020091e:	ec56                	sd	s5,24(sp)
ffffffffc0200920:	e85a                	sd	s6,16(sp)
ffffffffc0200922:	e45e                	sd	s7,8(sp)
ffffffffc0200924:	e062                	sd	s8,0(sp)
    int score = 0, sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200926:	26878963          	beq	a5,s0,ffffffffc0200b98 <best_fit_check+0x292>
    int count = 0, total = 0;
ffffffffc020092a:	4481                	li	s1,0
ffffffffc020092c:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc020092e:	ff07b703          	ld	a4,-16(a5)
ffffffffc0200932:	8b09                	andi	a4,a4,2
ffffffffc0200934:	26070663          	beqz	a4,ffffffffc0200ba0 <best_fit_check+0x29a>
        count++, total += p->property;
ffffffffc0200938:	ff87a703          	lw	a4,-8(a5)
ffffffffc020093c:	679c                	ld	a5,8(a5)
ffffffffc020093e:	2905                	addiw	s2,s2,1
ffffffffc0200940:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200942:	fe8796e3          	bne	a5,s0,ffffffffc020092e <best_fit_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc0200946:	89a6                	mv	s3,s1
ffffffffc0200948:	ca1ff0ef          	jal	ra,ffffffffc02005e8 <nr_free_pages>
ffffffffc020094c:	33351a63          	bne	a0,s3,ffffffffc0200c80 <best_fit_check+0x37a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200950:	4505                	li	a0,1
ffffffffc0200952:	c7fff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200956:	8a2a                	mv	s4,a0
ffffffffc0200958:	36050463          	beqz	a0,ffffffffc0200cc0 <best_fit_check+0x3ba>
    assert((p1 = alloc_page()) != NULL);
ffffffffc020095c:	4505                	li	a0,1
ffffffffc020095e:	c73ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200962:	89aa                	mv	s3,a0
ffffffffc0200964:	32050e63          	beqz	a0,ffffffffc0200ca0 <best_fit_check+0x39a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200968:	4505                	li	a0,1
ffffffffc020096a:	c67ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc020096e:	8aaa                	mv	s5,a0
ffffffffc0200970:	2c050863          	beqz	a0,ffffffffc0200c40 <best_fit_check+0x33a>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200974:	253a0663          	beq	s4,s3,ffffffffc0200bc0 <best_fit_check+0x2ba>
ffffffffc0200978:	24aa0463          	beq	s4,a0,ffffffffc0200bc0 <best_fit_check+0x2ba>
ffffffffc020097c:	24a98263          	beq	s3,a0,ffffffffc0200bc0 <best_fit_check+0x2ba>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200980:	000a2783          	lw	a5,0(s4)
ffffffffc0200984:	24079e63          	bnez	a5,ffffffffc0200be0 <best_fit_check+0x2da>
ffffffffc0200988:	0009a783          	lw	a5,0(s3)
ffffffffc020098c:	24079a63          	bnez	a5,ffffffffc0200be0 <best_fit_check+0x2da>
ffffffffc0200990:	411c                	lw	a5,0(a0)
ffffffffc0200992:	24079763          	bnez	a5,ffffffffc0200be0 <best_fit_check+0x2da>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200996:	00005797          	auipc	a5,0x5
ffffffffc020099a:	6ba7b783          	ld	a5,1722(a5) # ffffffffc0206050 <pages>
ffffffffc020099e:	40fa0733          	sub	a4,s4,a5
ffffffffc02009a2:	870d                	srai	a4,a4,0x3
ffffffffc02009a4:	00001597          	auipc	a1,0x1
ffffffffc02009a8:	7045b583          	ld	a1,1796(a1) # ffffffffc02020a8 <nbase+0x8>
ffffffffc02009ac:	02b70733          	mul	a4,a4,a1
ffffffffc02009b0:	00001617          	auipc	a2,0x1
ffffffffc02009b4:	6f063603          	ld	a2,1776(a2) # ffffffffc02020a0 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009b8:	00005697          	auipc	a3,0x5
ffffffffc02009bc:	6906b683          	ld	a3,1680(a3) # ffffffffc0206048 <npage>
ffffffffc02009c0:	06b2                	slli	a3,a3,0xc
ffffffffc02009c2:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009c4:	0732                	slli	a4,a4,0xc
ffffffffc02009c6:	22d77d63          	bgeu	a4,a3,ffffffffc0200c00 <best_fit_check+0x2fa>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009ca:	40f98733          	sub	a4,s3,a5
ffffffffc02009ce:	870d                	srai	a4,a4,0x3
ffffffffc02009d0:	02b70733          	mul	a4,a4,a1
ffffffffc02009d4:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009d6:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc02009d8:	3ed77463          	bgeu	a4,a3,ffffffffc0200dc0 <best_fit_check+0x4ba>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009dc:	40f507b3          	sub	a5,a0,a5
ffffffffc02009e0:	878d                	srai	a5,a5,0x3
ffffffffc02009e2:	02b787b3          	mul	a5,a5,a1
ffffffffc02009e6:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009e8:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc02009ea:	3ad7fb63          	bgeu	a5,a3,ffffffffc0200da0 <best_fit_check+0x49a>
    assert(alloc_page() == NULL);
ffffffffc02009ee:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc02009f0:	00043c03          	ld	s8,0(s0)
ffffffffc02009f4:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc02009f8:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc02009fc:	e400                	sd	s0,8(s0)
ffffffffc02009fe:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc0200a00:	00005797          	auipc	a5,0x5
ffffffffc0200a04:	6207a423          	sw	zero,1576(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc0200a08:	bc9ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a0c:	36051a63          	bnez	a0,ffffffffc0200d80 <best_fit_check+0x47a>
    free_page(p0);
ffffffffc0200a10:	4585                	li	a1,1
ffffffffc0200a12:	8552                	mv	a0,s4
ffffffffc0200a14:	bc9ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p1);
ffffffffc0200a18:	4585                	li	a1,1
ffffffffc0200a1a:	854e                	mv	a0,s3
ffffffffc0200a1c:	bc1ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p2);
ffffffffc0200a20:	4585                	li	a1,1
ffffffffc0200a22:	8556                	mv	a0,s5
ffffffffc0200a24:	bb9ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(nr_free == 3);
ffffffffc0200a28:	4818                	lw	a4,16(s0)
ffffffffc0200a2a:	478d                	li	a5,3
ffffffffc0200a2c:	32f71a63          	bne	a4,a5,ffffffffc0200d60 <best_fit_check+0x45a>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a30:	4505                	li	a0,1
ffffffffc0200a32:	b9fff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a36:	89aa                	mv	s3,a0
ffffffffc0200a38:	30050463          	beqz	a0,ffffffffc0200d40 <best_fit_check+0x43a>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a3c:	4505                	li	a0,1
ffffffffc0200a3e:	b93ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a42:	8aaa                	mv	s5,a0
ffffffffc0200a44:	2c050e63          	beqz	a0,ffffffffc0200d20 <best_fit_check+0x41a>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200a48:	4505                	li	a0,1
ffffffffc0200a4a:	b87ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a4e:	8a2a                	mv	s4,a0
ffffffffc0200a50:	2a050863          	beqz	a0,ffffffffc0200d00 <best_fit_check+0x3fa>
    assert(alloc_page() == NULL);
ffffffffc0200a54:	4505                	li	a0,1
ffffffffc0200a56:	b7bff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a5a:	28051363          	bnez	a0,ffffffffc0200ce0 <best_fit_check+0x3da>
    free_page(p0);
ffffffffc0200a5e:	4585                	li	a1,1
ffffffffc0200a60:	854e                	mv	a0,s3
ffffffffc0200a62:	b7bff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200a66:	641c                	ld	a5,8(s0)
ffffffffc0200a68:	1a878c63          	beq	a5,s0,ffffffffc0200c20 <best_fit_check+0x31a>
    assert((p = alloc_page()) == p0);
ffffffffc0200a6c:	4505                	li	a0,1
ffffffffc0200a6e:	b63ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a72:	52a99763          	bne	s3,a0,ffffffffc0200fa0 <best_fit_check+0x69a>
    assert(alloc_page() == NULL);
ffffffffc0200a76:	4505                	li	a0,1
ffffffffc0200a78:	b59ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a7c:	50051263          	bnez	a0,ffffffffc0200f80 <best_fit_check+0x67a>
    assert(nr_free == 0);
ffffffffc0200a80:	481c                	lw	a5,16(s0)
ffffffffc0200a82:	4c079f63          	bnez	a5,ffffffffc0200f60 <best_fit_check+0x65a>
    free_page(p);
ffffffffc0200a86:	854e                	mv	a0,s3
ffffffffc0200a88:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200a8a:	01843023          	sd	s8,0(s0)
ffffffffc0200a8e:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc0200a92:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200a96:	b47ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p1);
ffffffffc0200a9a:	4585                	li	a1,1
ffffffffc0200a9c:	8556                	mv	a0,s5
ffffffffc0200a9e:	b3fff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p2);
ffffffffc0200aa2:	4585                	li	a1,1
ffffffffc0200aa4:	8552                	mv	a0,s4
ffffffffc0200aa6:	b37ff0ef          	jal	ra,ffffffffc02005dc <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200aaa:	4515                	li	a0,5
ffffffffc0200aac:	b25ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200ab0:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0200ab2:	48050763          	beqz	a0,ffffffffc0200f40 <best_fit_check+0x63a>
    assert(!PageProperty(p0));
ffffffffc0200ab6:	651c                	ld	a5,8(a0)
ffffffffc0200ab8:	8b89                	andi	a5,a5,2
ffffffffc0200aba:	46079363          	bnez	a5,ffffffffc0200f20 <best_fit_check+0x61a>
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200abe:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200ac0:	00043b03          	ld	s6,0(s0)
ffffffffc0200ac4:	00843a83          	ld	s5,8(s0)
ffffffffc0200ac8:	e000                	sd	s0,0(s0)
ffffffffc0200aca:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200acc:	b05ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200ad0:	42051863          	bnez	a0,ffffffffc0200f00 <best_fit_check+0x5fa>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc0200ad4:	4589                	li	a1,2
ffffffffc0200ad6:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc0200ada:	01042b83          	lw	s7,16(s0)
    free_pages(p0 + 4, 1);
ffffffffc0200ade:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc0200ae2:	00005797          	auipc	a5,0x5
ffffffffc0200ae6:	5407a323          	sw	zero,1350(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0200aea:	af3ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0200aee:	8562                	mv	a0,s8
ffffffffc0200af0:	4585                	li	a1,1
ffffffffc0200af2:	aebff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200af6:	4511                	li	a0,4
ffffffffc0200af8:	ad9ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200afc:	3e051263          	bnez	a0,ffffffffc0200ee0 <best_fit_check+0x5da>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200b00:	0309b783          	ld	a5,48(s3)
ffffffffc0200b04:	8b89                	andi	a5,a5,2
ffffffffc0200b06:	3a078d63          	beqz	a5,ffffffffc0200ec0 <best_fit_check+0x5ba>
ffffffffc0200b0a:	0389a703          	lw	a4,56(s3)
ffffffffc0200b0e:	4789                	li	a5,2
ffffffffc0200b10:	3af71863          	bne	a4,a5,ffffffffc0200ec0 <best_fit_check+0x5ba>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200b14:	4505                	li	a0,1
ffffffffc0200b16:	abbff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b1a:	8a2a                	mv	s4,a0
ffffffffc0200b1c:	38050263          	beqz	a0,ffffffffc0200ea0 <best_fit_check+0x59a>
    assert(alloc_pages(2) != NULL);
ffffffffc0200b20:	4509                	li	a0,2
ffffffffc0200b22:	aafff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b26:	34050d63          	beqz	a0,ffffffffc0200e80 <best_fit_check+0x57a>
    assert(p0 + 4 == p1);
ffffffffc0200b2a:	334c1b63          	bne	s8,s4,ffffffffc0200e60 <best_fit_check+0x55a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc0200b2e:	854e                	mv	a0,s3
ffffffffc0200b30:	4595                	li	a1,5
ffffffffc0200b32:	aabff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200b36:	4515                	li	a0,5
ffffffffc0200b38:	a99ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b3c:	89aa                	mv	s3,a0
ffffffffc0200b3e:	30050163          	beqz	a0,ffffffffc0200e40 <best_fit_check+0x53a>
    assert(alloc_page() == NULL);
ffffffffc0200b42:	4505                	li	a0,1
ffffffffc0200b44:	a8dff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b48:	2c051c63          	bnez	a0,ffffffffc0200e20 <best_fit_check+0x51a>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc0200b4c:	481c                	lw	a5,16(s0)
ffffffffc0200b4e:	2a079963          	bnez	a5,ffffffffc0200e00 <best_fit_check+0x4fa>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc0200b52:	4595                	li	a1,5
ffffffffc0200b54:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc0200b56:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc0200b5a:	01643023          	sd	s6,0(s0)
ffffffffc0200b5e:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc0200b62:	a7bff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    return listelm->next;
ffffffffc0200b66:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200b68:	00878963          	beq	a5,s0,ffffffffc0200b7a <best_fit_check+0x274>
        struct Page *p = le2page(le, page_link);
        count--, total -= p->property;
ffffffffc0200b6c:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200b70:	679c                	ld	a5,8(a5)
ffffffffc0200b72:	397d                	addiw	s2,s2,-1
ffffffffc0200b74:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200b76:	fe879be3          	bne	a5,s0,ffffffffc0200b6c <best_fit_check+0x266>
    }
    assert(count == 0);
ffffffffc0200b7a:	26091363          	bnez	s2,ffffffffc0200de0 <best_fit_check+0x4da>
    assert(total == 0);
ffffffffc0200b7e:	e0ed                	bnez	s1,ffffffffc0200c60 <best_fit_check+0x35a>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n", score, sumscore);
    #endif
}
ffffffffc0200b80:	60a6                	ld	ra,72(sp)
ffffffffc0200b82:	6406                	ld	s0,64(sp)
ffffffffc0200b84:	74e2                	ld	s1,56(sp)
ffffffffc0200b86:	7942                	ld	s2,48(sp)
ffffffffc0200b88:	79a2                	ld	s3,40(sp)
ffffffffc0200b8a:	7a02                	ld	s4,32(sp)
ffffffffc0200b8c:	6ae2                	ld	s5,24(sp)
ffffffffc0200b8e:	6b42                	ld	s6,16(sp)
ffffffffc0200b90:	6ba2                	ld	s7,8(sp)
ffffffffc0200b92:	6c02                	ld	s8,0(sp)
ffffffffc0200b94:	6161                	addi	sp,sp,80
ffffffffc0200b96:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200b98:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200b9a:	4481                	li	s1,0
ffffffffc0200b9c:	4901                	li	s2,0
ffffffffc0200b9e:	b36d                	j	ffffffffc0200948 <best_fit_check+0x42>
        assert(PageProperty(p));
ffffffffc0200ba0:	00001697          	auipc	a3,0x1
ffffffffc0200ba4:	f7068693          	addi	a3,a3,-144 # ffffffffc0201b10 <etext+0x452>
ffffffffc0200ba8:	00001617          	auipc	a2,0x1
ffffffffc0200bac:	f3860613          	addi	a2,a2,-200 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200bb0:	0d000593          	li	a1,208
ffffffffc0200bb4:	00001517          	auipc	a0,0x1
ffffffffc0200bb8:	f4450513          	addi	a0,a0,-188 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200bbc:	e06ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200bc0:	00001697          	auipc	a3,0x1
ffffffffc0200bc4:	fe068693          	addi	a3,a3,-32 # ffffffffc0201ba0 <etext+0x4e2>
ffffffffc0200bc8:	00001617          	auipc	a2,0x1
ffffffffc0200bcc:	f1860613          	addi	a2,a2,-232 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200bd0:	09e00593          	li	a1,158
ffffffffc0200bd4:	00001517          	auipc	a0,0x1
ffffffffc0200bd8:	f2450513          	addi	a0,a0,-220 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200bdc:	de6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200be0:	00001697          	auipc	a3,0x1
ffffffffc0200be4:	fe868693          	addi	a3,a3,-24 # ffffffffc0201bc8 <etext+0x50a>
ffffffffc0200be8:	00001617          	auipc	a2,0x1
ffffffffc0200bec:	ef860613          	addi	a2,a2,-264 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200bf0:	09f00593          	li	a1,159
ffffffffc0200bf4:	00001517          	auipc	a0,0x1
ffffffffc0200bf8:	f0450513          	addi	a0,a0,-252 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200bfc:	dc6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200c00:	00001697          	auipc	a3,0x1
ffffffffc0200c04:	00868693          	addi	a3,a3,8 # ffffffffc0201c08 <etext+0x54a>
ffffffffc0200c08:	00001617          	auipc	a2,0x1
ffffffffc0200c0c:	ed860613          	addi	a2,a2,-296 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200c10:	0a100593          	li	a1,161
ffffffffc0200c14:	00001517          	auipc	a0,0x1
ffffffffc0200c18:	ee450513          	addi	a0,a0,-284 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200c1c:	da6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0200c20:	00001697          	auipc	a3,0x1
ffffffffc0200c24:	07068693          	addi	a3,a3,112 # ffffffffc0201c90 <etext+0x5d2>
ffffffffc0200c28:	00001617          	auipc	a2,0x1
ffffffffc0200c2c:	eb860613          	addi	a2,a2,-328 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200c30:	0ba00593          	li	a1,186
ffffffffc0200c34:	00001517          	auipc	a0,0x1
ffffffffc0200c38:	ec450513          	addi	a0,a0,-316 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200c3c:	d86ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200c40:	00001697          	auipc	a3,0x1
ffffffffc0200c44:	f4068693          	addi	a3,a3,-192 # ffffffffc0201b80 <etext+0x4c2>
ffffffffc0200c48:	00001617          	auipc	a2,0x1
ffffffffc0200c4c:	e9860613          	addi	a2,a2,-360 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200c50:	09c00593          	li	a1,156
ffffffffc0200c54:	00001517          	auipc	a0,0x1
ffffffffc0200c58:	ea450513          	addi	a0,a0,-348 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200c5c:	d66ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == 0);
ffffffffc0200c60:	00001697          	auipc	a3,0x1
ffffffffc0200c64:	16068693          	addi	a3,a3,352 # ffffffffc0201dc0 <etext+0x702>
ffffffffc0200c68:	00001617          	auipc	a2,0x1
ffffffffc0200c6c:	e7860613          	addi	a2,a2,-392 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200c70:	11200593          	li	a1,274
ffffffffc0200c74:	00001517          	auipc	a0,0x1
ffffffffc0200c78:	e8450513          	addi	a0,a0,-380 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200c7c:	d46ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == nr_free_pages());
ffffffffc0200c80:	00001697          	auipc	a3,0x1
ffffffffc0200c84:	ea068693          	addi	a3,a3,-352 # ffffffffc0201b20 <etext+0x462>
ffffffffc0200c88:	00001617          	auipc	a2,0x1
ffffffffc0200c8c:	e5860613          	addi	a2,a2,-424 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200c90:	0d300593          	li	a1,211
ffffffffc0200c94:	00001517          	auipc	a0,0x1
ffffffffc0200c98:	e6450513          	addi	a0,a0,-412 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200c9c:	d26ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200ca0:	00001697          	auipc	a3,0x1
ffffffffc0200ca4:	ec068693          	addi	a3,a3,-320 # ffffffffc0201b60 <etext+0x4a2>
ffffffffc0200ca8:	00001617          	auipc	a2,0x1
ffffffffc0200cac:	e3860613          	addi	a2,a2,-456 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200cb0:	09b00593          	li	a1,155
ffffffffc0200cb4:	00001517          	auipc	a0,0x1
ffffffffc0200cb8:	e4450513          	addi	a0,a0,-444 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200cbc:	d06ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200cc0:	00001697          	auipc	a3,0x1
ffffffffc0200cc4:	e8068693          	addi	a3,a3,-384 # ffffffffc0201b40 <etext+0x482>
ffffffffc0200cc8:	00001617          	auipc	a2,0x1
ffffffffc0200ccc:	e1860613          	addi	a2,a2,-488 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200cd0:	09a00593          	li	a1,154
ffffffffc0200cd4:	00001517          	auipc	a0,0x1
ffffffffc0200cd8:	e2450513          	addi	a0,a0,-476 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200cdc:	ce6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200ce0:	00001697          	auipc	a3,0x1
ffffffffc0200ce4:	f8868693          	addi	a3,a3,-120 # ffffffffc0201c68 <etext+0x5aa>
ffffffffc0200ce8:	00001617          	auipc	a2,0x1
ffffffffc0200cec:	df860613          	addi	a2,a2,-520 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200cf0:	0b700593          	li	a1,183
ffffffffc0200cf4:	00001517          	auipc	a0,0x1
ffffffffc0200cf8:	e0450513          	addi	a0,a0,-508 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200cfc:	cc6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200d00:	00001697          	auipc	a3,0x1
ffffffffc0200d04:	e8068693          	addi	a3,a3,-384 # ffffffffc0201b80 <etext+0x4c2>
ffffffffc0200d08:	00001617          	auipc	a2,0x1
ffffffffc0200d0c:	dd860613          	addi	a2,a2,-552 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200d10:	0b500593          	li	a1,181
ffffffffc0200d14:	00001517          	auipc	a0,0x1
ffffffffc0200d18:	de450513          	addi	a0,a0,-540 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200d1c:	ca6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200d20:	00001697          	auipc	a3,0x1
ffffffffc0200d24:	e4068693          	addi	a3,a3,-448 # ffffffffc0201b60 <etext+0x4a2>
ffffffffc0200d28:	00001617          	auipc	a2,0x1
ffffffffc0200d2c:	db860613          	addi	a2,a2,-584 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200d30:	0b400593          	li	a1,180
ffffffffc0200d34:	00001517          	auipc	a0,0x1
ffffffffc0200d38:	dc450513          	addi	a0,a0,-572 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200d3c:	c86ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200d40:	00001697          	auipc	a3,0x1
ffffffffc0200d44:	e0068693          	addi	a3,a3,-512 # ffffffffc0201b40 <etext+0x482>
ffffffffc0200d48:	00001617          	auipc	a2,0x1
ffffffffc0200d4c:	d9860613          	addi	a2,a2,-616 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200d50:	0b300593          	li	a1,179
ffffffffc0200d54:	00001517          	auipc	a0,0x1
ffffffffc0200d58:	da450513          	addi	a0,a0,-604 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200d5c:	c66ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 3);
ffffffffc0200d60:	00001697          	auipc	a3,0x1
ffffffffc0200d64:	f2068693          	addi	a3,a3,-224 # ffffffffc0201c80 <etext+0x5c2>
ffffffffc0200d68:	00001617          	auipc	a2,0x1
ffffffffc0200d6c:	d7860613          	addi	a2,a2,-648 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200d70:	0b100593          	li	a1,177
ffffffffc0200d74:	00001517          	auipc	a0,0x1
ffffffffc0200d78:	d8450513          	addi	a0,a0,-636 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200d7c:	c46ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d80:	00001697          	auipc	a3,0x1
ffffffffc0200d84:	ee868693          	addi	a3,a3,-280 # ffffffffc0201c68 <etext+0x5aa>
ffffffffc0200d88:	00001617          	auipc	a2,0x1
ffffffffc0200d8c:	d5860613          	addi	a2,a2,-680 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200d90:	0ac00593          	li	a1,172
ffffffffc0200d94:	00001517          	auipc	a0,0x1
ffffffffc0200d98:	d6450513          	addi	a0,a0,-668 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200d9c:	c26ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200da0:	00001697          	auipc	a3,0x1
ffffffffc0200da4:	ea868693          	addi	a3,a3,-344 # ffffffffc0201c48 <etext+0x58a>
ffffffffc0200da8:	00001617          	auipc	a2,0x1
ffffffffc0200dac:	d3860613          	addi	a2,a2,-712 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200db0:	0a300593          	li	a1,163
ffffffffc0200db4:	00001517          	auipc	a0,0x1
ffffffffc0200db8:	d4450513          	addi	a0,a0,-700 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200dbc:	c06ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200dc0:	00001697          	auipc	a3,0x1
ffffffffc0200dc4:	e6868693          	addi	a3,a3,-408 # ffffffffc0201c28 <etext+0x56a>
ffffffffc0200dc8:	00001617          	auipc	a2,0x1
ffffffffc0200dcc:	d1860613          	addi	a2,a2,-744 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200dd0:	0a200593          	li	a1,162
ffffffffc0200dd4:	00001517          	auipc	a0,0x1
ffffffffc0200dd8:	d2450513          	addi	a0,a0,-732 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200ddc:	be6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(count == 0);
ffffffffc0200de0:	00001697          	auipc	a3,0x1
ffffffffc0200de4:	fd068693          	addi	a3,a3,-48 # ffffffffc0201db0 <etext+0x6f2>
ffffffffc0200de8:	00001617          	auipc	a2,0x1
ffffffffc0200dec:	cf860613          	addi	a2,a2,-776 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200df0:	11100593          	li	a1,273
ffffffffc0200df4:	00001517          	auipc	a0,0x1
ffffffffc0200df8:	d0450513          	addi	a0,a0,-764 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200dfc:	bc6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200e00:	00001697          	auipc	a3,0x1
ffffffffc0200e04:	ec868693          	addi	a3,a3,-312 # ffffffffc0201cc8 <etext+0x60a>
ffffffffc0200e08:	00001617          	auipc	a2,0x1
ffffffffc0200e0c:	cd860613          	addi	a2,a2,-808 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200e10:	10600593          	li	a1,262
ffffffffc0200e14:	00001517          	auipc	a0,0x1
ffffffffc0200e18:	ce450513          	addi	a0,a0,-796 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200e1c:	ba6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200e20:	00001697          	auipc	a3,0x1
ffffffffc0200e24:	e4868693          	addi	a3,a3,-440 # ffffffffc0201c68 <etext+0x5aa>
ffffffffc0200e28:	00001617          	auipc	a2,0x1
ffffffffc0200e2c:	cb860613          	addi	a2,a2,-840 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200e30:	10000593          	li	a1,256
ffffffffc0200e34:	00001517          	auipc	a0,0x1
ffffffffc0200e38:	cc450513          	addi	a0,a0,-828 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200e3c:	b86ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200e40:	00001697          	auipc	a3,0x1
ffffffffc0200e44:	f5068693          	addi	a3,a3,-176 # ffffffffc0201d90 <etext+0x6d2>
ffffffffc0200e48:	00001617          	auipc	a2,0x1
ffffffffc0200e4c:	c9860613          	addi	a2,a2,-872 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200e50:	0ff00593          	li	a1,255
ffffffffc0200e54:	00001517          	auipc	a0,0x1
ffffffffc0200e58:	ca450513          	addi	a0,a0,-860 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200e5c:	b66ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 + 4 == p1);
ffffffffc0200e60:	00001697          	auipc	a3,0x1
ffffffffc0200e64:	f2068693          	addi	a3,a3,-224 # ffffffffc0201d80 <etext+0x6c2>
ffffffffc0200e68:	00001617          	auipc	a2,0x1
ffffffffc0200e6c:	c7860613          	addi	a2,a2,-904 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200e70:	0f700593          	li	a1,247
ffffffffc0200e74:	00001517          	auipc	a0,0x1
ffffffffc0200e78:	c8450513          	addi	a0,a0,-892 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200e7c:	b46ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(2) != NULL);
ffffffffc0200e80:	00001697          	auipc	a3,0x1
ffffffffc0200e84:	ee868693          	addi	a3,a3,-280 # ffffffffc0201d68 <etext+0x6aa>
ffffffffc0200e88:	00001617          	auipc	a2,0x1
ffffffffc0200e8c:	c5860613          	addi	a2,a2,-936 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200e90:	0f600593          	li	a1,246
ffffffffc0200e94:	00001517          	auipc	a0,0x1
ffffffffc0200e98:	c6450513          	addi	a0,a0,-924 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200e9c:	b26ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc0200ea0:	00001697          	auipc	a3,0x1
ffffffffc0200ea4:	ea868693          	addi	a3,a3,-344 # ffffffffc0201d48 <etext+0x68a>
ffffffffc0200ea8:	00001617          	auipc	a2,0x1
ffffffffc0200eac:	c3860613          	addi	a2,a2,-968 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200eb0:	0f500593          	li	a1,245
ffffffffc0200eb4:	00001517          	auipc	a0,0x1
ffffffffc0200eb8:	c4450513          	addi	a0,a0,-956 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200ebc:	b06ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc0200ec0:	00001697          	auipc	a3,0x1
ffffffffc0200ec4:	e5868693          	addi	a3,a3,-424 # ffffffffc0201d18 <etext+0x65a>
ffffffffc0200ec8:	00001617          	auipc	a2,0x1
ffffffffc0200ecc:	c1860613          	addi	a2,a2,-1000 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200ed0:	0f300593          	li	a1,243
ffffffffc0200ed4:	00001517          	auipc	a0,0x1
ffffffffc0200ed8:	c2450513          	addi	a0,a0,-988 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200edc:	ae6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200ee0:	00001697          	auipc	a3,0x1
ffffffffc0200ee4:	e2068693          	addi	a3,a3,-480 # ffffffffc0201d00 <etext+0x642>
ffffffffc0200ee8:	00001617          	auipc	a2,0x1
ffffffffc0200eec:	bf860613          	addi	a2,a2,-1032 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200ef0:	0f200593          	li	a1,242
ffffffffc0200ef4:	00001517          	auipc	a0,0x1
ffffffffc0200ef8:	c0450513          	addi	a0,a0,-1020 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200efc:	ac6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200f00:	00001697          	auipc	a3,0x1
ffffffffc0200f04:	d6868693          	addi	a3,a3,-664 # ffffffffc0201c68 <etext+0x5aa>
ffffffffc0200f08:	00001617          	auipc	a2,0x1
ffffffffc0200f0c:	bd860613          	addi	a2,a2,-1064 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200f10:	0e600593          	li	a1,230
ffffffffc0200f14:	00001517          	auipc	a0,0x1
ffffffffc0200f18:	be450513          	addi	a0,a0,-1052 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200f1c:	aa6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200f20:	00001697          	auipc	a3,0x1
ffffffffc0200f24:	dc868693          	addi	a3,a3,-568 # ffffffffc0201ce8 <etext+0x62a>
ffffffffc0200f28:	00001617          	auipc	a2,0x1
ffffffffc0200f2c:	bb860613          	addi	a2,a2,-1096 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200f30:	0dd00593          	li	a1,221
ffffffffc0200f34:	00001517          	auipc	a0,0x1
ffffffffc0200f38:	bc450513          	addi	a0,a0,-1084 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200f3c:	a86ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != NULL);
ffffffffc0200f40:	00001697          	auipc	a3,0x1
ffffffffc0200f44:	d9868693          	addi	a3,a3,-616 # ffffffffc0201cd8 <etext+0x61a>
ffffffffc0200f48:	00001617          	auipc	a2,0x1
ffffffffc0200f4c:	b9860613          	addi	a2,a2,-1128 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200f50:	0dc00593          	li	a1,220
ffffffffc0200f54:	00001517          	auipc	a0,0x1
ffffffffc0200f58:	ba450513          	addi	a0,a0,-1116 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200f5c:	a66ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200f60:	00001697          	auipc	a3,0x1
ffffffffc0200f64:	d6868693          	addi	a3,a3,-664 # ffffffffc0201cc8 <etext+0x60a>
ffffffffc0200f68:	00001617          	auipc	a2,0x1
ffffffffc0200f6c:	b7860613          	addi	a2,a2,-1160 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200f70:	0c000593          	li	a1,192
ffffffffc0200f74:	00001517          	auipc	a0,0x1
ffffffffc0200f78:	b8450513          	addi	a0,a0,-1148 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200f7c:	a46ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200f80:	00001697          	auipc	a3,0x1
ffffffffc0200f84:	ce868693          	addi	a3,a3,-792 # ffffffffc0201c68 <etext+0x5aa>
ffffffffc0200f88:	00001617          	auipc	a2,0x1
ffffffffc0200f8c:	b5860613          	addi	a2,a2,-1192 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200f90:	0be00593          	li	a1,190
ffffffffc0200f94:	00001517          	auipc	a0,0x1
ffffffffc0200f98:	b6450513          	addi	a0,a0,-1180 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200f9c:	a26ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200fa0:	00001697          	auipc	a3,0x1
ffffffffc0200fa4:	d0868693          	addi	a3,a3,-760 # ffffffffc0201ca8 <etext+0x5ea>
ffffffffc0200fa8:	00001617          	auipc	a2,0x1
ffffffffc0200fac:	b3860613          	addi	a2,a2,-1224 # ffffffffc0201ae0 <etext+0x422>
ffffffffc0200fb0:	0bd00593          	li	a1,189
ffffffffc0200fb4:	00001517          	auipc	a0,0x1
ffffffffc0200fb8:	b4450513          	addi	a0,a0,-1212 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0200fbc:	a06ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200fc0 <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc0200fc0:	1141                	addi	sp,sp,-16
ffffffffc0200fc2:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200fc4:	14058c63          	beqz	a1,ffffffffc020111c <best_fit_free_pages+0x15c>
    for (; p != base + n; p++) {
ffffffffc0200fc8:	00259693          	slli	a3,a1,0x2
ffffffffc0200fcc:	96ae                	add	a3,a3,a1
ffffffffc0200fce:	068e                	slli	a3,a3,0x3
ffffffffc0200fd0:	96aa                	add	a3,a3,a0
ffffffffc0200fd2:	87aa                	mv	a5,a0
ffffffffc0200fd4:	00d50e63          	beq	a0,a3,ffffffffc0200ff0 <best_fit_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0200fd8:	6798                	ld	a4,8(a5)
ffffffffc0200fda:	8b0d                	andi	a4,a4,3
ffffffffc0200fdc:	12071063          	bnez	a4,ffffffffc02010fc <best_fit_free_pages+0x13c>
        p->flags = 0;
ffffffffc0200fe0:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200fe4:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0200fe8:	02878793          	addi	a5,a5,40
ffffffffc0200fec:	fed796e3          	bne	a5,a3,ffffffffc0200fd8 <best_fit_free_pages+0x18>
    SetPageProperty(base);
ffffffffc0200ff0:	00853883          	ld	a7,8(a0)
    nr_free += n;
ffffffffc0200ff4:	00005697          	auipc	a3,0x5
ffffffffc0200ff8:	02468693          	addi	a3,a3,36 # ffffffffc0206018 <free_area>
ffffffffc0200ffc:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0200ffe:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0201000:	0028e613          	ori	a2,a7,2
    return list->next == list;
ffffffffc0201004:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0201006:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0201008:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc020100a:	9f2d                	addw	a4,a4,a1
ffffffffc020100c:	ca98                	sw	a4,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc020100e:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0201012:	0ad78b63          	beq	a5,a3,ffffffffc02010c8 <best_fit_free_pages+0x108>
            struct Page *page = le2page(le, page_link);
ffffffffc0201016:	fe878713          	addi	a4,a5,-24
ffffffffc020101a:	0006b303          	ld	t1,0(a3)
    if (list_empty(&free_list)) {
ffffffffc020101e:	4801                	li	a6,0
            if (base < page) {
ffffffffc0201020:	00e56a63          	bltu	a0,a4,ffffffffc0201034 <best_fit_free_pages+0x74>
    return listelm->next;
ffffffffc0201024:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0201026:	06d70563          	beq	a4,a3,ffffffffc0201090 <best_fit_free_pages+0xd0>
    for (; p != base + n; p++) {
ffffffffc020102a:	87ba                	mv	a5,a4
            struct Page *page = le2page(le, page_link);
ffffffffc020102c:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0201030:	fee57ae3          	bgeu	a0,a4,ffffffffc0201024 <best_fit_free_pages+0x64>
ffffffffc0201034:	00080463          	beqz	a6,ffffffffc020103c <best_fit_free_pages+0x7c>
ffffffffc0201038:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc020103c:	0007b803          	ld	a6,0(a5)
    prev->next = next->prev = elm;
ffffffffc0201040:	e390                	sd	a2,0(a5)
ffffffffc0201042:	00c83423          	sd	a2,8(a6)
    elm->next = next;
ffffffffc0201046:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0201048:	01053c23          	sd	a6,24(a0)
    if (le != &free_list) {
ffffffffc020104c:	02d80463          	beq	a6,a3,ffffffffc0201074 <best_fit_free_pages+0xb4>
        if (p + p->property == base) {
ffffffffc0201050:	ff882e03          	lw	t3,-8(a6)
        p = le2page(le, page_link);
ffffffffc0201054:	fe880313          	addi	t1,a6,-24
        if (p + p->property == base) {
ffffffffc0201058:	020e1613          	slli	a2,t3,0x20
ffffffffc020105c:	9201                	srli	a2,a2,0x20
ffffffffc020105e:	00261713          	slli	a4,a2,0x2
ffffffffc0201062:	9732                	add	a4,a4,a2
ffffffffc0201064:	070e                	slli	a4,a4,0x3
ffffffffc0201066:	971a                	add	a4,a4,t1
ffffffffc0201068:	02e50e63          	beq	a0,a4,ffffffffc02010a4 <best_fit_free_pages+0xe4>
    if (le != &free_list) {
ffffffffc020106c:	00d78f63          	beq	a5,a3,ffffffffc020108a <best_fit_free_pages+0xca>
ffffffffc0201070:	fe878713          	addi	a4,a5,-24
        if (base + base->property == p) {
ffffffffc0201074:	490c                	lw	a1,16(a0)
ffffffffc0201076:	02059613          	slli	a2,a1,0x20
ffffffffc020107a:	9201                	srli	a2,a2,0x20
ffffffffc020107c:	00261693          	slli	a3,a2,0x2
ffffffffc0201080:	96b2                	add	a3,a3,a2
ffffffffc0201082:	068e                	slli	a3,a3,0x3
ffffffffc0201084:	96aa                	add	a3,a3,a0
ffffffffc0201086:	04d70863          	beq	a4,a3,ffffffffc02010d6 <best_fit_free_pages+0x116>
}
ffffffffc020108a:	60a2                	ld	ra,8(sp)
ffffffffc020108c:	0141                	addi	sp,sp,16
ffffffffc020108e:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0201090:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201092:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc0201094:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0201096:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0201098:	02d70463          	beq	a4,a3,ffffffffc02010c0 <best_fit_free_pages+0x100>
    prev->next = next->prev = elm;
ffffffffc020109c:	8332                	mv	t1,a2
ffffffffc020109e:	4805                	li	a6,1
    for (; p != base + n; p++) {
ffffffffc02010a0:	87ba                	mv	a5,a4
ffffffffc02010a2:	b769                	j	ffffffffc020102c <best_fit_free_pages+0x6c>
            p->property += base->property;
ffffffffc02010a4:	01c585bb          	addw	a1,a1,t3
ffffffffc02010a8:	feb82c23          	sw	a1,-8(a6)
            ClearPageProperty(base);
ffffffffc02010ac:	ffd8f893          	andi	a7,a7,-3
ffffffffc02010b0:	01153423          	sd	a7,8(a0)
    prev->next = next;
ffffffffc02010b4:	00f83423          	sd	a5,8(a6)
    next->prev = prev;
ffffffffc02010b8:	0107b023          	sd	a6,0(a5)
            base = p;
ffffffffc02010bc:	851a                	mv	a0,t1
ffffffffc02010be:	b77d                	j	ffffffffc020106c <best_fit_free_pages+0xac>
        while ((le = list_next(le)) != &free_list) {
ffffffffc02010c0:	883e                	mv	a6,a5
ffffffffc02010c2:	e290                	sd	a2,0(a3)
ffffffffc02010c4:	87b6                	mv	a5,a3
ffffffffc02010c6:	b769                	j	ffffffffc0201050 <best_fit_free_pages+0x90>
}
ffffffffc02010c8:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc02010ca:	e390                	sd	a2,0(a5)
ffffffffc02010cc:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02010ce:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02010d0:	ed1c                	sd	a5,24(a0)
ffffffffc02010d2:	0141                	addi	sp,sp,16
ffffffffc02010d4:	8082                	ret
            base->property += p->property;
ffffffffc02010d6:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc02010da:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc02010de:	0007b803          	ld	a6,0(a5)
ffffffffc02010e2:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc02010e4:	9db5                	addw	a1,a1,a3
ffffffffc02010e6:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc02010e8:	9b75                	andi	a4,a4,-3
ffffffffc02010ea:	fee7b823          	sd	a4,-16(a5)
}
ffffffffc02010ee:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc02010f0:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc02010f4:	01063023          	sd	a6,0(a2)
ffffffffc02010f8:	0141                	addi	sp,sp,16
ffffffffc02010fa:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02010fc:	00001697          	auipc	a3,0x1
ffffffffc0201100:	cd468693          	addi	a3,a3,-812 # ffffffffc0201dd0 <etext+0x712>
ffffffffc0201104:	00001617          	auipc	a2,0x1
ffffffffc0201108:	9dc60613          	addi	a2,a2,-1572 # ffffffffc0201ae0 <etext+0x422>
ffffffffc020110c:	06200593          	li	a1,98
ffffffffc0201110:	00001517          	auipc	a0,0x1
ffffffffc0201114:	9e850513          	addi	a0,a0,-1560 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0201118:	8aaff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc020111c:	00001697          	auipc	a3,0x1
ffffffffc0201120:	9bc68693          	addi	a3,a3,-1604 # ffffffffc0201ad8 <etext+0x41a>
ffffffffc0201124:	00001617          	auipc	a2,0x1
ffffffffc0201128:	9bc60613          	addi	a2,a2,-1604 # ffffffffc0201ae0 <etext+0x422>
ffffffffc020112c:	05e00593          	li	a1,94
ffffffffc0201130:	00001517          	auipc	a0,0x1
ffffffffc0201134:	9c850513          	addi	a0,a0,-1592 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0201138:	88aff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020113c <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc020113c:	1141                	addi	sp,sp,-16
ffffffffc020113e:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0201140:	c5f1                	beqz	a1,ffffffffc020120c <best_fit_init_memmap+0xd0>
    for (; p != base + n; p++) {
ffffffffc0201142:	00259693          	slli	a3,a1,0x2
ffffffffc0201146:	96ae                	add	a3,a3,a1
ffffffffc0201148:	068e                	slli	a3,a3,0x3
ffffffffc020114a:	96aa                	add	a3,a3,a0
ffffffffc020114c:	87aa                	mv	a5,a0
ffffffffc020114e:	00d50f63          	beq	a0,a3,ffffffffc020116c <best_fit_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0201152:	6798                	ld	a4,8(a5)
ffffffffc0201154:	8b05                	andi	a4,a4,1
ffffffffc0201156:	cf41                	beqz	a4,ffffffffc02011ee <best_fit_init_memmap+0xb2>
        p->flags = p->property = 0;
ffffffffc0201158:	0007a823          	sw	zero,16(a5)
ffffffffc020115c:	0007b423          	sd	zero,8(a5)
ffffffffc0201160:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p++) {
ffffffffc0201164:	02878793          	addi	a5,a5,40
ffffffffc0201168:	fed795e3          	bne	a5,a3,ffffffffc0201152 <best_fit_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc020116c:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc020116e:	00005697          	auipc	a3,0x5
ffffffffc0201172:	eaa68693          	addi	a3,a3,-342 # ffffffffc0206018 <free_area>
ffffffffc0201176:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc0201178:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc020117a:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc020117e:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0201180:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0201182:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc0201184:	9db9                	addw	a1,a1,a4
ffffffffc0201186:	ca8c                	sw	a1,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0201188:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc020118c:	04d78a63          	beq	a5,a3,ffffffffc02011e0 <best_fit_init_memmap+0xa4>
            struct Page *page = le2page(le, page_link);
ffffffffc0201190:	fe878713          	addi	a4,a5,-24
ffffffffc0201194:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0201198:	4581                	li	a1,0
            if (base < page) {
ffffffffc020119a:	00e56a63          	bltu	a0,a4,ffffffffc02011ae <best_fit_init_memmap+0x72>
    return listelm->next;
ffffffffc020119e:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc02011a0:	02d70263          	beq	a4,a3,ffffffffc02011c4 <best_fit_init_memmap+0x88>
    for (; p != base + n; p++) {
ffffffffc02011a4:	87ba                	mv	a5,a4
            struct Page *page = le2page(le, page_link);
ffffffffc02011a6:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc02011aa:	fee57ae3          	bgeu	a0,a4,ffffffffc020119e <best_fit_init_memmap+0x62>
ffffffffc02011ae:	c199                	beqz	a1,ffffffffc02011b4 <best_fit_init_memmap+0x78>
ffffffffc02011b0:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc02011b4:	6398                	ld	a4,0(a5)
}
ffffffffc02011b6:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc02011b8:	e390                	sd	a2,0(a5)
ffffffffc02011ba:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc02011bc:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02011be:	ed18                	sd	a4,24(a0)
ffffffffc02011c0:	0141                	addi	sp,sp,16
ffffffffc02011c2:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc02011c4:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02011c6:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc02011c8:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc02011ca:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc02011cc:	00d70663          	beq	a4,a3,ffffffffc02011d8 <best_fit_init_memmap+0x9c>
    prev->next = next->prev = elm;
ffffffffc02011d0:	8832                	mv	a6,a2
ffffffffc02011d2:	4585                	li	a1,1
    for (; p != base + n; p++) {
ffffffffc02011d4:	87ba                	mv	a5,a4
ffffffffc02011d6:	bfc1                	j	ffffffffc02011a6 <best_fit_init_memmap+0x6a>
}
ffffffffc02011d8:	60a2                	ld	ra,8(sp)
ffffffffc02011da:	e290                	sd	a2,0(a3)
ffffffffc02011dc:	0141                	addi	sp,sp,16
ffffffffc02011de:	8082                	ret
ffffffffc02011e0:	60a2                	ld	ra,8(sp)
ffffffffc02011e2:	e390                	sd	a2,0(a5)
ffffffffc02011e4:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02011e6:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02011e8:	ed1c                	sd	a5,24(a0)
ffffffffc02011ea:	0141                	addi	sp,sp,16
ffffffffc02011ec:	8082                	ret
        assert(PageReserved(p));
ffffffffc02011ee:	00001697          	auipc	a3,0x1
ffffffffc02011f2:	c0a68693          	addi	a3,a3,-1014 # ffffffffc0201df8 <etext+0x73a>
ffffffffc02011f6:	00001617          	auipc	a2,0x1
ffffffffc02011fa:	8ea60613          	addi	a2,a2,-1814 # ffffffffc0201ae0 <etext+0x422>
ffffffffc02011fe:	45e5                	li	a1,25
ffffffffc0201200:	00001517          	auipc	a0,0x1
ffffffffc0201204:	8f850513          	addi	a0,a0,-1800 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0201208:	fbbfe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc020120c:	00001697          	auipc	a3,0x1
ffffffffc0201210:	8cc68693          	addi	a3,a3,-1844 # ffffffffc0201ad8 <etext+0x41a>
ffffffffc0201214:	00001617          	auipc	a2,0x1
ffffffffc0201218:	8cc60613          	addi	a2,a2,-1844 # ffffffffc0201ae0 <etext+0x422>
ffffffffc020121c:	45d5                	li	a1,21
ffffffffc020121e:	00001517          	auipc	a0,0x1
ffffffffc0201222:	8da50513          	addi	a0,a0,-1830 # ffffffffc0201af8 <etext+0x43a>
ffffffffc0201226:	f9dfe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc020122a <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc020122a:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc020122e:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201230:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201232:	cb81                	beqz	a5,ffffffffc0201242 <strlen+0x18>
        cnt ++;
ffffffffc0201234:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201236:	00a707b3          	add	a5,a4,a0
ffffffffc020123a:	0007c783          	lbu	a5,0(a5)
ffffffffc020123e:	fbfd                	bnez	a5,ffffffffc0201234 <strlen+0xa>
ffffffffc0201240:	8082                	ret
    }
    return cnt;
}
ffffffffc0201242:	8082                	ret

ffffffffc0201244 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201244:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201246:	e589                	bnez	a1,ffffffffc0201250 <strnlen+0xc>
ffffffffc0201248:	a811                	j	ffffffffc020125c <strnlen+0x18>
        cnt ++;
ffffffffc020124a:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc020124c:	00f58863          	beq	a1,a5,ffffffffc020125c <strnlen+0x18>
ffffffffc0201250:	00f50733          	add	a4,a0,a5
ffffffffc0201254:	00074703          	lbu	a4,0(a4) # fffffffffff80000 <end+0x3fd79f88>
ffffffffc0201258:	fb6d                	bnez	a4,ffffffffc020124a <strnlen+0x6>
ffffffffc020125a:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc020125c:	852e                	mv	a0,a1
ffffffffc020125e:	8082                	ret

ffffffffc0201260 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201260:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201264:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201268:	cb89                	beqz	a5,ffffffffc020127a <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc020126a:	0505                	addi	a0,a0,1
ffffffffc020126c:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020126e:	fee789e3          	beq	a5,a4,ffffffffc0201260 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201272:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201276:	9d19                	subw	a0,a0,a4
ffffffffc0201278:	8082                	ret
ffffffffc020127a:	4501                	li	a0,0
ffffffffc020127c:	bfed                	j	ffffffffc0201276 <strcmp+0x16>

ffffffffc020127e <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020127e:	c20d                	beqz	a2,ffffffffc02012a0 <strncmp+0x22>
ffffffffc0201280:	962e                	add	a2,a2,a1
ffffffffc0201282:	a031                	j	ffffffffc020128e <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201284:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201286:	00e79a63          	bne	a5,a4,ffffffffc020129a <strncmp+0x1c>
ffffffffc020128a:	00b60b63          	beq	a2,a1,ffffffffc02012a0 <strncmp+0x22>
ffffffffc020128e:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201292:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201294:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201298:	f7f5                	bnez	a5,ffffffffc0201284 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020129a:	40e7853b          	subw	a0,a5,a4
}
ffffffffc020129e:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02012a0:	4501                	li	a0,0
ffffffffc02012a2:	8082                	ret

ffffffffc02012a4 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc02012a4:	ca01                	beqz	a2,ffffffffc02012b4 <memset+0x10>
ffffffffc02012a6:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc02012a8:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc02012aa:	0785                	addi	a5,a5,1
ffffffffc02012ac:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc02012b0:	fec79de3          	bne	a5,a2,ffffffffc02012aa <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc02012b4:	8082                	ret

ffffffffc02012b6 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc02012b6:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02012ba:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc02012bc:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02012c0:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc02012c2:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc02012c6:	f022                	sd	s0,32(sp)
ffffffffc02012c8:	ec26                	sd	s1,24(sp)
ffffffffc02012ca:	e84a                	sd	s2,16(sp)
ffffffffc02012cc:	f406                	sd	ra,40(sp)
ffffffffc02012ce:	e44e                	sd	s3,8(sp)
ffffffffc02012d0:	84aa                	mv	s1,a0
ffffffffc02012d2:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc02012d4:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc02012d8:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02012da:	03067e63          	bgeu	a2,a6,ffffffffc0201316 <printnum+0x60>
ffffffffc02012de:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02012e0:	00805763          	blez	s0,ffffffffc02012ee <printnum+0x38>
ffffffffc02012e4:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02012e6:	85ca                	mv	a1,s2
ffffffffc02012e8:	854e                	mv	a0,s3
ffffffffc02012ea:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02012ec:	fc65                	bnez	s0,ffffffffc02012e4 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02012ee:	1a02                	slli	s4,s4,0x20
ffffffffc02012f0:	00001797          	auipc	a5,0x1
ffffffffc02012f4:	b6878793          	addi	a5,a5,-1176 # ffffffffc0201e58 <best_fit_pmm_manager+0x38>
ffffffffc02012f8:	020a5a13          	srli	s4,s4,0x20
ffffffffc02012fc:	9a3e                	add	s4,s4,a5
}
ffffffffc02012fe:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201300:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0201304:	70a2                	ld	ra,40(sp)
ffffffffc0201306:	69a2                	ld	s3,8(sp)
ffffffffc0201308:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020130a:	85ca                	mv	a1,s2
ffffffffc020130c:	87a6                	mv	a5,s1
}
ffffffffc020130e:	6942                	ld	s2,16(sp)
ffffffffc0201310:	64e2                	ld	s1,24(sp)
ffffffffc0201312:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201314:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201316:	03065633          	divu	a2,a2,a6
ffffffffc020131a:	8722                	mv	a4,s0
ffffffffc020131c:	f9bff0ef          	jal	ra,ffffffffc02012b6 <printnum>
ffffffffc0201320:	b7f9                	j	ffffffffc02012ee <printnum+0x38>

ffffffffc0201322 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201322:	7119                	addi	sp,sp,-128
ffffffffc0201324:	f4a6                	sd	s1,104(sp)
ffffffffc0201326:	f0ca                	sd	s2,96(sp)
ffffffffc0201328:	ecce                	sd	s3,88(sp)
ffffffffc020132a:	e8d2                	sd	s4,80(sp)
ffffffffc020132c:	e4d6                	sd	s5,72(sp)
ffffffffc020132e:	e0da                	sd	s6,64(sp)
ffffffffc0201330:	fc5e                	sd	s7,56(sp)
ffffffffc0201332:	f06a                	sd	s10,32(sp)
ffffffffc0201334:	fc86                	sd	ra,120(sp)
ffffffffc0201336:	f8a2                	sd	s0,112(sp)
ffffffffc0201338:	f862                	sd	s8,48(sp)
ffffffffc020133a:	f466                	sd	s9,40(sp)
ffffffffc020133c:	ec6e                	sd	s11,24(sp)
ffffffffc020133e:	892a                	mv	s2,a0
ffffffffc0201340:	84ae                	mv	s1,a1
ffffffffc0201342:	8d32                	mv	s10,a2
ffffffffc0201344:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201346:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc020134a:	5b7d                	li	s6,-1
ffffffffc020134c:	00001a97          	auipc	s5,0x1
ffffffffc0201350:	b40a8a93          	addi	s5,s5,-1216 # ffffffffc0201e8c <best_fit_pmm_manager+0x6c>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201354:	00001b97          	auipc	s7,0x1
ffffffffc0201358:	d14b8b93          	addi	s7,s7,-748 # ffffffffc0202068 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020135c:	000d4503          	lbu	a0,0(s10)
ffffffffc0201360:	001d0413          	addi	s0,s10,1
ffffffffc0201364:	01350a63          	beq	a0,s3,ffffffffc0201378 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0201368:	c121                	beqz	a0,ffffffffc02013a8 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc020136a:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020136c:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc020136e:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201370:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201374:	ff351ae3          	bne	a0,s3,ffffffffc0201368 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201378:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc020137c:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201380:	4c81                	li	s9,0
ffffffffc0201382:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201384:	5c7d                	li	s8,-1
ffffffffc0201386:	5dfd                	li	s11,-1
ffffffffc0201388:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc020138c:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020138e:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201392:	0ff5f593          	zext.b	a1,a1
ffffffffc0201396:	00140d13          	addi	s10,s0,1
ffffffffc020139a:	04b56263          	bltu	a0,a1,ffffffffc02013de <vprintfmt+0xbc>
ffffffffc020139e:	058a                	slli	a1,a1,0x2
ffffffffc02013a0:	95d6                	add	a1,a1,s5
ffffffffc02013a2:	4194                	lw	a3,0(a1)
ffffffffc02013a4:	96d6                	add	a3,a3,s5
ffffffffc02013a6:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc02013a8:	70e6                	ld	ra,120(sp)
ffffffffc02013aa:	7446                	ld	s0,112(sp)
ffffffffc02013ac:	74a6                	ld	s1,104(sp)
ffffffffc02013ae:	7906                	ld	s2,96(sp)
ffffffffc02013b0:	69e6                	ld	s3,88(sp)
ffffffffc02013b2:	6a46                	ld	s4,80(sp)
ffffffffc02013b4:	6aa6                	ld	s5,72(sp)
ffffffffc02013b6:	6b06                	ld	s6,64(sp)
ffffffffc02013b8:	7be2                	ld	s7,56(sp)
ffffffffc02013ba:	7c42                	ld	s8,48(sp)
ffffffffc02013bc:	7ca2                	ld	s9,40(sp)
ffffffffc02013be:	7d02                	ld	s10,32(sp)
ffffffffc02013c0:	6de2                	ld	s11,24(sp)
ffffffffc02013c2:	6109                	addi	sp,sp,128
ffffffffc02013c4:	8082                	ret
            padc = '0';
ffffffffc02013c6:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc02013c8:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02013cc:	846a                	mv	s0,s10
ffffffffc02013ce:	00140d13          	addi	s10,s0,1
ffffffffc02013d2:	fdd6059b          	addiw	a1,a2,-35
ffffffffc02013d6:	0ff5f593          	zext.b	a1,a1
ffffffffc02013da:	fcb572e3          	bgeu	a0,a1,ffffffffc020139e <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02013de:	85a6                	mv	a1,s1
ffffffffc02013e0:	02500513          	li	a0,37
ffffffffc02013e4:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc02013e6:	fff44783          	lbu	a5,-1(s0)
ffffffffc02013ea:	8d22                	mv	s10,s0
ffffffffc02013ec:	f73788e3          	beq	a5,s3,ffffffffc020135c <vprintfmt+0x3a>
ffffffffc02013f0:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02013f4:	1d7d                	addi	s10,s10,-1
ffffffffc02013f6:	ff379de3          	bne	a5,s3,ffffffffc02013f0 <vprintfmt+0xce>
ffffffffc02013fa:	b78d                	j	ffffffffc020135c <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02013fc:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0201400:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201404:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201406:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc020140a:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020140e:	02d86463          	bltu	a6,a3,ffffffffc0201436 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0201412:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201416:	002c169b          	slliw	a3,s8,0x2
ffffffffc020141a:	0186873b          	addw	a4,a3,s8
ffffffffc020141e:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201422:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201424:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201428:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc020142a:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc020142e:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201432:	fed870e3          	bgeu	a6,a3,ffffffffc0201412 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201436:	f40ddce3          	bgez	s11,ffffffffc020138e <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc020143a:	8de2                	mv	s11,s8
ffffffffc020143c:	5c7d                	li	s8,-1
ffffffffc020143e:	bf81                	j	ffffffffc020138e <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201440:	fffdc693          	not	a3,s11
ffffffffc0201444:	96fd                	srai	a3,a3,0x3f
ffffffffc0201446:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020144a:	00144603          	lbu	a2,1(s0)
ffffffffc020144e:	2d81                	sext.w	s11,s11
ffffffffc0201450:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201452:	bf35                	j	ffffffffc020138e <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201454:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201458:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc020145c:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020145e:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201460:	bfd9                	j	ffffffffc0201436 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201462:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201464:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201468:	01174463          	blt	a4,a7,ffffffffc0201470 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc020146c:	1a088e63          	beqz	a7,ffffffffc0201628 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201470:	000a3603          	ld	a2,0(s4)
ffffffffc0201474:	46c1                	li	a3,16
ffffffffc0201476:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201478:	2781                	sext.w	a5,a5
ffffffffc020147a:	876e                	mv	a4,s11
ffffffffc020147c:	85a6                	mv	a1,s1
ffffffffc020147e:	854a                	mv	a0,s2
ffffffffc0201480:	e37ff0ef          	jal	ra,ffffffffc02012b6 <printnum>
            break;
ffffffffc0201484:	bde1                	j	ffffffffc020135c <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201486:	000a2503          	lw	a0,0(s4)
ffffffffc020148a:	85a6                	mv	a1,s1
ffffffffc020148c:	0a21                	addi	s4,s4,8
ffffffffc020148e:	9902                	jalr	s2
            break;
ffffffffc0201490:	b5f1                	j	ffffffffc020135c <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201492:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201494:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201498:	01174463          	blt	a4,a7,ffffffffc02014a0 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc020149c:	18088163          	beqz	a7,ffffffffc020161e <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc02014a0:	000a3603          	ld	a2,0(s4)
ffffffffc02014a4:	46a9                	li	a3,10
ffffffffc02014a6:	8a2e                	mv	s4,a1
ffffffffc02014a8:	bfc1                	j	ffffffffc0201478 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014aa:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc02014ae:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014b0:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02014b2:	bdf1                	j	ffffffffc020138e <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc02014b4:	85a6                	mv	a1,s1
ffffffffc02014b6:	02500513          	li	a0,37
ffffffffc02014ba:	9902                	jalr	s2
            break;
ffffffffc02014bc:	b545                	j	ffffffffc020135c <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014be:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc02014c2:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014c4:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02014c6:	b5e1                	j	ffffffffc020138e <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc02014c8:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02014ca:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02014ce:	01174463          	blt	a4,a7,ffffffffc02014d6 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc02014d2:	14088163          	beqz	a7,ffffffffc0201614 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc02014d6:	000a3603          	ld	a2,0(s4)
ffffffffc02014da:	46a1                	li	a3,8
ffffffffc02014dc:	8a2e                	mv	s4,a1
ffffffffc02014de:	bf69                	j	ffffffffc0201478 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02014e0:	03000513          	li	a0,48
ffffffffc02014e4:	85a6                	mv	a1,s1
ffffffffc02014e6:	e03e                	sd	a5,0(sp)
ffffffffc02014e8:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02014ea:	85a6                	mv	a1,s1
ffffffffc02014ec:	07800513          	li	a0,120
ffffffffc02014f0:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02014f2:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02014f4:	6782                	ld	a5,0(sp)
ffffffffc02014f6:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02014f8:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02014fc:	bfb5                	j	ffffffffc0201478 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02014fe:	000a3403          	ld	s0,0(s4)
ffffffffc0201502:	008a0713          	addi	a4,s4,8
ffffffffc0201506:	e03a                	sd	a4,0(sp)
ffffffffc0201508:	14040263          	beqz	s0,ffffffffc020164c <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc020150c:	0fb05763          	blez	s11,ffffffffc02015fa <vprintfmt+0x2d8>
ffffffffc0201510:	02d00693          	li	a3,45
ffffffffc0201514:	0cd79163          	bne	a5,a3,ffffffffc02015d6 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201518:	00044783          	lbu	a5,0(s0)
ffffffffc020151c:	0007851b          	sext.w	a0,a5
ffffffffc0201520:	cf85                	beqz	a5,ffffffffc0201558 <vprintfmt+0x236>
ffffffffc0201522:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201526:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020152a:	000c4563          	bltz	s8,ffffffffc0201534 <vprintfmt+0x212>
ffffffffc020152e:	3c7d                	addiw	s8,s8,-1
ffffffffc0201530:	036c0263          	beq	s8,s6,ffffffffc0201554 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201534:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201536:	0e0c8e63          	beqz	s9,ffffffffc0201632 <vprintfmt+0x310>
ffffffffc020153a:	3781                	addiw	a5,a5,-32
ffffffffc020153c:	0ef47b63          	bgeu	s0,a5,ffffffffc0201632 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201540:	03f00513          	li	a0,63
ffffffffc0201544:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201546:	000a4783          	lbu	a5,0(s4)
ffffffffc020154a:	3dfd                	addiw	s11,s11,-1
ffffffffc020154c:	0a05                	addi	s4,s4,1
ffffffffc020154e:	0007851b          	sext.w	a0,a5
ffffffffc0201552:	ffe1                	bnez	a5,ffffffffc020152a <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201554:	01b05963          	blez	s11,ffffffffc0201566 <vprintfmt+0x244>
ffffffffc0201558:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc020155a:	85a6                	mv	a1,s1
ffffffffc020155c:	02000513          	li	a0,32
ffffffffc0201560:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201562:	fe0d9be3          	bnez	s11,ffffffffc0201558 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201566:	6a02                	ld	s4,0(sp)
ffffffffc0201568:	bbd5                	j	ffffffffc020135c <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc020156a:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020156c:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201570:	01174463          	blt	a4,a7,ffffffffc0201578 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201574:	08088d63          	beqz	a7,ffffffffc020160e <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0201578:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc020157c:	0a044d63          	bltz	s0,ffffffffc0201636 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201580:	8622                	mv	a2,s0
ffffffffc0201582:	8a66                	mv	s4,s9
ffffffffc0201584:	46a9                	li	a3,10
ffffffffc0201586:	bdcd                	j	ffffffffc0201478 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0201588:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020158c:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc020158e:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201590:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201594:	8fb5                	xor	a5,a5,a3
ffffffffc0201596:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020159a:	02d74163          	blt	a4,a3,ffffffffc02015bc <vprintfmt+0x29a>
ffffffffc020159e:	00369793          	slli	a5,a3,0x3
ffffffffc02015a2:	97de                	add	a5,a5,s7
ffffffffc02015a4:	639c                	ld	a5,0(a5)
ffffffffc02015a6:	cb99                	beqz	a5,ffffffffc02015bc <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc02015a8:	86be                	mv	a3,a5
ffffffffc02015aa:	00001617          	auipc	a2,0x1
ffffffffc02015ae:	8de60613          	addi	a2,a2,-1826 # ffffffffc0201e88 <best_fit_pmm_manager+0x68>
ffffffffc02015b2:	85a6                	mv	a1,s1
ffffffffc02015b4:	854a                	mv	a0,s2
ffffffffc02015b6:	0ce000ef          	jal	ra,ffffffffc0201684 <printfmt>
ffffffffc02015ba:	b34d                	j	ffffffffc020135c <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc02015bc:	00001617          	auipc	a2,0x1
ffffffffc02015c0:	8bc60613          	addi	a2,a2,-1860 # ffffffffc0201e78 <best_fit_pmm_manager+0x58>
ffffffffc02015c4:	85a6                	mv	a1,s1
ffffffffc02015c6:	854a                	mv	a0,s2
ffffffffc02015c8:	0bc000ef          	jal	ra,ffffffffc0201684 <printfmt>
ffffffffc02015cc:	bb41                	j	ffffffffc020135c <vprintfmt+0x3a>
                p = "(null)";
ffffffffc02015ce:	00001417          	auipc	s0,0x1
ffffffffc02015d2:	8a240413          	addi	s0,s0,-1886 # ffffffffc0201e70 <best_fit_pmm_manager+0x50>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02015d6:	85e2                	mv	a1,s8
ffffffffc02015d8:	8522                	mv	a0,s0
ffffffffc02015da:	e43e                	sd	a5,8(sp)
ffffffffc02015dc:	c69ff0ef          	jal	ra,ffffffffc0201244 <strnlen>
ffffffffc02015e0:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02015e4:	01b05b63          	blez	s11,ffffffffc02015fa <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02015e8:	67a2                	ld	a5,8(sp)
ffffffffc02015ea:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02015ee:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02015f0:	85a6                	mv	a1,s1
ffffffffc02015f2:	8552                	mv	a0,s4
ffffffffc02015f4:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02015f6:	fe0d9ce3          	bnez	s11,ffffffffc02015ee <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02015fa:	00044783          	lbu	a5,0(s0)
ffffffffc02015fe:	00140a13          	addi	s4,s0,1
ffffffffc0201602:	0007851b          	sext.w	a0,a5
ffffffffc0201606:	d3a5                	beqz	a5,ffffffffc0201566 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201608:	05e00413          	li	s0,94
ffffffffc020160c:	bf39                	j	ffffffffc020152a <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc020160e:	000a2403          	lw	s0,0(s4)
ffffffffc0201612:	b7ad                	j	ffffffffc020157c <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201614:	000a6603          	lwu	a2,0(s4)
ffffffffc0201618:	46a1                	li	a3,8
ffffffffc020161a:	8a2e                	mv	s4,a1
ffffffffc020161c:	bdb1                	j	ffffffffc0201478 <vprintfmt+0x156>
ffffffffc020161e:	000a6603          	lwu	a2,0(s4)
ffffffffc0201622:	46a9                	li	a3,10
ffffffffc0201624:	8a2e                	mv	s4,a1
ffffffffc0201626:	bd89                	j	ffffffffc0201478 <vprintfmt+0x156>
ffffffffc0201628:	000a6603          	lwu	a2,0(s4)
ffffffffc020162c:	46c1                	li	a3,16
ffffffffc020162e:	8a2e                	mv	s4,a1
ffffffffc0201630:	b5a1                	j	ffffffffc0201478 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201632:	9902                	jalr	s2
ffffffffc0201634:	bf09                	j	ffffffffc0201546 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201636:	85a6                	mv	a1,s1
ffffffffc0201638:	02d00513          	li	a0,45
ffffffffc020163c:	e03e                	sd	a5,0(sp)
ffffffffc020163e:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201640:	6782                	ld	a5,0(sp)
ffffffffc0201642:	8a66                	mv	s4,s9
ffffffffc0201644:	40800633          	neg	a2,s0
ffffffffc0201648:	46a9                	li	a3,10
ffffffffc020164a:	b53d                	j	ffffffffc0201478 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc020164c:	03b05163          	blez	s11,ffffffffc020166e <vprintfmt+0x34c>
ffffffffc0201650:	02d00693          	li	a3,45
ffffffffc0201654:	f6d79de3          	bne	a5,a3,ffffffffc02015ce <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201658:	00001417          	auipc	s0,0x1
ffffffffc020165c:	81840413          	addi	s0,s0,-2024 # ffffffffc0201e70 <best_fit_pmm_manager+0x50>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201660:	02800793          	li	a5,40
ffffffffc0201664:	02800513          	li	a0,40
ffffffffc0201668:	00140a13          	addi	s4,s0,1
ffffffffc020166c:	bd6d                	j	ffffffffc0201526 <vprintfmt+0x204>
ffffffffc020166e:	00001a17          	auipc	s4,0x1
ffffffffc0201672:	803a0a13          	addi	s4,s4,-2045 # ffffffffc0201e71 <best_fit_pmm_manager+0x51>
ffffffffc0201676:	02800513          	li	a0,40
ffffffffc020167a:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc020167e:	05e00413          	li	s0,94
ffffffffc0201682:	b565                	j	ffffffffc020152a <vprintfmt+0x208>

ffffffffc0201684 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201684:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201686:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020168a:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020168c:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020168e:	ec06                	sd	ra,24(sp)
ffffffffc0201690:	f83a                	sd	a4,48(sp)
ffffffffc0201692:	fc3e                	sd	a5,56(sp)
ffffffffc0201694:	e0c2                	sd	a6,64(sp)
ffffffffc0201696:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201698:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc020169a:	c89ff0ef          	jal	ra,ffffffffc0201322 <vprintfmt>
}
ffffffffc020169e:	60e2                	ld	ra,24(sp)
ffffffffc02016a0:	6161                	addi	sp,sp,80
ffffffffc02016a2:	8082                	ret

ffffffffc02016a4 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc02016a4:	4781                	li	a5,0
ffffffffc02016a6:	00005717          	auipc	a4,0x5
ffffffffc02016aa:	96a73703          	ld	a4,-1686(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc02016ae:	88ba                	mv	a7,a4
ffffffffc02016b0:	852a                	mv	a0,a0
ffffffffc02016b2:	85be                	mv	a1,a5
ffffffffc02016b4:	863e                	mv	a2,a5
ffffffffc02016b6:	00000073          	ecall
ffffffffc02016ba:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc02016bc:	8082                	ret
