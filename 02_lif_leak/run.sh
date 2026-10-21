#!/usr/bin/env bash
# 练习 02：带泄漏的膜电位累加器
#   bash run.sh         只仿真，打印 PASS / FAIL
#   bash run.sh wave    仿真并打开波形
set -e

cd "$(dirname "$0")"

iverilog -g2005 -o sim.out lif_leak.v tb_lif_leak.v
vvp sim.out

echo ""
echo "波形文件: $(pwd)/dump.vcd"
if [ "$1" = "wave" ]; then
    echo "正在打开 GTKWave ..."
    echo "  提示：展开 tb_lif_leak -> dut，重点看 en / i_in / v_out 三条线。"
    echo "        把 i_in 的显示格式改成有符号十进制，观察 v_out 的指数衰减。"
    gtkwave dump.vcd &
else
    echo "查看波形: bash run.sh wave"
fi
