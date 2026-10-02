#!/bin/bash
# ==============================================================================
# FronxKernel Master Build Script (Root-Only Edition)
# Target: Xiaomi POCO M4 Pro 5G / Redmi Note 11S 5G (everpal)
# Maintainer: FrontlXOX
# Architecture: MediaTek Dimensity 810 (MT6833P / Linux 4.14.357-Fronx)
# Embedded Root: ReSukiSU v4.2.0-rc3 + SuSFS v2.3.00 (Hardlocked)
# ==============================================================================

# Pre-build cleanup
rm -rf vmlinux* System.map modules.builtin*
rm -rf .config .config.old .tmp_versions
rm -rf include/generated include/config
rm -rf arch/arm64/include/generated
rm -f Module.symvers modules.order
rm -rf scripts/kconfig/.tmp*
rm -rf out/arch/arm64/boot

SECONDS=0
CUSTOM_TC=""
OUTPUT_DIR=""
DEVICE="everpal"
CLEAN_BUILD=false
CURRENT_DIR=$(pwd)
DATE=$(date '+%Y%m%d-%H%M')
DEFCONFIG="${DEVICE}_defconfig"

# Process options
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --toolchains)
            CUSTOM_TC="$2"
            shift 2
            ;;
        --toolchains=*)
            CUSTOM_TC="${1#*=}"
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            shift
            ;;
    esac
done

ZIPNAME="FronxKernel-${DATE}.zip"

# Toolchain directory resolution
if [ -n "$CUSTOM_TC" ]; then
    if [ -d "$CUSTOM_TC" ]; then
        CUSTOM_TC="$(cd "$CUSTOM_TC" 2>/dev/null && pwd || echo "$CUSTOM_TC")"
    fi
    if [ -f "$CUSTOM_TC/bin/clang" ]; then
        TC_DIR="$CUSTOM_TC"
    elif [ -f "$CUSTOM_TC/ZyC-clang-22.0.0/bin/clang" ]; then
        TC_DIR="$CUSTOM_TC/ZyC-clang-22.0.0"
    else
        TC_DIR="$CUSTOM_TC"
    fi
else
    if [ -f "$CURRENT_DIR/../../build/toolchains/ZyC-clang-22.0.0/bin/clang" ]; then
        TC_DIR="$(cd "$CURRENT_DIR/../../build/toolchains/ZyC-clang-22.0.0" && pwd)"
    elif [ -f "$CURRENT_DIR/build/toolchains/ZyC-clang-22.0.0/bin/clang" ]; then
        TC_DIR="$(cd "$CURRENT_DIR/build/toolchains/ZyC-clang-22.0.0" && pwd)"
    else
        TC_DIR="$HOME/toolchains/ZyC-clang-22.0.0"
    fi
fi

# Ensure compiler is available
if [ ! -d "$TC_DIR" ] || [ ! -f "$TC_DIR/bin/clang" ]; then
    mkdir -p "$TC_DIR" && cd "$TC_DIR" || exit
    wget https://github.com/ZyCromerZ/Clang/releases/download/22.0.0git-20250928-release/Clang-22.0.0git-20250928.tar.gz && tar xvf Clang-22.0.0git-20250928.tar.gz && rm -rf Clang-22.0.0git-20250928.tar.gz
    cd "$CURRENT_DIR" || exit
fi

export PATH="$TC_DIR/bin:$PATH"
export CC=clang
export LD=ld.lld

echo
echo "=================================================="
echo " FronxKernel Root Suite (Dimensity 810 / everpal)"
echo " Maintainer: FrontlXOX"
echo " Compiler:   $TC_DIR"
echo "=================================================="
clang --version
echo

# Resolve output directory
if [ -n "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" 2>/dev/null && pwd || echo "$OUTPUT_DIR")"
    ZIP_DEST="$OUTPUT_DIR_ABS/$ZIPNAME"
else
    OUTPUT_DIR_ABS="$CURRENT_DIR"
    ZIP_DEST="$CURRENT_DIR/$ZIPNAME"
fi

[ "$CLEAN_BUILD" = true ] && rm -rf out
mkdir -p out

# Ensure root architecture is permanently linked
if [ ! -L drivers/kernelsu ] && [ -d KernelSU/kernel ]; then
    ln -sf ../KernelSU/kernel drivers/kernelsu
fi

# Apply defconfig
make O=out ARCH=arm64 "$DEFCONFIG"

echo -e "\nStarting FronxKernel compilation...\n"
if \
    make -j$(nproc --all) O=out ARCH=arm64 CC="ccache clang" LLVM=1 LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    KCFLAGS="-Wno-error=default-const-init-var-unsafe" Image.gz dtbs; \
    then

    echo -e "\nKernel compiled successfully! Packaging FronxKernel AnyKernel3...\n"
    rm -rf AnyKernel3

    # Use local template if available, else clone AnyKernel3
    TEMPLATE_DIR="$CURRENT_DIR/../../src/package/templates/AnyKernel3"
    if [ -d "$TEMPLATE_DIR" ]; then
        cp -r "$TEMPLATE_DIR" AnyKernel3
    else
        git clone -q --depth=1 https://github.com/FrontlXOX/AnyKernel3 AnyKernel3 2>/dev/null || \
        git clone -q --depth=1 https://github.com/osm0sis/AnyKernel3 AnyKernel3
    fi

    # Inject kernel image
    cp out/arch/arm64/boot/Image.gz AnyKernel3/

    # Write custom FronxKernel branding banner
    cat << "EOF" > AnyKernel3/banner
================================================
 ███████╗██████╗  ██████╗ ███╗   ██╗██╗  ██╗
 ██╔════╝██╔══██╗██╔═══██╗████╗  ██║╚██╗██╔╝
 █████╗  ██████╔╝██║   ██║██╔██╗ ██║ ╚███╔╝ 
 ██╔══╝  ██╔══██╗██║   ██║██║╚██╗██║ ██╔██╗ 
 ██║     ██║  ██║╚██████╔╝██║ ╚████║██╔╝ ██╗
 ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝
    F R O N X   K E R N E L   R O O T
================================================
EOF

    # Write custom FronxKernel version info
    cat << EOF > AnyKernel3/version
FronxKernel 4.14.357-Fronx (Root-Only / ReSukiSU + SuSFS)
Target: Xiaomi POCO M4 Pro 5G / Redmi Note 11S 5G (everpal)
Build Date: $(date '+%Y-%m-%d %H:%M')
Author: FrontlXOX
EOF

    # Write custom FronxKernel anykernel.sh installer
    cat << "EOF" > AnyKernel3/anykernel.sh
### AnyKernel3 Ramdisk Mod Script
## FronxKernel Project by FrontlXOX
## Root-Only Edition: ReSukiSU v4.2.0-rc3 + SuSFS v2.3.0

properties() { '
kernel.string=Fronx Kernel for Xiaomi POCO M4 Pro 5G / Redmi Note 11S 5G
do.devicecheck=0
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=1
device.name1=everpal
device.name2=evergo
'; }

# boot shell variables
block=boot;
is_slot_device=auto;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;
no_block_display=1;

# import functions/variables and setup patching
. tools/ak3-core.sh;

ui_print " "
ui_print "================================================"
ui_print "   F R O N X   K E R N E L   R O O T"
ui_print "================================================"
ui_print " • Target:    Xiaomi POCO M4 Pro 5G (everpal)"
ui_print " • Platform:  MediaTek Dimensity 810 (MT6833P)"
ui_print " • Kernel:    Linux 4.14.357-Fronx PREEMPT SMP"
ui_print " • Variant:   Root Edition (ReSukiSU + SuSFS)"
ui_print " • Author:    FrontlXOX"
ui_print " • Toolchain: ZyC Clang 22.0.0 (LLVM + ThinLTO)"
ui_print "------------------------------------------------"

# Pre-flight environment diagnostics
ui_print " [i] Pre-flight Environment Inspection..."
SLOT=$(find_slot 2>/dev/null)
if [ -n "$SLOT" ]; then
  ui_print "     -> Active Slot:        $SLOT"
else
  ui_print "     -> Active Slot:        A-only / Single"
fi

DEVICE=$(getprop ro.product.device 2>/dev/null || getprop ro.build.product 2>/dev/null)
[ -n "$DEVICE" ] && ui_print "     -> Target Device:      $DEVICE"

SDK=$(getprop ro.build.version.sdk 2>/dev/null)
REL=$(getprop ro.build.version.release 2>/dev/null)
if [ -n "$REL" ]; then
  ui_print "     -> Android OS:         Android $REL (API $SDK)"
fi

ui_print " "
ui_print " [+] Dumping & splitting boot partition..."
split_boot;

ui_print " [+] Injecting Fronx Kernel (Image.gz)..."
flash_boot;

if [ -f dtb.img ] || [ -f dtbo.img ]; then
  ui_print " [+] Flashing Device Tree overlays..."
  flash_dtbo;
fi

ui_print " "
ui_print "================================================"
ui_print "  [✓] FRONXKERNEL FLASH COMPLETED SUCCESSFULLY!"
ui_print "================================================"
ui_print " Subsystems Status:"
ui_print " • Root Solution:    ReSukiSU v4.2.0-rc3 (Active)"
ui_print " • SuSFS Engine:     v2.3.00 Inline Hooks (Active)"
ui_print " • Stealth Spoofing: Path / Mount / Kstat / Map"
ui_print " • Energy Model:     EAS / Schedutil Optimized"
ui_print " • Memory Profile:   Zone Normal Reclaim Ready"
ui_print " • Interconnect:     CoreLink CCI Uncapped"
ui_print "------------------------------------------------"
ui_print " Please reboot your device to boot FronxKernel!"
ui_print "================================================"
ui_print " "
EOF

    (cd AnyKernel3 && zip -r9 "$ZIP_DEST" * -x '*.git*' README.md '*placeholder')
    rm -rf AnyKernel3

    echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
    echo "Zip: $ZIP_DEST"
    [ -n "$OUTPUT_DIR" ] && echo "Output directory: $OUTPUT_DIR_ABS"
else
    echo -e "\nCompilation failed!"
fi
