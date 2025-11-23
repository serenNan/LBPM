# LBPM 用户使用指南

从零开始使用 LBPM 进行多孔介质流动模拟的完整指南。

## 📚 目录

- [快速开始](#快速开始)
- [基础概念](#基础概念)
- [输入文件详解](#输入文件详解)
- [模拟器使用](#模拟器使用)
- [完整示例教程](#完整示例教程)
- [工作流程](#工作流程)
- [结果分析](#结果分析)
- [常见问题](#常见问题)
- [进阶技巧](#进阶技巧)

---

## 快速开始

### 前提条件

确保已完成构建（参考 `BUILD_GUIDE.md`）：

```bash
# 检查构建是否成功
ls ~/work/LBPM/build/bin/lbpm_*

# 设置环境变量
# Bash/Zsh 用户（添加到 ~/.bashrc 或 ~/.zshrc）
export LBPM_DIR=~/work/LBPM/build
export PATH=$LBPM_DIR/bin:$PATH

# Fish 用户
fish_add_path ~/work/LBPM/build/bin
```

### 5分钟快速体验

```bash
# 1. 进入示例目录
cd ~/work/LBPM/example/Bubble

# 2. 生成气泡几何(首次运行需要)
python3 generate_bubble.py

# 3. 运行气泡模拟(单进程)
# 方法A: 使用完整路径
~/work/LBPM/build/bin/lbpm_color_simulator bubble_final.db

# 方法B: 使用便捷脚本
bash run_bubble.sh

# 4. 查看输出文件
ls -lh *.csv vis*/*.silo

# 5. 分析结果
cat timelog.csv
```

**预期输出**:
- `timelog.csv` - 时间步数据和流动统计
- `minkowski.csv` - 几何特征(体积、面积等)
- `vis100/`, `vis200/` - 可视化数据目录(SILO格式)
- `id_t*.raw` - 各时间步的相分布文件

> **⚠️ 常见错误**: 如果提示 "unable to find the specified executable file"，说明可执行文件不在 PATH 中。
>
> **快速解决**:
> ```bash
> # Bash/Zsh 临时添加到 PATH（当前会话有效）
> export PATH=~/work/LBPM/build/bin:$PATH
>
> # Bash/Zsh 永久添加
> echo 'export PATH=~/work/LBPM/build/bin:$PATH' >> ~/.bashrc
> source ~/.bashrc
>
> # Fish 永久添加（推荐）
> fish_add_path ~/work/LBPM/build/bin
> ```

---

## 基础概念

### LBPM 是什么？

**LBPM** (Lattice Boltzmann Methods for Porous Media) 是一个基于格子玻尔兹曼方法的多孔介质模拟软件，用于：

- ✅ 两相不混溶流动（油水驱替）
- ✅ 渗透率和相对渗透率测量
- ✅ 毛细压力曲线计算
- ✅ 电化学传输（离子、电场）
- ✅ 复杂孔隙几何中的流动

### 核心模型

| 模型 | 用途 | 主要模拟器 |
|------|------|------------|
| **Color Model** | 两相不混溶流动 | `lbpm_color_simulator` |
| **Greyscale Model** | 部分饱和单相流 | `lbpm_greyscale_simulator` |
| **Free-Lee Model** | 相场模型 | `lbpm_freelee_simulator` |
| **BGK Model** | 单相流 | `lbpm_BGK_simulator` |
| **Nernst-Planck** | 电化学传输 | `lbpm_nernst_planck_simulator` |

### 标签系统

LBPM 使用整数标签标识不同相：

```
0           = 固体（不可移动相）
正值 (1, 2) = 流体相
  1         = 湿相（如水）
  2         = 非湿相（如油/气）
```

### 坐标约定

- **x, y**: 水平方向，默认周期性边界
- **z**: 垂直方向，施加压力或流量边界条件
- **外部边界**: 仅在 z 方向施加

---

## 输入文件详解

### 文件格式

LBPM 使用 `.db` 格式的配置文件（文本文件，层次化键值对）：

```c
BlockName {
    parameter1 = value1;
    parameter2 = value2;
    nested_block {
        param = value;
    }
}
```

### 必需的配置块

#### 1. Domain 块

定义计算域和并行分解：

```c
Domain {
    // --- 方法1: 生成几何 ---
    n = 80, 80, 80            // 域大小 (Nx, Ny, Nz)
    nproc = 2, 2, 2           // MPI进程分解
    L = 1, 1, 1               // 物理长度
    BC = 0                    // 边界条件 (0=周期, 3=恒压, 4=恒流)

    // --- 方法2: 读取几何 ---
    Filename = "geometry.raw" // 输入文件
    ReadType = "8bit"         // 数据类型
    N = 100, 100, 100         // 原始图像尺寸
    nproc = 2, 2, 2           // MPI分解
    n = 50, 50, 50            // 每个进程的子域
    voxel_length = 10.0       // 体素长度(微米)
    ReadValues = 0, 1, 2      // 原始标签
    WriteValues = 0, 1, 2     // LBPM使用标签
    BC = 0
}
```

**重要约定**：
- 每个方向**至少3个体素**
- 子域大小 `n` 应能被总大小整除
- `nproc` 的乘积 = MPI 总进程数

#### 2. Color 块

两相流模型参数：

```c
Color {
    // 物理参数
    tauA = 0.7                    // 湿相粘度 (0.7-1.5)
    tauB = 1.0                    // 非湿相粘度
    rhoA = 1.0                    // 湿相密度
    rhoB = 0.8                    // 非湿相密度
    alpha = 0.005                 // 界面张力参数 (0.001-0.01)
    beta = 0.95                   // 界面宽度 (接近1更尖锐)

    // 驱动力
    F = 0, 0, 1e-6               // 体积力 (Fx, Fy, Fz)

    // 润湿性
    WettingConvention = "SCAL"    // 润湿约定
    ComponentLabels = 0           // 固体标签列表
    ComponentAffinity = 0.9       // 润湿亲和力 (-1到1)
                                  // 正=亲水, 负=疏水

    // 模拟控制
    protocol = "fractional flow"  // 模拟协议
    timestepMax = 100000          // 最大时间步
    Restart = false               // 是否重启
}
```

**关键参数说明**：

| 参数 | 范围 | 物理意义 |
|------|------|----------|
| `tau` | 0.7-1.5 | 粘度: ν = (τ-0.5)/3 |
| `alpha` | 0.001-0.01 | 界面张力: σ ≈ 5.796×α |
| `beta` | 0.9-0.99 | 界面宽度 |
| `ComponentAffinity` | -1 to 1 | 接触角: θ ≈ acos(a)×180/π |

#### 3. Analysis 块

分析和输出控制：

```c
Analysis {
    analysis_interval = 100              // 日志输出间隔
    subphase_analysis_interval = 1000    // 子相分析间隔
    visualization_interval = 5000        // 可视化输出间隔
    restart_interval = 10000             // 重启文件间隔
    restart_file = "Restart"             // 重启文件前缀
    N_threads = 4                        // 分析线程数
}
```

#### 4. Visualization 块

可视化输出设置：

```c
Visualization {
    format = "hdf5"              // 输出格式 (hdf5/silo)
    write_silo = true            // 是否写SILO文件
    save_8bit_raw = true         // 保存RAW文件
    save_phase_field = true      // 保存相场
    save_pressure = true         // 保存压力场
    save_velocity = true         // 保存速度场
}
```

### 模拟协议

通过 `protocol` 参数选择模拟类型：

| 协议 | 说明 | 适用场景 |
|------|------|----------|
| `default` | 标准模拟 | 固定初始条件 |
| `fractional flow` | 分数流量 | 自动调节相对渗透率 |
| `core flooding` | 岩心驱替 | 注入流体驱替 |
| `image sequence` | 图像序列 | 时间演化几何 |

---

## 模拟器使用

### 主要模拟器

#### lbpm_color_simulator

**用途**：两相不混溶流动模拟

**基本用法**：
```bash
mpirun -np <进程数> lbpm_color_simulator <输入文件>
```

**示例**：
```bash
# 单进程
mpirun -np 1 lbpm_color_simulator input.db

# 8进程（需要 nproc = 2,2,2）
mpirun -np 8 lbpm_color_simulator input.db

# 后台运行
nohup mpirun -np 4 lbpm_color_simulator input.db > output.log 2>&1 &
```

#### lbpm_permeability_simulator

**用途**：渗透率测量

**特点**：单相流，自动计算渗透率

#### lbpm_greyscale_simulator

**用途**：部分饱和灰度模型

**适用**：快速估算相对渗透率

### 预处理工具

#### lbpm_morphdrain_pp

**用途**：形态学排水，生成初始两相配置

**用法**：
```bash
mpirun -np 4 lbpm_morphdrain_pp input.db
```

**输入要求**：Domain 块中添加 `Sw = 0.35`（目标饱和度）

**输出**：`<原文件名>.morphdrain.raw`

#### lbpm_serial_decomp

**用途**：域分解（当使用单个大图像文件时）

**用法**：
```bash
mpirun -np 1 lbpm_serial_decomp input.db
```

**输出**：为每个MPI进程生成子域文件

---

## 完整示例教程

### 示例 1: 气泡模拟（入门）

**目标**：模拟一个简单气泡在流体中的演化

#### 步骤 1: 创建几何

```python
# CreateBubble.py
import numpy as np

# 域大小
Nx, Ny, Nz = 40, 40, 40

# 初始化为流体1（湿相）
geometry = np.ones((Nz, Ny, Nx), dtype='uint8')

# 在中心创建气泡（流体2，非湿相）
center = np.array([20, 20, 20])
radius = 12.5

for i in range(Nz):
    for j in range(Ny):
        for k in range(Nx):
            pos = np.array([k, j, i])
            dist = np.linalg.norm(pos - center)
            if dist < radius:
                geometry[i, j, k] = 2

# 保存
geometry.tofile("bubble.raw")
print(f"Created bubble geometry: {Nx}x{Ny}x{Nz}")
```

运行：
```bash
python CreateBubble.py
```

#### 步骤 2: 创建输入文件

```c
// input.db
Domain {
    Filename = "bubble.raw"
    ReadType = "8bit"
    N = 40, 40, 40
    nproc = 1, 1, 1
    n = 40, 40, 40
    L = 1, 1, 1
    BC = 0
    ReadValues = 1, 2
    WriteValues = 1, 2
}

Color {
    tauA = 1.0
    tauB = 1.0
    rhoA = 1.0
    rhoB = 1.0
    alpha = 0.01
    beta = 0.95
    F = 0, 0, 0
    Restart = false
    timestepMax = 5000
}

Analysis {
    analysis_interval = 100
    visualization_interval = 1000
    restart_interval = 5000
    restart_file = "Restart"
}

Visualization {
    write_silo = true
    save_phase_field = true
}
```

#### 步骤 3: 运行模拟

```bash
mpirun -np 1 lbpm_color_simulator input.db
```

#### 步骤 4: 查看结果

```bash
# 查看日志
cat timelog.csv | column -t -s,

# 使用ParaView打开可视化文件
paraview *.silo
```

---

### 示例 2: 多孔介质驱替（进阶）

**目标**：模拟水驱油过程

#### 步骤 1: 创建多孔介质几何

```python
# create_porous_media.py
import numpy as np

Nx, Ny, Nz = 100, 100, 100
geometry = np.ones((Nz, Ny, Nx), dtype='uint8')

# 添加随机球形固体颗粒
np.random.seed(42)
n_spheres = 30
for _ in range(n_spheres):
    cx = np.random.randint(5, 95)
    cy = np.random.randint(5, 95)
    cz = np.random.randint(5, 95)
    r = np.random.randint(3, 8)

    for i in range(Nz):
        for j in range(Ny):
            for k in range(Nx):
                dist = np.sqrt((k-cx)**2 + (j-cy)**2 + (i-cz)**2)
                if dist < r:
                    geometry[i, j, k] = 0  # 固体

geometry.tofile("porous.raw")

# 计算孔隙度
porosity = np.sum(geometry > 0) / (Nx*Ny*Nz)
print(f"Porosity: {porosity:.2%}")
```

#### 步骤 2: 形态学初始化（油相）

```c
// init.db
Domain {
    Filename = "porous.raw"
    ReadType = "8bit"
    N = 100, 100, 100
    nproc = 2, 2, 2
    n = 50, 50, 50
    ReadValues = 0, 1
    WriteValues = 0, 1
    BC = 0
    Sw = 0.0                    // 初始全为油(非湿相)
}
```

运行形态学预处理：
```bash
mpirun -np 8 lbpm_morphdrain_pp init.db
# 输出: porous.raw.morphdrain.raw
```

#### 步骤 3: 驱替模拟配置

```c
// input.db
Domain {
    Filename = "porous.raw.morphdrain.raw"
    ReadType = "8bit"
    N = 100, 100, 100
    nproc = 2, 2, 2
    n = 50, 50, 50
    voxel_length = 10.0         // 10微米
    ReadValues = 0, 1, 2
    WriteValues = 0, 1, 2
    BC = 4                      // 恒流边界
}

Color {
    protocol = "core flooding"
    tauA = 0.7                  // 水粘度
    tauB = 1.0                  // 油粘度
    rhoA = 1.0
    rhoB = 0.8
    alpha = 0.005
    beta = 0.95
    F = 0, 0, 1e-6             // z方向驱动
    flux = 0.5                  // 注入流量
    WettingConvention = "SCAL"
    ComponentLabels = 0
    ComponentAffinity = 0.9     // 水湿
    timestepMax = 100000
}

Analysis {
    analysis_interval = 100
    subphase_analysis_interval = 1000
    visualization_interval = 5000
    restart_interval = 10000
}

Visualization {
    write_silo = true
    save_phase_field = true
    save_pressure = true
    save_velocity = true
}
```

#### 步骤 4: 运行驱替模拟

```bash
mpirun -np 8 lbpm_color_simulator input.db
```

#### 步骤 5: 分析结果

```python
# analyze.py
import pandas as pd
import matplotlib.pyplot as plt

# 读取时间日志
data = pd.read_csv('timelog.csv')

# 绘制饱和度曲线
plt.figure(figsize=(10, 6))
plt.plot(data['timestep'], data['saturation_wetting'])
plt.xlabel('Time Steps')
plt.ylabel('Water Saturation')
plt.title('Water Saturation Evolution')
plt.grid()
plt.savefig('saturation.png', dpi=300)

# 绘制相对渗透率
if 'kr_wetting' in data.columns:
    plt.figure(figsize=(10, 6))
    plt.plot(data['saturation_wetting'], data['kr_wetting'],
             'o-', label='Water', markersize=3)
    plt.plot(data['saturation_wetting'], data['kr_nonwetting'],
             's-', label='Oil', markersize=3)
    plt.xlabel('Water Saturation')
    plt.ylabel('Relative Permeability')
    plt.legend()
    plt.grid()
    plt.savefig('relperm.png', dpi=300)

print("Analysis complete! Check saturation.png and relperm.png")
```

---

## 工作流程

### 典型工作流程

```
1. 几何准备
   ├─ Python生成 OR
   └─ 微CT图像导入

2. 预处理
   ├─ 域分解 (lbpm_serial_decomp)
   ├─ 形态学分析 (lbpm_morph_pp)
   └─ 初始化 (lbpm_morphdrain_pp)

3. 模拟运行
   └─ lbpm_color_simulator

4. 后处理
   ├─ 日志分析 (timelog.csv)
   ├─ 可视化 (ParaView)
   └─ 几何测量 (geometry.csv)
```

### 排水-吸渗工作流程

这是研究毛细压力曲线和相对渗透率的标准流程：

#### 阶段 1: 排水 (Drainage)

```bash
# 1. 准备初始配置（全湿相）
# Domain { Sw = 1.0; ... }

# 2. 运行形态学排水到多个饱和度点
for Sw in 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9; do
    # 更新配置
    sed "s/Sw = .*/Sw = $Sw;/" template.db > drain_${Sw}.db

    # 运行
    mpirun -np 8 lbpm_morphdrain_pp drain_${Sw}.db
done

# 3. 对每个饱和度点运行模拟
for Sw in 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9; do
    mkdir -p drainage_${Sw}
    cd drainage_${Sw}

    # 复制初始配置
    cp ../porous.raw.morphdrain.raw .
    cp ../config_drain.db input.db

    # 运行
    mpirun -np 8 lbpm_color_simulator input.db

    cd ..
done
```

#### 阶段 2: 吸渗 (Imbibition)

```bash
# 从排水末态开始
for Sw in 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9; do
    mkdir -p imbibition_${Sw}
    cd imbibition_${Sw}

    # 复制排水末态作为初始条件
    cp ../drainage_0.1/Restart.final .

    # 更新配置为吸渗
    cp ../config_imb.db input.db

    # 运行
    mpirun -np 8 lbpm_color_simulator input.db

    cd ..
done
```

---

## 结果分析

### 输出文件

#### timelog.csv

实时模拟数据，每 `analysis_interval` 步输出一行：

| 列名 | 说明 |
|------|------|
| `timestep` | 时间步数 |
| `saturation_wetting` | 湿相饱和度 |
| `saturation_nonwetting` | 非湿相饱和度 |
| `pressure_wetting` | 湿相平均压力 |
| `pressure_nonwetting` | 非湿相平均压力 |
| `flow_rate_wetting` | 湿相流量 |
| `flow_rate_nonwetting` | 非湿相流量 |
| `kr_wetting` | 湿相相对渗透率 |
| `kr_nonwetting` | 非湿相相对渗透率 |

**查看方法**：
```bash
# 格式化查看
column -t -s, < timelog.csv | less

# 提取最后10行
tail -10 timelog.csv

# 绘图
python -c "
import pandas as pd
import matplotlib.pyplot as plt
df = pd.read_csv('timelog.csv')
df.plot(x='timestep', y='saturation_wetting')
plt.savefig('sat.png')
"
```

#### geometry.csv

几何和接触角测量：

| 列名 | 说明 |
|------|------|
| `timestep` | 时间步 |
| `sw` | 湿相饱和度 |
| `awn` | 湿-非湿界面面积 |
| `aws` | 湿-固界面面积 |
| `ans` | 非湿-固界面面积 |
| `lwns` | 接触线长度 |
| `cwns` | 平均接触角 (度) |
| `Jwn` | 界面积分 |
| `Kwn` | 曲率积分 |

#### 可视化文件

**.silo 文件**：
```bash
# 使用ParaView
paraview visualization.*.silo

# 或使用VisIt
visit -o visualization.*.silo
```

**ParaView 操作**：
1. File → Open → 选择 `.silo` 文件
2. Apply
3. 添加图层：
   - Pseudocolor → phase (相场)
   - Pseudocolor → pressure (压力场)
   - Vector → velocity (速度场)
4. 调整色标和范围
5. 动画：View → Animation View

**.raw 文件**：
```python
import numpy as np
import matplotlib.pyplot as plt

# 读取RAW文件
data = np.fromfile('phase_10000.raw', dtype='uint8')
Nx, Ny, Nz = 100, 100, 100
data = data.reshape((Nz, Ny, Nx))

# 绘制切片
plt.figure(figsize=(10, 10))
plt.imshow(data[50, :, :], cmap='viridis', origin='lower')
plt.colorbar(label='Phase')
plt.title('Phase Distribution (z=50)')
plt.xlabel('X')
plt.ylabel('Y')
plt.savefig('phase_slice.png', dpi=300)
```

### 典型分析任务

#### 1. 计算稳态相对渗透率

```python
import pandas as pd
import numpy as np

data = pd.read_csv('timelog.csv')

# 检查是否达到稳态（最后100步的标准差）
recent = data.tail(100)
std_sw = recent['saturation_wetting'].std()

if std_sw < 0.01:
    print("Reached steady state")
    kr_w = recent['kr_wetting'].mean()
    kr_nw = recent['kr_nonwetting'].mean()
    sw = recent['saturation_wetting'].mean()

    print(f"Sw = {sw:.3f}")
    print(f"Kr_w = {kr_w:.4f}")
    print(f"Kr_nw = {kr_nw:.4f}")
else:
    print(f"Not steady yet (std = {std_sw:.4f})")
```

#### 2. 绘制毛细压力曲线

```python
import pandas as pd
import matplotlib.pyplot as plt
import glob

# 收集所有drainage点的结果
results = []
for file in sorted(glob.glob('drainage_*/timelog.csv')):
    data = pd.read_csv(file)
    final = data.iloc[-1]
    results.append({
        'Sw': final['saturation_wetting'],
        'Pc': final['pressure_nonwetting'] - final['pressure_wetting']
    })

df = pd.DataFrame(results)
df = df.sort_values('Sw')

plt.figure(figsize=(10, 6))
plt.plot(df['Sw'], df['Pc'], 'o-', linewidth=2, markersize=8)
plt.xlabel('Water Saturation')
plt.ylabel('Capillary Pressure (Pa)')
plt.title('Drainage Capillary Pressure Curve')
plt.grid(True, alpha=0.3)
plt.savefig('capillary_pressure.png', dpi=300)
```

#### 3. 计算孔隙度和连通性

```python
import numpy as np

# 读取几何
geometry = np.fromfile('geometry.raw', dtype='uint8')
geometry = geometry.reshape((100, 100, 100))

# 孔隙度
solid = (geometry == 0).sum()
pore = (geometry > 0).sum()
total = geometry.size
porosity = pore / total

print(f"Porosity: {porosity:.2%}")
print(f"Solid fraction: {solid/total:.2%}")

# 各相体积分数
phase1 = (geometry == 1).sum()
phase2 = (geometry == 2).sum()

print(f"Phase 1 saturation: {phase1/pore:.2%}")
print(f"Phase 2 saturation: {phase2/pore:.2%}")
```

---

## 常见问题

### 问题 1: 模拟不收敛 / 出现 NaN

**症状**：timelog.csv 中出现 `nan` 值，或饱和度超出 [0,1] 范围

**可能原因**：
1. 界面张力参数 `alpha` 太大
2. 驱动力 `F` 太强
3. 时间步长不稳定

**解决方案**：
```c
Color {
    alpha = 0.001;              // 减小（原来可能是 0.01）
    F = 0, 0, 1e-7;            // 减小驱动力（原来 1e-6）
    tauA = 1.0;                // 增大粘度（原来 0.7）
    tauB = 1.0;
}
```

**验证稳定性**：
```bash
# 检查最大力
F_max = max(Fx, Fy, Fz)
tau_min = min(tauA, tauB)
stability = F_max * tau_min

# 应满足: stability < 0.01
```

---

### 问题 2: 内存不足 (Out of Memory)

**症状**：程序被系统 kill，或报内存分配错误

**解决方案**：

**方法1**: 减小子域大小
```c
Domain {
    nproc = 4, 4, 4;    // 从 2,2,2 增加到 4,4,4
    n = 25, 25, 25;     // 从 50,50,50 减小到 25,25,25
}
```

**方法2**: 禁用不必要的输出
```c
Visualization {
    save_velocity = false;     // 速度场很大
    save_pressure = false;
}
```

**方法3**: 增加输出间隔
```c
Analysis {
    visualization_interval = 50000;  // 从 5000 增大
}
```

**估算内存需求**：
```python
# 每个进程的内存需求（粗略估算）
Nx, Ny, Nz = 50, 50, 50  # 子域大小
memory_per_process_MB = (Nx * Ny * Nz) * 8 * 20 / 1024 / 1024
# 8 bytes/cell * 20 fields ≈ 20 MB per 50³ subdomain
```

---

### 问题 3: MPI 进程分解错误

**症状**：
```
Error: nproc does not match total processes
```

**原因**：`nproc` 的乘积 ≠ `mpirun -np` 的进程数

**解决**：
```bash
# nproc = 2, 2, 2  → 需要 2*2*2 = 8 个进程
mpirun -np 8 lbpm_color_simulator input.db

# nproc = 1, 2, 4  → 需要 1*2*4 = 8 个进程
mpirun -np 8 lbpm_color_simulator input.db
```

---

### 问题 4: 边界处出现伪影

**症状**：在 z=0 或 z=Nz-1 处相分布异常

**原因**：边界条件处理不当

**解决**：添加混合层
```c
Color {
    InletLayers = 5;       // inlet 混合层厚度
    OutletLayers = 5;      // outlet 混合层厚度
}
```

或增大域尺寸，远离感兴趣区域。

---

### 问题 5: 重启失败

**症状**：
```
Error: Restart file not found
```

**检查**：
```bash
# 确认重启文件存在
ls Restart.*

# 确认配置正确
grep -A3 "Restart" input.db
```

**修正**：
```c
Color {
    Restart = true;
    timestepMax = 200000;      // 从重启点继续
}

Analysis {
    restart_file = "Restart";  // 与保存时一致
    restart_interval = 10000;
}
```

---

## 进阶技巧

### 1. 参数扫描自动化

批量运行不同参数的模拟：

```bash
#!/bin/bash
# sweep_alpha.sh

for alpha in 0.001 0.002 0.005 0.01; do
    # 创建目录
    dir="alpha_${alpha}"
    mkdir -p $dir
    cd $dir

    # 生成配置
    sed "s/alpha = .*/alpha = $alpha;/" ../template.db > input.db

    # 运行
    mpirun -np 8 lbpm_color_simulator input.db > run.log 2>&1

    cd ..
done
```

### 2. 监控模拟进度

实时监控脚本：

```bash
#!/bin/bash
# monitor.sh

while true; do
    clear
    echo "=== LBPM Simulation Monitor ==="
    echo "Last 5 timesteps:"
    tail -5 timelog.csv | column -t -s,

    echo ""
    echo "Saturation plot (last 100 steps):"
    tail -100 timelog.csv | cut -d, -f1,2 | \
        gnuplot -e "set terminal dumb; plot '-' using 1:2 with lines"

    sleep 10
done
```

### 3. GPU 加速使用（如果已编译 CUDA/HIP）

```bash
# CUDA 版本
export CUDA_VISIBLE_DEVICES=0,1,2,3
mpirun -np 4 lbpm_color_simulator input.db

# HIP 版本 (Crusher 超算)
srun -n8 --gpus-per-task=1 --gpu-bind=closest \
    lbpm_color_simulator input.db
```

### 4. 高级可视化

**生成动画**：
```python
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
import glob

# 读取所有时间步的相场
files = sorted(glob.glob('phase_*.raw'))

fig, ax = plt.subplots(figsize=(10, 10))

def update(frame):
    data = np.fromfile(files[frame], dtype='uint8')
    data = data.reshape((100, 100, 100))

    ax.clear()
    ax.imshow(data[50, :, :], cmap='viridis', origin='lower')
    ax.set_title(f'Time step: {frame*5000}')

anim = FuncAnimation(fig, update, frames=len(files), interval=200)
anim.save('evolution.gif', writer='pillow', fps=5)
```

**3D 可视化**：
```python
import numpy as np
from mayavi import mlab

# 读取数据
data = np.fromfile('phase_final.raw', dtype='uint8')
data = data.reshape((100, 100, 100))

# 3D 可视化
mlab.figure(size=(800, 800))
mlab.contour3d(data, contours=[0.5, 1.5], opacity=0.5)
mlab.outline()
mlab.show()
```

### 5. 并行效率分析

测试不同进程数的性能：

```bash
#!/bin/bash
# scaling_test.sh

for np in 1 2 4 8 16 32; do
    echo "Testing with $np processes..."

    # 更新 nproc
    nproc_config=$(python3 -c "
import math
n = $np
# 尝试均匀分解
for nz in range(1, n+1):
    for ny in range(1, n+1):
        nx = n // (ny * nz)
        if nx * ny * nz == n:
            print(f'{nx}, {ny}, {nz}')
            exit()
    ")

    sed "s/nproc = .*/nproc = $nproc_config;/" template.db > input_${np}.db

    # 计时运行
    start_time=$(date +%s)
    mpirun -np $np lbpm_color_simulator input_${np}.db
    end_time=$(date +%s)

    runtime=$((end_time - start_time))
    echo "$np $runtime" >> scaling_results.txt
done

# 绘制扩展性曲线
python3 -c "
import matplotlib.pyplot as plt
import numpy as np

data = np.loadtxt('scaling_results.txt')
procs = data[:, 0]
times = data[:, 1]

plt.figure(figsize=(10, 6))
plt.plot(procs, times, 'o-', linewidth=2, markersize=8)
plt.xlabel('Number of Processes')
plt.ylabel('Runtime (seconds)')
plt.title('Parallel Scaling')
plt.grid(True, alpha=0.3)
plt.savefig('scaling.png', dpi=300)
"
```

---

## 学习路径建议

### 初学者路径

1. **第1周**:
   - 阅读本指南
   - 运行 `Bubble` 示例
   - 理解输入文件结构

2. **第2周**:
   - 修改 `Bubble` 参数（alpha, tau等）
   - 观察参数对结果的影响
   - 学习可视化（ParaView）

3. **第3周**:
   - 尝试 `Piston` 示例
   - 理解两相流动
   - 学习分析脚本

4. **第4周**:
   - 创建自己的简单几何
   - 运行完整模拟
   - 分析相对渗透率

### 进阶路径

1. 运行 `drainage/imbibition` 工作流
2. 处理实际微CT图像
3. 开发自定义分析脚本
4. 探索电化学模型
5. 优化大规模并行性能

---

## 参考资源

### 项目文档
- **BUILD_GUIDE.md** - 详细构建指南
- **BUILD_SUMMARY.md** - 构建过程总结
- **CLAUDE.md** - 项目架构说明

### 在线资源
- **示例数据**: Digital Rocks Portal
- **文献**: `docs/source/` 目录
- **GitHub**: 项目仓库

### 常用命令速查

```bash
# 编译
cd ~/work/LBPM/build && make -j4

# 运行测试
ctest -R Bubble

# 单进程模拟
mpirun -np 1 lbpm_color_simulator input.db

# 8进程模拟
mpirun -np 8 lbpm_color_simulator input.db

# 后台运行
nohup mpirun -np 8 lbpm_color_simulator input.db > output.log 2>&1 &

# 监控进度
tail -f timelog.csv

# 查看结果
paraview *.silo
```

---

## 下一步

现在您已经掌握了 LBPM 的基本使用，可以：

✅ 运行示例模拟
✅ 创建自己的几何
✅ 配置输入参数
✅ 分析模拟结果
✅ 可视化输出

**建议下一步**：

1. 选择一个与您研究相关的示例
2. 修改参数进行测试
3. 逐步增加复杂度
4. 开发自己的工作流程

**需要帮助？**
- 查看 `BUILD_GUIDE.md` 的故障排除章节
- 参考项目 `example/` 目录
- 阅读 `docs/` 中的技术文档

---

**文档版本**: 1.0
**最后更新**: 2025-11-23
**适用于**: LBPM master 分支
