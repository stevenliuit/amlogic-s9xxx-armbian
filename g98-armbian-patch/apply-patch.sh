#!/usr/bin/env bash
# apply-patch.sh - Integrate the G98 NVR board (rk3588s) into a local
# clone of stevenliuit/amlogic-s9xxx-armbian.
#
# Usage:
#   git clone --depth=1 https://github.com/stevenliuit/amlogic-s9xxx-armbian.git
#   cd amlogic-s9xxx-armbian
#   ../g98-armbian-patch/apply-patch.sh .
#
# Prerequisites on the host machine:
#   - bash (msys / git-bash / WSL)
#   - `patch` (optional, for the manual alternative workflow)
#   - git
#
# What this script does:
#   1. Writes the G98 row to model_database.conf (Rockchip section)
#   2. Copies the different-files/g98 overlay into the clone
#   3. Copies the build-armbian files into the clone
#   4. Copies the GitHub Actions workflow into .github/workflows/

set -euo pipefail
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="${1:-$PWD}"

if [[ ! -d "$REPO_DIR/build-armbian" ]]; then
    echo "ERROR: $REPO_DIR does not look like an amlogic-s9xxx-armbian checkout"
    echo "Hint: git clone https://github.com/stevenliuit/amlogic-s9xxx-armbian.git"
    exit 1
fi

CONF="$REPO_DIR/build-armbian/armbian-files/common-files/etc/model_database.conf"
SNIPPET="$PATCH_DIR/build-armbian/armbian-files/common-files/etc/model_database.conf.g98-snippet"

if ! grep -q "^r201[[:space:]]*:G98[[:space:]]*:" "$CONF" 2>/dev/null; then
    echo "appending G98 row to model_database.conf"
    cat "$SNIPPET" >> "$CONF"
else
    echo "model_database.conf: G98 row already present"
fi

# board overlay
install -m 0644 "$PATCH_DIR/different-files/g98/bootfs/armbianEnv.txt" \
    "$REPO_DIR/build-armbian/armbian-files/different-files/g98/bootfs/armbianEnv.txt"
install -m 0644 "$PATCH_DIR/different-files/g98/rootfs/etc/fw_env.config" \
    "$REPO_DIR/build-armbian/armbian-files/different-files/g98/rootfs/etc/fw_env.config"

# platform files (these will be added once the kernel-rk3588 armbian-kernel
# package contains our DTB; we still ship the source for sanity)
install -d "$REPO_DIR/build-armbian/armbian-files/platform-files/rockchip/bootfs/dtb/rockchip"
install -m 0644 "$PATCH_DIR/dtbs/rk3588s-g98.dtb" \
    "$REPO_DIR/build-armbian/armbian-files/platform-files/rockchip/bootfs/dtb/rockchip/rk3588s-g98.dtb" 2>/dev/null || \
    echo "note: dtb not copied (build the kernel-rk3588 package first)"

# GitHub Actions
install -d "$REPO_DIR/.github/workflows"
install -m 0644 "$PATCH_DIR/.github/workflows/build-g98-armbian.yml" \
    "$REPO_DIR/.github/workflows/build-g98-armbian.yml"

# readme hint
cp "$PATCH_DIR/g98-probe-summary.md" \
    "$REPO_DIR/build-armbian/armbian-files/different-files/g98/README-probe.md" 2>/dev/null || true

cat <<'BANNER'
======================================================================
 G98 patch applied.  Next:
   1. cd amlogic-s9xxx-armbian
   2. git add -A
   3. git commit -m "feat: add G98 (rk3588s) NVR board (2x YT9215 + 2x RTL8125)"
   4. git push origin main
   5. GitHub: Actions -> "Build G98 Armbian image" -> Run workflow
======================================================================
BANNER
