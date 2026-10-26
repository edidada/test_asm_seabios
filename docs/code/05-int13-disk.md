# 05 案例二：INT 13 读扇区与 CHS→LBA 换算

对应书：第 13 章「磁盘读写」。

## 1. 调用链总览

```text
引导程序        mov ah,2; mov al,扇区数; int 13h
   │
   ▼
disk_13(&regs)          disk.c:621     选出目标 drive_s
   │
   ▼  按 AH 分发
disk_1302(regs, drive)  disk.c:226     读扇区
   │
   ▼
basic_access(...)       disk.c:120     CHS→LBA、参数检查
   │
   ▼
send_disk_op(&dop)      disk.c:107     派发给具体硬件驱动
```

## 2. AH=02 读扇区：薄壳函数

出处 `seabios/src/disk.c:224-229`：

```c
// read disk sectors
static void
disk_1302(struct bregs *regs, struct drive_s *drive_fl)
{
    basic_access(regs, drive_fl, CMD_READ);
}
```

- AH=03 写扇区（disk.c:233）、AH=04 校验（disk.c:240）也各一行，只是传不同的 `CMD_*`。
- 三个功能共用 `basic_access`，这就是书中「读写扇区参数一样，只是方向不同」的工程写法。
- 第二参数 `drive_fl` 是块层在 `disk_13`（disk.c:621）里按 `DL`（盘号）查到的驱动器描述。

## 3. CHS 怎么变成物理位置

书里反复强调：INT 13 用 CHS 三元组（柱面/磁头/扇区），但磁盘硬件只认 LBA 线性号。看格式化磁道 AH=05 的实现，出处 `seabios/src/disk.c:246-271`：

```c
// format disk track
static void noinline
disk_1305(struct bregs *regs, struct drive_s *drive_fl)
{
    debug_stub(regs);

    struct chs_s chs = getLCHS(drive_fl);        // 取该盘的 CHS 几何
    u16 nlc=chs.cylinder, nlh=chs.head, nls=chs.sector;

    u8 count = regs->al;        // 扇区数      ← 书中 AL
    u8 cylinder = regs->ch;     // 柱面低位    ← 书中 CH
    u8 head = regs->dh;         // 磁头        ← 书中 DH

    if (cylinder >= nlc || head >= nlh || count == 0 || count > nls) {
        disk_ret(regs, DISK_RET_EPARAM);        // 参数非法 → AH=07,C=1
        return;
    }

    struct disk_op_s dop;
    dop.drive_fl = drive_fl;
    dop.command = CMD_FORMAT;
    dop.lba = (((u32)cylinder * (u32)nlh) + (u32)head) * (u32)nls;  // ①
    dop.count = count;
    dop.buf_fl = MAKE_FLATPTR(regs->es, regs->bx);  // ② ES:BX 缓冲区
    int status = send_disk_op(&dop);            // 派发硬件层
    disk_ret(regs, status);                     // 统一设置 AH/CF
}
```

- ① 就是书中 13.2 节「逻辑扇区号换算」公式：

```text
LBA = (柱面 × 总磁头数 + 磁头) × 每磁道扇区数 + 扇区序号
```

  汇编版你需要自己写 `mul`，C 版直接一行乘加。
- ② `MAKE_FLATPTR(ES, BX)`（farptr.h）：把 `ES:BX` 段:偏移合成 32 位线性指针——书中「读出的数据放在 ES:BX 指向的缓冲区」里的 BX 就是它。
- `disk_ret`（同文件内）封装 `set_cf(regs, status)` + `regs->ah = status`，即出错时 `CF=1, AH=错误码`，DOS 代码用 `jc` 捕获（见 docs/code/03-bregs.md 第 5 节）。

## 4. 一个完整的"重置控制器"样例

出处 `seabios/src/disk.c:197-207`：

```c
// disk controller reset
static void
disk_1300(struct bregs *regs, struct drive_s *drive_fl)
{
    struct disk_op_s dop;
    dop.drive_fl = drive_fl;
    dop.command = CMD_RESET;
    dop.count = 0;
    int status = send_disk_op(&dop);
    disk_ret(regs, status);
}
```

新手看懂这 10 行 = 看懂 SeaBIOS 块层接口模板：

1. 造一个请求结构 `disk_op_s`（命令 + 盘 + 缓冲 + 数量）；
2. `send_disk_op`（disk.c:107）转给具体硬件（IDE/AHCI/NVMe/USB…）；
3. `disk_ret` 回填 INT 13 返回值。

## 5. 底下是谁

`send_disk_op` 之后的硬件驱动都在 `seabios/src/hw/`：

| 你挂的 QEMU 设备 | 驱动文件 |
|---|---|
| IDE/PATA | hw/ata.c（921 行） |
| 软驱 | hw/floppy.c（705 行） |
| AHCI | hw/ahci.c（644 行） |
| NVMe | hw/nvme.c（630 行） |
| U 盘 | hw/usb-msc.c（193 行） |

同一份 INT 13 服务，底层驱动不同——这就是「抽象层」的价值。

## 6. 和书对应表

| 书中 | 代码 |
|---|---|
| AH=2/AL=扇区数/CH=柱面/DH=磁头/DL=盘号 | disk.c:254-256 逐个 `regs->al/ch/dh` |
| ES:BX 缓冲区 | `MAKE_FLATPTR(regs->es, regs->bx)` disk.c:268 |
| CHS→逻辑扇区公式 | disk.c:266 |
| 出错 CF=1、AH=错误码 | `disk_ret`/`set_cf`（bregs.h:42） |
| 软驱与硬盘状态分开存 | `disk_1301` disk.c:214-218（`EXTSTART_HD` 分界） |
