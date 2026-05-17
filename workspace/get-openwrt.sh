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

# 1. V2 用 DTS コピー
cp "$HOME/workspace/rtl9313_xikestor_sks8300-12x-v2.dts" target/linux/realtek/dts/rtl9313_xikestor_sks8300-12x-v2.dts

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
    sed -i '/^dtb-y/a\     rtl9313_xikestor_sks8300-12x-v2.dtb' "$DTS_MK"
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

# === jffs2-cfg を /etc へ overlay マウントする preinit フック ===
# /lib/preinit/85_mount_jffs2_cfg_overlay を base-files に追加
# - mount_root の後、procd/init 起動前に動作
# - jffs2-cfg パーティションが存在する場合のみ動作 (他デバイス影響なし)
# - lowerdir=/etc, upperdir/workdir=jffs2-cfg 上 で /etc に overlay マウント
mkdir -p target/linux/realtek/base-files/lib/preinit
cat > target/linux/realtek/base-files/lib/preinit/85_mount_jffs2_cfg_overlay << 'PREINITEOF'
#!/bin/sh
# Overlay-mount the "jffs2-cfg" MTD partition onto /etc.
# Persists only diffs of /etc into a dedicated 640KB JFFS2 partition.

do_mount_jffs2_cfg_overlay() {
    local idx mtdblock mtdchar mp upper work

    idx=$(awk -F: '/"jffs2-cfg"/ { sub("mtd","",$1); print $1; exit }' /proc/mtd)
    [ -n "$idx" ] || return 0

    mtdblock="/dev/mtdblock${idx}"
    mtdchar="/dev/mtd${idx}"
    mp="/tmp/jffs2-cfg"

    [ -b "$mtdblock" ] || return 0

    mkdir -p "$mp"

    # Try to mount existing JFFS2; on failure erase and retry once.
    if ! mount -t jffs2 -o sync,noatime "$mtdblock" "$mp" 2>/dev/null; then
        echo "jffs2-cfg: erase & format $mtdchar"
        if command -v mtd >/dev/null 2>&1; then
            mtd erase "$mtdchar" >/dev/null 2>&1
        fi
        mount -t jffs2 -o sync,noatime "$mtdblock" "$mp" || {
            echo "jffs2-cfg: mount failed, skip /etc overlay"
            return 1
        }
    fi

    upper="$mp/upper"
    work="$mp/work"
    mkdir -p "$upper" "$work"

    # Overlay /etc: lower = current /etc (rootfs+rootfs_data view),
    # upper/work = on jffs2-cfg. Only diffs are persisted to jffs2-cfg.
    mount -t overlay overlay-etc \
        -o "lowerdir=/etc,upperdir=$upper,workdir=$work" \
        /etc || {
        echo "jffs2-cfg: /etc overlay failed"
        umount "$mp" 2>/dev/null
        return 1
    }

    echo "jffs2-cfg: /etc overlay mounted (upper=$upper)"
}

boot_hook_add preinit_main do_mount_jffs2_cfg_overlay
PREINITEOF
chmod 0755 target/linux/realtek/base-files/lib/preinit/85_mount_jffs2_cfg_overlay

# === jffs2-log を /var/log (= /tmp/log) へ直接マウントする preinit フック ===
# - /var は OpenWrt で /tmp への symlink のためマウント先は /tmp/log
# - /var/log は通常 tmpfs 上で空 → overlay 不要、JFFS2 を直接マウント
# - jffs2-cfg と同じく、パーティションが無いデバイスでは何もしない
cat > target/linux/realtek/base-files/lib/preinit/86_mount_jffs2_log << 'PREINITEOF'
#!/bin/sh
# Mount the "jffs2-log" MTD partition as /var/log to persist logs across reboot.

do_mount_jffs2_log() {
    local idx mtdblock mtdchar mp

    idx=$(awk -F: '/"jffs2-log"/ { sub("mtd","",$1); print $1; exit }' /proc/mtd)
    [ -n "$idx" ] || return 0

    mtdblock="/dev/mtdblock${idx}"
    mtdchar="/dev/mtd${idx}"
    # /var -> /tmp symlink in OpenWrt; mount on real path /tmp/log
    mp="/tmp/log"

    [ -b "$mtdblock" ] || return 0

    mkdir -p "$mp"

    # Try to mount existing JFFS2; on failure erase and retry once.
    if ! mount -t jffs2 -o sync,noatime "$mtdblock" "$mp" 2>/dev/null; then
        echo "jffs2-log: erase & format $mtdchar"
        if command -v mtd >/dev/null 2>&1; then
            mtd erase "$mtdchar" >/dev/null 2>&1
        fi
        mount -t jffs2 -o sync,noatime "$mtdblock" "$mp" || {
            echo "jffs2-log: mount failed, /var/log stays on tmpfs"
            return 1
        }
    fi

    echo "jffs2-log: mounted at /var/log"
}

boot_hook_add preinit_main do_mount_jffs2_log
PREINITEOF
chmod 0755 target/linux/realtek/base-files/lib/preinit/86_mount_jffs2_log

echo "=== セットアップ完了 ==="
grep -r "sks8300-12x-v2" target/linux/realtek/
