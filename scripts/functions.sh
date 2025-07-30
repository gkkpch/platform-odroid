#!/bin/bash


clone_uboot() {
  if [ -d ${UBOOTDIR} ]; then
    log "${UBOOTDIR} exists, keeping it" "info"
  else
    git clone ${UBOOT_REPO_URL} -b ${UBOOTBRANCH} ${UBOOTDIR}
    log "${UBOOTDIR}, branch ${UBOOTBRANCH} clone successfully" "info"
  fi
}

clone_kernel() {
  if [ -d ${KERNELDIR} ]; then
    log "${KERNELDIR} exists, keeping it"
  else
    git clone ${LINUX_REPO_URL} -b ${KERNELBRANCH} ${KERNELDIR}
    log "${KERNELDIR}, branch ${KERNELBRANCH} cloned successfully"
  fi
}

compile_uboot() {
  cd ${UBOOTDIR}
  make mrproper
  make ARCH=arm64 CROSS_COMPILE=aarch64-none-elf- ${DEVICE}_defconfig
  make

  log "securing uboot"
  [ -d ${SRC}/uboot/${DEVICE} ] || mkdir -p ${SRC}/uboot/${DEVICE}
  cp sd_fuse/u-boot.bin ${SRC}/uboot/${DEVICE}
  log "Compiled ${UBOOTBRANCH} successfully" "info"
  cd ..
}

compile_kernel() {

  cd ${KERNELDIR}
  log "Cleaning and preparing .config"

  cp ${SRC}/configs/odroidg12_defconfig arch/arm64/configs/
  make clean
  make odroidg12_defconfig

  make menuconfig
  cp .config ${SRC}/configs/odroidg12_defconfig

  log "Compiling dts, image and modules"
  make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(expr $(expr $(nproc) \* 6) \/ 5) Image.gz dtbs modules

  log "securing used defconfig file"
  rm ${SRC}/${CURRENTCONFIG_PREFIX}*
  kver=`make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 kernelrelease`
  cp arch/arm64/configs/odroidg12_defconfig ${SRC}/configs/config-${kver}

  log "Kernel compiled successfully" "info"
  cd ..
}

build_platform() {

  log "Saving platform files to ${PLATFORMDIR}" "info"
  log "Initializing..."
  if [ -d ${DEVICE} ]; then
    rm -r ${DEVICE}/*
  else
    mkdir ${DEVICE}
  fi
  mkdir ${DEVICE}/uboot
  mkdir -p ${PLATFORMDIR}/boot/amlogic/overlays/${DEVICE}
  mkdir -p ${PLATFORMDIR}/lib/firmware

  log "Coyping u-boot..."
  cp uboot/${DEVICE}/u-boot.bin ${PLATFORMDIR}/uboot/

  cd ${KERNELDIR}
  log "Copying image and dtb's.."
  cp arch/arm64/boot/Image.gz ${PLATFORMDIR}/boot
  cp arch/arm64/boot/dts/amlogic/meson64_${DEVICE}*.dtb ${PLATFORMDIR}/boot/amlogic
  cp arch/arm64/boot/dts/amlogic/overlays/${DEVICE}/*.dtbo ${PLATFORMDIR}/boot/amlogic/overlays/${DEVICE}

  log "Copying used defconfig"
  cp ${SRC}/configs/config-${kver} ${PLATFORMDIR}/boot

  log "Copying modules..."
  make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 modules_install INSTALL_MOD_PATH=${PLATFORMDIR}/
  cd ..

  log "Copying .ini files"
  cp configs/${DEVICE}-boot.ini ${PLATFORMDIR}/boot/boot.ini
  if [ -f configs/${DEVICE}-config.ini ]; then
    cp configs/${DEVICE}-config.ini ${PLATFORMDIR}/boot/config.ini
  fi
  cp configs/${DEVICE}-example.user.config.ini ${PLATFORMDIR}/boot/example.user.config.ini

  log "Coyping firmware..."
  cp -pdR firmware/ ${DEVICE}

  log "Copying etc"
  cp -pdR "etc" ${DEVICE}
}

compress_platform() {
  echo $PWD
  log "Compressing ${DEVICE}"
  tar cvfJ ${DEVICE}.tar.xz ./${DEVICE}
}
