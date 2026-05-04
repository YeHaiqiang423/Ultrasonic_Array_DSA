# build_project.tcl - 适配 Mizar Z7 的全自动化构建内核
# =========================================================

# --- 1. 环境与路径配置 ---
set prj_name "Ultrasonic_Project"
set device "xc7z020clg400-2" ;# Mizar Z7020 芯片型号
set script_path [file dirname [info script]]
set prj_root [file normalize "$script_path/.."]
set work_dir "$prj_root/workspace"

puts "\[USER_LOG\] 正在初始化构建流..."
puts "\[USER_LOG\] 工程名: $prj_name | 目标器件: $device"

# --- 2. 创建工程 (如果已存在则强制覆盖) ---
create_project -force $prj_name $work_dir/$prj_name -part $device

# --- 3. 导入所有 RTL 源码 ---
puts "\[USER_LOG\] 正在导入 RTL 源码和 IP 配置文件..."
add_files $prj_root/rtl/adc_ctrl
add_files $prj_root/rtl/pwm_array
add_files $prj_root/rtl/ultrasonic_top.v
add_files $prj_root/rtl/ultrasonic_fpga_top.v

# --- 4. 处理时钟 IP 核 (.xci) ---
set ip_file "$prj_root/rtl/ip/ClockingWizard_clk_wiz_0_0.xci"
if {[file exists $ip_file]} {
    # 核心修改：使用 import_ip 剥离 IP 的旧路径记忆，彻底归化到当前工程！
    import_ip $ip_file
    puts "\[USER_LOG\] 正在生成时钟 IP 的底层运行文件..."
    generate_target all [get_ips ClockingWizard_clk_wiz_0_0]
} else {
    puts "ERROR: 找不到 IP 配置文件: $ip_file"
    exit 1
}

# --- 5. 添加约束文件 (引脚分配) ---
set xdc_file "$prj_root/scripts/pin_assign.xdc"
if {[file exists $xdc_file]} {
    add_files -fileset constrs_1 $xdc_file
    puts "\[USER_LOG\] 已加载管脚约束文件: pin_assign.xdc"
} else {
    puts "ERROR: 找不到 XDC 约束文件: $xdc_file"
    exit 1
}

# --- 6. 设置顶层模块 ---
set_property top ultrasonic_fpga_top [current_fileset]
update_compile_order -fileset sources_1

# --- 7. 启动综合 (Synthesis) ---
puts "\[USER_LOG\] 启动综合 (Synthesis)..."
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# ================= 检验 IP 专用的“刹车点” =================
puts "\[USER_LOG\] 综合已完成！仅测试 IP 连通性，提前结束流程。"
exit 0 
# ==========================================================

# (下面的布线和生成 bit 等今晚跑全流程再解开注释)
# # --- 8. 启动布局布线 (Implementation) ---
# puts "[USER_LOG] 🚀 启动布局布线 (Implementation)..."
# launch_runs impl_1 -jobs 8
# wait_on_run impl_1

# # --- 9. 生成 Bitstream ---
# puts "[USER_LOG] 💾 正在生成最终 Bitstream (.bit)..."
# launch_runs impl_1 -to_step write_bitstream -jobs 8
# wait_on_run impl_1

# # --- 10. 提取产物 ---
# set bit_result "$work_dir/$prj_name/$prj_name.runs/impl_1/ultrasonic_fpga_top.bit"
# if {[file exists $bit_result]} {
#     file copy -force $bit_result "$prj_root/ultrasonic_top_final.bit"
#     puts "[USER_LOG] 🎉 构建成功！Bit 文件已导出至: ultrasonic_top_final.bit"
# } else {
#     puts "ERROR: 未能生成 Bitstream，请检查 build_full_dump.log"
#     exit 1
# }