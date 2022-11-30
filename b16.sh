#!/bin/bash
#
# Compile script for FuAnDo ginkgo kernel
# Copyright (C) 2020-2021 Adithya R.
# Copyright (C) 2021-2022 @LeCmnGend.
#
# Download needed files
KERNEL_DIR=`pwd`
TC_BRANCH="clang-16"
TC_DIR="$HOME/tc/proton/$TC_BRANCH"
TC_URL="https://gitlab.com/lecmngend/proton-clang"
TC_GIT_BRANCH=$TC_BRANCH

AK3_URL="https://github.com/lecmngend/AnyKernel3"
AK3_BRANCH="ginkgo"
AK3_DIR="$HOME/tc/AK3/$AK3_BRANCH"
# Check if toolchain is exist
if ! [ -d "$TC_DIR" ]; then
		echo "Proton clang not found! Cloning to $TC_DIR..."
		if ! git clone --single-branch --depth=1 -b $TC_GIT_BRANCH $TC_URL $TC_DIR; then
				echo "Cloning failed! Aborting..."
				exit 1
		fi
fi

# Check if AK3 exist	
if ! [ -d "$AK3_DIR" ]; then
				echo "$AK3_DIR not found! Cloning to $AK3_DIR..."
				if ! git clone -q --single-branch --depth 1 -b $AK3_BRANCH $AK3_URL $AK3_DIR; then
						echo "Cloning failed! Aborting..."
						exit 1
				fi
else
				echo "$AK3_DIR found! Update $AK3_DIR"
				cd $AK3_DIR
				git pull
				cd $KERNEL_DIR
fi

# Setup environment
DEFCONFIG="ginkgo_defconfig"
SECONDS=0 # builtin bash timer
ZIPNAME="FuAnDo-ginkgo-$(date '+%Y%m%d-%H%M').zip"
export PROC="-j$(nproc --all)"

# Setup ccache environment
export USE_CCACHE=1
export CCACHE_EXEC=/usr/local/bin/ccache
CROSS_COMPILE+="ccache clang"

# Toolchain environtment
export PATH="$TC_DIR/bin:$PATH" 
export THINLTO_CACHE_DIR="/mnt/e/.ccache/ltocache/"
export KBUILD_COMPILER_STRING="$($TC_DIR/bin/clang --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/')"
STRIP="$TC_DIR/bin/$(echo "$(find "$TC_DIR/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"

# Kernel Details
KERNEL_VER="$(date '+%Y%m%d-%H%M')"

clear


function clean_all {
		cd $KERNEL_DIR
		echo
		rm -rf prebuilt
		rm -rf out && make clean && make mrproper
}

while read -p "Do you want to clean stuffs (y/n)? " cchoice
do
case "$cchoice" in
	y|Y )
		clean_all
		echo
		echo "All Cleaned now."
		break
		;;
	n|N )
		echo
		break
		;;
	* )
		echo
		echo "Invalid try again!"
		echo
		;;
esac
done

# Delete old file before build
if [[ $1 = "-c" || $1 = "--clean" ]]; then
		rm -rf out
fi

# Make out folder
mkdir -p out
make  $PROC O=out ARCH=arm64 $DEFCONFIG \
		CLANG_PATH=$TC_DIR/bin \
		CC="ccache clang" \
		CXX="ccache clang++" \
		HOSTCC="ccache clang" \
		HOSTCXX="ccache clang++" \
		LD=ld.lld \
		AR=llvm-ar \
		AS=llvm-as \
		NM=llvm-nm \
		OBJCOPY=llvm-objcopy \
		OBJDUMP=llvm-objdump \
		STRIP=llvm-strip \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
		CROSS_COMPILE_ARM32=arm-linux-gnueabi-

# Regened defconfig 
#  Test use ccache. -j$(nproc --all)
if [[ $1 == "-r" || $1 == "--regen" ]]; then
		   cp out/.config arch/arm64/configs/$DEFCONFIG
		   echo -e "\nRegened defconfig succesfully!"
		   exit 0
else
		echo -e "\nStarting compilation...\n"
		make $PROC O=out ARCH=arm64 \
			CLANG_PATH=$TC_DIR/bin \
			CC="ccache clang" \
			CXX="ccache clang++" \
			HOSTCC="ccache clang" \
			HOSTCXX="ccache clang++" \
			LD=ld.lld \
			AR=llvm-ar \
			AS=llvm-as \
			NM=llvm-nm \
			OBJCOPY=llvm-objcopy \
			OBJDUMP=llvm-objdump \
			STRIP=llvm-strip \
			CROSS_COMPILE="aarch64-linux-gnu-" \
			CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
			CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb dtbo.img
fi


# Creating zip flashable file
function create_zip {
		#Copy AK3 to out/Anykernel13
		cp -r $AK3_DIR AnyKernel3
		cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
		cp out/arch/arm64/boot/dtbo.img AnyKernel3

		# Change dir to AK3 to make zip kernel
		cd AnyKernel3
		zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder

		#Back to out folder and clean
		cd ..
		rm -rf AnyKernel3
		# rm -rf out/arch/arm64/boot ##keep boot to compile rom
		echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
		echo "Zip: $ZIPNAME"
}

function create_prebuilt {
		#Copy Image.gz and dtbo.img to prebuilt folder
		mkdir -p prebuilt
		cp out/arch/arm64/boot/Image.gz-dtb prebuilt
		cp out/arch/arm64/boot/dtbo.img prebuilt
		rm -rf out
		make clean
}

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
		 echo -e "\nKernel compiled succesfully! Zipping up...\n"
		while read -p "Do you want to create Zip file (y/n/p)? " cchoice
		do
		case "$cchoice" in
			y|Y )
				create_zip
				echo -e "\nDone !"
				break
				;;
			n|N )
				echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
				break
				;;
			p|P )
				create_prebuilt
				echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
				break
				;;			
			* )
				echo
				echo "Invalid try again!"
				echo
				;;
		esac
		done
else
		echo -e "\nFailed!"
fi
