`timescale 1ns / 1ps

module ultrasonic_top (
    input  wire clk,         // 系统主时钟 100MHz (Zynq PL 侧)
    input  wire rst_n,       // 系统异步复位信号，低电平有效
    
    // 物理层输入端口 -> 桥接至 XCS7478E ADC 芯片
    output wire adc_cs_n,
    output wire adc_sclk,
    input  wire adc_sdata,
    
    // 物理层输出端口 -> 桥接至 74HC595 及 UCC 驱动阵列
    output wire shcp,
    output wire stcp,
    output wire ds1, ds2, ds3, ds4,
    output wire oe_n
);
    // 内部信号互联：各功能模块数据流通路
    wire [7:0]  raw_adc_data;
    wire        raw_adc_valid;
    
    wire [11:0] filtered_audio;
    wire        filtered_audio_valid;
    
    wire [31:0] internal_pwm_bus;
    wire        internal_pwm_valid;
    wire        internal_driver_ready;

    // 模块 1：ADC 驱动接口 (1 MSPS 高速 SPI 读取)
    spi_adc_driver u_spi_driver (
        .clk        (clk),
        .rst_n      (rst_n),
        .adc_cs_n   (adc_cs_n),
        .adc_sclk   (adc_sclk),
        .adc_sdata  (adc_sdata),
        .adc_data   (raw_adc_data),   // 输出 8-bit 原始数据
        .adc_valid  (raw_adc_valid)
    );

    // 模块 2：过采样滤波模块 (数据降噪与位宽扩展)
    oversample_filter u_filter (
        .clk        (clk),
        .rst_n      (rst_n),
        .adc_data   (raw_adc_data),
        .adc_valid  (raw_adc_valid),
        .audio_out  (filtered_audio), // 输出 12-bit 滤波数据
        .audio_valid(filtered_audio_valid)
    );

    // 模块 3：PWM 阵列核心调度器 
    pwm_array_core u_pwm_core (
        .clk         (clk),
        .rst_n       (rst_n),
        .audio_in    (filtered_audio),       // 输入 12-bit 音频数据
        .audio_valid (filtered_audio_valid), 
        
        .driver_ready(internal_driver_ready),
        .pwm_out_bus (internal_pwm_bus),
        .pwm_valid   (internal_pwm_valid)
    );

    // 模块 4：底层 74HC595 移位寄存器并行驱动接口
    hc595_parallel_driver u_driver (
        .clk         (clk),
        .rst_n       (rst_n),
        .valid       (internal_pwm_valid),
        .data_in     (internal_pwm_bus),
        .tx_en       (1'b1), // 默认使能发波控制端
        .ready       (internal_driver_ready),
        
        .shcp        (shcp),
        .stcp        (stcp),
        .ds1         (ds1),
        .ds2         (ds2),
        .ds3         (ds3),
        .ds4         (ds4),
        .oe_n       (oe_n)
    );

endmodule

// 仿真大吉，上板大吉