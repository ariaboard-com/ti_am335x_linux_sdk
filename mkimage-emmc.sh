#!/bin/bash

IMAGE=am335x-emmc.img
IMAGE_SIZE=3584
BOOTFS_SIZE=64
ROOTFS_SIZE=1536
RESCFS_SIZE=256
USERFS_SIZE=1536

BOOTFS_START=1
ROOTFS_START=$(expr ${BOOTFS_START} + ${BOOTFS_SIZE})
RESCFS_START=$(expr ${ROOTFS_START} + ${ROOTFS_SIZE})
USERFS_START=$(expr ${RESCFS_START} + ${RESCFS_SIZE})

export WORKDIR="$(pwd)"

if [ ! -f "${WORKDIR}/output/u-boot.img" ]; then
    echo "U-Boot is not built yet!"
    exit 1
fi

if [ ! -f "${WORKDIR}/buildroot/output/am335x/images/rootfs.tar" ]; then
    echo "RootFS is not built yet!"
    exit 2
fi

RUID="$(id -u)"

if [ x"${RUID}" != x"0" ]; then
    echo "Need root privilege to create image!"
    exit 255
fi

mkdir -p "${WORKDIR}/output/tmp"
mkdir -p "${WORKDIR}/output/tmp/bootfs"
mkdir -p "${WORKDIR}/output/tmp/rootfs"

echo "Creating disk image..."
dd if=/dev/zero of="${WORKDIR}/output/${IMAGE}" bs=1M count="${IMAGE_SIZE}"
sfdisk "${WORKDIR}/output/${IMAGE}" < "${WORKDIR}/emmc-parts.sfdisk"

echo "Creating bootfs..."
dd if=/dev/zero of="${WORKDIR}/output/tmp/am335x-bootfs.img" bs=1M count="${BOOTFS_SIZE}"
mkfs.vfat "${WORKDIR}/output/tmp/am335x-bootfs.img"
mount -o loop "${WORKDIR}/output/tmp/am335x-bootfs.img" "${WORKDIR}/output/tmp/bootfs"
cp -v "${WORKDIR}/output/MLO" "${WORKDIR}/output/tmp/bootfs/"
cp -v "${WORKDIR}/output/u-boot.img" "${WORKDIR}/output/tmp/bootfs/"
cp -v "${WORKDIR}/output/uEnv.txt" "${WORKDIR}/output/tmp/bootfs/"
umount "${WORKDIR}/output/tmp/bootfs"

dd if="${WORKDIR}/output/tmp/am335x-bootfs.img" of="${WORKDIR}/output/${IMAGE}" bs=1M \
    seek=${BOOTFS_START} conv=notrunc
rm -f "${WORKDIR}/output/tmp/am335x-bootfs.img"
sync

echo "Creating rootfs..."
dd if=/dev/zero of="${WORKDIR}/output/tmp/am335x-rootfs.img" bs=1M count="${ROOTFS_SIZE}"
dd if=/dev/zero of="${WORKDIR}/output/tmp/am335x-userfs.img" bs=1M count="${USERFS_SIZE}"
mkfs.ext4 "${WORKDIR}/output/tmp/am335x-rootfs.img"
mkfs.ext4 "${WORKDIR}/output/tmp/am335x-userfs.img"
mount -o loop "${WORKDIR}/output/tmp/am335x-rootfs.img" "${WORKDIR}/output/tmp/rootfs"
mkdir -p "${WORKDIR}/output/tmp/rootfs/var"
mount -o loop "${WORKDIR}/output/tmp/am335x-userfs.img" "${WORKDIR}/output/tmp/rootfs/var"
tar -xpf "${WORKDIR}/buildroot/output/am335x/images/rootfs.tar" -C "${WORKDIR}/output/tmp/rootfs"
sync

umount "${WORKDIR}/output/tmp/rootfs/var"
umount "${WORKDIR}/output/tmp/rootfs"

dd if="${WORKDIR}/output/tmp/am335x-rootfs.img" of="${WORKDIR}/output/${IMAGE}" bs=1M \
    seek=${ROOTFS_START} conv=notrunc
rm -f "${WORKDIR}/output/tmp/am335x-rootfs.img"
dd if="${WORKDIR}/output/tmp/am335x-userfs.img" of="${WORKDIR}/output/${IMAGE}" bs=1M \
    seek=${USERFS_START} conv=notrunc
rm -f "${WORKDIR}/output/tmp/am335x-userfs.img"
sync

echo "Creating rescfs..."
dd if=/dev/zero of="${WORKDIR}/output/tmp/am335x-rescfs.img" bs=1M count="${RESCFS_SIZE}"
mkfs.ext4 "${WORKDIR}/output/tmp/am335x-rescfs.img"

dd if="${WORKDIR}/output/tmp/am335x-rescfs.img" of="${WORKDIR}/output/${IMAGE}" bs=1M \
    seek=${RESCFS_START} conv=notrunc
rm -f "${WORKDIR}/output/tmp/am335x-rescfs.img"
sync

rm -rf "${WORKDIR}/output/tmp"

gzip "${WORKDIR}/output/${IMAGE}"

echo "Image ${IMAGE} created successfully."
