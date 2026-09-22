# AGENTS.md — Aqua Kernel (Xiaomi POCO M4 Pro 5G / Redmi Note 11S 5G)

> **Master AI Agent Operational & Architectural Specification for Aqua Kernel**
> Target Device: **Xiaomi POCO M4 Pro 5G / Redmi Note 11S 5G (`everpal`)**
> Target SoC: **MediaTek Dimensity 810 5G (MT6833P / MT6833 family)**
> Target OS: **Android 16** (Project Infinity-X / LineageOS 23.0 base)
> Kernel Version: **Linux 4.14.357-Aqua SMP PREEMPT**
> Repository Remote: `https://github.com/FrontlXOX/android_kernel_xiaomi_mt6833`
> Upstream Maintainer: **Addster09** | Android 16 Bringup: **himanshuksr0007** | Optimization Maintainer: **FrontlXOX**

---

## 1. Architecture & Base Specifications

This kernel repository is the authoritative source for the Aqua Kernel on `everpal`. It is built upon Addster's **Aqua V3.4** baseline (`lineage-24.0-old` / git tag `AquaV3.4` at `d81fee89be1c86979a2421933a0741f55918cc44`).

### Core Backports & Performance Features
- **WALT Scheduler:** `CONFIG_SCHED_WALT=y` enabled with window-assisted load tracking.
- **Android 4.19 Binder:** Full backport from `android-4.19-stable` resolving Android 15/16 IPC concurrency stalls.
- **Modern Syscalls:** Backports for `clone3()` (with `CLONE_CLEAR_SIGHAND`, `set_tid`, `CAP_CHECKPOINT_RESTORE`) and `statx()` (with mount root and mount ID attributes).
- **Memory Management:** LRU_GEN enabled (`CONFIG_LRU_GEN=y`, `CONFIG_LRU_GEN_ENABLED=y`), slab cache alignment to hardware cachelines, and zsmalloc memory allocation hints.
- **CPU & Build Tuning:** ARMv8.2-A + Cortex-A76 microarchitecture optimizations (`-march=armv8.2-a+crypto+crc+lse+fp16+dotprod+rcpc+rdm -mtune=cortex-a76`), Clang ThinLTO, inline optimization thresholds, and BBR congestion control.

---

## 2. Root & Stealth Subsystems: ReSukiSU + SUSFS v2.3.0

The repository provides a dual-state architecture supporting both pure vanilla builds and rooted builds with state-of-the-art stealth capabilities:

| Component | Specification |
| :--- | :--- |
| **Driver Implementation** | **ReSukiSU** (commit `f1dd81dc96d7f3f6691e6ac8b50fba9ae8a2f17c`, version code `35119`, version `v4.2.0-rc1`) |
| **Stealth Engine** | **SUSFS v2.3.0** (`#define SUSFS_VERSION "v2.3.0"`) |
| **Hook Type** | SuSFS Inline Hooks (zero compile warnings, no deprecated manual hook guards) |
| **Sub-options Enabled** | `SUS_PATH`, `SUS_MOUNT`, `SUS_KSTAT`, `SPOOF_UNAME`, `ENABLE_LOG`, `HIDE_KSU_SUSFS_SYMBOLS`, `SPOOF_CMDLINE_OR_BOOTCONFIG`, `OPEN_REDIRECT`, `SUS_MAP` |
| **Manager Support** | Full multi-manager support enabled (`CONFIG_KSU_MULTI_MANAGER_SUPPORT=y`) |

---

## 3. The One-Shot Patch System: `ResukiSU-SusFS.patch`

All code and configuration changes required to convert the vanilla Aqua V3.4 tree into the rooted ReSukiSU + SUSFS v2.3.0 kernel are captured in a self-contained unified patch:

**File:** `ResukiSU-SusFS.patch` (155 KB, 31 files modified, 3,599 insertions)

### Switching Between Vanilla and Rooted Builds

#### To Apply Root Subsystems (ReSukiSU + SUSFS v2.3.0):
```bash
# 1. Ensure the ReSukiSU driver exists at verified commit f1dd81dc:
[ ! -d KernelSU ] && git clone https://github.com/ReSukiSU/ReSukiSU KernelSU && git -C KernelSU checkout f1dd81dc

# 2. Apply the patch:
git apply ResukiSU-SusFS.patch
```

#### To Revert Back to Pure Vanilla Aqua V3.4:
```bash
git apply -R ResukiSU-SusFS.patch
# Or: git checkout .
```

---

## 4. Compiler Toolchain & Crucial Build Flags

- **Target Toolchain:** **ZyC Clang 22.0.0** (`LLD 22.0.0`, commit `ebfee327df69e6cfeaa4c5300e6abd19476b8bfe`).
- **Cross-Compilers:** `aarch64-linux-gnu-` (ARM64) and `arm-linux-gnueabi-` (ARM32 VDSO).

> [!CRITICAL]
> **ThinLTO Linker Variable Trap:**
> Linux 4.14 `Makefile` includes `scripts/Kbuild.include` at line 280 before setting `LD = ld.lld` at line 388. Under `CONFIG_LTO_CLANG`, `$(ld-name)` evaluates to `bfd`, forcing `LD := $(CROSS_COMPILE)ld.gold` (which does not exist) and causing `/bin/sh: -EL: not found`.
> **You MUST always pass `LD="ld.lld"` to `make`:**
> `make ... CC="ccache clang" LD="ld.lld" LLVM=1 LLVM_IAS=1 ...`

---

## 5. Build Commands

### Quick Automated Build (`build.sh`)
```bash
# Pure Vanilla Aqua V3.4
./build.sh

# Rooted (ReSukiSU + SUSFS v2.3.0)
./build.sh --with-ksu

# Clean build
./build.sh --clean
```

### Manual Build Instructions
```bash
export PATH="$HOME/toolchains/ZyC-clang-22.0.0/bin:$PATH"

# 1. Configure
make O=out ARCH=arm64 everpal_defconfig

# 2. Compile
make -j$(nproc) O=out \
    ARCH=arm64 \
    CC="ccache clang" \
    LD="ld.lld" \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    KCFLAGS="-Wno-error=default-const-init-var-unsafe" \
    Image.gz dtbs
```

---

## 6. Packaging & Flashable Outputs

1. **AnyKernel3 Zip:**
   - Package `out/arch/arm64/boot/Image.gz` with AnyKernel3 template targeting partition `boot`.
2. **Flashable Signed Boot Image (`boot.img`):**
   - Unpack base stock boot image (`Project_Infinity-X-3.12.img` / Android 16 base, header version 2).
   - Repack kernel using `mkbootimg.py` and re-sign with `avbtool.py add_hash_footer --algorithm SHA256_RSA2048`.
