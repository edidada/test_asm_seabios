# 01 启动流程：从复位向量到 C 代码

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. CPU 复位入口

CPU 上电后从物理地址 `0xFFFFFFF0` 取第一条指令，ROM 里该位置是固定入口：

- `seabios/src/romlayout.S:687-690` — `ORG 0xfff0` 之后的 `reset_vector:`，只有一条 `ljmpw $SEG_BIOS, $entry_post`，跳回 BIOS 段的 `entry_post`。

这就是用 GDB 在 `0xFFFFFFF0` 断下后看到的第一条指令。

## 2. entry_post：区分冷启动与重启

`entry_post` 位于 `0xe05b`（传统 BIOS POST 入口）：

- `seabios/src/romlayout.S:593-597` — `cmpl $0, %cs:HaveRunPost` 判断是否已经跑过 POST：
  - 已跑过（即重启/唤醒）→ 跳 `entry_resume`；
  - 否则 `ENTRY_INTO32 _cfunc32flat_handle_post` 切到 32 位进入 C 函数 `handle_post`。

`ENTRY_INTO32` 宏定义在 `seabios/src/entryfuncs.S:153`，作用是保存 16 位现场并切换到 32 位平面模式后调用 C 函数。

## 3. handle_post → dopost：先准备内存

- `seabios/src/post.c:317-325` — `handle_post()` 注释明确说明：先把 `0xc0000-0xfffff` 变为可写，再调用 `dopost()`。
- `seabios/src/post.c:303-315` — `dopost()` 做三件事：
  1. `code_mutable_preinit()`（post.c:306）
  2. 探测 RAM：`qemu_preinit()`（`seabios/src/fw/paravirt.c:227`）、`coreboot_preinit()`、`malloc_preinit()`（`seabios/src/malloc.c:413`）（post.c:309-311）
  3. `reloc_preinit(maininit, NULL)`（post.c:314）——把 init 段代码搬到 RAM 再调用 `maininit`。

`reloc_preinit` / `updateRelocs` 在 `seabios/src/post.c:254-259`、`243-249`，负责修正重定位偏移，这就是 README 提到的 `CONFIG_RELOCATE_INIT` 相关机制。

## 4. maininit：POST 主体

`seabios/src/post.c:197-235` 的 `maininit()` 按顺序：

| 步骤 | 位置 |
|---|---|
| 接口表初始化 `interface_init()` | post.c:200（定义在 102） |
| 平台硬件 `platform_hardware_setup()` | post.c:203（定义在 138） |
| 可选：optionrom 期间允许线程 `device_hardware_setup()` | post.c:206-207（定义在 127） |
| 加载 VGA ROM 并开控制台 `vgarom_setup()` / `sercon_setup()` / `enable_vga_console()` | post.c:210-212 |
| 设备硬件初始化 `device_hardware_setup()` | post.c:215-218 |
| 加载其余 option ROM `optionrom_setup()` | post.c:221 |
| 启动菜单 `interactive_bootmenu()` | post.c:224 |
| `prepareboot()` | post.c:228 |
| ROM 改回只读 `make_bios_readonly()` | post.c:231 |
| `startBoot()` 即 INT 19 | post.c:234（定义在 183） |

## 5. startBoot → INT 19

`startBoot`（post.c:183）最终通过 `entry_19`（`seabios/src/romlayout.S:576-577`，`ENTRY_INTO32 _cfunc32flat_handle_19`）进入 `handle_19`（`seabios/src/boot.c:1041`），交给 `do_boot()`（boot.c:987）执行真正的引导。详见 [05-boot.md](05-boot.md)。

## 6. 与王爽汇编知识对应

- `ljmpw $SEG_BIOS, $entry_post`（romlayout.S:690）＝远跳转＝段间 JMP，对应书中的段跳转。
- `HaveRunPost`（romlayout.S:595，定义于 `seabios/src/biosvar.h`）是 BIOS 数据区全局标志，对应“用内存变量在程序间传递状态”。
- 16 位入口到 32 位 C 的切换（entryfuncs.S:153）是真实模式→保护模式过渡实例。
