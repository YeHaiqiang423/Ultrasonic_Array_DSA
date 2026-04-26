`timescale 1ns / 1ps

`include "../rtl/pwm_array/hc595_driver.v"
`include "../rtl/pwm_array/pwm_array_core.v"
`include "../rtl/ultrasonic_top.v"

module tb_ultrasonic_top();

    // ==========================================
    // 1. 信号定义
    // ==========================================
    logic        clk;
    logic        rst_n;
    logic [11:0] adc_audio_in; // 模拟 ADC 的 12-bit 信号
    
    logic        shcp, stcp;
    logic        ds1, ds2, ds3, ds4;
    logic        ucc_en;

    // ==========================================
    // 2. 例化被测顶层模块
    // ==========================================
    ultrasonic_top u_top (
        .clk         (clk),
        .rst_n       (rst_n),
        .adc_audio_in(adc_audio_in),
        .shcp        (shcp),
        .stcp        (stcp),
        .ds1         (ds1),
        .ds2         (ds2),
        .ds3         (ds3),
        .ds4         (ds4),
        .ucc_en      (ucc_en)
    );

    // ==========================================
    // 3. 产生 100MHz 系统时钟 (10ns 周期)
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ==========================================
    // 4. SV 黑魔法：模拟 1kHz 正弦波 ADC 采样
    // ==========================================
    // 假设 ADC 的采样率我们定为 40kHz (每 25us 采样一次，契合超声波载波)
    real PI = 3.141592653589793;
    real phase = 0.0;
    real sin_out;
    
    initial begin
        adc_audio_in = 12'd2048; // 上电默认静音 (12位的中点)
        
        #50000; // 等复位稳定
        
        forever begin
            #25000; // 等待 25000ns (25us)，模拟 ADC 转换周期
            
            // 算相位：1kHz 正弦波在 40kHz 采样率下，每次步进 1/40 个周期
            phase = phase + (2.0 * PI * 1000.0 / 40000.0);
            if (phase >= 2.0 * PI) begin
                phase = phase - 2.0 * PI;
            end
            
            // 调用 SV 内部的 $sin 算出 -1.0 到 1.0 的小数
            sin_out = $sin(phase);
            
            // 核心映射：把 [-1.0 ~ 1.0] 放大平移到 [0 ~ 4095]
            // $rtoi 是 Real TO Integer 的缩写
            adc_audio_in = $rtoi((sin_out + 1.0) * 2047.5);
        end
    end

    // ==========================================
    // 5. 主控制流程
    // ==========================================
    initial begin
        $dumpfile("tb_ultrasonic_top.vcd");
        $dumpvars(0, tb_ultrasonic_top);
        
        rst_n = 0;
        #100;
        rst_n = 1;
        
        // 我们要测 1kHz 音频，它的一个周期是 1ms。
        // 这里我们跑 3ms，足够在波形上看到 3 个极其完美的正弦包络！
        #3000000; 
        
        $display("✅ 1kHz 正弦波 ADC 采样与 Dithering 调制仿真完美结束！");
        $finish;
    end

endmodule