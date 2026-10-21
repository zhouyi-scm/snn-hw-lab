//=============================================================================
// 练习 02 自检测试平台 —— 不要修改本文件
//-----------------------------------------------------------------------------
// 它用整数在软件里复现 LIF 的定点行为，每个使能周期都和你的硬件比对。
//
// 特别注意"阶段 5/6 的负数用例"：那是专门用来抓 >> 和 >>> 混用的。
//=============================================================================

`timescale 1ns/1ps

module tb_lif_leak;

    localparam WIDTH = 16;
    localparam SHIFT = 4;

    reg                     clk;
    reg                     rst_n;
    reg                     en;
    reg  signed [WIDTH-1:0] i_in;
    wire signed [WIDTH-1:0] v_out;

    integer errors = 0;
    integer checks = 0;
    integer model_v;            // 参考模型（32 位整数，够用）

    lif_leak #(
        .WIDTH (WIDTH),
        .SHIFT (SHIFT)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .i_in  (i_in),
        .v_out (v_out)
    );

    always #5 clk = ~clk;       // 100 MHz

    //-------------------------------------------------------------------------
    // 模拟 >>> SHIFT 的精确语义：向负无穷取整
    //   Verilog 的 >>> 对负数等价于 floor(v / 2^SHIFT)，
    //   而整数除法 / 是向零截断的，所以负数要单独处理。
    //-------------------------------------------------------------------------
    function integer ashr;
        input integer v;
        integer divisor;
        begin
            divisor = (1 << SHIFT);
            if (v >= 0) begin
                ashr = v / divisor;
            end else begin
                ashr = -(((-v) + (divisor - 1)) / divisor);
            end
        end
    endfunction

    task do_reset;
        begin
            rst_n  = 1'b0;
            en     = 1'b0;
            i_in   = {WIDTH{1'b0}};
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n  = 1'b1;
            @(negedge clk);
            model_v = 0;
        end
    endtask

    // 一个"使能"周期：注入 cur
    task step_en;
        input integer cur;
        begin
            @(negedge clk);
            en   = 1'b1;
            i_in = cur[WIDTH-1:0];
            model_v = model_v - ashr(model_v) + cur;
            @(posedge clk);
            @(negedge clk);
            en = 1'b0;
            checks = checks + 1;
            if (v_out !== model_v) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  en=1 时 v_out=%0d，期望 %0d",
                         $time, v_out, model_v);
            end
        end
    endtask

    // 一个"不使能"周期：i_in 变化但 en=0，v_out 必须一动不动
    task step_disabled;
        input integer cur;
        begin
            @(negedge clk);
            en   = 1'b0;
            i_in = cur[WIDTH-1:0];
            @(posedge clk);
            @(negedge clk);
            checks = checks + 1;
            if (v_out !== model_v) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  en=0 时 v_out 变了：%0d，期望保持 %0d",
                         $time, v_out, model_v);
            end
        end
    endtask

    integer i;

    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        en    = 1'b0;
        i_in  = {WIDTH{1'b0}};

        $dumpfile("dump.vcd");
        $dumpvars(0, tb_lif_leak);

        $display("");
        $display("============================================================");
        $display("  练习 02：带泄漏的膜电位累加器 自检");
        $display("============================================================");

        //---------- 阶段 1 ----------
        $display("[阶段1] 复位后膜电位应为 0");
        do_reset;
        checks = checks + 1;
        if (v_out !== 0) begin
            errors = errors + 1;
            $display("  [FAIL] t=%0t  复位后 v_out=%0d，期望 0", $time, v_out);
        end

        //---------- 阶段 2 ----------
        $display("[阶段2] 单次注入 100（第一次衰减前 v=0，所以结果应为 100）");
        step_en(100);

        //---------- 阶段3 ----------
        $display("[阶段3] 连续注入 50 三次（每次都会先泄漏再累加）");
        step_en(50);
        step_en(50);
        step_en(50);

        //---------- 阶段 4 ----------
        $display("[阶段4] ★ 关键：en=0 时无论 i_in 怎么变，v 必须保持不变");
        step_disabled(999);
        step_disabled(999);
        step_disabled(-999);
        step_disabled(0);

        //---------- 阶段 5 ----------
        $display("[阶段5] 自然衰减：en=1 但 i_in=0，重复 20 次");
        for (i = 0; i < 20; i = i + 1) begin
            step_en(0);
        end

        //---------- 阶段 6 ----------
        $display("[阶段6] 负输入注入");
        step_en(-200);
        step_en(-100);

        //---------- 阶段 7 ----------
        $display("[阶段7] ★ 负数衰减：专门检查你用的是 >>> 还是 >>  （重复 10 次）");
        for (i = 0; i < 10; i = i + 1) begin
            step_en(0);
        end

        //---------- 阶段 8 ----------
        $display("[阶段8] 长时间静默：en=0 持续 50 个周期");
        for (i = 0; i < 50; i = i + 1) begin
            step_disabled(0);
        end

        //---------- 阶段 9 ----------
        $display("[阶段9] 衰减趋势检查（应随时间趋近于 0）");
        $display("        当前 v_out = %0d", v_out);
        checks = checks + 1;
        if ((v_out > 200) || (v_out < -200)) begin
            errors = errors + 1;
            $display("  [FAIL] 经历了 50 个周期的泄漏后，膜电位仍未回到 0 附近");
        end

        //---------- 汇总 ----------
        $display("");
        $display("============================================================");
        $display("  检查项: %0d", checks);
        $display("  失败项: %0d", errors);
        if (errors == 0) begin
            $display("  >>> PASS：泄漏 + 累加 + 事件驱动保持，全部正确 <<<");
            $display("  你已经实现了一个 LIF 神经元的计算核心。");
        end else begin
            $display("  >>> FAIL：请根据上面的 [FAIL] 行定位问题 <<<");
            $display("  常见原因：");
            $display("    - 用了 = 而不是 <=（时序逻辑必须用非阻塞赋值）");
            $display("    - 用了 >> 而不是 >>>（负数会算错）");
            $display("    - 忘了声明 signed");
            $display("    - en=0 的分支写了赋值（应该什么都不做）");
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
