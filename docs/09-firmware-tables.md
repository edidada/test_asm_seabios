# 09 固件表：PCI、ACPI、SMBIOS、MPTable、PIR

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

BIOS 除了服务中断，还要给 OS 留下硬件描述表。`seabios/src/fw/` 目录专管这件事，QEMU 通过 fw_cfg（`fw/paravirt.c`）传入预生成表，SeaBIOS 负责放置或补充。

## 1. fw_cfg / romfile 抽象

- 文件注册：`romfile_add()` `seabios/src/romfile.c:16`
- 查找：`romfile_findprefix()` romfile.c:39、`romfile_find()` romfile.c:45
- 读取：`romfile_loadfile()` romfile.c:53、`romfile_loadint()` romfile.c:84
- QEMU 侧枚举入口在 `seabios/src/fw/paravirt.c`（690 行），`qemu_preinit()` paravirt.c:227、`qemu_platform_setup()` paravirt.c:270。

## 2. PCI 初始化（src/fw/pciinit.c，1070 行）

| 步骤 | 函数 | 行号 |
|---|---|---|
| 总线枚举 | `pci_bios_init_bus()` | pciinit.c:653（递归在 570） |
| 设备资源分配 | `pci_bios_init_devices()` | pciinit.c:425（单设备 403） |
| 默认 VGA 启用 | `pci_enable_default_vga()` | pciinit.c:433 |
| 平台挂钩 | `pci_bios_init_platform()` | pciinit.c:521 |
| 最终映射 | `pci_bios_map_devices()` | pciinit.c:1117 |
| 模块入口 | `pci_setup()` | pciinit.c:1185 |

PCI 设备抽象在 `seabios/src/hw/pci.c`（202 行）、`hw/pcidevice.c`（180 行）；INT 1A B1 PCI BIOS 服务在 `seabios/src/pcibios.c:209`（`handle_pcibios`）。

## 3. 各固件表

| 表 | 生成/放置 | 文件 |
|---|---|---|
| ACPI（RSDP/XSDT） | fw_cfg 直传 + 填充 | fw/acpi.c（16）、fw/biostable.c（574）、fw/dsdt_parser.c（614） |
| SMBIOS | fw/smbios.c | 481 行 |
| MPTable | fw/mptable.c | 181 行 |
| PIR（PCI 路由） | fw/pirtable.c | 97 行 |
| SMM | fw/smm.c | 240 行 |
| MTRR | fw/mtrr.c | 93 行 |
| 多路启动（multiboot） | fw/multiboot.c | 104 行 |
| coreboot/xen/csm 平台 | fw/coreboot.c（504）/ fw/xen.c（141）/ fw/csm.c（305） | |
| AP 启动 | `smp_setup()` | fw/smp.c:173 |

## 4. 与王爽书的对应

- `pci_bios_init_devices()`（pciinit.c:425）＝书中第 3 章“端口/内存地址分配”的 PCI 版：BAR 填充。
- `smp_setup()`（fw/smp.c:173）＝书中“多处理器只有 BSP 从复位开始”的实例，AP 被 SIPI 唤醒。
- fw_cfg/romfile（romfile.c:53）＝“BIOS 读配置文件”，等价书中的文件句柄概念但极简。

## 5. QEMU 调试

用 `info qtree`/`info mtree` 对照 `pci_setup()`（pciinit.c:1185）的结果，验证 BAR 分配。
