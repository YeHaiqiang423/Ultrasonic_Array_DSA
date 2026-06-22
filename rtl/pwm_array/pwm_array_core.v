`timescale 1ns/1ps

module pwm_array_core (
    // 全局信号
    input  wire         clk,
    input  wire         rst_n,

    // ADC 信号
    input  wire [11:0]  audio_in,
    input  wire         audio_valid,

    // 🌟 新增：上位机/串口屏控制接口
    input  wire [199:0] phase_in_bus, // 25 个探头的相位延迟 (25 * 8-bit = 200-bit)
    input  wire         window_en,    // 一键加窗使能 (1:开启压制旁瓣, 0:全阵列最大火力)

    // 595 驱动
    input  wire         driver_ready, // 595驱动是否空闲
    output reg  [31:0]  pwm_out_bus,  // 模块数据输出口
    output reg          pwm_valid     // 告知595模块数据已好
);

    // =========================================================
    // 1. 基准时间轴发生器 (40kHz 载波生成)
    // =========================================================
    reg [4:0]  tick_cnt;    // 计数18次，匹配 595 发包周期
    wire       tick_en;     

    always @(posedge clk or negedge rst_n)begin
        if (!rst_n) begin
            tick_cnt  <=  5'd0;
            pwm_valid <=  1'd0;
        end else begin
            if (tick_cnt == 5'd17) begin
                tick_cnt  <=  5'd0;
                pwm_valid <=  1'd1;
            end else begin
                tick_cnt  <=  tick_cnt + 5'd1; 
                pwm_valid <=  1'b0;
            end
        end
    end

    assign  tick_en = (tick_cnt == 5'd17); 

    // 载波周期计步器 (40kHz -> 139步)
    localparam MAX_HW_STEPS = 8'd139;
    reg     [7:0]   pwm_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            pwm_cnt <=  8'd0;
        end else if(tick_en) begin
            if (pwm_cnt == MAX_HW_STEPS - 8'd1)
                pwm_cnt <=  8'd0;
            else 
                pwm_cnt <=  pwm_cnt + 1'b1;
        end
    end

    // =========================================================
    // 2. 基准占空比计算 (AM 调制，计算中心基础 Duty)
    // =========================================================
    localparam SCALE = 6'd59;

    reg     [5:0]   error_acc;          // 记录余数防丢精度
    reg     [6:0]   base_hw_duty;       // 全局基准占空比

    wire    [12:0]  total_target = audio_in + error_acc; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)begin
            error_acc    <=  6'd0;
            base_hw_duty <=  7'd0;
        end else if (tick_en && (pwm_cnt == 8'd0)) begin
            base_hw_duty <=  total_target / SCALE;
            error_acc    <=  total_target % SCALE;
        end
    end

    // =========================================================
    // 🌟 3. 空间阵列解包与汉明窗权重定义 (5x5 阵列)
    // =========================================================
    wire [7:0] phase_offset  [0:24]; // 25 个独立的相位偏移
    wire [7:0] window_weight [0:24]; // 25 个独立的空间权重 (0~255代表 0%~100%)

    // assign window_weight[ 0] = 8'd233; assign window_weight[ 1] = 8'd212; assign window_weight[ 2] = 8'd192; assign window_weight[ 3] = 8'd174; assign window_weight[ 4] = 8'd157; 
    // assign window_weight[ 5] = 8'd141; assign window_weight[ 6] = 8'd127; assign window_weight[ 7] = 8'd114; assign window_weight[ 8] = 8'd101; assign window_weight[ 9] = 8'd 90; 
    // assign window_weight[10] = 8'd 80; assign window_weight[11] = 8'd 71; assign window_weight[12] = 8'd 63; assign window_weight[13] = 8'd 55; assign window_weight[14] = 8'd 49; 
    // assign window_weight[15] = 8'd 43; assign window_weight[16] = 8'd 38; assign window_weight[17] = 8'd 33; assign window_weight[18] = 8'd 30; assign window_weight[19] = 8'd 27; 
    // assign window_weight[20] = 8'd 24; assign window_weight[21] = 8'd 23; assign window_weight[22] = 8'd 21; assign window_weight[23] = 8'd 21; assign window_weight[24] = 8'd 20; 
    assign window_weight[ 0] = 8'd 20; assign window_weight[ 1] = 8'd 45; assign window_weight[ 2] = 8'd 67; assign window_weight[ 3] = 8'd 45; assign window_weight[ 4] = 8'd 20; 
assign window_weight[ 5] = 8'd 45; assign window_weight[ 6] = 8'd138; assign window_weight[ 7] = 8'd190; assign window_weight[ 8] = 8'd138; assign window_weight[ 9] = 8'd 45; 
assign window_weight[10] = 8'd 67; assign window_weight[11] = 8'd190; assign window_weight[12] = 8'd255; assign window_weight[13] = 8'd190; assign window_weight[14] = 8'd 67; 
assign window_weight[15] = 8'd 45; assign window_weight[16] = 8'd138; assign window_weight[17] = 8'd190; assign window_weight[18] = 8'd138; assign window_weight[19] = 8'd 45; 
assign window_weight[20] = 8'd 20; assign window_weight[21] = 8'd 45; assign window_weight[22] = 8'd 67; assign window_weight[23] = 8'd 45; assign window_weight[24] = 8'd 20; 
    // =========================================================
    // 🌟 4. 25路超声波独立生成引擎 (多线程并发执行)
    // =========================================================
    genvar i;
    generate
        for (i = 0; i < 25; i = i + 1) begin : GEN_PWM
            
            // 🌟 4.1 从 200-bit 大总线中切出属于自己的 8-bit 相位数据
            assign phase_offset[i] = phase_in_bus[i*8 +: 8]; 

            // 🌟 4.2 独立加窗计算 (修复乘法溢出 Bug)
            wire [14:0] mult_temp;
            wire [6:0]  channel_duty;
            
            // 用花括号补 0，强行把 7-bit 拓宽到 15-bit 参与乘法，绝对不溢出！
            assign mult_temp = {8'd0, base_hw_duty} * window_weight[i];
            
            // 乘完之后再安心地右移 8 位 (除以256)
            assign channel_duty = window_en ? (mult_temp[14:8]) : base_hw_duty;

            // 🌟 4.3 完美的时间环形取模计算
            // 注意：LUT 传进来的 phase_offset 必须保证在 0 ~ 138 之间！
            wire [8:0] sum;
            wire [7:0] local_cnt;
            assign sum = pwm_cnt + phase_offset[i];
            assign local_cnt = (sum >= MAX_HW_STEPS) ? (sum - MAX_HW_STEPS) : sum[7:0];

            // 🌟 4.4 PWM 最终射击
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    pwm_out_bus[i]  <=  1'b0;
                else if (tick_en)
                    pwm_out_bus[i]  <=  (local_cnt < channel_duty) ? 1'b1 : 1'b0;
            end
        end
    endgenerate

    // =========================================================
    // 5. 闲置管脚接地防啸叫
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out_bus [31:25] <= 7'd0;
        else if (tick_en)
            pwm_out_bus [31:25] <= 7'd0;
    end
    
    ila_pwm u_ila_pwm (
        .clk    (clk),                // 100MHz 满速采样
        .probe0 (phase_in_bus),       // 200-bit: 看看单片机/串口下发的相位值对不对
        .probe1 (pwm_out_bus),        // 32-bit: 最终打给硬件的方波
        .probe2 (tick_en)             // 1-bit: 40kHz 的发包节拍
    );
endmodule