#!/bin/bash
# 气泡模拟快速运行脚本

LBPM_BIN=~/work/LBPM/build/bin/lbpm_color_simulator

echo "=========================================="
echo "LBPM 气泡模拟"
echo "=========================================="

# 检查几何文件是否存在
if [ ! -f "bubble_80x80x80.raw" ]; then
    echo "生成气泡几何文件..."
    python3 generate_bubble.py
fi

# 运行模拟
echo "运行模拟..."
mpirun -np 1 $LBPM_BIN bubble_final.db

# 显示结果
echo ""
echo "=========================================="
echo "模拟完成!"
echo "=========================================="
echo "输出文件:"
ls -lh *.csv vis*/*.silo 2>/dev/null

echo ""
echo "可视化目录:"
ls -d vis* 2>/dev/null
