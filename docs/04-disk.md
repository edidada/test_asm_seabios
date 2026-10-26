# 04 磁盘存储：INT 13 与块设备驱动

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. 分层结构

```text
INT 13 C 分发 (src/disk.c)
        │  统一驱动描述 struct drive_s
        ▼
驱动公共层 (src/block.c: 块请求执行、驱动注册)
        │
        ▼
硬件驱动 (src/hw/: ata/ahci/nvme/virtio/usb-msc/floppy/scsi/sdcard...)
```

## 2. INT 13 分发（seabios/src/disk.c）

- 总入口 `disk_13()`：disk.c:621；非法功能兜底 `disk_13XX()`：disk.c:615。
- 子功能按 `disk_13XX` 命名（XX = AH 值）：

| 功能 | 行号 |
|---|---|
| AH=00 复位 | disk.c:199 |
| AH=01 读上次状态 | disk.c:211 |
| AH=02 读扇区 | disk.c:226 |
| AH=03 写扇区 | disk.c:233 |
| AH=04 校验 | disk.c:240 |
| AH=05 格式化磁道 | disk.c:247 |
| AH=08 读驱动器参数 | disk.c:275 |
| AH=41/42/43/44/45/47/48 扩展服务 | disk.c:409/419/426/433/443/544/551 |
| AH=49 读扩展参数 | disk.c:559 |
| AH=4E CDROM 速度设置 | disk.c:572-612 |

## 3. 块层（seabios/src/block.c）

- `block_setup()`（block.c:508）：POST 时扫描注册所有 `drive_s`（硬盘/软盘/光驱/U盘等），建立 drive 号到描述符的映射。
- INT 13 的磁盘 I/O 最终走这里的统一执行路径。

## 4. 硬件驱动（seabios/src/hw/）

| 驱动 | 文件 | 行数 |
|---|---|---|
| IDE/PATA | hw/ata.c | 921 |
| 软驱 | hw/floppy.c | 705 |
| AHCI/SATA | hw/ahci.c | 644 |
| NVMe | hw/nvme.c | 630 |
| virtio-blk / virtio-scsi | hw/virtio-blk.c / hw/virtio-scsi.c | ~ |
| USB 大容量存储 | hw/usb-msc.c（193）、usb-uas.c（262） | ~ |
| SCSI 控制器 | esp-scsi/lsi-scsi/megasas/mpt-scsi/pvscsi | ~ |
| SD 卡 | hw/sdcard.c | 538 |
| 光盘（El Torito） | src/cdrom.c | 277 |
| 内存盘 | hw/ramdisk.c | 96 |

## 5. 和王爽书的对应

- `disk_1302`（disk.c:226，读扇区）与书中第 13 章 `int 13h` 的 CHS 三元组参数完全一致：`DL=盘号 CL/CH/DH=柱面/磁头/扇区`。
- `disk_1342`（disk.c:419，扩展读）对应 LBA 方式，是 CHS 之上的增强。
- `block_setup()`（block.c:508）展示“设备枚举与注册”如何对应书中的“逻辑扇区号换算”。

## 6. 调试入口

用 QEMU + `-drive` 挂磁盘后，在 `disk_1342`（disk.c:419）下断点，观察 DAP 结构（disk offset packet），见 README 第三章调试方法。
