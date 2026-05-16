#!/bin/bash
set -eux

cd "$HOME"
echo "=== Current DIR: $(pwd) ==="
ls -la

if [ ! -d "openwrt" ]; then
    echo "=== OpenWrt ソースコードをクローン ==="
    git clone --depth 1 --branch main \
        https://github.com/openwrt/openwrt.git openwrt
else
    echo "=== OpenWrt ソースコードを最新に更新 ==="
    cd openwrt
    pwd
    # スクリプトが加えたローカル変更を破棄して最新コミットに reset
    git fetch --depth=1 origin main
    git reset --hard origin/main
    git clean -fd
    cd "$HOME"
fi

cd ~/openwrt
./scripts/feeds update -a
./scripts/feeds install -a

# === V2 デバイス定義を追加 ===

# 1. V2 用 DTS 作成 (V1 をベース + partition@600000 へのオフセット変更)
cat > target/linux/realtek/dts/rtl9313_xikestor_sks8300-12x-v2.dts << 'EOF'
// SPDX-License-Identifier: GPL-2.0-or-later

#include "rtl931x.dtsi"

#include <dt-bindings/input/input.h>
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/leds/common.h>
#include <dt-bindings/phy/phy.h>

/ {
        compatible = "xikestor,sks8300-12x-v2", "realtek,rtl9313-soc";
        model = "XikeStor SKS8300-12X V2.0";

        memory@0 {
                device_type = "memory";
                reg = <0x00000000 0x10000000>, /* first 256 MiB */
                      <0x90000000 0x10000000>; /* remaining 256 MiB */
        };

        aliases {
                label-mac-device = &ethernet0;
                led-boot = &led_sys;
                led-failsafe = &led_sys;
                led-running = &led_sys;
                led-upgrade = &led_sys;
        };

        chosen {
                stdout-path = "serial0:115200n8";
                bootargs = "loglevel=4";
        };

        keys {
                compatible = "gpio-keys";

                button-reset {
                        label = "reset";
                        gpios = <&gpio0 10 GPIO_ACTIVE_LOW>;
                        linux,code = <KEY_RESTART>;
                };
        };

        leds {
                compatible = "gpio-leds";

                led_sys: led-0 {
                        gpios = <&gpio0 31 GPIO_ACTIVE_HIGH>;
                        color = <LED_COLOR_ID_GREEN>;
                        function = LED_FUNCTION_STATUS;
                };
        };

        led_set {
                compatible = "realtek,rtl9300-leds";
                active-low;

                /* LED[0]: green | LED[1]: amber */
                led_set0 = <(RTL93XX_LED_SET_10G | RTL93XX_LED_SET_LINK |
                             RTL93XX_LED_SET_ACT)
                            (RTL93XX_LED_SET_2P5G | RTL93XX_LED_SET_1G |
                             RTL93XX_LED_SET_LINK | RTL93XX_LED_SET_ACT)>;
        };

        watchdog1: watchdog {
                compatible = "diodes,pt7a75xx-wdt";
        };

        i2c-gpio0 {
                compatible = "i2c-gpio";
                #address-cells = <1>;
                #size-cells = <0>;

                sda-gpios = <&gpio0 29 GPIO_ACTIVE_HIGH>;
                scl-gpios = <&gpio0 30 GPIO_ACTIVE_HIGH>;

                i2c-gpio,delay-us = <5>;        /* ~100 kHz */
                lm75: sensor@4f {
                        compatible = "national,lm75a";
                        reg = <0x4f>;
                };
        };

        sfp1: sfp-p1 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c1_sda0>;
                los-gpio = <&gpio1 0 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 1 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 2 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp2: sfp-p2 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c1_sda1>;
                los-gpio = <&gpio1 3 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 4 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 5 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp3: sfp-p3 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c1_sda2>;
                los-gpio = <&gpio1 6 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 7 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 8 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp4: sfp-p4 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c1_sda3>;
                los-gpio = <&gpio1 9 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 10 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 11 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp5: sfp-p5 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c1_sda4>;
                los-gpio = <&gpio1 12 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 13 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 14 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp6: sfp-p6 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c1_sda5>;
                los-gpio = <&gpio1 21 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 22 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 23 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp7: sfp-p7 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c2_sda6>;
                los-gpio = <&gpio1 24 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 25 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 26 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp8: sfp-p8 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c2_sda7>;
                los-gpio = <&gpio1 27 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio1 28 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio1 29 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp9: sfp-p9 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c2_sda9>;
                los-gpio = <&gpio2 3 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio2 4 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio2 5 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp10: sfp-p10 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c2_sda8>;
                los-gpio = <&gpio2 0 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio2 1 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio2 2 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp11: sfp-p11 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c2_sda11>;
                los-gpio = <&gpio2 9 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio2 10 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio2 11 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };

        sfp12: sfp-p12 {
                compatible = "sff,sfp";
                i2c-bus = <&i2c2_sda10>;
                los-gpio = <&gpio2 6 GPIO_ACTIVE_HIGH>;
                mod-def0-gpio = <&gpio2 7 GPIO_ACTIVE_LOW>;
                tx-disable-gpio = <&gpio2 8 GPIO_ACTIVE_HIGH>;
                #thermal-sensor-cells = <0>;
        };
};

&i2c_mst1 {
        status = "okay";

        i2c1_sda0: i2c@0 {
                reg = <0>;
        };
        i2c1_sda1: i2c@1 {
                reg = <1>;
        };
        i2c1_sda2: i2c@2 {
                reg = <2>;
        };
        i2c1_sda3: i2c@3 {
                reg = <3>;
        };
        i2c1_sda4: i2c@4 {
                reg = <4>;
        };
        i2c1_sda5: i2c@5 {
                reg = <5>;
        };
};

&i2c_mst2 {
        status = "okay";

        i2c2_sda6: i2c@6 {
                reg = <6>;
        };
        i2c2_sda7: i2c@7 {
                reg = <7>;
        };
        i2c2_sda8: i2c@8 {
                reg = <8>;
        };
        i2c2_sda9: i2c@9 {
                reg = <9>;
        };
        i2c2_sda10: i2c@a {
                reg = <10>;
        };
        i2c2_sda11: i2c@b {
                reg = <11>;
        };
};

&mdio_aux {
        status = "okay";

        gpio1: gpio@0 {
                compatible = "realtek,rtl8231";
                reg = <0>;

                gpio-controller;
                #gpio-cells = <2>;
                gpio-ranges = <&gpio1 0 0 37>;

                led-controller {
                        compatible = "realtek,rtl8231-leds";
                        status = "disabled";
                };
        };

        gpio2: gpio@1 {
                compatible = "realtek,rtl8231";
                reg = <1>;

                gpio-controller;
                #gpio-cells = <2>;
                gpio-ranges = <&gpio2 0 0 37>;

                led-controller {
                        compatible = "realtek,rtl8231-leds";
                        status = "disabled";
                };
        };
};

&spi0 {
        status = "okay";

        flash@0 {
                compatible = "jedec,spi-nor";
                reg = <0>;
                spi-max-frequency = <10000000>;

                /* Delete all V1 partitions completely */
                /delete-node/ partitions;

                partitions {
                        compatible = "fixed-partitions";
                        #address-cells = <1>;
                        #size-cells = <1>;

                        /* LOADER: 0x000000-0x13ffff (1.25MB) */
                        partition@0 {
                                label = "u-boot";
                                reg = <0x0 0x140000>;
                                read-only;
                        };

                        /* BDINFO: 0x140000-0x14ffff (64KB) */
                        partition@140000 {
                                label = "board-info";
                                reg = <0x140000 0x10000>;
                                read-only;

                                nvmem-layout {
                                        compatible = "fixed-layout";
                                        #address-cells = <1>;
                                        #size-cells = <1>;

                                        macaddr_vendor: macaddr@1f1 {
                                                compatible = "mac-base";
                                                reg = <0x1f1 0x6>;
                                                #nvmem-cell-cells = <1>;
                                        };
                                };
                        };

                        /* SYSINFO: 0x150000-0x15ffff (64KB) */
                        partition@150000 {
                                label = "sysinfo";
                                reg = <0x150000 0x10000>;
                                read-only;
                        };

                        /* JFFS2_CFG: 0x160000-0x1fffff (640KB) */
                        partition@160000 {
                                label = "jffs2-cfg";
                                reg = <0x160000 0xa0000>;
                                read-only;
                        };

                        /* JFFS2_LOG: 0x200000-0x5fffff (4MB) */
                        partition@200000 {
                                label = "jffs2-log";
                                reg = <0x200000 0x400000>;
                                read-only;
                        };

                        /* RUNTIME1: 0x600000-0x12fffff (13MB) */
                        partition@600000 {
                                compatible = "fixed-partitions";
                                label = "runtime1";
                                reg = <0x600000 0xd00000>;
                                #address-cells = <1>;
                                #size-cells = <1>;

                                partition@0 {
                                        label = "kernel";
                                        reg = <0x0 0x500000>;
                                };

                                partition@500000 {
                                        label = "rootfs";
                                        reg = <0x500000 0x800000>;
                                };
                        };

                        /* RUNTIME2: 0x1300000-0x1ffffff (13MB) */
                        partition@1300000 {
                                label = "runtime2";
                                reg = <0x1300000 0xd00000>;
                        };
                };
        };
};

&ethernet0 {
        nvmem-cells = <&macaddr_vendor 0>;
        nvmem-cell-names = "mac-address";
};

&switch0 {
        ethernet-ports {
                #address-cells = <1>;
                #size-cells = <0>;

                SWITCH_PORT_SFP(0, 1, 2, 0, 1)
                SWITCH_PORT_SFP(8, 2, 3, 0, 2)
                SWITCH_PORT_SFP(16, 3, 4, 0, 3)
                SWITCH_PORT_SFP(24, 4, 5, 0, 4)
                SWITCH_PORT_SFP(32, 5, 6, 0, 5)
                SWITCH_PORT_SFP(40, 6, 7, 0, 6)
                SWITCH_PORT_SFP(48, 7, 8, 0, 7)
                SWITCH_PORT_SFP(50, 8, 9, 0, 8)
                SWITCH_PORT_SFP(52, 10, 10, 0, 10)
                SWITCH_PORT_SFP(53, 9, 11, 0, 9)
                SWITCH_PORT_SFP(54, 12, 12, 0, 12)
                SWITCH_PORT_SFP(55, 11, 13, 0, 11)

                /* CPU port */
                port@56 {
                        ethernet = <&ethernet0>;
                        reg = <56>;
                        phy-mode = "internal";
                        fixed-link {
                                speed = <1000>;
                                full-duplex;
                        };
                };
        };
};

&port0  { phy-mode = "10gbase-r"; };
&port8  { phy-mode = "10gbase-r"; };
&port16 { phy-mode = "10gbase-r"; };
&port24 { phy-mode = "10gbase-r"; };
&port32 { phy-mode = "10gbase-r"; };
&port40 { phy-mode = "10gbase-r"; };
&port48 { phy-mode = "10gbase-r"; };
&port50 { phy-mode = "10gbase-r"; };
&port52 { phy-mode = "10gbase-r"; };
&port53 { phy-mode = "10gbase-r"; };
&port54 { phy-mode = "10gbase-r"; };
&port55 { phy-mode = "10gbase-r"; };

&serdes2 { tx-polarity = <PHY_POL_INVERT>; };
&serdes3 { tx-polarity = <PHY_POL_INVERT>; };
&serdes4 { tx-polarity = <PHY_POL_INVERT>; };
&serdes5 { tx-polarity = <PHY_POL_INVERT>; };
&serdes6 { tx-polarity = <PHY_POL_INVERT>; };
&serdes7 { tx-polarity = <PHY_POL_INVERT>; };
&serdes8 { tx-polarity = <PHY_POL_INVERT>; };
&serdes9 { tx-polarity = <PHY_POL_INVERT>; };
&serdes10 { tx-polarity = <PHY_POL_INVERT>; };
&serdes11 { tx-polarity = <PHY_POL_INVERT>; };
&serdes12 { tx-polarity = <PHY_POL_INVERT>; };
&serdes13 { tx-polarity = <PHY_POL_INVERT>; };
EOF

# 1.5 realtek/dts/Makefile に DTS compile rule を追加
DTS_MK="target/linux/realtek/dts/Makefile"
if [ ! -f "$DTS_MK" ]; then
    mkdir -p target/linux/realtek/dts
    cat > "$DTS_MK" << 'DTSMAKEFILE'
dtb-y += \
	rtl9313_xikestor_sks8300-12x-v2.dtb

targets += $(dtb-y)
DTSMAKEFILE
fi
if ! grep -q "rtl9313_xikestor_sks8300-12x-v2" "$DTS_MK"; then
    sed -i '/^dtb-y/a\ 	rtl9313_xikestor_sks8300-12x-v2.dtb' "$DTS_MK"
fi

# 2. rtl931x.mk に V2 定義を追加
MK="target/linux/realtek/image/rtl931x.mk"
if ! grep -q "sks8300-12x-v2" "$MK"; then
    # Build/xikestor-bix-header マクロ と デバイス定義を追加
    # ルールコマンド行は TAB インデント必須 (Makefile 要件)
    python3 - << 'PYEOF'
mk_content = (
    "\n"
    "define Build/xikestor-bix-header\n"
    "    $(STAGING_DIR_HOST)/bin/xikestor-bix-header < $@ > $@.new\n"
    "    @mv $@.new $@\n"
    "endef\n"
    "\n"
    "define Device/xikestor_sks8300-12x-v2\n"
    "    SOC := rtl9313\n"
    "    DEVICE_VENDOR := XikeStor\n"
    "    DEVICE_MODEL := SKS8300-12X\n"
    "    DEVICE_VARIANT := V2.0\n"
    "    BLOCKSIZE := 64k\n"
    "    IMAGE_SIZE := 13312k\n"
    "    KERNEL := kernel-bin | append-dtb | lzma\n"
    "    KERNEL_INITRAMFS := kernel-bin | append-dtb | lzma | uImage lzma\n"
    "    IMAGES := firmware.bix\n"
    "    IMAGE/firmware.bix := \\\n"
    "        append-kernel | \\\n"
    "        pad-to 5242800 | \\\n"
    "        append-rootfs | \\\n"
    "        pad-rootfs | \\\n"
    "        xikestor-bix-header\n"
    "endef\n"
    "TARGET_DEVICES += xikestor_sks8300-12x-v2\n"
)
with open("target/linux/realtek/image/rtl931x.mk", "a") as f:
    f.write(mk_content)
print("rtl931x.mk updated")
PYEOF
fi

# 3. board.d に V2 を追加
BOARD_D="target/linux/realtek/base-files/etc/board.d/02_network"
if ! grep -q "sks8300-12x-v2" "$BOARD_D"; then
    sed -i '/xikestor,sks8300-12x-v1|\\$/a\\t\txikestor,sks8300-12x-v2|\\' "$BOARD_D"
fi

# === RTL8231 EPROBE_DEFER 修正 ===
# 802パッチ自体を修正(行数も自動調整)
python3 - << 'PYEOF'
import re

filepath = 'target/linux/realtek/patches-6.18/802-mfd-Add-RTL8231-core-device.patch'
with open(filepath, 'r') as f:
    content = f.read()

old = ('+\terr = regmap_read(map, RTL8231_REG_FUNC1, &val);\n'
       '+\tif (err) {\n'
       '+\t\tdev_err(dev, "failed to read READY_CODE\\n");\n'
       '+\t\treturn err;\n'
       '+\t}')
new = ('+\terr = regmap_read(map, RTL8231_REG_FUNC1, &val);\n'
       '+\tif (err)\n'
       '+\t\treturn dev_err_probe(dev, -EPROBE_DEFER, "failed to read READY_CODE, will retry\\n");')

if old not in content:
    print("WARNING: RTL8231 pattern not found, may already be patched")
else:
    content = content.replace(old, new, 1)
    # @@ -0,0 +1,N @@ の N を実際の行数に修正
    lines = content.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if '+++ b/drivers/mfd/rtl8231.c' in line:
            for j in range(i+1, len(lines)):
                if lines[j].startswith('@@'):
                    count = 0
                    for k in range(j+1, len(lines)):
                        if lines[k].startswith('@@') or lines[k].startswith('diff ') or lines[k].startswith('---'):
                            break
                        if lines[k].startswith('+') and not lines[k].startswith('+++'):
                            count += 1
                    old_hdr = lines[j]
                    new_hdr = re.sub(r'\+1,\d+', f'+1,{count}', old_hdr)
                    lines[j] = new_hdr
                    print(f"Fixed hunk header: {old_hdr.strip()} -> {new_hdr.strip()}")
                    break
            break
    content = ''.join(lines)
    with open(filepath, 'w') as f:
        f.write(content)
    print("RTL8231 EPROBE_DEFER patch applied to 802")
PYEOF

# === xikestor-bix-header ツールを firmware-utils に追加 ===

# 4. C ソースファイルをパッチとして追加
mkdir -p tools/firmware-utils/patches

python3 - << 'PYEOF'
c_src = r"""// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * xikestor-bix-header: Add RTK BIX header for XikeStor SKS8300-12X V2
 *
 * Header format (80 bytes):
 *   0x00  magic       = 0x00000002
 *   0x04  flags       = 0x00000000
 *   0x08  model_id    = 0x0000245E  (SKS8300-12X family, hardcoded)
 *   0x0C  dev_sig     = 0x43E1761B  (device signature, hardcoded)
 *   0x10  chipset     = 0x93000000  (RTL93xx, hardcoded)
 *   0x14  header_crc  = CRC32(header with 0x14 zeroed) (big-endian, COMPUTED)
 *   0x18  timestamp   = build time  (Unix time, big-endian)
 *   0x1C  data_size   = payload len (big-endian, COMPUTED)
 *   0x20  load_addr   = 0x80000000
 *   0x24  entry_point = 0x802B3470
 *   0x28  data_crc    = CRC32(payload) (big-endian, COMPUTED)
 *   0x2C  version     = 0x05050203  (5.5.2.3, hardcoded)
 *   0x30  name[32]    = "RTK_SDK\0..."
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define BIX_HEADER_SIZE 0x50u
#define BIX_MAGIC       0x00000002u
#define BIX_MODEL_ID    0x0000245Eu
#define BIX_CHIPSET     0x93000000u
#define BIX_LOAD_ADDR   0x80100000u
#define BIX_ENTRY_POINT 0x80100000u
#define BIX_VERSION     0x05050203u
#define BIX_IMAGE_NAME  "RTK_SDK"

static uint32_t crc32_table[256];

static void crc32_init(void)
{
    unsigned int i, j;

    for (i = 0; i < 256; i++) {
        uint32_t c = i;
        for (j = 0; j < 8; j++)
            c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
        crc32_table[i] = c;
    }
}

static uint32_t crc32_update(uint32_t crc, const uint8_t *data, size_t len)
{
    size_t i;
    for (i = 0; i < len; i++)
        crc = crc32_table[(crc ^ data[i]) & 0xFFu] ^ (crc >> 8);
    return crc;
}

static void put_be32(uint8_t *buf, uint32_t val)
{
    buf[0] = (uint8_t)(val >> 24);
    buf[1] = (uint8_t)(val >> 16);
    buf[2] = (uint8_t)(val >>  8);
    buf[3] = (uint8_t)(val      );
}

int main(void)
{
    uint8_t *payload = NULL;
    size_t payload_size = 0, capacity = 0;
    uint8_t buf[65536];
    uint8_t header[BIX_HEADER_SIZE];
    uint32_t crc;
    size_t n;

    crc32_init();
    crc = 0xFFFFFFFFu;

    while ((n = fread(buf, 1, sizeof(buf), stdin)) > 0) {
        uint8_t *new_buf;
        if (payload_size + n > capacity) {
            capacity = (payload_size + n + 65535u) & ~65535u;
            new_buf = realloc(payload, capacity);
            if (!new_buf) {
                perror("realloc");
                free(payload);
                return 1;
            }
            payload = new_buf;
        }
        memcpy(payload + payload_size, buf, n);
        crc = crc32_update(crc, buf, n);
        payload_size += n;
    }

    if (ferror(stdin)) {
        perror("fread");
        free(payload);
        return 1;
    }

    if (payload_size == 0) {
        fprintf(stderr, "xikestor-bix-header: empty input\n");
        free(payload);
        return 1;
    }

    crc ^= 0xFFFFFFFFu;

    memset(header, 0, BIX_HEADER_SIZE);
    put_be32(header + 0x00, BIX_MAGIC);
    /* 0x04: flags = 0 (already zeroed) */
    put_be32(header + 0x08, BIX_MODEL_ID);
    /* 0x0C: file_crc - computed below after header_crc(0x14) is set */
    put_be32(header + 0x10, BIX_CHIPSET);
    /* 0x14: header_crc - computed below */
    put_be32(header + 0x18, (uint32_t)time(NULL));
    put_be32(header + 0x1C, (uint32_t)payload_size);
    put_be32(header + 0x20, BIX_LOAD_ADDR);
    put_be32(header + 0x24, BIX_ENTRY_POINT);
    put_be32(header + 0x28, crc);
    put_be32(header + 0x2C, BIX_VERSION);
    memcpy(header + 0x30, BIX_IMAGE_NAME, sizeof(BIX_IMAGE_NAME) - 1);

    /* Step 1: header_crc(0x14) = CRC32(header[0x10:0x50]), 0x14 is 0 from memset */
    {
        uint32_t hdr_crc = 0xFFFFFFFFu;
        size_t k;
        for (k = 0x10; k < BIX_HEADER_SIZE; k++)
            hdr_crc = crc32_table[(hdr_crc ^ header[k]) & 0xFFu] ^ (hdr_crc >> 8);
        hdr_crc ^= 0xFFFFFFFFu;
        put_be32(header + 0x14, hdr_crc);
    }

    /* Step 2: file_crc(0x0C) = CRC32(header[0x10:0x50] + payload), 0x14 has real value */
    {
        uint32_t file_crc = 0xFFFFFFFFu;
        size_t k;
        for (k = 0x10; k < BIX_HEADER_SIZE; k++)
            file_crc = crc32_table[(file_crc ^ header[k]) & 0xFFu] ^ (file_crc >> 8);
        file_crc = crc32_update(file_crc, payload, payload_size);
        file_crc ^= 0xFFFFFFFFu;
        put_be32(header + 0x0C, file_crc);
    }

    if (fwrite(header, 1, BIX_HEADER_SIZE, stdout) != BIX_HEADER_SIZE ||
        fwrite(payload, 1, payload_size, stdout) != payload_size) {
        perror("fwrite");
        free(payload);
        return 1;
    }

    free(payload);
    return 0;
}
"""

lines = c_src.splitlines(keepends=True)
count = len(lines)
with open('tools/firmware-utils/patches/100-add-xikestor-bix-header.patch', 'w') as f:
    f.write('--- /dev/null\n')
    f.write('+++ b/src/xikestor-bix-header.c\n')
    f.write(f'@@ -0,0 +1,{count} @@\n')
    for line in lines:
        f.write('+' + line)
    f.write('\n')
print(f"Patch 1 created: {count} lines")
PYEOF

# 5. CMakeLists.txt パッチ: xiaomifw と xorimage の間に挿入(アルファベット順)
python3 - << 'PYEOF'
lines = [
    '--- a/CMakeLists.txt\n',
    '+++ b/CMakeLists.txt\n',
    '@@ -200,2 +200,3 @@\n',
    ' FW_UTIL(xiaomifw "" "" "")\n',
    '+FW_UTIL(xikestor-bix-header "" "" "")\n',
    ' FW_UTIL(xorimage "" "" "")\n',
    '\n',
]
with open('tools/firmware-utils/patches/101-cmake-xikestor-bix-header.patch', 'w') as f:
    f.writelines(lines)
print("Patch 101 created")
PYEOF

echo "=== セットアップ完了 ==="
grep -r "sks8300-12x-v2" target/linux/realtek/
