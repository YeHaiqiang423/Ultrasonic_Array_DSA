`timescale 1ns / 1ps

// 这是专门给仿真用的替身模型，真身上板时由 .xci 自动替换
module ClockingWizard_clk_wiz_0_0 (
    input  wire clk_in1,
    input  wire resetn,
    output reg  clk_out1,
    output reg  locked
);

    // 模拟 PLL 锁定延迟 (等待 200ns)
    initial begin
        locked = 1'b0;
        #200;
        locked = 1'b1;
    end

    // 捏造一个 100MHz 的时钟输出 (周期 10ns -> 翻转 5ns)
    initial begin
        clk_out1 = 1'b0;
    end
    
    always #5 clk_out1 = ~clk_out1;

endmodule