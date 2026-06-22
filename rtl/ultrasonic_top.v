`timescale 1ns / 1ps

module ultrasonic_top (
    // 基础时钟复位 (由外部 Top 传入的 100MHz)
    input  wire         clk,           
    input  wire         rst_n,

    // 🎛️ 控制接口：对接外部 Top 传来的串口解析数据
    input  wire [3:0]   ctrl_volume,   // 音量档位 (0~15)
    input  wire [3:0]   ctrl_mode,     // 相控阵模式 (0~3)
    input  wire         ctrl_window,   // 一键加窗使能

    // 🎤 物理接口：对接硬件 ADC (SPI 接口)
    input  wire         adc_sdata,
    output wire         adc_sclk,
    output wire         adc_cs_n,

    // 🔊 物理接口：对接后级 595 移位寄存器阵列 (四线并发)
    output wire         ds1,
    output wire         ds2,
    output wire         ds3,
    output wire         ds4,
    output wire         shcp,
    output wire         stcp,
    output wire         oe_n
);

    // =========================================================
    // 内部互联总线 (Wires)
    // =========================================================
    wire [7:0]   raw_adc_data;
    wire         raw_adc_valid;
    
    wire [7:0]   linear_gain;
    
    wire [11:0]  filtered_audio;
    wire         filtered_valid;
    
    wire [199:0] phase_bus;
    
    wire [31:0]  pwm_out_bus;
    wire         pwm_valid;
    wire         driver_ready;

    // =========================================================
    // 1. ADC 物理驱动模块
    // =========================================================
    spi_adc_driver u_adc_drvr (
        .clk        (clk),
        .rst_n      (rst_n),
        .adc_sdata  (adc_sdata),
        .adc_sclk   (adc_sclk),
        .adc_cs_n   (adc_cs_n),
        .adc_data   (raw_adc_data),
        .adc_valid  (raw_adc_valid)
    );

    // =========================================================
    // 2. 音量分贝转换查表器
    // =========================================================
    gain_lut u_gain_lut (
        .clk         (clk),
        .rst_n       (rst_n),
        .vol_idx     (ctrl_volume),
        .gain_factor (linear_gain)
    );

    // =========================================================
    // 3. 过采样与低通滤波器 (前级数字功放)
    // =========================================================
    oversample_filter u_filter (
        .clk        (clk),
        .rst_n      (rst_n),
        .gain       (linear_gain),
        .adc_data   (raw_adc_data),
        .adc_valid  (raw_adc_valid),
        .audio_out  (filtered_audio),
        .audio_valid(filtered_valid)
    );

    // =========================================================
    // 4. 相控阵聚焦/偏转查表器 (时空控制器)
    // =========================================================
    phase_lut u_phase_lut (
        .clk           (clk),
        .rst_n         (rst_n),
        .mode_sel      (ctrl_mode),
        .phase_out_bus (phase_bus)
    );

    // =========================================================
    // 5. 25路相控阵 PWM 核心生成引擎
    // =========================================================
    pwm_array_core u_pwm_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .audio_in     (filtered_audio),
        .audio_valid  (filtered_valid),
        .phase_in_bus (phase_bus),
        .window_en    (ctrl_window),
        .driver_ready (driver_ready),
        .pwm_out_bus  (pwm_out_bus),
        .pwm_valid    (pwm_valid)
    );

    // =========================================================
   // =========================================================
    // 6. 后级 595 硬件高速发送驱动 (4组并发发往探头板)
    // =========================================================
    hc595_parallel_driver u_595_drvr (
        .clk          (clk),
        .rst_n        (rst_n),
        
        // 🌟 完美对齐你队友真实的端口名
        .valid        (pwm_valid),     // 对接 PWM 核心的数据有效信号
        .data_in      (pwm_out_bus),   // 对接 PWM 核心的 32 位方波总线
        .tx_en        (1'b1),          // 全局发送使能：给 1 强行拉高，让它火力全开
        .ready        (driver_ready),  // 接收 595 吐出的就绪信号，反馈给 PWM 核心
        
        .ds1          (ds1),
        .ds2          (ds2),
        .ds3          (ds3),
        .ds4          (ds4),
        .shcp         (shcp),
        .stcp         (stcp),
        .oe_n         (oe_n)
    );

endmodule