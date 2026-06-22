`timescale 1ns / 1ps

module gain_lut (
    input  wire         clk,
    input  wire         rst_n,
    input  wire [3:0]   vol_idx,       // 串口屏传来的音量档位 (4-bit, 0~15档)
    output reg  [7:0]   gain_factor    // 喂给滤波器的线性放大倍数
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gain_factor <= 8'd2;       // 默认开机 2 倍音量，安全且有声音
        end else begin
            case (vol_idx)
                4'd0 : gain_factor <= 8'd0;   // 静音
                4'd1 : gain_factor <= 8'd1;   // 基础原音 (0dB)
                4'd2 : gain_factor <= 8'd2;   // +6dB
                4'd3 : gain_factor <= 8'd3;   // +9.5dB
                4'd4 : gain_factor <= 8'd4;   // +12dB
                4'd5 : gain_factor <= 8'd5;   // +14dB
                4'd6 : gain_factor <= 8'd6;   // +15.5dB
                4'd7 : gain_factor <= 8'd8;   // +18dB
                4'd8 : gain_factor <= 8'd10;  // +20dB (昨天测试的健康音量)
                4'd9 : gain_factor <= 8'd12;  // +21.5dB
                4'd10: gain_factor <= 8'd15;  // +23.5dB
                4'd11: gain_factor <= 8'd19;  // +25.5dB
                4'd12: gain_factor <= 8'd24;  // +27.6dB
                4'd13: gain_factor <= 8'd30;  // +29.5dB
                4'd14: gain_factor <= 8'd38;  // +31.6dB
                4'd15: gain_factor <= 8'd48;  // +33.6dB (极限轰鸣，再大硬件易失真)
                default: gain_factor <= 8'd2;
            endcase
        end
    end

endmodule