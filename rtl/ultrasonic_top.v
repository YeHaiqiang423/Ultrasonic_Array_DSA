`timescale 1ns / 1ps

module ultrasonic_top (
    input  wire         clk,           
    input  wire         rst_n,

    // 控制接口 (来自串口解析)
    input  wire [3:0]   ctrl_volume,   // 音量档位 (0~15)
    input  wire [3:0]   ctrl_mode,     // 相控阵模式 (0~3)
    input  wire         ctrl_window,   // 一键加窗使能

    // ADC 物理接口 (SPI)
    input  wire         adc_sdata,
    output wire         adc_sclk,
    output wire         adc_cs_n,

    // 74HC595 物理接口 (四线并发)
    output wire         ds1,
    output wire         ds2,
    output wire         ds3,
    output wire         ds4,
    output wire         shcp,
    output wire         stcp,
    output wire         oe_n
);

    // 内部互联总线
    wire [7:0]   raw_adc_data;
    wire         raw_adc_valid;
    
    wire [7:0]   linear_gain;
    
    wire [11:0]  filtered_audio;
    wire         filtered_valid;
    
    wire [199:0] phase_bus;
    
    wire [31:0]  pwm_out_bus;
    wire         pwm_valid;
    wire         driver_ready;

    // 1. ADC 物理驱动模块
    spi_adc_driver u_adc_drvr (
        .clk        (clk),
        .rst_n      (rst_n),
        .adc_sdata  (adc_sdata),
        .adc_sclk   (adc_sclk),
        .adc_cs_n   (adc_cs_n),
        .adc_data   (raw_adc_data),
        .adc_valid  (raw_adc_valid)
    );

    // 2. 音量分贝转换查表器
    gain_lut u_gain_lut (
        .clk         (clk),
        .rst_n       (rst_n),
        .vol_idx     (ctrl_volume),
        .gain_factor (linear_gain)
    );

    // 3. 过采样与低通滤波器 (数字前级功放)
    oversample_filter u_filter (
        .clk        (clk),
        .rst_n      (rst_n),
        .gain       (linear_gain),
        .adc_data   (raw_adc_data),
        .adc_valid  (raw_adc_valid),
        .audio_out  (filtered_audio),
        .audio_valid(filtered_valid)
    );

    // 4. 相控阵聚焦/偏转查表器
    phase_lut u_phase_lut (
        .clk           (clk),
        .rst_n         (rst_n),
        .mode_sel      (ctrl_mode),
        .phase_out_bus (phase_bus)
    );

    // 5. 25 路相控阵 PWM 核心生成引擎
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

    // 6. 74HC595 高速并行驱动 (4 组并发输出至探头板)
    hc595_parallel_driver u_595_drvr (
        .clk          (clk),
        .rst_n        (rst_n),
        
        .valid        (pwm_valid),
        .data_in      (pwm_out_bus),
        .tx_en        (1'b1),          // 全局发送使能常开
        .ready        (driver_ready),
        
        .ds1          (ds1),
        .ds2          (ds2),
        .ds3          (ds3),
        .ds4          (ds4),
        .shcp         (shcp),
        .stcp         (stcp),
        .oe_n         (oe_n)
    );

endmodule