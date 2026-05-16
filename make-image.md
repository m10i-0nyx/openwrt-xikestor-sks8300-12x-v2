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
```
setenv ipaddr 192.168.1.254
setenv netmask 255.255.255.0

rtk network on
rtk 10g 0 fiber10g

tftpboot 0x82000000 openwrt-realtek-rtl931x-xikestor_sks8300-12x-v2-initramfs-kernel.bin
bootm 0x82000000
```
