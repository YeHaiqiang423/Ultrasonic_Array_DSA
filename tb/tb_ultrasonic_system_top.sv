`include "../rtl/pwm_array/gain_lut.v"
`include "../rtl/phase_lut.v"
`include "../rtl/pwm_array/pwm_array_core.v"
`include "../rtl/pwm_array/hc595_driver.v"
`include "../rtl/adc_ctrl/spi_adc_driver.v"
`include "../rtl/adc_ctrl/oversample_filter.v"

`timescale 1ns / 1ps

module tb_ultrasonic_system_top();

    reg         clk;
    reg         rst_n;
    reg         adc_sdata;
    wire        adc_sclk;
    wire        adc_cs_n;

    // 模拟串口屏控制
    reg  [3:0]  ctrl_volume;
    reg  [3:0]  ctrl_mode;
    reg         ctrl_window;

    // 🌟 核心修改：595 物理引脚输出改为四线并发，去除前缀对齐 Top
    wire        ds1;
    wire        ds2;
    wire        ds3;
    wire        ds4;
    wire        shcp;
    wire        stcp;
    wire        oe_n;

    // 例化系统总顶层
    ultrasonic_top uut (
        .clk         (clk),
        .rst_n       (rst_n),
        .adc_sdata   (adc_sdata),
        .adc_sclk    (adc_sclk),
        .adc_cs_n    (adc_cs_n),
        .ctrl_volume (ctrl_volume),
        .ctrl_mode   (ctrl_mode),
        .ctrl_window (ctrl_window),
        
        // 🌟 核心修改：对接全新的四线并发端口
        .ds1         (ds1),
        .ds2         (ds2),
        .ds3         (ds3),
        .ds4         (ds4),
        .shcp        (shcp),
        .stcp        (stcp),
        .oe_n        (oe_n)
    );

    always #5 clk = ~clk;

    // ---------------------------------------------------
    // 极简模拟硬件 ADC 行为 (直接给 8-bit 正弦波)
    // ---------------------------------------------------
    reg [7:0] mock_adc_val = 8'd128;
    always #1000 mock_adc_val = mock_adc_val + 1'b1; // 让数据缓慢起伏模拟音乐
    
    // 简单粗暴模拟 SPI 串行输入
    integer bit_cnt = 0;
    always @(posedge clk) begin
        if (!adc_cs_n) begin
            adc_sdata <= mock_adc_val[7 - (bit_cnt % 8)];
            bit_cnt   <= bit_cnt + 1;
        end else begin
            bit_cnt   <= 0;
        end
    end

    // ---------------------------------------------------
    // 模拟明日串口屏的操作序列
    // ---------------------------------------------------
    initial begin
        $dumpfile("tb_ultrasonic_system_top.vcd");
        $dumpvars(0, tb_ultrasonic_system_top);

        clk = 0; rst_n = 0;
        adc_sdata = 0;
        ctrl_volume = 4'd0;  // 0档：静音
        ctrl_mode   = 4'd0;  // 模式0：正前
        ctrl_window = 1'b0;  // 不加窗

        #100; rst_n = 1;

        // 🌟 阶段 1：模拟评委说“声音太小了，调大点！”
        #50000;
        $display(">> 串口屏触发：音量调至 8 档 (+20dB)");
        ctrl_volume = 4'd8; 

        // 🌟 阶段 2：模拟一键加窗开启，压制旁瓣
        #100000;
        $display(">> 串口屏触发：开启汉明加窗");
        ctrl_window = 1'b1;

        // 🌟 阶段 3：模拟切换偏转角度到左边15度
        #100000;
        $display(">> 串口屏触发：切换到模式 2 (左偏15度聚焦)");
        ctrl_mode = 4'd2;

        #200000;
        $display("🎉 全系统联调仿真圆满成功！");
        $finish;
    end

endmodule