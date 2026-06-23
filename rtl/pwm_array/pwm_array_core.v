`timescale 1ns/1ps

module pwm_array_core (
    // 全局信号
    input  wire         clk,            // 系统时钟 100MHz
    input  wire         rst_n,          // 异步复位信号，低电平有效

    // 音频信号输入
    input  wire [11:0]  audio_in,       // 滤波增益后音频数据 (12-bit, 来自 oversample_filter)
    input  wire         audio_valid,    // 音频数据有效脉冲

    // 控制接口
    input  wire [199:0] phase_in_bus,   // 25 路相位偏移总线 (25 x 8-bit = 200-bit, 来自 phase_lut)
    input  wire         window_en,      // 汉明窗加窗使能 (1: 空间加权, 0: 全阵列等幅输出)

    // 595 驱动接口
    input  wire         driver_ready,   // 595 驱动就绪信号 (高电平表示可接收新数据)
    output reg  [31:0]  pwm_out_bus,    // 32-bit PWM 方波总线输出 (低 25 位有效)
    output reg          pwm_valid       // PWM 数据有效脉冲 (通知 595 驱动锁存数据)
);

    // =========================================================
    // 1. 基准时间轴发生器 (40 kHz 载波生成与发包节拍控制)
    // =========================================================

    // 发包间隔计数器: 100MHz / 18 ≈ 5.56MHz 发包速率
    // 每 18 个时钟周期产生一次 tick_en, 作为 PWM 更新与发包的统一节拍
    reg [4:0]  tick_cnt;    // 计数范围 0~17
    wire       tick_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt  <= 5'd0;
            pwm_valid <= 1'b0;
        end else begin
            if (tick_cnt == 5'd17) begin
                tick_cnt  <= 5'd0;
                pwm_valid <= 1'b1;      // 产生 1 周期数据有效脉冲
            end else begin
                tick_cnt  <= tick_cnt + 5'd1;
                pwm_valid <= 1'b0;
            end
        end
    end

    assign tick_en = (tick_cnt == 5'd17);

    // 载波周期步数计数器: 40kHz 载波在 5.56MHz 发包速率下对应 139 步/周期
    localparam MAX_HW_STEPS = 8'd139;
    reg [7:0]   pwm_cnt;               // 当前载波步数 (计数范围 0~138)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_cnt <= 8'd0;
        else if (tick_en) begin
            if (pwm_cnt == MAX_HW_STEPS - 8'd1)
                pwm_cnt <= 8'd0;
            else
                pwm_cnt <= pwm_cnt + 1'b1;
        end
    end

    // =========================================================
    // 2. 基准占空比计算 (AM 调制, 音频幅度映射为 PWM 占空比)
    // =========================================================

    // 缩放因子: 将 12-bit 音频范围映射到 139 步 PWM 分辨率
    localparam SCALE = 6'd59;

    reg [5:0]   error_acc;             // 余数累加器 (保留除法截断误差, 防止幅度持续偏低)
    reg [6:0]   base_hw_duty;          // 全局基准占空比 (0~139, 中心值约 70)

    wire [12:0] total_target = audio_in + error_acc;   // 音频值加上历史余数

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_acc    <= 6'd0;
            base_hw_duty <= 7'd0;
        end else if (tick_en && (pwm_cnt == 8'd0)) begin
            base_hw_duty <= total_target / SCALE;      // 整除得到当前基准占空比
            error_acc    <= total_target % SCALE;      // 保留余数下次累加
        end
    end

    // =========================================================
    // 3. 空间阵列参数定义 (5x5 阵列: 相位偏移 + 汉明窗权重)
    // =========================================================

    wire [7:0] phase_offset  [0:24];   // 25 路独立相位偏移 (从 200-bit 总线解包)
    wire [7:0] window_weight [0:24];   // 25 路汉明窗空间权重 (0: 全抑制, 255: 全透过)

    // 5x5 汉明窗权重矩阵 (中心高、边缘低, 压制栅瓣旁瓣)
    assign window_weight[ 0] = 8'd 20; assign window_weight[ 1] = 8'd 45; assign window_weight[ 2] = 8'd 67; assign window_weight[ 3] = 8'd 45; assign window_weight[ 4] = 8'd 20;
    assign window_weight[ 5] = 8'd 45; assign window_weight[ 6] = 8'd138; assign window_weight[ 7] = 8'd190; assign window_weight[ 8] = 8'd138; assign window_weight[ 9] = 8'd 45;
    assign window_weight[10] = 8'd 67; assign window_weight[11] = 8'd190; assign window_weight[12] = 8'd255; assign window_weight[13] = 8'd190; assign window_weight[14] = 8'd 67;
    assign window_weight[15] = 8'd 45; assign window_weight[16] = 8'd138; assign window_weight[17] = 8'd190; assign window_weight[18] = 8'd138; assign window_weight[19] = 8'd 45;
    assign window_weight[20] = 8'd 20; assign window_weight[21] = 8'd 45; assign window_weight[22] = 8'd 67; assign window_weight[23] = 8'd 45; assign window_weight[24] = 8'd 20;

    // =========================================================
    // 4. 25 路 PWM 独立生成引擎 (generate 并发例化)
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < 25; i = i + 1) begin : GEN_PWM

            // 从 200-bit 总线中截取本通道 8-bit 相位偏移
            assign phase_offset[i] = phase_in_bus[i*8 +: 8];

            // 加窗占空比计算: 基准占空比 x 汉明窗权重 / 256
            wire [14:0] mult_temp;     // 乘法中间结果 (7-bit x 8-bit = 15-bit, 无溢出)
            wire [6:0]  channel_duty;  // 本通道最终占空比

            assign mult_temp = {8'd0, base_hw_duty} * window_weight[i];

            // 加窗使能时取乘法结果高 7 位 (右移 8 位); 否则直接使用基准占空比
            assign channel_duty = window_en ? mult_temp[14:8] : base_hw_duty;

            // 相位偏移后的本地计数器 (环形取模, 保证索引不越界)
            wire [8:0] sum;
            wire [7:0] local_cnt;
            assign sum = pwm_cnt + phase_offset[i];
            assign local_cnt = (sum >= MAX_HW_STEPS) ? (sum - MAX_HW_STEPS) : sum[7:0];

            // PWM 方波输出: 本地计数器小于占空比时输出高电平
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    pwm_out_bus[i] <= 1'b0;
                else if (tick_en)
                    pwm_out_bus[i] <= (local_cnt < channel_duty) ? 1'b1 : 1'b0;
            end
        end
    endgenerate

    // =========================================================
    // 5. 闲置管脚接地 (bit [31:25] 未使用, 固定输出低电平)
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out_bus[31:25] <= 7'd0;
        else if (tick_en)
            pwm_out_bus[31:25] <= 7'd0;
    end

    // 片上逻辑分析仪 (ILA) 探针例化 (观测相控阵内部信号)
    ila_pwm u_ila_pwm (
        .clk    (clk),                 // ILA 采样时钟 100MHz
        .probe0 (phase_in_bus),        // 200-bit: 相位偏移总线 (验证上位机下发值)
        .probe1 (pwm_out_bus),         // 32-bit : 最终 PWM 方波输出
        .probe2 (tick_en)              // 1-bit  : 40kHz 发包节拍
    );

endmodule