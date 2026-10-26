# README
可以。SeaBIOS 完全可以在 QEMU 中运行、单步调试，甚至查看 CPU 从复位入口开始执行的汇编指令。

而且，SeaBIOS + QEMU + GDB 是学习 x86 BIOS 启动过程非常合适的组合。

你可以做到：

1. 编译 SeaBIOS 源代码，生成 BIOS 固件镜像。
2. 使用 QEMU 模拟 x86 CPU、内存和主板。
3. 使用 GDB 连接 QEMU，查看 CPU 寄存器。
4. 从 CPU 复位入口开始单步执行汇编。
5. 在 SeaBIOS 的 C 函数中设置断点。
6. 修改 SeaBIOS 源代码，重新编译并观察启动行为。

## 一、SeaBIOS + QEMU + GDB 架构

```text
              Linux 主机
                  │
       ┌──────────┴──────────┐
       │                     │
       ▼                     ▼
  SeaBIOS 源代码          GDB 调试器
       │                     │
       ▼                     │
   GCC + Make                │
       │                     │
       ▼                     │
    bios.bin                 │
       │                     │
       ▼                     │
  ┌─────────────────────────────┐
  │            QEMU             │
  │                             │
  │   x86 CPU                   │
  │   ├── AX / BX / CX / DX      │
  │   ├── CS / IP               │
  │   ├── CR0 / CR3             │
  │   └── EFLAGS               │
  │                             │
  │   RAM                       │
  │   BIOS ROM                  │
  │   PCI / VGA / IDE           │
  │                             │
  │   SeaBIOS 正在执行          │
  └─────────────────────────────┘
```

QEMU 模拟硬件，SeaBIOS 作为客户机固件运行，GDB 通过 QEMU 的调试接口控制虚拟 CPU。

与王爽《汇编语言》中的 DOSBox、DEBUG 实验相比，这种方式能够观察更接近实际 PC 固件的启动过程。

## 二、Ubuntu 24.04 实际操作

建议先在 Ubuntu 22.04/24.04 上实验。

### 1. 安装依赖

```bash
sudo apt update

sudo apt install -y \
    git \
    build-essential \
    gcc \
    make \
    python3 \
    nasm \
    gdb \
    binutils \
    libncurses-dev \
    qemu-system-x86
```

### 2. 下载 SeaBIOS 源码

GitHub：

[SeaBIOS 源代码](https://github.com/qemu/seabios?utm_source=chatgpt.com)

```bash
git clone https://github.com/qemu/seabios.git

cd seabios
```

查看源码结构：

```text
seabios/
├── src/
│   ├── romlayout.S
│   ├── entryfuncs.S
│   ├── post.c
│   ├── boot.c
│   ├── disk.c
│   ├── kbd.c
│   └── ...
├── scripts/
├── docs/
└── Makefile
```

特别建议阅读：

- `src/romlayout.S`：BIOS ROM 布局及入口相关汇编。
- `src/entryfuncs.S`：BIOS 入口相关汇编。
- `src/post.c`：BIOS 初始化。
- `src/boot.c`：设备启动和引导流程。

### 3. 编译 SeaBIOS

```bash
make menuconfig
```

选择 QEMU 目标，并根据需要提高 Debug level。

然后：

```bash
make -j$(nproc)
```

生成：

```text
out/bios.bin
out/rom.o
out/rom16.o
```

`bios.bin` 是实际运行的固件镜像，`.o` 文件可以用于 GDB 符号调试。[GitHub](https://github.com/qemu/seabios/blob/master/docs/Build_overview.md?utm_source=chatgpt.com)

---

## 三、QEMU 启动 SeaBIOS

执行：

```bash
qemu-system-x86_64 \
    -machine pc \
    -accel tcg \
    -m 256M \
    -bios out/bios.bin \
    -s \
    -S
```

参数解释：

| 参数 | 作用 |
|---|---|
| `-machine pc` | 模拟传统 PC 平台 |
| `-accel tcg` | 使用 QEMU 软件 CPU 模拟 |
| `-m 256M` | 分配 256MB 内存 |
| `-bios out/bios.bin` | 加载自己编译的 SeaBIOS |
| `-s` | 开启 GDB 调试端口 1234 |
| `-S` | CPU 启动时暂停 |

这里的 `-S` 特别重要。

它可以让 CPU 在执行第一条指令之前暂停，等待 GDB 连接。 [QEMU](https://www.qemu.org/docs/master/system/gdb.html?utm_source=chatgpt.com)

---

## 四、GDB 查看 CPU 第一条指令

打开第二个终端：

```bash
gdb
```

连接 QEMU：

```gdb
set architecture i8086

target remote localhost:1234
```

查看寄存器：

```gdb
info registers
```

重点观察：

```text
CS
EIP
EFLAGS
CR0
```

典型 x86 复位状态中：

```text
CS  = F000
IP  = FFF0
```

复位入口对应的物理地址是：

```text
0xFFFFFFF0
```

这里容易混淆：复位时不能简单地用 `CS × 16 + IP` 计算实际取指地址，因为 CPU 的 CS 隐藏段基址处于特殊复位状态。

继续：

```gdb
x/10i $pc
```

查看当前机器指令。

单步执行：

```gdb
si
```

再次查看：

```gdb
info registers
```

就能观察每条指令执行之后寄存器的变化。

注意，GDB 在 16 位实模式下的地址显示可能存在差异；进入普通实模式后，可以尝试：

```gdb
x/10i ($cs * 16 + ($eip & 0xffff))
```

这是 QEMU 官方文档介绍的实模式调试方法。[GitLab](https://qemu-project.gitlab.io/qemu/system/gdb.html?utm_source=chatgpt.com)

---

## 五、如何调试 SeaBIOS 的 C 源代码？

SeaBIOS 不仅能调试汇编，还能进行源码级调试。

例如：

```bash
gdb out/rom.o
```

连接：

```gdb
target remote localhost:1234
```

查看函数：

```gdb
info functions
```

但需要注意，SeaBIOS 包含 16 位代码、32 位代码及重定位机制，直接加载 `rom.o` 不一定能正确匹配所有运行时地址。

官方文档针对 16 位代码提供了符号地址调整方法：

```bash
objcopy --adjust-vma 0xf0000 \
    out/rom16.o rom16offset.o
```

GDB：

```gdb
set architecture i8086
target remote localhost:1234
add-symbol-file rom16offset.o 0
```

对于 32 位初始化代码，如果符号因自重定位而错位，可以在构建配置中关闭 `CONFIG_RELOCATE_INIT`。[QEMU Git Repositories](https://qemu.googlesource.com/seabios/%2B/refs/heads/1.10-stable/docs/Debugging.md?utm_source=chatgpt.com)

建议先完成汇编指令级调试，再配置源码级断点。

---

## 六、SeaBIOS 还能打印调试日志

这是实际 BIOS 开发中非常重要的功能。

运行：

```bash
qemu-system-x86_64 \
    -machine pc \
    -accel tcg \
    -bios out/bios.bin \
    -chardev stdio,id=seabios \
    -device isa-debugcon,iobase=0x402,chardev=seabios
```

SeaBIOS 的 `dprintf()` 日志可以通过 QEMU 模拟的调试端口输出。

这样就能观察：

```text
SeaBIOS 启动
    ↓
硬件检测
    ↓
设备初始化
    ↓
启动设备选择
    ↓
加载 Boot Sector
```

也可以修改源码中的日志输出，再重新编译测试。[QEMU Git Repositories](https://qemu.googlesource.com/seabios/%2B/refs/heads/1.10-stable/docs/Debugging.md?utm_source=chatgpt.com)

---

## 七、与王爽《汇编语言》的知识对应关系

| 王爽书中的知识 | SeaBIOS 实际应用 |
|---|---|
| CS:IP | CPU 指令执行位置 |
| SS:SP | 早期栈管理 |
| MOV | 寄存器及内存操作 |
| JMP | BIOS 入口及流程跳转 |
| CALL/RET | 函数调用 |
| PUSH/POP | 保存恢复寄存器 |
| INT | BIOS 中断服务 |
| IRET | 中断返回 |
| 段地址 | 16 位实模式寻址 |
| 内存访问 | BIOS 数据结构和硬件操作 |

特别推荐你重点跟踪这条执行路径：

```text
CPU Reset
    ↓
0xFFFFFFF0
    ↓
SeaBIOS ROM 入口
    ↓
早期汇编初始化
    ↓
SeaBIOS C 初始化代码
    ↓
POST
    ↓
设备初始化
    ↓
Bootloader
    ↓
操作系统
```

### 推荐阅读

- [SeaBIOS 官方网站](https://seabios.org/SeaBIOS?utm_source=chatgpt.com)
- [SeaBIOS 编译文档](https://github.com/qemu/seabios/blob/master/docs/Build_overview.md?utm_source=chatgpt.com)
- [SeaBIOS 官方调试文档](https://qemu.googlesource.com/seabios/%2B/refs/heads/1.10-stable/docs/Debugging.md?utm_source=chatgpt.com)
- [QEMU GDB 调试文档](https://www.qemu.org/docs/master/system/gdb.html?utm_source=chatgpt.com)

我的建议： 先使用 QEMU + GDB，从 `0xFFFFFFF0` 开始单步执行，观察 `CS`、`EIP`、`CR0` 等寄存器的变化。然后进入 SeaBIOS 的 `romlayout.S` 和 `post.c`，把汇编与 C 代码连接起来理解。这比单独学习 DOS 8086 汇编更接近真实 BIOS 固件开发。