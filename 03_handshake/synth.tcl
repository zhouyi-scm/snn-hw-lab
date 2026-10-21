# ============================================================================
#  Ex 03: valid/ready handshake register -- Vivado 2019.1 synthesis (batch)
#
#  Usage: run  .\synth.bat  inside  C:\ic-work\verilog-start\03_handshake
#         (this file is called by synth.bat; you normally don't run it directly)
#
#  Only "synthesis" (RTL -> gate netlist). No place & route,
#  so there is NO fmax number here -- that needs implementation.
#
#  What to look at in util.rpt for this module:
#    Slice Registers  -- should be exactly 9 = 1 (m_valid_r) + WIDTH (m_data_r)
#    Slice LUTs       -- should be 1 or 2:  s_ready = (~m_valid_r) | m_ready
#                        is the ONLY combinational logic in the whole module
#    Block RAM / DSPs -- 0, always
#
#  Bonus check in "Report Cell Usage" (section 7, Primitives):
#    FDCE = 1  -> m_valid_r, the only register WITH reset
#    FDRE = 8  -> m_data_r, data registers have NO reset (on purpose)
# ============================================================================

# ---- 1. read the design (only hs_reg.v, never the testbench) ----
read_verilog hs_reg.v

# ---- 2. synthesize ----
synth_design -top hs_reg -part xc7a35tcsg324-1

# ---- 3. reports ----
report_utilization -file util.rpt
report_utilization

# ---- 4. no report_cell_usage: it doesn't exist in 2019.1.
#         The per-primitive breakdown is already section 7 of util.rpt.

# puts in English: the Vivado console is cp936, Chinese here turns into garbage
puts ""
puts "============================================================"
puts "  Synthesis done. Report: util.rpt"
puts "  Expect: Slice Registers = 9, Slice LUTs = 1..2, BRAM = 0, DSP = 0"
puts "  Primitives: FDCE = 1, FDRE = 8"
puts "============================================================"
