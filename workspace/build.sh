#!/bin/bash
set -eux

cd "$HOME/openwrt"

# Enable ccache for faster rebuilds
ccache -M 10G

cp "$HOME/workspace/.config.seed.txt" "$HOME/openwrt/.config"
# Ensure the configuration is up to date
make oldconfig

JOBS=$(nproc)

echo "=== ターゲット確認 ==="
grep "CONFIG_TARGET_realtek_rtl931x_DEVICE_xikestor_sks8300-12x-v2=y" .config || {
    echo "ERROR: デバイスが見つかりません"
    exit 1
}

echo "=== ビルド開始 ==="
time make -j"$JOBS" V=0 2>&1 | tee "$HOME/workspace/build.log"

echo "=== IMAGE ビルド ==="
# target/linux/install で squashfs + IMAGE パイプラインを確実に実行
time make -j1 V=1 target/linux/install 2>&1 | tee -a "$HOME/workspace/build.log"

echo "=== 成果物 ==="
ls "$HOME/openwrt/bin/targets/realtek/rtl931x/"*v2*
cp "$HOME/openwrt/bin/targets/realtek/rtl931x/"*v2*.bin \
   "$HOME/workspace/output/"
cp "$HOME/openwrt/bin/targets/realtek/rtl931x/"*v2*.bix \
   "$HOME/workspace/output/"
