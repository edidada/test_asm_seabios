# SeaBIOS 文档索引

本系列文档基于 `seabios/` 子模块锁定的代码讲解：

- Commit: `28aa46349b97ef0ebf742ae4fb9f9fad03578670`
- 原因: `clext: leave the hardware cursor off and at 32x32 after a mode set`

所有 `文件:行号` 引用均对照该 commit 下的源码，例如 `seabios/src/post.c:321`。

## 篇目

| 文件 | 主题 |
|---|---|
| [01-startup-flow.md](01-startup-flow.md) | 从复位到 C 代码：POST 启动流程 |
| [02-memory.md](02-memory.md) | 内存探测、e820、malloc 与 ROM shadow |
| [03-interrupts.md](03-interrupts.md) | 中断向量表与 INT 13/15/16/1A 分发 |
| [04-disk.md](04-disk.md) | INT 13 磁盘服务与块设备驱动 |
| [05-boot.md](05-boot.md) | 启动设备选择与 INT 19 |
| [06-usb-input.md](06-usb-input.md) | USB/PS2/键盘/鼠标 |
| [07-vga-console.md](07-vga-console.md) | VGA/串口控制台/bootsplash |
| [08-clock.md](08-clock.md) | 时钟、RTC 与定时器 |
| [09-firmware-tables.md](09-firmware-tables.md) | PCI/ACPI/SMBIOS/MPTable/PIR 等固件表 |
| [10-runtime.md](10-runtime.md) | 运行时基础设施（栈/线程/输出/PM） |

## 相关仓库文件

- `build-seabios.sh`：编译脚本（根目录）
- `.github/workflows/build.yml`：CI 编译并上传 `bios.bin`
- 上篇 README 讲 QEMU + GDB 调试方法
