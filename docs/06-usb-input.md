# 06 输入设备：USB、PS2、键盘与鼠标

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. 设备初始化链

`maininit()` → `device_hardware_setup()`（`seabios/src/post.c:127`，调用点 post.c:207/216）会拉起所有外设驱动，其中就包括 USB 与 PS2。

## 2. USB 子系统（seabios/src/hw/）

| 组件 | 文件 | 要点 |
|---|---|---|
| 总入口 | `hw/usb.c` | `usb_setup()` 在 usb.c:501；`usb_hub_port_setup()` usb.c:420 |
| 控制器 | usb-ehci.c(578) / usb-ohci.c(498) / usb-uhci.c(506) / usb-xhci.c(1071) | 各自 `XXX_init()` 检测 PCI 设备并初始化 |
| HID | usb-hid.c (417) | USB 键盘/鼠标，转成 PS2 风格事件喂给 INT 16 |
| MSC | usb-msc.c (193) | U 盘 → 块设备 |
| UAS | usb-uas.c (262) | 高速 SCSI-over-USB |
| Hub | usb-hub.c (183) | 端口枚举 |

## 3. PS2 底层（seabios/src/hw/ps2port.c）

| 功能 | 行号 |
|---|---|
| 收一个字节 `ps2_recvbyte()` | ps2port.c:157 |
| 发一个字节 `ps2_sendbyte()` | ps2port.c:190 |
| 命令封装 `ps2_command()` | ps2port.c:320 |
| 键盘命令 `ps2_kbd_command()` | ps2port.c:330 |
| 鼠标命令 `ps2_mouse_command()` | ps2port.c:338 |
| 轮询扫描码 `ps2_check_event()` | ps2port.c:421 |
| 键盘端口初始化 `ps2_keyboard_setup()` | ps2port.c:450 |
| 模块初始化 `ps2port_setup()` | ps2port.c:532 |
| 硬中断入口 `handle_74`（鼠标） | ps2port.c:364 |
| 硬中断入口 `handle_09`（键盘） | ps2port.c:391 |

## 4. INT 16 键盘服务（seabios/src/kbd.c）

- 初始化：`kbd_init()` kbd.c:19
- 分发：`handle_16()` kbd.c:246
- 子功能：读键 `handle_1600` kbd.c:117、入队检查 `handle_1601` kbd.c:124、状态字节 `handle_1602` kbd.c:131、扩展键盘 `handle_1610/1611` kbd.c:176/183、移位状态 `handle_1612` kbd.c:190
- 组合键处理：`kbd_set_flag()` kbd.c:395、Ctrl-Break kbd.c:412、SysReq kbd.c:431、PrtScr kbd.c:443

## 5. 鼠标（seabios/src/mouse.c）

INT 15 C2（PS2 鼠标接口），mouse.c 共 306 行；键盘缓冲区在 BDA（`seabios/src/std/bda.h`），INT 16 直接消费它。

## 6. 与王爽书的对应

- INT 16 AH=0/1/2（kbd.c:117-139）＝书中第 17 章“键盘缓冲区”直接实现：`kbd_...` 读环形缓冲区。
- `handle_09`（ps2port.c:391）是硬件键盘中断，即书中第 15 章“按键盘引发 9 号中断”的真实版本。
- `ps2_check_event()`（ps2port.c:421）演示扫描码 → 按键语义的完整转换。

## 7. 调试

在 QEMU 里加 `-chardev stdio` + `-device isa-debugcon`（README 第六章），配合在 `ps2_check_event`（ps2port.c:421）加 dprintf 可观察扫描码流。
