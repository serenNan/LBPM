#!/usr/bin/env python3
import numpy as np

# 创建 80x80x80 的域
Nx, Ny, Nz = 80, 80, 80
geometry = np.ones((Nz, Ny, Nx), dtype='uint8')

# 球心位置
cx, cy, cz = 40, 40, 40

# 球半径
radius = 25.0

# 生成球形气泡
for i in range(Nz):
    for j in range(Ny):
        for k in range(Nx):
            dist = np.sqrt((k-cx)**2 + (j-cy)**2 + (i-cz)**2)
            if dist < radius:
                geometry[i, j, k] = 2  # 非湿相(气泡)

# 保存为二进制文件
geometry.tofile("bubble_80x80x80.raw")
print(f"生成了 {Nx}x{Ny}x{Nz} 的气泡几何文件: bubble_80x80x80.raw")
print(f"球心: ({cx}, {cy}, {cz}), 半径: {radius}")
