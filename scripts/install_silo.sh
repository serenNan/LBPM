#!/bin/bash
set -e

echo "=== SILO 库安装脚本 ==="
echo "开始时间: $(date)"
echo ""

# 检查依赖
if ! command -v h5dump &> /dev/null; then
    echo "错误: HDF5 未安装"
    exit 1
fi

# 等待下载完成
while [ ! -f /tmp/silo-4.11.tar.gz ] || [ $(stat -c%s /tmp/silo-4.11.tar.gz 2>/dev/null || echo 0) -lt 100000 ]; do
    echo "等待 SILO 源码下载完成..."
    sleep 2
done

echo "[1/5] 解压源码..."
cd /tmp
tar xzf silo-4.11.tar.gz
cd silo-4.11

echo ""
echo "[2/5] 配置编译选项..."
./configure --prefix=/opt/silo \
    --with-hdf5=/usr/include/hdf5/openmpi,/usr/lib/x86_64-linux-gnu/hdf5/openmpi \
    --enable-optimization \
    --disable-fortran

echo ""
echo "[3/5] 编译 SILO（使用 4 线程，约 5-10 分钟）..."
make -j4

echo ""
echo "[4/5] 安装到 /opt/silo（需要 sudo 密码）..."
sudo make install

echo ""
echo "[5/5] 验证安装..."
ls -lh /opt/silo/lib/libsilo*

echo ""
echo "=== 安装完成 ==="
echo "SILO 库位置: /opt/silo"
echo "头文件: /opt/silo/include"
echo "库文件: /opt/silo/lib"
echo "结束时间: $(date)"
