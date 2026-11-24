#!/bin/sh
# A 部分验证脚本：在临时副本里注入 tools/test_lab5.c，编译并运行 QEMU，
# 打印 Lab5 的三组基础评分检查结果。
#
# 用法（在任意目录）：
#   ./report/run_injected_check.sh
#
# 说明：
# 1) 不会修改 code/ 本身，所有改动都在 .gradetest/ 临时副本里；
# 2) 运行约 25~35 秒，最后打印一个“评分检查结果”块，直接对该块截屏即可；
# 3) 完整 QEMU 输出会保存到 report/test_process_control.log，便于复核。

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CODE="$ROOT/code"
TMP="$ROOT/.gradetest"
LOG="$ROOT/report/test_process_control.log"

echo "[1/4] 准备临时副本：$TMP"
rm -rf "$TMP"
mkdir -p "$TMP"
tar -C "$CODE" --exclude=.git --exclude=bin --exclude=obj -cf - . | tar -C "$TMP" -xf -
if [ $? -ne 0 ]; then
    echo "错误：复制 code/ 失败"
    exit 1
fi

echo "[2/4] 注入 tools/test_lab5.c"
python3 "$CODE/tools/inject.py" "$TMP" || exit 1

echo "[3/4] 编译（默认 TEST=exit）"
make -C "$TMP" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "错误：编译失败，请单独运行 make -C $TMP 查看"
    exit 1
fi

echo "[4/4] 运行 QEMU（最多 25 秒）"
# 用 -serial file: 直接把串口写进文件，避免依赖当前终端的 tty 状态。
timeout 25 qemu-system-riscv64 \
    -machine virt -display none -bios default \
    -monitor none -serial "file:$LOG" \
    -device loader,file="$TMP/bin/ucore.img",addr=0x80200000
qemu_rc=$?
if [ ! -s "$LOG" ]; then
    echo "警告：QEMU 没有产生输出（退出码 $qemu_rc）。"
    echo "请检查 qemu-system-riscv64 是否在 PATH 中，以及 $TMP/bin/ucore.img 是否存在。"
    exit 1
fi

# QEMU 串口输出带 CRLF，去掉 \r 后再匹配
tr -d '\r' < "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

echo
echo "================ Lab5 基础评分检查 ================"
grep -E '^\[Test (Process Create|Syscall|Process Control)\] PASS$' "$LOG"
echo "--------------------------------------------------"
grep -E '^(exit pass\.|all user-mode processes have quit\.|init check memory pass\.)$' "$LOG"
echo "=================================================="
echo
echo "完整输出尾部："
tail -8 "$LOG"
echo
echo "（完整日志：report/test_process_control.log）"

rm -rf "$TMP"
