#!/bin/bash

# Compile script for Aqua kernel

# Remove out directory
rm -rf out/arch/arm64/boot

# Prebuild hacks
rm -rf .config .config.old .tmp_versions
rm -rf include/generated include/config
rm -rf arch/arm64/include/generated
rm -rf vmlinux* System.map modules.builtin*
rm -f Module.symvers modules.order
rm -rf scripts/kconfig/.tmp*

# Date/Time (IST) and version (from VERSION file, bumped per release)
SECONDS=0
DT=$(TZ=Asia/Kolkata date '+%Y%m%d-%H%M')
VERSION=$(cat VERSION)

# Toolchain
TC_DIR="$HOME/toolchains/ZyC-clang-22.0.0"
CURRENT_DIR=$(pwd)

# Device Configs
DEVICE="everpal"
DEFCONFIG="${DEVICE}_defconfig"

# Ensure the toolchain is available
if [ ! -d "$TC_DIR" ]; then
    mkdir -p "$TC_DIR" && cd "$TC_DIR" || exit
    wget https://github.com/ZyCromerZ/Clang/releases/download/22.0.0git-20250928-release/Clang-22.0.0git-20250928.tar.gz \
    && tar xvf Clang-22.0.0git-20250928.tar.gz \
    && rm -rf Clang-22.0.0git-20250928.tar.gz
    cd "$CURRENT_DIR" || exit
fi

export PATH="$TC_DIR/bin:$PATH"
export CC=clang
export LD=ld.lld

echo 
echo "Using compiler:"
clang --version
echo 

# Process options
CLEAN_BUILD=false
INCLUDE_KSU=false

for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN_BUILD=true
            ;;
        --with-ksu)
            INCLUDE_KSU=true
            ;;
        --redo-ksu)
            rm -f .ksu_applied
            INCLUDE_KSU=true
            ;; 
    esac
done

# Perform clean build if specified
[ "$CLEAN_BUILD" = true ] && rm -rf out

# Zip + image names (per flavor, IST stamp shared by all artifacts of this run)
if [[ "$INCLUDE_KSU" = true ]]; then
    ZIPNAME="FronxKernel_ResukiSU_SusFS-${VERSION}_${DT}.zip"
else
    ZIPNAME="FronxKernel-${VERSION}_${DT}.zip"
fi
IMGNAME="${ZIPNAME%.zip}.img"

# Locate the EverpalTweaks checkout root (walk up: tree root has no src//out pair)
REPO_ROOT="$CURRENT_DIR"
for _ in 1 2 3 4 5 6 7 8; do
  [ -f "$REPO_ROOT/AGENTS.md" ] && [ -d "$REPO_ROOT/src" ] && [ -d "$REPO_ROOT/out" ] && break
  REPO_ROOT="$(dirname "$REPO_ROOT")"
done

# Branding applies to both flavors; KSU patch only with --with-ksu (order: KSU first, branding last)
APPLIED_KSU=false
APPLIED_BRANDING=false
[ -f out/.ksu_applied ] && echo "Including KernelSU Next!"

# Include KernelSU if specified
if [[ "$INCLUDE_KSU" = true && ! -f out/.ksu_applied ]]; then
    echo "Including ReSukiSU + SUSFS v2.3.0!"
    if [ ! -d KernelSU ]; then
        git clone https://github.com/ReSukiSU/ReSukiSU KernelSU
        git -C KernelSU checkout 239e1e8871b8fcd51a6e5b3002e0ba522fdd99fb
    fi
    if [ -f ResukiSU-SusFS.patch ]; then
        git apply --exclude=.gitignore ResukiSU-SusFS.patch
        APPLIED_KSU=true
    fi
    mkdir -p out
    touch out/.ksu_applied
fi

# Branding (both flavors)
if [ -f Branding.patch ]; then
    echo "Applying Fronx branding!"
    git apply Branding.patch
    APPLIED_BRANDING=true
fi

# Compilation process
mkdir -p out
make O=out ARCH=arm64 "$DEFCONFIG"

echo -e "\nStarting compilation...\n"

if \
	make -j$(nproc --all) O=out \
	ARCH=arm64 \
	CC="ccache clang" \
	LD="ld.lld" \
	LLVM=1 \
	LLVM_IAS=1 \
	CROSS_COMPILE=aarch64-linux-gnu- \
	CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        KCFLAGS="-Wno-error=default-const-init-var-unsafe" \
	FROnxDT="$DT" \
	Image.gz dtbs; \
	then

    echo -e "\nKernel compiled successfully! Zipping up...\n"

    # Clone AnyKernel3 and create zip
    git clone -q --depth=1 https://github.com/Addster09/AnyKernel3 AnyKernel3
    cp out/arch/arm64/boot/Image.gz AnyKernel3
    sed -i 's/^kernel.string=.*/kernel.string=Fronx Kernel by FrontlXOX/' AnyKernel3/anykernel.sh
    (cd AnyKernel3 && zip -r9 "../$ZIPNAME" * -x '*.git*' README.md '*placeholder')
    rm -rf AnyKernel3 

    # Build flashable boot.img from the zip (needs PI-X base in EverpalTweaks out/)
    BASE_IMG="$REPO_ROOT/out/Firmwares/Project_Infinity-X-3.12.img"
    if [ -f "$BASE_IMG" ]; then
        echo -e "\nBuilding boot.img ...\n"
        python3 "$REPO_ROOT/src/modules/ResukiSU/main.py" \
            -k "$CURRENT_DIR/$ZIPNAME" -b "$BASE_IMG" -o "$REPO_ROOT/out/$IMGNAME"
    else
        echo "PI-X base not found ($BASE_IMG) — skipping boot.img."
    fi

    # Deliver both artifacts to EverpalTweaks out/
    mv -f "$CURRENT_DIR/$ZIPNAME" "$REPO_ROOT/out/" 

    # Revert to vanilla default (reverse order of application)
    [ "$APPLIED_BRANDING" = true ] && git apply -R Branding.patch
    if [ "$APPLIED_KSU" = true ]; then
        git apply -R --exclude=.gitignore ResukiSU-SusFS.patch
        rm -f out/.ksu_applied
    fi 

    echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
    echo "Zip: $REPO_ROOT/out/$ZIPNAME"
    [ -f "$REPO_ROOT/out/$IMGNAME" ] && echo "Img: $REPO_ROOT/out/$IMGNAME"
else
    echo -e "\nCompilation failed!"
fi
