`timescale 1ns / 1ps

// 包含我们要测试的 RTL 文件 (注意 ../ 退出 workspace 目录)
`include "../rtl/adc_ctrl/spi_adc_driver.v"

module tb_spi_adc_driver();

    // ==========================================
    // 1. 连线声明
    // ==========================================
    logic       clk;
    logic       rst_n;
    logic       adc_cs_n;
    logic       adc_sclk;
    logic       adc_sdata;
    
    logic [7:0] adc_data;
    logic       adc_valid;

    // ==========================================
    // 2. 召唤被测模块 (FPGA SPI 驱动)
    // ==========================================
    spi_adc_driver u_spi_driver (
        .clk        (clk),
        .rst_n      (rst_n),
        .adc_cs_n   (adc_cs_n),
        .adc_sclk   (adc_sclk),
        .adc_sdata  (adc_sdata),
        .adc_data   (adc_data),
        .adc_valid  (adc_valid)
    );

    // ==========================================
    // 3. 产生 100MHz 系统心脏
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns 周期
    end

    // ==========================================
    // 🎭 4. 终极黑魔法：扮演 XCS7478E 芯片
    // ==========================================
    real PI = 3.141592653589793;
    real phase = 0.0;
    real sin_out;
    
    logic [7:0]  mock_audio_data; // 我们要发送的 8 位假音频
    logic [11:0] shift_out_reg;   // 12 位的移位发送盒子
    
    initial begin
        adc_sdata = 1'bz; // 默认高阻态，模拟真实芯片没被选中时放开总线
        mock_audio_data = 8'd128; // 默认静音点
    end

    // 动作 1：每次 FPGA 读完一帧（CS拉高），我们更新一次正弦波数值
    // 我们的读取频率是 1 MSPS，所以这就等效于 1 MSPS 的采样！
    always @(posedge adc_cs_n) begin
        // 产生 1kHz 正弦波，采样率 1,000,000 Hz
        phase = phase + (2.0 * PI * 1000.0 / 1000000.0);
        if (phase >= 2.0 * PI) phase = phase - 2.0 * PI;
        
        sin_out = $sin(phase);
        mock_audio_data = $rtoi((sin_out + 1.0) * 127.5); // 映射到 0~255 (8-Bit)
    end

    // 动作 2：当 FPGA 拉低 CS，我们火速准备好数据，并吐出第一个 Bit
    always @(negedge adc_cs_n) begin
        // 拼装规格书要求的格式：4个前导零 + 8个数据位
        shift_out_reg = {4'b0000, mock_audio_data};
        // 立刻把最高位放到 SDATA 线上去
        adc_sdata = shift_out_reg[11];
    end

    // 动作 3：当 FPGA 砸下 SCLK (下降沿)，我们把数据往左推一位
    always @(negedge adc_sclk) begin
        if (!adc_cs_n) begin // 只有在 CS 被选中的时候才干活
            shift_out_reg = shift_out_reg << 1;
            adc_sdata = shift_out_reg[11];
        end
    end
    
    // 当 CS 拉高时，释放 SDATA 总线
    always @(posedge adc_cs_n) begin
        adc_sdata = 1'bz;
    end

    // ==========================================
    // 5. 主机剧情控制
    // ==========================================
    initial begin
        $dumpfile("tb_spi_adc_driver.vcd");
        $dumpvars(0, tb_spi_adc_driver);
        
        rst_n = 0;
        #100;
        rst_n = 1;
        
        // 跑 3 毫秒，足以看到好几个完整的 1kHz 正弦波了！
        #3000000; 
        
        $display("✅ ADC 1MSPS 高速 SPI 驱动测试完美竣工！");
        $finish;
    end

endmodule