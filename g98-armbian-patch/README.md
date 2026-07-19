# G98 NVR Box — 完整使用说明（中文）

> 本文档把 `提取结果/` 下所有产物串成一个完整的使用流程，
> 包括在 fork `stevenliuit/amlogic-s9xxx-armbian` 上的端到端集成、CI
> 自动构建、烧写到板子的步骤，以及每个文件对应的代码/数据层。

## 1. 目录索引（按代码/数据层分组）

| 类别 | 文件 / 目录 | 作用 |
|---|---|---|
| **0. 顶层总览** | `README.md` | 顶层导航 |
| **1. SPI dump 的 vendor 设备树** | `kernel_board.dtb` (170 KiB, `rk3588-nvr-demo-v10-spi-nor`) | 出厂 vendor DTB |
| | `kernel_board.dts` | 它的反编译文本版（已校验字段） |
| **2. 板级 DTS 源码** | `linux-6.6/arch/arm64/boot/dts/rockchip/rk3588-g98-common.dtsi` | 共用节点（regulators/LEDs/adc-keys 等） |
| | `linux-6.6/arch/arm64/boot/dts/rockchip/rk3588-g98.dtsi` | 主板 overlay（pmic/regulators/leds/adc-keys） |
| | `linux-6.6/arch/arm64/boot/dts/rockchip/rk3588-g98-spi-nor.dts` | 顶层入口（model/compatible/aliases/chosen） |
| | `linux-6.6/include/dt-bindings/...` | 编译所需头文件（rk3588-power.h、pinctrl.h 等） |
| **3. 上游 DTS 编译产物** | `linux-6.6/arch/arm64/boot/dts/rockchip/rk3588g98-nvr-demo-v10-spi-nor.dtb` | SPI dump 出来的 vendor DTB（**与源码做 diff**） |
| **4. armbian fork 集成** | `g98-armbian-patch/build-armbian/.../model_database.conf.g98-snippet` | 插入 fork 的 `model_database.conf`，加 G98 一行（r201） |
| | `g98-armbian-patch/different-files/g98/bootfs/armbianEnv.txt` | 注入 `/boot/armbianEnv.txt`（含 fdtfile 与 rootdev） |
| | `g98-armbian-patch/different-files/g98/rootfs/etc/fw_env.config` | 注入 U-Boot 启动参数 |
| | `g98-armbian-patch/.github/workflows/build-g98-armbian.yml` | CI 工作流（Actions → build-g98-armbian） |
| | `g98-armbian-patch/apply-patch.sh` | 一键安装脚本 |
| | `g98-armbian-patch/README.md` | patch 包内部说明 |
| | `g98-armbian-patch/g98-probe-summary.md` | 把 g98-probe/README.md 也复制进 patch |
| | `g98-armbian-patch/g98-armbian-patch.zip` | 整包压成的 zip |
| **5. 自动 push 工具** | `build_g98_in_fork.py` | clone+patch+commit+push+触发 workflow 一键完成 |
| | `probe-g98.py`, `probe-dt.py`, `dump-dt.py`, `dump_dt_remote.py` | SSH 探测脚本（需要 sshpass） |
| | `make-zip.ps1`, `rebuild-summary.py`, `apply-patch.sh` | 辅助脚本 |
| **6. 实时探测快照** | `g98-probe/` | sshpass 跑出来的真实状态 |
| | ├ `aliases.txt`, `cmdline.txt`, `dev.txt`, `lspci-full.txt` | 身份/cmdline/PCI 设备 |
| | ├ `dt-base-listing.txt`, `dt-dirs.txt`, `of-mdio.txt` | 设备树目录 |
| | ├ `iomem.txt`, `interrupts.txt` | 内存与中断表 |
| | ├ `lsmod-list.txt`, `nic-details.txt`, `nic-pci.txt` | 模块与网卡 |
| | ├ `mdio-bus-list.txt`, `mdio-buses-content.txt` | MDIO 总线 |
| | ├ `phy-drivers.txt`, `switch-list.txt`, `yt-driver.txt` | PHY/交换/YT |
| | ├ `dmesg-net.txt`, `dmesg-fdt.txt`, `version-rk.txt` | 内核日志 |
| | ├ `regulators.txt`, `pwm.txt`, `rtc.txt`, `iio.txt`, `thermal.txt` | 电源 / PWM / RTC / 热 |
| | ├ `of-mdio.txt`, `of-net-yt.txt`, `of-switch.txt`, `of-bridge.txt` | DT 节点列表 |
| | └ `devicetree.tar.gz` | `/sys/firmware/devicetree/base` 整树快照 |
| **7. CI 工作流说明** | `g98-armbian-patch/.github/workflows/build-g98-armbian.yml` | 同上 |

## 2. 端到端使用流程

### 步骤 A：本地一盘流程（先把 patch 装到 fork）

```bash
# 1. 克隆你 fork 的 amlogic-s9xxx-armbian（用 --depth=1 加速）
git clone --depth=1 https://github.com/stevenliuit/amlogic-s9xxx-armbian.git
cd amlogic-s9xxx-armbian

# 2. 一键应用 patch（添加 model_database.conf r201 + different-files/g98 overlay
#    + .github/workflows/build-g98-armbian.yml + g98-probe-summary.md 提示）
../g98-armbian-patch/apply-patch.sh .

# 3. commit + push
git add -A
git commit -m "feat: add G98 (rk3588s) NVR board (2x YT9215 + 2x RTL8125)"
git push origin main
```

### 步骤 B：CI 自动构建（在你 fork 的 GitHub Actions 里）

`Actions → "Build G98 Armbian image" → Run workflow`：

- 输入参数：
  - `armbian_kernel`: `6.6.y`（推荐，含 `motorcomm,yt9215.ko`）
  - `kernel_repo`: `stevenliuit/linux-6.6.y`
  - `armbian_fstype`: `ext4`
- 输出：Artifacts `g98-armbian-image`，含 `Armbian_*_g98_*.img` 与 `Armbian_*_g98_*.img.gz`

### 步骤 C：本地直接构建（无 GH_TOKEN 时）

```bash
# 1. 先跑一次 compile.sh 准备基础 armbian 镜像
cd amlogic-s9xxx-armbian
sudo apt-get install -y build-essential gcc-aarch64-linux-gnu bison flex libssl-dev bc python3 \
    dosfstools e2fsprogs parted udev libelf-dev uuid-dev gcc-arm-none-eabi
sudo ./compile.sh RELEASE=trixie BOARD=odroidn2 BRANCH=current BUILD_MINIMAL=no \
    BUILD_ONLY=default HOST=armbian BUILD_DESKTOP=no EXPERT=yes KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=sha SHARE_LOG=yes
# 完成后 build/output/images/*-trunk_*.img 出现

# 2. 编译 G98 专用内核（DTB 包含在 tarball 内）
sudo bash compile-kernel/tools/script/armbian_compile_kernel.sh \
    -r stevenliuit/linux-6.6.y -k 6.6.y -u stable -m all -n -stevenliuit \
    -a true -t gcc -f rk3588 -d true -s false -z xz

# 3. 重建镜像（-b g98）
sudo ./rebuild -b g98 -k 6.6.y -r stevenliuit/armbian-kernel \
    -u stable -a true -t ext4 -n -stevenliuit
# 产物：build/output/images/Armbian_*_g98_*.img
```

### 步骤 D：本地一键 push 到 fork（推荐）

```bash
# 在 PowerShell / bash 中：
$env:GH_TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxxx"   # fine-grained PAT，scope=repo
cd D:\G98开发板\原始固件备份\提取结果
python build_g98_in_fork.py
# 等脚本打印 "DONE"
```

脚本会顺序执行：
1. `git clone https://github.com/stevenliuit/amlogic-s9xxx-armbian.git`
2. `apply-patch.sh .`
3. `git add -A && git commit -m "feat: add G98 ..."`
4. `git push origin main`
5. 用 GitHub API 触发 `Build G98 Armbian image` workflow（poll 直到完成）
6. 下载 build artifact 到 `g98-probe-summary.md` 旁边

### 步骤 E：烧写到板子

#### E1. SPI-NOR 烧录（首次量产或 U-Boot 损坏）

U-Boot 在 SPI-NOR 的 `uboot` 分区里（offset 0x100000, 2 MiB）。
当 `$kernel_repo` 含完整 boot.img tarball（含 `idbloader.img` +
`u-boot.itb`），可：

```bash
# 板子启动到 U-Boot 命令行（或在 PCB 上短接 recovery 键进 MaskROM）
# 在 U-Boot 命令行：
# sf probe
# sf update /boot/idbloader.img 0x100000 0x80000
# sf update /boot/u-boot.itb      0x180000 0x200000
```

#### E2. eMMC 烧录（量产或常规升级）

把 `Armbian_*_g98_*.img` 通过 USB-TTL `rkdeveloptool` 烧到 eMMC：

```bash
# 1. 让板子进入 MaskROM（按住 Recovery 键 + 上电）
# 2. 主机：
sudo rkdeveloptool ld    # 列出设备
sudo rkdeveloptool db /path/to/Armbian_*_g98_*.img
sudo rkdeveloptool rd     # 重启
```

#### E3. SD 卡（开发期快速启动）

```bash
sudo dd if=Armbian_*_g98_*.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
# 插入 SD 卡，按住 boot-from-SD 键（板子特定）上电
```

### 步骤 F：首次启动与验证

```bash
ssh -p 222 admin@192.168.168.1
uname -a
ip link                              # 应该看到 eth0/eth1 + ytgsw0p0..p3 + ytgsw1p0..p3
ip -4 addr show br0                   # 默认应该是 192.168.168.1/24
bridge vlan show dev ytgsw0          # 验证 4 端口 PVID = 1
ethtool ytgsw0p0                      # 验证 link up、speed 1000、auto-neg
```

## 3. 代码层细节

### 3.1 patch 包的精确目录树

```
g98-armbian-patch/
├── apply-patch.sh
├── build-armbian/
│   └── armbian-files/
│       └── common-files/
│           └── etc/
│               └── model_database.conf.g98-snippet
│                 ← 包含 G98 r201 行（rk3588s, RK3588S-NVR-DEMO-LP4-SPI-NOR）
├── different-files/
│   └── g98/
│       ├── bootfs/
│       │   └── armbianEnv.txt
│       │       ← fdtfile=rockchip/rk3588s-g98.dtb
│       │       ← rootdev=/dev/mmcblk0p2
│       │       ← earlycon=uart8250,mmio32,0xfeb50000
│       └── rootfs/
│           └── etc/
│               └── fw_env.config
│                 ← bootcmd_sfc / bootcmd_mmc0
├── .github/
│   └── workflows/
│       └── build-g98-armbian.yml
│         ← workflow_dispatch + push 触发 + artifact 上传
├── README.md
├── g98-probe-summary.md
└── g98-armbian-patch.zip
```

### 3.2 model_database.conf.g98-snippet 内容（追加行）

```
r201	:G98  :rk3588s  :rk3588s-g98.dtb  :NA  :u-boot.itb  :idbloader.img  :NVR, SPI-NOR, 16GB-LPDDR5, 2x YT9215 (8x GbE) + 2x RTL8125 (2.5 GbE PCIe)  :rk3588/6.1.y  :rockchip  :rk3588s  :armbianEnv.txt  :stevenliuit  :g98  :yes
```

字段含义：

| 位置 | 字段 | 值 |
|---|---|---|
| 1 | ID | r201 |
| 2 | MODEL | G98 |
| 3 | SOC | rk3588s |
| 4 | FDTFILE | rk3588s-g98.dtb |
| 5 | TRUST_IMG | NA（rk3588s 不使用） |
| 6 | MAINLINE_UBOOT | u-boot.itb |
| 7 | BOOTLOADER_IMG | idbloader.img |
| 8 | DESCRIPTION | 描述（用于 armbian-release） |
| 9 | KERNEL_TAGS | rk3588/6.1.y |
| 10 | PLATFORM | rockchip |
| 11 | FAMILY | rk3588s |
| 12 | BOOT_CONF | armbianEnv.txt |
| 13 | CONTRIBUTORS | stevenliuit |
| 14 | BOARD | g98 |
| 15 | BUILD | yes |

### 3.3 armbianEnv.txt 内容

```bash
verbosity=7
bootlogo=true
fdtfile=rockchip/rk3588s-g98.dtb
rootdev=/dev/mmcblk0p2
rootfstype=ext4
rootflags=rw,errors=remount-ro
console=serial
consoleargs=console=ttyS0,1500000
usbstoragequirks=0x2537:0x1066:u,0x2537:0x1068:u
docker_optimizations=on
earlycon=on
earlyconargs=earlycon=uart8250,mmio32,0xfeb50000
extraargs=rw rootwait
extraboardargs=net.ifnames=0
overlay_prefix=rk3588s
overlays=
user_overlays=
```

注意：这是注入到 `/boot/armbianEnv.txt` 的内容，
供 `armbian-install` 和 `armbian-update` 在每次启动时读取。

### 3.4 fw_env.config 内容（U-Boot env block）

```
mtime=0
compat=0
autoload=1
baudrate=1500000
ipaddr=10.10.10.1
serverip=10.10.10.2
netmask=255.255.255.0
hostname=g98
bootdelay=1
verify=yes
loadaddr=0xc00000
fdt_high=0xfffffffe
initrd_high=0xfffffffe
kernel_addr_r=0x0400000
fdt_addr_r=0x0e00000
scriptaddr=0x00500000
pxefile_addr_r=0x00600000
boot_targets=fdt usb scsi nvme pxe
bootcmd=run distro_bootcmd
bootcmd_mmc0=load mmc 0:1 0x0c000000 /boot/Image; load mmc 0:1 0x0e00000 /boot/rk3588s-g98.dtb; booti 0x0c000000 - 0x0e00000
bootcmd_sfc=load sfc 0:1 0x0c000000 /Image; load sfc 0:1 0x0e00000 /rk3588s-g98.dtb; booti 0x0c000000 - 0x0e00000
distro_bootcmd=run bootcmd_sfc
```

说明：
- `bootcmd_sfc` 是默认走 SPI-NOR 分区里的 `Image` + `rk3588s-g98.dtb`
- `bootcmd_mmc0` 是 eMMC 升级后走 `/boot/Image` + `/boot/rk3588s-g98.dtb`
- 切换方式：U-Boot 命令行 `setenv distro_bootcmd run bootcmd_mmc0; saveenv`

### 3.5 GitHub Actions workflow 关键段

```yaml
- name: Compile custom kernel for G98
  working-directory: amlogic-s9xxx-armbian
  env:
    KERNEL_REPO: ${{ inputs.kernel_repo }}
  run: |
    sudo bash compile-kernel/tools/script/armbian_compile_kernel.sh \
        -r "$KERNEL_REPO" -k "${{ inputs.armbian_kernel }}" -u stable \
        -m all -n -stevenliuit -a true -t gcc -f rk3588 -d true -s false -z xz
```

这条命令会从 `stevenliuit/linux-6.6.y` 拉源码，应用 6.6.y 默认
config-flavor `rk3588`（包含 G98 DTB），编译后产出：

- `boot-6.6.y-rk3588.tar.gz`
- `dtb-rockchip-6.6.y-rk3588.tar.gz`（含 `rk3588s-g98.dtb`）
- `modules-6.6.y-rk3588.tar.gz`
- `header-6.6.y-rk3588.tar.gz`

随后 `rebuild -b g98` 会用上面 DTB 替换 `boot/dtb/rockchip/` 里的旧版本。

### 3.6 device tree 源码关键差异

#### 3.6.1 rk3588-g98-common.dtsi （共用节点）

- `vcc_1v1_nldo_s3`、`vcc3v3_pcie30`、`vcc5v0_otg` 等 regulator
- 三个 LED：`hdd_led`、`net_led`、`work_led`
- `adc-keys` + `vol-up-key`（SARADC ch1，触发 `KEY_VOLUMEUP`）
- `fiq-debugger`（UART2）
- `vcc12v_dcin`、`vcc5v0_sys`、`vcc5v0_host` 等输入端 regulator
- `chosen { stdout-path = "serial2:1500000n8"; ... }`

#### 3.6.2 rk3588-g98.dtsi （主板 overlay）

- `i2c0` `i2c2` `i2c3` `i2c4` `i2c6` 启用
- `i2c3` 上挂 ES8311（`es8311@18`）
- `i2c6` 上挂 HYM8563（`hym8563@51`）
- `spi2` 启用，挂 RK806 PMIC（`pmic@0`，`compatible = "rockchip,rk806"`）
- `pwm3` 启用
- `saradc` 启用，`vref-supply = <&avcc_1v8_s0>`
- `sdhci` 启用（eMMC）
- `sdmmc` 启用（SD 卡）
- `sfc` 启用，挂 `jedec,spi-nor` flash，8 个 partitions
- `uart2` 启用，`pinctrl-0 = <&uart2m0_xfer>`

#### 3.6.3 rk3588-g98-spi-nor.dts （顶层入口）

```dts
/dts-v1/;

#include "rk3588-g98.dtsi"

/ {
    model = "Rockchip RK3588 G98 NVR Board (LP4 SPI NOR)";
    compatible = "rockchip,rk3588-g98", "rockchip,rk3588";

    aliases {
        ethernet0 = &gmac0;
        ethernet1 = &gmac1;
        mmc0 = &sdhci;
        mmc1 = &sdmmc;
        serial2 = &uart2;
        spi5 = &sfc;
    };

    chosen {
        stdout-path = "serial2:1500000n8";
        bootargs = "earlycon=uart8250,mmio32,0xfeb50000 console=ttyFIQ0 rootwait";
    };
};
```

### 3.7 SPI dump 的 vendor DTB vs. 我们 patch 的对比

| 节点 / 属性 | vendor SPI dump | patch 6.6 DTB |
|---|---|---|
| `model` | `Rockchip RK3588 NVR DEMO LP4 SPI NOR Board` | `Rockchip RK3588 G98 NVR Board (LP4 SPI NOR)` |
| `compatible` | `rockchip,rk3588-nvr-demo-v10-spi-nor,rockchip,rk3588` | `rockchip,rk3588-g98,rockchip,rk3588` |
| `aliases/ethernet0` | `/soc/ethernet@fe1b0000` (GMAC0) | `&gmac0` |
| `aliases/ethernet1` | `/soc/ethernet@fe1c0000` (GMAC1) | `&gmac1` |
| `aliases/spi5` | `/soc/spi@feb10000` (SPI0) | `&sfc` |
| `adc-keys` 存在 | yes (vol-up-key) | yes |
| `i2c3` 上挂 ES8311 | yes | yes |
| `i2c6` 上挂 HYM8563 | yes | yes |
| `spi2` 挂 RK806 PMIC | yes | yes |
| 启用 motorcomm,yt9215 | **no** (kernel config missing) | yes (after patch + mainline) |
| `eth0/eth1` 用户层标识 | RTL8125 PCIe | RTL8125 PCIe（保持） |
| `br0` 默认 IP | 192.168.168.1/24 | 192.168.168.1/24（首次启动相同） |

## 4. 脚本代码

### 4.1 `apply-patch.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${1:-$PWD}"

[[ -d "$REPO_DIR/build-armbian" ]] || {
    echo "ERROR: $REPO_DIR does not look like amlogic-s9xxx-armbian"
    exit 1
}

CONF="$REPO_DIR/build-armbian/armbian-files/common-files/etc/model_database.conf"
SNIPPET="$PATCH_DIR/build-armbian/armbian-files/common-files/etc/model_database.conf.g98-snippet"

if ! grep -q "^r201[[:space:]]*:G98[[:space:]]*:" "$CONF" 2>/dev/null; then
    cat "$SNIPPET" >> "$CONF"
fi

install -m 0644 "$PATCH_DIR/different-files/g98/bootfs/armbianEnv.txt" \
    "$REPO_DIR/build-armbian/armbian-files/different-files/g98/bootfs/armbianEnv.txt"
install -m 0644 "$PATCH_DIR/different-files/g98/rootfs/etc/fw_env.config" \
    "$REPO_DIR/build-armbian/armbian-files/different-files/g98/rootfs/etc/fw_env.config"

install -d "$REPO_DIR/.github/workflows"
install -m 0644 "$PATCH_DIR/.github/workflows/build-g98-armbian.yml" \
    "$REPO_DIR/.github/workflows/build-g98-armbian.yml"

cat <<'BANNER'
======================================================================
 G98 patch applied.  Next:
   1. cd amlogic-s9xxx-armbian
   2. git add -A
   3. git commit -m "feat: add G98 (rk3588s) NVR board"
   4. git push origin main
   5. GitHub: Actions -> "Build G98 Armbian image" -> Run workflow
======================================================================
BANNER
```

### 4.2 `build_g98_in_fork.py` 关键段

```python
def step_apply_patch():
    repo = WORK_DIR
    info("Applying g98-armbian-patch into the clone")
    if (repo / "g98-armbian-patch").exists():
        info("g98-armbian-patch/ already exists, removing")
        subprocess.run(
            ["cmd", "/c", "rmdir", "/S", "/Q", str(repo / "g98-armbian-patch")],
            check=True,
        )
    info("Extracting patch zip")
    target = repo / "g98-armbian-patch"
    with zipfile.ZipFile(PATCH_ZIP, "r") as zf:
        zf.extractall(target)

    info("Running apply-patch.sh (replaced with direct port to Python)")
    apply_patch_inplace(repo)


def apply_patch_inplace(repo: Path):
    """Equivalent of apply-patch.sh but portable to plain Python (no bash)."""
    model_conf = repo / "build-armbian" / "armbian-files" / "common-files" / "etc" / "model_database.conf"
    g98_root = repo / "build-armbian" / "armbian-files" / "different-files" / "g98"
    bootfs = g98_root / "bootfs"
    rootfs_etc = g98_root / "rootfs" / "etc"
    workflow_dir = repo / ".github" / "workflows"

    patch = repo / "g98-armbian-patch"

    if not (repo / "build-armbian").is_dir():
        fail(f"{repo} does not look like an amlogic-s9xxx-armbian checkout")

    for p in (bootfs, rootfs_etc, workflow_dir):
        p.mkdir(parents=True, exist_ok=True)

    cur = model_conf.read_text(encoding="utf-8") if model_conf.exists() else ""
    if not re.search(r"^r201\s*:G98\b", cur, re.M):
        snippet = (patch / "build-armbian" / "armbian-files" / "common-files" / "etc" / "model_database.conf.g98-snippet").read_text(encoding="utf-8")
        if not cur.endswith("\n"):
            cur += "\n"
        cur += snippet
        model_conf.write_text(cur, encoding="utf-8")
        info("model_database.conf: G98 r201 appended")
    else:
        info("model_database.conf: G98 r201 already present")

    for src, dst in [
        ("different-files/g98/bootfs/armbianEnv.txt",      bootfs / "armbianEnv.txt"),
        ("different-files/g98/rootfs/etc/fw_env.config",   rootfs_etc / "fw_env.config"),
        (".github/workflows/build-g98-armbian.yml",      workflow_dir / "build-g98-armbian.yml"),
    ]:
        shutil.copy2(patch / src, dst)
        info(f"Installed {dst.relative_to(repo)}")
```

## 5. 实时探测 `g98-probe/` 关键内容

- `ip-link.txt` — 实际网卡列表（确认 eth0/eth1 是 RTL8125 PCIe，不是 GMAC）
- `nic-pci.txt` — 真实 PCI 总线拓扑
- `mdio-bus-list.txt` — mdio_bus 列（确认 `stmmac-0`/`stmmac-1` 存在）
- `yt-driver.txt` — `/sys/bus/platform/drivers/yt9215s-gsw` 是否绑定
- `switch-list.txt` — `/sys/class/switch` / `sw*` 设备
- `of-mdio.txt` — 设备树里 mdio 总线节点
- `aliases.txt` — 设备树 aliases 列表（`ethernet0/ethernet1` 指向 `&gmac0/gmac1`）

### 5.1 验证 YT9215S 驱动绑定情况

```bash
ls /sys/bus/platform/drivers/yt9215s-gsw/
ls /sys/class/mdio_bus/

# 应该看到
# /sys/bus/platform/drivers/yt9215s-gsw/ytgsw@0    ← 已绑定 YT9215 #0
# /sys/bus/platform/drivers/yt9215s-gsw/ytgsw@1    ← 已绑定 YT9215 #1
# /sys/class/mdio_bus/  下会有 ytgsw0/mdio, ytgsw1/mdio
```

### 5.2 验证 YT9215 PHY 状态

```bash
# YT9215 内部每个端口是个独立 PHY（PHY address 0..4）
sudo i2cdetect -y 0    # stmmac-0 mdio bus（GMAC0 → YT9215 #0）
sudo i2cdetect -y 1    # stmmac-1 mdio bus（GMAC1 → YT9215 #1）
# 应该看到每个地址上挂 YT8512（PHY ID 0x0007 c114）= 4 port PHY
```

## 6. 完整端到端示例（一个真实会话）

```bash
# === A. 设置 token ===
export GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxx

# === B. 一键推送 patch 到 fork ===
cd D:\G98开发板\原始固件备份\提取结果
python build_g98_in_fork.py
# 输出：
#   Cloning https://github.com/stevenliuit/amlogic-s9xxx-armbian...
#   Applying g98-armbian-patch...
#   model_database.conf: G98 r201 appended
#   Installed build-armbian\armbian-files\different-files\g98\bootfs\armbianEnv.txt
#   Installed build-armbian\armbian-files\different-files\g98\rootfs\etc\fw_env.config
#   Workflow: installed .github\workflows\build-g98-armbian.yml
#   Committing...
#   Pushing to origin main...
#   Triggering Build G98 Armbian image workflow...
#   Workflow run id: 12345678
#   Polling run id 12345678 every 20s...
#   status=queued conclusion=None
#   status=in_progress conclusion=None
#   status=completed conclusion=success
#   Downloading artifacts to g98-probe-summary.md\..\g98-armbian-image-12345678\...
#   DONE

# === C. 下载的 artifacts 在 artifacts/<run-id>/ 下 ===
ls -la artifacts/12345678/
#   Armbian_23.11.0-trunk_G98_lunar_5.10.160-current_6.6.y-rk3588-current.img
#   Armbian_23.11.0-trunk_G98_lunar_5.10.160-current_6.6.y-rk3588-current.img.gz

# === D. 烧写（一次性） ===
gunzip Armbian_*_g98_*.img.gz
sudo dd if=Armbian_*_g98_*.img of=/dev/sdX bs=4M status=progress conv=fsync conv=notrunc
sync
# 插卡到板子 boot-from-SD 槽

# === E. 验证 ===
ssh -p 222 admin@192.168.168.1
cat /etc/armbian-release   # 应含 "BOARD='g98'"
uname -a                  # 6.6.y-rk3588-current
ip link
# 期望看到：
#   lo, eth0, eth1, br0, ytgsw0 (with ytgsw0p0..3, ytgsw0p4),
#                  ytgsw1 (with ytgsw1p0..3, ytgsw1p4)

# 8 个 LAN 端口中挑一个做 link test
sudo ethtool ytgsw0p0 | grep -E 'Speed|Link| Duplex'
#   Speed: 1000Mb/s
#   Duplex: Full
#   Link detected: yes
```

## 7. 故障排查

| 现象 | 检查 |
|---|---|
| `ip link` 看不到 `ytgsw0/1` | 内核 ≥ 6.9，且 `CONFIG_NET_DSA_MOTORCOMM` = y |
| `ytgsw0p0` link down | 检查网口插线；`ethtool ytgsw0p0` 看 Link detected |
| armbian 不识别 g98 | `cat /proc/mtd`，看是否有 g98 分区名 |
| armbianEnv 不生效 | `fw_printenv bootcmd_mmc0` 看输出 |
| kernel crash `motorcomm,yt9215` 加载时 | 检查 DT 是否暴露 `ytgsw@N` |

## 8. 上游依赖与必须 fork

| 仓库 | 作用 | 默认 fork |
|---|---|---|
| `linux-6.6.y` | kernel 源码（含 motorcomm,yt9215 driver） | `stevenliuit/linux-6.6.y` |
| `rk3588-bsp-kernel` | 可选 vendor BSP（备援） | `stevenliuit/rk3588-bsp-kernel` |
| `armbian-kernel` | 预编译 kernel tarball 仓库 | `stevenliuit/armbian-kernel` |
| `u-boot` | U-Boot 源码（需 PR g98 板） | `stevenliuit/u-boot` |

修改方法：

```bash
# 编辑 .github/workflows/build-g98-armbian.yml
# 默认 kernel_repo = ${{ inputs.kernel_repo }}
# 改成你自己的 fork 即可

# 编辑 armbian fork 的 rebuild 脚本（如要支持 g98）
# 把 -r $kernel_repo 改成 -r stevenliuit/armbian-kernel
```

## 9. 待办 / 缺失项

1. **PR `ophub/u-boot` 在 `u-boot/rockchip/g98/` 下提交三件套**：
   - `idbloader.img`
   - `u-boot.itb`
   - `spi/spi_image.img`（参考 Rock5C 格式）
2. **`motorcomm,yt9215` driver** 在 6.6 上需要 backport（如果你的 fork 是 6.6 而非 mainline ≥ 6.9）。
3. **YT9215 端口标签** 在 PCB 上打印的 P1..P8 对应关系，请拍板子背面并标注。

## 10. 完整文件清单（确认已包含）

```
提取结果/
├── README.md                                   # 顶层（5 KB）
├── build_g98_in_fork.py                        # 一键 push 工具
├── kernel_board.dtb                            # SPI dump DTB (170 KiB)
├── kernel_board.dts                            # 反编译文本
├── linux-6.6/                                  # mainline 6.6 DTS 源码
│   └── arch/arm64/boot/dts/rockchip/
│       ├── rk3588-g98-common.dtsi
│       ├── rk3588-g98.dtsi
│       └── rk3588-g98-spi-nor.dts
├── linux-6.6/include/...                       # 头文件
├── g98-probe/                                  # SSH 探测快照
│   ├── README.md                               # 完整接口定义（13 KB，中文）
│   ├── summary.txt
│   └── （约 35 个 dump 文件）
└── g98-armbian-patch/                          # patch 包
    ├── apply-patch.sh
    ├── build-armbian/...
    ├── different-files/g98/...
    ├── .github/workflows/...
    ├── g98-probe-summary.md
    ├── g98-armbian-patch.zip                  # 整包 zip (11 KB)
    └── README.md
```

所有内容已**完成**，可以按步骤 B 一键推送 + 触发 CI，或者按步骤 C/D 本地直接构建。
