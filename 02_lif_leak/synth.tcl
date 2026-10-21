# ============================================================================
#  LIF 泄漏累加器 综合脚本（Vivado 2019.1，batch 模式，不打开 GUI）
#
#  用法：在 C:\ic-work\verilog-start\02_lif_leak 下运行  .\synth.bat
#        本文件由 synth.bat 自动调用，一般不用手动敲。
#
#  作用：只做"综合"（RTL -> 门级网表），拿到资源占用数字。
#        不做布局布线，所以没有"最高频率"这个数字。
#
#  这个模块很小，重点看的只有两个数：
#    Slice LUTs        —— 那个"减法器"到底值多少个 LUT
#    Slice Registers   —— 应该正好 WIDTH = 16 个（v_out 是唯一的寄存器）
#  如果 Slice Registers 不是 16，说明你代码里有你没意识到的东西。
# ============================================================================

# ---- 1. 读入设计（只读 lif_leak.v，不读 tb_lif_leak.v）----
read_verilog lif_leak.v

# ---- 2. 综合 ----
synth_design -top lif_leak -part xc7a35tcsg324-1

# ---- 3. 出资源报告 ----
report_utilization -file util.rpt
report_utilization

# ---- 4. cell 级明细不用再跑命令：它就在 util.rpt 里 ----
#   util.rpt 第 7 节 "Primitives" 就是"到底用了什么元件"：
#     FDCE  = 带异步复位 + 时钟使能的触发器（你的 v_out 16 个）
#     LUT6/LUT5/LUT4 = 组合逻辑
#     CARRY4 = 专用进位链（加法器/减法器走的就是它，不占 LUT）
#   注意：Vivado 2019.1 里没有 report_cell_usage 这个命令
#        （那是老 PlanAhead 的命令），敲了会报 invalid command name。

# puts 用英文：控制台是 cp936，中文在这里只会变成乱码
puts ""
puts "============================================================"
puts "  Synthesis done. Report: util.rpt"
puts "  Expect: Slice Registers = 16 (= WIDTH), DSPs = 0, BRAM = 0"
puts "============================================================"
