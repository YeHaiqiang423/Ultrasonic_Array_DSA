`timescale 1ns / 1ps

module oversample_filter (
    input  wire        clk,        
    input  wire        rst_n,
    
    // 接口 A：ADC 数据输入 (对接 SPI ADC 驱动)
    input  wire [7:0]  adc_data,   
    input  wire        adc_valid,  
    
    // 接口 B：滤波后音频数据输出 (对接 PWM 阵列)
    output reg  [11:0] audio_out,  
    output reg         audio_valid 
);

    reg [4:0]  cnt;       // 采样计数器 (0~24，累加 25 次为一周期)
    reg [12:0] sum_pool;  // 数据累加器 (13-bit 防止溢出，最大值 255*25=6375)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt         <= 5'd0;
            sum_pool    <= 13'd0;
            audio_out   <= 12'd2048; // 默认输出中点值 (12-bit 范围的中间值)
            audio_valid <= 1'b0;
        end else if (adc_valid) begin
            if (cnt == 5'd24) begin
                // 完成 25 次采样累加，由于输出需要 12-bit 数据，将其右移 1 位 (等效于除以 2) 以适配位宽
                audio_out   <= (sum_pool + adc_data) >> 1;
                audio_valid <= 1'b1; // 产生输出数据有效脉冲
                
                // 累加器和计数器清零，准备下一轮滤波计算
                sum_pool    <= 13'd0;
                cnt         <= 5'd0;
            end else begin
                // 未达到 25 次累加门限，继续累加当前数据
                sum_pool    <= sum_pool + adc_data;
                audio_valid <= 1'b0;
                cnt         <= cnt + 1'b1;
            end
        end else begin
            audio_valid <= 1'b0; // 控制有效信号为单周期脉冲输出
        end
    end

endmodule