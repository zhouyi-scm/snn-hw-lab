//=============================================================================
// 练习 01 自检测试平台 —— 不要修改本文件
//-----------------------------------------------------------------------------
// 它内部维护一个"软件参考模型"（一个用数组实现的理想 FIFO），
// 每一步都拿你写的硬件行为和参考模型比对，不一致就打印 [FAIL]。
//
// 一共 9 个测试阶段，覆盖：
//   复位 / 连续写入 / 顺序读出 / 空读 / 填满 / 满时写 / 全部读出 /
//   指针回绕压力 / 同时读写
//=============================================================================

`timescale 1ns/1ps

module tb_fifo;

    localparam WIDTH = 8;
    localparam DEPTH = 16;
    localparam MSIZE = 1024;        // 参考模型队列大小（2 的幂）

    reg              clk;
    reg              rst_n;
    reg              wr_en;
    reg  [WIDTH-1:0] din;
    wire             full;
    reg              rd_en;
    wire [WIDTH-1:0] dout;
    wire             empty;
    wire [7:0]       count;

    integer errors = 0;
    integer checks = 0;

    // ---- 软件参考模型 ----
    reg [WIDTH-1:0] model [0:MSIZE-1];
    integer m_head;
    integer m_tail;

    integer i;
    reg [WIDTH-1:0] dout_hold;

    fifo #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .wr_en (wr_en),
        .din   (din),
        .full  (full),
        .rd_en (rd_en),
        .dout  (dout),
        .empty (empty),
        .count (count)
    );

    always #5 clk = ~clk;           // 100 MHz

    //=========================================================================
    // 基本操作任务
    //=========================================================================

    task do_reset;
        begin
            rst_n = 1'b0;
            wr_en = 1'b0;
            rd_en = 1'b0;
            din   = {WIDTH{1'b0}};
            repeat (3) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
            @(negedge clk);
            m_head = 0;
            m_tail = 0;
        end
    endtask

    // 写入一个数据，并同步更新参考模型
    task push;
        input [WIDTH-1:0] d;
        begin
            @(negedge clk);
            wr_en = 1'b1;
            din   = d;
            @(posedge clk);                     // DUT 在这一刻采样
            model[m_tail[9:0]] = d;
            m_tail = m_tail + 1;
            @(negedge clk);
            wr_en = 1'b0;
        end
    endtask

    // 读出一个数据：先检查队首 dout，再发 rd_en
    task pop_check;
        begin
            @(negedge clk);
            checks = checks + 1;
            if (dout !== model[m_head[9:0]]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  队首 dout=%0d，期望 %0d",
                         $time, dout, model[m_head[9:0]]);
            end
            rd_en = 1'b1;
            @(posedge clk);
            m_head = m_head + 1;
            @(negedge clk);
            rd_en = 1'b0;
        end
    endtask

    task check_count;
        input integer exp;
        begin
            checks = checks + 1;
            if (count !== exp[7:0]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  count=%0d，期望 %0d", $time, count, exp);
            end
        end
    endtask

    task check_empty;
        input integer exp;
        begin
            checks = checks + 1;
            if (empty !== exp[0]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  empty=%b，期望 %b", $time, empty, exp[0]);
            end
        end
    endtask

    task check_full;
        input integer exp;
        begin
            checks = checks + 1;
            if (full !== exp[0]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  full=%b，期望 %b", $time, full, exp[0]);
            end
        end
    endtask

    //=========================================================================
    // 主流程
    //=========================================================================
    initial begin
        clk   = 1'b0;
        rst_n = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        din   = {WIDTH{1'b0}};

        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fifo);

        $display("");
        $display("============================================================");
        $display("  练习 01：同步 FIFO 自检");
        $display("============================================================");

        //---------- 阶段 1 ----------
        $display("[阶段1] 复位后的初始状态");
        do_reset;
        check_empty(1);
        check_full(0);
        check_count(0);

        //---------- 阶段 2 ----------
        $display("[阶段2] 连续写入 5 个数据");
        for (i = 0; i < 5; i = i + 1) begin
            push(i[WIDTH-1:0] + 8'd10);
        end
        check_count(5);
        check_empty(0);
        check_full(0);

        //---------- 阶段 3 ----------
        $display("[阶段3] 读出 5 个，检查 FIFO 顺序（先进先出）");
        for (i = 0; i < 5; i = i + 1) begin
            pop_check;
        end
        check_count(0);
        check_empty(1);

        //---------- 阶段 4 ----------
        $display("[阶段4] 空读：rd_en 拉高但 FIFO 为空，应被忽略");
        dout_hold = dout;
        @(negedge clk);
        rd_en = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rd_en = 1'b0;
        check_count(0);
        check_empty(1);
        checks = checks + 1;
        if (dout !== dout_hold) begin
            errors = errors + 1;
            $display("  [FAIL] t=%0t  空读时 dout 发生了变化", $time);
        end

        //---------- 阶段 5 ----------
        $display("[阶段5] 填满 %0d 个数据", DEPTH);
        for (i = 0; i < DEPTH; i = i + 1) begin
            push(i[WIDTH-1:0]);
        end
        check_count(DEPTH);
        check_full(1);
        check_empty(0);

        //---------- 阶段 6 ----------
        $display("[阶段6] 满时继续写，应被忽略（不能覆盖已有数据）");
        @(negedge clk);
        wr_en = 1'b1;
        din   = 8'hEE;
        repeat (2) @(posedge clk);
        @(negedge clk);
        wr_en = 1'b0;
        check_count(DEPTH);
        check_full(1);

        //---------- 阶段 7 ----------
        $display("[阶段7] 全部读出，验证数据没有被 0xEE 覆盖");
        for (i = 0; i < DEPTH; i = i + 1) begin
            pop_check;
        end
        check_count(0);
        check_empty(1);
        check_full(0);

        //---------- 阶段 8 ----------
        $display("[阶段8] 指针回绕压力测试：写 8 读 8，重复 6 轮");
        for (i = 0; i < 6; i = i + 1) begin
            push(i[WIDTH-1:0] + 8'h20);
            push(i[WIDTH-1:0] + 8'h21);
            push(i[WIDTH-1:0] + 8'h22);
            push(i[WIDTH-1:0] + 8'h23);
            push(i[WIDTH-1:0] + 8'h24);
            push(i[WIDTH-1:0] + 8'h25);
            push(i[WIDTH-1:0] + 8'h26);
            push(i[WIDTH-1:0] + 8'h27);
            pop_check;
            pop_check;
            pop_check;
            pop_check;
            pop_check;
            pop_check;
            pop_check;
            pop_check;
        end
        check_count(0);
        check_empty(1);

        //---------- 阶段 9 ----------
        $display("[阶段9] 同时读写：count 必须保持不变");
        for (i = 0; i < 4; i = i + 1) begin
            push(i[WIDTH-1:0]);
        end
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk);
            checks = checks + 1;
            if (dout !== model[m_head[9:0]]) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  同时读写前 dout=%0d，期望 %0d",
                         $time, dout, model[m_head[9:0]]);
            end
            wr_en = 1'b1;
            din   = 8'h80 + i[7:0];
            rd_en = 1'b1;
            @(posedge clk);
            model[m_tail[9:0]] = 8'h80 + i[7:0];
            m_tail = m_tail + 1;
            m_head = m_head + 1;
            @(negedge clk);
            wr_en = 1'b0;
            rd_en = 1'b0;
            checks = checks + 1;
            if (count !== 4) begin
                errors = errors + 1;
                $display("  [FAIL] t=%0t  同时读写时 count=%0d，期望 4", $time, count);
            end
        end
        while (m_head < m_tail) begin
            pop_check;
        end

        //---------- 汇总 ----------
        $display("");
        $display("============================================================");
        $display("  检查项: %0d", checks);
        $display("  失败项: %0d", errors);
        if (errors == 0) begin
            $display("  >>> PASS：全部通过，这个 FIFO 可以用了 <<<");
        end else begin
            $display("  >>> FAIL：请根据上面的 [FAIL] 行定位问题 <<<");
            $display("  提示：先跑 bash run.sh wave 打开波形，看 wptr/rptr/count");
        end
        $display("============================================================");
        $display("");
        $finish;
    end

    // 超时保护：防止某个信号一直是 x 导致仿真卡死
    initial begin
        #200000;
        $display("[TIMEOUT] 仿真超时：可能有信号始终为 x，或存在组合环");
        $finish;
    end

endmodule
