#!/bin/bash
set -o pipefail 

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRJ_ROOT="$(dirname "$SCRIPT_DIR")"
cd "${PRJ_ROOT}"

mkdir -p "${PRJ_ROOT}/workspace"
FULL_LOG="${PRJ_ROOT}/workspace/build_full_dump.log"
clear
echo "======================================================="
echo "启动自动化构建流"
echo "完整日志: ${FULL_LOG}"
echo "======================================================="

vivado -mode batch -source ./scripts/build_project.tcl -nolog -nojournal 2>&1 | tee "$FULL_LOG" | while IFS= read -r line; do
    
    # Tcl 自定义日志
    if [[ "$line" == "[USER_LOG]"* ]]; then
        echo -e "\033[36m${line/[USER_LOG]/}\033[0m"

    # Vivado 原生错误
    elif [[ "$line" == "ERROR:"* ]]; then
        echo -e "\033[31m[ERROR] ${line}\033[0m"

    # Vivado 严重警告
    elif [[ "$line" == "CRITICAL WARNING:"* ]]; then
        echo -e "\033[33m[CRITICAL WARNING] ${line}\033[0m"

    # 关键进度节点
    elif [[ "$line" == *"Waiting for synth_1 to finish"* ]]; then
        echo "[INFO] 综合进行中，请耐心等待..."
    elif [[ "$line" == *"Waiting for impl_1 to finish"* ]]; then
        echo "[INFO] 布局布线进行中..."
    elif [[ "$line" == *"Loading part"* ]]; then
        echo "[INFO] 加载器件配置..."
    fi
done

EXIT_CODE=$?

echo "======================================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "构建完成"
else
    echo "构建失败，请查看 build_full_dump.log"
fi