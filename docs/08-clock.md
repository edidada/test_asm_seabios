# 08 时钟、RTC 与定时器

对应代码 commit：`28aa46349b97ef0ebf742ae4fb9f9fad03578670`

## 1. PIT 与 TSC 基础（seabios/src/hw/timer.c）

- `timer_setup()`：hw/timer.c:102 — POST 时校准 TSC 与 PIT。
- `pit_setup()`：hw/timer.c:274 — 配置 8254 PIT。

## 2. RTC 与 INT 08/1A（seabios/src/clock.c）

| 功能 | 函数 | 行号 |
|---|---|---|
| 模块初始化 | `clock_setup()` | clock.c:33 |
| INT 1A 分发 | `handle_1a()` | clock.c:263 |
| AH=00 读日计数/秒 | `handle_1a00` | clock.c:70 |
| AH=01 设置日计数 | `handle_1a01` | clock.c:83 |
| AH=02 读 RTC 时间 | `handle_1a02` | clock.c:95 |
| AH=03 设置 RTC 时间 | `handle_1a03` | clock.c:113 |
| AH=04 读 RTC 日期 | `handle_1a04` | clock.c:143 |
| AH=05 设置日期 | `handle_1a05` | clock.c:160 |
| AH=06 设置闹钟 | `handle_1a06` | clock.c:191 |
| AH=07 取消闹钟 | `handle_1a07` | clock.c:224 |
| RT(实时) 兜底 | `handle_1aXX` | clock.c:256 |
| 日计数更新 | `clock_update()` | clock.c:282 |
| INT 08（PIT IRQ0） | `handle_08()` | clock.c:303 |
| 轮询 IRQ | `clock_poll_irq()` | clock.c:321 |
| INT 70（RTC 闹钟 IRQ8） | `handle_70()` | clock.c:458 |

## 3. 其他 INT 15 时间服务

- AH=86 等待微秒：`handle_1586()` clock.c:394。
- AH=83 设置用户等待：`handle_158300` clock.c:415、取消 `handle_158301` clock.c:427、兜底 `handle_1583XX` clock.c:434、分发 `handle_1583` clock.c:441。

## 4. 依赖链

```text
PIT 8254 (hw/timer.c:274)
   │  IRQ0
   ▼
INT 08 stub (romlayout.S:674-675)
   │
   ▼
handle_08 (clock.c:303) → clock_update (clock.c:282) → 日计数/用户定时器
   │
   ▼
INT 1A 服务 (clock.c:70-256) ← OS 调用
```

RTC 芯片访问在 `seabios/src/hw/rtc.c`（90 行），CMOS 读写也是它；POST 里的 CMOS 重启原因码见 `seabios/src/post.c:296`（`rtc_write(CMOS_RESET_CODE, 0)`）。

## 5. 与王爽书的对应

- INT 1A AH=00（clock.c:70）＝书中 BIOS 例程“读取日时钟”。
- `handle_08()`（clock.c:303）＝硬件定时中断处理，可对照第 15 章中断实验。
- `handle_1586`（clock.c:394）演示“用循环/端口实现延时”，对应书中 delay 例程的工业实现。
