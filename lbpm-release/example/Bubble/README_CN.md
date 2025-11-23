# LBPM 气泡模拟示例

这是一个简单的两相流气泡模拟示例,用于快速测试 LBPM 安装和基本功能。

## 快速开始

### 1. 生成几何文件

```bash
python3 generate_bubble.py
```

这会生成一个 80×80×80 的计算域,中心包含一个半径为 25 的球形气泡。

### 2. 运行模拟

**方法 A: 直接运行**
```bash
~/work/LBPM/build/bin/lbpm_color_simulator bubble_final.db
```

**方法 B: 使用脚本**
```bash
bash run_bubble.sh
```

### 3. 查看结果

模拟完成后会生成以下文件:

- `timelog.csv` - 时间步统计数据
- `minkowski.csv` - Minkowski 几何测量
- `solid.csv` - 固相信息
- `vis*/` - 可视化数据目录(SILO格式)
- `id_t*.raw` - 各时间步的相分布

## 配置说明

### bubble_final.db

这是可工作的配置文件,主要参数:

```
Color {
    timestepMax = 200        # 总时间步数
    alpha = 1e-2            # 表面张力参数
    beta  = 0.95            # 流体-流体相互作用
}

Domain {
    N = 80, 80, 80          # 全局域大小
    BC = 0                  # 周期性边界条件
}

Analysis {
    analysis_interval = 100         # 分析间隔
    visualization_interval = 100    # 可视化输出间隔
}
```

## 性能基准

在标准桌面系统上的典型性能:
- **域大小**: 80³ = 512,000 格点
- **时间步**: 200 步
- **运行时间**: ~0.06 秒
- **更新速率**: ~8.5 MLUPS (Million Lattice Updates Per Second)

## 修改参数

### 调整模拟时长
编辑 `bubble_final.db` 中的 `timestepMax`:
```
timestepMax = 1000  # 更长的模拟
```

### 改变域大小
1. 修改 `generate_bubble.py` 中的 `Nx, Ny, Nz`
2. 重新生成几何: `python3 generate_bubble.py`
3. 更新 `bubble_final.db` 中的 `N` 参数

### 调整气泡大小
修改 `generate_bubble.py` 中的 `radius` 参数

## 文件说明

| 文件 | 用途 |
|------|------|
| `generate_bubble.py` | 生成球形气泡几何 |
| `bubble_final.db` | LBPM 配置文件 |
| `bubble_80x80x80.raw` | 生成的几何文件 |
| `run_bubble.sh` | 快速运行脚本 |

## 故障排除

### 找不到可执行文件
确保 LBPM 二进制文件在 PATH 中:
```bash
# Fish shell
fish_add_path ~/work/LBPM/build/bin

# Bash/Zsh
export PATH=~/work/LBPM/build/bin:$PATH
```

### 缺少几何文件
运行 `python3 generate_bubble.py` 生成 `bubble_80x80x80.raw`

### 查看详细输出
模拟会在终端打印详细的初始化和运行信息,包括:
- 几何读取统计
- 相体积分数
- 时间步性能

## 下一步

成功运行这个示例后,你可以:
1. 尝试其他示例(如多孔介质模拟)
2. 修改参数探索不同的物理场景
3. 学习使用 VisIt 或 ParaView 可视化 SILO 输出
4. 运行多进程并行模拟

更多信息请参考主目录下的 `USER_GUIDE.md`。
