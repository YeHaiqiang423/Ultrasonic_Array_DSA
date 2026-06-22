# import numpy as np

# # ==========================================
# # 1. 物理参数对齐 (来自队友的 MATLAB)
# # ==========================================
# N = 25
# f = 40e3
# c = 340
# c0 = 11.5e-3
# golden_angle = 137.508 * np.pi / 180

# # 载波周期 (25us) 和 FPGA 量化步长 (139步)
# T_carrier = 1 / f
# MAX_HW_STEPS = 139 
# step_time = T_carrier / MAX_HW_STEPS # 约 179.8ns

# # 生成坐标和权重 (0-based indexing for Verilog)
# n = np.arange(1, N + 1)
# r_n = c0 * np.sqrt(n)
# theta_n = n * golden_angle
# x_n = r_n * np.cos(theta_n)
# y_n = r_n * np.sin(theta_n)
# z_n = np.zeros(N)

# R_max = np.max(r_n)
# w_hamming = 0.54 + 0.46 * np.cos(np.pi * r_n / R_max)
# w_quantized = np.round(w_hamming * 255).astype(int)

# # ==========================================
# # 2. 打印 Verilog 加窗权重代码
# # ==========================================
# print("/* ========================================================")
# print(" * 请将以下权重代码替换进 pwm_array_core.v 的第 3 部分")
# print(" * ======================================================== */")
# for i in range(N):
#     print(f"assign window_weight[{i:2d}] = 8'd{w_quantized[i]:3d}; ", end="")
#     if (i + 1) % 5 == 0: print()
# print("\n")

# # ==========================================
# # 3. 核心相位计算函数
# # ==========================================
# def calc_phase_steps(target_deg, F_focus=1.0):
#     target_rad = target_deg * np.pi / 180
#     xf = F_focus * np.sin(target_rad)
#     yf = 0
#     zf = F_focus * np.cos(target_rad)
    
#     # 计算空间直线距离
#     d_focus = np.sqrt((x_n - xf)**2 + (y_n - yf)**2 + (z_n - zf)**2)
#     # 计算理想飞行时间
#     t_ideal = d_focus / c
#     # 找最远的点，所有人等他 (计算补偿延迟)
#     t_comp = np.max(t_ideal) - t_ideal 
    
#     # 🌟 关键：将时间延迟映射到 FPGA 的 0~138 步长中
#     # 1. 延迟时间除以载波周期取余 (剔除整周期)
#     t_comp_mod = np.mod(t_comp, T_carrier)
#     # 2. 换算成 FPGA 计数值
#     steps = np.round(t_comp_mod / step_time).astype(int)
#     steps = np.mod(steps, MAX_HW_STEPS) # 防止 139 变成越界
#     return steps

# def pack_to_200bit_hex(steps):
#     # 将 25 个 8-bit 数据拼成一个 200-bit 的大十六进制数
#     hex_str = ""
#     for s in reversed(steps): # Verilog 拼接是高位在左，所以要倒序拼接
#         hex_str += f"{s:02X}"
#     return f"200'h{hex_str}"

# # ==========================================
# # 4. 生成不同模式的 200-bit 寄存器值
# # ==========================================
# print("/* ========================================================")
# print(" * 请将以下 LUT 填入新建的 phase_lut.v 模块中")
# print(" * ======================================================== */")
# modes = [
#     ("模式 0 : 正前方平行波束 (无限远聚焦)", calc_phase_steps(0, 9999)),
#     ("模式 1 : 正前方聚焦 1 米", calc_phase_steps(0, 1.0)),
#     ("模式 2 : 左偏 15 度聚焦 1 米", calc_phase_steps(-15, 1.0)),
#     ("模式 3 : 右偏 15 度聚焦 1 米", calc_phase_steps(15, 1.0)),
# ]

# for i, (desc, steps) in enumerate(modes):
#     hex_val = pack_to_200bit_hex(steps)
#     print(f"// {desc}")
#     print(f"4'd{i}: phase_out_bus = {hex_val};")

# import math

# # ==========================================
# # 1. 物理与系统核心参数
# # ==========================================
# C_SPEED = 340.0              # 声速 (m/s)
# STEP_TIME_NS = 180e-9        # FPGA 单步时长: 18 个 100MHz 周期 = 180ns
# MAX_STEPS = 139              # FPGA 最大步数 (139步 = 40kHz 周期)

# # ==========================================
# # 2. 阵列几何参数 (5x5 矩形阵列)
# # ==========================================
# # 标准 TCT40 探头直径是 16mm。
# # 如果你们的 PCB 间距更大，请修改这个值 (例如 0.0165)
# # ==========================================
# # 2. 阵列几何参数 (5x5 矩形阵列 - 定制版)
# # ==========================================
# SPACING = 0.016              

# coords = []
# for row in range(5):
#     # 🌟 核心修改：列数从 4 递减到 0 (匹配你们从右往左的编号)
#     for col in range(4, -1, -1): 
#         # 当 col=4(最右侧) 时，x = 2 * SPACING (正数最大)
#         # 当 col=0(最左侧) 时，x = -2 * SPACING (负数最大)
#         x = (col - 2) * SPACING   
        
#         # Y轴：上面是正，下面是负
#         y = (2 - row) * SPACING   
#         coords.append((x, y, 0.0))

# # ==========================================
# # 3. 核心计算函数
# # ==========================================
# def generate_hex_lut(angle_deg, focus_m):
#     angle_rad = math.radians(angle_deg)
    
#     # 计算目标焦点的三维坐标 (默认只在水平面 X-Z 发生偏转)
#     xf = focus_m * math.sin(angle_rad)
#     yf = 0.0
#     zf = focus_m * math.cos(angle_rad)
    
#     # 计算每个探头到焦点的绝对距离
#     distances = []
#     for (x, y, z) in coords:
#         if focus_m > 1000: # 如果距离极大，视为平面波方程
#             d = x * math.sin(angle_rad) + z * math.cos(angle_rad)
#         else:
#             d = math.sqrt((x - xf)**2 + (y - yf)**2 + (z - zf)**2)
#         distances.append(d)
        
#     max_dist = max(distances)
    
#     hex_str = ""
#     # 🌟 绝杀细节：倒序打包！
#     # 在 FPGA 中，phase_offset[0] 对应总线的最右侧(最低的8位)
#     # 所以我们必须把探头 0 的延迟量放在字符串的最右边！
#     for d in reversed(distances):
#         time_diff = (max_dist - d) / C_SPEED
#         steps = round(time_diff / STEP_TIME_NS) % MAX_STEPS
#         hex_str += f"{int(steps):02X}"
        
#     return hex_str

# # ==========================================
# # 4. 一键生成 Verilog 代码
# # ==========================================
# if __name__ == "__main__":
#     print("/* ========================================================")
#     print("   5x5 矩形阵列 - 相位查找表 (LUT) 自动生成")
#     print("   探头排布假设: [0号在左上角] -> 行优先 -> [24号在右下角]")
#     print("   ======================================================== */")
    
#     # 模式 0: 正前方平行波束 (焦距设为 9999 米模拟无限远)
#     print(f"4'd0: phase_out_bus = 200'h{generate_hex_lut(0, 9999)};")
    
#     # 模式 1: 正前方聚焦 1 米
#     print(f"4'd1: phase_out_bus = 200'h{generate_hex_lut(0, 1.0)};")
    
#     # 模式 2: 左偏 15 度聚焦 1 米
#     print(f"4'd2: phase_out_bus = 200'h{generate_hex_lut(-15, 1.0)};")
    
#     # 模式 3: 右偏 15 度聚焦 1 米
#     print(f"4'd3: phase_out_bus = 200'h{generate_hex_lut(15, 1.0)};")

import math

# ==========================================
# 5x5 二维径向海明窗计算器 (2D Radial Hamming)
# ==========================================
SPACING = 0.016  # 探头间距 (米)

# 1. 生成与相位相同的 5x5 物理坐标 (0号在右上角)
coords = []
for row in range(5):
    for col in range(4, -1, -1):
        x = (col - 2) * SPACING
        y = (2 - row) * SPACING
        coords.append((x, y))

# 2. 寻找阵列中的最大半径 (即中心点到最四个角落的距离)
r_max = math.sqrt((2 * SPACING)**2 + (2 * SPACING)**2)

weights_8bit = []

# 3. 计算二维海明窗并映射到 0~255
for x, y in coords:
    # 当前探头距离中心的半径
    r = math.sqrt(x**2 + y**2)
    
    # 标准径向海明窗公式
    # 中心点 r=0 时，cos(0)=1，w = 1.0
    # 最角落 r=r_max 时，cos(pi)=-1，w = 0.08
    w = 0.54 + 0.46 * math.cos(math.pi * r / r_max)
    
    # 映射为 8-bit 无符号整数 (给 FPGA 里的乘法器用)
    w_8bit = int(round(w * 255))
    weights_8bit.append(w_8bit)

# 4. 直接输出 Verilog 代码！
print("// =========================================================")
print("// 🌟 3. 空间阵列解包与汉明窗权重定义 (5x5 矩形靶心映射)")
print("// =========================================================")
for i in range(25):
    # 格式化输出，每 5 个换一行，完美对应你们板子上的物理位置
    print(f"assign window_weight[{i:2d}] = 8'd{weights_8bit[i]:3d}; ", end="")
    if (i + 1) % 5 == 0:
        print()

