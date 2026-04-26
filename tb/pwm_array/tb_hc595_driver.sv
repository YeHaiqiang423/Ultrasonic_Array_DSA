`timescale 1ns / 1ps

module tb_hc595_driver();

    // SV 信号定义
    logic        clk;
    logic        rst_n;
    logic        valid;
    logic [31:0] data_in;
    logic        tx_en;     // 新增：发送使能
    
    logic        ready;
    logic        shcp;
    logic        stcp;
    logic        ds1, ds2, ds3, ds4; // 新增：4根独立数据线
    logic        ucc_en;

    // 例化待测模块
    hc595_driver u_driver (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .data_in(data_in),
        .tx_en(tx_en),
        .ready(ready),
        .shcp(shcp),
        .stcp(stcp),
        .ds1(ds1), .ds2(ds2), .ds3(ds3), .ds4(ds4),
        .ucc_en(ucc_en)
    );

    // 产生 100MHz 系统时钟 (周期 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // 测试主流程
    initial begin
        // 开启 FST 波形转储
        $dumpfile("tb_hc595_driver.vcd");
        $dumpvars(0, tb_hc595_driver);

        // 1. 初始化
        rst_n   = 0;
        valid   = 0;
        data_in = 32'd0;
        tx_en   = 0;       // 默认不开火
        #20;
        rst_n   = 1;
        #20;

        // 2. 发送第一包数据：全 1 (测试引脚全开)
        @(posedge clk);
        data_in = 32'hFFFF_FFFF;
        valid   = 1;
        tx_en   = 1;       // 允许 UCC 发声
        @(posedge clk);
        valid   = 0; 

        // 等待发完
        wait(ready == 1'b1);
        #50;

        // 3. 发送第二包数据：随机数测试切片是否正确！
        @(posedge clk);
        data_in = 32'hA5A5_5A5A; // 用极其规律的 1010 和 0101 测试
        valid   = 1;
        @(posedge clk);
        valid   = 0;

        wait(ready == 1'b1);
        #100;

        $display("✅ 595 驱动仿真完美结束！");
        $finish;
    end
endmodule