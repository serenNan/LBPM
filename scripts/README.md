# LBPM 编译安装脚本

本目录包含用于编译和安装 LBPM 项目的所有自动化脚本。

## 📁 文件列表

### 安装脚本

| 文件名 | 用途 | 预计时间 |
|--------|------|----------|
| `install_cuda.sh` | 安装 CUDA Toolkit 12.6 | 15-20 分钟 |
| `install_cuda.fish` | CUDA 安装（Fish Shell 版本） | 15-20 分钟 |
| `install_silo.sh` | 编译安装 SILO 可视化库 | 10-15 分钟 |
| `build_lbpm_full.sh` | 编译 LBPM 完整版（含 CUDA + SILO） | 20-30 分钟 |

### 文档

| 文件名 | 说明 |
|--------|------|
| `lbpm_install_guide.txt` | 完整的安装指南（分步说明） |
| `lbpm_dependencies_summary.txt` | 依赖库配置摘要 |
| `README.md` | 本文件 |

---

## 🚀 快速开始

### 方式一：分步安装（推荐）

```bash
# 1. 安装 CUDA Toolkit（需要 sudo）
bash scripts/install_cuda.sh

# 2. 安装 SILO 库（需要 sudo）
bash scripts/install_silo.sh

# 3. 编译 LBPM
bash scripts/build_lbpm_full.sh
```

### 方式二：一键安装

```bash
bash scripts/install_cuda.sh && \
bash scripts/install_silo.sh && \
bash scripts/build_lbpm_full.sh
```

**总耗时**: 约 45-65 分钟

---

## 📋 安装步骤详解

### 步骤 1: 安装 CUDA Toolkit

**命令**:
```bash
bash scripts/install_cuda.sh
```

**操作**:
- 安装 CUDA 12.6
- 配置环境变量（自动添加到 `~/.bashrc` 或 `~/.config/fish/config.fish`）
- 验证安装

**完成标志**:
```bash
nvcc --version  # 应显示 CUDA 版本
```

**注意**: 安装完成后需要重新打开终端或运行 `source ~/.bashrc`

---

### 步骤 2: 安装 SILO 库

**命令**:
```bash
bash scripts/install_silo.sh
```

**操作**:
- 下载 SILO 4.11 源码
- 配置并编译（使用 4 线程）
- 安装到 `/opt/silo`

**完成标志**:
```bash
ls /opt/silo/lib/libsilo*  # 应显示库文件
```

**可选**: 如果不需要 SILO 可视化，可以跳过此步骤

---

### 步骤 3: 编译 LBPM

**命令**:
```bash
bash scripts/build_lbpm_full.sh
```

**操作**:
1. 检查所有依赖（CUDA, MPI, HDF5, SILO）
2. 自动检测 GPU 架构（RTX 3060 = sm_86）
3. 配置 CMake
4. 编译（使用 4 线程）
5. 安装到 `~/build/LBPM-full`
6. 运行快速测试

**完成标志**:
```bash
ls ~/build/LBPM-full/tests/lbpm_*_simulator
```

---

## 🖥️ 系统要求

### 硬件
- **CPU**: 4+ 核心（推荐 8+）
- **内存**: 8 GB 最小，16 GB 推荐
- **GPU**: NVIDIA GPU（支持 CUDA）
- **磁盘**: 至少 5 GB 可用空间

### 软件
- **操作系统**: Linux (Ubuntu, CentOS 等)
- **必需**: GCC, MPI, HDF5, CMake
- **可选**: SILO, NetCDF, TimerUtility

---

## 🔧 编译选项说明

### 已启用的功能

| 功能 | 说明 |
|------|------|
| ✅ **CUDA GPU 加速** | 自动检测 GPU 架构 |
| ✅ **MPI 并行** | OpenMPI 支持 |
| ✅ **HDF5 输出** | 数据存储格式 |
| ✅ **SILO 可视化** | VisIt 兼容格式 |
| ✅ **Release 优化** | `-O3 -march=native` |

### 已禁用的功能

| 功能 | 原因 | 如何启用 |
|------|------|----------|
| ❌ **NetCDF** | 可选，非必需 | 编辑脚本设置 `USE_NETCDF=1` |
| ❌ **TimerUtility** | 性能分析工具，可选 | 先安装 TimerUtility 库 |
| ❌ **Doxygen 文档** | 加快编译速度 | 设置 `USE_DOXYGEN=1` |

---

## 📊 编译配置详情

完整的 CMake 配置（在 `build_lbpm_full.sh` 中）：

```cmake
-D CMAKE_BUILD_TYPE=Release
-D USE_CUDA=1
-D CMAKE_CUDA_FLAGS="-arch sm_86"       # 根据 GPU 自动检测
-D USE_HDF5=1
-D HDF5_DIRECTORY=/usr/lib/x86_64-linux-gnu/hdf5/openmpi
-D USE_SILO=1
-D SILO_DIRECTORY=/opt/silo
-D CMAKE_C_COMPILER=mpicc
-D CMAKE_CXX_COMPILER=mpicxx
```

查看完整配置: `cat scripts/lbpm_dependencies_summary.txt`

---

## ⚠️ 常见问题

### 问题 1: CUDA 安装失败

**症状**: `nvcc: command not found`

**解决**:
```bash
# 重新运行安装脚本
bash scripts/install_cuda.sh

# 重新加载环境变量
source ~/.bashrc

# 验证
nvcc --version
```

---

### 问题 2: 编译内存不足

**症状**: `c++: fatal error: Killed signal terminated program cc1plus`

**解决**:
脚本会自动从 `-j4` 降低到 `-j2`，如果还失败：
```bash
# 手动降低并行度
cd ~/build/LBPM-full
make -j1  # 单线程编译（最慢但最安全）
```

---

### 问题 3: SILO 找不到

**症状**: `Could NOT find SILO`

**解决**:
```bash
# 方案 1: 安装 SILO
bash scripts/install_silo.sh

# 方案 2: 禁用 SILO（编辑 build_lbpm_full.sh）
# 将 USE_SILO=1 改为 USE_SILO=0
```

---

### 问题 4: GPU 未被使用

**症状**: 运行时 GPU 使用率为 0%

**诊断**:
```bash
# 检查 CUDA 是否正确安装
nvcc --version

# 检查编译时是否启用了 CUDA
cd ~/build/LBPM-full
grep "USE_CUDA" CMakeCache.txt  # 应该显示 USE_CUDA:BOOL=ON

# 重新编译
rm -rf ~/build/LBPM-full
bash scripts/build_lbpm_full.sh
```

---

## 📖 详细文档

- **完整安装指南**: `scripts/lbpm_install_guide.txt`
- **依赖配置摘要**: `scripts/lbpm_dependencies_summary.txt`
- **编译指南（中文）**: `docs/编译指南.md`
- **项目说明**: `CLAUDE.md`

---

## 🧪 验证安装

### 1. 基础测试

```bash
cd ~/build/LBPM-full
ctest
```

### 2. GPU 加速测试

```bash
# 终端 1: 运行模拟器
cd ~/build/LBPM-full/tests
./lbpm_color_simulator --help

# 终端 2: 监控 GPU
watch -n1 nvidia-smi
```

### 3. 查看编译结果

```bash
# 可执行文件
ls ~/build/LBPM-full/tests/lbpm_*_simulator

# 库文件
ls ~/build/LBPM-full/lib/liblbpm-wia.*

# 头文件
ls ~/build/LBPM-full/include/
```

---

## 🎯 下一步

安装完成后：

1. **设置环境变量**（可选）:
   ```bash
   source ~/build/LBPM-full/setup_env.sh
   ```

2. **运行示例**:
   ```bash
   cd example/Bubble
   mpirun -np 1 ../../build/LBPM-full/tests/lbpm_color_simulator input.db
   ```

3. **阅读文档**:
   - 项目架构: `CLAUDE.md`
   - 使用教程: `example/` 目录
   - API 文档: `make doc`（如果启用）

---

## 🤝 贡献

如果脚本有问题或需要改进，请：
1. 检查 `lbpm_install_guide.txt` 中的故障排查部分
2. 查看脚本输出的错误信息
3. 提交 Issue 或 Pull Request

---

## 📝 更新日志

- **2025-10-30**: 创建初始版本
  - 添加 CUDA 12.6 自动安装脚本
  - 添加 SILO 4.11 编译脚本
  - 添加 LBPM 完整编译脚本
  - 自动检测 GPU 架构（RTX 3060 = sm_86）
  - 内存优化（自动降级并行度）

---

**祝编译顺利！** 🎉
