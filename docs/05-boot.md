# 05 启动选择与 INT 19

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. 启动条目的数据结构

- `struct bootentry_s`：`seabios/src/boot.c:503`，含优先级、类型、描述、回调数据。
- 注册核心：`bootentry_add()` boot.c:525。

## 2. 各类启动项注册（boot.c）

| 函数 | 行号 | 说明 |
|---|---|---|
| `boot_init()` | boot.c:466 | 读 fw_cfg 里 QEMU 配置的启动顺序 |
| `boot_add_bev()` | boot.c:569 | Option ROM 的 BEV（引号启动向量） |
| `boot_add_bcv()` | boot.c:579 | Option ROM 的 BCV（INT 13 驱动） |
| `boot_add_floppy()` | boot.c:587 | 软驱 |
| `boot_add_hd()` | boot.c:594 | 硬盘 |
| `boot_add_cd()` | boot.c:601 | 光驱 |
| `boot_add_cbfs()` | boot.c:619 | CBFS 中的 payload |

## 3. 启动菜单

- `interactive_bootmenu()`：`seabios/src/boot.c:695`，`maininit()` 在 post.c:224 调用。
- 允许用户按键调整顺序，然后 `prepareboot()`（post.c:228）锁定最终顺序。

## 4. INT 19：真正开始引导

`maininit` 尾部 `startBoot()`（post.c:183，调用点 post.c:234）→ `entry_19`（romlayout.S:576）→ `handle_19()`（boot.c:1041）→ `do_boot(0)`（boot.c:987）。

`do_boot()` 按 bootentry 链表顺序逐个尝试：

| 引导方式 | 函数 | 行号 |
|---|---|---|
| 硬盘/软盘（INT 19 直接跳 MBR） | `boot_disk()` | boot.c:882 |
| 光驱（El Torito） | `boot_cdrom()` | boot.c:921 |
| CBFS payload | `boot_cbfs()` | boot.c:947 |
| Option ROM（BEV） | `boot_rom()` | boot.c:957 |
| 全部失败 | `boot_fail()` | boot.c:967（打印 "No bootable device"） |

INT 18（ BASIC / 回退）是 `handle_18()`：boot.c:1031。

## 5. 与王爽书的对应

- `boot_disk()`（boot.c:882）即“读 0 盘 0 道 1 扇区并校验 0x55AA”的工程版，对应书中 7.4 节 MBR 实验；`checksig` 参数就是 55AA 校验开关。
- `do_boot()`（boot.c:987）把 CPU 控制权交给引导扇区，对应书中 `jmp far` 转移执行权。
- 王爽书里 INT 19 是“重启”概念，SeaBIOS 把它做成完整的状态机。

## 6. 源码阅读建议

从 `do_boot()`（boot.c:987）往下读，每个 `boot_xxx` 都很短，再对照 README 的 QEMU 日志（第六章 isa-debugcon）看 SeaBIOS 实际选择哪个条目。
