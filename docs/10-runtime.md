# 10 运行时基础设施：栈、线程、yield 与 resume

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. 协作式线程（seabios/src/stacks.c，689 行）

SeaBIOS 用极简协作调度器让慢速硬件初始化（如 NVMe 探测）不阻塞 INT 服务：

| 功能 | 行号 |
|---|---|
| 让出 CPU `yield()` | stacks.c:625 |
| IRQ 线程让出 `yield_toirq()` | stacks.c:651 |
| 进 preempt 区 `start_preempt()` | stacks.c:701 |
| 让出 preempt `yield_preempt()` | stacks.c:738 |
| 检查抢占 `check_preempt()` | stacks.c:746 |

调用约定（call16/切换大实模式）也在这里与 `seabios/src/entryfuncs.S` 配合。

## 2. 代码分段机制（seabios/src/entryfuncs.S、farptr.h）

- `ENTRY_INTO32` entryfuncs.S:153：16 位入口 → 32 位 C。
- `DECLFUNC` entryfuncs.S:162：入口符号声明。
- `src/code16gcc.s`：1 行，把 .text16 段标 16 位，使 GCC 生成实模式代码。
- far 指针访问：`seabios/src/farptr.h`（186 行）。

## 3. Resume / 重启

- `entry_resume` 从 `entry_post` 分支进入（romlayout.S:596）。
- C 端：`handle_resume()` `seabios/src/resume.c:23-24`，区分 `status`（suspend vs reboot）。
- 32 位部分：`handle_resume32()` resume.c:146-147。

## 4. Option ROM 执行（src/optionroms.c，435 行）

| 功能 | 行号 |
|---|---|
| 单个 ROM 初始化/校验 | `init_optionrom()` optionroms.c:126 |
| fw_cfg 文件形式 ROM | `run_file_roms()` optionroms.c:190 |
| POST 中扫描 PCI/VGA | `optionrom_setup()` optionroms.c:364 |
| VGA ROM | `vgarom_setup()` optionroms.c:451 |

Option ROM 的 PMM 调用见 [02-memory.md](02-memory.md)（pmm.c:134）。

## 5. 日志与错误

- `dprintf`（output.h 声明）：所有模块用它打日志，级别由 Kconfig `Debug level` 决定。
- `panic()` output.c:331：致命错误，QEMU 里见 "SeaBIOS (version ...) ... panic"。

## 6. 与王爽书的对应

- `yield()`（stacks.c:625）＝书中“用循环+标志实现简单调度”的成熟版。
- `entryfuncs.S:153` 的现场保存/切换＝书中中断返回时恢复寄存器的思路。
- `handle_resume()`（resume.c:23）＝书中“用内存单元判断冷/热启动”。

## 7. 全局结构小结

```text
reset_vector (romlayout.S:690)
   → entry_post (594)
      → handle_post (post.c:321)
         → dopost (304) → reloc_preinit (255) → maininit (197)
            → device_hardware_setup (127)
            → optionrom_setup (optionroms.c:364)
            → interactive_bootmenu (boot.c:695)
            → startBoot (post.c:183) → handle_19 (boot.c:1041) → do_boot (987)
```

外加常驻服务：INT 13/15/16/1A/10（docs 03/04/06/07/08）。
