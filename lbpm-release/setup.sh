#!/bin/bash
# LBPM 环境配置脚本
# 使用方法: source setup.sh 或 bash setup.sh

LBPM_HOME="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# 修复可执行文件权限(复制到新环境时可能丢失执行权限)
echo "=========================================="
echo "正在配置 LBPM 环境..."
echo "=========================================="

if [ ! -x "$LBPM_HOME/bin/lbpm_color_simulator" ]; then
    echo "⚠ 检测到可执行文件缺少执行权限"
    echo "  (这在跨文件系统复制时很常见)"
    echo "  正在修复..."
    chmod +x "$LBPM_HOME"/bin/* 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ 权限已修复"
    else
        echo "✗ 权限修复失败,请手动运行: chmod +x bin/*"
    fi
    echo ""
fi

# 设置环境变量
export PATH="$LBPM_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$LBPM_HOME/lib:$LD_LIBRARY_PATH"

echo "✓ LBPM 环境已加载"
echo "=========================================="
echo "安装目录: $LBPM_HOME"
echo "可执行文件: $LBPM_HOME/bin"
echo "依赖库: $LBPM_HOME/lib"
echo ""
echo "可用的主要模拟器:"
ls -1 "$LBPM_HOME/bin" 2>/dev/null | grep "lbpm_.*_simulator$" | head -10
echo ""
echo "快速测试:"
echo "  cd $LBPM_HOME/example/Bubble"
echo "  python3 generate_bubble.py  # 生成测试几何"
echo "  mpirun -np 1 lbpm_color_simulator bubble_final.db"
echo ""
echo "详细文档请查看: INSTALL.txt 和 USER_GUIDE.md"
echo "=========================================="
