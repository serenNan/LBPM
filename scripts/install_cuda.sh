#!/bin/bash
set -e

echo "=== CUDA Toolkit 安装脚本 ==="
echo "开始时间: $(date)"
echo ""

# 检查是否已下载 keyring
if [ ! -f /tmp/cuda-keyring_1.1-1_all.deb ]; then
    echo "[1/5] 下载 CUDA keyring..."
    cd /tmp
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
else
    echo "[1/5] CUDA keyring 已下载，跳过"
fi

echo ""
echo "[2/5] 安装 CUDA keyring（需要 sudo 密码）..."
sudo dpkg -i /tmp/cuda-keyring_1.1-1_all.deb

echo ""
echo "[3/5] 更新软件源..."
sudo apt update

echo ""
echo "[4/5] 安装 CUDA Toolkit 12.6（约 3 GB，可能需要 10-20 分钟）..."
echo "提示: 这个步骤会下载大量文件，请耐心等待"
sudo apt install -y cuda-toolkit-12-6

echo ""
echo "[5/5] 设置环境变量..."
if ! grep -q "CUDA" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# CUDA Toolkit" >> ~/.bashrc
    echo "export PATH=/usr/local/cuda-12.6/bin:\$PATH" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:\$LD_LIBRARY_PATH" >> ~/.bashrc
    echo "已添加到 ~/.bashrc"
else
    echo "环境变量已存在于 ~/.bashrc"
fi

# 对当前会话立即生效
export PATH=/usr/local/cuda-12.6/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH

echo ""
echo "=== 安装完成 ==="
echo "验证安装:"
nvcc --version
echo ""
echo "结束时间: $(date)"
echo ""
echo "请运行以下命令使环境变量生效:"
echo "  source ~/.bashrc"
echo "或者重新打开终端"
