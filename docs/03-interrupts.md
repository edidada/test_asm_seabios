# 03 中断服务：向量表与 INT 13/15/16/1A 分发

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. 入口在汇编，逻辑在 C

SeaBIOS 的中断处理遵循统一模式：

1. 汇编入口（`romlayout.S` / 固定地址）用宏生成 stub；
2. stub 保存寄存器到 `bregs` 结构；
3. 切到 32 位调用 C 分发函数 `handle_XX(struct bregs *regs)`；
4. 按 `regs->al/ah` 等再分发给子功能函数。

关键宏都在 `seabios/src/entryfuncs.S`：

- `ENTRY_INTO32`（entryfuncs.S:153）：保存 16 位现场并进入 32 位平面 C 函数。
- `DECLFUNC`（entryfuncs.S:162）：声明 16 位入口符号。

## 2. romlayout.S 的固定入口

传统 BIOS 要求部分中断入口位于固定物理地址（兼容旧程序硬编码），`seabios/src/romlayout.S:584-690`：

| 固定地址 | 入口 | 行号 |
|---|---|---|
| 0xe05b | `entry_post` | romlayout.S:594 |
| 0xe3fe | `entry_13_official` → `jmp entry_13` | romlayout.S:605-608 |
| 0xe6f2 | `entry_19_official` → `jmp entry_19` | romlayout.S:612-615 |
| 0xe739 | INT 14（串口） | romlayout.S:621-622 |
| 0xe82e | INT 16（键盘） | romlayout.S:624-625 |
| 0xe987 | INT 09（键盘中断） | romlayout.S:627-628 |
| 0xf859 | INT 15 | romlayout.S:658-663 |
| 0xfe6e | INT 1A | romlayout.S:667-672 |
| 0xfea5 | INT 08（时钟） | romlayout.S:674-675 |
| 0xfff0 | `reset_vector` | romlayout.S:687-690 |

## 3. 硬中断入口

`DECL_IRQ_ENTRY` 宏（romlayout.S:543）生成硬件 IRQ stub，实例见 romlayout.S:566-572（IRQ 13/76/70/74/75/hwpic1/hwpic2）。

PS2 相关硬中断在 `seabios/src/hw/ps2port.c`：`handle_74`（鼠标 IRQ12）ps2port.c:364、`handle_09`（键盘 IRQ1）ps2port.c:391。

## 4. C 端分发函数

按“主功能 → 子功能”两级命名：

- INT 13：`handle_13` 在 `seabios/src/disk.c:621`（`disk_13`），子功能如 `disk_1302`（读扇区）disk.c:226、`disk_1348`（读驱动器参数）disk.c:551。详见 [04-disk.md](04-disk.md)。
- INT 15：`handle_15` 在 `seabios/src/system.c:335`，子功能如 `handle_15e820`（内存表）system.c:290、`handle_1587`（切换保护模式）system.c:72。
- INT 16：`handle_16` 在 `seabios/src/kbd.c:246`，子功能 `handle_1600`（读键）kbd.c:117、`handle_1601` kbd.c:124、`handle_1602`（读状态）kbd.c:131。
- INT 1A：`handle_1a` 在 `seabios/src/clock.c:263`，如 `handle_1a00`（读 RTC）clock.c:70。
- INT 10：`handle_10` 在 `seabios/vgasrc/vgabios.c:1101`（VGA BIOS 独立编译）。详见 [07-vga-console.md](07-vga-console.md)。

## 5. bregs：汇编→C 的参数包

`seabios/src/bregs.h` 定义 `struct bregs`，即所有 16 位寄存器快照。每个 `handle_XXXX` 第一参数都是它，等价于书中的“INT 处理程序从栈里取寄存器”，只是 SeaBIOS 用结构体+宏（`SET_LOWFLAT` 等）更系统化。

## 6. 与王爽书对应

- INT 16 读键盘（kbd.c:117-190）＝书中第 17 章键盘输入。
- INT 13 读扇区（disk.c:226-246）＝书中第 13 章磁盘读写。
- INT 15/INT 1A 在书里是 BIOS 例程扩展，这里能看到完整工业实现。
