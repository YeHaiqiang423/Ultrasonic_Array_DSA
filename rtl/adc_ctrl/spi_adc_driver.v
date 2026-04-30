`timescale 1ns / 1ps

module spi_adc_driver (
    input  wire       clk,        // 系统时钟 100MHz (周期 10ns)
    input  wire       rst_n,      // 异步复位信号，低电平有效
    // 物理层接口 (SPI 接口连至 ADC 芯片)
    output reg        adc_cs_n,   // ADC 片选信号 (低电平有效)
    output reg        adc_sclk,   // SPI 串行时钟 (分频输出 25MHz)
    input  wire       adc_sdata,  // ADC 串行数据输入
    // 内部逻辑接口
    output reg  [7:0] adc_data,     // 采样后提取的 8-bit 有效数据
    output reg        adc_valid     // 数据有效指示脉冲 (采样率 1 MSPS)
);
    localparam IDLE = 2'd0;         // 空闲状态
    localparam CONV = 2'd1;         // SPI 通信与数据转换状态
    localparam DONE = 2'd2;         // 数据锁存及有效输出状态
    
    reg [1:0]  state;

    // 计时器：1 MSPS 采样周期对齐 (1 us 定时控制)
    // 100MHz 时钟下，1 us 对应 100 个时钟周期。计数范围 0~99。
    reg [6:0] timer_1us; 
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            timer_1us <= 7'd0;
        else if (timer_1us == 7'd99) 
            timer_1us <= 7'd0;
        else 
            timer_1us <= timer_1us + 1'b1;
    end

    // SPI 通信状态机与数据移位寄存逻辑
    reg [1:0]  sck_div;   // SCLK 分频计数器 (100MHz 分频至 25MHz)
    reg [3:0]  bit_cnt;   // 位计数器 (记录已接收的 bit 数，单次传输完整位数为 12 bits)
    reg [11:0] shift_reg; // 移位寄存器 (接收串行格式：4 bit 前导数据 + 8 bit 采样数据)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            adc_cs_n  <= 1'b1;  // 默认处于非转换状态，CS 拉高
            adc_sclk  <= 1'b1;  // 默认 SCLK 拉高 (对应 SPI 模式 CPOL=1)
            bit_cnt   <= 4'd0;
            sck_div   <= 2'd0;
            adc_data  <= 8'd0;
            adc_valid <= 1'b0;
            shift_reg <= 12'd0;
        end else begin
            adc_valid <= 1'b0;  // 默认为低电平，仅在 DONE 状态下输出单周期脉冲

            case (state)

                // IDLE: 空闲状态，等待 1us 定时结束
                IDLE: begin
                    adc_cs_n <= 1'b1;
                    adc_sclk <= 1'b1;
                    if (timer_1us == 7'd0) begin    // 满足 1us 定时周期，触发新一轮转换
                        state    <= CONV;
                        adc_cs_n <= 1'b0;           // 拉低 CS，启动 ADC 数据转换
                        bit_cnt  <= 4'd0;
                        sck_div  <= 2'd0;
                    end
                end

                // CONV: 时钟分频生成与数据串行移位接收
                CONV: begin
                    sck_div <= sck_div + 1'b1;      // 时钟相位切分: 0, 1, 2, 3
                    
                    if (sck_div == 2'd1) begin
                        // 在分频周期的第 2 拍产生 SCLK 下降沿，触发 ADC 数据输出
                        adc_sclk <= 1'b0;
                        
                    end else if (sck_div == 2'd3) begin
                        // 在分频周期的第 4 拍产生 SCLK 上升沿，在总线上对数据进行采样
                        adc_sclk <= 1'b1;
                        
                        // 串行数据移入寄存器末位
                        shift_reg <= {shift_reg[10:0], adc_sdata}; 
                        
                        bit_cnt <= bit_cnt + 1'b1;      // 完成 1 bit 接收
                        
                        // 判断是否接收完 12 bit 完整数据通信包
                        if (bit_cnt == 4'd11) begin
                            state <= DONE;              // 传输完成，进入结算状态
                        end
                    end
                end

                // DONE: 数据截取与有效信号标志传递
                DONE: begin
                    adc_cs_n <= 1'b1;                   // 拉高 CS，ADC 返回待机模式
                    
                    // 根据器件时序，截取中间的 8-bit 有效 ADC 数据
                    adc_data  <= shift_reg[8:1]; 
                    adc_valid <= 1'b1;                  // 产生 1周期数据有效脉冲
                    
                    state <= IDLE;                      // 状态复位，等待下一个 1us 转换周期
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule