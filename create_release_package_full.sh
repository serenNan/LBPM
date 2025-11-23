#!/bin/bash
# 完整打包版本 - 包含所有依赖库
# 适用于客户系统与编译环境相同或相近的情况

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 导入原始脚本的配置
source "$SCRIPT_DIR/create_release_package.sh"
