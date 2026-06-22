`timescale 1ns / 1ps

`include "../rtl/adc_ctrl/spi_adc_driver.v"
`include "../rtl/adc_ctrl/oversample_filter.v"
`include "../rtl/pwm_array/hc595_driver.v"
`include "../rtl/pwm_array/pwm_array_core.v"
`include "../rtl/ultrasonic_top.v"
`include "../rtl/ultrasonic_fpga_top.v"
`include "sim_pll_stub.v"
`include "../rtl/phase_lut.v"

module tb_pwm_array_core();

    // ==========================================
    // 1. 信号声明 (对接被测模块)
    // ==========================================
    reg         clk;
    reg         rst_n;
    
    // 模拟前级传来的音频信号
    reg  [11:0] audio_in;
    reg         audio_valid;
    
    // 模拟顶层/上位机传来的控制信号
    reg  [3:0]  mode_sel;
    reg         window_en;
    
    // 输出信号接收
    wire [199:0] phase_bus;      // 从 LUT 出来的 200-bit 阵列
    wire         driver_ready;
    wire [31:0]  pwm_out_bus;
    wire         pwm_valid;

    // ==========================================
    // 2. 模块例化 (将被测模块与 LUT 连接)
    // ==========================================
    
    // 例化相位查表模块 (产生 200-bit 相位总线)
    phase_lut u_lut (
        .clk           (clk),
        .rst_n         (rst_n),
        .mode_sel      (mode_sel),
        .phase_out_bus (phase_bus)
    );

    // 假设 595 驱动一直处于就绪状态
    assign driver_ready = 1'b1;

    // 例化 核心阵列引擎 (你刚爆改完的模块)
    pwm_array_core uut (
        .clk          (clk),
        .rst_n        (rst_n),
        .audio_in     (audio_in),
        .audio_valid  (audio_valid),
        .phase_in_bus (phase_bus),
        .window_en    (window_en),
        .driver_ready (driver_ready),
        .pwm_out_bus  (pwm_out_bus),
        .pwm_valid    (pwm_valid)
    );

    // ==========================================
    // 3. 基础时钟生成 (100MHz)
    // ==========================================
    always #5 clk = ~clk;

    // ==========================================
    // 4. 模拟 40kHz 的音频数据更新节拍
    // (对应真实硬件中滤波器吐出 audio_valid 的节奏)
    // ==========================================
    reg [11:0] audio_tick_cnt;
    always @(posedge clk) begin
        if (!rst_n) begin
            audio_tick_cnt <= 0;
            audio_valid    <= 0;
        end else begin
            // 100MHz / 40kHz = 2500个周期
            if (audio_tick_cnt == 12'd2499) begin
                audio_tick_cnt <= 0;
                audio_valid    <= 1;
            end else begin
                audio_tick_cnt <= audio_tick_cnt + 1;
                audio_valid    <= 0;
            end
        end
    end

    // ==========================================
    // 🌟 5. 核心测试激励流程 (Test Sequence)
    // ==========================================
    initial begin
        // 配置波形抓取 (配合你的 run_sim.sh)
        $dumpfile("tb_pwm_array_core.vcd"); 
        $dumpvars(0, tb_pwm_array_core);

        // 初始状态设定
        clk       = 0;
        rst_n     = 0;
        audio_in  = 12'd2048; // 默认静音点
        mode_sel  = 4'd0;     // 模式 0: 不偏转
        window_en = 1'b0;     // 初始关闭加窗
        
        // 释放复位
        #100;
        rst_n = 1;
        
        // 我们给一个相对比较满的测试音量，方便观察脉宽
        audio_in = 12'd3500; 

        // ----------------------------------------------------
        // 测试阶段 1：观察默认行为 (无偏转，无加窗)
        // 预期现象：所有 25 根 PWM 线波形必须完全重合，且脉宽一样。
        // ----------------------------------------------------
        $display(">> Stage 1: Mode 0 (No Steer), Window OFF");
        #200000; // 跑 200us (约 8 个超声波周期)

        // ----------------------------------------------------
        // 测试阶段 2：激活汉明窗 (无偏转，有加窗)
        // 预期现象：所有线起步依然对齐，但高电平持续时间不同。
        //         [0]号线脉宽最窄，[12]号线(中心点)脉宽最宽！
        // ----------------------------------------------------
        $display(">> Stage 2: Mode 0 (No Steer), Window ON!");
        window_en = 1'b1;
        #200000;

        // ----------------------------------------------------
        // 测试阶段 3：启动波束偏转 (左偏 15度，有加窗)
        // 预期现象：[0]~[24] 线的上升沿不再对齐，出现阶梯状的错位时间差。
        // ----------------------------------------------------
        $display(">> Stage 3: Mode 2 (Steer Left 15 deg), Window ON");
        mode_sel = 4'd2; // 切换 LUT
        #200000;
        
        // ----------------------------------------------------
        // 测试阶段 4：模拟音量变化
        // 预期现象：占空比缩小，错位依然保持。
        // ----------------------------------------------------
        $display(">> Stage 4: Volume Down");
        audio_in = 12'd1000; 
        #200000;

        $display(">> Simulation Finished Successfully!");
        $finish;
    end

endmodule

// ./scripts/run_sim.sh rtl/pwm_array/pwm_array_core.v tb/tb_pwm_array_core.sv tb_pwm_array_core