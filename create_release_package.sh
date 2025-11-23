#!/bin/bash
#===============================================================================
# LBPM Release Package Creator
# 自动创建可分发的 LBPM 打包文件
#===============================================================================

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

#===============================================================================
# 配置参数
#===============================================================================
LBPM_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$LBPM_ROOT/build"
RELEASE_NAME="lbpm-release"
RELEASE_DIR="$LBPM_ROOT/$RELEASE_NAME"
VERSION="1.0"

# 打包模式: full=包含所有库, minimal=只包含可执行文件
PACKAGE_MODE="${1:-minimal}"  # 默认minimal模式

if [ "$PACKAGE_MODE" = "full" ]; then
    PACKAGE_NAME="lbpm-v${VERSION}-ubuntu2404-full"
else
    PACKAGE_NAME="lbpm-v${VERSION}-linux-minimal"
fi

echo_info "=========================================="
echo_info "LBPM 打包脚本 - $PACKAGE_MODE 模式"
echo_info "=========================================="
echo_info "源目录: $LBPM_ROOT"
echo_info "构建目录: $BUILD_DIR"
echo_info "发布目录: $RELEASE_DIR"
echo_info "打包名称: $PACKAGE_NAME"
if [ "$PACKAGE_MODE" = "full" ]; then
    echo_warn "完整模式: 包含所有依赖库(仅适用于Ubuntu 24.04或GLIBC 2.39+系统)"
else
    echo_info "精简模式: 不包含系统库,需要客户自行安装依赖"
fi
echo_info ""

#===============================================================================
# 第1步: 检查前置条件
#===============================================================================
echo_info "步骤 1/7: 检查前置条件..."

if [ ! -d "$BUILD_DIR" ]; then
    echo_error "构建目录不存在: $BUILD_DIR"
    exit 1
fi

if [ ! -f "$BUILD_DIR/bin/lbpm_color_simulator" ]; then
    echo_error "找不到可执行文件,请先编译 LBPM"
    exit 1
fi

if ! command -v patchelf &> /dev/null; then
    echo_error "patchelf 未安装,请运行: sudo apt install patchelf"
    exit 1
fi

echo_info "✓ 前置条件检查通过"

#===============================================================================
# 第2步: 修复 RPATH
#===============================================================================
echo_info "步骤 2/7: 修复可执行文件 RPATH..."

FIXED_COUNT=0
for bin in "$BUILD_DIR"/bin/*; do
    if [ -f "$bin" ] && file "$bin" | grep -q "ELF.*executable"; then
        echo_info "  修复: $(basename "$bin")"
        patchelf --set-rpath '$ORIGIN/../lib' "$bin" 2>/dev/null || true
        FIXED_COUNT=$((FIXED_COUNT + 1))
    fi
done

echo_info "✓ 已修复 $FIXED_COUNT 个可执行文件"

#===============================================================================
# 第3步: 创建目录结构
#===============================================================================
echo_info "步骤 3/7: 创建打包目录结构..."

# 清理旧的发布目录
if [ -d "$RELEASE_DIR" ]; then
    echo_warn "删除旧的发布目录"
    rm -rf "$RELEASE_DIR"
fi

# 创建目录
mkdir -p "$RELEASE_DIR"/{bin,lib,example,docs}

echo_info "✓ 目录结构创建完成"

#===============================================================================
# 第4步: 收集依赖库
#===============================================================================
echo_info "步骤 4/7: 收集依赖库..."

# 获取第一个可执行文件的依赖
TEST_BIN="$BUILD_DIR/bin/lbpm_color_simulator"

if [ "$PACKAGE_MODE" = "full" ]; then
    # 完整模式: 打包所有依赖库
    echo_info "  收集所有依赖库..."
    ldd "$TEST_BIN" | \
        awk '{if ($3 ~ /^\//) print $3}' | \
        grep -E "libhdf5_openmpi|libsiloh5|libmpi|libopen|libz\.so\.1|libevent|libhwloc" | \
        sort -u > /tmp/lbpm_deps.txt
    echo_info "  模式: 包含所有系统库(适用于Ubuntu 24.04)"
else
    # 精简模式: 不打包系统库
    echo_info "  精简模式: 不打包系统库"
    echo_info "  客户需要安装: OpenMPI, HDF5 (with MPI), SILO"
    touch /tmp/lbpm_deps.txt
fi

# 复制依赖库
LIB_COUNT=0
while read -r lib; do
    if [ -f "$lib" ]; then
        cp -L "$lib" "$RELEASE_DIR/lib/"
        echo_info "  ✓ $(basename "$lib")"
        LIB_COUNT=$((LIB_COUNT + 1))
    fi
done < /tmp/lbpm_deps.txt

echo_info "✓ 已收集 $LIB_COUNT 个依赖库"

#===============================================================================
# 第5步: 复制可执行文件和资源
#===============================================================================
echo_info "步骤 5/7: 复制可执行文件和资源..."

# 复制可执行文件
echo_info "  复制可执行文件..."
cp -rp "$BUILD_DIR"/bin/* "$RELEASE_DIR/bin/"
BIN_COUNT=$(ls "$RELEASE_DIR/bin" | wc -l)

# 确保所有可执行文件都有执行权限
chmod +x "$RELEASE_DIR"/bin/* 2>/dev/null || true
echo_info "  ✓ 已复制 $BIN_COUNT 个文件"

# 复制示例
echo_info "  复制示例..."
cp -r "$LBPM_ROOT/example"/* "$RELEASE_DIR/example/"
# 清理示例中的临时文件
find "$RELEASE_DIR/example" -name "*.silo" -delete
find "$RELEASE_DIR/example" -name "*.csv" -delete
find "$RELEASE_DIR/example" -name "ID.*" -delete
find "$RELEASE_DIR/example" -name "id_t*.raw" -delete
find "$RELEASE_DIR/example" -type d -name "vis*" -exec rm -rf {} + 2>/dev/null || true
EXAMPLE_COUNT=$(find "$RELEASE_DIR/example" -maxdepth 1 -type d | wc -l)
echo_info "  ✓ 已复制 $((EXAMPLE_COUNT - 1)) 个示例"

# 复制文档
echo_info "  复制文档..."
cp "$LBPM_ROOT/LICENSE" "$RELEASE_DIR/" 2>/dev/null || echo_warn "  LICENSE 文件不存在"
cp "$LBPM_ROOT/README.md" "$RELEASE_DIR/" 2>/dev/null || echo_warn "  README.md 文件不存在"
cp "$LBPM_ROOT/USER_GUIDE.md" "$RELEASE_DIR/" 2>/dev/null || true
cp "$LBPM_ROOT/BUILD_GUIDE.md" "$RELEASE_DIR/docs/" 2>/dev/null || true

if [ -d "$LBPM_ROOT/docs" ]; then
    cp -r "$LBPM_ROOT/docs"/* "$RELEASE_DIR/docs/" 2>/dev/null || true
fi

echo_info "✓ 文件复制完成"

#===============================================================================
# 第6步: 创建客户文档和脚本
#===============================================================================
echo_info "步骤 6/7: 创建客户文档和脚本..."

# 创建 INSTALL.txt
cat > "$RELEASE_DIR/INSTALL.txt" << 'EOFINSTALL'
==========================================
LBPM 安装与运行指南
==========================================

版本: 1.0
日期: 2025-11-23

## 系统要求

- Linux x86_64 (Ubuntu 20.04+, CentOS 8+, Red Hat 8+)
- OpenMPI 4.0+ (必须)
- HDF5 with OpenMPI support (必须)
- SILO library with HDF5 support (必须)

**重要**: 为提高兼容性,本发布包不包含系统库,需要在目标系统安装依赖。

### 安装依赖 (Ubuntu/Debian):
```bash
sudo apt update
sudo apt install -y \
    openmpi-bin \
    libopenmpi-dev \
    libhdf5-openmpi-dev \
    libsilo-dev
```

### 安装依赖 (CentOS/RHEL):
```bash
sudo yum install -y \
    openmpi \
    openmpi-devel \
    hdf5-openmpi \
    hdf5-openmpi-devel \
    silo \
    silo-devel

# 加载MPI模块
module load mpi/openmpi-x86_64
```

## 安装步骤

### 1. 解压软件包

```bash
tar xzf lbpm-v1.0-linux-x86_64.tar.gz
cd lbpm-release
```

### 2. 配置环境

**方法 A: 使用配置脚本 (推荐)**
```bash
source setup.sh
```

**方法 B: 手动配置**
```bash
export PATH=$PWD/bin:$PATH
export LD_LIBRARY_PATH=$PWD/lib:$LD_LIBRARY_PATH
```

建议将以下内容添加到 ~/.bashrc 或 ~/.bash_profile:
```bash
export PATH=/path/to/lbpm-release/bin:$PATH
export LD_LIBRARY_PATH=/path/to/lbpm-release/lib:$LD_LIBRARY_PATH
```

### 3. 验证安装

```bash
# 检查依赖
ldd bin/lbpm_color_simulator

# 应该显示所有库都已找到,没有 "not found"
```

### 4. 运行测试示例

```bash
cd example/Bubble
python3 generate_bubble.py
mpirun -np 1 lbpm_color_simulator bubble_final.db
```

如果成功运行,将看到:
```
********************************************************
Running Color LBM
********************************************************
...
CPU time = ...
Lattice update rate (per core)= ... MLUPS
```

## 可用程序

### 主要模拟器:
- lbpm_color_simulator              - 两相流Color模型
- lbpm_permeability_simulator       - 渗透率计算
- lbpm_greyscale_simulator          - 灰度模型
- lbpm_BGK_simulator                - 单相流BGK模型
- lbpm_nernst_planck_simulator      - 电化学传输

### 工具程序:
- lbpm_serial_decomp    - 几何分解工具
- lbpm_morph_pp         - 形态学处理
- convertIO             - 数据格式转换
- GenerateSphereTest    - 几何生成

完整列表请查看 bin/ 目录

## 故障排除

### 问题 1: 找不到共享库
```
error while loading shared libraries: libhdf5_openmpi.so.103: cannot open shared object file
```

**解决方法:**
```bash
# 确保设置了 LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$PWD/lib:$LD_LIBRARY_PATH

# 验证库文件存在
ls -l lib/libhdf5_openmpi.so.103
```

### 问题 2: MPI 相关错误
```
mpirun: command not found
```

**解决方法:**
大多数 Linux 发行版需要安装 OpenMPI:
```bash
# Ubuntu/Debian
sudo apt install openmpi-bin

# CentOS/RHEL
sudo yum install openmpi
# 然后加载模块
module load mpi/openmpi-x86_64
```

### 问题 3: GLIBC 版本过低
```
version `GLIBC_2.34' not found
```

**解决方法:**
您的系统 glibc 版本太旧。选项:
1. 升级系统到更新版本
2. 联系我们获取针对您系统的专用编译版本

检查您的 glibc 版本:
```bash
ldd --version
```

### 问题 4: 可执行文件没有执行权限
```
bash: ./lbpm_color_simulator: Permission denied
```

**解决方法:**
如果在某些文件系统(如FAT32、NTFS)上解压或复制文件可能丢失执行权限:
```bash
# 修复所有可执行文件的权限
chmod +x bin/*

# 或者只修复特定文件
chmod +x bin/lbpm_color_simulator
```

### 问题 5: Python 脚本错误
示例中的 Python 脚本需要 NumPy:
```bash
pip3 install numpy
# 或
sudo apt install python3-numpy
```

## 使用文档

- USER_GUIDE.md - 完整用户指南
- example/ - 各种示例配置
- docs/ - 技术文档

## 许可证

LBPM 使用 GPL v3 许可证。详情请查看 LICENSE 文件。

## 技术支持

如遇问题,请提供以下信息:
1. Linux 发行版和版本 (`cat /etc/os-release`)
2. glibc 版本 (`ldd --version`)
3. 完整错误信息
4. ldd 输出 (`ldd bin/lbpm_color_simulator`)

==========================================
EOFINSTALL

# 创建 setup.sh 脚本
cat > "$RELEASE_DIR/setup.sh" << 'EOFSETUP'
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
EOFSETUP

chmod +x "$RELEASE_DIR/setup.sh"

# 创建简短的 README
cat > "$RELEASE_DIR/README_RELEASE.txt" << 'EOFREADME'
LBPM v1.0 - Linux x86_64 发布版
================================

快速开始:
1. source setup.sh
2. cd example/Bubble
3. mpirun -np 1 lbpm_color_simulator bubble_final.db

详细说明请查看 INSTALL.txt

目录结构:
- bin/      可执行文件
- lib/      依赖库
- example/  示例文件
- docs/     文档
EOFREADME

echo_info "✓ 文档和脚本创建完成"

#===============================================================================
# 第7步: 打包和验证
#===============================================================================
echo_info "步骤 7/7: 打包和验证..."

# 计算大小
RELEASE_SIZE=$(du -sh "$RELEASE_DIR" | cut -f1)
echo_info "  发布包大小: $RELEASE_SIZE"

# 创建压缩包
cd "$LBPM_ROOT"
echo_info "  创建压缩包..."
tar czf "${PACKAGE_NAME}.tar.gz" "$RELEASE_NAME"

PACKAGE_SIZE=$(du -sh "${PACKAGE_NAME}.tar.gz" | cut -f1)
echo_info "  ✓ 压缩包大小: $PACKAGE_SIZE"

# 验证
echo_info "  验证打包结果..."
CHECK_BIN="$RELEASE_DIR/bin/lbpm_color_simulator"
if [ -f "$CHECK_BIN" ]; then
    echo_info "    检查 RPATH/RUNPATH..."
    RPATH=$(readelf -d "$CHECK_BIN" | grep -E "RPATH|RUNPATH" || true)
    if [ -n "$RPATH" ]; then
        echo_info "    ✓ 已设置: $RPATH"
    else
        echo_warn "    未设置 RPATH/RUNPATH"
    fi

    echo_info "    检查依赖..."
    MISSING=$(ldd "$CHECK_BIN" 2>&1 | grep "not found" || true)
    if [ -z "$MISSING" ]; then
        echo_info "    ✓ 所有依赖库都已找到"
    else
        echo_warn "    发现缺失的依赖:"
        echo "$MISSING"
    fi
fi

#===============================================================================
# 完成
#===============================================================================
echo ""
echo_info "=========================================="
echo_info "打包完成!"
echo_info "=========================================="
echo_info "发布目录: $RELEASE_DIR"
echo_info "压缩包: ${PACKAGE_NAME}.tar.gz"
echo_info "解压后大小: $RELEASE_SIZE"
echo_info "压缩包大小: $PACKAGE_SIZE"
echo ""
echo_info "测试方法:"
echo_info "  cd $RELEASE_DIR"
echo_info "  source setup.sh"
echo_info "  cd example/Bubble"
echo_info "  mpirun -np 1 lbpm_color_simulator bubble_final.db"
echo ""
echo_info "客户交付文件: ${PACKAGE_NAME}.tar.gz"
echo_info "=========================================="
