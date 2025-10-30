# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

LBPM (Lattice Boltzmann Methods for Porous Media) 是一个多相流多孔介质模拟框架，基于格子玻尔兹曼方法(LBM)。这是一个高性能计算(HPC)项目，支持 CPU、CUDA 和 HIP 后端。

**项目特点:**
- 大规模并行计算框架 (MPI + GPU/CPU)
- 多物理场耦合模拟 (两相流、电化学、非牛顿流体等)
- ScaLBL 核心库提供统一的 CPU/GPU 接口
- 支持多种边界条件和复杂几何结构

## 构建系统

### 必需依赖
- MPI (并行计算框架)
- HDF5 (数据输出)
- SILO (可视化数据格式)
- C++14 或更高版本
- CMake 3.9+

### 可选依赖
- NetCDF (网络通用数据格式)
- CUDA (NVIDIA GPU 加速)
- HIP (AMD GPU 加速)
- TimerUtility (性能分析)

### 配置和构建流程

**不要在源码目录中构建！必须使用独立的构建目录:**

```bash
# 1. 创建并进入独立的构建目录
mkdir /path/to/build
cd /path/to/build

# 2. 编辑并运行配置脚本
# 示例配置脚本位于 sample_scripts/ 目录
/path/to/LBPM/sample_scripts/configure_desktop

# 3. 编译和安装
make -j4 && make install

# 4. 运行测试
ctest
```

**配置脚本示例** (`sample_scripts/configure_desktop`):
- 使用 mpicc/mpicxx 作为编译器
- 指定 HDF5、SILO 库路径
- 设置 CUDA/HIP 选项
- 可选 USE_CUDA=1, USE_HIP=1, USE_NETCDF=1 等开关

### 重要的 CMake 目标

```bash
make                 # 编译主库和可执行文件
make install         # 安装到指定目录
make test / ctest    # 运行所有测试
make doc             # 生成 Doxygen 文档
make build-test      # 构建测试但不运行
make build-examples  # 构建示例程序
make check           # 等同于 make test
```

### 单个测试运行

```bash
# 运行特定测试
ctest -R TestName

# 并行测试 (使用 MPI)
mpirun -np 4 ./tests/lbpm_color_simulator input.db

# 查看详细输出
ctest -V -R TestName
```

## 代码架构

### 核心目录结构

```
LBPM/
├── common/          # 核心数据结构和通信
│   ├── Domain.h/cpp       # 并行域分解
│   ├── ScaLBL.h/cpp       # CPU/GPU 统一接口
│   ├── Communication.h    # MPI 通信框架
│   ├── Array.h            # 多维数组模板
│   ├── MPI.h              # MPI 包装器
│   └── Database.h         # 输入参数解析
├── models/          # 物理模型实现
│   ├── ColorModel.h/cpp           # 两相流色模型 (D3Q19+D3Q7)
│   ├── GreyscaleModel.h/cpp       # 灰度模型
│   ├── FreeLeeModel.h/cpp         # Free energy 模型
│   ├── IonModel.h/cpp             # 离子输运
│   ├── PoissonSolver.h/cpp        # 泊松方程求解器
│   ├── StokesModel.h/cpp          # 斯托克斯流动
│   └── MultiPhysController.h      # 多物理耦合控制器
├── cpu/             # CPU 实现的核心算法
│   ├── Color.cpp        # 两相流算法
│   ├── D3Q19.cpp        # D3Q19 格子
│   ├── D3Q7.cpp         # D3Q7 格子
│   ├── MRT.cpp          # 多松弛时间
│   ├── BGK.cpp          # BGK 碰撞算子
│   ├── Poisson.cpp      # 泊松求解器
│   └── Ion.cpp          # 离子输运
├── cuda/            # CUDA 内核 (.cu 文件)
├── hip/             # HIP 内核 (.hip 文件)
├── analysis/        # 后处理和分析
│   ├── TwoPhase.h         # 两相流分析
│   ├── morphology.cpp     # 形态学分析
│   ├── Minkowski.cpp      # Minkowski 函数
│   └── pmmc.h             # PMMC 算法
├── IO/              # 输入输出
│   ├── HDF5_IO.h/cpp      # HDF5 接口
│   ├── silo.h/cpp         # SILO 可视化
│   ├── Writer.h           # 数据写入
│   └── Reader.h           # 数据读取
├── tests/           # 测试和可执行程序
│   ├── lbpm_color_simulator.cpp
│   ├── lbpm_greyscale_simulator.cpp
│   ├── lbpm_BGK_simulator.cpp
│   ├── TestComm*.cpp      # 通信测试
│   └── Test*.cpp          # 单元测试
└── example/         # 示例和工作流
    ├── Bubble/            # 气泡模拟
    ├── Droplet/           # 液滴
    ├── drainage/          # 排水过程
    └── Python/            # Python 后处理脚本
```

### 关键抽象层次

**1. 底层: ScaLBL 抽象层** (`common/ScaLBL.h`)
- 提供 `ScaLBL_*` 函数族统一 CPU/CUDA/HIP 接口
- 内存管理: `ScaLBL_AllocateDeviceMemory`, `ScaLBL_CopyToDevice`
- 设备选择: `ScaLBL_SetDevice`
- 具体实现在 `cpu/*.cpp`, `cuda/*.cu`, `hip/*.hip`

**2. 中间层: Domain 类** (`common/Domain.h`)
- 管理并行域分解 (使用 MPI)
- 存储 3D 图像数据 (8-bit 标签)
- 处理边界条件 (BC: 0=周期, 1=流入流出等)
- 提供 halo 通信接口

**3. 高层: Model 类** (`models/*.h`)
- 封装完整的物理求解器
- 例如 `ScaLBL_ColorModel`:
  - 动量方程: D3Q19 格子
  - 质量输运: D3Q7 格子
  - 包含初始化、时间推进、输出等完整流程
- 使用 Database 对象读取输入参数

**4. 应用层: Simulator** (`tests/lbpm_*_simulator.cpp`)
- 主程序入口
- 初始化 MPI、读取输入、创建 Domain 和 Model 对象
- 调用 Model 的 `Run()` 方法执行模拟

### 通信模式

- **MPI 并行**: 使用 `common/Communication.h` 和自定义 MPI 包装器
- **Halo 交换**: 子域边界的 ghost cell 更新
- **GPU 直接通信**: 支持 CUDA-aware MPI (当启用时)

### 数据流

```
输入 (.db + geometry files)
  ↓
Domain 初始化 (域分解)
  ↓
Model 初始化 (分配内存, 设置初始条件)
  ↓
时间循环:
  - 碰撞 (Collision)
  - 迁移 (Streaming)
  - Halo 通信
  - 边界条件
  - 分析输出 (每 N 步)
  ↓
输出 (HDF5/SILO 可视化文件)
```

## 开发规范

### 平台特定代码

- **CPU 实现**: `cpu/*.cpp` - 普通 C++ 代码
- **CUDA 实现**: `cuda/*.cu` - CUDA 内核, 使用 `__global__` 和 `__device__`
- **HIP 实现**: `hip/*.hip` - HIP 内核, 与 CUDA 类似但不同扩展名
- **共享接口**: 通过 `ScaLBL.h` 中的 `extern "C"` 函数统一调用

### CMake 宏

项目使用自定义 CMake 宏 (`cmake/LBPM-macros.cmake`):
- `ADD_LBPM_EXECUTABLE(name)` - 添加可执行文件
- `ADD_LBPM_TEST(name ...)` - 添加测试
- `ADD_LBPM_TEST_PARALLEL(name nproc ...)` - 并行测试
- `INSTALL_LBPM_TARGET(name)` - 安装目标

### 输入文件格式

输入使用 `.db` 文件 (Database 格式), 例如:
```
Domain {
    Nx = 64
    Ny = 64
    Nz = 64
    nproc = 2 2 1
    BC = 0  // 0=periodic
}

Color {
    tauA = 0.7
    tauB = 0.7
    alpha = 0.005
    beta = 0.95
    timestepMax = 100000
}
```

### 测试策略

- **单元测试**: `Test*.cpp` 文件测试单个组件
- **集成测试**: `lbpm_*_simulator.cpp` 测试完整工作流
- **并行测试**: 使用 `ADD_LBPM_TEST_1_2_4` 宏在 1/2/4 进程上测试

## Python 工具

`example/Python/` 目录包含后处理脚本:
- `lbpm_morph_utils.py` - 形态学分析工具
- `lbpm_*_Postprocessing_utils.py` - 可视化和数据处理
- `LBPM_Preprocessing_*.py` - 输入数据准备

## 文档生成

需要安装:
```bash
pip install Sphinx sphinx-rtd-theme breathe
sudo apt-get install dvipng texlive-latex-extra
```

构建文档:
```bash
# 1. 构建 LBPM 时启用 USE_DOXYGEN
# 2. make doc  (生成 Doxygen XML)
# 3. cd docs && make html
```

## 调试和分析

- **Valgrind**: 使用 `ValgrindSuppresionFile` 抑制已知的第三方库误报
- **性能分析**: 可选集成 TimerUtility
- **代码格式**: 提供 `.clang-format` 和 `clang-format-all` 脚本

## 注意事项

1. **并行调试**: MPI 程序需要特殊调试技术 (例如 `mpirun -np 1 xterm -e gdb ...`)
2. **GPU 内存**: CUDA/HIP 代码需要注意设备内存管理和同步
3. **大数据**: HDF5 输出可能非常大, 注意磁盘空间
4. **版本兼容**: 不同 HPC 系统的 MPI/CUDA/HIP 版本差异较大, 参考 `sample_scripts/` 中的配置

## 常见任务

### 添加新的物理模型

1. 在 `models/` 创建 `NewModel.h` 和 `NewModel.cpp`
2. 在 `cpu/cuda/hip/` 添加对应的内核实现
3. 在 `tests/` 添加 `lbpm_new_simulator.cpp`
4. 修改 `tests/CMakeLists.txt` 添加 `ADD_LBPM_EXECUTABLE(lbpm_new_simulator)`

### 修改现有算法

1. 定位到 `cpu/` 或 `cuda/hip/` 中的相关文件
2. 修改函数实现 (CPU 和 GPU 版本需要同步修改)
3. 运行相关测试: `ctest -R TestName`
4. 验证输出结果

### 添加新的分析功能

1. 在 `analysis/` 添加新的类或函数
2. 在 Model 类中调用分析功能
3. 修改输出逻辑将结果写入文件
