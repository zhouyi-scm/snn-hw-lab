#!/usr/bin/env bash
# 练习 01：同步 FIFO
#   bash run.sh         只仿真，打印 PASS / FAIL
#   bash run.sh wave    仿真并打开波形
set -e

cd "$(dirname "$0")"

iverilog -g2005 -o sim.out fifo.v tb_fifo.v
vvp sim.out

echo ""
echo "波形文件: $(pwd)/dump.vcd"
if [ "$1" = "wave" ]; then
    echo "正在打开 GTKWave ..."
    echo "  提示：左侧展开 tb_fifo -> dut，把 clk / rst_n / wr_en / rd_en /"
    echo "        din / dout / full / empty / count 拖到右侧窗口"
    gtkwave dump.vcd &
else
    echo "查看波形: bash run.sh wave"
fi
