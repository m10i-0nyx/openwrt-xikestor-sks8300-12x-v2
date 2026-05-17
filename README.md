# 1. イメージビルド
```
podman build -t openwrt-builder ./builder
```

# 2. ビルド成果物を取り出すためのボリュームを用意
```
mkdir -p ./workspace/output
```

# 3. コンテナ起動(rootlessの場合 --userns=keep-id 推奨)
```
podman run --rm -it \
    --userns=keep-id \
    -v ./workspace:/home/ubuntu/workspace:Z \
    --name openwrt-build \
    localhost/openwrt-builder:latest \
    bash
```
# 4. コンテナ内で下記実行
```
./workspace/get-openwrt.sh && ./workspace/build.sh
```

# 5. ビルド成果物は ~/workspace/output に出力される

# 6. XikeStor SKS8300-12X V2.0 用のイメージを本体に書き込む

> **重要**: 本ビルドでは `runtime2` パーティション（13MB）を `rootfs_data`（/overlay）に転用しています。
> したがって `upgrade runtime2 ...bix` は **行いません**（行うと overlay 領域が破壊されます）。
> 副作用としてデュアルバンク failsafe を失い、ファームウェア書き込み失敗時のフォールバック起動はできません。

```
setenv ipaddr 192.168.1.254
setenv netmask 255.255.255.0
setenv serverip 192.168.1.10

rtk network on
rtk 10g 0 fiber10g

upgrade runtimeforce openwrt-realtek-rtl931x-xikestor_sks8300-12x-v2-squashfs-firmware.bix
reset
```

# 7. パーティション利用方針（OpenWrt 起動後）

| MTD | サイズ | 用途 |
|---|---|---|
| u-boot / board-info / sysinfo | 1.25M + 64K + 64K | ブートローダ・出荷情報（read-only） |
| jffs2-cfg | 640KB | `/etc` への差分 overlay（preinit hook） |
| jffs2-log | 4MB | `/var/log` 直接マウント（preinit hook） |
| runtime1 (kernel + rootfs) | 13MB | カーネル + squashfs ルートファイルシステム |
| rootfs_data (旧 runtime2) | 13MB | OpenWrt 標準 /overlay。`opkg install` 等のパッケージデータはここに格納 |

`/proc/mtd` で `rootfs_data` が 13MB として認識され、`mount` の overlay 行が `upperdir=/overlay/upper`（jffs2 上）になっていれば成功です。
