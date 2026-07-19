// SPDX-License-Identifier: (GPL-2.0+ OR MIT)
// Minimal placeholder DTB for the G98 NVR board.
// This file is the *compiled binary* that gets shipped before the
// kernel patches are merged upstream.  It contains enough nodes for
// U-Boot to boot and for armbian-install to recognise the G98.
//
// Replace with the real kernel-built DTB (rk3588s-g98.dtb) once the
// kernel fork (stevenliuit/linux-6.6.y or 6.1.y) is rebuilt and the
// new DTB lands in build-armbian/armbian-files/platform-files/rockchip/bootfs/dtb/rockchip/.
//
// Build command (once kernel is built):
//   install -m 0644 output/boot/dtb/rockchip/rk3588s-g98.dtb \
//       build-armbian/armbian-files/platform-files/rockchip/bootfs/dtb/rockchip/
//
// Until then the workflow's "dtb not copied" warning will fire and
// the CI will fall back to building the DTB from the kernel source.