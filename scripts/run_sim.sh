#!/bin/bash
set -e 

# ==============================================================================
# Vivado 仿真自动化执行脚本 (run_sim.sh)
# ==============================================================================
# 功能说明：
#   提供一键编译 RTL 与 Testbench 代码、执行 xsim 仿真，并将生成的 VCD 波形
#   自动转换为 FST 格式（便于在 Surfer 或 GTKWave 等波形工具中高效查看）。
#
# 使用方法：
#   ./scripts/run_sim.sh <RTL源码相对路径> <TB文件相对路径> <Testbench顶层模块名>
#
# 运行示例（请在整个工程的根目录 /Ultrasonic_Array_DSA 下执行）：
#   1. 仿真 SPI ADC 驱动：
#      ./scripts/run_sim.sh rtl/adc_ctrl/spi_adc_driver.v tb/adc_ctrl/tb_spi_adc_driver.sv tb_spi_adc_driver
#   
#   2. 仿真顶层模块：
#      ./scripts/run_sim.sh rtl/ultrasonic_top.v tb/tb_ultrasonic_top.sv tb_ultrasonic_top
#
# 注意事项：
#   - 必须在系统中提前 source 确保加载了 Vivado 环境变量（如 xvlog, xelab, xsim）。
#   - 须保证系统已安装并能够调用 vcd2fst 工具。
#   - 需确保在 Testbench 文件中已通过 $dumpvars 产生以顶层模块名一致的 .vcd 文件。
# ==============================================================================

# --- 1. 参数数量检验 ---
if [ "$#" -lt 3 ]; then
    echo "❌ Error: 传入参数不足！"
    echo "💡 用法: $0 <RTL源码路径> <TB文件路径> <顶层模块名>"
    echo "🔥 示例: $0 rtl/adc_ctrl/spi_adc_driver.v tb/adc_ctrl/tb_spi_adc_driver.sv tb_spi_adc_driver"
    exit 1
fi

RTL_FILE=$1
TB_FILE=$2
TB_TOP=$3

# --- 2. 工程路径解析 ---
# 获取当前脚本所在绝对目录，进而推导工程根目录以支持任意路径安全调用
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRJ_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="${PRJ_ROOT}/workspace"

echo ">>> [1/4] Preparing Simulation Workspace..."
# 创建并切换至统一的仿真输出（及波形暂存）目录
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

echo ">>> [2/4] Compiling Design and Testbench..."
# 根据计算出的绝对路径调用 xvlog 对目标代码执行编译
xvlog -sv "${PRJ_ROOT}/${RTL_FILE}" "${PRJ_ROOT}/${TB_FILE}"

echo ">>> [3/4] Elaborating and Running Simulation..."
# 绑定指定的 Testbench 顶层模块并执行仿真解析
xelab -debug typical -top "${TB_TOP}" -snapshot sim_snap
xsim sim_snap -R

echo ">>> [4/4] Converting VCD to FST for wave viewer..."
# 检查是否成功生成 VCD 文件，若存在则转换为高性能 FST 格式文件
if [ -f "${TB_TOP}.vcd" ]; then
    vcd2fst "${TB_TOP}.vcd" "${TB_TOP}_result.fst"
    rm "${TB_TOP}.vcd" 
    echo "🎉 All Done! Check workspace/${TB_TOP}_result.fst in Surfer or GTKWave!"
else
    echo "⚠️ Warning: ${TB_TOP}.vcd not found. Please verify \$dumpvars statement in your Testbench."
fi