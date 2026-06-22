`timescale 1ns / 1ps

module oversample_filter (
    input  wire        clk,        
    input  wire        rst_n,

    // 音量增益控制接口
    input  wire [7:0]  gain,       

    // ADC 数据输入
    (* mark_debug = "true" *)   input  wire [7:0]  adc_data,   
    input  wire        adc_valid,  
    
    // 滤波后音频数据输出
    (* mark_debug = "true" *)   output reg  [11:0] audio_out,  
    output reg         audio_valid 
);
    // ========================================
    // 过采样累加与低通滤波 (1MHz -> 40kHz)
    // ========================================
    reg [4:0]  cnt;        
    reg [12:0] sum_pool;   

    reg [12:0] raw_avg;    
    reg        calc_en;    

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt      <= 5'd0;
            sum_pool <= 13'd0;
            raw_avg  <= 13'd1600; 
            calc_en  <= 1'b0;
        end else if (adc_valid) begin
            if (cnt == 5'd24) begin
                raw_avg  <= (sum_pool + adc_data) >> 1;     
                calc_en  <= 1'b1;                           
                
                sum_pool <= 13'd0;
                cnt      <= 5'd0;
            end else begin
                sum_pool <= sum_pool + adc_data;
                calc_en  <= 1'b0;
                cnt      <= cnt + 1'b1;
            end
        end else begin
            calc_en  <= 1'b0;
        end
    end

    // =========================================================================
    // DSP 音效处理算法 (去直流 -> 包络提取 -> 动态载波 -> 饱和截断)
    // =========================================================================
    localparam signed [13:0] DC_CENTER  = 14'sd1600; // 请确保这个是你们用万用表校准过的值！
    localparam signed [21:0] MAX_VAL    = 22'sd4095; 

    // [DSP-1]：去直流偏置，剥离出纯交流波形
    (* mark_debug = "true" *)   wire signed [13:0] signed_raw   = {1'b0, raw_avg};
    (* mark_debug = "true" *)   wire signed [13:0] ac_component = signed_raw - DC_CENTER;                

    // ===================================================================
    // 🌟 猛药二：硬件级包络跟踪器 (Envelope Tracker)
    // ===================================================================
    // 1. 提取当前波形的绝对值
    wire [13:0] abs_ac = (ac_component[13]) ? (~ac_component + 1'b1) : ac_component;
    
    // 2. 动态跟踪波形的外边缘 (包络)
    (* mark_debug = "true" *)   reg [13:0] envelope;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            envelope <= 14'd0;
        end else if (calc_en) begin
            if (abs_ac > envelope)
                envelope <= abs_ac;                     // 极速起音 (Fast Attack)：音乐一响，瞬间拉满
            else if (envelope > 14'd0)
                // 缓慢释放 (Slow Release)：右移6位代表衰减速率
                envelope <= envelope - (envelope >> 9); 
        end
    end

    // ===================================================================
    // 🌟 核心魔法：动态计算中心点与最终输出
    // ===================================================================
    // [DSP-2]：同时放大交流音频 和 它的包络
    wire signed [21:0] amplified_ac  = ac_component * $signed({1'b0, gain});  
    wire signed [21:0] amplified_env = envelope * {1'b0, gain};

    // [DSP-3]：动态载波生成！(Dynamic Carrier)
    // 基础保底载波 400，加上放大的包络。
    wire signed [21:0] raw_center = 22'sd400 + amplified_env;
    
    // 🌟 终极安全锁：载波中心最高绝对不允许超过 2047 (留一半空间给交流波形振动)
    wire signed [21:0] DYNAMIC_CENTER = (raw_center > 22'sd2047) ? 22'sd2047 : raw_center;

    // 最终音频 = 交流音频 + 动态载波
    (* mark_debug = "true" *)   wire signed [21:0] final_audio  = amplified_ac + DYNAMIC_CENTER;

    // [DSP-4]：饱和截断输出 (全网唯一出口，绝不多重驱动！)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            audio_out   <= 12'd400; // 默认静音时输出极低保底载波
            audio_valid <= 1'b0;
        end else if (calc_en) begin
            audio_valid <= 1'b1;
            
            // 因为动态载波的保护，下限绝不会破底，只需要防上限破顶
            if (final_audio > MAX_VAL)
                audio_out <= 12'd4095;
            else
                audio_out <= final_audio[11:0]; 
        end else begin
            audio_valid <= 1'b0;
        end
    end

    my_ila u_ila (
        .clk    (clk),                // ILA 采样时钟
        .probe0 (adc_data),           // 8-bit  : 进水管 (查海浪底噪)
        .probe1 (signed_raw),         // 14-bit : 去直流前数据 (查静音偏置)
        .probe2 (envelope),           // 14-bit : 包络线 (查退潮平滑度)
        .probe3 (DYNAMIC_CENTER),     // 22-bit : 动态中心点 (查锁死元凶)
        .probe4 (audio_out),           // 12-bit : 出水管 (查最终截断)
        .probe5 (calc_en)
    );

endmodule