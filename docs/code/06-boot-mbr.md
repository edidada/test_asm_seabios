# 06 案例三：读 MBR、校验 0x55AA、交出控制权

对应书：7.4 节「第一个引导扇区」实验。

## 1. INT 19 的入口

`startBoot`（post.c:183）→ 跳板 `entry_19`（romlayout.S:575-577，`ENTRY_INTO32 _cfunc32flat_handle_19`）→ `handle_19`（boot.c:1041）→ `do_boot(0)`（boot.c:987）。

## 2. handle_19 / handle_18：重启与重试

出处 `seabios/src/boot.c:1027-1046`：

```c
int BootSequence VARLOW = -1;          // ① 全局变量：当前试到第几个设备

// Boot Failure recovery: try the next device.
void VISIBLE32FLAT
handle_18(void)                        // INT 18：换下一个设备再试
{
    debug_enter(NULL, DEBUG_HDL_18);
    int seq = BootSequence + 1;
    BootSequence = seq;
    do_boot(seq);                      // seq+1 递增
}

// INT 19h Boot Load Service Entry Point
void VISIBLE32FLAT
handle_19(void)                        // INT 19：从头开始
{
    debug_enter(NULL, DEBUG_HDL_19);
    BootSequence = 0;
    do_boot(0);
}
```

- ① `VARLOW` 宏表示存放在低端 1MB 的变量（重启后仍可访问），这是「用内存单元跨阶段传递状态」的实战版。
- INT 18 传统语义是"无系统，回 BASIC"，SeaBIOS 把它改造成**重试下一个启动设备**。

## 3. do_boot：按表逐个尝试

出处 `seabios/src/boot.c:987-1025`（节选）：

```c
do_boot(int seq_nr)
{
    if (! CONFIG_BOOT)
        panic("Boot support not compiled in.\n");

    if (seq_nr >= BEVCount)
        boot_fail();                       // 试完了都不行

    // Boot the given BEV type.
    struct bev_s *ie = &BEV[seq_nr];       // 取第 seq_nr 个启动项
    switch (ie->type) {
    case IPL_TYPE_FLOPPY:
        printf("Booting from Floppy...\n");
        boot_disk(0x00, CheckFloppySig);   // 软驱盘号 0x00
        break;
    case IPL_TYPE_HARDDISK:
        printf("Booting from Hard Disk...\n");
        boot_disk(0x80, 1);                // 硬盘盘号 0x80
        break;
    case IPL_TYPE_CDROM:
        boot_cdrom((void*)ie->vector);
        break;
    case IPL_TYPE_CBFS:
        boot_cbfs((void*)ie->vector);
        break;
    case IPL_TYPE_BEV:
        boot_rom(ie->vector);              // 网卡/SCSI ROM 的启动向量
        break;
    case IPL_TYPE_HALT:
        boot_fail();
        break;
    }

    // Boot failed: invoke the boot recovery function
    struct bregs br;
    memset(&br, 0, sizeof(br));
    br.flags = F_IF;
    call16_int(0x18, &br);                 // ② 失败 → INT 18 换设备
}
```

- `0x00`/`0x80` 就是书中 DL 的软盘/硬盘盘号——真实 BIOS 也这么编码。
- ② C 里**主动触发中断**：把一个 `struct bregs` 当参数构造好（`br.flags = F_IF` 保证中断里 IF=1），`call16_int(0x18, &br)` 相当于 `int 18h`。这解释了 docs/code/03-bregs.md 里结构体的用途——它既可以"收"，也可以"发"。

## 4. boot_disk：BIOS 自己也用 INT 13 读盘

出处 `seabios/src/boot.c:882-908`（节选）：

```c
boot_disk(u8 bootdrv, int checksig)
{
    u16 bootseg = 0x07c0;                  // ① MBR 约定加载段

    // Read sector
    struct bregs br;
    memset(&br, 0, sizeof(br));            // 清零
    br.flags = F_IF;
    br.dl = bootdrv;                       // DL = 盘号
    br.es = bootseg;                       // ES:BX = 0x07C0:0000 = 物理地址 0x7C00
    br.ah = 2;                             // AH=2 读扇区
    br.al = 1;                             // 读 1 扇区
    br.cl = 1;                             // 从第 1 扇区开始
    call16_int(0x13, &br);                 // 发 INT 13

    if (br.flags & F_CF) {                 // CF=1 读失败
        printf("Boot failed: could not read the boot disk\n\n");
        return;
    }

    if (checksig) {                        // ② 校验 0x55AA
        struct mbr_s *mbr = (void*)0;
        if (GET_FARVAR(bootseg, mbr->signature) != MBR_SIGNATURE) {
            printf("Boot failed: not a bootable disk\n\n");
            return;
        }
    }
    ...
}
```

新手逐点：

- ① `0x07C0:0000` = 物理地址 `0x7C00`，即书中 7.4 节「引导扇区约定加载到 0x7C00」。BIOS 自己读 MBR 时也遵守这个约定。
- ② `GET_FARVAR(bootseg, mbr->signature)`：读 0x7C00+签名偏移处的两个字节，与 `MBR_SIGNATURE`（0xAA55）比较。你在书里写 `cmp word [0x7c00+510], 0xAA55` 的那一步，变成了 C 的一行。
- 读失败/签名错都不跳转，返回后 `do_boot` 落到 `call16_int(0x18,...)` 换下一个设备——所以 QEMU 无盘启动时你会看到 "No bootable device"。

## 5. 之后发生什么

`boot_disk` 尾部构造 FAR JUMP 到 `0x07C0:0000`，把 CS:IP 交给 MBR——就是书中「引导扇区最后 `jmp 0:7c00h` 控制权转移」的反向操作。之后 CPU 全听引导扇区的，BIOS 使命结束（除 INT 服务外）。

## 6. 和书对应表

| 书中 | 代码 |
|---|---|
| 0x7C00 约定 | boot.c:884 `u16 bootseg = 0x07c0` |
| 55AA 校验 | boot.c:902-907 |
| DL=80h 硬盘 / 00h 软盘 | boot.c:1000/1004 |
| 读完校验失败就报错 | boot.c:897-907 |
| 控制权转移 | boot_disk 尾部 far jump |

## 7. 动手实验

QEMU 挂你自己的 MBR（书 7.4 的代码），`-s -S` 后在 `disk.c:226`（disk_1302）断点，单步观察 `br.es=0x07c0`、`br.cl=1` 的参数包，再在 boot.c:904 观察 0x55AA 校验。你就完成了一次「BIOS 视角」的引导实验。
