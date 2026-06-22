`timescale 1ns / 1ps

module phase_lut (
    input  wire         clk,
    input  wire         rst_n,
    
    input  wire [3:0]   mode_sel,      // 由串口屏传来的模式编号 (0~15)
    output reg  [199:0] phase_out_bus  // 送给 pwm 核心的 25个探头相位
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_out_bus <= 200'd0; // 默认复位全0，不偏转
        end else begin
            case (mode_sel)
                // ==========================================
                // 把 Python 脚本打印出的 200'h 替换到这里！
                // ==========================================
                
                // 模式 0 : 正前方平行波束 (无限远聚焦)
              4'd0: phase_out_bus = 200'h00000000000000000000000000000000000000000000000000;
4'd1: phase_out_bus = 200'h0006080600060D0F0D06080F110F08060D0F0D060006080600;
4'd2: phase_out_bus = 200'h83460449008A4C0A5006014E0C52088A4C0A50068346044900;
4'd3: phase_out_bus = 200'h004904468306500A4C8A08520C4E0106500A4C8A0049044683;
                
                default: phase_out_bus <= 200'd0;
            endcase
        end
    end

endmodule