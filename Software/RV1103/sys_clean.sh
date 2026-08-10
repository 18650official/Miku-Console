#!/bin/bash

echo "Start to clean build cache..."
set -eu

BUILD_DIR=$(pwd)
TOOLCHAIN_PARENT_DIR="${BUILD_DIR}/luckfox_toolchain"
TOOLCHAIN_DIR="${TOOLCHAIN_PARENT_DIR}/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"
TOOLCHAIN_BIN_PATH="${TOOLCHAIN_DIR}/bin"

# 清理SDK构建缓存
echo ">>> 清理SDK构建缓存..."
cd "${TOOLCHAIN_PARENT_DIR}"

./build.sh clean
cd ${BUILD_DIR}
rm -rf "${BUILD_DIR}/dist/image"
echo ">>> SDK 目录与构建产物已清理"