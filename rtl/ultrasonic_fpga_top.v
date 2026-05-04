`timescale 1ns / 1ps

module ultrasonic_fpga_top (
    // 开发板物理时钟与复位
    input  wire sys_clk_50m, // 接 Mizar Z7 的 PL 50M 时钟
    input  wire sys_rst_n,   // 接 Mizar Z7 的硬件复位按键

    // 以下是你分配给扩展模块的物理引脚
    output wire adc_cs_n,
    output wire adc_sclk,
    input  wire adc_sdata,
    
    output wire shcp,
    output wire stcp,
    output wire ds1, ds2, ds3, ds4,
    output wire ucc_en
);

    wire clk_100m;
    wire locked;

    // 1. 例化时钟 IP (将外部 50MHz 倍频至内部 100MHz)
    ClockingWizard_clk_wiz_0_0 u_pll (
        .clk_in1  (sys_clk_50m),
        .resetn   (sys_rst_n),
        .clk_out1 (clk_100m),
        .locked   (locked)      // 当 100MHz 时钟稳定后，此信号拉高
    );

    // 2. 生成安全复位：必须等外部复位释放 且 PLL 输出稳定后，才启动业务逻辑
    wire core_rst_n = sys_rst_n & locked;

    // 3. 例化你完美跑通仿真的核心业务模块 (一字不改)
    ultrasonic_top u_core (
        .clk        (clk_100m),
        .rst_n      (core_rst_n),
        
        .adc_cs_n   (adc_cs_n),
        .adc_sclk   (adc_sclk),
        .adc_sdata  (adc_sdata),
        
        .shcp       (shcp),
        .stcp       (stcp),
        .ds1        (ds1),
        .ds2        (ds2),
        .ds3        (ds3),
        .ds4        (ds4),
        .ucc_en     (ucc_en)
    );

endmodule