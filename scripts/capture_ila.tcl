puts "\[USER_LOG\] 🔌 正在连接 Mizar Z7..."
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
current_hw_device [get_hw_devices xc7z020_1]
refresh_hw_device [lindex [get_hw_devices xc7z020_1] 0]

puts "\[USER_LOG\] 📸 正在强制触发 ILA 抓取底层波形..."
set my_ila [lindex [get_hw_ilas] 0]
# 直接强行抓取 4096 个采样点 (在 100MHz 下相当于抓取约 40us，足够看清 25us 的载波周期)
run_hw_ila -trigger_now $my_ila
wait_on_hw_ila $my_ila

puts "\[USER_LOG\] 💾 正在将芯片脑电波导出为 VCD 格式..."
# 导出为 VCD 文件，方便后续转 fst
write_hw_ila_data -force -vcd_file hw_capture.vcd [current_hw_ila_data]

puts "\[USER_LOG\] 🎉 抓取成功！文件已保存为 hw_capture.vcd"
close_hw_manager