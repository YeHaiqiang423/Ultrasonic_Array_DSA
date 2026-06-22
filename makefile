# ==========================================
# 超声波阵列定向传输系统 - 自动化构建脚本
# ==========================================

# 声明伪目标，防止和同名文件冲突
.PHONY: help build sim program ila clean

# 默认目标：输入 make 直接回车，会打印帮助菜单
help:
	@echo "================================================="
	@echo "    Ultrasonic Array DSA - 快捷命令菜单"
	@echo "================================================="
	@echo "  make build   - 🚀 运行全流程构建 (综合->布线->生成 .bit)"
	@echo "  make sim     - 🔬 运行纯软件仿真 (Testbench -> GTKWave)"
	@echo "  make program - 🔌 烧录比特流到 FPGA (通过 JTAG)"
	@echo "  make ila     - 📸 抓取芯片真实波形 (ILA -> VCD -> FST -> GTKWave)"
	@echo "  make clean   - 🧹 清理 Vivado 产生的垃圾文件和日志"
	@echo "================================================="

# 1. 一键构建
build:
	@echo "\[MAKE\] 🚀 启动硬件构建流..."
	bash ./scripts/run_build.sh

# 2. 一键仿真
sim:
	@echo "\[MAKE\] 🔬 启动软件仿真..."
	bash ./scripts/run_sim.sh

# 3. 一键烧录
program:
	@echo "\[MAKE\] 🔌 正在烧录 FPGA..."
	vivado -mode batch -source ./scripts/program.tcl -nolog -nojournal

# 4. 一键 ILA 抓波形大连招 (抓取 -> 转换 -> 显示)
ila:
	@echo "\[MAKE\] 📸 正在触发 ILA 抓取..."
	vivado -mode batch -source ./scripts/capture_ila.tcl -nolog -nojournal
	@echo "\[MAKE\] 🔄 正在将 VCD 转换为极速 FST 格式..."
	vcd2fst hw_capture.vcd hw_capture.fst
	@echo "\[MAKE\] 🌊 正在召唤 GTKWave..."
	gtkwave hw_capture.fst &

# 5. 一键清理垃圾
clean:
	@echo "\[MAKE\] 🧹 清理临时文件和工作区..."
	rm -rf workspace/
	rm -rf .Xil/
	rm -f *.jou *.log *.pb *.str *.vcd *.fst usage_statistics_webtalk.*
	@echo "\[MAKE\] ✨ 清理完成"