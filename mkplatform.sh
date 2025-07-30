#!/bin/bash
#
# Copyright (c) 2025 Gé Koerkamp / ge(dot)koerkamp(at)bluewin##(dot)com
#
# This script is used for building the kernel, u-boot and platform files used for Odroid C4 and Odroid C5.
#
# Prerequisites cq recommended packages:   nfs-common cifs-utils build-essential ca-certificates curl
#                                           debootstrap dosfstools git jq kpartx libssl-dev lz4 lzop
#                                           md5deep multistrap parted patch pv qemu-user-static qemu-utils
#                                           squashfs-tools sudo u-boot-tools wget xz-utils zip debhelper
#                                           libelf-dev flex bison
#
# You also need to install the correct toolchain to cross-compile the kernel:
# http://tbs    gcc-linaro-11.3.1-2022.06-x86_64_aarch64-linux-gnu
#
# For cross-compiling U-Boot:
# https://releases.linaro.org/archive/13.11/components/toolchain/binaries/gcc-linaro-aarch64-none-elf-4.8-2013.11_linux.tar.xz
# https://releases.linaro.org/archive/14.04/components/toolchain/binaries/gcc-linaro-arm-none-eabi-4.8-2014.04_linux.tar.xz

export PATH=/opt/toolchains/gcc-linaro-11.3.1-2022.06-x86_64_aarch64-linux-gnu/bin/:$PATH
export PATH=/opt/toolchains/gcc-linaro-aarch64-none-elf-4.8-2013.11_linux/bin/:/opt/toolchains/gcc-linaro-arm-none-eabi-4.8-2014.04_linux/bin/:$PATH
export ARCH=arm64

SRC="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# check for whitespace in ${SRC} and exit for safety reasons
grep -q "[[:space:]]" <<<"${SRC}" && { log "\"${SRC}\" contains whitespaces, this is not supported. Aborting." "err" >&2 ; exit 1 ; }

# shellcheck source=scripts/helpers.sh
source "${SRC}"/scripts/helpers.sh

# shellcheck source=scripts/main.sh
source "${SRC}"/scripts/main.sh

# shellcheck source=scripts/functions.sh
source "${SRC}"/scripts/functions.sh

DELAY=2 # Number of seconds to display results
while true; do
  clear
  cat << _EOF_
Please select the Odroid board you wish to build the platform files for:
1. C4
2. N2/N2+
3. Quit

_EOF_

  read -p "Enter selection [1-3] > "
  if [[ $REPLY =~ ^[1-3]$ ]]; then
    case $REPLY in
      1)
        DEVICE="odroidc4"
        break
        ;;
      2)
        DEVICE="odroidn2"
        break
        ;;
      3)
        echo "Platform build interrupted"
        exit
        ;;
    esac
  else
    echo "Invalid entry, please select either 1 (odroidc4), 2 (odroidn2) or 3 (to quit)"
    sleep $DELAY
  fi
done

source "${SRC}"/configs/config.arm64

log "LINUX_REPO_URL=       " ${LINUX_REPO_URL}
log "KERNELDIR=            " ${KERNELDIR}
log "KERNELBRANCH=         " ${KERNELBRANCH}
log "CURRENTCONFIG_PREFIX= " ${CURRENTCONFIG_PREFIX}

log "UBOOT_REPO_URL=       " ${UBOOT_REPO_URL}
log "UBOOTDIR=             " ${UBOOTDIR}
log "UBOOTBRANCH           " ${UBOOTBRANCH}


PLATFORMDIR=${SRC}/$DEVICE
log "PLATFORMDIR           "  $PLATFORMDIR

log "Start processing for $DEVICE"
log "Cloning ${UBOOTDIR}, branch ${UBOOTBRANCH}" "info"
clone_uboot
log "Compiling u-boot..."
compile_uboot ${DEVICE}

log "Cloning ${KERNELDIR}, branch ${KERNELBRANCH}" "info"
clone_kernel
log "Compiling the kernel..."
compile_kernel

log "Building platform files" "info"
build_platform

log "Compressing the platform folder" "info"
compress_platform


