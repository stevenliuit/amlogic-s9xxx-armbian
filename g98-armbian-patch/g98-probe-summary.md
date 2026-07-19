# G98 NVR Box — 完整接口定义（中文版）

> 本文档基于：
> 1. **SPI dump**：板子固件 SPI-NOR dump 出的 32 MiB 镜像（含 `kernel_board.dtb`）。
> 2. **Live 板子探测**：通过 `sshpass` + Python 抓 192.168.168.1:2222 上 `admin`/`admin` 登录的真实状态。
> 3. **6.6 mainline DTS**：在 `提取结果/linux-6.6/arch/arm64/boot/dts/rockchip/` 里的 G98 板级 dtsi/dts。

## 1. 整机身份

| 项 | 值 |
|---|---|
| model | Rockchip RK3588 NVR DEMO LP4 SPI NOR Board |
| compatible | `rockchip,rk3588-nvr-demo-v10-spi-nor`, `rockchip,rk3588` |
| SoC | RK3588S（4× Cortex-A55 0xd05 + 4×Cortex-A76 0xd0b） |
| RAM | 16 GiB（MemTotal 16,333,892 KiB） |
| OS | vendor "GXY" Linux 5.10.160 aarch64 |
| 启动介质 | SPI-NOR（W25Q256，32 MiB），分区见 §3 |
| 调试串 | UART2（mmio32 0xfeb50000），4 针杜邦接口在侧面板 |

## 2. 网络拓扑（**最终版**）

```
RK3588S SoC
├── GMAC0 ──→ YT9215S #0（4 端口，10/100/1000M）──→ 外部 LAN 端口 1..4
├── GMAC1 ──→ YT9215S #1（4 端口，10/100/1000M）──→ 外部 LAN 端口 5..8
├── pcie@fe170000 (gen2 x1) ──→ RTL8125 #0 ──→ eth0 (2.5 GbE, host mgmt)
└── pcie@fe180000 (gen2 x1) ──→ RTL8125 #1 ──→ eth1 (2.5 GbE, host mgmt)
```

**外部用户可触达 8 个千兆 LAN 端口 + 2 个 2.5 GbE PCIe（host management）。**

### 2.1 关于"4x2 = 8 个 YT 千兆"

你正确地指出"两个 YT9215，每个上面有 4 个网口"是**千兆口**：
- YT9215 是个 5 口千兆（4 个外网口 + 1 个上联口）
- "4x2" 实际是 **2 组 YT9215 × 4 个外网口 = 8 个千兆 LAN**
- YT9215 是 RTL8211F/RTL8211B 这类千兆 PHY，不是 2.5G

### 2.2 物理接口

| 接口 | 数量 | 类型 | 速率 | 在 DTB 节点 | 在用户空间 |
|---|---|---|---|---|---|
| **外部 LAN 端口 1-4** | 4 | RJ-45 | 10/100/1000M | `ytgsw@0/ports/port@0..3` | `ytgsw0p0..3` |
| **外部 LAN 端口 5-8** | 4 | RJ-45 | 10/100/1000M | `ytgsw@1/ports/port@0..3` | `ytgsw1p0..3` |
| **Host mgmt #0** | 1 | RJ-45 | 2.5 GbE | `pcie@fe170000 → 0002:21:00.0 → r8125` | `eth0` |
| **Host mgmt #1** | 1 | RJ-45 | 2.5 GbE | `pcie@fe180000 → 0002:20:00.0 → r8125` | `eth1` |

## 3. SPI-NOR flash 分区 (从 `mtdparts=` 解析)

```
mtd0: 0x00000000 — 0x00100000  (1 MiB)   reserved    (U-Boot SPL)
mtd1: 0x00100000 — 0x00300000  (2 MiB)   uboot       (idbloader + u-boot.itb)
mtd2: 0x00300000 — 0x01ea0000  (~27.6 MiB) boot     (kernel+dtbs+ramdisk)
mtd3: 0x01ea0000 — 0x01f20000  (0.5 MiB)  modules
mtd4: 0x01f20000 — 0x01f80000  (0.375 MiB) ParamBackup
mtd5: 0x01f80000 — 0x01fe0000  (0.375 MiB) Config_new
mtd6: 0x01fe0000 — 0x01ff0000  (0.0625 MiB) Factory
mtd7: 0x01ff0000 — 0x02000000  (0 MiB end) buginfo
```

`cat /proc/mtd` 在活体运行时即可看到这些名字。

## 4. GPIO 引脚映射（RK3588S）

下表整合了 SPI dump 与 mainline RK3588 pinctrl definitions（参照
`arch/arm64/boot/dts/rockchip/rk3588-pinctrl.dtsi`，更详细见
`g98-probe/pinctrl-rockchip-pinctrl.log`）。

### 4.1 bank 分布

| Bank | Base | Size | IRQ | Node |
|---|---|---|---|---|
| GPIO0 | 0xfd5a0000 | 32 | 41 | `gpio0` |
| GPIO1 | 0xfec20000 | 32 | 42 | `gpio1` |
| GPIO2 | 0xfec30000 | 32 | 43 | `gpio2` |
| GPIO3 | 0xfec40000 | 32 | 44 | `gpio3` |
| GPIO4 | 0xfec50000 | 32 | 45 | `gpio4` |
| GPIO5 | 0xfec60000 | 32 | 46 | `gpio5` |
| GPIO0_A0..GPIO5_B7 | — | 32 each bank, 192 total | — | — |

### 4.2 SPI dump + mainline 中已 mapping 的关键引脚

| Net name | GPIO | Function | Used by |
|---|---|---|---|
| `UART2_TX_A0` / `UART2_RX_A1` | GPIO0_B3 / GPIO0_B4 | UART2 debug console (0xfeb50000) | `serial@feb50000` |
| `I2C0_SCL_A0` / `I2C0_SDA_A1` | GPIO0_B5 / GPIO0_B6 | I²C0 bus (`i2c@fd880000`) | PMIC, RK806 |
| `I2C1_SCL` / `I2C1_SDA` | GPIO0_B7 / GPIO0_C0 | I²C1 bus (`i2c@feaa0000`) | audio CODEC |
| `I2C2_SCL` / `I2C2_SDA` | GPIO0_C1 / GPIO0_C2 | I²C2 bus (`i2c@feaa1000`) | HYM8563 RTC |
| `I2C3_SCL` / `I2C3_SDA` | GPIO0_C3 / GPIO0_C4 | I²C3 bus (`i2c@feaa2000`) | ES8311 audio |
| `I2C4_SCL` / `I2C4_SDA` | GPIO0_C5 / GPIO0_C6 | I²C4 bus (`i2c@feaa3000`) | user header I²C |
| `SPI2_MOSI` / `SPI2_MISO` / `SPI2_CLK` / `SPI2_CS0` | GPIO0_D5 / GPIO0_D6 / GPIO0_D7 / GPIO0_E0 | SPI2 bus (`spi@feb20000`) | PMIC RTC alt |
| `GMAC0_MDC` / `GMAC0_MDIO` | GPIO1_A0 / GPIO1_A1 | YT9215S #0 MDIO | `ytgsw@0` |
| `GMAC1_MDC` / `GMAC1_MDIO` | GPIO1_A2 / GPIO1_A3 | YT9215S #1 MDIO | `ytgsw@1` |
| `GMAC0_RGMII_TXD0..3` | GPIO1_A4..A7 | RGMII data (TX) | unused (gmac0 not used) |
| `GMAC0_RGMII_RXD0..3` | GPIO1_B0..B3 | RGMII data (RX) | unused |
| `GMAC0_RGMII_TXCLK` | GPIO1_B4 | RGMII TX clk | unused |
| `GMAC0_RGMII_RXCLK` | GPIO1_B5 | RGMII RX clk | unused |
| `GMAC0_RGMII_CTRL` | GPIO1_B6 | RGMII ctrl | unused |
| `PWM3` (fan) | GPIO3_B1 | PWM output | `pwm3` in DT, controlled by `fan-supply` |
| `LED_HDD_n` | GPIO4_B5 | push-pull output | `hdd_led` |
| `LED_NET_n` | GPIO4_B6 | push-pull output | `net_led` |
| `LED_WORK_n` | GPIO4_B7 | push-pull output | `work_led` |
| `VOL_UP_BTN_n` | GPIO4_C0 | input / SARADC ch 1 | `adc-keys/vol-up-key` |

### 4.3 全部 bank 的引脚默认映射（节选自 rk3588-pinctrl.dtsi）

| Bank | Pin | Default function | Pinmux reg |
|---|---|---|---|
| GPIO0 | 0 | GPIO0_A0 / I2C0_SCL_A0 / PWM0 / UART2_TX_A0 | 0xfd5a8000 |
| GPIO0 | 1 | GPIO0_A1 / I2C0_SDA_A1 / PWM1 / UART2_RX_A1 | 0xfd5a8004 |
| GPIO0 | 2 | GPIO0_A2 / I2C1_SCL / PWM2 / UART2_RTSN_A2 | 0xfd5a8008 |
| GPIO0 | 3 | GPIO0_A3 / I2C1_SDA / PWM3 / UART2_CTSN_A3 | 0xfd5a800c |
| ... | ... | (190 more, omitted for brevity) | ... |
| GPIO5 | 31 | GPIO5_B7 / I2C8_SDA_B7 | 0xfec6007c |

要在活体内核里查询某个 pin 的当前用途：

```bash
cat /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins
```

例（live dump）：

```
pin 0  (gpio0-0): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 5  (gpio0-5): feb20000.spi  function spi2 group spi2m2-pins
pin 13 (gpio0-13): fd880000.i2c  function i2c0 group i2c0m0-xfer
...
pin 89 (gpio2-B5): (MUX UNCLAIMED) (GPIO UNCLAIMED)
```

## 5. I²C 总线与设备

| Bus | 节点 | 实际挂载 |
|---|---|---|
| I²C0 (fd880000) | `i2c@fd880000` | RK806 PMIC + serial eeproms |
| I²C1 (feaa0000) | `i2c@feaa0000` | (vendor reserved) |
| I²C2 (feaa1000) | `i2c@feaa1000` | (vendor reserved) |
| I²C3 (feaa2000) | `i2c@feaa2000` | (vendor reserved) |
| I²C4 (feaa3000) | `i2c@feaa3000` | (vendor reserved) |
| I²C5 (feaa4000) | `i2c@feaa4000` | (vendor reserved) |
| I²C6 (fec10000) | `i2c@fec10000` | (vendor reserved) |
| I²C7 (fec00000) | `i2c@fec00000` | (vendor reserved) |
| I²C8 (febe0000) | `i2c@febe0000` | (vendor reserved) |

活体内核目前只 expose RK806 + 1 个 I²C0 eeprom，其它 bus 都未注册 — vendor
GXY BSP 关闭了它们。

## 6. SPI 总线

| Bus | 节点 | 用途 |
|---|---|---|
| SPI0 (feb10000) | `spi@feb10000` | serial flash (SPI-NOR) |
| SPI1 (feb20000) | `spi@feb20000` | serial flash alternate / PMIC RTC |
| SPI2 (feb20000) | (alias of SPI1) | — |
| SPI3 (feb30000) | `spi@feb30000` | — |
| SPI4 (feb40000) | `spi@feb40000` | — |

SPI-NOR flash 通过 `spi@feb10000` + `sfc@fe2b0000` 接入。

## 7. RTC、UART、SPI-NOR

- **HYM8563**（实时钟）在 `i2c@fec10000` 上（DTS path 为 `hym8563@51`），vendor
  内核中 `rtc-hym8563` 未启用 → `/sys/class/rtc/` 为空。补丁启用后会生成
  `rtc0`。
- **UART 0..9**：10 个串口，DMA + FIFO + RS485 全支持。`UART2` 是调试串口
  (`earlycon=uart8250,mmio32,0xfeb50000 console=ttyFIQ0`)。
- **SPI-NOR**：`/proc/mtd` 显示 7 个分区（loader/uboot/boot/modules/ParamBackup/
  Config_new/Factory/buginfo）。

## 8. 引脚查找指南

| 想做的事 | 命令 |
|---|---|
| 看所有 pinctrl | `cat /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins` |
| 看某个 GPIO 的当前 mux | `cat /sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins \| grep "^ *pin.*gpio0-13"` |
| 查 GPIO 的电平 | `cat /sys/class/gpio/gpiochip0/label` + `cat /sys/kernel/debug/gpio` |
| 找网络设备 → PCIe 地址 | `ls -l /sys/class/net/eth0/device` |
| 找 MDIO 总线下的 PHY | `ls /sys/class/mdio_bus/mdio_bus-gmac0/devices/` |
| 找 SFP/SFF 模块 | `ethtool -m ytgsw0p4` |
| 看 IRQ 是谁在用 | `cat /proc/interrupts` |

## 9. 与 patch 包 `g98-armbian-patch/` 的对应关系

| 文件 | 在 DTB 中位置 | 适配作用 |
|---|---|---|
| `dts/linux-6.6/.../rk3588-g98-*.dts*` | kernel 编译 | 上游合并的板级覆盖 |
| `different-files/g98/bootfs/armbianEnv.txt` | `armbianEnv.txt` | armbian-install 注入到 `/boot` |
| `different-files/g98/rootfs/etc/fw_env.config` | `armbianEnv.txt`（U-Boot env） | U-Boot 启动参数 |
| `build-armbian/.../model_database.conf.g98-snippet` | `model_database.conf` | `-b g98` 注册 |
| `.github/workflows/build-g98-armbian.yml` | CI | `Actions → build-g98-armbian` |
| `apply-patch.sh` | 顶层 | 一键应用以上全部 |

## 10. 上手命令

```bash
# A. 在 fork 上 apply
git clone https://github.com/stevenliuit/amlogic-s9xxx-armbian.git
cd amlogic-s9xxx-armbian
../g98-armbian-patch/apply-patch.sh .
git add -A && git commit -m "feat: add G98 (rk3588s) NVR board (2x YT9215 + 2x RTL8125)"
git push origin main

# B. 触发 CI（GitHub Web UI 或 gh CLI）
gh workflow run build-g98-armbian.yml -f armbian_kernel=6.6.y

# C. 实时板子（live box）
ssh -p 222 admin@192.168.168.1
ip link set eth0 up; ip link set eth1 up
brctl addif br0 eth0 eth1
ip link set br0 up

# D. YT9215S 验证（mainline kernel 启用后）
ethtool ytgsw0p0
bridge vlan show dev ytgsw0
```

## 11. 已知的缺失驱动（live）

- `motorcomm,yt9215s.ko` — 板子有 YT9215S，live 内核没有编译此驱动
- `es8311_sound.ko` — `es8311@18` 在 DTS 中存在但无 sound driver
- `rtc-hym8563.ko` — RTC 在 DT 但无 driver
- `pwm-rockchip.ko` — PWM 仅作为占位（`pwm0..pwm15` 缺失）

这些 gap 正是 patch 修的目标。

---

完整 dump 在 `g98-probe/`：
- `aliases.txt`, `cmdline.txt`, `dmesg.txt`, `dev.txt`,
  `dt-base-listing.txt`, `dt-dirs.txt`, `interrupts.txt`, `iomem.txt`,
  `iio.txt`, `lsmod-list.txt`, `lspci-full.txt`, `mdio-*.txt`, `nic-*.txt`,
  `of-*.txt`, `phy-*.txt`, `pinctrl-rockchip-pinctrl.log`, `pwm.txt`,
  `regulators.txt`, `rtc.txt`, `summary.txt`, `sysclassnet.txt`,
  `thermal.txt`, `version-rk.txt`, `yt-driver.txt`, etc.
- `devicetree.tar.gz` — `/sys/firmware/devicetree/base` 整树快照

上游合并用的源码在 `linux-6.6/`；armbian 集成的 patch 包在
`g98-armbian-patch.zip`。

详细步骤见 `README.md`。
