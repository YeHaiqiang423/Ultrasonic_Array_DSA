`timescale 1ns/1ps

module pwm_array_core (
    // 全局信号
    input   wire        clk,
    input   wire        rst_n,

    // ADC 信号
    input   wire    [11:0]  audio_in,
    input   wire            audio_valid,

    // 595 驱动
    input   wire            driver_ready,   // 595驱动是否空闲
    output  reg     [31:0]  pwm_out_bus,    // 模块数据输出口
    output  reg             pwm_valid       // 告知595模块数据已好，原神启动
);

    reg [4:0]   tick_cnt;                       // 计数18次，595发包一次需要（8个移位脉冲＋1个锁存脉冲）x 2个时钟周期
    wire        tick_en;                        // 数到17，拉高一次，cnt归零

    always @(posedge clk or negedge rst_n)begin
        if (!rst_n) begin
            tick_cnt    <=  5'd0;
            pwm_valid   <=  1'd0;
        end else begin
            if (tick_cnt == 5'd17) begin
                tick_cnt    <=  5'd0;
                pwm_valid   <=  1'd1;
            end else begin
                tick_cnt    <=  tick_cnt + 5'd1;    // TODO
            end
        end
    end

    assign  tick_en     =   (tick_cnt == 5'd17);    // 一旦计数满17，拉高



    // 每个tick_en（100M/18）刷新一次，40kHz要计138.8次约为139次
    localparam MAX_HW_STEPS = 8'd139;
    reg     [7:0]   pwm_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            pwm_cnt     <=  8'd0;
        end else if(tick_en) begin
            if (pwm_cnt == MAX_HW_STEPS - 8'd1)
                pwm_cnt     <=  8'd0;
            else 
                pwm_cnt     <=  pwm_cnt + 1'b1;
        end
    end


    // 0~4095音频强行压缩成0~69（139/2），并处理余数
    // 4096/69 = 59
    // 要发的占空比 = （输入的音频 + 欠的余数)/59
    // 新的余数继续记下
    // 只有当40kHz周期刚开始才要算占空比
    localparam SCALE = 6'd59;

    reg     [5:0]   error_acc;          // 记录余数
    reg     [6:0]   hw_duty;            // 计算出来的占空比

    wire    [12:0]  total_target = audio_in + error_acc;    // 防溢出

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            error_acc   <=  6'd0;
            hw_duty     <=  7'd0;
        end else if (tick_en && (pwm_cnt == 8'd0)) begin
            hw_duty     <=  total_target / SCALE;
            error_acc   <=  total_target % SCALE;
        end
    end


    // 25个方波发生
    wire    [7:0]   phase_offset    [0:24];             // 调相9未来波束偏转接口
    genvar i;
    generate
        for (i = 0; i < 25; i = i + 1) begin : GEN_PWM
            
            assign  phase_offset[i] = 8'd0;             // 目前默认0

            wire    [7:0]   local_cnt;                  // 每台机器自己的刻度
            wire    [8:0]   sum;                        // 

            // 算出这台机器现在的等效时间：总时间 + 偏移量
            assign  sum = pwm_cnt + phase_offset[i];
            assign  local_cnt = (sum >= MAX_HW_STEPS) ? (sum - MAX_HW_STEPS) : sum;

            // 时间刻度 < 目标门限，就输出高电平 1
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    pwm_out_bus[i]  <=  1'b0;
                else if (tick_en)
                    pwm_out_bus[i]  <=  (local_cnt < hw_duty) ? 1'b1 : 1'b0;
            end
        end
    endgenerate


    // 剩下 7 根线没用，直接接地，防止乱叫
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out_bus [31:25]     <=  7'd0;
        else if (tick_en)
            pwm_out_bus [31:25]     <=  7'd0;
    end
endmodule