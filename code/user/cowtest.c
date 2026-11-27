#include <ulib.h>
#include <stdio.h>
#include <error.h>

#define PAGE_SIZE 4096

/* Each buffer owns complete pages, so unrelated globals cannot split it. */
static volatile unsigned char probe[PAGE_SIZE]
    __attribute__((aligned(PAGE_SIZE)));
static volatile unsigned char cross_page[2 * PAGE_SIZE]
    __attribute__((aligned(PAGE_SIZE)));
static volatile unsigned int wait_page[PAGE_SIZE / sizeof(unsigned int)]
    __attribute__((aligned(PAGE_SIZE)));
static const unsigned char readonly_page[PAGE_SIZE]
    __attribute__((aligned(PAGE_SIZE))) = {0x3c};

static void snapshot(const char *name)
{
    cprintf("COWTEST SNAP %s\n", name);
    print_pgdir();
    cprintf("COWTEST END\n");
}

static void wait_code(int pid, int expected)
{
    int code = 0;
    assert(waitpid(pid, &code) == 0);
    assert(code == expected);
}

static void test_mapping_and_writes(void)
{
    probe[7] = 0x5a;
    cprintf("COWTEST ADDR probe=0x%llx readonly=0x%llx\n",
            (unsigned long long)(uintptr_t)probe,
            (unsigned long long)(uintptr_t)readonly_page);

    int pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        snapshot("child-before");
        assert(probe[7] == 0x5a);
        probe[7] = 0xa5;
        snapshot("child-after");
        assert(probe[7] == 0xa5);
        exit(0x11);
    }

    /* Only the child prints snapshots until wait returns. */
    wait_code(pid, 0x11);
    assert(probe[7] == 0x5a);
    snapshot("parent-before");
    probe[7] = 0xb2;
    assert(probe[7] == 0xb2);
    snapshot("parent-after");
    cprintf("COWTEST mapping-and-writes PASS\n");
}

static void test_parent_writes(void)
{
    probe[7] = 0x22;
    int pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        for (int i = 0; i < 8; i++) {
            yield();
            assert(probe[7] == 0x22);
        }
        exit(0);
    }
    probe[7] = 0x77;
    wait_code(pid, 0);
    assert(probe[7] == 0x77);
    cprintf("COWTEST parent-writes PASS\n");
}

static void test_multiple_forks(void)
{
    int children[4];
    probe[7] = 0x22;
    for (int i = 0; i < 4; i++) {
        int pid = fork();
        assert(pid >= 0);
        if (pid == 0) {
            assert(probe[7] == 0x22);
            probe[7] = 0x30 + i;
            for (int n = 0; n < 3; n++) {
                yield();
                assert(probe[7] == 0x30 + i);
            }
            exit(i);
        }
        children[i] = pid;
    }
    for (int i = 0; i < 4; i++) {
        wait_code(children[i], i);
    }
    assert(probe[7] == 0x22);

    /* Fork once more from a child that still holds the original COW page. */
    int pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        int nested = fork();
        assert(nested >= 0);
        if (nested == 0) {
            probe[7] = 0x99;
            assert(probe[7] == 0x99);
            exit(0);
        }
        wait_code(nested, 0);
        assert(probe[7] == 0x22);
        exit(0);
    }
    wait_code(pid, 0);
    assert(probe[7] == 0x22);
    cprintf("COWTEST multiple-forks PASS\n");
}

static void test_cross_page(void)
{
    for (int i = 0; i < 2 * PAGE_SIZE; i++) {
        cross_page[i] = 0x5a;
    }
    int pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        /* Byte stores cross the boundary without misaligned word accesses. */
        for (int i = PAGE_SIZE - 4; i < PAGE_SIZE + 8; i++) {
            cross_page[i] = 0x37;
        }
        for (int i = PAGE_SIZE - 4; i < PAGE_SIZE + 8; i++) {
            assert(cross_page[i] == 0x37);
        }
        assert(cross_page[PAGE_SIZE - 5] == 0x5a);
        assert(cross_page[PAGE_SIZE + 8] == 0x5a);
        exit(0);
    }
    wait_code(pid, 0);
    for (int i = PAGE_SIZE - 5; i <= PAGE_SIZE + 8; i++) {
        assert(cross_page[i] == 0x5a);
    }
    cprintf("COWTEST cross-page PASS\n");
}

static void test_wait_copyout(void)
{
    wait_page[0] = 0x12345678;
    int observer = fork();
    assert(observer >= 0);
    if (observer == 0) {
        while (1) {
            assert(wait_page[0] == 0x12345678);
            yield();
        }
    }
    int worker = fork();
    assert(worker >= 0);
    if (worker == 0) {
        exit(0x3344);
    }
    /* The observer retains the old page throughout this kernel write. */
    assert(waitpid(worker, (int *)(uintptr_t)wait_page) == 0);
    assert(wait_page[0] == 0x3344);
    for (int i = 0; i < 8; i++) {
        yield();
    }
    assert(kill(observer) == 0);
    wait_code(observer, -E_KILLED);
    cprintf("COWTEST wait-copyout PASS\n");
}

static void test_readonly(void)
{
    int pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        volatile unsigned char *target =
            (volatile unsigned char *)(uintptr_t)readonly_page;
        *target = 0xa5;
        exit(0x7e);
    }
    wait_code(pid, -E_KILLED);
    cprintf("COWTEST readonly PASS\n");
}

static void test_repeated_exit(void)
{
    for (int i = 0; i < 16; i++) {
        int pid = fork();
        assert(pid >= 0);
        if (pid == 0) {
            probe[7] = i;
            exit(i);
        }
        wait_code(pid, i);
        assert(probe[7] == 0x22);
    }
    cprintf("COWTEST repeated-exit PASS\n");
}

int main(void)
{
    test_mapping_and_writes();
    test_parent_writes();
    test_multiple_forks();
    test_cross_page();
    test_wait_copyout();
    test_readonly();
    test_repeated_exit();
    cprintf("COWTEST ALL PASS\n");
    return 0;
}
