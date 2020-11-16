#!/bin/sh

export WORKDIR="$(pwd)"
export CORES=$(getconf _NPROCESSORS_ONLN)

export PATH="$WORKDIR/prebuilts/gcc/gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux/bin:$PATH"
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export LC_ALL="C.UTF-8"
export LC_CTYPE="C.UTF-8"

mkdir -p "${WORKDIR}/output"

echo "Build u-boot..."
cd "${WORKDIR}/u-boot"

rm MLO || true
rm u-boot.img || true

make clean
make -j${CORES} am335x_evm

mkdir -p "${WORKDIR}/output"
cp -v MLO "${WORKDIR}/output/"
cp -v u-boot.img "${WORKDIR}/output/"
cp -v uEnv/uEnv.txt "${WORKDIR}/output/"

echo "Build buildroot..."
cd "${WORKDIR}/buildroot"
./build-am335x.sh

echo "Completed."
