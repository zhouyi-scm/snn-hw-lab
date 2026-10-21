//=============================================================================
// 练习 03 自检测试平台 —— 不要修改本文件
//-----------------------------------------------------------------------------
// 分两部分：
//   定向测试：验证空/满/背压（backpressure）下的行为
//   随机测试：跑 500 个周期随机激励，内部维护参考队列，
//             检查每一个进入的数据是否原样、按序地从输出出来
//             （不丢、不重、不乱序）
//=============================================================================

`timescale 1ns/1ps

module tb_hs_reg;

    localparam WIDTH = 8;

    reg              clk;
    reg              rst_n;
    reg              s_valid;
    wire             s_ready;
    reg  [WIDTH-1:0] s_data;
    wire             m_valid;
    reg              m_ready;
    wire [WIDTH-1:0] m_data;

    integer errors   = 0;
    integer checks   = 0;
    integer accepted = 0;
    integer popped   = 0;

    // ---- 参考队列（环形，2 的幂大小）----
    reg [WIDTH-1:0] q [0:255];
    integer qh;
    integer qt;

    integer i;
    integer r;
    integer k;

    hs_reg #(
        .WIDTH (WIDTH)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .s_valid (s_valid),
        .s_ready (s_ready),
        .s_data  (s_data),
        .m_valid (m_valid),
        .m_ready (m_ready),
        .m_data  (m_data)
    );

    always #5 clk = ~clk;       // 100 MHz

    task do_reset;
        begin
            rst_n   = 1'b0;
            s_valid = 1'b0;
            s_data  = {WIDTH{1'b0}};
            m_ready = 1'b0;
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n   = 1'b1;
            @(negedge clk);
            qh = 0;
            qt = 0;
        end
    endtask

    // 检查一次握手周期：采样当期被接收 / 被取走的数据
    task sample_cycle;
        begin
            #1;                                     // 等组合逻辑稳定
            if (s_valid && s_ready) begin
                q[qt[7:0]] = s_data;
                qt = qt + 1;
                accepted = accepted + 1;
            end
            if (m_valid && m_ready) begin
                checks = checks + 1;
                if (m_data !== q[qh[7:0]]) begin
                    errors = errors + 1;
                    $display("  [FAIL] t=%0t  输出数据 %0d，期望 %0d（顺序错或丢数据）",
                             $time, m_data, q[qh[7:0]]);
                end
                qh = qh + 1;
                popped = popped + 1;
            end
        end
    endtask

    task check_m_valid;
        input integer exp;
        begin
            checks = checks + 1;
            if (m_valid !== exp[0]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  m_valid=%b，期望 %b", $time, m_valid, exp[0]);
            end
        end
    endtask

    task check_s_ready;
        input integer exp;
        begin
            checks = checks + 1;
            if (s_ready !== exp[0]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  s_ready=%b，期望 %b", $time, s_ready, exp[0]);
            end
        end
    endtask

    initial begin
        clk     = 1'b0;
        rst_n   = 1'b0;
        s_valid = 1'b0;
        s_data  = {WIDTH{1'b0}};
        m_ready = 1'b0;
        qh = 0;
        qt = 0;

        $dumpfile("dump.vcd");
        $dumpvars(0, tb_hs_reg);

        $display("");
        $display("============================================================");
        $display("  练习 03：valid/ready 握手寄存器 自检");
        $display("============================================================");

        //=========================================================
        // 第一部分：定向测试
        //=========================================================
        $display("[定向1] 复位后 m_valid 应为 0，s_ready 应为 1");
        do_reset;
        check_m_valid(0);
        check_s_ready(1);

        $display("[定向2] 上游送一个数据，下游堵住（m_ready=0）");
        @(negedge clk);
        s_valid = 1'b1;
        s_data  = 8'hA5;
        m_ready = 1'b0;
        check_s_ready(1);               // 输出寄存器还空着，应该能收
        @(posedge clk);                 // 数据被锁进输出寄存器
        @(negedge clk);
        check_m_valid(1);
        check_s_ready(0);               // 输出满了且下游不收，不能再收
        checks = checks + 1;
        if (m_data !== 8'hA5) begin
            errors = errors + 1;
            $display("  [FAIL] t=%0t  m_data=%02h，期望 A5", $time, m_data);
        end

        $display("[定向3] 背压保持：s_valid=0，等 3 个周期，数据不能丢");
        s_valid = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        check_m_valid(1);
        check_s_ready(0);
        checks = checks + 1;
        if (m_data !== 8'hA5) begin
            errors = errors + 1;
            $display("  [FAIL] t=%0t  背压期间 m_data 变成了 %02h，期望保持 A5",
                     $time, m_data);
        end

        $display("[定向4] 下游取走（m_ready=1），m_valid 应回到 0");
        @(negedge clk);
        m_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        check_m_valid(0);
        check_s_ready(1);
        m_ready = 1'b0;

        $display("[定向5] 一拍顶一拍：输出满且下游能收时，同一周期可以换新数据");
        @(negedge clk);
        s_valid = 1'b1;
        s_data  = 8'h11;
        m_ready = 1'b0;
        @(posedge clk);
        @(negedge clk);
        check_m_valid(1);
        // 现在输出满，下游能收，同时上游送新数据
        s_data  = 8'h22;
        m_ready = 1'b1;
        @(negedge clk);
        check_s_ready(1);               // 下游能收 -> 可以接新数据
        @(posedge clk);
        @(negedge clk);
        checks = checks + 1;
        if (m_data !== 8'h22) begin
            errors = errors + 1;
            $display("  [FAIL] t=%0t  一拍顶一拍后 m_data=%02h，期望 22", $time, m_data);
        end
        check_m_valid(1);
        s_valid = 1'b0;
        m_ready = 1'b0;
        // 清干净
        @(negedge clk);
        m_ready = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        m_ready = 1'b0;
        check_m_valid(0);

        //=========================================================
        // 第二部分：随机激励压力测试
        //=========================================================
        $display("[随机] 500 个周期的随机 valid/ready 组合");
        qh = 0;
        qt = 0;
        for (k = 0; k < 500; k = k + 1) begin
            @(negedge clk);
            r = $random;
            s_valid = r[0] | r[2];              // 约 75% 的概率有数据
            if (s_valid) begin
                s_data = (r >> 8) & 8'hFF;
            end
            m_ready = r[1];                     // 约 50% 的概率下游能收
            sample_cycle;
        end

        $display("[随机] 收尾：停止上游，把在途数据排空");
        for (i = 0; i < 4; i = i + 1) begin
            @(negedge clk);
            s_valid = 1'b0;
            m_ready = 1'b1;
            sample_cycle;
        end
        @(negedge clk);
        m_ready = 1'b0;
        check_m_valid(0);

        $display("");
        $display("  接收 %0d 个，输出 %0d 个", accepted, popped);
        checks = checks + 1;
        if (accepted !== popped) begin
            errors = errors + 1;
            $display("  [FAIL] 数量不一致：有数据丢失或重复");
        end

        //---------- 汇总 ----------
        $display("");
        $display("============================================================");
        $display("  检查项: %0d", checks);
        $display("  失败项: %0d", errors);
        if (errors == 0) begin
            $display("  >>> PASS：握手协议完全正确，这个模块可以用了 <<<");
        end else begin
            $display("  >>> FAIL：请根据上面的 [FAIL] 行定位问题 <<<");
            $display("  常见原因：");
            $display("    - s_ready 写成了 ~m_valid（少了 | m_ready）");
            $display("    - m_valid 用了组合赋值（违反第 5 条约束）");
            $display("    - 忘了在 s_ready && s_valid 时才更新 m_data");
        end
        $display("============================================================");
        $display("");
        $finish;
    end

    initial begin
        #200000;
        $display("[TIMEOUT] 仿真超时：可能有信号始终为 x");
        $finish;
    end

endmodule
