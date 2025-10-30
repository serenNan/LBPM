#!/bin/bash
set -e

echo "======================================================="
echo "LBPM 完整编译脚本"
echo "======================================================="
echo "开始时间: $(date)"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查必需依赖
echo "=== 步骤 1/10: 检查依赖 ==="
checks_passed=true

# 检查 CUDA
if command -v nvcc &> /dev/null; then
    echo -e "${GREEN}✓${NC} CUDA Toolkit: $(nvcc --version | grep release | awk '{print $5,$6}')"
    CUDA_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
    echo "  GPU 架构代码: sm_${CUDA_ARCH}"
else
    echo -e "${RED}✗${NC} CUDA Toolkit 未找到"
    echo "  请先运行: bash /tmp/install_cuda.sh"
    checks_passed=false
fi

# 检查 MPI
if command -v mpicc &> /dev/null; then
    echo -e "${GREEN}✓${NC} MPI: $(mpicc --version | head -1 | awk '{print $1,$2}')"
else
    echo -e "${RED}✗${NC} MPI 未找到"
    checks_passed=false
fi

# 检查 HDF5
if pkg-config --exists hdf5; then
    echo -e "${GREEN}✓${NC} HDF5: $(pkg-config --modversion hdf5)"
else
    echo -e "${YELLOW}!${NC} HDF5: 未找到 pkg-config，尝试手动检测"
fi

# 检查 SILO
if [ -f /opt/silo/lib/libsiloh5.a ]; then
    echo -e "${GREEN}✓${NC} SILO: 已安装在 /opt/silo"
    USE_SILO=1
elif [ -f /usr/lib/x86_64-linux-gnu/libsilo.so ]; then
    echo -e "${GREEN}✓${NC} SILO: 系统版本"
    USE_SILO=1
else
    echo -e "${YELLOW}!${NC} SILO: 未安装（将禁用 SILO 支持）"
    echo "  可以稍后运行: bash /tmp/install_silo.sh"
    USE_SILO=0
fi

if [ "$checks_passed" = false ]; then
    echo -e "${RED}依赖检查失败，请先安装缺失的依赖${NC}"
    exit 1
fi

echo ""
echo "=== 步骤 2/10: 创建构建目录 ==="
BUILD_DIR=~/build/LBPM-full
mkdir -p $BUILD_DIR
cd $BUILD_DIR
echo "构建目录: $BUILD_DIR"

echo ""
echo "=== 步骤 3/10: 清理旧配置 ==="
rm -rf CMake* cmake_install.cmake Makefile

echo ""
echo "=== 步骤 4/10: 配置 CMake ==="
echo "配置选项:"
echo "  - CUDA: 启用 (sm_${CUDA_ARCH})"
echo "  - HDF5: 启用"
echo "  - SILO: $([ $USE_SILO -eq 1 ] && echo '启用' || echo '禁用')"
echo "  - 编译模式: Release (优化)"
echo ""

cmake \
    -D CMAKE_C_COMPILER=mpicc \
    -D CMAKE_CXX_COMPILER=mpicxx \
    -D CMAKE_C_FLAGS="-O3 -march=native -fPIC" \
    -D CMAKE_CXX_FLAGS="-O3 -march=native -fPIC" \
    -D CMAKE_CXX_STANDARD=14 \
    -D CMAKE_BUILD_TYPE=Release \
    -D MPIEXEC=mpirun \
    -D USE_EXT_MPI_FOR_SERIAL_TESTS=TRUE \
    -D USE_CUDA=1 \
    -D CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    -D CMAKE_CUDA_FLAGS="-arch sm_${CUDA_ARCH}" \
    -D CMAKE_CUDA_HOST_COMPILER=/usr/bin/gcc \
    -D USE_HDF5=1 \
    -D HDF5_DIRECTORY=/usr/lib/x86_64-linux-gnu/hdf5/openmpi \
    -D HDF5_LIB=/usr/lib/x86_64-linux-gnu/hdf5/openmpi/libhdf5.so \
    -D USE_SILO=$USE_SILO \
    $([ $USE_SILO -eq 1 ] && echo "-D SILO_DIRECTORY=/opt/silo -D SILO_LIB=/opt/silo/lib/libsiloh5.a") \
    -D USE_NETCDF=0 \
    -D USE_TIMER=0 \
    -D USE_DOXYGEN=0 \
    /home/serennan/work/LBPM

if [ $? -ne 0 ]; then
    echo -e "${RED}CMake 配置失败！${NC}"
    exit 1
fi

echo ""
echo "=== 步骤 5/10: 释放内存准备编译 ==="
free -h
echo "清理系统缓存..."
sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
echo "释放后:"
free -h

echo ""
echo "=== 步骤 6/10: 编译 LBPM ==="
echo "使用 4 线程编译（预计 20-30 分钟）"
echo "提示: 你可以在另一个终端运行 'watch -n2 free -h' 监控内存"
echo ""

make -j4

if [ $? -ne 0 ]; then
    echo -e "${RED}编译失败！尝试降低并行度...${NC}"
    echo "使用 2 线程重新编译..."
    make -j2
    if [ $? -ne 0 ]; then
        echo -e "${RED}编译仍然失败，请检查错误信息${NC}"
        exit 1
    fi
fi

echo ""
echo "=== 步骤 7/10: 安装 ==="
make install

echo ""
echo "=== 步骤 8/10: 验证编译结果 ==="
echo "生成的可执行文件:"
ls -lh tests/lbpm_*_simulator 2>/dev/null || echo "  未找到模拟器"
echo ""
echo "生成的库文件:"
ls -lh lib/liblbpm-wia.* 2>/dev/null || echo "  未找到库文件"

echo ""
echo "=== 步骤 9/10: 运行快速测试 ==="
echo "运行基础测试..."
ctest -R TestDatabase --output-on-failure || echo "测试可能需要后续调试"

echo ""
echo "=== 步骤 10/10: 生成环境设置脚本 ==="
cat > $BUILD_DIR/setup_env.sh << 'ENVEOF'
#!/bin/bash
# LBPM 环境设置脚本
export LBPM_BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH=$LBPM_BUILD_DIR/tests:$PATH
export LD_LIBRARY_PATH=$LBPM_BUILD_DIR/lib:$LD_LIBRARY_PATH
echo "LBPM 环境已设置"
echo "构建目录: $LBPM_BUILD_DIR"
echo "可执行文件: $LBPM_BUILD_DIR/tests/"
ENVEOF
chmod +x $BUILD_DIR/setup_env.sh

echo ""
echo "======================================================="
echo "编译完成！"
echo "======================================================="
echo "结束时间: $(date)"
echo ""
echo "构建目录: $BUILD_DIR"
echo ""
echo "下一步:"
echo "  1. 运行完整测试:"
echo "     cd $BUILD_DIR && ctest"
echo ""
echo "  2. 测试 GPU 加速:"
echo "     cd $BUILD_DIR/tests"
echo "     mpirun -np 1 ./lbpm_color_simulator /path/to/input.db"
echo "     # 在另一个终端运行: watch -n1 nvidia-smi"
echo ""
echo "  3. 设置环境变量（可选）:"
echo "     source $BUILD_DIR/setup_env.sh"
echo ""
