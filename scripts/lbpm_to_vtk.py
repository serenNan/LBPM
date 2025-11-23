#!/usr/bin/env python3
"""
LBPM 可视化数据转换工具 v2 - 使用 ASCII 格式确保兼容性
"""
import numpy as np
import os
import glob
import sys

def detect_dimensions(raw_file):
    """自动检测数据尺寸"""
    file_size = os.path.getsize(raw_file)

    # 常见的尺寸组合
    common_sizes = [
        (24, 24, 24), (32, 32, 32), (48, 48, 48),
        (64, 64, 64), (80, 80, 80), (96, 96, 96),
        (24, 24, 96), (32, 32, 64),
    ]

    for dims in common_sizes:
        if dims[0] * dims[1] * dims[2] == file_size:
            return dims

    # 尝试立方体
    cube_size = round(file_size ** (1/3))
    if cube_size ** 3 == file_size:
        return (cube_size, cube_size, cube_size)

    raise ValueError(f"无法检测尺寸 (文件大小={file_size})")

def write_vtk_structured_points(data_3d, output_file):
    """写入 VTK Legacy 格式（ASCII，兼容性最好）"""
    nz, ny, nx = data_3d.shape

    with open(output_file, 'w') as f:
        # VTK 文件头
        f.write("# vtk DataFile Version 3.0\n")
        f.write("LBPM Phase Field Data\n")
        f.write("ASCII\n")
        f.write("DATASET STRUCTURED_POINTS\n")
        f.write(f"DIMENSIONS {nx} {ny} {nz}\n")
        f.write(f"ORIGIN 0 0 0\n")
        f.write(f"SPACING 1 1 1\n")
        f.write(f"POINT_DATA {nx*ny*nz}\n")
        f.write(f"SCALARS Phase unsigned_char 1\n")
        f.write(f"LOOKUP_TABLE default\n")

        # 写入数据（按 VTK 顺序：x 变化最快）
        for k in range(nz):
            for j in range(ny):
                for i in range(nx):
                    f.write(f"{int(data_3d[k, j, i])}\n")

def create_vtk_from_raw(raw_file, dims, output_file):
    """转换 RAW 到 VTK"""
    data = np.fromfile(raw_file, dtype=np.uint8)
    nx, ny, nz = dims

    try:
        data_3d = data.reshape((nz, ny, nx), order='C')
    except ValueError:
        # 如果失败，尝试转置
        actual_size = len(data)
        raise ValueError(f"尺寸不匹配: 文件有 {actual_size} 字节，期望 {nx*ny*nz}")

    write_vtk_structured_points(data_3d, output_file)
    return True

def main():
    output_dir = sys.argv[1] if len(sys.argv) > 1 else "vtk_output"
    os.makedirs(output_dir, exist_ok=True)

    # 查找文件
    id_files = sorted(glob.glob("id_t*.raw"))

    if not id_files:
        print("❌ 未找到 id_t*.raw 文件")
        return 1

    print(f"找到 {len(id_files)} 个时间步文件")

    # 自动检测尺寸
    try:
        dims = detect_dimensions(id_files[0])
        print(f"✓ 检测尺寸: {dims[0]} × {dims[1]} × {dims[2]}")
    except ValueError as e:
        print(f"❌ {e}")
        return 1

    # 转换
    success = 0
    for raw_file in id_files:
        base_name = os.path.splitext(raw_file)[0]
        output_file = os.path.join(output_dir, f"{base_name}.vtk")

        try:
            create_vtk_from_raw(raw_file, dims, output_file)
            file_size = os.path.getsize(output_file)
            print(f"✓ {raw_file} → {output_file} ({file_size//1024}KB)")
            success += 1
        except Exception as e:
            print(f"✗ {raw_file}: {e}")

    print(f"\n✅ 转换完成: {success}/{len(id_files)}")
    print(f"📁 输出目录: {os.path.abspath(output_dir)}")

if __name__ == "__main__":
    sys.exit(main())
