`timescale 1ns / 1ps

module oversample_filter (
    input  wire        clk,          // 系统时钟 100MHz
    input  wire        rst_n,        // 异步复位信号，低电平有效

    // 音量增益控制接口
    input  wire [7:0]  gain,         // 线性增益因子 (由 gain_lut 查表输出)

    // ADC 数据输入
    (* mark_debug = "true" *)   input  wire [7:0]  adc_data,   // ADC 采样数据 (8-bit, 来自 spi_adc_driver)
    input  wire        adc_valid,    // ADC 数据有效脉冲 (采样率 1 MSPS)

    // 滤波后音频数据输出
    (* mark_debug = "true" *)   output reg  [11:0] audio_out,  // 滤波增益后音频数据 (12-bit 精度)
    output reg         audio_valid   // 音频数据有效脉冲 (输出率约 40 kHz)
);
    // 过采样累加与低通滤波 (1 MSPS -> 40 kHz)
    // 每 25 个 ADC 采样点做一次累加求均值，实现 25 倍过采样降频与抗混叠滤波
    reg [4:0]  cnt;        // 累加计数器 (计数范围 0~24, 对应 25 倍过采样比)
    reg [12:0] sum_pool;   // 累加池 (暂存 25 个 adc_data 的求和结果)

    reg [12:0] raw_avg;    // 过采样均值结果 (右移 1 位近似除以 25)
    reg        calc_en;    // 均值计算完成使能脉冲 (每 25 个 adc_valid 产生一次)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt      <= 5'd0;
            sum_pool <= 13'd0;
            raw_avg  <= 13'd1600;   // 复位默认值对应 ADC 直流偏置中心点
            calc_en  <= 1'b0;
        end else if (adc_valid) begin
            if (cnt == 5'd24) begin
                raw_avg  <= (sum_pool + adc_data) >> 1;     // 累加末值后右移 1 位取均值
                calc_en  <= 1'b1;                            // 产生 1 周期计算使能脉冲

                sum_pool <= 13'd0;
                cnt      <= 5'd0;
            end else begin
                sum_pool <= sum_pool + adc_data;             // 累加当前采样值
                calc_en  <= 1'b0;
                cnt      <= cnt + 1'b1;
            end
        end else begin
            calc_en  <= 1'b0;
        end
    end

    // DSP 音效处理算法 (去直流 -> 包络提取 -> 动态载波 -> 饱和截断)
    localparam signed [13:0] DC_CENTER  = 14'sd1600;    // ADC 静态直流偏置中心 (需用万用表校准)
    localparam signed [21:0] MAX_VAL    = 22'sd4095;    // 12-bit 输出上限饱和阈值

    // [DSP-1] 去直流偏置，剥离出纯交流音频分量
    (* mark_debug = "true" *)   wire signed [13:0] signed_raw   = {1'b0, raw_avg};
    (* mark_debug = "true" *)   wire signed [13:0] ac_component = signed_raw - DC_CENTER;

    // 硬件级包络跟踪器 (Envelope Tracker)
    // 提取当前交流波形的绝对值
    wire [13:0] abs_ac = (ac_component[13]) ? (~ac_component + 1'b1) : ac_component;

    // 动态跟踪波形外边缘 (Fast Attack / Slow Release 包络检测)
    (* mark_debug = "true" *)   reg [13:0] envelope;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            envelope <= 14'd0;
        end else if (calc_en) begin
            if (abs_ac > envelope)
                envelope <= abs_ac;                          // 极速起音 (Fast Attack): 信号到达瞬间拉满
            else if (envelope > 14'd0)
                envelope <= envelope - (envelope >> 9);      // 缓慢释放 (Slow Release): 右移 9 位控制衰减速率
        end
    end

    // 动态载波中心与最终输出计算
    // [DSP-2] 同时放大交流音频分量和包络幅度
    wire signed [21:0] amplified_ac  = ac_component * $signed({1'b0, gain});
    wire signed [21:0] amplified_env = envelope * {1'b0, gain};

    // [DSP-3] 动态载波生成 (基础保底 400 + 放大的包络)
    wire signed [21:0] raw_center = 22'sd400 + amplified_env;

    // 载波中心安全上限: 最高不超过 2047, 为交流波形预留一半振动空间
    wire signed [21:0] DYNAMIC_CENTER = (raw_center > 22'sd2047) ? 22'sd2047 : raw_center;

    // 最终音频 = 放大后的交流分量 + 动态载波中心
    (* mark_debug = "true" *)   wire signed [21:0] final_audio  = amplified_ac + DYNAMIC_CENTER;

    // [DSP-4] 饱和截断输出 (单出口驱动, 防止多重赋值冲突)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_out   <= 12'd400;     // 复位时输出极低保底载波 (静音状态)
            audio_valid <= 1'b0;
        end else if (calc_en) begin
            audio_valid <= 1'b1;        // 产生 1 周期数据有效脉冲

            // 动态载波已保护下限不越界, 仅需对上限做饱和截断
            if (final_audio > MAX_VAL)
                audio_out <= 12'd4095;
            else
                audio_out <= final_audio[11:0];
        end else begin
            audio_valid <= 1'b0;
        end
    end

    // 片上逻辑分析仪 (ILA) 探针例化
    my_ila u_ila (
        .clk    (clk),                // ILA 采样时钟
        .probe0 (adc_data),           // 8-bit  : ADC 原始采样数据
        .probe1 (signed_raw),         // 14-bit : 去直流前数据 (观测静音偏置)
        .probe2 (envelope),           // 14-bit : 包络跟踪结果
        .probe3 (DYNAMIC_CENTER),     // 22-bit : 动态载波中心点
        .probe4 (audio_out),          // 12-bit : 最终截断输出
        .probe5 (calc_en)             // 1-bit  : 计算使能脉冲
    );

endmodule