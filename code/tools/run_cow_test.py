#!/usr/bin/env python3
"""Check the enabled COW implementation in QEMU and save evidence to report/."""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


CASES = [
    ("mapping-and-writes", "子写时复制、父子数据隔离"),
    ("parent-writes", "父进程写入也保持隔离"),
    ("multiple-forks", "多个子进程及子进程再次 fork"),
    ("cross-page", "跨页写入与相邻字节保护"),
    ("wait-copyout", "内核写回退出码遵守 COW"),
    ("readonly", "真正只读页保持只读"),
    ("repeated-exit", "反复 fork、写入与退出"),
]


def verify(text):
    for name, _ in CASES:
        if f"COWTEST {name} PASS" not in text:
            raise RuntimeError(f"Missing successful case: {name}")
    if "COWTEST ALL PASS" not in text or "init check memory pass." not in text:
        raise RuntimeError("User test or final process/memory cleanup did not finish")
    if "user panic at" in text:
        raise RuntimeError("A user assertion failed; inspect the serial log")

    addresses = re.search(r"COWTEST ADDR probe=0x([0-9a-f]+) readonly=0x([0-9a-f]+)", text)
    if addresses is None:
        raise RuntimeError("Missing test buffer addresses")
    probe, readonly = (int(value, 16) for value in addresses.groups())
    snapshots = {}
    for name, block in re.findall(r"COWTEST SNAP ([\w-]+)\n(.*?)COWTEST END", text, re.S):
        entries = {}
        for va, pa, size, pte in re.findall(
            r"VA=0x([0-9a-f]+) -> PA=0x([0-9a-f]+) "
            r"size=0x([0-9a-f]+).*?PTE=0x([0-9a-f]+)", block
        ):
            entries[int(va, 16)] = tuple(int(value, 16) for value in (pa, size, pte))
        if probe not in entries or readonly not in entries:
            raise RuntimeError(f"Incomplete page-table snapshot: {name}")
        if entries[probe][1] != 4096 or entries[readonly][1] != 4096:
            raise RuntimeError("The user test expects 4 KiB leaf mappings")
        if entries[readonly][2] & (0x004 | 0x100):
            raise RuntimeError("A genuinely read-only page gained write/COW permission")
        snapshots[name] = entries[probe]

    names = ["child-before", "child-after", "parent-before", "parent-after"]
    if any(name not in snapshots for name in names):
        raise RuntimeError("Missing COW lifecycle snapshots")
    cb, ca, pb, pa = (snapshots[name] for name in names)
    writable, cow = 0x004, 0x100
    if cb[0] != pb[0] or ca[0] == cb[0] or pa[0] != pb[0]:
        raise RuntimeError("Physical pages did not follow COW sharing/split/reuse")
    if any((entry[2] & (writable | cow)) != cow for entry in (cb, pb)):
        raise RuntimeError("Expected read-only COW mappings before writes")
    if any((entry[2] & (writable | cow)) != writable for entry in (ca, pa)):
        raise RuntimeError("Write completion left incorrect PTE permissions")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=int, default=60)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    modes = re.findall(r"(?m)^#define\s+LAB5_USE_COW\s+([01])\b",
                       (root / "kern/mm/mmu.h").read_text())
    if modes != ["1"]:
        parser.exit(1, "Set LAB5_USE_COW to 1 in kern/mm/mmu.h before running this test.\n")
    report = root.parent / "report"
    report.mkdir(exist_ok=True)
    log = report / "cow_qemu_mode1.log"
    build_log = report / "cow_build_mode1.log"
    qemu = shutil.which("qemu-system-riscv64")
    if qemu is None:
        parser.exit(1, "qemu-system-riscv64 is required\n")

    try:
        with tempfile.TemporaryDirectory(prefix="lab5-cow-user-") as directory:
            stage = Path(directory) / "code"
            shutil.copytree(root, stage, ignore=shutil.ignore_patterns(
                "obj", "bin", ".git", ".gradetest", "__pycache__", "*.log", ".qemu.out"
            ))
            print("Building temporary copy of the enabled COW version...", flush=True)
            with build_log.open("w") as output:
                subprocess.run(["make", "build-cowtest"], cwd=stage, stdout=output,
                               stderr=subprocess.STDOUT, check=True)
            with log.open("w") as output:
                subprocess.run([
                    qemu, "-machine", "virt", "-nographic", "-bios", "default",
                    "-monitor", "none", "-device",
                    f"loader,file={stage / 'bin/ucore.img'},addr=0x80200000",
                ], stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
                    timeout=args.timeout, check=True)
            verify(log.read_text(errors="replace").replace("\r", ""))
    except (RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f"FAIL: {error}\nBuild log: {build_log}\nSerial log: {log}\n")

    for name, description in CASES:
        print(f"[{name}] PASS - {description}")
    print("[PTE evidence] PASS - 共享同页、写后分离、单引用保留原物理页")
    print("[Final cleanup] PASS - 进程与内存回收检查")
    print(f"Serial log: {log}")
    print(f"Build log: {build_log}")


if __name__ == "__main__":
    main()
