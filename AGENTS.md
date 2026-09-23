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

### Companion Patch: `Branding.patch`

Product identity (Fronx) lives in a second one-shot patch so vanilla stays Addster-clean:
- **Content:** `Makefile` `EXTRAVERSION` → `-FronxKernel_$(FROnxDT)` (uname becomes `4.14.357-FronxKernel_<IST-stamp>`; empty without the var). AnyKernel `kernel.string` is rebranded by `build.sh` via `sed` (template is cloned fresh, so no patch can cover it).
- **Credits:** Addster + Goku credit lines are NEVER renamed — only product identity. See §10 for why each release matters.
- **Same rules as §8:** regenerate via apply → edit → `git diff`, round-trip proof, revert after build. Apply order with the KSU patch: KSU first, branding last; revert in reverse.

### Switching Between Vanilla and Rooted Builds

#### To Apply Root Subsystems (ReSukiSU + SUSFS v2.3.0):
```bash
# 1. Ensure the ReSukiSU driver exists at verified commit f1dd81dc:
[ ! -d KernelSU ] && git clone https://github.com/ReSukiSU/ReSukiSU KernelSU && git -C KernelSU checkout f1dd81dc

# 2. Apply the patch (.gitignore hunks are pre-kept in-tree, so exclude it):
git apply --exclude=.gitignore ResukiSU-SusFS.patch
```

#### To Revert Back to Pure Vanilla Aqua V3.4:
```bash
git apply -R --exclude=.gitignore ResukiSU-SusFS.patch
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
# Pure Vanilla Aqua V3.4 (+ Fronx branding, reverted after)
./build.sh                                # → FronxKernel-<ver>_<IST>.zip

# Rooted (ReSukiSU + SUSFS v2.3.0 + branding, reverted after)
./build.sh --with-ksu                     # → FronxKernel_ResukiSU_SusFS-<ver>_<IST>.zip

# Clean build
./build.sh --clean
```
Version comes from the `VERSION` file (current: `1.0`, bump per release); timestamps are IST, one stamp shared by all artifacts of a run. `build.sh` applies patches pre-build and reverts to vanilla post-build automatically.

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

---

## 7. Merging Addster's Latest Upstream Changes

> **Principle:** upstream is never blocked, vetoed, or cherry-avoided. Whatever Addster (or anyone) creates gets merged — our patch file absorbs ALL adaptation. If an upstream change breaks patch application, we fix OUR patch at merge time, never the other way around. This is what enforces the phase discipline for every agent working here.

The vanilla-default model makes upstream syncs trivial: our root customizations live in normal commits on a vanilla base, and all root-related code lives in `ResukiSU-SusFS.patch`. Syncing Addster never requires untangling hand-ported KSU commits.

**Remotes:** `addster` = Addster09 (upstream), `frontlxox` = our fork (push target), `origin` = himanshuksr0007 (Goku, legacy — do not push here).

```bash
# 0. Start from a clean vanilla tree (non-negotiable):
git status --short          # must be empty
ls fs/susfs.c               # must NOT exist
grep -c CONFIG_KSU arch/arm64/configs/everpal_defconfig   # must print 0

# 1. Fetch and integrate upstream (prefer merge to preserve history):
git fetch addster
git merge addster/lineage-24.0-old   # or cherry-pick specific commits

# 2. Re-apply our root layer on top:
git apply --exclude=.gitignore ResukiSU-SusFS.patch
# If any hunk fails: resolve by hand in the worktree, then REGENERATE
# the patch file per §8 (never leave a half-applied tree committed).

# 3. Validate both flavors before pushing:
./build.sh                  # vanilla must compile, Image.gz must boot
./build.sh --with-ksu       # KSU build log must show all hooks found, zero "build maybe broken" warnings
git apply -R --exclude=.gitignore ResukiSU-SusFS.patch   # back to vanilla
git status --short          # must be empty again
git push frontlxox lineage-24.0
```

---

## 8. Making Our Own Changes (Two Classes, Never Mixed)

- **Class V (vanilla-safe):** device tree, drivers, vanilla defconfig lines, `build.sh`, docs. Work directly on the vanilla tree and commit normally: `git commit -m "🦋 [FEAT]: ..."`.
- **Class R (root-related):** anything under `CONFIG_KSU`/`CONFIG_SUSFS`, hook call sites, KSU defconfig block, driver pin. These MUST go into `ResukiSU-SusFS.patch`, never as direct tree commits.

**Regenerating the patch file after Class-R edits:**
```bash
# From clean vanilla HEAD:
git apply --exclude=.gitignore ResukiSU-SusFS.patch
# ... make your Class-R edits in the worktree ...
git add -A
git diff --cached -- . ':!ResukiSU-SusFS.patch' ':!.gitignore' > /tmp/new.patch
mv /tmp/new.patch ResukiSU-SusFS.patch
# Prove round-trip before committing:
git apply -R --exclude=.gitignore ResukiSU-SusFS.patch   # back to vanilla
git apply --check --exclude=.gitignore ResukiSU-SusFS.patch  # must pass silently
git add ResukiSU-SusFS.patch && git commit -m "🦋 [FEAT]: update ResukiSU-SusFS.patch (<what changed>)"
# Also update the spec table in §2 (driver commit / SUSFS version / sub-options).
```

**Pre-commit gate (every commit, both classes):** `git status` shows only intended files; the tree ends in vanilla state (`ls fs/susfs.c` fails, defconfig KSU count is 0) unless the commit IS the documented vanilla-revert flow.

---

## 9. Version Bumps & Inviolable Rules

**Bumping the ReSukiSU driver pin** (current: `f1dd81dc`): `git -C KernelSU checkout <new-sha>`, rebuild KSU flavor, verify the `v4.2.0-rc1-<sha>@ReSukiSU` string in the image + `fastboot boot` test, then update the §2 table AND the checkout line in `build.sh` + §3. (`KernelSU/` itself is gitignored — the pin lives in these two files.)

**Bumping SUSFS** (current: `v2.3.0`): source a `-4.14`-compatible core, apply over the patched tree, regenerate the patch per §8, update §2.

**Rules:**
1. Default branch state is ALWAYS vanilla + clean status. No rooted/proot-applied state is ever committed.
2. `ResukiSU-SusFS.patch` is the single source of truth for the root layer — tree and file must never drift (prove with apply/revert round-trip after every regeneration).
3. `.gitignore` hunks stay pre-kept in-tree; always apply/revert with `--exclude=.gitignore`.
4. Always pass `LD="ld.lld"` (§4 trap) and test KSU images with `fastboot boot` before flashing.

---

## 10. Addster's Release History (What Each Version Did)

Source: release notes on `Addster09/android_kernel_xiaomi_mt6833`. Our baseline is **V3.4** (see §1). Use this as the map for future improvements — each entry notes what it unlocks next.

| Release | Date | Highlights | Future-work hooks |
| :--- | :--- | :--- | :--- |
| **V1.0** | 2025-11-13 | WireGuard in-tree; BORE scheduler; KSU Next v1.0.9 + SUSFS v1.5.2; ThinLTO; 4.19.323 backports; LZ4 v1.10.0 + faster decompression. Base: Sushrut1101 (+ proximity fixes). | BORE-vs-WALT A/B data point (V3.4 moved to WALT — compare scheduler behavior on everpal before touching scheduler code). |
| **V2.0** | 2025-12-04 | Rebased onto Sushrut base; KSU Next v1.1.1 + SUSFS v1.5.8; Cubic/BBR/Westwood TCP, BBR default (still current). | TCP-CC baseline settled — don't regress BBR default when touching net stack. |
| **V3.0** | 2026-03-26 | Multi-Gen LRU (MGLRU) + reclaim efficiency; Maple I/O scheduler (default — app-launch responsiveness); Clang Armv8.2 codegen (LSE/FP16/DotProd), built-in crypto/CRC, `-O3`; KSU Next v3.1.0 + SUSFS v2.0.0. | Maple default + MGLRU are load-bearing for memory feel — benchmark before/after any VM or block-layer change. |
| **V3.1** | 2026-04-19 | Clang 22 toolchain; merged `v4.14.357-openela`; GPU sysfs exposed (frequency control); GPU security patches; dropped MTK memtrack; ReSukiSU v4.1.0 + SUSFS v2.1.0. | GPU sysfs nodes are the EverpalTweaks thermal/GED interface — keep them stable. openela merge = security baseline; track future openela tags. |
| **V3.2** | 2026-05-08 | A76-targeted compiler opts; TCP-CC + BBR default re-affirmed; ARM64 crypto extensions; high-overhead debug trimmed. | Perf headroom mostly extracted here — further gains now come from scheduling/thermal, not flags. |
| **V3.3** | 2026-07-05 | Random-reboot fixes; frequency stability; ReSukiSU update + SUSFS v2.2.0; hotspot fix (PortEdition). | If reboots recur, `git log` V3.2→V3.3 first — the fix may already exist upstream. |
| **V3.4** | 2026-09-10 | **Our baseline.** input_suspend node (charge limiting); WALT enabled; 4.19 binder backport; Clang crypto/CRC/RCpc/RDM opts; statx attrs, clone3, cgroup-prio backports; ReSukiSU (f1dd81dc) + SUSFS v2.3.0. | Current frontier. Next candidates: newer openela merges, SUSFS updates (see §9), scheduler tunables around WALT. |

**How to use this table:** before starting any kernel improvement, find the release that last touched that subsystem and read its tag diff (`git log AquaVX..AquaVY -- <path>`) — prior art and prior fixes live there, not in chat history.

---

## 11. Phase-Wise Building (Per Session)

Follow phases in order. Each phase has an exit gate — do not proceed until it passes.

### Phase 0 — Preconditions
- Tree is vanilla + clean: `git status --short` empty, `ls fs/susfs.c` fails, defconfig KSU count is 0.
- Toolchain reachable (`build/toolchains/ZyC-clang-22.0.0/bin`), ccache warm, `KernelSU/` present at pinned commit (§2) for rooted builds.
- Patch integrity: `git apply --check --exclude=.gitignore ResukiSU-SusFS.patch` passes silently.
- **Gate:** all four checks green.

### Phase 1 — Vanilla Build
1. `make O=out ARCH=arm64 everpal_defconfig` (+ `--disable CONFIG_KSU` + `olddefconfig` if the tree carries KSU lines).
2. Full build with §5 flags (`LD="ld.lld"` mandatory, §4 trap).
3. Verify: `Linux version 4.14.357-Aqua` in image, **zero** KSU/SUSFS symbols.
- **Gate:** `Image.gz` (~17 MB) + exit 0. Package `AquaKernel-<ver>.zip` (AnyKernel3, no dtb).

### Phase 2 — Rooted Build
1. Apply patch (`--exclude=.gitignore`), `olddefconfig`, confirm `CONFIG_KSU=y` + `CONFIG_KSU_SUSFS=y`.
2. Incremental rebuild with §5 flags.
3. Verify: ReSukiSU version string matches §2 pin, SUSFS version string matches §2, all 7 hook checks `found` in log with **zero** "build maybe broken" warnings.
- **Gate:** `Image.gz` verified. Package `AquaKernel_ResukiSU_SusFS-<ver>.zip`.

### Phase 3 — Boot Image
1. Unpack PI-X base (`Project_Infinity-X-3.12.img`, header v2) → repack with new kernel, same ramdisk/dtb/cmdline → AVB `add_hash_footer` (testkey, unlocked bootloader only).
2. Verify by re-unpacking: kernel md5 matches, ramdisk/dtb byte-identical to base.
- **Gate:** 128 MB image + round-trip verification record.

### Phase 4 — Flash Validation (On Device)
1. Never flash untested images — `fastboot boot` first, stopwatch running: instant POCO-loop = pre-init panic (no adb ever); delayed loop = userspace/init failure.
2. On boot: `cat /proc/version`, `dmesg | grep -iE "kernelsu|susfs is initialized"`, `su` root check, `sconfig`, `dumpsys gpu` (Vulkan `4206592`), ZRAM.
- **Gate:** all checks pass. Only then flash + confirm second boot.

### Phase 5 — Close-Out
1. Revert to vanilla (`git apply -R --exclude=.gitignore`), confirm clean status.
2. Record artifacts + md5s in `out/REPORT.md`.
- **Gate:** tree vanilla + clean. Push `frontlxox` only from this state.

---

## 12. Phase-Wise Maintenance & Development (Ongoing)

### Phase 0 — Triage
Classify the work before touching anything: **upstream sync** (§7) / **Class-V change** / **Class-R change** (§8) / **version bump** (§9) / **release-history update** (§10). One class per commit — never mix.

### Phase 1 — Upstream Sync (§7)
Fetch `addster`, integrate onto vanilla base, re-apply patch, regenerate it if hunks drift. If Addster shipped a new release, add its §10 row from the GitHub release notes in the same commit window.

### Phase 2 — Development (§8)
Class-V commits directly; Class-R through the apply → edit → regenerate → revert → commit-file cycle with round-trip proof. Driver/SUSFS bumps per §9 (update §2 table + `build.sh` pin in the same commit).

### Phase 3 — Validation
Both flavors build clean (§11 Phases 1–2 abbreviated: version strings + hook-check log), KSU flavor passes Phase-4 device validation. No validation, no release.

### Phase 4 — Release
Name zips per convention, update benchmark compare URLs across docs on any new record, write release notes in Addster's format (subsystem sections + credits), tag `AquaVX.Y`, extend the §10 table.

### Phase 5 — Close-Out
Vanilla + clean tree, push `frontlxox`, update the EverpalTweaks superproject submodule pointer if it tracks this tree, record in `out/REPORT.md`.
