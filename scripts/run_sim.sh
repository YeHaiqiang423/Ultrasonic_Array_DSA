#!/bin/bash
set -e 

# 用法: ./scripts/run_sim.sh <RTL源码路径> <TB文件路径> <顶层模块名>
if [ "$#" -lt 3 ]; then
    echo "Error: 参数不足"
    echo "用法: $0 <RTL源码路径> <TB文件路径> <顶层模块名>"
    echo "示例: $0 rtl/adc_ctrl/spi_adc_driver.v tb/adc_ctrl/tb_spi_adc_driver.sv tb_spi_adc_driver"
    exit 1
fi

RTL_FILE=$1
TB_FILE=$2
TB_TOP=$3

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRJ_ROOT="$(dirname "$SCRIPT_DIR")"
WORK_DIR="${PRJ_ROOT}/workspace"

echo ">>> [1/4] Preparing Simulation Workspace..."
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

echo ">>> [2/4] Compiling Design and Testbench..."
xvlog -sv "${PRJ_ROOT}/${RTL_FILE}" "${PRJ_ROOT}/${TB_FILE}"

echo ">>> [3/4] Elaborating and Running Simulation..."
xelab -debug typical -top "${TB_TOP}" -snapshot sim_snap
xsim sim_snap -R

echo ">>> [4/4] Converting VCD to FST for wave viewer..."
if [ -f "${TB_TOP}.vcd" ]; then
    vcd2fst "${TB_TOP}.vcd" "${TB_TOP}_result.fst"
    rm "${TB_TOP}.vcd" 
    echo "Done! Check workspace/${TB_TOP}_result.fst"
else
    echo "Warning: ${TB_TOP}.vcd not found. Please verify \$dumpvars in your Testbench."
fi