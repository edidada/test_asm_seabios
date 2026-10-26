# 07 视频：VGA BIOS、串口控制台与 bootsplash

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. VGA BIOS 是单独的 ROM

SeaBIOS 里 VGA 部分独立编译成 `vgabios.bin`（QEMU 里作为 option ROM 挂载），位于 `seabios/vgasrc/`：

- 入口 stub：`vgaentry.S` — `entry_10` vgaentry.S:91-92，VBE 模式切换专用入口 `entry_104f05` vgaentry.S:81-82，option ROM 入口 `_optionrom_entry` vgaentry.S:86，定时器钩子 `entry_timer_hook` vgaentry.S:141。
- INT 10 分发：`handle_10()` `vgasrc/vgabios.c:1101`；子功能表按 `handle_10XY` 命名，例如设置模式 `handle_1000` vgabios.c:336、读字符 `handle_1009` vgabios.c:437、写字符串 `handle_1013` vgabios.c:986、VBE 功能 `handle_104f` `vgasrc/vbe.c:493`。
- 主 BIOS 侧的加载函数：`vgarom_setup()` `seabios/src/optionroms.c:451`（post.c:210 调用）、`enable_vga_console()`（post.c:212）。

VGA 硬件后端：`stdvga.c`（标准 VGA）、`bochsvga.c`、`clext.c`（Cirrus）、`geodevga.c`、`ramfb.c`、`cbvga.c`（coreboot 帧缓冲）、`bochsdisplay.c`、`atiext.c`。本 commit 的 tip 就是 clext.c 的光标修复。

## 2. 串口终端 sercon

`seabios/src/sercon.c`（589 行）：把 INT 10 的文本输出镜像到串口，让 SeaBIOS 也能在无显卡环境输出。

- `sercon_setup()`：sercon.c:511（post.c:211 调用）。

## 3. 开机画面 bootsplash

`seabios/src/bootsplash.c`（231 行）：

- `enable_bootsplash()`：bootsplash.c:98 — 通过 `romfile_loadfile("bootsplash.jpg"/"bootsplash.bmp", ...)`（bootsplash.c:106/108）读 fw_cfg 文件，解码 JPEG（src/jpeg.c）或 BMP（src/bmp.c）后写入帧缓冲。
- `disable_bootsplash()`：bootsplash.c:249。

## 4. 文字输出与日志（seabios/src/output.c）

- `printf()`：output.c:370
- `panic()`：output.c:331 — 打印后死循环，QEMU 日志里 SeaBIOS 出错看这里。
- `dprintf(level, fmt, ...)`：声明在 `seabios/src/output.h`，级别 1-8；README 第六章 `Debug level` 即此。

## 5. 字体与代码页

- 点阵字体：`seabios/src/font.c`（137 行）、`vgasrc/vgafonts.c`
- CP437 转换：`seabios/src/cp437.c`（272 行）

## 6. 与王爽书的对应

- INT 10 各功能（vgabios.c:336-1101）＝书中第 10 章“int 10h 中断例程”的全部服务（设模式、光标、字符、滚动）。
- `handle_1000`（vgabios.c:336）就是书中“设置显示模式 AL=3”对应的实现。
- 串口终端（sercon.c:511）演示“输出设备抽象”如何与书中的 I/O 接口编程（第 9 章）呼应。

## 7. 调试

README 第四/六章的 QEMU 调试同样适用于 vgabios.bin：`-device VGA` + `-s -S`，然后 `x/10i $pc` 观察 INT 10 stub。
