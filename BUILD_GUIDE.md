# LBPM 构建指南

完整的 LBPM (Lattice Boltzmann Methods for Porous Media) 构建、配置和故障排除指南。

## 目录

- [快速开始](#快速开始)
- [依赖项详细说明](#依赖项详细说明)
- [构建场景](#构建场景)
- [CMake选项参考](#cmake选项参考)
- [验证和测试](#验证和测试)
- [故障排除](#故障排除)
- [平台特定说明](#平台特定说明)

---

## 快速开始

### 系统要求

- **操作系统**: Linux (强烈推荐) 或 WSL2
- **CMake**: 3.9+ (推荐 3.21+)
- **编译器**: 支持 C++14 的编译器 (GCC 7.5+, Clang, Intel ICC)
- **并行**: MPI 实现 (OpenMPI, MPICH, Intel MPI)

### 最简单的构建流程

```bash
# 1. 创建构建目录（必须在源码目录外）
mkdir ~/lbpm-build
cd ~/lbpm-build

# 2. 配置（使用预设脚本）
~/work/LBPM/sample_scripts/configure_desktop

# 3. 编译、安装和测试
make -j4 && make install
ctest
```

### 前置条件检查

```bash
# 检查 MPI
which mpicc mpicxx
mpirun --version

# 检查 CMake
cmake --version

# 检查编译器
gcc --version  # 或 g++ --version
```

---

## 依赖项详细说明

### 必需依赖

#### 1. MPI (消息传递接口)

**作用**: 并行计算核心

**安装方法**:

```bash
# Ubuntu/Debian
sudo apt-get install libopenmpi-dev openmpi-bin

# CentOS/RHEL
sudo yum install openmpi openmpi-devel

# 从源码安装
wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.4.tar.gz
tar -xzf openmpi-4.1.4.tar.gz
cd openmpi-4.1.4
./configure --prefix=/opt/openmpi
make -j4 && sudo make install

# 设置环境变量
export PATH=/opt/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/opt/openmpi/lib:$LD_LIBRARY_PATH
```

#### 2. HDF5 (分层数据格式)

**版本要求**: 1.8.12+ (推荐并行版本)

**安装方法**:

```bash
# 方法1: 包管理器（可能不支持并行）
sudo apt-get install libhdf5-dev libhdf5-mpi-dev

# 方法2: 从源码构建（推荐）
export LBPM_HDF5_DIR=/opt/hdf5
export LBPM_ZLIB_DIR=/usr

wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.7/src/hdf5-1.10.7.tar.gz
tar -xzf hdf5-1.10.7.tar.gz
cd hdf5-1.10.7

CC=mpicc CXX=mpicxx CXXFLAGS="-fPIC -O3 -std=c++14" \
./configure --prefix=$LBPM_HDF5_DIR \
            --enable-parallel \
            --enable-shared \
            --with-zlib=$LBPM_ZLIB_DIR

make -j4 && sudo make install
```

#### 3. SILO (科学可视化库)

**推荐版本**: 4.10.3RC (修改版)

**安装方法**:

```bash
export LBPM_SILO_DIR=/opt/silo

# 下载LBPM推荐的修改版
wget https://bitbucket.org/AdvancedMultiPhysics/tpl-builder/downloads/Silo-4.10.3RC.modified.tar.gz
tar -xzf Silo-4.10.3RC.modified.tar.gz
cd Silo-4.10.3RC

CC=mpicc CXX=mpicxx CXXFLAGS="-fPIC -O3 -std=c++14" \
./configure --prefix=$LBPM_SILO_DIR \
            --with-hdf5=$LBPM_HDF5_DIR/include,$LBPM_HDF5_DIR/lib \
            --enable-static \
            --disable-silex

make -j4 && sudo make install
```

#### 4. Zlib (压缩库)

```bash
# Ubuntu/Debian
sudo apt-get install zlib1g-dev

# 或从源码
export LBPM_ZLIB_DIR=/opt/zlib
wget https://zlib.net/zlib-1.2.11.tar.gz
tar -xzf zlib-1.2.11.tar.gz
cd zlib-1.2.11
./configure --prefix=$LBPM_ZLIB_DIR
make -j4 && sudo make install
```

### 可选依赖

#### CUDA (NVIDIA GPU 支持)

**适用场景**: NVIDIA GPU 加速计算

**要求**:
- CUDA Toolkit 10.0+
- NVIDIA Driver
- GPU 计算能力 3.5+

**安装**:
```bash
# 检查 GPU
nvidia-smi

# 安装 CUDA (Ubuntu)
# 访问 https://developer.nvidia.com/cuda-downloads
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.6.0/local_installers/cuda-repo-ubuntu2004-11-6-local_11.6.0-510.39.01-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2004-11-6-local_11.6.0-510.39.01-1_amd64.deb
sudo apt-key add /var/cuda-repo-ubuntu2004-11-6-local/7fa2af80.pub
sudo apt-get update
sudo apt-get install cuda

# 环境变量
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

**常用 GPU 架构**:
- `sm_35`: Tesla K40, K80
- `sm_60`: Tesla P100
- `sm_70`: Tesla V100
- `sm_80`: A100
- `sm_86`: RTX 3090
- `sm_89`: RTX 4090

#### HIP (AMD GPU 支持)

**适用场景**: AMD GPU 加速计算

**要求**:
- ROCm 4.5.0+
- AMD GPU (gfx90a, gfx908, 等)

**安装**:
```bash
# Ubuntu 20.04
wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -
echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian/ ubuntu main' | sudo tee /etc/apt/sources.list.d/rocm.list
sudo apt update
sudo apt install rocm-dkms

# 环境变量
export ROCM_PATH=/opt/rocm
export PATH=$ROCM_PATH/bin:$PATH
```

#### NetCDF (可选数据格式)

```bash
sudo apt-get install libnetcdf-dev
# 或指定路径
export NETCDF_DIR=/opt/netcdf
```

#### TimerUtility (性能分析)

仅用于详细性能分析，一般开发不需要。

---

## 构建场景

### 场景 1: 桌面开发环境 (CPU Only)

**适用**: 日常开发、测试、学习

**环境变量设置**:
```bash
export LBPM_SOURCE=~/work/LBPM
export LBPM_DIR=~/lbpm-build
export LBPM_HDF5_DIR=/opt/hdf5
export LBPM_SILO_DIR=/opt/silo
```

**配置命令**:
```bash
mkdir -p $LBPM_DIR && cd $LBPM_DIR

cmake \
    -D CMAKE_BUILD_TYPE:STRING=Release \
    -D CMAKE_C_COMPILER:PATH=mpicc \
    -D CMAKE_CXX_COMPILER:PATH=mpicxx \
    -D CMAKE_C_FLAGS="-fPIC" \
    -D CMAKE_CXX_FLAGS="-fPIC" \
    -D CMAKE_CXX_STANDARD=14 \
    -D MPIEXEC=mpirun \
    -D USE_EXT_MPI_FOR_SERIAL_TESTS:BOOL=TRUE \
    -D USE_CUDA=0 \
    -D USE_HIP=0 \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY=$LBPM_HDF5_DIR \
    -D USE_SILO=1 \
        -D SILO_DIRECTORY=$LBPM_SILO_DIR \
    -D USE_NETCDF=0 \
    -D USE_TIMER=0 \
    $LBPM_SOURCE

make -j4
make install
ctest
```

### 场景 2: CUDA GPU 环境

**适用**: NVIDIA GPU 加速计算

**环境变量**:
```bash
export LBPM_SOURCE=~/work/LBPM
export LBPM_DIR=~/lbpm-build-cuda
export CUDA_HOME=/usr/local/cuda
```

**配置命令**:
```bash
mkdir -p $LBPM_DIR && cd $LBPM_DIR

# 首先确定 GPU 架构
nvidia-smi --query-gpu=compute_cap --format=csv
# 假设输出 7.0，则使用 sm_70

cmake \
    -D CMAKE_BUILD_TYPE:STRING=Release \
    -D CMAKE_C_COMPILER:PATH=mpicc \
    -D CMAKE_CXX_COMPILER:PATH=mpicxx \
    -D CMAKE_CXX_FLAGS="-lstdc++" \
    -D CMAKE_CXX_STANDARD=14 \
    -D USE_CUDA=1 \
        -D CMAKE_CUDA_FLAGS="-arch sm_70 -Xptxas=-v -Xptxas -dlcm=cg -lineinfo" \
        -D CMAKE_CUDA_HOST_COMPILER="/usr/bin/gcc" \
    -D USE_MPI=1 \
        -D MPIEXEC=mpirun \
        -D USE_EXT_MPI_FOR_SERIAL_TESTS:BOOL=TRUE \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY=$LBPM_HDF5_DIR \
    -D USE_SILO=1 \
        -D SILO_DIRECTORY=$LBPM_SILO_DIR \
    -D USE_TIMER=0 \
    $LBPM_SOURCE

make -j4
make install

# 测试 GPU 功能
cd tests/gpu
ctest
```

**CUDA 编译标志说明**:
- `-arch sm_70`: 目标 GPU 架构（根据你的GPU调整）
- `-Xptxas=-v`: 显示寄存器使用等详细信息
- `-Xptxas -dlcm=cg`: L1缓存配置
- `-lineinfo`: 生成行号信息（便于调试）

### 场景 3: HIP GPU 环境 (AMD)

**适用**: AMD GPU 加速计算（如 MI100, MI250X）

**环境变量**:
```bash
export LBPM_SOURCE=~/work/LBPM
export LBPM_DIR=~/lbpm-build-hip
export ROCM_PATH=/opt/rocm
```

**对于 Cray 系统（Crusher, Frontier）**:
```bash
# 加载模块
module load PrgEnv-amd
module load rocm/4.5.0
module load cray-mpich
module load cray-hdf5-parallel
module load craype-accel-amd-gfx908

# 设置 GTL 库（GPU-aware MPI）
export PE_MPICH_GTL_DIR_amd_gfx90a="-L${CRAY_MPICH_ROOTDIR}/gtl/lib"
export PE_MPICH_GTL_LIBS_amd_gfx90a="-lmpi_gtl_hsa"
export LD_LIBRARY_PATH=${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}

# 配置
cd $LBPM_DIR
cmake \
    -D CMAKE_BUILD_TYPE:STRING=Release \
    -D CMAKE_C_COMPILER:PATH=cc \
    -D CMAKE_CXX_COMPILER:PATH=CC \
    -D CMAKE_CXX_STANDARD=14 \
    -D DISABLE_GOLD:BOOL=TRUE \
    -D DISABLE_LTO:BOOL=TRUE \
    -D CMAKE_C_FLAGS="-L${MPICH_DIR}/lib -lmpi -L${CRAY_MPICH_ROOTDIR}/gtl/lib -lmpi_gtl_hsa" \
    -D CMAKE_CXX_FLAGS="-L${MPICH_DIR}/lib -lmpi -L${CRAY_MPICH_ROOTDIR}/gtl/lib -lmpi_gtl_hsa" \
    -D LINK_LIBRARIES="${ROCM_PATH}/lib/libamdhip64.so;${CRAY_MPICH_ROOTDIR}/gtl/lib/libmpi_gtl_hsa.so" \
    -D USE_HIP=1 \
        -D CMAKE_HIP_COMPILER_TOOLKIT_ROOT=$ROCM_PATH/hip \
    -D USE_MPI=1 \
        -D MPI_SKIP_SEARCH=1 \
        -D MPIEXEC="srun" \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY="${HDF5_DIR}" \
    -D USE_SILO=0 \
    $LBPM_SOURCE
```

**对于桌面 AMD GPU**:
```bash
cmake \
    -D CMAKE_BUILD_TYPE:STRING=Release \
    -D CMAKE_C_COMPILER:PATH=mpicc \
    -D CMAKE_CXX_COMPILER:PATH=mpicxx \
    -D CMAKE_CXX_STANDARD=14 \
    -D USE_HIP=1 \
        -D CMAKE_HIP_COMPILER_TOOLKIT_ROOT=$ROCM_PATH/hip \
    -D USE_MPI=1 \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY=$LBPM_HDF5_DIR \
    -D USE_SILO=1 \
        -D SILO_DIRECTORY=$LBPM_SILO_DIR \
    $LBPM_SOURCE
```

### 场景 4: 最小化构建

**适用**: 快速测试、CI/CD、资源受限环境

```bash
cmake \
    -D CMAKE_BUILD_TYPE:STRING=Release \
    -D CMAKE_C_COMPILER:PATH=mpicc \
    -D CMAKE_CXX_COMPILER:PATH=mpicxx \
    -D CMAKE_CXX_STANDARD=14 \
    -D USE_CUDA=0 \
    -D USE_HIP=0 \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY=$LBPM_HDF5_DIR \
    -D USE_SILO=0 \
    -D USE_NETCDF=0 \
    -D USE_TIMER=0 \
    -D USE_DOXYGEN:BOOL=FALSE \
    -D TEST_MAX_PROCS=2 \
    $LBPM_SOURCE
```

### 场景 5: Debug 调试构建

**适用**: 开发调试、问题诊断

```bash
cmake \
    -D CMAKE_BUILD_TYPE:STRING=Debug \
    -D CMAKE_C_FLAGS="-g -O0 -fPIC" \
    -D CMAKE_CXX_FLAGS="-g -O0 -fPIC" \
    -D CMAKE_CXX_STANDARD=14 \
    -D CMAKE_C_COMPILER:PATH=mpicc \
    -D CMAKE_CXX_COMPILER:PATH=mpicxx \
    -D ENABLE_GXX_DEBUG=1 \
    -D USE_CUDA=0 \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY=$LBPM_HDF5_DIR \
    -D USE_SILO=1 \
        -D SILO_DIRECTORY=$LBPM_SILO_DIR \
    $LBPM_SOURCE

# 使用 gdb 调试
mpirun -np 1 xterm -e gdb $LBPM_DIR/bin/lbpm_color_simulator
```

---

## CMake 选项参考

### 核心选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `CMAKE_BUILD_TYPE` | STRING | - | Release/Debug/RelWithDebInfo |
| `CMAKE_CXX_STANDARD` | INT | 14 | C++ 标准版本 (14/17/20) |
| `CMAKE_C_COMPILER` | PATH | - | C 编译器路径 |
| `CMAKE_CXX_COMPILER` | PATH | - | C++ 编译器路径 |
| `CMAKE_C_FLAGS` | STRING | - | C 编译标志 |
| `CMAKE_CXX_FLAGS` | STRING | - | C++ 编译标志 |

### MPI 选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `USE_MPI` | BOOL | 1 | 启用 MPI |
| `MPIEXEC` | STRING | mpirun | MPI 启动器 |
| `MPI_SKIP_SEARCH` | BOOL | FALSE | 跳过 MPI 自动搜索 |
| `USE_EXT_MPI_FOR_SERIAL_TESTS` | BOOL | FALSE | 串行测试使用 MPI |

### GPU 选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `USE_CUDA` | BOOL | 0 | 启用 CUDA |
| `CMAKE_CUDA_FLAGS` | STRING | - | CUDA 编译标志 |
| `CMAKE_CUDA_HOST_COMPILER` | PATH | - | CUDA 主机编译器 |
| `USE_HIP` | BOOL | 0 | 启用 HIP |
| `CMAKE_HIP_COMPILER_TOOLKIT_ROOT` | PATH | - | HIP 工具链根目录 |

### 依赖选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `USE_HDF5` | BOOL | 0 | 启用 HDF5 |
| `HDF5_DIRECTORY` | PATH | - | HDF5 安装目录 |
| `HDF5_LIB` | PATH | - | HDF5 库文件 |
| `USE_SILO` | BOOL | 0 | 启用 SILO |
| `SILO_DIRECTORY` | PATH | - | SILO 安装目录 |
| `SILO_LIB` | PATH | - | SILO 库文件 |
| `USE_NETCDF` | BOOL | 0 | 启用 NetCDF |
| `NETCDF_DIRECTORY` | PATH | - | NetCDF 安装目录 |
| `USE_TIMER` | BOOL | 0 | 启用性能计时器 |

### 测试选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `TEST_MAX_PROCS` | INT | 32 | 测试最大进程数 |
| `EXCLUDE_TESTS_FROM_ALL` | BOOL | FALSE | 从 ALL 排除测试 |

### 高级选项

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `DISABLE_LTO` | BOOL | FALSE | 禁用链接时优化 |
| `DISABLE_GOLD` | BOOL | FALSE | 禁用 gold 链接器 |
| `USE_STATIC` | BOOL | FALSE | 静态链接 |
| `ENABLE_GCOV` | BOOL | FALSE | 代码覆盖率 |
| `USE_DOXYGEN` | BOOL | TRUE | 生成文档 |
| `ONLY_BUILD_DOCS` | BOOL | FALSE | 仅构建文档 |

---

## 验证和测试

### 构建验证

**检查编译详细输出**:
```bash
make VERBOSE=1 -j4
```

**验证安装文件**:
```bash
# 检查可执行文件
ls $LBPM_DIR/bin/
# 应该看到: lbpm_color_simulator, lbpm_permeability_simulator 等

# 检查库文件
ls $LBPM_DIR/lib/
# 应该看到: liblbpm-wia.so 或 .a

# 检查头文件
ls $LBPM_DIR/include/
```

### 运行测试

**运行所有测试**:
```bash
cd $LBPM_DIR
ctest
```

**运行特定测试**:
```bash
# 运行单个测试
ctest -R hello_world

# 运行包含特定名称的测试
ctest -R Bubble

# 运行测试并显示详细输出
ctest -V -R TestColorGrad
```

**并行运行测试**:
```bash
ctest -j4
```

**查看测试列表**:
```bash
ctest -N
```

### 推荐的验证测试

**基础功能测试**:
```bash
ctest -R "hello_world|test_MPI|TestDatabase"
```

**物理模型测试**:
```bash
ctest -R "TestBubble|TestColorGrad|TestPoiseuille"
```

**GPU 测试** (如果启用):
```bash
# CUDA
cd $LBPM_DIR/tests/gpu
ctest

# HIP
cd $LBPM_DIR/tests/hip
ctest
```

### 运行示例模拟

**简单气泡测试**:
```bash
cd $LBPM_DIR
mkdir test-run && cd test-run
cp $LBPM_SOURCE/example/Bubble/input.db .

# CPU 运行
mpirun -np 2 $LBPM_DIR/bin/lbpm_color_simulator input.db

# GPU 运行
mpirun -np 2 $LBPM_DIR/bin/lbpm_color_simulator input.db
```

**检查输出**:
```bash
ls *.silo  # SILO 可视化文件
ls *.h5    # HDF5 数据文件
```

### 性能验证

**检查 GPU 使用** (CUDA):
```bash
# 运行模拟时，另一终端监控
nvidia-smi -l 1
```

**检查 GPU 使用** (HIP):
```bash
rocm-smi -l 1
```

**MPI 通信测试**:
```bash
mpirun -np 4 $LBPM_DIR/tests/test_MPI
```

---

## 故障排除

### 依赖问题

#### 问题: HDF5 未找到

**错误信息**:
```
FATAL_ERROR: Default search for hdf5 is not yet supported
```

**解决方案**:
```bash
# 1. 确认 HDF5 已安装
ls /opt/hdf5/include/hdf5.h
ls /opt/hdf5/lib/libhdf5.a

# 2. 显式指定路径
cmake ... \
    -D USE_HDF5=1 \
    -D HDF5_DIRECTORY=/opt/hdf5 \
    ...

# 3. 如果使用系统包
cmake ... \
    -D USE_HDF5=1 \
    -D HDF5_DIRECTORY=/usr \
    ...
```

#### 问题: SILO 版本不兼容

**错误信息**:
```
error: undefined reference to `DBGetXXX'
```

**解决方案**:
使用 LBPM 推荐的修改版 SILO
```bash
wget https://bitbucket.org/AdvancedMultiPhysics/tpl-builder/downloads/Silo-4.10.3RC.modified.tar.gz
# 然后重新编译 SILO（参见依赖项章节）
```

#### 问题: MPI 找不到

**错误信息**:
```
Could not find MPI
```

**解决方案**:
```bash
# 1. 检查 MPI 环境
which mpicc mpicxx
mpicc --version

# 2. 加载 MPI 模块（HPC 系统）
module load openmpi
# 或
module load intel-mpi

# 3. 设置环境变量
export PATH=/opt/openmpi/bin:$PATH
export LD_LIBRARY_PATH=/opt/openmpi/lib:$LD_LIBRARY_PATH

# 4. 显式指定编译器
cmake ... \
    -D CMAKE_C_COMPILER=/opt/openmpi/bin/mpicc \
    -D CMAKE_CXX_COMPILER=/opt/openmpi/bin/mpicxx \
    ...
```

### 编译问题

#### 问题: C++ 标准不支持

**错误信息**:
```
FATAL_ERROR: C++14 or newer required
```

**解决方案**:
```bash
# 1. 检查编译器版本
g++ --version
# GCC 需要 7.5.0+

# 2. 升级编译器或使用其他编译器
sudo apt-get install g++-9

# 3. 显式指定标准
cmake ... \
    -D CMAKE_CXX_STANDARD=14 \
    ...
```

#### 问题: MPI 编译器不一致

**错误信息**:
```
undefined reference to `MPI_XXX'
```

**解决方案**:
确保 HDF5、SILO 和 LBPM 使用相同的 MPI
```bash
# 查看 MPI 版本
mpicc --version
which mpicc

# 重新编译 HDF5 和 SILO，使用相同的 MPI
CC=mpicc CXX=mpicxx ./configure ...
```

#### 问题: 链接错误

**错误信息**:
```
undefined reference to `H5XXX'
```

**解决方案**:
```bash
# 检查库文件
ls $HDF5_DIR/lib/

# 确保使用正确的库路径
cmake ... \
    -D HDF5_LIB=$HDF5_DIR/lib/libhdf5.a \
    ...

# 或使用动态库
cmake ... \
    -D HDF5_LIB=$HDF5_DIR/lib/libhdf5.so \
    ...
```

### GPU 特定问题

#### CUDA: 架构不匹配

**错误信息**:
```
error: unsupported GPU architecture 'compute_XX'
```

**解决方案**:
```bash
# 1. 查看 GPU 型号和计算能力
nvidia-smi --query-gpu=name,compute_cap --format=csv

# 2. 设置正确的架构
# Tesla V100 -> sm_70
cmake ... \
    -D CMAKE_CUDA_FLAGS="-arch sm_70 ..." \
    ...

# 3. 支持多种架构
cmake ... \
    -D CMAKE_CUDA_FLAGS="-gencode arch=compute_70,code=sm_70 -gencode arch=compute_80,code=sm_80" \
    ...
```

#### CUDA: 主机编译器不兼容

**错误信息**:
```
error: unsupported GNU version! gcc versions later than X are not supported
```

**解决方案**:
```bash
# 使用兼容的 GCC 版本
cmake ... \
    -D CMAKE_CUDA_HOST_COMPILER=/usr/bin/gcc-7 \
    ...
```

#### HIP: GTL 库缺失

**错误信息**:
```
undefined reference to `mpi_gtl_hsa'
```

**解决方案**:
```bash
# Cray 系统设置 GTL 环境变量
export PE_MPICH_GTL_DIR_amd_gfx90a="-L${CRAY_MPICH_ROOTDIR}/gtl/lib"
export PE_MPICH_GTL_LIBS_amd_gfx90a="-lmpi_gtl_hsa"

# 配置时添加链接库
cmake ... \
    -D LINK_LIBRARIES="${ROCM_PATH}/lib/libamdhip64.so;${CRAY_MPICH_ROOTDIR}/gtl/lib/libmpi_gtl_hsa.so" \
    ...
```

#### GPU: 运行时错误

**检查 GPU 可见性**:
```bash
# CUDA
nvidia-smi
export CUDA_VISIBLE_DEVICES=0,1,2,3

# HIP
rocm-smi
export HIP_VISIBLE_DEVICES=0,1,2,3
```

### 测试问题

#### 问题: 测试超出可用核心数

**错误信息**:
```
Test #XX: ... (Disabled, exceeds TEST_MAX_PROCS)
```

**解决方案**:
```bash
# 调整最大进程数
cmake ... \
    -D TEST_MAX_PROCS=4 \
    ...

# 或运行特定测试
ctest -R "test_name" --verbose
```

#### 问题: 串行测试 MPI 错误

**解决方案**:
```bash
cmake ... \
    -D USE_EXT_MPI_FOR_SERIAL_TESTS:BOOL=TRUE \
    ...
```

#### 问题: 测试数据文件缺失

**解决方案**:
```bash
# 确保在构建目录运行测试
cd $LBPM_DIR
ctest

# 或指定测试数据路径
ctest -R TestBubble --verbose
```

### 平台特定问题

#### Cray 系统

**问题**: 默认链接器问题

**解决方案**:
```bash
cmake ... \
    -D DISABLE_GOLD:BOOL=TRUE \
    -D DISABLE_LTO:BOOL=TRUE \
    ...
```

#### WSL2

**问题**: CUDA 不可用

**解决方案**:
WSL2 支持 CUDA 需要特定配置:
```bash
# 1. 安装 Windows NVIDIA 驱动 (470.76+)
# 2. WSL2 内安装 CUDA toolkit (无需驱动)
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
sudo mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.6.0/local_installers/cuda-repo-wsl-ubuntu-11-6-local_11.6.0-1_amd64.deb
sudo dpkg -i cuda-repo-wsl-ubuntu-11-6-local_11.6.0-1_amd64.deb
sudo apt-key add /var/cuda-repo-wsl-ubuntu-11-6-local/7fa2af80.pub
sudo apt-get update
sudo apt-get install cuda

# 3. 验证
nvidia-smi
```

#### macOS

LBPM 主要针对 Linux，macOS 支持有限。建议使用 Docker 或 Linux VM。

---

## 平台特定说明

### WSL2 (Windows Subsystem for Linux)

**推荐配置**:

1. **安装 WSL2 和 Ubuntu**:
```powershell
# PowerShell (管理员)
wsl --install -d Ubuntu-20.04
```

2. **更新系统**:
```bash
sudo apt update && sudo apt upgrade -y
```

3. **安装基础工具**:
```bash
sudo apt install -y build-essential cmake git wget
```

4. **安装 MPI**:
```bash
sudo apt install -y libopenmpi-dev openmpi-bin
```

5. **构建依赖** (按本指南的依赖项章节)

6. **构建 LBPM** (使用场景1的CPU配置)

**WSL2 优势**:
- 原生 Linux 环境
- 可以使用 Windows IDE (VS Code Remote-WSL)
- 文件系统性能良好

**注意事项**:
- 文件存放在 Linux 文件系统 (`/home/`) 性能更好
- GPU 支持需要 CUDA on WSL2

### HPC 集群环境

**通用步骤**:

1. **加载模块**:
```bash
module purge
module load gcc/9.3.0
module load openmpi/4.1.0
module load cmake/3.21.0
module load hdf5/1.10.7
```

2. **设置环境**:
```bash
export LBPM_SOURCE=$HOME/LBPM
export LBPM_DIR=$SCRATCH/lbpm-build
```

3. **使用作业脚本编译**:
```bash
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --time=1:00:00
#SBATCH --job-name=lbpm-build

cd $LBPM_DIR
cmake [配置选项] $LBPM_SOURCE
make -j16
make install
```

**常见 HPC 系统配置**:

- **Summit** (OLCF): 参考 `sample_scripts/configure_summit`
- **Crusher/Frontier** (OLCF): 参考 `sample_scripts/configure_crusher_hip`
- **Perlmutter** (NERSC): 参考 `sample_scripts/configure_basic_cluster`

### 桌面工作站

**Ubuntu 20.04 完整安装示例**:

```bash
# 1. 系统准备
sudo apt update
sudo apt install -y build-essential cmake git wget curl

# 2. 安装 MPI
sudo apt install -y libopenmpi-dev openmpi-bin

# 3. 安装依赖工具
sudo apt install -y zlib1g-dev

# 4. 创建目录
export LBPM_TPL=/opt/lbpm-tpl
sudo mkdir -p $LBPM_TPL
sudo chown $USER:$USER $LBPM_TPL

# 5. 构建 HDF5
cd $LBPM_TPL
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.7/src/hdf5-1.10.7.tar.gz
tar -xzf hdf5-1.10.7.tar.gz
cd hdf5-1.10.7
CC=mpicc CXX=mpicxx CXXFLAGS="-fPIC -O3 -std=c++14" \
./configure --prefix=$LBPM_TPL/hdf5 --enable-parallel --enable-shared
make -j$(nproc) && make install

# 6. 构建 SILO
cd $LBPM_TPL
wget https://bitbucket.org/AdvancedMultiPhysics/tpl-builder/downloads/Silo-4.10.3RC.modified.tar.gz
tar -xzf Silo-4.10.3RC.modified.tar.gz
cd Silo-4.10.3RC
CC=mpicc CXX=mpicxx CXXFLAGS="-fPIC -O3 -std=c++14" \
./configure --prefix=$LBPM_TPL/silo \
            --with-hdf5=$LBPM_TPL/hdf5/include,$LBPM_TPL/hdf5/lib \
            --enable-static --disable-silex
make -j$(nproc) && make install

# 7. 克隆 LBPM
cd ~
git clone https://github.com/OPM/LBPM-WIA.git LBPM

# 8. 构建 LBPM
mkdir ~/lbpm-build && cd ~/lbpm-build
cmake \
    -D CMAKE_BUILD_TYPE:STRING=Release \
    -D CMAKE_C_COMPILER:PATH=mpicc \
    -D CMAKE_CXX_COMPILER:PATH=mpicxx \
    -D CMAKE_CXX_STANDARD=14 \
    -D USE_CUDA=0 \
    -D USE_HDF5=1 \
        -D HDF5_DIRECTORY=$LBPM_TPL/hdf5 \
    -D USE_SILO=1 \
        -D SILO_DIRECTORY=$LBPM_TPL/silo \
    ~/LBPM

make -j$(nproc)
make install
ctest

# 9. 添加到 PATH
echo "export PATH=$HOME/lbpm-build/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc
```

---

## 附录

### 使用预配置脚本

LBPM 提供了 30+ 个预配置脚本，位于 `sample_scripts/` 目录:

**桌面环境**:
- `configure_desktop` - 通用桌面配置
- `configure_ubuntu` - Ubuntu 特定配置

**HPC 集群**:
- `configure_summit` - ORNL Summit (CUDA)
- `configure_crusher_hip` - ORNL Crusher (HIP)
- `configure_crusher_cpu` - ORNL Crusher (CPU)
- `configure_spock_hip` - ORNL Spock (HIP)

**使用方法**:
```bash
# 1. 复制并编辑脚本
cp $LBPM_SOURCE/sample_scripts/configure_desktop my_config.sh
nano my_config.sh
# 修改路径：HDF5_DIRECTORY, SILO_DIRECTORY 等

# 2. 运行配置
cd $LBPM_DIR
chmod +x my_config.sh
./my_config.sh

# 3. 编译
make -j4 && make install
```

### 使用 TPL Builder

对于完全从源码构建所有依赖:

```bash
# 1. 克隆 TPL Builder
git clone https://bitbucket.org/AdvancedMultiPhysics/tpl-builder

# 2. 准备源码包
mkdir tpl-source
cd tpl-source
wget https://zlib.net/zlib-1.2.11.tar.gz
wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.7/src/hdf5-1.10.7.tar.gz
wget https://bitbucket.org/AdvancedMultiPhysics/tpl-builder/downloads/Silo-4.10.3RC.modified.tar.gz

# 3. 构建 TPL
mkdir tpl-build && cd tpl-build
cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/opt/lbpm-tpl \
    -D TPL_LIST:STRING="ZLIB;HDF5;SILO" \
    -D ZLIB_URL="$PWD/../tpl-source/zlib-1.2.11.tar.gz" \
    -D HDF5_URL="$PWD/../tpl-source/hdf5-1.10.7.tar.gz" \
    -D SILO_URL="$PWD/../tpl-source/Silo-4.10.3RC.modified.tar.gz" \
    ../tpl-builder

make -j4
```

### 环境变量参考

**编译时**:
```bash
export CC=mpicc
export CXX=mpicxx
export CFLAGS="-fPIC -O3"
export CXXFLAGS="-fPIC -O3 -std=c++14"
```

**运行时**:
```bash
export LD_LIBRARY_PATH=/opt/hdf5/lib:/opt/silo/lib:$LD_LIBRARY_PATH
export PATH=$LBPM_DIR/bin:$PATH

# GPU
export CUDA_VISIBLE_DEVICES=0,1,2,3
export HIP_VISIBLE_DEVICES=0,1,2,3
```

### 常用命令速查

```bash
# 清理构建
make clean
rm -rf CMakeCache.txt CMakeFiles

# 完全重新配置
cd $LBPM_DIR
rm -rf *
cmake [配置选项] $LBPM_SOURCE

# 只编译特定目标
make lbpm_color_simulator

# 安装到自定义位置
cmake ... -D CMAKE_INSTALL_PREFIX=/custom/path ...

# 查看 CMake 变量
cmake -L $LBPM_DIR
cmake -LAH $LBPM_DIR  # 显示帮助

# 格式化代码
cd $LBPM_SOURCE
./clang-format-all
```

### 获取帮助

- **项目主页**: https://github.com/OPM/LBPM-WIA
- **文档**: `docs/` 目录
- **示例**: `example/` 目录
- **Issues**: GitHub Issues 页面

---

**最后更新**: 2025-11
**LBPM 版本**: master branch
