// `timescale 1ns / 1ps

// module ultrasonic_fpga_top (
//     input  wire sys_clk_50m, 
//     input  wire sys_rst_n,   
//     output wire pl_led1,     

//     // ADC 物理接口（暂时不用，保持声明不报错）
//     output wire adc_cs_n,
//     output wire adc_sclk,
//     input  wire adc_sdata,
    
//     // 🌟 595 接口
//     output wire shcp,
//     output wire stcp,
//     output wire ds1, ds2, ds3, ds4,
//     output wire oe_n    // 🌟 替换为 oe_n
// );

//     wire clk_100m;
//     wire locked;

//     // 1. 例化时钟 IP
//     ClockingWizard_clk_wiz_0_0 u_pll (
//         .clk_in1  (sys_clk_50m),
//         .resetn   (sys_rst_n),
//         .clk_out1 (clk_100m),
//         .locked   (locked)
//     );

//     wire core_rst_n = sys_rst_n & locked;
//     assign pl_led1 = ~locked; 
//     // ==========================================
//     // 🐢 测试用：全局时钟降速 (时间膨胀)
//     // ==========================================
//     // SLOW_FACTOR = 100: 示波器挡位 (100MHz -> 1MHz，SHCP 变成 500kHz)
//     // SLOW_FACTOR = 10000000: 肉眼挡位 (100MHz -> 10Hz，你能用肉眼看 595 逐位移位！)
//     localparam SLOW_FACTOR = 32'd100; 
    
//     reg [31:0] slow_cnt;
//     reg        clk_slow_reg;

//     always @(posedge clk_100m or negedge core_rst_n) begin
//         if (!core_rst_n) begin
//             slow_cnt     <= 32'd0;
//             clk_slow_reg <= 1'b0;
//         end else if (slow_cnt >= (SLOW_FACTOR / 2 - 1)) begin
//             slow_cnt     <= 32'd0;
//             clk_slow_reg <= ~clk_slow_reg;
//         end else begin
//             slow_cnt     <= slow_cnt + 1'b1;
//         end
//     end

//     // 规范的 FPGA 时钟缓冲器，将普通逻辑信号提升为全局时钟
//     wire clk_test;
//     BUFG u_bufg_test (
//         .I(clk_slow_reg),
//         .O(clk_test)
//     );
//     // ==========================================
//     // 🎯 核心测试逻辑：内部生成 1kHz 模拟音频
//     // ==========================================
    
//     reg [16:0] audio_clk_cnt;
//     reg        audio_tick; 

//     always @(posedge clk_test or negedge core_rst_n) begin
//         if (!core_rst_n) begin
//             audio_clk_cnt <= 17'd0;
//             audio_tick    <= 1'b0;
//         end else if (audio_clk_cnt == 17'd999) begin 
//             audio_clk_cnt <= 17'd0;
//             audio_tick    <= 1'b1;
//         end else begin
//             audio_clk_cnt <= audio_clk_cnt + 1'b1;
//             audio_tick    <= 1'b0;
//         end
//     end

//     reg [11:0] test_audio_data;
//     reg        up_down; 

//     always @(posedge clk_test or negedge core_rst_n) begin
//         if (!core_rst_n) begin
//             test_audio_data <= 12'd2048; 
//             up_down         <= 1'b1;
//         end else if (audio_tick) begin
//             if (up_down) begin
//                 if (test_audio_data >= 12'd4000) begin
//                     up_down <= 1'b0;
//                 end else begin
//                     test_audio_data <= test_audio_data + 12'd40; 
//                 end
//             end else begin
//                 if (test_audio_data <= 12'd100) begin
//                     up_down <= 1'b1;
//                 end else begin
//                     test_audio_data <= test_audio_data - 12'd40;
//                 end
//             end
//         end
//     end

//     wire test_audio_valid = audio_tick;

//     assign adc_cs_n = 1'b1; 
//     assign adc_sclk = 1'b0;

//     wire internal_driver_ready;
//     wire [31:0] internal_pwm_bus;
//     wire internal_pwm_valid;

//     pwm_array_core u_pwm_core (
//         .clk          (clk_test),
//         .rst_n        (core_rst_n),
//         .audio_in     (test_audio_data),  
//         .audio_valid  (test_audio_valid), 
//         .driver_ready (internal_driver_ready),
//         .pwm_out_bus  (internal_pwm_bus),
//         .pwm_valid    (internal_pwm_valid)
//     );

//     hc595_parallel_driver u_driver (
//         .clk          (clk_test),
//         .rst_n        (core_rst_n),
//         .valid        (internal_pwm_valid),
//         .data_in      (internal_pwm_bus),
//         .tx_en        (1'b1), 
//         .ready        (internal_driver_ready),
        
//         .shcp         (shcp),
//         .stcp         (stcp),
//         .ds1          (ds1),
//         .ds2          (ds2),
//         .ds3          (ds3),
//         .ds4          (ds4),
//         .oe_n         (oe_n)  // 🌟 连出 oe_n
//     );

//     // my_ila u_ila (
//     //     .clk    (clk_test),         
//     //     .probe0 (stcp),             
//     //     .probe1 (shcp),             
//     //     .probe2 (ds1),              
//     //     .probe3 (test_audio_data)   
//     // );
// endmodule


`timescale 1ns / 1ps

module ultrasonic_fpga_top (
    // ==========================================
    // 开发板板载基础接口 (Mizar Z7)
    // ==========================================
    input  wire sys_clk_50m,    // 50MHz 外部晶振输入
    input  wire sys_rst_n,      // 硬件复位按键 (低电平有效)
    output wire pl_led1,        // PLL 锁定指示灯 (高亮表示时钟正常)

    // ==========================================
    // 🎤 ADC 物理接口 -> 桥接至 XCS7478E (采集音频)
    // ==========================================
    output wire adc_cs_n,       // SPI 片选 (低电平有效)
    output wire adc_sclk,       // SPI 时钟 (1MHz ~ 20MHz)
    input  wire adc_sdata,      // SPI 串行数据输入
    
    // ==========================================
    // 🔊 595 阵列物理接口 -> 桥接至 74HC595 (发射超声波)
    // ==========================================
    output wire shcp,           // 移位时钟 (高频突发)
    output wire stcp,           // 锁存时钟 (40kHz)
    output wire ds1,            // 数据线 1 (负责阵元 0~7)
    output wire ds2,            // 数据线 2 (负责阵元 8~15)
    output wire ds3,            // 数据线 3 (负责阵元 16~23)
    output wire ds4,            // 数据线 4 (负责阵元 24, 其余拉低)
    output wire oe_n            // 595 硬件输出使能 (接 N15, 低电平有效)
);

    // 内部时钟与复位网络
    wire clk_100m;
    wire locked;

    // ==========================================
    // 1. 例化系统时钟 IP (50MHz -> 100MHz)
    // ==========================================
    ClockingWizard_clk_wiz_0_0 u_pll (
        .clk_in1  (sys_clk_50m),
        .resetn   (sys_rst_n),
        .clk_out1 (clk_100m),
        .locked   (locked)      // 当 100MHz 时钟稳定后，此信号拉高
    );

    // ==========================================
    // 2. 生成安全复位与状态指示
    // ==========================================
    // 必须等外部复位释放 且 PLL 输出稳定后，才启动后续所有的业务逻辑
    wire core_rst_n = sys_rst_n & locked;
    
    // 指示灯逻辑：时钟稳定即亮起，方便肉眼排错
    assign pl_led1 = locked; 

    // ==========================================
    // 3. 例化全链路核心业务模块 (完全体)
    // ==========================================
    ultrasonic_top u_core (
        // 全局时钟复位
        .clk         (clk_100m),
        .rst_n       (core_rst_n),
        
        // ADC 链路
        .adc_cs_n    (adc_cs_n),
        .adc_sclk    (adc_sclk),
        .adc_sdata   (adc_sdata),
        
        // 595 发射链路
        .shcp        (shcp),
        .stcp        (stcp),
        .ds1         (ds1),
        .ds2         (ds2),
        .ds3         (ds3),
        .ds4         (ds4),
        .oe_n        (oe_n)     // 严格对应 N15 使能管脚
    );

endmodule