#!/usr/bin/env bash
# shellcheck disable=SC2154

# Script For Building Android arm64 Kernel#
# Copyright (c) 2018-2021 Panchajanya1999 <rsk52959@gmail.com>
# Copyright (c) 2023 Hoppless <hoppless@proton.me>
# Rewrites script by: Hoppless <hoppless@proton.me>

set -e
export $(grep -v '^#' config.env | xargs)
# Directory info
KDIR="$(pwd)"

# Kernel info
ZIPNAME="Atomic!"
VERSION="0.1"
ARCH=arm64
DEFCONFIG="merlin_defconfig"
COMPILER="clang"
LINKER=ld.lld

# Device info
MODEL="Redmi Note 9"
DEVICE="merlin"

# Misc info
CLEAN="1"
SIGN=1
if [[ $SIGN == 1 ]]; then
	#Check for java
	if ! hash java 2>/dev/null 2>&1; then
		SIGN=0
		msger -n "you may need to install java, if you wanna have Signing enabled"
	else
		SIGN=1
	fi
fi

# Date info
DATE=$(TZ=Asia/Jakarta date)
ZDATE=$(date "+%Y%m%d")

clone() {
	echo " "
	if [[ $COMPILER == "gcc" ]]; then
		echo -e "\n\e[1;93m[*] Cloning GCC \e[0m"
			git clone https://github.com/mvaisakh/gcc-arm64 --depth=1 -b gcc-master "${KDIR}"/gcc64
			git clone https://github.com/mvaisakh/gcc-arm --depth=1 -b gcc-master "${KDIR}"/gcc32
    elif [[ $COMPILER == "clang" ]]; then
              rm -rf clang-azure
		echo -e "\e[1;93m[*] Cloning Clang! \e[0m"
			git clone https://gitlab.com/Panchajanya1999/azure-clang clang-azure --depth=1
                        cd clang-azure
                        wget "https://gist.github.com/dakkshesh07/240736992abf0ea6f0ee1d8acb57a400/raw/a835c3cf8d99925ca33cec3b210ee962904c9478/patch-for-old-glibc.sh" -O patch.sh && chmod +x patch.sh && ./patch.sh 
                        cd ..
	fi
	        echo -e "\n\e[1;32m[*] Cloning Anykernel3 ! \e[0m"
                       rm -rf Anykernel3
			git clone https://github.com/nuuwy0/Anykernel3.git  --depth=1 -b merlin "${KDIR}"/Anykernel3
}

##------------------------------------------------------##

exports() {
	KBUILD_BUILD_HOST="nuuwy0"
	KBUILD_BUILD_USER="0ywuun"

	if [[ $COMPILER == "clang" ]]; then
		 export PATH="${KDIR}"/clang-azure/bin/:/usr/bin/:${PATH}
	elif [[ $COMPILER == "gcc" ]]; then
		 export PATH="${KDIR}"/gcc32/bin:"${KDIR}"/gcc64/bin:/usr/bin/:${PATH}
	fi
	PROCS=$(nproc --all)

	export KBUILD_BUILD_USER KBUILD_BUILD_HOST \
		KBUILD_COMPILER_STRING ARCH SUBARCH \
		PATH
}

##---------------------------------------------------------##

if [ ! -d "Telegram" ]; then
  git clone --depth=1 https://github.com/Hopireika/telegram.sh Telegram
fi
TELEGRAM="$(pwd)/Telegram/telegram"
tgm() {
	"${TELEGRAM}" -H -D \
		"$(
			for POST in "${@}"; do
				echo "${POST}"
			done
		)"
}

tgf() {
	"${TELEGRAM}" -H \
		-f "$1" \
		"$2"
}

##----------------------------------------------------------##

build_kernel() {
	if [[ $CLEAN == "1" ]]; then
		echo -e "\n\e[1;93m[*] Cleaning source and out/ directory! \e[0m"
		make clean && make mrproper && rm -rf out
	fi

tgm "
<b>🛠 Atomic! Kernel Build Triggered</b>
<b>-----------------------------------------</b>
<b>[*] Architecture</b>   => <code>$ARCH</code>
<b>[*] Build Date</b>     => <code>$DATE</code>
<b>[*] Device Name</b>    => <code>${MODEL} [${DEVICE}]</code>
<b>[*] Defconfig</b>      => <code>$CONFIG</code>
<b>[*] Kernel Name</b>    => <code>${ZIPNAME}</code>
<b>[*] Kernel Version</b> => <code>${VERSION}</code>
<b>[*] Linux Version</b>  => <code>$(make kernelversion)</code>
<b>[*] Compiler Name</b>  => <code>${KBUILD_COMPILER_STRING}</code>
<b>-----------------------------------------</b>
"
	make O=out $DEFCONFIG
	BUILD_START=$(date +"%s")

	if [[ $COMPILER == "clang" ]]; then
	       MAKE+=(
		       ARCH=arm64
                       CROSS_COMPILE=aarch64-linux-gnu-
                       CROSS_COMPILE_ARM32=arm-linux-gnueabi-
                       LD="${LINKER}"
                       AR=llvm-ar
                       AS=llvm-as
                       NM=llvm-nm
                       OBJDUMP=llvm-objdump
                       STRIP=llvm-strip
                       CC=clang
              )
       elif [[ $COMPILER == "gcc" ]]; then
	       MAKE+=(
		       ARCH=arm64
                       CROSS_COMPILE=aarch64-elf-
                       CROSS_COMPILE_COMPAT=arm-eabi-
                       LD="${KDIR}"/gcc64/bin/aarch64-elf-"${LINKER}"
                       AR=aarch64-elf-ar
                       AS=aarch64-elf-as
                       NM=aarch64-elf-nm
                       OBJDUMP=aarch64-elf-objdump
                       OBJCOPY=aarch64-elf-objcopy
                       CC=aarch64-elf-gcc
	      )
	fi

	echo -e "\n\e[1;93m[*] Building Kernel! \e[0m"
	make -kj"$PROCS" O=out \
		V=$VERBOSE \
		"${MAKE[@]}" 2>&1 | tee build.txt

	BUILD_END=$(date +"%s")
	DIFF=$((BUILD_END - BUILD_START))

	if [[ -f "${KDIR}"/out/arch/arm64/boot/Image ]]; then
		echo -e "\n\e[1;32m[✓] Kernel successfully compiled!  \e[0m"
		gen_zip
	else
		echo -e "\n\e[1;32m[✗] Build Failed! \e[0m"
                tgf "$(pwd)/error.log"
	fi

}

##--------------------------------------------------------------##

gen_zip() {
	echo -e "\n\e[1;32m[*] Create a flashable zip! \e[0m"
	mv "${KDIR}"/out/arch/arm64/boot/Image Anykernel3/
	mv "${KDIR}"/out/arch/arm64/boot/dts/mediatek/mt6768.dtb Anykernel3/dtb
	mv "${KDIR}"/out/arch/arm64/boot/dtbo.img Anykernel3/
	cd  Anykernel3
	zip -r $ZIPNAME-$VERSION-$DEVICE-"$ZDATE" . -x ".git*" -x "README.md" -x "*.zip"
	ZIP_FINAL="$ZIPNAME-$VERSION-$DEVICE-$ZDATE"

	if [[ $SIGN == 1 ]]; then
		## Sign the zip before sending it to telegram
		echo -e "\n\e[1;32m[*] Signing zip with AOSP keys! \e[0m"
		curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
		java -jar zipsigner-3.0.jar "$ZIP_FINAL".zip "$ZIP_FINAL"-signed.zip
		ZIP_FINAL="$ZIP_FINAL-signed"
		echo -e "\n\e[1;32m[✓] Zip Signed! \e[0m"
	fi
}

clean() {
      echo -e "\n\e[1;32m[*] Cleaning work directory! \e[0m"
      rm -rf out Anykernel3 gcc clang-azure
      echo -e "\n\e[1;32m[✓] Work directory has benn cleaned! \e[0m"
}

clone
exports
build_kernel
clean
##--------------------------------------------------##
