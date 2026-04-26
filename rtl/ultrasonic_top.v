`timescale 1ns / 1ps

module ultrasonic_top (
    input  wire clk,         // Zynq 100MHz 晶振输入
    input  wire rst_n,       // 复位按键
    
    input  wire [11:0] adc_audio_in, // 👈 新增：真实 ADC 送来的 12bit 音频
    // (这里先留空 ADC 接口，未来接你队友的 ADC 模块)
    // input wire ... adc_pins
    
    // 物理输出引脚 -> 外接排线 -> 595 & UCC 阵列
    output wire shcp,        // 移位时钟
    output wire stcp,        // 锁存时钟
    output wire ds1,         // 数据线 1
    output wire ds2,         // 数据线 2
    output wire ds3,         // 数据线 3
    output wire ds4,         // 数据线 4
    output wire ucc_en       // 全局静音开关
);

    // 内部连线
    wire [31:0] internal_pwm_bus;
    wire        internal_valid;
    wire        internal_ready;
    
    // ==========================================
    // 模块 1：模拟音频产生器 (测试用，后期换成真实 ADC)
    // ==========================================
    // 这里我们造一个测试用的虚拟 ADC 数据。
    // 为了测听感，我们给一个中等偏上的音量常数，或者接一个极低频的计数器。
    // wire [11:0] virtual_audio = 12'd2048; // 固定输出 50% 音量
    
    // ==========================================
    // 模块 2：核心 PWM 生成引擎 (带 Dithering)
    // ==========================================
    pwm_array_core u_pwm_core (
        .clk         (clk),
        .rst_n       (rst_n),
        .audio_in    (adc_audio_in),
        .audio_valid (1'b1),
        
        .driver_ready(internal_ready),
        .pwm_out_bus (internal_pwm_bus),
        .pwm_valid   (internal_valid)
    );

    // ==========================================
    // 模块 3：底层 595 半并行驱动轮子
    // ==========================================
    hc595_parallel_driver u_driver (
        .clk         (clk),
        .rst_n       (rst_n),
        .valid       (internal_valid),
        .data_in     (internal_pwm_bus),
        .tx_en       (1'b1), // 默认允许开火 (或者接一个拨码开关)
        .ready       (internal_ready),
        
        .shcp        (shcp),
        .stcp        (stcp),
        .ds1         (ds1),
        .ds2         (ds2),
        .ds3         (ds3),
        .ds4         (ds4),
        .ucc_en      (ucc_en)
    );

endmodule