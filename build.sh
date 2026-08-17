#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CONFIGURATION & PATHS
# ==============================================================================
WINE_SRC_DIR="./"
WINE_SRC_DIR="$(cd "${WINE_SRC_DIR}" && pwd)"
BUILD_DIR="${WINE_SRC_DIR}/build-x86_64"
INSTALL_PREFIX="/tmp/wine_build"
OUTPUT_WCP="${HOME}/wine-custom-10.12.wcp"

echo "================================================================="
echo "==> Starting Complete Wine WOW64 Build Pipeline for Winlator..."
echo "================================================================="

# 1. Clear Conflict Environment Variables
echo "==> Cleaning pkg-config environment variables..."
unset PKG_CONFIG_PATH
unset PKG_CONFIG_SYSROOT_DIR

# 2. Install EXHAUSTIVE Build Dependencies
echo "==> Installing ALL Wine host & cross-compiler build dependencies..."
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  bison \
  flex \
  pkg-config \
  gcc-mingw-w64-i686 \
  g++-mingw-w64-i686 \
  gcc-mingw-w64-x86-64 \
  g++-mingw-w64-x86-64 \
  mingw-w64 \
  libfreetype-dev \
  libfontconfig1-dev \
  libgl1-mesa-dev \
  libglu1-mesa-dev \
  libvulkan-dev \
  libsdl2-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  libgstreamer-plugins-good1.0-dev \
  libgstreamer-plugins-bad1.0-dev \
  libasound2-dev \
  libpulse-dev \
  libgnutls28-dev \
  libdbus-1-dev \
  libmpg123-dev \
  libopenal-dev \
  libpng-dev \
  libjpeg-dev \
  libtiff-dev \
  libwebp-dev \
  liblcms2-dev \
  libxml2-dev \
  libxslt1-dev \
  libx11-dev \
  libxcursor-dev \
  libxi-dev \
  libxext-dev \
  libxfixes-dev \
  libxrandr-dev \
  libxcomposite-dev \
  libxxf86vm-dev \
  libxrender-dev \
  ocl-icd-opencl-dev \
  tar \
  xz-utils

# 3. Setup Directories
if [ ! -d "${WINE_SRC_DIR}" ]; then
  echo "ERROR: Wine source directory '${WINE_SRC_DIR}' not found!"
  echo "Please place your Wine source code at '${WINE_SRC_DIR}' before running this script."
  exit 1
fi

echo "==> Preparing build directory at ${BUILD_DIR}..."
mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}"/*
rm -rf "${INSTALL_PREFIX}"
mkdir -p "${INSTALL_PREFIX}"

cd "${BUILD_DIR}"

# 4. Configure Wine with Full WOW64 Support & Explicitly Exclude Host Unwind
echo "==> Running Wine ./configure..."
../configure --prefix="${INSTALL_PREFIX}" \
  --enable-archs=i386,x86_64 \
  --enable-win64 \
  --with-mingw \
  --without-unwind \
  --with-freetype \
  --with-fontconfig \
  --with-gstreamer \
  --with-vulkan \
  --with-opengl \
  --with-sdl \
  --with-gnutls \
  --with-dbus \
  --enable-tools \
  --disable-tests \
  --disable-win16 \
  --without-capi \
  --without-coreaudio \
  --without-cups \
  --without-gphoto \
  --without-krb5 \
  --without-netapi \
  --without-oss \
  --without-pcap \
  --without-pcsclite \
  --without-sane \
  --without-udev \
  --without-usb \
  --without-v4l2 \
  --without-wayland \
  --without-xinerama \
  --without-ffmpeg

# 5. Compile Across All CPU Cores
NPROC=$(nproc)
echo "==> Compiling Wine using ${NPROC} threads..."
make -j"${NPROC}"

# 6. Install Binaries & Strip Debug Symbols
echo "==> Installing stripped binaries to ${INSTALL_PREFIX}..."
make install STRIP=true

# 7. Verification Steps
echo "==> Verifying PE architecture output..."
if [ -f "${INSTALL_PREFIX}/lib/wine/i386-windows/ntdll.dll" ] && [ -f "${INSTALL_PREFIX}/lib/wine/x86_64-windows/ntdll.dll" ]; then
  echo "SUCCESS: Both i386-windows and x86_64-windows PE modules compiled successfully!"
else
  echo "ERROR: Build failed! Missing i386-windows or x86_64-windows ntdll.dll."
  exit 1
fi

echo "==> Checking for unwanted libunwind link..."
if ldd "${INSTALL_PREFIX}/lib/wine/x86_64-unix/ntdll.so" 2>/dev/null | grep -q "unwind"; then
  echo "WARNING: libunwind dependency was found!"
else
  echo "SUCCESS: Zero libunwind dependencies in Unix binaries!"
fi

# 8. Inject profile.json and prefixPack.tzst into Package Root
echo "==> Injecting profile.json and prefixPack.tzst..."
if [ -f "${WINE_SRC_DIR}/profile.json" ]; then
  cp -v "${WINE_SRC_DIR}/profile.json" "${INSTALL_PREFIX}/"
else
  echo "WARNING: ${WINE_SRC_DIR}/profile.json not found!"
fi

if [ -f "${WINE_SRC_DIR}/prefixPack.tzst" ]; then
  cp -v "${WINE_SRC_DIR}/prefixPack.tzst" "${INSTALL_PREFIX}/"
else
  echo "WARNING: ${WINE_SRC_DIR}/prefixPack.tzst not found!"
fi

# 9. Compress Package into .wcp
echo "==> Packaging into Winlator Container Package (.wcp)..."
cd "${INSTALL_PREFIX}"
tar --exclude='include' -cJvf "${OUTPUT_WCP}" .

echo "================================================================="
echo "BUILD COMPLETE!"
echo "Package saved to: ${OUTPUT_WCP}"
echo "================================================================="