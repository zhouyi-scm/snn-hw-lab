# ============================================================================
#  FIFO 综合脚本（Vivado 2019.1，batch 模式，不打开 GUI）
#
#  用法：在 C:\ic-work\verilog-start\01_fifo 下运行  .\synth.bat
#        本文件由 synth.bat 自动调用，一般不用手动敲。
#
#  作用：只做"综合"（RTL -> 门级网表），拿到资源占用数字。
#        不做布局布线，所以现在没有"最高频率"这个数字 -- 那是后面的事。
# ============================================================================

# ---- 1. 读入设计（只读 fifo.v，不读 tb_fifo.v：testbench 不参与综合）----
read_verilog fifo.v

# ---- 2. 综合 ----
#   -top  fifo                ：指定顶层模块名
#   -part xc7a35tcsg324-1     ：Artix-7 35T（WebPACK 免费版支持）
synth_design -top fifo -part xc7a35tcsg324-1

# ---- 3. 出资源报告 ----
#   -file util.rpt  ：写一份到文件里，方便以后贴进 README / 做前后对比
#   不加 -file 的那次：直接把表格打到屏幕上，你能当场看到
report_utilization -file util.rpt
report_utilization

# puts 用英文：控制台是 cp936，中文在这里只会变成乱码
puts ""
puts "============================================================"
puts "  Synthesis done. Report: util.rpt"
puts "  Record: Slice LUTs / LUT as Memory / Slice Registers / Block RAM / DSPs"
puts "============================================================"
