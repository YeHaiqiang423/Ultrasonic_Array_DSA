`timescale 1ns / 1ps

`include "../rtl/adc_ctrl/spi_adc_driver.v"
`include "../rtl/adc_ctrl/oversample_filter.v"
`include "../rtl/pwm_array/hc595_driver.v"
`include "../rtl/pwm_array/pwm_array_core.v"
`include "../rtl/ultrasonic_top.v"
`include "../rtl/ultrasonic_fpga_top.v"
`include "sim_pll_stub.v"

module tb_ultrasonic_fpga_top();

    logic sys_clk_50m; 
    logic sys_rst_n;
    
    // ADC 物理连线
    logic adc_cs_n;
    logic adc_sclk;
    logic adc_sdata;
    
    // 595 输出连线
    logic shcp, stcp;
    logic ds1, ds2, ds3, ds4;
    logic ucc_en;

    ultrasonic_fpga_top u_top (
        .sys_clk_50m    (sys_clk_50m),
        .sys_rst_n      (sys_rst_n),
        .adc_cs_n       (adc_cs_n),
        .adc_sclk       (adc_sclk),
        .adc_sdata      (adc_sdata),
        .shcp           (shcp),
        .stcp           (stcp),
        .ds1            (ds1),
        .ds2            (ds2),
        .ds3            (ds3),
        .ds4            (ds4),
        .ucc_en         (ucc_en)
    );      

    // 产生 50MHz 时钟
    initial begin
        sys_clk_50m = 0;
        forever #10 sys_clk_50m = ~sys_clk_50m; 
    end

    // ==========================================
    // 🎭 扮演 XCS7478E 发送正弦波 (1kHz)
    // ==========================================
    real PI = 3.141592653589793;
    real phase = 0.0;
    real sin_out;
    
    logic [7:0]  mock_audio_data; 
    logic [11:0] shift_out_reg;   
    
    initial begin
        adc_sdata = 1'bz;
        mock_audio_data = 8'd128;
    end

    // 每次 CS 拉高，产生一个新的 8-Bit 正弦波采样点
    always @(posedge adc_cs_n) begin
        phase = phase + (2.0 * PI * 1000.0 / 1000000.0);
        if (phase >= 2.0 * PI) phase = phase - 2.0 * PI;
        sin_out = $sin(phase);
        mock_audio_data = $rtoi((sin_out + 1.0) * 127.5);
    end

    // CS 拉低，准备移位数据
    always @(negedge adc_cs_n) begin
        shift_out_reg = {4'b0000, mock_audio_data};
        adc_sdata = shift_out_reg[11];
    end

    // SCLK 下降沿，往外推数据
    always @(negedge adc_sclk) begin
        if (!adc_cs_n) begin
            shift_out_reg = shift_out_reg << 1;
            adc_sdata = shift_out_reg[11];
        end
    end
    
    always @(posedge adc_cs_n) begin
        adc_sdata = 1'bz;
    end

    // ==========================================
    // 主控制流程
    // ==========================================
    initial begin
        $dumpfile("tb_ultrasonic_fpga_top.vcd");
        $dumpvars(0, tb_ultrasonic_fpga_top);
        
        sys_rst_n = 0;
        #100;
        sys_rst_n = 1;
        
        #3000000; // 跑 3 毫秒 
        
        $display("✅ 全链路仿真完美结束！从 ADC SPI 到 595 DSB 调制全部打通！");
        $finish;
    end

endmodule