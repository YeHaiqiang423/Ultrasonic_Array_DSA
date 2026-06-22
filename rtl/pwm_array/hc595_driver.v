`timescale 1ns/1ps

module hc595_parallel_driver (
    // 全局信号
    input   wire    clk,    // 系统时钟
    input   wire    rst_n,  // 低电平复位

    // 数据握手与接口
    input   wire            valid,      // 上游数据有效 / I
    input   wire    [31:0]  data_in,    // 32位输入数据 / I
    input   wire            tx_en,      // 全局发送使能 / I
    output  reg             ready,      // 模块已就绪，可接收新数据 / O

    // 74HC595物理引脚
    output  reg             stcp,       // 锁存脉冲 / O
    output  reg             shcp,       // 移位脉冲 / O
    output  reg             ds1,        // 芯片数据线 data_in [31:24]
    output  reg             ds2,        // 芯片数据线 data_in [23:16]
    output  reg             ds3,        // 芯片数据线 data_in [15:8]
    output  reg             ds4,        // 芯片数据线 data_in [7:0]

    // UCC 驱动使能引脚 
    output  wire            oe_n       // 低电平有效 / O
);

    // UCC 驱动使能逻辑
    assign oe_n = ~ tx_en;

    // 状态机定义 
    localparam IDLE  = 2'd0;
    localparam SHIFT = 2'd1;
    localparam LATCH = 2'd2;

    reg     [1:0]   state;          // 当前状态
    reg     [31:0]  shift_reg;      

    reg [2:0]  bit_cnt;     // 发送位计数器
    reg        clk_div;     // 用来生成 SHCP 的翻转标志

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            shift_reg <= 32'd0;
            bit_cnt   <= 3'd0;
            clk_div   <= 1'b0;
            ready     <= 1'b1;
            shcp      <= 1'b0;
            stcp      <= 1'b0;
            ds1       <= 1'b0;
            ds2       <= 1'b0;
            ds3       <= 1'b0;
            ds4       <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    stcp <= 1'b0; // 确保锁存信号拉低
                    if (valid && ready) begin
                        ready     <= 1'b0;           // 变忙
                        shift_reg <= data_in;        // 锁存上游数据
                        
                        bit_cnt   <= 3'd7;           
                        clk_div   <= 1'b0;
                        shcp      <= 1'b0;
                        state     <= SHIFT;
                    end
                end

                SHIFT: begin
                    if (clk_div == 1'b0) begin
                        shcp    <= 1'b0;
                        
                        // 🌟 核心修改：不再使用复杂的加法动态索引，直接取每个字节的最高位！
                        ds4     <= shift_reg[31];
                        ds3     <= shift_reg[23];
                        ds2     <= shift_reg[15];
                        ds1     <= shift_reg[7];
                        
                        // 🌟 真正的硬件移位操作！四个字节同时向左移 1 位，完美避开编译器 Bug
                        shift_reg[31:24] <= {shift_reg[30:24], 1'b0};
                        shift_reg[23:16] <= {shift_reg[22:16], 1'b0};
                        shift_reg[15:8]  <= {shift_reg[14:8],  1'b0};
                        shift_reg[7:0]   <= {shift_reg[6:0],   1'b0};
                        
                        clk_div <= 1'b1;
                    end else begin
                        shcp    <= 1'b1;
                        clk_div <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            state <= LATCH; // 8次发完了，去锁存
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                LATCH: begin
                    shcp  <= 1'b0; 
                    stcp  <= 1'b1;  // 制造上升沿，4片595瞬间集体更
                    ready <= 1'b1;  // 释放 ready，疯狂接下一单
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule
