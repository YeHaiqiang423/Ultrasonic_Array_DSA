`timescale 1ns / 1ps

module uart_rx_driver #(
    parameter CLK_FREQ  = 100_000_000,  // 系统主时钟 100MHz
    parameter BAUD_RATE = 115200        // 串口波特率 (请根据你的串口屏实际配置修改，比如 9600)
)(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         uart_rxd,       // 串口接收物理引脚

    // 输出给超声波核心引擎的控制总线
    output reg  [3:0]   out_volume,
    output reg  [3:0]   out_mode,
    output reg          out_window
);

    localparam BAUD_CNT_MAX = CLK_FREQ / BAUD_RATE;
    localparam BAUD_CNT_MID = BAUD_CNT_MAX / 2;

    // ==========================================
    // 1. 串口接收引脚去亚稳态与下降沿检测
    // ==========================================
    reg rx_d0, rx_d1, rx_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_d0 <= 1'b1;
            rx_d1 <= 1'b1;
            rx_d2 <= 1'b1;
        end else begin
            rx_d0 <= uart_rxd;
            rx_d1 <= rx_d0;
            rx_d2 <= rx_d1;
        end
    end
    wire rx_fall = (~rx_d1) & rx_d2; // 检测起始位的下降沿

    // ==========================================
    // 2. UART 接收状态机
    // ==========================================
    reg [2:0]  state;
    reg [15:0] baud_cnt;
    reg [2:0]  bit_cnt;
    reg [7:0]  rx_data;
    reg        rx_done;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            baud_cnt <= 16'd0;
            bit_cnt  <= 3'd0;
            rx_data  <= 8'd0;
            rx_done  <= 1'b0;
        end else begin
            rx_done <= 1'b0; // 默认拉低，只在接收完成那一拍拉高一个周期

            case (state)
                IDLE: begin
                    if (rx_fall) begin
                        state    <= START;
                        baud_cnt <= 16'd0;
                    end
                end

                START: begin
                    if (baud_cnt == BAUD_CNT_MID) begin
                        if (rx_d1 == 1'b0) begin // 再次确认是低电平，防止毛刺
                            baud_cnt <= 16'd0;
                            state    <= DATA;
                            bit_cnt  <= 3'd0;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if (baud_cnt == BAUD_CNT_MAX - 1) begin
                        baud_cnt <= 16'd0;
                        rx_data[bit_cnt] <= rx_d1; // 采样数据位
                        
                        if (bit_cnt == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_cnt <= bit_cnt + 1'b1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                STOP: begin
                    if (baud_cnt == BAUD_CNT_MAX - 1) begin
                        baud_cnt <= 16'd0;
                        state    <= IDLE;
                        rx_done  <= 1'b1; // 触发一条有效指令
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    // ==========================================
    // 3. 核心指令解析引擎 (16进制协议映射)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_volume <= 4'd8;  // 默认开机 8 档音量
            out_mode   <= 4'd0;  // 默认开机模式 0 (正前方)
            out_window <= 1'b0;  // 默认开机关闭加窗
        end else if (rx_done) begin
            case (rx_data)
                // [加权] 一键切换汉明窗
                8'h69: out_window <= ~out_window; 
                
                // [聚焦] 模式1，如果已经是模式1，则退回模式0
                8'h96: out_mode <= (out_mode == 4'd1) ? 4'd0 : 4'd1;
                
                // [偏转 -] 模式2 (左偏)，如果是则退回0
                8'h5A: out_mode <= (out_mode == 4'd2) ? 4'd0 : 4'd2;
                
                // [偏转 +] 模式3 (右偏)，如果是则退回0
                8'hA5: out_mode <= (out_mode == 4'd3) ? 4'd0 : 4'd3;
                
                // [增益 +] 音量加，最高 15 档
                8'h55: if (out_volume < 4'd15) out_volume <= out_volume + 1'b1;
                
                // [增益 -] 音量减，最低 0 档 (静音)
                8'hAA: if (out_volume > 4'd0)  out_volume <= out_volume - 1'b1;
                
                default: ; // 收到未定义指令，保持当前状态不变
            endcase
        end
    end

endmodule