`timescale 1ns / 1ps
`include "uart/uart_rx_driver.v"
module ultrasonic_fpga_top (
    // 开发板板载基础接口 (Mizar Z7 / 50MHz 外部晶振)
    input  wire sys_clk_50m,    // 50MHz 外部晶振输入
    input  wire sys_rst_n,      // 硬件复位按键 (低电平有效)
    output wire pl_led1,        // PLL 锁定指示灯 (亮起表示 100M 时钟就绪)

    // 串口屏物理引脚
    input  wire uart_rx,        

    // ADC 物理接口 (对接 XCS7478E)
    output wire adc_cs_n,       
    output wire adc_sclk,       
    input  wire adc_sdata,      
    
    // 74HC595 阵列物理接口 (四线并发)
    output wire shcp,           
    output wire stcp,           
    output wire ds1,            
    output wire ds2,            
    output wire ds3,            
    output wire ds4,            
    output wire oe_n            
);

    // 1. 时钟倍频逻辑 (50MHz -> 100MHz)
    wire clk_100m;
    wire locked;

    ClockingWizard_clk_wiz_0_0 u_pll (
        .clk_in1  (sys_clk_50m),
        .resetn   (sys_rst_n),
        .clk_out1 (clk_100m),
        .locked   (locked)      
    );

    // 复位按键未按下且 PLL 输出稳定后，才释放系统复位
    wire core_rst_n = sys_rst_n & locked;
    assign pl_led1 = locked; 

    // 2. 串口屏接收与指令解析
    wire [3:0] ctrl_volume; 
    wire [3:0] ctrl_mode;   
    wire       ctrl_window; 

    uart_rx_driver #(
        .CLK_FREQ(100_000_000), 
        .BAUD_RATE(115200)
    ) u_uart_rx (
        .clk        (clk_100m),
        .rst_n      (core_rst_n),
        .uart_rxd   (uart_rx),   // 接串口屏的 TX 管脚
        .out_volume (ctrl_volume),
        .out_mode   (ctrl_mode),
        .out_window (ctrl_window)
    );

    // 3. 例化核心业务顶层
    ultrasonic_top u_core (
        .clk         (clk_100m),
        .rst_n       (core_rst_n),
        
        .ctrl_volume (ctrl_volume),  
        .ctrl_mode   (ctrl_mode),    
        .ctrl_window (ctrl_window),  

        .adc_cs_n    (adc_cs_n),
        .adc_sclk    (adc_sclk),
        .adc_sdata   (adc_sdata),
        
        .ds1         (ds1),
        .ds2         (ds2),
        .ds3         (ds3),
        .ds4         (ds4),
        .shcp        (shcp),
        .stcp        (stcp),
        .oe_n        (oe_n) 
    );

endmodule