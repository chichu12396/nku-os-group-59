
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
ffffffffc0200050:	73c50513          	addi	a0,a0,1852 # ffffffffc0201788 <etext+0x4>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	74650513          	addi	a0,a0,1862 # ffffffffc02017a8 <etext+0x24>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	71658593          	addi	a1,a1,1814 # ffffffffc0201784 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	75250513          	addi	a0,a0,1874 # ffffffffc02017c8 <etext+0x44>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00006597          	auipc	a1,0x6
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0206018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	75e50513          	addi	a0,a0,1886 # ffffffffc02017e8 <etext+0x64>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00006597          	auipc	a1,0x6
ffffffffc020009a:	fe258593          	addi	a1,a1,-30 # ffffffffc0206078 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	76a50513          	addi	a0,a0,1898 # ffffffffc0201808 <etext+0x84>
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
ffffffffc02000d0:	75c50513          	addi	a0,a0,1884 # ffffffffc0201828 <etext+0xa4>
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
ffffffffc02000f0:	27a010ef          	jal	ra,ffffffffc020136a <memset>
    dtb_init();
ffffffffc02000f4:	122000ef          	jal	ra,ffffffffc0200216 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	4ce000ef          	jal	ra,ffffffffc02005c6 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	75c50513          	addi	a0,a0,1884 # ffffffffc0201858 <etext+0xd4>
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
ffffffffc0200140:	2a8010ef          	jal	ra,ffffffffc02013e8 <vprintfmt>
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
ffffffffc0200176:	272010ef          	jal	ra,ffffffffc02013e8 <vprintfmt>
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
ffffffffc02001f6:	68650513          	addi	a0,a0,1670 # ffffffffc0201878 <etext+0xf4>
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
ffffffffc020020c:	64850513          	addi	a0,a0,1608 # ffffffffc0201850 <etext+0xcc>
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
ffffffffc020021c:	68050513          	addi	a0,a0,1664 # ffffffffc0201898 <etext+0x114>
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
ffffffffc020024a:	66250513          	addi	a0,a0,1634 # ffffffffc02018a8 <etext+0x124>
ffffffffc020024e:	effff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc0200252:	00006417          	auipc	s0,0x6
ffffffffc0200256:	db640413          	addi	s0,s0,-586 # ffffffffc0206008 <boot_dtb>
ffffffffc020025a:	600c                	ld	a1,0(s0)
ffffffffc020025c:	00001517          	auipc	a0,0x1
ffffffffc0200260:	65c50513          	addi	a0,a0,1628 # ffffffffc02018b8 <etext+0x134>
ffffffffc0200264:	ee9ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200268:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc020026c:	00001517          	auipc	a0,0x1
ffffffffc0200270:	66450513          	addi	a0,a0,1636 # ffffffffc02018d0 <etext+0x14c>
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
ffffffffc020032a:	5fa90913          	addi	s2,s2,1530 # ffffffffc0201920 <etext+0x19c>
ffffffffc020032e:	49bd                	li	s3,15
        switch (token) {
ffffffffc0200330:	4d91                	li	s11,4
ffffffffc0200332:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200334:	00001497          	auipc	s1,0x1
ffffffffc0200338:	5e448493          	addi	s1,s1,1508 # ffffffffc0201918 <etext+0x194>
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
ffffffffc020038c:	61050513          	addi	a0,a0,1552 # ffffffffc0201998 <etext+0x214>
ffffffffc0200390:	dbdff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc0200394:	00001517          	auipc	a0,0x1
ffffffffc0200398:	63c50513          	addi	a0,a0,1596 # ffffffffc02019d0 <etext+0x24c>
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
ffffffffc02003d8:	51c50513          	addi	a0,a0,1308 # ffffffffc02018f0 <etext+0x16c>
}
ffffffffc02003dc:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	b3bd                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003e0:	8556                	mv	a0,s5
ffffffffc02003e2:	70f000ef          	jal	ra,ffffffffc02012f0 <strlen>
ffffffffc02003e6:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003e8:	4619                	li	a2,6
ffffffffc02003ea:	85a6                	mv	a1,s1
ffffffffc02003ec:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003ee:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f0:	755000ef          	jal	ra,ffffffffc0201344 <strncmp>
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
ffffffffc0200486:	6a1000ef          	jal	ra,ffffffffc0201326 <strcmp>
ffffffffc020048a:	66a2                	ld	a3,8(sp)
ffffffffc020048c:	f94d                	bnez	a0,ffffffffc020043e <dtb_init+0x228>
ffffffffc020048e:	fb59f8e3          	bgeu	s3,s5,ffffffffc020043e <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc0200492:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc0200496:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc020049a:	00001517          	auipc	a0,0x1
ffffffffc020049e:	48e50513          	addi	a0,a0,1166 # ffffffffc0201928 <etext+0x1a4>
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
ffffffffc020056c:	3e050513          	addi	a0,a0,992 # ffffffffc0201948 <etext+0x1c4>
ffffffffc0200570:	bddff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc0200574:	014b5613          	srli	a2,s6,0x14
ffffffffc0200578:	85da                	mv	a1,s6
ffffffffc020057a:	00001517          	auipc	a0,0x1
ffffffffc020057e:	3e650513          	addi	a0,a0,998 # ffffffffc0201960 <etext+0x1dc>
ffffffffc0200582:	bcbff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200586:	008b05b3          	add	a1,s6,s0
ffffffffc020058a:	15fd                	addi	a1,a1,-1
ffffffffc020058c:	00001517          	auipc	a0,0x1
ffffffffc0200590:	3f450513          	addi	a0,a0,1012 # ffffffffc0201980 <etext+0x1fc>
ffffffffc0200594:	bb9ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc0200598:	00001517          	auipc	a0,0x1
ffffffffc020059c:	43850513          	addi	a0,a0,1080 # ffffffffc02019d0 <etext+0x24c>
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
ffffffffc02005cc:	19e0106f          	j	ffffffffc020176a <sbi_console_putchar>

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
    pmm_manager = &default_pmm_manager;
ffffffffc02005f4:	00002797          	auipc	a5,0x2
ffffffffc02005f8:	96c78793          	addi	a5,a5,-1684 # ffffffffc0201f60 <default_pmm_manager>
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
ffffffffc0200606:	3e650513          	addi	a0,a0,998 # ffffffffc02019e8 <etext+0x264>
    pmm_manager = &default_pmm_manager;
ffffffffc020060a:	00006417          	auipc	s0,0x6
ffffffffc020060e:	a4e40413          	addi	s0,s0,-1458 # ffffffffc0206058 <pmm_manager>
{
ffffffffc0200612:	f406                	sd	ra,40(sp)
ffffffffc0200614:	e84a                	sd	s2,16(sp)
ffffffffc0200616:	ec26                	sd	s1,24(sp)
ffffffffc0200618:	e44e                	sd	s3,8(sp)
ffffffffc020061a:	e052                	sd	s4,0(sp)
    pmm_manager = &default_pmm_manager;
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
ffffffffc0200670:	40450513          	addi	a0,a0,1028 # ffffffffc0201a70 <etext+0x2ec>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200674:	e09c                	sd	a5,0(s1)
    cprintf("physical memory map:\n");
ffffffffc0200676:	ad7ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n",
ffffffffc020067a:	fff98693          	addi	a3,s3,-1
ffffffffc020067e:	864a                	mv	a2,s2
ffffffffc0200680:	85d2                	mv	a1,s4
ffffffffc0200682:	00001517          	auipc	a0,0x1
ffffffffc0200686:	40650513          	addi	a0,a0,1030 # ffffffffc0201a88 <etext+0x304>
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
ffffffffc0200726:	41e50513          	addi	a0,a0,1054 # ffffffffc0201b40 <etext+0x3bc>
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
ffffffffc0200764:	40050513          	addi	a0,a0,1024 # ffffffffc0201b60 <etext+0x3dc>
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
ffffffffc0200798:	2a460613          	addi	a2,a2,676 # ffffffffc0201a38 <etext+0x2b4>
ffffffffc020079c:	06300593          	li	a1,99
ffffffffc02007a0:	00001517          	auipc	a0,0x1
ffffffffc02007a4:	28850513          	addi	a0,a0,648 # ffffffffc0201a28 <etext+0x2a4>
ffffffffc02007a8:	a1bff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("invalid physical memory range from DTB");
ffffffffc02007ac:	00001617          	auipc	a2,0x1
ffffffffc02007b0:	25460613          	addi	a2,a2,596 # ffffffffc0201a00 <etext+0x27c>
ffffffffc02007b4:	05d00593          	li	a1,93
ffffffffc02007b8:	00001517          	auipc	a0,0x1
ffffffffc02007bc:	27050513          	addi	a0,a0,624 # ffffffffc0201a28 <etext+0x2a4>
ffffffffc02007c0:	a03ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("not enough memory for physical page descriptors");
ffffffffc02007c4:	00001617          	auipc	a2,0x1
ffffffffc02007c8:	31c60613          	addi	a2,a2,796 # ffffffffc0201ae0 <etext+0x35c>
ffffffffc02007cc:	08000593          	li	a1,128
ffffffffc02007d0:	00001517          	auipc	a0,0x1
ffffffffc02007d4:	25850513          	addi	a0,a0,600 # ffffffffc0201a28 <etext+0x2a4>
ffffffffc02007d8:	9ebff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02007dc:	86ae                	mv	a3,a1
ffffffffc02007de:	00001617          	auipc	a2,0x1
ffffffffc02007e2:	2da60613          	addi	a2,a2,730 # ffffffffc0201ab8 <etext+0x334>
ffffffffc02007e6:	0aa00593          	li	a1,170
ffffffffc02007ea:	00001517          	auipc	a0,0x1
ffffffffc02007ee:	23e50513          	addi	a0,a0,574 # ffffffffc0201a28 <etext+0x2a4>
ffffffffc02007f2:	9d1ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02007f6:	00001617          	auipc	a2,0x1
ffffffffc02007fa:	2c260613          	addi	a2,a2,706 # ffffffffc0201ab8 <etext+0x334>
ffffffffc02007fe:	07b00593          	li	a1,123
ffffffffc0200802:	00001517          	auipc	a0,0x1
ffffffffc0200806:	22650513          	addi	a0,a0,550 # ffffffffc0201a28 <etext+0x2a4>
ffffffffc020080a:	9b9ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc020080e:	00001617          	auipc	a2,0x1
ffffffffc0200812:	30260613          	addi	a2,a2,770 # ffffffffc0201b10 <etext+0x38c>
ffffffffc0200816:	06a00593          	li	a1,106
ffffffffc020081a:	00001517          	auipc	a0,0x1
ffffffffc020081e:	31650513          	addi	a0,a0,790 # ffffffffc0201b30 <etext+0x3ac>
ffffffffc0200822:	9a1ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200826 <default_init>:
ffffffffc0200826:	00005797          	auipc	a5,0x5
ffffffffc020082a:	7f278793          	addi	a5,a5,2034 # ffffffffc0206018 <free_area>
ffffffffc020082e:	e79c                	sd	a5,8(a5)
ffffffffc0200830:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc0200832:	0007a823          	sw	zero,16(a5)
}
ffffffffc0200836:	8082                	ret

ffffffffc0200838 <default_nr_free_pages>:
}

static size_t
default_nr_free_pages(void) {
    return nr_free;
}
ffffffffc0200838:	00005517          	auipc	a0,0x5
ffffffffc020083c:	7f056503          	lwu	a0,2032(a0) # ffffffffc0206028 <free_area+0x10>
ffffffffc0200840:	8082                	ret

ffffffffc0200842 <default_alloc_pages>:
    assert(n > 0);
ffffffffc0200842:	c949                	beqz	a0,ffffffffc02008d4 <default_alloc_pages+0x92>
    if (n > nr_free) {
ffffffffc0200844:	00005597          	auipc	a1,0x5
ffffffffc0200848:	7d458593          	addi	a1,a1,2004 # ffffffffc0206018 <free_area>
ffffffffc020084c:	0105a803          	lw	a6,16(a1)
ffffffffc0200850:	862a                	mv	a2,a0
ffffffffc0200852:	02081793          	slli	a5,a6,0x20
ffffffffc0200856:	9381                	srli	a5,a5,0x20
ffffffffc0200858:	00a7ee63          	bltu	a5,a0,ffffffffc0200874 <default_alloc_pages+0x32>
    list_entry_t *le = &free_list;
ffffffffc020085c:	87ae                	mv	a5,a1
ffffffffc020085e:	a801                	j	ffffffffc020086e <default_alloc_pages+0x2c>
        if (p->property >= n) {
ffffffffc0200860:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200864:	02071693          	slli	a3,a4,0x20
ffffffffc0200868:	9281                	srli	a3,a3,0x20
ffffffffc020086a:	00c6f763          	bgeu	a3,a2,ffffffffc0200878 <default_alloc_pages+0x36>
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc020086e:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200870:	feb798e3          	bne	a5,a1,ffffffffc0200860 <default_alloc_pages+0x1e>
        return NULL;
ffffffffc0200874:	4501                	li	a0,0
}
ffffffffc0200876:	8082                	ret
 * list_prev - get the previous entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_prev(list_entry_t *listelm) {
    return listelm->prev;
ffffffffc0200878:	0007b303          	ld	t1,0(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc020087c:	0087b883          	ld	a7,8(a5)
        struct Page *p = le2page(le, page_link);
ffffffffc0200880:	fe878513          	addi	a0,a5,-24
            p->property = page->property - n;
ffffffffc0200884:	00060e1b          	sext.w	t3,a2
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200888:	01133423          	sd	a7,8(t1)
    next->prev = prev;
ffffffffc020088c:	0068b023          	sd	t1,0(a7)
        if (page->property > n) {
ffffffffc0200890:	02d67863          	bgeu	a2,a3,ffffffffc02008c0 <default_alloc_pages+0x7e>
            struct Page *p = page + n;
ffffffffc0200894:	00261693          	slli	a3,a2,0x2
ffffffffc0200898:	96b2                	add	a3,a3,a2
ffffffffc020089a:	068e                	slli	a3,a3,0x3
ffffffffc020089c:	96aa                	add	a3,a3,a0
            SetPageProperty(p);
ffffffffc020089e:	6690                	ld	a2,8(a3)
            p->property = page->property - n;
ffffffffc02008a0:	41c7073b          	subw	a4,a4,t3
ffffffffc02008a4:	ca98                	sw	a4,16(a3)
            SetPageProperty(p);
ffffffffc02008a6:	00266713          	ori	a4,a2,2
ffffffffc02008aa:	e698                	sd	a4,8(a3)
            list_add(prev, &(p->page_link));
ffffffffc02008ac:	01868713          	addi	a4,a3,24
    prev->next = next->prev = elm;
ffffffffc02008b0:	00e8b023          	sd	a4,0(a7)
ffffffffc02008b4:	00e33423          	sd	a4,8(t1)
    elm->next = next;
ffffffffc02008b8:	0316b023          	sd	a7,32(a3)
    elm->prev = prev;
ffffffffc02008bc:	0066bc23          	sd	t1,24(a3)
        ClearPageProperty(page);
ffffffffc02008c0:	ff07b703          	ld	a4,-16(a5)
        nr_free -= n;
ffffffffc02008c4:	41c8083b          	subw	a6,a6,t3
ffffffffc02008c8:	0105a823          	sw	a6,16(a1)
        ClearPageProperty(page);
ffffffffc02008cc:	9b75                	andi	a4,a4,-3
ffffffffc02008ce:	fee7b823          	sd	a4,-16(a5)
ffffffffc02008d2:	8082                	ret
default_alloc_pages(size_t n) {
ffffffffc02008d4:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc02008d6:	00001697          	auipc	a3,0x1
ffffffffc02008da:	2ca68693          	addi	a3,a3,714 # ffffffffc0201ba0 <etext+0x41c>
ffffffffc02008de:	00001617          	auipc	a2,0x1
ffffffffc02008e2:	2ca60613          	addi	a2,a2,714 # ffffffffc0201ba8 <etext+0x424>
ffffffffc02008e6:	02f00593          	li	a1,47
ffffffffc02008ea:	00001517          	auipc	a0,0x1
ffffffffc02008ee:	2d650513          	addi	a0,a0,726 # ffffffffc0201bc0 <etext+0x43c>
default_alloc_pages(size_t n) {
ffffffffc02008f2:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02008f4:	8cfff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02008f8 <default_check>:
}

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
ffffffffc02008f8:	715d                	addi	sp,sp,-80
ffffffffc02008fa:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc02008fc:	00005417          	auipc	s0,0x5
ffffffffc0200900:	71c40413          	addi	s0,s0,1820 # ffffffffc0206018 <free_area>
ffffffffc0200904:	641c                	ld	a5,8(s0)
ffffffffc0200906:	e486                	sd	ra,72(sp)
ffffffffc0200908:	fc26                	sd	s1,56(sp)
ffffffffc020090a:	f84a                	sd	s2,48(sp)
ffffffffc020090c:	f44e                	sd	s3,40(sp)
ffffffffc020090e:	f052                	sd	s4,32(sp)
ffffffffc0200910:	ec56                	sd	s5,24(sp)
ffffffffc0200912:	e85a                	sd	s6,16(sp)
ffffffffc0200914:	e45e                	sd	s7,8(sp)
ffffffffc0200916:	e062                	sd	s8,0(sp)
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200918:	2c878363          	beq	a5,s0,ffffffffc0200bde <default_check+0x2e6>
    int count = 0, total = 0;
ffffffffc020091c:	4481                	li	s1,0
ffffffffc020091e:	4901                	li	s2,0
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc0200920:	ff07b703          	ld	a4,-16(a5)
ffffffffc0200924:	8b09                	andi	a4,a4,2
ffffffffc0200926:	2c070063          	beqz	a4,ffffffffc0200be6 <default_check+0x2ee>
        count ++, total += p->property;
ffffffffc020092a:	ff87a703          	lw	a4,-8(a5)
ffffffffc020092e:	679c                	ld	a5,8(a5)
ffffffffc0200930:	2905                	addiw	s2,s2,1
ffffffffc0200932:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200934:	fe8796e3          	bne	a5,s0,ffffffffc0200920 <default_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc0200938:	89a6                	mv	s3,s1
ffffffffc020093a:	cafff0ef          	jal	ra,ffffffffc02005e8 <nr_free_pages>
ffffffffc020093e:	71351463          	bne	a0,s3,ffffffffc0201046 <default_check+0x74e>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200942:	4505                	li	a0,1
ffffffffc0200944:	c8dff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200948:	8a2a                	mv	s4,a0
ffffffffc020094a:	42050e63          	beqz	a0,ffffffffc0200d86 <default_check+0x48e>
    assert((p1 = alloc_page()) != NULL);
ffffffffc020094e:	4505                	li	a0,1
ffffffffc0200950:	c81ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200954:	89aa                	mv	s3,a0
ffffffffc0200956:	70050863          	beqz	a0,ffffffffc0201066 <default_check+0x76e>
    assert((p2 = alloc_page()) != NULL);
ffffffffc020095a:	4505                	li	a0,1
ffffffffc020095c:	c75ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200960:	8aaa                	mv	s5,a0
ffffffffc0200962:	4a050263          	beqz	a0,ffffffffc0200e06 <default_check+0x50e>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200966:	2b3a0063          	beq	s4,s3,ffffffffc0200c06 <default_check+0x30e>
ffffffffc020096a:	28aa0e63          	beq	s4,a0,ffffffffc0200c06 <default_check+0x30e>
ffffffffc020096e:	28a98c63          	beq	s3,a0,ffffffffc0200c06 <default_check+0x30e>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200972:	000a2783          	lw	a5,0(s4)
ffffffffc0200976:	2a079863          	bnez	a5,ffffffffc0200c26 <default_check+0x32e>
ffffffffc020097a:	0009a783          	lw	a5,0(s3)
ffffffffc020097e:	2a079463          	bnez	a5,ffffffffc0200c26 <default_check+0x32e>
ffffffffc0200982:	411c                	lw	a5,0(a0)
ffffffffc0200984:	2a079163          	bnez	a5,ffffffffc0200c26 <default_check+0x32e>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200988:	00005797          	auipc	a5,0x5
ffffffffc020098c:	6c87b783          	ld	a5,1736(a5) # ffffffffc0206050 <pages>
ffffffffc0200990:	40fa0733          	sub	a4,s4,a5
ffffffffc0200994:	870d                	srai	a4,a4,0x3
ffffffffc0200996:	00002597          	auipc	a1,0x2
ffffffffc020099a:	8525b583          	ld	a1,-1966(a1) # ffffffffc02021e8 <nbase+0x8>
ffffffffc020099e:	02b70733          	mul	a4,a4,a1
ffffffffc02009a2:	00002617          	auipc	a2,0x2
ffffffffc02009a6:	83e63603          	ld	a2,-1986(a2) # ffffffffc02021e0 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc02009aa:	00005697          	auipc	a3,0x5
ffffffffc02009ae:	69e6b683          	ld	a3,1694(a3) # ffffffffc0206048 <npage>
ffffffffc02009b2:	06b2                	slli	a3,a3,0xc
ffffffffc02009b4:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009b6:	0732                	slli	a4,a4,0xc
ffffffffc02009b8:	28d77763          	bgeu	a4,a3,ffffffffc0200c46 <default_check+0x34e>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009bc:	40f98733          	sub	a4,s3,a5
ffffffffc02009c0:	870d                	srai	a4,a4,0x3
ffffffffc02009c2:	02b70733          	mul	a4,a4,a1
ffffffffc02009c6:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009c8:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc02009ca:	4ad77e63          	bgeu	a4,a3,ffffffffc0200e86 <default_check+0x58e>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc02009ce:	40f507b3          	sub	a5,a0,a5
ffffffffc02009d2:	878d                	srai	a5,a5,0x3
ffffffffc02009d4:	02b787b3          	mul	a5,a5,a1
ffffffffc02009d8:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc02009da:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc02009dc:	30d7f563          	bgeu	a5,a3,ffffffffc0200ce6 <default_check+0x3ee>
    assert(alloc_page() == NULL);
ffffffffc02009e0:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc02009e2:	00043c03          	ld	s8,0(s0)
ffffffffc02009e6:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc02009ea:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc02009ee:	e400                	sd	s0,8(s0)
ffffffffc02009f0:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc02009f2:	00005797          	auipc	a5,0x5
ffffffffc02009f6:	6207ab23          	sw	zero,1590(a5) # ffffffffc0206028 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc02009fa:	bd7ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc02009fe:	2c051463          	bnez	a0,ffffffffc0200cc6 <default_check+0x3ce>
    free_page(p0);
ffffffffc0200a02:	4585                	li	a1,1
ffffffffc0200a04:	8552                	mv	a0,s4
ffffffffc0200a06:	bd7ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p1);
ffffffffc0200a0a:	4585                	li	a1,1
ffffffffc0200a0c:	854e                	mv	a0,s3
ffffffffc0200a0e:	bcfff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p2);
ffffffffc0200a12:	4585                	li	a1,1
ffffffffc0200a14:	8556                	mv	a0,s5
ffffffffc0200a16:	bc7ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(nr_free == 3);
ffffffffc0200a1a:	4818                	lw	a4,16(s0)
ffffffffc0200a1c:	478d                	li	a5,3
ffffffffc0200a1e:	28f71463          	bne	a4,a5,ffffffffc0200ca6 <default_check+0x3ae>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200a22:	4505                	li	a0,1
ffffffffc0200a24:	badff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a28:	89aa                	mv	s3,a0
ffffffffc0200a2a:	24050e63          	beqz	a0,ffffffffc0200c86 <default_check+0x38e>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200a2e:	4505                	li	a0,1
ffffffffc0200a30:	ba1ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a34:	8aaa                	mv	s5,a0
ffffffffc0200a36:	3a050863          	beqz	a0,ffffffffc0200de6 <default_check+0x4ee>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200a3a:	4505                	li	a0,1
ffffffffc0200a3c:	b95ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a40:	8a2a                	mv	s4,a0
ffffffffc0200a42:	38050263          	beqz	a0,ffffffffc0200dc6 <default_check+0x4ce>
    assert(alloc_page() == NULL);
ffffffffc0200a46:	4505                	li	a0,1
ffffffffc0200a48:	b89ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a4c:	34051d63          	bnez	a0,ffffffffc0200da6 <default_check+0x4ae>
    free_page(p0);
ffffffffc0200a50:	4585                	li	a1,1
ffffffffc0200a52:	854e                	mv	a0,s3
ffffffffc0200a54:	b89ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200a58:	641c                	ld	a5,8(s0)
ffffffffc0200a5a:	20878663          	beq	a5,s0,ffffffffc0200c66 <default_check+0x36e>
    assert((p = alloc_page()) == p0);
ffffffffc0200a5e:	4505                	li	a0,1
ffffffffc0200a60:	b71ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a64:	30a99163          	bne	s3,a0,ffffffffc0200d66 <default_check+0x46e>
    assert(alloc_page() == NULL);
ffffffffc0200a68:	4505                	li	a0,1
ffffffffc0200a6a:	b67ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200a6e:	2c051c63          	bnez	a0,ffffffffc0200d46 <default_check+0x44e>
    assert(nr_free == 0);
ffffffffc0200a72:	481c                	lw	a5,16(s0)
ffffffffc0200a74:	2a079963          	bnez	a5,ffffffffc0200d26 <default_check+0x42e>
    free_page(p);
ffffffffc0200a78:	854e                	mv	a0,s3
ffffffffc0200a7a:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200a7c:	01843023          	sd	s8,0(s0)
ffffffffc0200a80:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc0200a84:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200a88:	b55ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p1);
ffffffffc0200a8c:	4585                	li	a1,1
ffffffffc0200a8e:	8556                	mv	a0,s5
ffffffffc0200a90:	b4dff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p2);
ffffffffc0200a94:	4585                	li	a1,1
ffffffffc0200a96:	8552                	mv	a0,s4
ffffffffc0200a98:	b45ff0ef          	jal	ra,ffffffffc02005dc <free_pages>

    basic_check();

    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200a9c:	4515                	li	a0,5
ffffffffc0200a9e:	b33ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200aa2:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0200aa4:	26050163          	beqz	a0,ffffffffc0200d06 <default_check+0x40e>
    assert(!PageProperty(p0));
ffffffffc0200aa8:	651c                	ld	a5,8(a0)
ffffffffc0200aaa:	8b89                	andi	a5,a5,2
ffffffffc0200aac:	52079d63          	bnez	a5,ffffffffc0200fe6 <default_check+0x6ee>

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200ab0:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200ab2:	00043b83          	ld	s7,0(s0)
ffffffffc0200ab6:	00843b03          	ld	s6,8(s0)
ffffffffc0200aba:	e000                	sd	s0,0(s0)
ffffffffc0200abc:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200abe:	b13ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200ac2:	50051263          	bnez	a0,ffffffffc0200fc6 <default_check+0x6ce>

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    free_pages(p0 + 2, 3);
ffffffffc0200ac6:	05098a13          	addi	s4,s3,80
ffffffffc0200aca:	8552                	mv	a0,s4
ffffffffc0200acc:	458d                	li	a1,3
    unsigned int nr_free_store = nr_free;
ffffffffc0200ace:	01042c03          	lw	s8,16(s0)
    nr_free = 0;
ffffffffc0200ad2:	00005797          	auipc	a5,0x5
ffffffffc0200ad6:	5407ab23          	sw	zero,1366(a5) # ffffffffc0206028 <free_area+0x10>
    free_pages(p0 + 2, 3);
ffffffffc0200ada:	b03ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200ade:	4511                	li	a0,4
ffffffffc0200ae0:	af1ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200ae4:	4c051163          	bnez	a0,ffffffffc0200fa6 <default_check+0x6ae>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0200ae8:	0589b783          	ld	a5,88(s3)
ffffffffc0200aec:	8b89                	andi	a5,a5,2
ffffffffc0200aee:	48078c63          	beqz	a5,ffffffffc0200f86 <default_check+0x68e>
ffffffffc0200af2:	0609a703          	lw	a4,96(s3)
ffffffffc0200af6:	478d                	li	a5,3
ffffffffc0200af8:	48f71763          	bne	a4,a5,ffffffffc0200f86 <default_check+0x68e>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc0200afc:	450d                	li	a0,3
ffffffffc0200afe:	ad3ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b02:	8aaa                	mv	s5,a0
ffffffffc0200b04:	46050163          	beqz	a0,ffffffffc0200f66 <default_check+0x66e>
    assert(alloc_page() == NULL);
ffffffffc0200b08:	4505                	li	a0,1
ffffffffc0200b0a:	ac7ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b0e:	42051c63          	bnez	a0,ffffffffc0200f46 <default_check+0x64e>
    assert(p0 + 2 == p1);
ffffffffc0200b12:	415a1a63          	bne	s4,s5,ffffffffc0200f26 <default_check+0x62e>

    p2 = p0 + 1;
    free_page(p0);
ffffffffc0200b16:	4585                	li	a1,1
ffffffffc0200b18:	854e                	mv	a0,s3
ffffffffc0200b1a:	ac3ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_pages(p1, 3);
ffffffffc0200b1e:	458d                	li	a1,3
ffffffffc0200b20:	8552                	mv	a0,s4
ffffffffc0200b22:	abbff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc0200b26:	0089b783          	ld	a5,8(s3)
    p2 = p0 + 1;
ffffffffc0200b2a:	02898a93          	addi	s5,s3,40
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc0200b2e:	8b89                	andi	a5,a5,2
ffffffffc0200b30:	3c078b63          	beqz	a5,ffffffffc0200f06 <default_check+0x60e>
ffffffffc0200b34:	0109a703          	lw	a4,16(s3)
ffffffffc0200b38:	4785                	li	a5,1
ffffffffc0200b3a:	3cf71663          	bne	a4,a5,ffffffffc0200f06 <default_check+0x60e>
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc0200b3e:	008a3783          	ld	a5,8(s4)
ffffffffc0200b42:	8b89                	andi	a5,a5,2
ffffffffc0200b44:	3a078163          	beqz	a5,ffffffffc0200ee6 <default_check+0x5ee>
ffffffffc0200b48:	010a2703          	lw	a4,16(s4)
ffffffffc0200b4c:	478d                	li	a5,3
ffffffffc0200b4e:	38f71c63          	bne	a4,a5,ffffffffc0200ee6 <default_check+0x5ee>

    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc0200b52:	4505                	li	a0,1
ffffffffc0200b54:	a7dff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b58:	36a99763          	bne	s3,a0,ffffffffc0200ec6 <default_check+0x5ce>
    free_page(p0);
ffffffffc0200b5c:	4585                	li	a1,1
ffffffffc0200b5e:	a7fff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc0200b62:	4509                	li	a0,2
ffffffffc0200b64:	a6dff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b68:	32aa1f63          	bne	s4,a0,ffffffffc0200ea6 <default_check+0x5ae>

    free_pages(p0, 2);
ffffffffc0200b6c:	4589                	li	a1,2
ffffffffc0200b6e:	a6fff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    free_page(p2);
ffffffffc0200b72:	4585                	li	a1,1
ffffffffc0200b74:	8556                	mv	a0,s5
ffffffffc0200b76:	a67ff0ef          	jal	ra,ffffffffc02005dc <free_pages>

    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200b7a:	4515                	li	a0,5
ffffffffc0200b7c:	a55ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b80:	89aa                	mv	s3,a0
ffffffffc0200b82:	48050263          	beqz	a0,ffffffffc0201006 <default_check+0x70e>
    assert(alloc_page() == NULL);
ffffffffc0200b86:	4505                	li	a0,1
ffffffffc0200b88:	a49ff0ef          	jal	ra,ffffffffc02005d0 <alloc_pages>
ffffffffc0200b8c:	2c051d63          	bnez	a0,ffffffffc0200e66 <default_check+0x56e>

    assert(nr_free == 0);
ffffffffc0200b90:	481c                	lw	a5,16(s0)
ffffffffc0200b92:	2a079a63          	bnez	a5,ffffffffc0200e46 <default_check+0x54e>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc0200b96:	4595                	li	a1,5
ffffffffc0200b98:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc0200b9a:	01842823          	sw	s8,16(s0)
    free_list = free_list_store;
ffffffffc0200b9e:	01743023          	sd	s7,0(s0)
ffffffffc0200ba2:	01643423          	sd	s6,8(s0)
    free_pages(p0, 5);
ffffffffc0200ba6:	a37ff0ef          	jal	ra,ffffffffc02005dc <free_pages>
    return listelm->next;
ffffffffc0200baa:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200bac:	00878963          	beq	a5,s0,ffffffffc0200bbe <default_check+0x2c6>
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
ffffffffc0200bb0:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200bb4:	679c                	ld	a5,8(a5)
ffffffffc0200bb6:	397d                	addiw	s2,s2,-1
ffffffffc0200bb8:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200bba:	fe879be3          	bne	a5,s0,ffffffffc0200bb0 <default_check+0x2b8>
    }
    assert(count == 0);
ffffffffc0200bbe:	26091463          	bnez	s2,ffffffffc0200e26 <default_check+0x52e>
    assert(total == 0);
ffffffffc0200bc2:	46049263          	bnez	s1,ffffffffc0201026 <default_check+0x72e>
}
ffffffffc0200bc6:	60a6                	ld	ra,72(sp)
ffffffffc0200bc8:	6406                	ld	s0,64(sp)
ffffffffc0200bca:	74e2                	ld	s1,56(sp)
ffffffffc0200bcc:	7942                	ld	s2,48(sp)
ffffffffc0200bce:	79a2                	ld	s3,40(sp)
ffffffffc0200bd0:	7a02                	ld	s4,32(sp)
ffffffffc0200bd2:	6ae2                	ld	s5,24(sp)
ffffffffc0200bd4:	6b42                	ld	s6,16(sp)
ffffffffc0200bd6:	6ba2                	ld	s7,8(sp)
ffffffffc0200bd8:	6c02                	ld	s8,0(sp)
ffffffffc0200bda:	6161                	addi	sp,sp,80
ffffffffc0200bdc:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200bde:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200be0:	4481                	li	s1,0
ffffffffc0200be2:	4901                	li	s2,0
ffffffffc0200be4:	bb99                	j	ffffffffc020093a <default_check+0x42>
        assert(PageProperty(p));
ffffffffc0200be6:	00001697          	auipc	a3,0x1
ffffffffc0200bea:	ff268693          	addi	a3,a3,-14 # ffffffffc0201bd8 <etext+0x454>
ffffffffc0200bee:	00001617          	auipc	a2,0x1
ffffffffc0200bf2:	fba60613          	addi	a2,a2,-70 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200bf6:	0bd00593          	li	a1,189
ffffffffc0200bfa:	00001517          	auipc	a0,0x1
ffffffffc0200bfe:	fc650513          	addi	a0,a0,-58 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200c02:	dc0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200c06:	00001697          	auipc	a3,0x1
ffffffffc0200c0a:	06268693          	addi	a3,a3,98 # ffffffffc0201c68 <etext+0x4e4>
ffffffffc0200c0e:	00001617          	auipc	a2,0x1
ffffffffc0200c12:	f9a60613          	addi	a2,a2,-102 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200c16:	08a00593          	li	a1,138
ffffffffc0200c1a:	00001517          	auipc	a0,0x1
ffffffffc0200c1e:	fa650513          	addi	a0,a0,-90 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200c22:	da0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200c26:	00001697          	auipc	a3,0x1
ffffffffc0200c2a:	06a68693          	addi	a3,a3,106 # ffffffffc0201c90 <etext+0x50c>
ffffffffc0200c2e:	00001617          	auipc	a2,0x1
ffffffffc0200c32:	f7a60613          	addi	a2,a2,-134 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200c36:	08b00593          	li	a1,139
ffffffffc0200c3a:	00001517          	auipc	a0,0x1
ffffffffc0200c3e:	f8650513          	addi	a0,a0,-122 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200c42:	d80ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200c46:	00001697          	auipc	a3,0x1
ffffffffc0200c4a:	08a68693          	addi	a3,a3,138 # ffffffffc0201cd0 <etext+0x54c>
ffffffffc0200c4e:	00001617          	auipc	a2,0x1
ffffffffc0200c52:	f5a60613          	addi	a2,a2,-166 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200c56:	08d00593          	li	a1,141
ffffffffc0200c5a:	00001517          	auipc	a0,0x1
ffffffffc0200c5e:	f6650513          	addi	a0,a0,-154 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200c62:	d60ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0200c66:	00001697          	auipc	a3,0x1
ffffffffc0200c6a:	0f268693          	addi	a3,a3,242 # ffffffffc0201d58 <etext+0x5d4>
ffffffffc0200c6e:	00001617          	auipc	a2,0x1
ffffffffc0200c72:	f3a60613          	addi	a2,a2,-198 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200c76:	0a600593          	li	a1,166
ffffffffc0200c7a:	00001517          	auipc	a0,0x1
ffffffffc0200c7e:	f4650513          	addi	a0,a0,-186 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200c82:	d40ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200c86:	00001697          	auipc	a3,0x1
ffffffffc0200c8a:	f8268693          	addi	a3,a3,-126 # ffffffffc0201c08 <etext+0x484>
ffffffffc0200c8e:	00001617          	auipc	a2,0x1
ffffffffc0200c92:	f1a60613          	addi	a2,a2,-230 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200c96:	09f00593          	li	a1,159
ffffffffc0200c9a:	00001517          	auipc	a0,0x1
ffffffffc0200c9e:	f2650513          	addi	a0,a0,-218 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200ca2:	d20ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 3);
ffffffffc0200ca6:	00001697          	auipc	a3,0x1
ffffffffc0200caa:	0a268693          	addi	a3,a3,162 # ffffffffc0201d48 <etext+0x5c4>
ffffffffc0200cae:	00001617          	auipc	a2,0x1
ffffffffc0200cb2:	efa60613          	addi	a2,a2,-262 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200cb6:	09d00593          	li	a1,157
ffffffffc0200cba:	00001517          	auipc	a0,0x1
ffffffffc0200cbe:	f0650513          	addi	a0,a0,-250 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200cc2:	d00ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200cc6:	00001697          	auipc	a3,0x1
ffffffffc0200cca:	06a68693          	addi	a3,a3,106 # ffffffffc0201d30 <etext+0x5ac>
ffffffffc0200cce:	00001617          	auipc	a2,0x1
ffffffffc0200cd2:	eda60613          	addi	a2,a2,-294 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200cd6:	09800593          	li	a1,152
ffffffffc0200cda:	00001517          	auipc	a0,0x1
ffffffffc0200cde:	ee650513          	addi	a0,a0,-282 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200ce2:	ce0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200ce6:	00001697          	auipc	a3,0x1
ffffffffc0200cea:	02a68693          	addi	a3,a3,42 # ffffffffc0201d10 <etext+0x58c>
ffffffffc0200cee:	00001617          	auipc	a2,0x1
ffffffffc0200cf2:	eba60613          	addi	a2,a2,-326 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200cf6:	08f00593          	li	a1,143
ffffffffc0200cfa:	00001517          	auipc	a0,0x1
ffffffffc0200cfe:	ec650513          	addi	a0,a0,-314 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200d02:	cc0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != NULL);
ffffffffc0200d06:	00001697          	auipc	a3,0x1
ffffffffc0200d0a:	09a68693          	addi	a3,a3,154 # ffffffffc0201da0 <etext+0x61c>
ffffffffc0200d0e:	00001617          	auipc	a2,0x1
ffffffffc0200d12:	e9a60613          	addi	a2,a2,-358 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200d16:	0c500593          	li	a1,197
ffffffffc0200d1a:	00001517          	auipc	a0,0x1
ffffffffc0200d1e:	ea650513          	addi	a0,a0,-346 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200d22:	ca0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200d26:	00001697          	auipc	a3,0x1
ffffffffc0200d2a:	06a68693          	addi	a3,a3,106 # ffffffffc0201d90 <etext+0x60c>
ffffffffc0200d2e:	00001617          	auipc	a2,0x1
ffffffffc0200d32:	e7a60613          	addi	a2,a2,-390 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200d36:	0ac00593          	li	a1,172
ffffffffc0200d3a:	00001517          	auipc	a0,0x1
ffffffffc0200d3e:	e8650513          	addi	a0,a0,-378 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200d42:	c80ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200d46:	00001697          	auipc	a3,0x1
ffffffffc0200d4a:	fea68693          	addi	a3,a3,-22 # ffffffffc0201d30 <etext+0x5ac>
ffffffffc0200d4e:	00001617          	auipc	a2,0x1
ffffffffc0200d52:	e5a60613          	addi	a2,a2,-422 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200d56:	0aa00593          	li	a1,170
ffffffffc0200d5a:	00001517          	auipc	a0,0x1
ffffffffc0200d5e:	e6650513          	addi	a0,a0,-410 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200d62:	c60ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc0200d66:	00001697          	auipc	a3,0x1
ffffffffc0200d6a:	00a68693          	addi	a3,a3,10 # ffffffffc0201d70 <etext+0x5ec>
ffffffffc0200d6e:	00001617          	auipc	a2,0x1
ffffffffc0200d72:	e3a60613          	addi	a2,a2,-454 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200d76:	0a900593          	li	a1,169
ffffffffc0200d7a:	00001517          	auipc	a0,0x1
ffffffffc0200d7e:	e4650513          	addi	a0,a0,-442 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200d82:	c40ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200d86:	00001697          	auipc	a3,0x1
ffffffffc0200d8a:	e8268693          	addi	a3,a3,-382 # ffffffffc0201c08 <etext+0x484>
ffffffffc0200d8e:	00001617          	auipc	a2,0x1
ffffffffc0200d92:	e1a60613          	addi	a2,a2,-486 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200d96:	08600593          	li	a1,134
ffffffffc0200d9a:	00001517          	auipc	a0,0x1
ffffffffc0200d9e:	e2650513          	addi	a0,a0,-474 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200da2:	c20ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200da6:	00001697          	auipc	a3,0x1
ffffffffc0200daa:	f8a68693          	addi	a3,a3,-118 # ffffffffc0201d30 <etext+0x5ac>
ffffffffc0200dae:	00001617          	auipc	a2,0x1
ffffffffc0200db2:	dfa60613          	addi	a2,a2,-518 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200db6:	0a300593          	li	a1,163
ffffffffc0200dba:	00001517          	auipc	a0,0x1
ffffffffc0200dbe:	e0650513          	addi	a0,a0,-506 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200dc2:	c00ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200dc6:	00001697          	auipc	a3,0x1
ffffffffc0200dca:	e8268693          	addi	a3,a3,-382 # ffffffffc0201c48 <etext+0x4c4>
ffffffffc0200dce:	00001617          	auipc	a2,0x1
ffffffffc0200dd2:	dda60613          	addi	a2,a2,-550 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200dd6:	0a100593          	li	a1,161
ffffffffc0200dda:	00001517          	auipc	a0,0x1
ffffffffc0200dde:	de650513          	addi	a0,a0,-538 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200de2:	be0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200de6:	00001697          	auipc	a3,0x1
ffffffffc0200dea:	e4268693          	addi	a3,a3,-446 # ffffffffc0201c28 <etext+0x4a4>
ffffffffc0200dee:	00001617          	auipc	a2,0x1
ffffffffc0200df2:	dba60613          	addi	a2,a2,-582 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200df6:	0a000593          	li	a1,160
ffffffffc0200dfa:	00001517          	auipc	a0,0x1
ffffffffc0200dfe:	dc650513          	addi	a0,a0,-570 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200e02:	bc0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200e06:	00001697          	auipc	a3,0x1
ffffffffc0200e0a:	e4268693          	addi	a3,a3,-446 # ffffffffc0201c48 <etext+0x4c4>
ffffffffc0200e0e:	00001617          	auipc	a2,0x1
ffffffffc0200e12:	d9a60613          	addi	a2,a2,-614 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200e16:	08800593          	li	a1,136
ffffffffc0200e1a:	00001517          	auipc	a0,0x1
ffffffffc0200e1e:	da650513          	addi	a0,a0,-602 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200e22:	ba0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(count == 0);
ffffffffc0200e26:	00001697          	auipc	a3,0x1
ffffffffc0200e2a:	0ca68693          	addi	a3,a3,202 # ffffffffc0201ef0 <etext+0x76c>
ffffffffc0200e2e:	00001617          	auipc	a2,0x1
ffffffffc0200e32:	d7a60613          	addi	a2,a2,-646 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200e36:	0f200593          	li	a1,242
ffffffffc0200e3a:	00001517          	auipc	a0,0x1
ffffffffc0200e3e:	d8650513          	addi	a0,a0,-634 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200e42:	b80ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == 0);
ffffffffc0200e46:	00001697          	auipc	a3,0x1
ffffffffc0200e4a:	f4a68693          	addi	a3,a3,-182 # ffffffffc0201d90 <etext+0x60c>
ffffffffc0200e4e:	00001617          	auipc	a2,0x1
ffffffffc0200e52:	d5a60613          	addi	a2,a2,-678 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200e56:	0e700593          	li	a1,231
ffffffffc0200e5a:	00001517          	auipc	a0,0x1
ffffffffc0200e5e:	d6650513          	addi	a0,a0,-666 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200e62:	b60ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200e66:	00001697          	auipc	a3,0x1
ffffffffc0200e6a:	eca68693          	addi	a3,a3,-310 # ffffffffc0201d30 <etext+0x5ac>
ffffffffc0200e6e:	00001617          	auipc	a2,0x1
ffffffffc0200e72:	d3a60613          	addi	a2,a2,-710 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200e76:	0e500593          	li	a1,229
ffffffffc0200e7a:	00001517          	auipc	a0,0x1
ffffffffc0200e7e:	d4650513          	addi	a0,a0,-698 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200e82:	b40ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200e86:	00001697          	auipc	a3,0x1
ffffffffc0200e8a:	e6a68693          	addi	a3,a3,-406 # ffffffffc0201cf0 <etext+0x56c>
ffffffffc0200e8e:	00001617          	auipc	a2,0x1
ffffffffc0200e92:	d1a60613          	addi	a2,a2,-742 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200e96:	08e00593          	li	a1,142
ffffffffc0200e9a:	00001517          	auipc	a0,0x1
ffffffffc0200e9e:	d2650513          	addi	a0,a0,-730 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200ea2:	b20ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc0200ea6:	00001697          	auipc	a3,0x1
ffffffffc0200eaa:	00a68693          	addi	a3,a3,10 # ffffffffc0201eb0 <etext+0x72c>
ffffffffc0200eae:	00001617          	auipc	a2,0x1
ffffffffc0200eb2:	cfa60613          	addi	a2,a2,-774 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200eb6:	0df00593          	li	a1,223
ffffffffc0200eba:	00001517          	auipc	a0,0x1
ffffffffc0200ebe:	d0650513          	addi	a0,a0,-762 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200ec2:	b00ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc0200ec6:	00001697          	auipc	a3,0x1
ffffffffc0200eca:	fca68693          	addi	a3,a3,-54 # ffffffffc0201e90 <etext+0x70c>
ffffffffc0200ece:	00001617          	auipc	a2,0x1
ffffffffc0200ed2:	cda60613          	addi	a2,a2,-806 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200ed6:	0dd00593          	li	a1,221
ffffffffc0200eda:	00001517          	auipc	a0,0x1
ffffffffc0200ede:	ce650513          	addi	a0,a0,-794 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200ee2:	ae0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc0200ee6:	00001697          	auipc	a3,0x1
ffffffffc0200eea:	f8268693          	addi	a3,a3,-126 # ffffffffc0201e68 <etext+0x6e4>
ffffffffc0200eee:	00001617          	auipc	a2,0x1
ffffffffc0200ef2:	cba60613          	addi	a2,a2,-838 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200ef6:	0db00593          	li	a1,219
ffffffffc0200efa:	00001517          	auipc	a0,0x1
ffffffffc0200efe:	cc650513          	addi	a0,a0,-826 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200f02:	ac0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc0200f06:	00001697          	auipc	a3,0x1
ffffffffc0200f0a:	f3a68693          	addi	a3,a3,-198 # ffffffffc0201e40 <etext+0x6bc>
ffffffffc0200f0e:	00001617          	auipc	a2,0x1
ffffffffc0200f12:	c9a60613          	addi	a2,a2,-870 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200f16:	0da00593          	li	a1,218
ffffffffc0200f1a:	00001517          	auipc	a0,0x1
ffffffffc0200f1e:	ca650513          	addi	a0,a0,-858 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200f22:	aa0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 + 2 == p1);
ffffffffc0200f26:	00001697          	auipc	a3,0x1
ffffffffc0200f2a:	f0a68693          	addi	a3,a3,-246 # ffffffffc0201e30 <etext+0x6ac>
ffffffffc0200f2e:	00001617          	auipc	a2,0x1
ffffffffc0200f32:	c7a60613          	addi	a2,a2,-902 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200f36:	0d500593          	li	a1,213
ffffffffc0200f3a:	00001517          	auipc	a0,0x1
ffffffffc0200f3e:	c8650513          	addi	a0,a0,-890 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200f42:	a80ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200f46:	00001697          	auipc	a3,0x1
ffffffffc0200f4a:	dea68693          	addi	a3,a3,-534 # ffffffffc0201d30 <etext+0x5ac>
ffffffffc0200f4e:	00001617          	auipc	a2,0x1
ffffffffc0200f52:	c5a60613          	addi	a2,a2,-934 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200f56:	0d400593          	li	a1,212
ffffffffc0200f5a:	00001517          	auipc	a0,0x1
ffffffffc0200f5e:	c6650513          	addi	a0,a0,-922 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200f62:	a60ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc0200f66:	00001697          	auipc	a3,0x1
ffffffffc0200f6a:	eaa68693          	addi	a3,a3,-342 # ffffffffc0201e10 <etext+0x68c>
ffffffffc0200f6e:	00001617          	auipc	a2,0x1
ffffffffc0200f72:	c3a60613          	addi	a2,a2,-966 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200f76:	0d300593          	li	a1,211
ffffffffc0200f7a:	00001517          	auipc	a0,0x1
ffffffffc0200f7e:	c4650513          	addi	a0,a0,-954 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200f82:	a40ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0200f86:	00001697          	auipc	a3,0x1
ffffffffc0200f8a:	e5a68693          	addi	a3,a3,-422 # ffffffffc0201de0 <etext+0x65c>
ffffffffc0200f8e:	00001617          	auipc	a2,0x1
ffffffffc0200f92:	c1a60613          	addi	a2,a2,-998 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200f96:	0d200593          	li	a1,210
ffffffffc0200f9a:	00001517          	auipc	a0,0x1
ffffffffc0200f9e:	c2650513          	addi	a0,a0,-986 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200fa2:	a20ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc0200fa6:	00001697          	auipc	a3,0x1
ffffffffc0200faa:	e2268693          	addi	a3,a3,-478 # ffffffffc0201dc8 <etext+0x644>
ffffffffc0200fae:	00001617          	auipc	a2,0x1
ffffffffc0200fb2:	bfa60613          	addi	a2,a2,-1030 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200fb6:	0d100593          	li	a1,209
ffffffffc0200fba:	00001517          	auipc	a0,0x1
ffffffffc0200fbe:	c0650513          	addi	a0,a0,-1018 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200fc2:	a00ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc0200fc6:	00001697          	auipc	a3,0x1
ffffffffc0200fca:	d6a68693          	addi	a3,a3,-662 # ffffffffc0201d30 <etext+0x5ac>
ffffffffc0200fce:	00001617          	auipc	a2,0x1
ffffffffc0200fd2:	bda60613          	addi	a2,a2,-1062 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200fd6:	0cb00593          	li	a1,203
ffffffffc0200fda:	00001517          	auipc	a0,0x1
ffffffffc0200fde:	be650513          	addi	a0,a0,-1050 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0200fe2:	9e0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p0));
ffffffffc0200fe6:	00001697          	auipc	a3,0x1
ffffffffc0200fea:	dca68693          	addi	a3,a3,-566 # ffffffffc0201db0 <etext+0x62c>
ffffffffc0200fee:	00001617          	auipc	a2,0x1
ffffffffc0200ff2:	bba60613          	addi	a2,a2,-1094 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0200ff6:	0c600593          	li	a1,198
ffffffffc0200ffa:	00001517          	auipc	a0,0x1
ffffffffc0200ffe:	bc650513          	addi	a0,a0,-1082 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0201002:	9c0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0201006:	00001697          	auipc	a3,0x1
ffffffffc020100a:	eca68693          	addi	a3,a3,-310 # ffffffffc0201ed0 <etext+0x74c>
ffffffffc020100e:	00001617          	auipc	a2,0x1
ffffffffc0201012:	b9a60613          	addi	a2,a2,-1126 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0201016:	0e400593          	li	a1,228
ffffffffc020101a:	00001517          	auipc	a0,0x1
ffffffffc020101e:	ba650513          	addi	a0,a0,-1114 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0201022:	9a0ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == 0);
ffffffffc0201026:	00001697          	auipc	a3,0x1
ffffffffc020102a:	eda68693          	addi	a3,a3,-294 # ffffffffc0201f00 <etext+0x77c>
ffffffffc020102e:	00001617          	auipc	a2,0x1
ffffffffc0201032:	b7a60613          	addi	a2,a2,-1158 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0201036:	0f300593          	li	a1,243
ffffffffc020103a:	00001517          	auipc	a0,0x1
ffffffffc020103e:	b8650513          	addi	a0,a0,-1146 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0201042:	980ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(total == nr_free_pages());
ffffffffc0201046:	00001697          	auipc	a3,0x1
ffffffffc020104a:	ba268693          	addi	a3,a3,-1118 # ffffffffc0201be8 <etext+0x464>
ffffffffc020104e:	00001617          	auipc	a2,0x1
ffffffffc0201052:	b5a60613          	addi	a2,a2,-1190 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0201056:	0c000593          	li	a1,192
ffffffffc020105a:	00001517          	auipc	a0,0x1
ffffffffc020105e:	b6650513          	addi	a0,a0,-1178 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0201062:	960ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0201066:	00001697          	auipc	a3,0x1
ffffffffc020106a:	bc268693          	addi	a3,a3,-1086 # ffffffffc0201c28 <etext+0x4a4>
ffffffffc020106e:	00001617          	auipc	a2,0x1
ffffffffc0201072:	b3a60613          	addi	a2,a2,-1222 # ffffffffc0201ba8 <etext+0x424>
ffffffffc0201076:	08700593          	li	a1,135
ffffffffc020107a:	00001517          	auipc	a0,0x1
ffffffffc020107e:	b4650513          	addi	a0,a0,-1210 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc0201082:	940ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0201086 <default_free_pages>:
default_free_pages(struct Page *base, size_t n) {
ffffffffc0201086:	1141                	addi	sp,sp,-16
ffffffffc0201088:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020108a:	14058c63          	beqz	a1,ffffffffc02011e2 <default_free_pages+0x15c>
    for (; p != base + n; p ++) {
ffffffffc020108e:	00259693          	slli	a3,a1,0x2
ffffffffc0201092:	96ae                	add	a3,a3,a1
ffffffffc0201094:	068e                	slli	a3,a3,0x3
ffffffffc0201096:	96aa                	add	a3,a3,a0
ffffffffc0201098:	87aa                	mv	a5,a0
ffffffffc020109a:	00d50e63          	beq	a0,a3,ffffffffc02010b6 <default_free_pages+0x30>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc020109e:	6798                	ld	a4,8(a5)
ffffffffc02010a0:	8b0d                	andi	a4,a4,3
ffffffffc02010a2:	12071063          	bnez	a4,ffffffffc02011c2 <default_free_pages+0x13c>
        p->flags = 0;
ffffffffc02010a6:	0007b423          	sd	zero,8(a5)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc02010aa:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc02010ae:	02878793          	addi	a5,a5,40
ffffffffc02010b2:	fed796e3          	bne	a5,a3,ffffffffc020109e <default_free_pages+0x18>
    SetPageProperty(base);
ffffffffc02010b6:	00853883          	ld	a7,8(a0)
    nr_free += n;
ffffffffc02010ba:	00005697          	auipc	a3,0x5
ffffffffc02010be:	f5e68693          	addi	a3,a3,-162 # ffffffffc0206018 <free_area>
ffffffffc02010c2:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc02010c4:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc02010c6:	0028e613          	ori	a2,a7,2
    return list->next == list;
ffffffffc02010ca:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc02010cc:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc02010ce:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc02010d0:	9f2d                	addw	a4,a4,a1
ffffffffc02010d2:	ca98                	sw	a4,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc02010d4:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc02010d8:	0ad78b63          	beq	a5,a3,ffffffffc020118e <default_free_pages+0x108>
            struct Page* page = le2page(le, page_link);
ffffffffc02010dc:	fe878713          	addi	a4,a5,-24
ffffffffc02010e0:	0006b303          	ld	t1,0(a3)
    if (list_empty(&free_list)) {
ffffffffc02010e4:	4801                	li	a6,0
            if (base < page) {
ffffffffc02010e6:	00e56a63          	bltu	a0,a4,ffffffffc02010fa <default_free_pages+0x74>
    return listelm->next;
ffffffffc02010ea:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc02010ec:	06d70563          	beq	a4,a3,ffffffffc0201156 <default_free_pages+0xd0>
    for (; p != base + n; p ++) {
ffffffffc02010f0:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc02010f2:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc02010f6:	fee57ae3          	bgeu	a0,a4,ffffffffc02010ea <default_free_pages+0x64>
ffffffffc02010fa:	00080463          	beqz	a6,ffffffffc0201102 <default_free_pages+0x7c>
ffffffffc02010fe:	0066b023          	sd	t1,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc0201102:	0007b803          	ld	a6,0(a5)
    prev->next = next->prev = elm;
ffffffffc0201106:	e390                	sd	a2,0(a5)
ffffffffc0201108:	00c83423          	sd	a2,8(a6)
    elm->next = next;
ffffffffc020110c:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020110e:	01053c23          	sd	a6,24(a0)
    if (le != &free_list) {
ffffffffc0201112:	02d80463          	beq	a6,a3,ffffffffc020113a <default_free_pages+0xb4>
        if (p + p->property == base) {
ffffffffc0201116:	ff882e03          	lw	t3,-8(a6)
        p = le2page(le, page_link);
ffffffffc020111a:	fe880313          	addi	t1,a6,-24
        if (p + p->property == base) {
ffffffffc020111e:	020e1613          	slli	a2,t3,0x20
ffffffffc0201122:	9201                	srli	a2,a2,0x20
ffffffffc0201124:	00261713          	slli	a4,a2,0x2
ffffffffc0201128:	9732                	add	a4,a4,a2
ffffffffc020112a:	070e                	slli	a4,a4,0x3
ffffffffc020112c:	971a                	add	a4,a4,t1
ffffffffc020112e:	02e50e63          	beq	a0,a4,ffffffffc020116a <default_free_pages+0xe4>
    if (le != &free_list) {
ffffffffc0201132:	00d78f63          	beq	a5,a3,ffffffffc0201150 <default_free_pages+0xca>
ffffffffc0201136:	fe878713          	addi	a4,a5,-24
        if (base + base->property == p) {
ffffffffc020113a:	490c                	lw	a1,16(a0)
ffffffffc020113c:	02059613          	slli	a2,a1,0x20
ffffffffc0201140:	9201                	srli	a2,a2,0x20
ffffffffc0201142:	00261693          	slli	a3,a2,0x2
ffffffffc0201146:	96b2                	add	a3,a3,a2
ffffffffc0201148:	068e                	slli	a3,a3,0x3
ffffffffc020114a:	96aa                	add	a3,a3,a0
ffffffffc020114c:	04d70863          	beq	a4,a3,ffffffffc020119c <default_free_pages+0x116>
}
ffffffffc0201150:	60a2                	ld	ra,8(sp)
ffffffffc0201152:	0141                	addi	sp,sp,16
ffffffffc0201154:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc0201156:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201158:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc020115a:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc020115c:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc020115e:	02d70463          	beq	a4,a3,ffffffffc0201186 <default_free_pages+0x100>
    prev->next = next->prev = elm;
ffffffffc0201162:	8332                	mv	t1,a2
ffffffffc0201164:	4805                	li	a6,1
    for (; p != base + n; p ++) {
ffffffffc0201166:	87ba                	mv	a5,a4
ffffffffc0201168:	b769                	j	ffffffffc02010f2 <default_free_pages+0x6c>
            p->property += base->property;
ffffffffc020116a:	01c585bb          	addw	a1,a1,t3
ffffffffc020116e:	feb82c23          	sw	a1,-8(a6)
            ClearPageProperty(base);
ffffffffc0201172:	ffd8f893          	andi	a7,a7,-3
ffffffffc0201176:	01153423          	sd	a7,8(a0)
    prev->next = next;
ffffffffc020117a:	00f83423          	sd	a5,8(a6)
    next->prev = prev;
ffffffffc020117e:	0107b023          	sd	a6,0(a5)
            base = p;
ffffffffc0201182:	851a                	mv	a0,t1
ffffffffc0201184:	b77d                	j	ffffffffc0201132 <default_free_pages+0xac>
        while ((le = list_next(le)) != &free_list) {
ffffffffc0201186:	883e                	mv	a6,a5
ffffffffc0201188:	e290                	sd	a2,0(a3)
ffffffffc020118a:	87b6                	mv	a5,a3
ffffffffc020118c:	b769                	j	ffffffffc0201116 <default_free_pages+0x90>
}
ffffffffc020118e:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0201190:	e390                	sd	a2,0(a5)
ffffffffc0201192:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0201194:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0201196:	ed1c                	sd	a5,24(a0)
ffffffffc0201198:	0141                	addi	sp,sp,16
ffffffffc020119a:	8082                	ret
            base->property += p->property;
ffffffffc020119c:	ff87a683          	lw	a3,-8(a5)
            ClearPageProperty(p);
ffffffffc02011a0:	ff07b703          	ld	a4,-16(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc02011a4:	0007b803          	ld	a6,0(a5)
ffffffffc02011a8:	6790                	ld	a2,8(a5)
            base->property += p->property;
ffffffffc02011aa:	9db5                	addw	a1,a1,a3
ffffffffc02011ac:	c90c                	sw	a1,16(a0)
            ClearPageProperty(p);
ffffffffc02011ae:	9b75                	andi	a4,a4,-3
ffffffffc02011b0:	fee7b823          	sd	a4,-16(a5)
}
ffffffffc02011b4:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc02011b6:	00c83423          	sd	a2,8(a6)
    next->prev = prev;
ffffffffc02011ba:	01063023          	sd	a6,0(a2)
ffffffffc02011be:	0141                	addi	sp,sp,16
ffffffffc02011c0:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02011c2:	00001697          	auipc	a3,0x1
ffffffffc02011c6:	d4e68693          	addi	a3,a3,-690 # ffffffffc0201f10 <etext+0x78c>
ffffffffc02011ca:	00001617          	auipc	a2,0x1
ffffffffc02011ce:	9de60613          	addi	a2,a2,-1570 # ffffffffc0201ba8 <etext+0x424>
ffffffffc02011d2:	05000593          	li	a1,80
ffffffffc02011d6:	00001517          	auipc	a0,0x1
ffffffffc02011da:	9ea50513          	addi	a0,a0,-1558 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc02011de:	fe5fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc02011e2:	00001697          	auipc	a3,0x1
ffffffffc02011e6:	9be68693          	addi	a3,a3,-1602 # ffffffffc0201ba0 <etext+0x41c>
ffffffffc02011ea:	00001617          	auipc	a2,0x1
ffffffffc02011ee:	9be60613          	addi	a2,a2,-1602 # ffffffffc0201ba8 <etext+0x424>
ffffffffc02011f2:	04d00593          	li	a1,77
ffffffffc02011f6:	00001517          	auipc	a0,0x1
ffffffffc02011fa:	9ca50513          	addi	a0,a0,-1590 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc02011fe:	fc5fe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0201202 <default_init_memmap>:
default_init_memmap(struct Page *base, size_t n) {
ffffffffc0201202:	1141                	addi	sp,sp,-16
ffffffffc0201204:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0201206:	c5f1                	beqz	a1,ffffffffc02012d2 <default_init_memmap+0xd0>
    for (; p != base + n; p ++) {
ffffffffc0201208:	00259693          	slli	a3,a1,0x2
ffffffffc020120c:	96ae                	add	a3,a3,a1
ffffffffc020120e:	068e                	slli	a3,a3,0x3
ffffffffc0201210:	96aa                	add	a3,a3,a0
ffffffffc0201212:	87aa                	mv	a5,a0
ffffffffc0201214:	00d50f63          	beq	a0,a3,ffffffffc0201232 <default_init_memmap+0x30>
        assert(PageReserved(p));
ffffffffc0201218:	6798                	ld	a4,8(a5)
ffffffffc020121a:	8b05                	andi	a4,a4,1
ffffffffc020121c:	cf41                	beqz	a4,ffffffffc02012b4 <default_init_memmap+0xb2>
        p->flags = p->property = 0;
ffffffffc020121e:	0007a823          	sw	zero,16(a5)
ffffffffc0201222:	0007b423          	sd	zero,8(a5)
ffffffffc0201226:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc020122a:	02878793          	addi	a5,a5,40
ffffffffc020122e:	fed795e3          	bne	a5,a3,ffffffffc0201218 <default_init_memmap+0x16>
    SetPageProperty(base);
ffffffffc0201232:	6510                	ld	a2,8(a0)
    nr_free += n;
ffffffffc0201234:	00005697          	auipc	a3,0x5
ffffffffc0201238:	de468693          	addi	a3,a3,-540 # ffffffffc0206018 <free_area>
ffffffffc020123c:	4a98                	lw	a4,16(a3)
    base->property = n;
ffffffffc020123e:	2581                	sext.w	a1,a1
    SetPageProperty(base);
ffffffffc0201240:	00266613          	ori	a2,a2,2
    return list->next == list;
ffffffffc0201244:	669c                	ld	a5,8(a3)
    base->property = n;
ffffffffc0201246:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0201248:	e510                	sd	a2,8(a0)
    nr_free += n;
ffffffffc020124a:	9db9                	addw	a1,a1,a4
ffffffffc020124c:	ca8c                	sw	a1,16(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc020124e:	01850613          	addi	a2,a0,24
    if (list_empty(&free_list)) {
ffffffffc0201252:	04d78a63          	beq	a5,a3,ffffffffc02012a6 <default_init_memmap+0xa4>
            struct Page* page = le2page(le, page_link);
ffffffffc0201256:	fe878713          	addi	a4,a5,-24
ffffffffc020125a:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc020125e:	4581                	li	a1,0
            if (base < page) {
ffffffffc0201260:	00e56a63          	bltu	a0,a4,ffffffffc0201274 <default_init_memmap+0x72>
    return listelm->next;
ffffffffc0201264:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0201266:	02d70263          	beq	a4,a3,ffffffffc020128a <default_init_memmap+0x88>
    for (; p != base + n; p ++) {
ffffffffc020126a:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc020126c:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0201270:	fee57ae3          	bgeu	a0,a4,ffffffffc0201264 <default_init_memmap+0x62>
ffffffffc0201274:	c199                	beqz	a1,ffffffffc020127a <default_init_memmap+0x78>
ffffffffc0201276:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc020127a:	6398                	ld	a4,0(a5)
}
ffffffffc020127c:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc020127e:	e390                	sd	a2,0(a5)
ffffffffc0201280:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0201282:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0201284:	ed18                	sd	a4,24(a0)
ffffffffc0201286:	0141                	addi	sp,sp,16
ffffffffc0201288:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc020128a:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc020128c:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc020128e:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc0201290:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0201292:	00d70663          	beq	a4,a3,ffffffffc020129e <default_init_memmap+0x9c>
    prev->next = next->prev = elm;
ffffffffc0201296:	8832                	mv	a6,a2
ffffffffc0201298:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc020129a:	87ba                	mv	a5,a4
ffffffffc020129c:	bfc1                	j	ffffffffc020126c <default_init_memmap+0x6a>
}
ffffffffc020129e:	60a2                	ld	ra,8(sp)
ffffffffc02012a0:	e290                	sd	a2,0(a3)
ffffffffc02012a2:	0141                	addi	sp,sp,16
ffffffffc02012a4:	8082                	ret
ffffffffc02012a6:	60a2                	ld	ra,8(sp)
ffffffffc02012a8:	e390                	sd	a2,0(a5)
ffffffffc02012aa:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02012ac:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02012ae:	ed1c                	sd	a5,24(a0)
ffffffffc02012b0:	0141                	addi	sp,sp,16
ffffffffc02012b2:	8082                	ret
        assert(PageReserved(p));
ffffffffc02012b4:	00001697          	auipc	a3,0x1
ffffffffc02012b8:	c8468693          	addi	a3,a3,-892 # ffffffffc0201f38 <etext+0x7b4>
ffffffffc02012bc:	00001617          	auipc	a2,0x1
ffffffffc02012c0:	8ec60613          	addi	a2,a2,-1812 # ffffffffc0201ba8 <etext+0x424>
ffffffffc02012c4:	45d9                	li	a1,22
ffffffffc02012c6:	00001517          	auipc	a0,0x1
ffffffffc02012ca:	8fa50513          	addi	a0,a0,-1798 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc02012ce:	ef5fe0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc02012d2:	00001697          	auipc	a3,0x1
ffffffffc02012d6:	8ce68693          	addi	a3,a3,-1842 # ffffffffc0201ba0 <etext+0x41c>
ffffffffc02012da:	00001617          	auipc	a2,0x1
ffffffffc02012de:	8ce60613          	addi	a2,a2,-1842 # ffffffffc0201ba8 <etext+0x424>
ffffffffc02012e2:	45cd                	li	a1,19
ffffffffc02012e4:	00001517          	auipc	a0,0x1
ffffffffc02012e8:	8dc50513          	addi	a0,a0,-1828 # ffffffffc0201bc0 <etext+0x43c>
ffffffffc02012ec:	ed7fe0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02012f0 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc02012f0:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc02012f4:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc02012f6:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc02012f8:	cb81                	beqz	a5,ffffffffc0201308 <strlen+0x18>
        cnt ++;
ffffffffc02012fa:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc02012fc:	00a707b3          	add	a5,a4,a0
ffffffffc0201300:	0007c783          	lbu	a5,0(a5)
ffffffffc0201304:	fbfd                	bnez	a5,ffffffffc02012fa <strlen+0xa>
ffffffffc0201306:	8082                	ret
    }
    return cnt;
}
ffffffffc0201308:	8082                	ret

ffffffffc020130a <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc020130a:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc020130c:	e589                	bnez	a1,ffffffffc0201316 <strnlen+0xc>
ffffffffc020130e:	a811                	j	ffffffffc0201322 <strnlen+0x18>
        cnt ++;
ffffffffc0201310:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201312:	00f58863          	beq	a1,a5,ffffffffc0201322 <strnlen+0x18>
ffffffffc0201316:	00f50733          	add	a4,a0,a5
ffffffffc020131a:	00074703          	lbu	a4,0(a4) # fffffffffff80000 <end+0x3fd79f88>
ffffffffc020131e:	fb6d                	bnez	a4,ffffffffc0201310 <strnlen+0x6>
ffffffffc0201320:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201322:	852e                	mv	a0,a1
ffffffffc0201324:	8082                	ret

ffffffffc0201326 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201326:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc020132a:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020132e:	cb89                	beqz	a5,ffffffffc0201340 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201330:	0505                	addi	a0,a0,1
ffffffffc0201332:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201334:	fee789e3          	beq	a5,a4,ffffffffc0201326 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201338:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc020133c:	9d19                	subw	a0,a0,a4
ffffffffc020133e:	8082                	ret
ffffffffc0201340:	4501                	li	a0,0
ffffffffc0201342:	bfed                	j	ffffffffc020133c <strcmp+0x16>

ffffffffc0201344 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201344:	c20d                	beqz	a2,ffffffffc0201366 <strncmp+0x22>
ffffffffc0201346:	962e                	add	a2,a2,a1
ffffffffc0201348:	a031                	j	ffffffffc0201354 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc020134a:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020134c:	00e79a63          	bne	a5,a4,ffffffffc0201360 <strncmp+0x1c>
ffffffffc0201350:	00b60b63          	beq	a2,a1,ffffffffc0201366 <strncmp+0x22>
ffffffffc0201354:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201358:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020135a:	fff5c703          	lbu	a4,-1(a1)
ffffffffc020135e:	f7f5                	bnez	a5,ffffffffc020134a <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201360:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201364:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201366:	4501                	li	a0,0
ffffffffc0201368:	8082                	ret

ffffffffc020136a <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc020136a:	ca01                	beqz	a2,ffffffffc020137a <memset+0x10>
ffffffffc020136c:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc020136e:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201370:	0785                	addi	a5,a5,1
ffffffffc0201372:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201376:	fec79de3          	bne	a5,a2,ffffffffc0201370 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc020137a:	8082                	ret

ffffffffc020137c <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc020137c:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201380:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201382:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201386:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201388:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020138c:	f022                	sd	s0,32(sp)
ffffffffc020138e:	ec26                	sd	s1,24(sp)
ffffffffc0201390:	e84a                	sd	s2,16(sp)
ffffffffc0201392:	f406                	sd	ra,40(sp)
ffffffffc0201394:	e44e                	sd	s3,8(sp)
ffffffffc0201396:	84aa                	mv	s1,a0
ffffffffc0201398:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc020139a:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc020139e:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc02013a0:	03067e63          	bgeu	a2,a6,ffffffffc02013dc <printnum+0x60>
ffffffffc02013a4:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc02013a6:	00805763          	blez	s0,ffffffffc02013b4 <printnum+0x38>
ffffffffc02013aa:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc02013ac:	85ca                	mv	a1,s2
ffffffffc02013ae:	854e                	mv	a0,s3
ffffffffc02013b0:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc02013b2:	fc65                	bnez	s0,ffffffffc02013aa <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02013b4:	1a02                	slli	s4,s4,0x20
ffffffffc02013b6:	00001797          	auipc	a5,0x1
ffffffffc02013ba:	be278793          	addi	a5,a5,-1054 # ffffffffc0201f98 <default_pmm_manager+0x38>
ffffffffc02013be:	020a5a13          	srli	s4,s4,0x20
ffffffffc02013c2:	9a3e                	add	s4,s4,a5
}
ffffffffc02013c4:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02013c6:	000a4503          	lbu	a0,0(s4)
}
ffffffffc02013ca:	70a2                	ld	ra,40(sp)
ffffffffc02013cc:	69a2                	ld	s3,8(sp)
ffffffffc02013ce:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02013d0:	85ca                	mv	a1,s2
ffffffffc02013d2:	87a6                	mv	a5,s1
}
ffffffffc02013d4:	6942                	ld	s2,16(sp)
ffffffffc02013d6:	64e2                	ld	s1,24(sp)
ffffffffc02013d8:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc02013da:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc02013dc:	03065633          	divu	a2,a2,a6
ffffffffc02013e0:	8722                	mv	a4,s0
ffffffffc02013e2:	f9bff0ef          	jal	ra,ffffffffc020137c <printnum>
ffffffffc02013e6:	b7f9                	j	ffffffffc02013b4 <printnum+0x38>

ffffffffc02013e8 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc02013e8:	7119                	addi	sp,sp,-128
ffffffffc02013ea:	f4a6                	sd	s1,104(sp)
ffffffffc02013ec:	f0ca                	sd	s2,96(sp)
ffffffffc02013ee:	ecce                	sd	s3,88(sp)
ffffffffc02013f0:	e8d2                	sd	s4,80(sp)
ffffffffc02013f2:	e4d6                	sd	s5,72(sp)
ffffffffc02013f4:	e0da                	sd	s6,64(sp)
ffffffffc02013f6:	fc5e                	sd	s7,56(sp)
ffffffffc02013f8:	f06a                	sd	s10,32(sp)
ffffffffc02013fa:	fc86                	sd	ra,120(sp)
ffffffffc02013fc:	f8a2                	sd	s0,112(sp)
ffffffffc02013fe:	f862                	sd	s8,48(sp)
ffffffffc0201400:	f466                	sd	s9,40(sp)
ffffffffc0201402:	ec6e                	sd	s11,24(sp)
ffffffffc0201404:	892a                	mv	s2,a0
ffffffffc0201406:	84ae                	mv	s1,a1
ffffffffc0201408:	8d32                	mv	s10,a2
ffffffffc020140a:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc020140c:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0201410:	5b7d                	li	s6,-1
ffffffffc0201412:	00001a97          	auipc	s5,0x1
ffffffffc0201416:	bbaa8a93          	addi	s5,s5,-1094 # ffffffffc0201fcc <default_pmm_manager+0x6c>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc020141a:	00001b97          	auipc	s7,0x1
ffffffffc020141e:	d8eb8b93          	addi	s7,s7,-626 # ffffffffc02021a8 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201422:	000d4503          	lbu	a0,0(s10)
ffffffffc0201426:	001d0413          	addi	s0,s10,1
ffffffffc020142a:	01350a63          	beq	a0,s3,ffffffffc020143e <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc020142e:	c121                	beqz	a0,ffffffffc020146e <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0201430:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201432:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0201434:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201436:	fff44503          	lbu	a0,-1(s0)
ffffffffc020143a:	ff351ae3          	bne	a0,s3,ffffffffc020142e <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020143e:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0201442:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201446:	4c81                	li	s9,0
ffffffffc0201448:	4881                	li	a7,0
        width = precision = -1;
ffffffffc020144a:	5c7d                	li	s8,-1
ffffffffc020144c:	5dfd                	li	s11,-1
ffffffffc020144e:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201452:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201454:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201458:	0ff5f593          	zext.b	a1,a1
ffffffffc020145c:	00140d13          	addi	s10,s0,1
ffffffffc0201460:	04b56263          	bltu	a0,a1,ffffffffc02014a4 <vprintfmt+0xbc>
ffffffffc0201464:	058a                	slli	a1,a1,0x2
ffffffffc0201466:	95d6                	add	a1,a1,s5
ffffffffc0201468:	4194                	lw	a3,0(a1)
ffffffffc020146a:	96d6                	add	a3,a3,s5
ffffffffc020146c:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc020146e:	70e6                	ld	ra,120(sp)
ffffffffc0201470:	7446                	ld	s0,112(sp)
ffffffffc0201472:	74a6                	ld	s1,104(sp)
ffffffffc0201474:	7906                	ld	s2,96(sp)
ffffffffc0201476:	69e6                	ld	s3,88(sp)
ffffffffc0201478:	6a46                	ld	s4,80(sp)
ffffffffc020147a:	6aa6                	ld	s5,72(sp)
ffffffffc020147c:	6b06                	ld	s6,64(sp)
ffffffffc020147e:	7be2                	ld	s7,56(sp)
ffffffffc0201480:	7c42                	ld	s8,48(sp)
ffffffffc0201482:	7ca2                	ld	s9,40(sp)
ffffffffc0201484:	7d02                	ld	s10,32(sp)
ffffffffc0201486:	6de2                	ld	s11,24(sp)
ffffffffc0201488:	6109                	addi	sp,sp,128
ffffffffc020148a:	8082                	ret
            padc = '0';
ffffffffc020148c:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc020148e:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201492:	846a                	mv	s0,s10
ffffffffc0201494:	00140d13          	addi	s10,s0,1
ffffffffc0201498:	fdd6059b          	addiw	a1,a2,-35
ffffffffc020149c:	0ff5f593          	zext.b	a1,a1
ffffffffc02014a0:	fcb572e3          	bgeu	a0,a1,ffffffffc0201464 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc02014a4:	85a6                	mv	a1,s1
ffffffffc02014a6:	02500513          	li	a0,37
ffffffffc02014aa:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc02014ac:	fff44783          	lbu	a5,-1(s0)
ffffffffc02014b0:	8d22                	mv	s10,s0
ffffffffc02014b2:	f73788e3          	beq	a5,s3,ffffffffc0201422 <vprintfmt+0x3a>
ffffffffc02014b6:	ffed4783          	lbu	a5,-2(s10)
ffffffffc02014ba:	1d7d                	addi	s10,s10,-1
ffffffffc02014bc:	ff379de3          	bne	a5,s3,ffffffffc02014b6 <vprintfmt+0xce>
ffffffffc02014c0:	b78d                	j	ffffffffc0201422 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc02014c2:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc02014c6:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02014ca:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc02014cc:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc02014d0:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02014d4:	02d86463          	bltu	a6,a3,ffffffffc02014fc <vprintfmt+0x114>
                ch = *fmt;
ffffffffc02014d8:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc02014dc:	002c169b          	slliw	a3,s8,0x2
ffffffffc02014e0:	0186873b          	addw	a4,a3,s8
ffffffffc02014e4:	0017171b          	slliw	a4,a4,0x1
ffffffffc02014e8:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc02014ea:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc02014ee:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc02014f0:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc02014f4:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02014f8:	fed870e3          	bgeu	a6,a3,ffffffffc02014d8 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc02014fc:	f40ddce3          	bgez	s11,ffffffffc0201454 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201500:	8de2                	mv	s11,s8
ffffffffc0201502:	5c7d                	li	s8,-1
ffffffffc0201504:	bf81                	j	ffffffffc0201454 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201506:	fffdc693          	not	a3,s11
ffffffffc020150a:	96fd                	srai	a3,a3,0x3f
ffffffffc020150c:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201510:	00144603          	lbu	a2,1(s0)
ffffffffc0201514:	2d81                	sext.w	s11,s11
ffffffffc0201516:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201518:	bf35                	j	ffffffffc0201454 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc020151a:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020151e:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201522:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201524:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201526:	bfd9                	j	ffffffffc02014fc <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201528:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020152a:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020152e:	01174463          	blt	a4,a7,ffffffffc0201536 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201532:	1a088e63          	beqz	a7,ffffffffc02016ee <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201536:	000a3603          	ld	a2,0(s4)
ffffffffc020153a:	46c1                	li	a3,16
ffffffffc020153c:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc020153e:	2781                	sext.w	a5,a5
ffffffffc0201540:	876e                	mv	a4,s11
ffffffffc0201542:	85a6                	mv	a1,s1
ffffffffc0201544:	854a                	mv	a0,s2
ffffffffc0201546:	e37ff0ef          	jal	ra,ffffffffc020137c <printnum>
            break;
ffffffffc020154a:	bde1                	j	ffffffffc0201422 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc020154c:	000a2503          	lw	a0,0(s4)
ffffffffc0201550:	85a6                	mv	a1,s1
ffffffffc0201552:	0a21                	addi	s4,s4,8
ffffffffc0201554:	9902                	jalr	s2
            break;
ffffffffc0201556:	b5f1                	j	ffffffffc0201422 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201558:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc020155a:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020155e:	01174463          	blt	a4,a7,ffffffffc0201566 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201562:	18088163          	beqz	a7,ffffffffc02016e4 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201566:	000a3603          	ld	a2,0(s4)
ffffffffc020156a:	46a9                	li	a3,10
ffffffffc020156c:	8a2e                	mv	s4,a1
ffffffffc020156e:	bfc1                	j	ffffffffc020153e <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201570:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201574:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201576:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201578:	bdf1                	j	ffffffffc0201454 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc020157a:	85a6                	mv	a1,s1
ffffffffc020157c:	02500513          	li	a0,37
ffffffffc0201580:	9902                	jalr	s2
            break;
ffffffffc0201582:	b545                	j	ffffffffc0201422 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201584:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201588:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020158a:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020158c:	b5e1                	j	ffffffffc0201454 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc020158e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201590:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201594:	01174463          	blt	a4,a7,ffffffffc020159c <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201598:	14088163          	beqz	a7,ffffffffc02016da <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc020159c:	000a3603          	ld	a2,0(s4)
ffffffffc02015a0:	46a1                	li	a3,8
ffffffffc02015a2:	8a2e                	mv	s4,a1
ffffffffc02015a4:	bf69                	j	ffffffffc020153e <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc02015a6:	03000513          	li	a0,48
ffffffffc02015aa:	85a6                	mv	a1,s1
ffffffffc02015ac:	e03e                	sd	a5,0(sp)
ffffffffc02015ae:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc02015b0:	85a6                	mv	a1,s1
ffffffffc02015b2:	07800513          	li	a0,120
ffffffffc02015b6:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02015b8:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc02015ba:	6782                	ld	a5,0(sp)
ffffffffc02015bc:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc02015be:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc02015c2:	bfb5                	j	ffffffffc020153e <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02015c4:	000a3403          	ld	s0,0(s4)
ffffffffc02015c8:	008a0713          	addi	a4,s4,8
ffffffffc02015cc:	e03a                	sd	a4,0(sp)
ffffffffc02015ce:	14040263          	beqz	s0,ffffffffc0201712 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc02015d2:	0fb05763          	blez	s11,ffffffffc02016c0 <vprintfmt+0x2d8>
ffffffffc02015d6:	02d00693          	li	a3,45
ffffffffc02015da:	0cd79163          	bne	a5,a3,ffffffffc020169c <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02015de:	00044783          	lbu	a5,0(s0)
ffffffffc02015e2:	0007851b          	sext.w	a0,a5
ffffffffc02015e6:	cf85                	beqz	a5,ffffffffc020161e <vprintfmt+0x236>
ffffffffc02015e8:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02015ec:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02015f0:	000c4563          	bltz	s8,ffffffffc02015fa <vprintfmt+0x212>
ffffffffc02015f4:	3c7d                	addiw	s8,s8,-1
ffffffffc02015f6:	036c0263          	beq	s8,s6,ffffffffc020161a <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc02015fa:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02015fc:	0e0c8e63          	beqz	s9,ffffffffc02016f8 <vprintfmt+0x310>
ffffffffc0201600:	3781                	addiw	a5,a5,-32
ffffffffc0201602:	0ef47b63          	bgeu	s0,a5,ffffffffc02016f8 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201606:	03f00513          	li	a0,63
ffffffffc020160a:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc020160c:	000a4783          	lbu	a5,0(s4)
ffffffffc0201610:	3dfd                	addiw	s11,s11,-1
ffffffffc0201612:	0a05                	addi	s4,s4,1
ffffffffc0201614:	0007851b          	sext.w	a0,a5
ffffffffc0201618:	ffe1                	bnez	a5,ffffffffc02015f0 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc020161a:	01b05963          	blez	s11,ffffffffc020162c <vprintfmt+0x244>
ffffffffc020161e:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201620:	85a6                	mv	a1,s1
ffffffffc0201622:	02000513          	li	a0,32
ffffffffc0201626:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201628:	fe0d9be3          	bnez	s11,ffffffffc020161e <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc020162c:	6a02                	ld	s4,0(sp)
ffffffffc020162e:	bbd5                	j	ffffffffc0201422 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201630:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201632:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201636:	01174463          	blt	a4,a7,ffffffffc020163e <vprintfmt+0x256>
    else if (lflag) {
ffffffffc020163a:	08088d63          	beqz	a7,ffffffffc02016d4 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc020163e:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201642:	0a044d63          	bltz	s0,ffffffffc02016fc <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201646:	8622                	mv	a2,s0
ffffffffc0201648:	8a66                	mv	s4,s9
ffffffffc020164a:	46a9                	li	a3,10
ffffffffc020164c:	bdcd                	j	ffffffffc020153e <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc020164e:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201652:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201654:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201656:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc020165a:	8fb5                	xor	a5,a5,a3
ffffffffc020165c:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201660:	02d74163          	blt	a4,a3,ffffffffc0201682 <vprintfmt+0x29a>
ffffffffc0201664:	00369793          	slli	a5,a3,0x3
ffffffffc0201668:	97de                	add	a5,a5,s7
ffffffffc020166a:	639c                	ld	a5,0(a5)
ffffffffc020166c:	cb99                	beqz	a5,ffffffffc0201682 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc020166e:	86be                	mv	a3,a5
ffffffffc0201670:	00001617          	auipc	a2,0x1
ffffffffc0201674:	95860613          	addi	a2,a2,-1704 # ffffffffc0201fc8 <default_pmm_manager+0x68>
ffffffffc0201678:	85a6                	mv	a1,s1
ffffffffc020167a:	854a                	mv	a0,s2
ffffffffc020167c:	0ce000ef          	jal	ra,ffffffffc020174a <printfmt>
ffffffffc0201680:	b34d                	j	ffffffffc0201422 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201682:	00001617          	auipc	a2,0x1
ffffffffc0201686:	93660613          	addi	a2,a2,-1738 # ffffffffc0201fb8 <default_pmm_manager+0x58>
ffffffffc020168a:	85a6                	mv	a1,s1
ffffffffc020168c:	854a                	mv	a0,s2
ffffffffc020168e:	0bc000ef          	jal	ra,ffffffffc020174a <printfmt>
ffffffffc0201692:	bb41                	j	ffffffffc0201422 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201694:	00001417          	auipc	s0,0x1
ffffffffc0201698:	91c40413          	addi	s0,s0,-1764 # ffffffffc0201fb0 <default_pmm_manager+0x50>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020169c:	85e2                	mv	a1,s8
ffffffffc020169e:	8522                	mv	a0,s0
ffffffffc02016a0:	e43e                	sd	a5,8(sp)
ffffffffc02016a2:	c69ff0ef          	jal	ra,ffffffffc020130a <strnlen>
ffffffffc02016a6:	40ad8dbb          	subw	s11,s11,a0
ffffffffc02016aa:	01b05b63          	blez	s11,ffffffffc02016c0 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc02016ae:	67a2                	ld	a5,8(sp)
ffffffffc02016b0:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02016b4:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc02016b6:	85a6                	mv	a1,s1
ffffffffc02016b8:	8552                	mv	a0,s4
ffffffffc02016ba:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc02016bc:	fe0d9ce3          	bnez	s11,ffffffffc02016b4 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02016c0:	00044783          	lbu	a5,0(s0)
ffffffffc02016c4:	00140a13          	addi	s4,s0,1
ffffffffc02016c8:	0007851b          	sext.w	a0,a5
ffffffffc02016cc:	d3a5                	beqz	a5,ffffffffc020162c <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02016ce:	05e00413          	li	s0,94
ffffffffc02016d2:	bf39                	j	ffffffffc02015f0 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc02016d4:	000a2403          	lw	s0,0(s4)
ffffffffc02016d8:	b7ad                	j	ffffffffc0201642 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc02016da:	000a6603          	lwu	a2,0(s4)
ffffffffc02016de:	46a1                	li	a3,8
ffffffffc02016e0:	8a2e                	mv	s4,a1
ffffffffc02016e2:	bdb1                	j	ffffffffc020153e <vprintfmt+0x156>
ffffffffc02016e4:	000a6603          	lwu	a2,0(s4)
ffffffffc02016e8:	46a9                	li	a3,10
ffffffffc02016ea:	8a2e                	mv	s4,a1
ffffffffc02016ec:	bd89                	j	ffffffffc020153e <vprintfmt+0x156>
ffffffffc02016ee:	000a6603          	lwu	a2,0(s4)
ffffffffc02016f2:	46c1                	li	a3,16
ffffffffc02016f4:	8a2e                	mv	s4,a1
ffffffffc02016f6:	b5a1                	j	ffffffffc020153e <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc02016f8:	9902                	jalr	s2
ffffffffc02016fa:	bf09                	j	ffffffffc020160c <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc02016fc:	85a6                	mv	a1,s1
ffffffffc02016fe:	02d00513          	li	a0,45
ffffffffc0201702:	e03e                	sd	a5,0(sp)
ffffffffc0201704:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201706:	6782                	ld	a5,0(sp)
ffffffffc0201708:	8a66                	mv	s4,s9
ffffffffc020170a:	40800633          	neg	a2,s0
ffffffffc020170e:	46a9                	li	a3,10
ffffffffc0201710:	b53d                	j	ffffffffc020153e <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201712:	03b05163          	blez	s11,ffffffffc0201734 <vprintfmt+0x34c>
ffffffffc0201716:	02d00693          	li	a3,45
ffffffffc020171a:	f6d79de3          	bne	a5,a3,ffffffffc0201694 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc020171e:	00001417          	auipc	s0,0x1
ffffffffc0201722:	89240413          	addi	s0,s0,-1902 # ffffffffc0201fb0 <default_pmm_manager+0x50>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201726:	02800793          	li	a5,40
ffffffffc020172a:	02800513          	li	a0,40
ffffffffc020172e:	00140a13          	addi	s4,s0,1
ffffffffc0201732:	bd6d                	j	ffffffffc02015ec <vprintfmt+0x204>
ffffffffc0201734:	00001a17          	auipc	s4,0x1
ffffffffc0201738:	87da0a13          	addi	s4,s4,-1923 # ffffffffc0201fb1 <default_pmm_manager+0x51>
ffffffffc020173c:	02800513          	li	a0,40
ffffffffc0201740:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201744:	05e00413          	li	s0,94
ffffffffc0201748:	b565                	j	ffffffffc02015f0 <vprintfmt+0x208>

ffffffffc020174a <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020174a:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc020174c:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201750:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201752:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201754:	ec06                	sd	ra,24(sp)
ffffffffc0201756:	f83a                	sd	a4,48(sp)
ffffffffc0201758:	fc3e                	sd	a5,56(sp)
ffffffffc020175a:	e0c2                	sd	a6,64(sp)
ffffffffc020175c:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc020175e:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201760:	c89ff0ef          	jal	ra,ffffffffc02013e8 <vprintfmt>
}
ffffffffc0201764:	60e2                	ld	ra,24(sp)
ffffffffc0201766:	6161                	addi	sp,sp,80
ffffffffc0201768:	8082                	ret

ffffffffc020176a <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc020176a:	4781                	li	a5,0
ffffffffc020176c:	00005717          	auipc	a4,0x5
ffffffffc0201770:	8a473703          	ld	a4,-1884(a4) # ffffffffc0206010 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201774:	88ba                	mv	a7,a4
ffffffffc0201776:	852a                	mv	a0,a0
ffffffffc0201778:	85be                	mv	a1,a5
ffffffffc020177a:	863e                	mv	a2,a5
ffffffffc020177c:	00000073          	ecall
ffffffffc0201780:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201782:	8082                	ret
