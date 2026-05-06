# program.tcl - 一键下载 Bitstream
set prj_root [file normalize "[file dirname [info script]]/.."]

open_hw_manager
connect_hw_server -url TCP:10.20.0.169:3121   
open_hw_target

puts "\[USER_LOG\] 正在寻找 Zynq 芯片..."
current_hw_device [get_hw_devices xc7z020_1]
refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7z020_1] 0]

set bit_file "$prj_root/ultrasonic_top_final.bit"
set_property PROGRAM.FILE $bit_file [get_hw_devices xc7z020_1]

puts "\[USER_LOG\] 开始烧录 $bit_file ..."
program_hw_devices [get_hw_devices xc7z020_1]

puts "\[USER_LOG\] 烧录完成！"
close_hw_manager

# vivado -mode batch -source ./scripts/program.tcl -nolog -nojournal
