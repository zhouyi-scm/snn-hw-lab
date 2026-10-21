#!/usr/bin/env bash
# 练习 03：valid/ready 握手寄存器
#   bash run.sh         只仿真，打印 PASS / FAIL
#   bash run.sh wave    仿真并打开波形
set -e

cd "$(dirname "$0")"

iverilog -g2005 -o sim.out hs_reg.v tb_hs_reg.v
vvp sim.out

echo ""
echo "波形文件: $(pwd)/dump.vcd"
if [ "$1" = "wave" ]; then
    echo "正在打开 GTKWave ..."
    echo "  提示：展开 tb_hs_reg -> dut，重点看 s_valid/s_ready/m_valid/m_ready"
    echo "        四条线的握手关系，特别是 m_ready=0 时的背压行为。"
    gtkwave dump.vcd &
else
    echo "查看波形: bash run.sh wave"
fi
