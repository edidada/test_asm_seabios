# 02 内存管理：e820、malloc 与 ROM shadow

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. 内存探测

- QEMU 平台：`qemu_preinit()` 在 `seabios/src/fw/paravirt.c:227`，通过 fw_cfg/e820 接口获得宿主给出的内存布局。
- POST 阶段在 `dopost()` 中调用（`seabios/src/post.c:309-311`）。

## 2. e820 内存表

- 结构与操作在 `seabios/src/e820map.c`（共 151 行）：添加/裁剪 e820 range。
- INT 15 E820 服务给 OS 查询：`handle_15e820()` 在 `seabios/src/system.c:290`，分发链 `handle_15e8`（system.c:318）→ `handle_15`（system.c:335）。
- 其他内存查询服务：`handle_15e801`（system.c:260）、`handle_1588`（system.c:170）。

## 3. 内部 malloc：分区与生命周期

SeaBIOS 自带三阶段堆管理，全部在 `seabios/src/malloc.c`：

| 阶段函数 | 行号 | 说明 |
|---|---|---|
| `malloc_preinit()` | malloc.c:413 | POST 早期，按 e820 划分各 zone |
| `malloc_init()` | malloc.c:495 | 初始化运行时 zone |
| `malloc_prepboot()` | malloc.c:531 | 引导前把 tmp/fseg 内存冻结、清理 |

- 分配核心：`malloc_palloc()` malloc.c:236，`malloc_pfree()` malloc.c:273。
- 句柄机制（PMM 用）：`malloc_sethandle()` malloc.c:322、`malloc_findhandle()` malloc.c:335。
- `malloc.h` 里的 `malloc_high()` / `malloc_fseg()` / `malloc_tmp()` 等是不同生命周期 zone 的包装。

## 4. PMM（Post Memory Manager，INT 15 / PMM API）

给 option ROM 用的标准分配接口：

- 入口分发 `handle_pmm()`：`seabios/src/pmm.c:134`
- 功能 0/1/2：`handle_pmm00` pmm.c:29、`handle_pmm01` pmm.c:105、`handle_pmm02` pmm.c:116、非法功能 `handle_pmmXX` pmm.c:128
- 初始化/收尾：`pmm_init()` pmm.c:155、`pmm_prepboot()` pmm.c:167

## 5. ROM shadow：0xc0000-0xfffff 可写切换

POST 期间要把 BIOS 代码搬到 RAM，因此先解锁再锁回：

- Intel 芯片组实现：`make_bios_writable_intel()` `seabios/src/fw/shadow.c:60`，`make_bios_readonly_intel()` shadow.c:78（写 PAM 寄存器）。
- 平台无关入口：`make_bios_writable()` shadow.c:118（POST 时），`make_bios_readonly()` shadow.c:151（`maininit` 尾部 post.c:231 调用）。

对应 README 第四章：GDB 里能在 `0xf0000` 段看到 C 代码正是因为这段 RAM 化的 shadow。

## 6. 汇编角度

- zone 常量地址用 far pointer 访问：`seabios/src/farptr.h`（186 行）提供 `GET_FARVAR/SET_FARVAR`，等价于书中的段:偏移访问。
- e820 表操作本身就是典型的“内存区间管理”练习。
