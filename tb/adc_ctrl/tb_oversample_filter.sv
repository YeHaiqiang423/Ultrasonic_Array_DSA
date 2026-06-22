`timescale 1ns / 1ps

module tb_oversample_filter();

    reg        clk;
    reg        rst_n;
    reg [7:0]  gain;
    reg [7:0]  adc_data;
    reg        adc_valid;
    
    wire [11:0] audio_out;
    wire        audio_valid;

    oversample_filter uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .gain       (gain),
        .adc_data   (adc_data),
        .adc_valid  (adc_valid),
        .audio_out  (audio_out),
        .audio_valid(audio_valid)
    );

    always #5 clk = ~clk;

    reg [7:0] song_rom [0:99999];
    integer   write_file;
    integer   sample_idx = 0;

    initial begin
        $dumpfile("tb_oversample_filter.vcd"); 
        $dumpvars(0, tb_oversample_filter); // 记录当前层级下的所有信号

        for (integer i=0; i<100000; i=i+1) song_rom[i] = 8'hxx;

        $readmemh("audio_in.txt", song_rom);
        
        clk = 0;
        rst_n = 0;
        gain = 8'd1; 
        adc_data = 8'd128; 
        
        #100;
        rst_n = 1;
    end

    // ==========================================
    // 🌟 物理世界：音频源 (按 44100Hz 真实流逝)
    // 100MHz / 44100Hz ≈ 2267 个周期更新一次模拟电压
    // ==========================================
    reg [13:0] audio_tick_cnt;
    reg [7:0]  current_analog_val;

    always @(posedge clk) begin
        if (!rst_n) begin
            audio_tick_cnt     <= 0;
            sample_idx         <= 0;
            current_analog_val <= 8'd128;
        end else begin
            if (audio_tick_cnt == 12'd9070) begin
                audio_tick_cnt <= 0;
                
                // 🌟 核心修复 2：一旦读到 x，说明歌放完了，完美退场！
                if (song_rom[sample_idx] === 8'hxx) begin
                    $display("🎶 歌曲数据已全部读完，完美落幕！");
                    $fclose(write_file);
                    $finish;
                end
                
                current_analog_val <= song_rom[sample_idx];
                sample_idx <= sample_idx + 1;
            end else begin
                audio_tick_cnt <= audio_tick_cnt + 1;
            end
        end
    end

    // ==========================================
    // 🌟 芯片世界：ADC 采样 (按 1MSPS 疯狂抓取)
    // 每 100 个周期 (1us) 抓取当前的模拟电压
    // ==========================================
    reg [6:0] adc_tick_cnt;
    always @(posedge clk) begin
        if (!rst_n) begin
            adc_tick_cnt <= 0;
            adc_valid    <= 0;
        end else begin
            if (adc_tick_cnt == 7'd99) begin
                adc_tick_cnt <= 0;
                adc_valid    <= 1;
                adc_data     <= current_analog_val; // 采样这一瞬间的电压
            end else begin
                adc_tick_cnt <= adc_tick_cnt + 1;
                adc_valid    <= 0;
            end
        end
    end

    // 记录滤波器的输出
    // always @(posedge clk) begin
    //     if (audio_valid && rst_n) begin
    //         $fdisplay(write_file, "%x", audio_out);
    //     end
    // end

endmodule