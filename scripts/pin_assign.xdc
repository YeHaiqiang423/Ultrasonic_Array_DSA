# ==========================================
# 1. 核心系统时钟与复位与状态灯
# ==========================================
# PL 50MHz 时钟输入 (Bank 13) [cite: 658, 659]
set_property PACKAGE_PIN H16 [get_ports sys_clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk_50m]

# 硬件复位按键 (Bank 35) [cite: 715]
set_property PACKAGE_PIN R19 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

# 板载 PL_LED1 (Bank 35，输出低电平亮) [cite: 1174]
set_property PACKAGE_PIN G14 [get_ports pl_led1]
set_property IOSTANDARD LVCMOS33 [get_ports pl_led1]

# ==========================================
# 2. 超声波阵列与 595 驱动 (修正了大小写，匹配 Verilog 顶层)
# ==========================================
set_property PACKAGE_PIN P16 [get_ports stcp]
set_property IOSTANDARD LVCMOS33 [get_ports stcp]

set_property PACKAGE_PIN L15 [get_ports shcp]
set_property IOSTANDARD LVCMOS33 [get_ports shcp]

set_property PACKAGE_PIN N15 [get_ports oe_n]
set_property IOSTANDARD LVCMOS33 [get_ports oe_n]

set_property PACKAGE_PIN M15 [get_ports ds1]
set_property IOSTANDARD LVCMOS33 [get_ports ds1]

set_property PACKAGE_PIN L20 [get_ports ds2]
set_property IOSTANDARD LVCMOS33 [get_ports ds2]

set_property PACKAGE_PIN H20 [get_ports ds3]
set_property IOSTANDARD LVCMOS33 [get_ports ds3]

set_property PACKAGE_PIN J14 [get_ports ds4]
set_property IOSTANDARD LVCMOS33 [get_ports ds4]

# ==========================================
# 3. ADC 防报错虚拟占位 (今天不测它，随便绑到 JP1 空闲管脚防止报错)
# ==========================================
set_property PACKAGE_PIN U13 [get_ports adc_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports adc_cs_n]

set_property PACKAGE_PIN Y14 [get_ports adc_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_sclk]

set_property PACKAGE_PIN U15 [get_ports adc_sdata]
set_property IOSTANDARD LVCMOS33 [get_ports adc_sdata]