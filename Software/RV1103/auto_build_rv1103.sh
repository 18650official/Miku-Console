#!/bin/bash

echo "Start to compile Miku-Console..."
set -eu

# =================================================================
# Part 1: Install all required dependencies on the host machine
# =================================================================
echo "====== 1.1 Installing all host dependencies (sudo password may be required) ======"
sudo apt-get update
sudo apt-get install -y \
    git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ \
    gawk texinfo libssl-dev bison flex fakeroot cmake unzip gperf autoconf \
    device-tree-compiler libncurses5-dev pkg-config bc python-is-python3 \
    openssl openssh-server openssh-client vim file cpio rsync \
    build-essential automake libtool uuid-dev wget xz-utils tree
echo "====== Host base dependencies installed. ======"
echo ""

# --- Final fix: Create symlinks for aclocal and automake to be compatible with fontconfig ---
echo "====== 1.2 Creating aclocal/automake compatibility symlinks... ======"
# Check if aclocal exists
if command -v aclocal &> /dev/null
then
    ACLOCAL_PATH=$(which aclocal)
    # Create aclocal-1.17 symlink
    sudo ln -sf "$ACLOCAL_PATH" /usr/bin/aclocal-1.17
    echo "Symbolic link 'aclocal-1.17' -> '${ACLOCAL_PATH}' created."
else
    echo "Warning: 'aclocal' command not found, skipping symlink creation."
fi
# Check if automake exists
if command -v automake &> /dev/null
then
    AUTOMAKE_PATH=$(which automake)
    # Create automake-1.17 symlink
    sudo ln -sf "$AUTOMAKE_PATH" /usr/bin/automake-1.17
    echo "Symbolic link 'automake-1.17' -> '${AUTOMAKE_PATH}' created."
else
    echo "Warning: 'automake' command not found, skipping symlink creation."
fi
echo ""

# =================================================================
# Part 2: Automatically download and set up the cross-compile toolchain
# =================================================================
BUILD_DIR=$(pwd)
TOOLCHAIN_PARENT_DIR="${BUILD_DIR}/luckfox_toolchain"
TOOLCHAIN_DIR="${TOOLCHAIN_PARENT_DIR}/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf"
TOOLCHAIN_BIN_PATH="${TOOLCHAIN_DIR}/bin"
WRAPPED_TOOLCHAIN_BIN_PATH="${TOOLCHAIN_PARENT_DIR}/sysdrv/source/buildroot/buildroot-2023.02.6/output/host/bin"

echo "====== 2.1 Checking cross-compile toolchain... ======"
if [ ! -d "${TOOLCHAIN_BIN_PATH}" ]; then
    echo "Toolchain not found or incomplete. Cleaning and re-cloning..."
    rm -rf "${TOOLCHAIN_PARENT_DIR}"
    git clone --depth 1 https://gitee.com/LuckfoxTECH/luckfox-pico.git "${TOOLCHAIN_PARENT_DIR}"
    echo "Toolchain cloned."
else
    echo "Toolchain verified and exists at: ${TOOLCHAIN_PARENT_DIR}"
fi
echo ""

# =================================================================
# Part 3: Automatically check and upgrade Autoconf
# =================================================================
echo "====== 3.1 Checking Autoconf version... ======"
AUTOCONF_REQUIRED_VERSION="2.71"
INSTALLED_AUTOCONF_VERSION=$(autoconf --version | head -n 1 | awk '{print $NF}' || echo "0")
LOWEST_VERSION=$(printf '%s\n' "$AUTOCONF_REQUIRED_VERSION" "$INSTALLED_AUTOCONF_VERSION" | sort -V | head -n1)

if [ "$LOWEST_VERSION" != "$AUTOCONF_REQUIRED_VERSION" ]; then
    echo "Warning: Current Autoconf version ($INSTALLED_AUTOCONF_VERSION) is too old, requires >= $AUTOCONF_REQUIRED_VERSION."
    echo "====== Automatically downloading and compiling new Autoconf 2.72 ======"
    
    TEMP_BUILD_DIR=${BUILD_DIR}/build_temp
    mkdir -p "$TEMP_BUILD_DIR"
    cd "$TEMP_BUILD_DIR"
    wget -q --show-progress https://ftp.wayne.edu/gnu/autoconf/autoconf-2.72.tar.gz
    tar -xzf autoconf-2.72.tar.gz
    cd autoconf-2.72
    echo "Configuring Autoconf..."
    ./configure --prefix=/usr/local
    echo "Compiling Autoconf..."
    make -j$(nproc)
    echo "Installing Autoconf to /usr/local/bin with sudo (password required)..."
    sudo make install
    cd ../..
    rm -rf "$TEMP_BUILD_DIR"
    hash -r
    echo "====== Autoconf upgrade complete. ======"
else
    echo "Current Autoconf version ($INSTALLED_AUTOCONF_VERSION) meets requirements, no upgrade needed."
fi
echo "Confirming final Autoconf version:"
which autoconf
autoconf --version
echo ""

# Build system firmware
# =========================================================
# 阶段一：构建 Luckfox 底层系统与镜像 (Buildroot & Kernel)
# =========================================================
echo ">>> 开始准备 SDK 环境..."

# 获取当前工作目录（完美适配 CI/CD，无硬编码绝对路径）
WORKSPACE_DIR="$PWD"
SDK_DIR="${WORKSPACE_DIR}/luckfox_toolchain"

# 确保 SDK 目录存在
if [ ! -d "$SDK_DIR" ]; then
    echo ">>> [错误] 找不到 luckfox_toolchain 目录，请先拉取 SDK！"
    exit 1
fi

# 1. 复制 config 文件夹下的内容到 SDK 目录
# 使用 -a 参数确保原有的文件权限和属性不变
echo ">>> 同步自定义内核源码..."
rsync -av --delete --exclude='.git/' \
    "${WORKSPACE_DIR}/kernel/" \
    "${SDK_DIR}/sysdrv/source/kernel/"

echo ">>> 替换分区表文件 (BoardConfig)..."
cp "${WORKSPACE_DIR}/fstab/BoardConfig-SPI_NAND-Buildroot-RV1103_Luckfox_Pico_Mini-IPC.mk" \
   "${SDK_DIR}/project/cfg/BoardConfig_IPC/"
ln -sf "${SDK_DIR}/project/cfg/BoardConfig_IPC/BoardConfig-SPI_NAND-Buildroot-RV1103_Luckfox_Pico_Mini-IPC.mk" "${SDK_DIR}/.BoardConfig.mk"

echo ">>> 替换BSP配置文件..."
# 1. 替换 Buildroot 配置模板（SDK 会在解压后自动将其拷贝到 source 里）
cp "${WORKSPACE_DIR}/config/luckfox_pico_defconfig" "${SDK_DIR}/sysdrv/tools/board/buildroot/"
# 2. 追加 overlay 文件
cp -r "${WORKSPACE_DIR}/fstab/overlay-luckfox-mikuconsole" "${SDK_DIR}/project/cfg/BoardConfig_IPC/overlay/"

# 2. 替换 Kernel 配置文件和设备树（由于 kernel 是由 rsync 整个同步过来的，这里可以直接放进去）
cp "${WORKSPACE_DIR}/config/luckfox_rv1106_linux_defconfig" "${SDK_DIR}/sysdrv/source/kernel/arch/arm/configs/"
cp "${WORKSPACE_DIR}/config/rv1103g-luckfox-pico-mini.dts" "${SDK_DIR}/sysdrv/source/kernel/arch/arm/boot/dts/"

# 4. 进入 SDK 目录并执行完整系统编译
echo ">>> 开始编译 Luckfox 系统镜像 (这可能需要较长时间)..."
cd "${SDK_DIR}"

# 捕获 build.sh 的执行状态，如果编译炸了直接熔断退出，保护 CI/CD 流水线
if ./build.sh; then
    echo ">>> [成功] 底层系统编译完成！"
else
    echo ">>> [致命错误] SDK build.sh 编译失败，终止自动构建！"
    exit 1
fi

# 5. 回到工作目录，拷贝最终镜像产物
cd "${WORKSPACE_DIR}"
mkdir -p "${WORKSPACE_DIR}/dist"

# 将生成的镜像文件夹复制到 dist 下
echo ">>> 正在将生成的系统镜像收集到 dist/image 目录..."
cp -r "${SDK_DIR}/output/image" "${WORKSPACE_DIR}/dist/"
echo ">>> 系统级构建阶段全部完成！"
echo "================================================="
tree "${WORKSPACE_DIR}/dist/image"
echo "================================================="
sleep 1

# =====================================================
# 构建用户程序
# =====================================================

# --- Core compilation environment variables ---
TOOLCHAIN_PREFIX="arm-rockchip830-linux-uclibcgnueabihf-"
TARGET_HOST="arm-linux"
INSTALL_DIR="${BUILD_DIR}/staging"

export PATH="${WRAPPED_TOOLCHAIN_BIN_PATH}:${PATH}"
export CC="${TOOLCHAIN_PREFIX}gcc"
export CXX="${TOOLCHAIN_PREFIX}g++"
export LD="${TOOLCHAIN_PREFIX}ld"
export AR="${TOOLCHAIN_PREFIX}ar"
export AS="${TOOLCHAIN_PREFIX}as"
export NM="${TOOLCHAIN_PREFIX}nm"
export RANLIB="${TOOLCHAIN_PREFIX}ranlib"
export STRIP="${TOOLCHAIN_PREFIX}strip"
export PKG_CONFIG_PATH="${INSTALL_DIR}/usr/lib/pkgconfig"
export CPPFLAGS="-I${INSTALL_DIR}/usr/include"
export CXXFLAGS="-g -O2"
export LDFLAGS="-L${INSTALL_DIR}/usr/lib"


# =================================================================
# Part 4: Automatically generate CMake toolchain file
# =================================================================
echo "====== 4.1 Generating CMake toolchain file (toolchain.cmake)... ======"
TOOLCHAIN_CMAKE_FILE="${BUILD_DIR}/toolchain.cmake"
TOOLCHAIN_SYSROOT="${TOOLCHAIN_DIR}/arm-rockchip830-linux-uclibcgnueabihf/sysroot"

cat > "${TOOLCHAIN_CMAKE_FILE}" << EOF
# CMake arm-linux Cross-Compile Toolchain File
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER   "${CC}")
set(CMAKE_CXX_COMPILER "${CXX}")
set(CMAKE_SYSROOT "${TOOLCHAIN_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "${INSTALL_DIR}" "\${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF
echo "====== CMake toolchain file generated. ======"
echo ""

# 编译系统附件
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

echo "================================================================="
echo "Cross-compile environment is set:"
echo "  - Install directory: ${INSTALL_DIR}"
echo "  - C Compiler: $(which ${CC})"
echo "================================================================="

echo "生成系统刷机包目录..."
DIST_DIR="${WORKSPACE_DIR}/dist"
rm -rf "${DIST_DIR}/sysdump"
mkdir -p "${DIST_DIR}/sysdump"
SYSDUMP_DIR="${DIST_DIR}/sysdump"

# 进一步构建文件夹
mkdir -p "${SYSDUMP_DIR}/usr/bin"
mkdir -p "${SYSDUMP_DIR}/usr/lib"
mkdir -p "${SYSDUMP_DIR}/meow_rpg"

# 1. 编译简单系统应用与插件
echo ">>> Start to compile HID controller..."
cd "${WORKSPACE_DIR}/hid"
make clean
make -j$(nproc)
cp "${WORKSPACE_DIR}/hid/build/joystick_app" "${SYSDUMP_DIR}/usr/bin"
cd "${WORKSPACE_DIR}"
echo ">>> HID controller          [OK]"

echo ">>> Start to compile hwclock_ds1302 part..."
cd "${WORKSPACE_DIR}/hwclock_ds1302"
make clean
make -j$(nproc)
cp "${WORKSPACE_DIR}/hwclock_ds1302/build/hwclock_ds1302" "${SYSDUMP_DIR}/usr/bin"
cd "${WORKSPACE_DIR}"
echo ">>> hwclock_ds1302          [OK]"

echo ">>> Start to compile Music CLI Player..."
cd "${WORKSPACE_DIR}/music"
make clean
make -j$(nproc)
cp "${WORKSPACE_DIR}/music/build/music_player" "${SYSDUMP_DIR}/usr/bin"
cd "${WORKSPACE_DIR}"
echo ">>> Music CLI Player          [OK]"

echo ">>> Start to compile I2C I/O Controller..."
cd "${WORKSPACE_DIR}/virtual_keypad"
make clean
make -j$(nproc)
cp "${WORKSPACE_DIR}/virtual_keypad/build/virtual_keypad" "${SYSDUMP_DIR}/usr/bin"
cd "${WORKSPACE_DIR}"
echo ">>> I2C I/O Controller          [OK]"

# 2. 编译GUI程序
echo ">>> Start to compile LVGL..."
cd "${WORKSPACE_DIR}/lvgl"
make clean

echo "--> Initializing nested submodules for lvgl_menu (e.g., lvgl)..."
git submodule update --init --recursive
echo "--> Submodules initialized."

./configure-rv1103
make -j$(nproc)
cp "${WORKSPACE_DIR}/lvgl/build/bin/pico-menu" "${SYSDUMP_DIR}/usr/bin"
cd "${WORKSPACE_DIR}"
echo ">>> LVGL          [OK]"

echo ">>> Start to compile nesemu..."
cd "${WORKSPACE_DIR}/nesemu/build"
make clean
cd "${WORKSPACE_DIR}/nesemu"
./configure-rv1103
cd "${WORKSPACE_DIR}/nesemu/build"
make -j$(nproc)
cp "${WORKSPACE_DIR}/nesemu/build/bin/nesemu" "${SYSDUMP_DIR}/usr/bin/.nesemu"
cd "${WORKSPACE_DIR}"
echo ">>> nesemu          [OK]"

echo ">>> Start to compile meow_rpg..."
cd "${WORKSPACE_DIR}/meow_rpg"
make clean
make -j$(nproc)
cp -r "${WORKSPACE_DIR}/meow_rpg/dist/"* "${SYSDUMP_DIR}/meow_rpg/"
cd "${WORKSPACE_DIR}"
echo ">>> meow_rpg          [OK]"

echo "用户组件构建完成"
echo "====================================================="
tree "${SYSDUMP_DIR}"
sleep 1
echo "====================================================="

# 3. 构建fbterm
# --- Compile zlib ---
echo ""
echo "======== 5.1 Compiling zlib-1.3.1 ========"
cd "${BUILD_DIR}/zlib-1.3.1"
make clean &> /dev/null || true
# --- UPDATED: Use standard prefix and DESTDIR ---
./configure --prefix=/usr --static
make -j$(nproc)
make install DESTDIR="${INSTALL_DIR}"
cd "${BUILD_DIR}"
echo "======== zlib compilation finished. ========"

# --- Compile expat ---
echo ""
echo "======== 5.2 Compiling expat-2.7.1 ========"
cd "${BUILD_DIR}/expat-2.7.1"
make clean &> /dev/null || true
# --- UPDATED: Add --disable-docs to skip building documentation ---
./configure --prefix=/usr \
            --host="${TARGET_HOST}" \
            --enable-static \
            --disable-shared \
            --without-docbook \
            --disable-docs
make -j$(nproc) SUBDIRS="lib xmlwf"
make install DESTDIR="${INSTALL_DIR}" SUBDIRS="lib xmlwf"
cd "${BUILD_DIR}"
echo "======== expat compilation finished. ========"

# --- Compile libiconv ---
echo ""
echo "======== 5.3 Compiling libiconv-1.7 ========"
cd "${BUILD_DIR}/libiconv-1.7"
make clean &> /dev/null || true
# --- UPDATED: Use standard prefix and DESTDIR ---
./configure --prefix=/usr --host="${TARGET_HOST}" --enable-static --disable-shared
make -j$(nproc)
make install DESTDIR="${INSTALL_DIR}"
cd "${BUILD_DIR}"
echo "======== libiconv compilation finished. ========"

# --- Compile freetype ---
echo ""
echo "======== 5.4 Compiling freetype-2.14.1 ========"
cd "${BUILD_DIR}/freetype-2.14.1"
make clean &> /dev/null || true
# --- UPDATED: Use standard prefix and DESTDIR ---
./configure --prefix=/usr --host="${TARGET_HOST}" --with-zlib=yes --enable-static --disable-shared
make -j$(nproc)
make install DESTDIR="${INSTALL_DIR}"
cd "${BUILD_DIR}"
echo "======== freetype compilation finished. ========"

# --- Compile fontconfig ---
( # Use a subshell to isolate the CPPFLAGS change for fontconfig
    echo ""
    echo "======== 5.5 Compiling fontconfig-2.16.0 ========"
    cd "${BUILD_DIR}/fontconfig-2.16.0"
    make clean &> /dev/null || true

    # --- CRITICAL FIX for freetype headers ---
    export CPPFLAGS="${CPPFLAGS} -I${INSTALL_DIR}/usr/include/freetype2"
    echo "Temporarily adding FreeType include path for fontconfig: ${CPPFLAGS}"
    # --- END FIX ---

    # 重点在这里：添加 --disable-nls 关闭多语言本地化支持，避免依赖 libintl
    ./configure --prefix=/usr \
                --host="${TARGET_HOST}" \
                --enable-static \
                --disable-shared \
                --disable-docs \
                --disable-nls \
                --sysconfdir=/etc \
                --localstatedir=/var
    make -j$(nproc)
    make install DESTDIR="${INSTALL_DIR}"
    cd "${BUILD_DIR}"
    echo "======== fontconfig compilation finished. ========"
)

# --- Compile fbterm ---
( # Use a subshell to isolate fbterm's special environment variables
    echo ""
    echo "======== 5.7 Compiling fbterm-truecolor ========"
    cd "${BUILD_DIR}/fbterm-truecolor"
    make clean &> /dev/null || true

    # --- Final fix: Run autoreconf for fbterm ---
    echo "--> Regenerating build system for fbterm..."
    autoreconf -fiv
    echo "--> Build system generated."
    
    # --- CRITICAL FIX for freetype headers ---
    export CPPFLAGS="${CPPFLAGS} -I${INSTALL_DIR}/usr/include/freetype2"
    echo "Temporarily adding FreeType include path for fbterm: ${CPPFLAGS}"
    # --- END FIX ---

    export CXXFLAGS="${CXXFLAGS} -Wno-narrowing -fpermissive"
    export LIBS="-liconv -lexpat -lz"
    echo "Applying special compile flags for fbterm: CXXFLAGS='${CXXFLAGS}' LIBS='${LIBS}'"

    # 重点在这里：添加 --disable-nls 
    ./configure --prefix=/usr --host="${TARGET_HOST}" --disable-nls
    make -j$(nproc)

    echo "fbterm executable is at: ${BUILD_DIR}/fbterm-truecolor/src/fbterm"
    cd "${BUILD_DIR}"
    echo "======== fbterm compilation finished. ========"
)

cd "${WORKSPACE_DIR}"
echo "fbterm-truecolor      [OK]"
echo "含动态链接库组件编译完成"
cd "$(WORKSPACE_DIR)"
echo "========================================="
tree "${WORKSPACE_DIR}/staging"
sleep 1
echo "========================================="

# 3. 安装可执行文件
echo ">>> Installing fbterm libs and executables in the sysdump..."
cp -r "${INSTALL_DIR}/usr/bin/"* "${SYSDUMP_DIR}/usr/bin"
cp -r "${WORKSPACE_DIR}/fbterm-truecolor/src/fbterm" "${SYSDUMP_DIR}/usr/bin"
echo ">>> All programs compile finished"

# 4. 合并系统资源文件到 sysdump
OEM_DIR="${WORKSPACE_DIR}/oem-sysroot"
cp -r "${OEM_DIR}/oem/"* "${SYSDUMP_DIR}"
cp -r "${OEM_DIR}/usr/share/" "${SYSDUMP_DIR}/usr/"
cp -r "${OEM_DIR}/usr/etc/" "${SYSDUMP_DIR}/usr/"
cp -r "${OEM_DIR}/usr/ko/" "${SYSDUMP_DIR}/usr/"
cp -r "${OEM_DIR}/usr/lib/"* "${SYSDUMP_DIR}/usr/lib"
cp -r "${OEM_DIR}/usr/bin/"* "${SYSDUMP_DIR}/usr/bin"

echo "All Compilations done"
echo "========================================="
tree "${DIST_DIR}"
sleep 1
echo "========================================="

# 5. 打包
cd "${SYSDUMP_DIR}"
tar cvf ../sysdump.tar .
cd "${WORKSPACE_DIR}"


echo "====== Executables exported. ======"
echo ""
echo "================================================================="
echo "Script finished! The 'output' directory has been generated and is ready for packaging."
echo "================================================================="
