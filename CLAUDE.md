# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

LBPM (Lattice Boltzmann Methods for Porous Media) 是一个基于格子玻尔兹曼方法的多孔介质流动模拟框架。该项目使用C++14编写，支持MPI并行计算，并可选支持CUDA和HIP GPU加速。

## 核心依赖

**必需依赖:**
- MPI (并行计算)
- HDF5 (数据输出)
- SILO (可视化输出)
- C++14或更高版本

**可选依赖:**
- NetCDF (可选数据格式)
- CUDA (NVIDIA GPU加速)
- HIP (AMD GPU加速)
- TimerUtility (性能分析)

## 构建系统

### CMake 配置要求

- **严格禁止源码内构建** - 必须创建独立的构建目录
- CMake 最低版本: 3.9
- C++标准: C++14 (可通过 CMAKE_CXX_STANDARD 指定)
- **重要**: 在主 CMakeLists.txt 中添加 `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)` 以生成 compile_commands.json

### 构建流程

```bash
# 1. 创建构建目录(必须在源码目录外)
mkdir /path/to/build
cd /path/to/build

# 2. 配置 - 使用或修改 sample_scripts/ 中的配置脚本
/path/to/LBPM/sample_scripts/configure_desktop

# 3. 编译和安装
make -j4 && make install

# 4. 运行测试
ctest
```

### 配置脚本说明

- `sample_scripts/` 目录包含各种平台的配置示例
  - `configure_desktop` - 标准桌面环境
  - `configure_crusher_hip` - AMD GPU (HIP)
  - `configure_summit` - NVIDIA GPU (CUDA)
  - 等各种HPC集群配置

关键配置参数:
```cmake
-D CMAKE_C_COMPILER=mpicc
-D CMAKE_CXX_COMPILER=mpicxx
-D CMAKE_CXX_STANDARD=14
-D USE_CUDA=0/1          # CUDA支持
-D USE_HIP=0/1           # HIP支持
-D USE_SILO=1            # SILO输出
-D USE_NETCDF=0/1        # NetCDF支持
-D HDF5_DIRECTORY=/path/to/hdf5
-D SILO_DIRECTORY=/path/to/silo
```

## 项目架构

### 源码目录结构

```
LBPM/
├── common/          # 基础数据结构和工具
│   ├── Domain.{h,cpp}        # 区域分解和MPI通信
│   ├── ScaLBL.{h,cpp}        # ScaLBL框架核心
│   ├── MPI.{h,cpp}           # MPI包装器
│   ├── Database.{h,cpp}      # 参数数据库
│   ├── Communication.h        # Halo交换通信
│   └── ReadMicroCT.{h,cpp}   # 微CT图像读取
├── models/          # LBM物理模型
│   ├── ColorModel.{h,cpp}           # 两相流色模型(主要模型)
│   ├── GreyscaleModel.{h,cpp}       # 灰度单相流
│   ├── GreyscaleColorModel.{h,cpp}  # 灰度-颜色耦合
│   ├── FreeLeeModel.{h,cpp}         # Free energy模型
│   ├── IonModel.{h,cpp}             # 离子传输
│   ├── PoissonSolver.{h,cpp}        # 泊松求解器
│   ├── StokesModel.{h,cpp}          # Stokes流动
│   └── BGKModel.{h,cpp}             # BGK碰撞模型
├── cpu/             # CPU实现
│   ├── D3Q19.cpp             # D3Q19格子(动量方程)
│   ├── D3Q7.cpp              # D3Q7格子(质量方程)
│   ├── Color.cpp             # 颜色模型核心函数
│   ├── MRT.cpp               # 多弛豫时间碰撞算子
│   └── exe/                  # CPU可执行文件
├── cuda/            # CUDA GPU实现(.cu文件)
├── hip/             # HIP GPU实现
├── analysis/        # 后处理分析工具
│   ├── TwoPhase.{h,cpp}      # 两相流分析
│   ├── runAnalysis.{h,cpp}   # 分析运行器
│   ├── morphology.{h,cpp}    # 形态学分析
│   ├── Minkowski.{h,cpp}     # Minkowski泛函
│   └── pmmc.h                # 分段马尔可夫链表面重建
├── IO/              # I/O工具
│   ├── Writer.{h,cpp}        # 通用写入器
│   ├── Reader.{h,cpp}        # 通用读取器
│   ├── HDF5_IO.{h,cpp}       # HDF5接口
│   └── silo.{h,cpp,hpp}      # SILO可视化输出
├── tests/           # 测试和模拟器
│   ├── lbpm_*_simulator.cpp  # 各种模拟器程序
│   └── Test*.cpp             # 单元测试
├── example/         # 示例配置
│   ├── Bubble/               # 气泡测试用例
│   ├── drainage/             # 排水过程
│   ├── imbibition/           # 渗吸过程
│   └── */input.db            # 输入参数文件(二进制)
├── workflows/       # 工作流脚本
└── cmake/           # CMake宏和配置
    ├── macros.cmake
    ├── libraries.cmake
    └── LBPM-macros.cmake
```

### 关键抽象

**Domain (common/Domain.h)**
- 管理MPI区域分解
- 处理3D图像数据到多个进程的分发
- 提供Halo交换机制
- 每个进程获得 [Nx, Ny, Nz] 子域

**ScaLBL Framework (common/ScaLBL.h)**
- GPU/CPU数据结构的核心框架
- 设备内存管理
- Halo通信优化

**Model Classes (models/)**
- 各物理模型的高层接口
- 初始化、参数读取、运行循环
- 典型模式: ReadParams() → SetDomain() → ReadInput() → Initialize() → Run()

**Lattice Schemes**
- D3Q19: 19速度格子，用于动量方程
- D3Q7: 7速度格子，用于质量/浓度方程

**Color Model (最常用)**
- 两相不混溶流动模拟
- 使用颜色梯度方法追踪界面
- 支持多种边界条件和湿润性设置

## 测试

### 运行所有测试
```bash
ctest
```

### 运行特定测试
```bash
ctest -R TestName
```

### 测试分类
- 单元测试: Test*.cpp (例如 TestFluxBC, TestTorus)
- 集成测试: 使用示例输入文件 (例如 TestColorBubble ../example/Bubble/input.db)
- 并行测试: 自动以1、2、4进程运行 (通过 ADD_LBPM_TEST_1_2_4)

## 模拟器程序

主要模拟器位于 `tests/` 目录:
- `lbpm_color_simulator` - 两相流颜色模型
- `lbpm_greyscale_simulator` - 灰度单相流
- `lbpm_permeability_simulator` - 渗透率计算
- `lbpm_nernst_planck_simulator` - 电化学离子传输
- `lbpm_BGK_simulator` - 单松弛时间BGK模型

运行方式:
```bash
mpirun -np 4 lbpm_color_simulator input.db
```

## GPU 支持

项目支持三种后端:
1. **CPU** (cpu/ 目录) - .cpp文件
2. **CUDA** (cuda/ 目录) - .cu文件，通过 USE_CUDA=1 启用
3. **HIP** (hip/ 目录) - HIP文件，通过 USE_HIP=1 启用

GPU实现文件与CPU文件保持对应关系(例如 cpu/Color.cpp 对应 cuda/Color.cu)

## 输入文件

- 输入文件通常为 `.db` 格式的二进制数据库文件
- 包含模拟参数、几何信息、物理参数等
- 示例文件位于 `example/*/input.db`

## 文档生成

需要安装:
```bash
pip install Sphinx sphinx-rtd-theme breathe
sudo apt-get install dvipng texlive texlive-latex-recommended texlive-pictures texlive-latex-extra
```

构建文档:
```bash
# 1. 配置时启用 Doxygen
# 2. 构建 doxygen
make doc

# 3. 构建 Sphinx HTML
cd docs/
make html
```

## 代码风格

- 使用 `.clang-format` 进行代码格式化
- 运行 `./clang-format-all` 格式化所有源文件

## 重要开发注意事项

1. **区域分解**: 所有并行算法必须考虑MPI区域分解和Halo通信
2. **GPU同步**: 注意 `ScaLBL_DeviceBarrier()` 的使用
3. **输入验证**: 模拟器需要通过 `Database` 类读取参数
4. **测试覆盖**: 新功能需要添加对应的测试用例到 tests/CMakeLists.txt
5. **后端兼容**: 如果修改算法，需要同步更新 cpu/、cuda/、hip/ 三个后端
