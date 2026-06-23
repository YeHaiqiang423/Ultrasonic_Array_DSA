`timescale 1ns/1ps

module hc595_parallel_driver (
    // 全局信号
    input   wire        clk,        // 系统时钟 100MHz
    input   wire        rst_n,      // 异步复位信号，低电平有效

    // 数据握手接口
    input   wire        valid,      // 上游数据有效指示 (来自 pwm_array_core)
    input   wire [31:0] data_in,    // 32-bit PWM 方波总线输入
    input   wire        tx_en,      // 全局发送使能 (高电平驱动输出)
    output  reg         ready,      // 模块就绪信号 (高电平表示可接收新数据)

    // 74HC595 物理引脚 (4 组并发移位输出)
    output  reg         stcp,       // 存储寄存器锁存时钟 (上升沿触发并行输出更新)
    output  reg         shcp,       // 移位寄存器时钟 (上升沿触发数据移入)
    output  reg         ds1,        // 数据线 1 (对应 data_in [7:0])
    output  reg         ds2,        // 数据线 2 (对应 data_in [15:8])
    output  reg         ds3,        // 数据线 3 (对应 data_in [23:16])
    output  reg         ds4,        // 数据线 4 (对应 data_in [31:24])

    // 驱动使能引脚
    output  wire        oe_n        // 74HC595 输出使能 (低电平有效, 由 tx_en 取反生成)
);

    // 输出使能逻辑: tx_en 高电平时 oe_n 拉低，允许 595 驱动后级
    assign oe_n = ~tx_en;

    // =========================================================
    // 状态机定义
    // =========================================================
    localparam IDLE  = 2'd0;   // 空闲状态，等待上游数据
    localparam SHIFT = 2'd1;   // 移位状态，逐 bit 并发送出 4 路数据
    localparam LATCH = 2'd2;   // 锁存状态，产生 STCP 上升沿更新并行输出

    reg [1:0]  state;          // 当前状态寄存器
    reg [31:0] shift_reg;      // 移位寄存器 (4 组 8-bit 并发移位)
    reg [2:0]  bit_cnt;        // 发送位计数器 (8 bit/byte, 计数范围 7~0)
    reg        clk_div;        // SHCP 分频翻转标志 (生成移位时钟半周期)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            shift_reg <= 32'd0;
            bit_cnt   <= 3'd0;
            clk_div   <= 1'b0;
            ready     <= 1'b1;       // 复位后默认就绪
            shcp      <= 1'b0;
            stcp      <= 1'b0;
            ds1       <= 1'b0;
            ds2       <= 1'b0;
            ds3       <= 1'b0;
            ds4       <= 1'b0;
        end else begin
            case (state)

                // IDLE: 空闲状态，等待 valid 握手并锁存输入数据
                IDLE: begin
                    stcp <= 1'b0;
                    if (valid && ready) begin
                        ready     <= 1'b0;          // 置忙标志，拒绝新数据
                        shift_reg <= data_in;       // 锁存 32-bit 输入数据至移位寄存器

                        bit_cnt   <= 3'd7;          // 初始化位计数器 (需移位 8 次)
                        clk_div   <= 1'b0;
                        shcp      <= 1'b0;
                        state     <= SHIFT;
                    end
                end

                // SHIFT: 移位状态，每 2 个 clk 完成 1 bit 的并发移位输出
                SHIFT: begin
                    if (clk_div == 1'b0) begin
                        // 前半周期: SHCP 拉低，数据线上放置当前最高位
                        shcp <= 1'b0;

                        // 取各字节最高位 (MSB first) 送至对应数据线
                        ds4 <= shift_reg[31];       // data_in [31:24] 的当前最高位
                        ds3 <= shift_reg[23];       // data_in [23:16] 的当前最高位
                        ds2 <= shift_reg[15];       // data_in [15:8]  的当前最高位
                        ds1 <= shift_reg[7];        // data_in [7:0]   的当前最高位

                        // 四组 8-bit 同步左移 1 位，空出低位补零
                        shift_reg[31:24] <= {shift_reg[30:24], 1'b0};
                        shift_reg[23:16] <= {shift_reg[22:16], 1'b0};
                        shift_reg[15:8]  <= {shift_reg[14:8],  1'b0};
                        shift_reg[7:0]   <= {shift_reg[6:0],   1'b0};

                        clk_div <= 1'b1;
                    end else begin
                        // 后半周期: SHCP 拉高产生上升沿，595 锁存当前数据位
                        shcp    <= 1'b1;
                        clk_div <= 1'b0;

                        if (bit_cnt == 3'd0) begin
                            state <= LATCH;          // 8 bit 全部移出，进入锁存状态
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                // LATCH: 锁存状态，STCP 上升沿触发 4 片 595 并行输出更新
                LATCH: begin
                    shcp  <= 1'b0;
                    stcp  <= 1'b1;                   // 产生 STCP 上升沿，更新并行输出
                    ready <= 1'b1;                   // 释放就绪信号，允许接收下一帧数据
                    state <= IDLE;                   // 返回空闲状态
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule