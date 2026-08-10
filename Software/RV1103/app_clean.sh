#!/bin/bash

echo "Start to clean app build cache..."
set -eu

BUILD_DIR=$(pwd)
TOOLCHAIN_PARENT_DIR="${BUILD_DIR}/luckfox_toolchain"
TOOLCHAIN_DIR="${TOOLCHAIN_PARENT_DIR}/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"
TOOLCHAIN_BIN_PATH="${TOOLCHAIN_DIR}/bin"

cd ${BUILD_DIR}
rm -rf "${BUILD_DIR}/dist/sysdump"

cd "${BUILD_DIR}/hid"
make clean

cd "${BUILD_DIR}/hwclock_ds1302"
make clean

cd "${BUILD_DIR}/music"
make clean

cd "${BUILD_DIR}/meow_rpg"
make clean

cd "${BUILD_DIR}/virtual_keypad"
make clean

cd "${BUILD_DIR}/lvgl"
make clean

cd "${BUILD_DIR}/nesemu/build"
make clean

cd "${BUILD_DIR}/expat-2.7.1"
make clean

cd "${BUILD_DIR}/fontconfig-2.16.0"
make clean

cd "${BUILD_DIR}/zlib-1.3.1"
make clean

cd "${BUILD_DIR}/libiconv-1.7"
make clean

cd "${BUILD_DIR}/freetype-2.14.1"
make clean

cd "${BUILD_DIR}/fbterm-truecolor"
make clean

rm -rf "${BUILD_DIR}/staging/"*
rm -rf "${BUILD_DIR}/dist/"*

echo ">>> APP 目录与构建产物已清理"