# 04 案例一：INT 16 读键盘全链路

对应书：第 17 章「键盘缓冲区」。

## 1. 调用链总览

```text
DOS/引导程序        mov ah,0; int 16h
   │
   ▼  中断向量表
entry_16 跳板       romlayout.S（push $handle_16）
   │
   ▼  公共 stub
handle_16(&regs)    kbd.c:246   按 AH 分发
   │
   ├─ AH=0 → handle_1600  kbd.c:117
   │           └→ dequeue_key(regs, 1, 0)   kbd.c:55
   └─ AH=1 → handle_1601  kbd.c:124
               └→ dequeue_key(regs, 0, 0)
```

## 2. C 端：功能号 0 与 1 只差一个参数

出处 `seabios/src/kbd.c:117-127`：

```c
handle_1600(struct bregs *regs)
{
    dequeue_key(regs, 1, 0);    // AH=0：有键才返回（incr=1）
}

// check keyboard status
static void
handle_1601(struct bregs *regs)
{
    dequeue_key(regs, 0, 0);    // AH=1：无键立即返回 ZF=1（incr=0）
}
```

同一个函数读键盘，第二参数 `incr` 决定「等还是不等」。这就是书中 AH=0「等待按键」和 AH=1「检查按键」共用一套实现的典型写法。

## 3. 核心：环形键盘缓冲区

出处 `seabios/src/kbd.c:55-94`（节选并注解）：

```c
dequeue_key(struct bregs *regs, int incr, int extended)
{
    yield();                          // 让其他线程跑一会儿（协作调度）
    u16 buffer_head;
    u16 buffer_tail;
    for (;;) {
        buffer_head = GET_BDA(kbd_buf_head);  // ①
        buffer_tail = GET_BDA(kbd_buf_tail);

        if (buffer_head != buffer_tail)   // 头≠尾 = 有键
            break;
        if (!incr) {                      // AH=1 且没键：
            regs->flags |= F_ZF;          //   置 ZF=1 告知"无键" ②
            return;
        }
        yield_toirq();                    // 等键：让出 CPU 等硬中断 ③
    }

    u16 keycode = GET_FARVAR(SEG_BDA, *(u16*)(buffer_head+0));  // ④
    u8 ascii = keycode & 0xff;            // 低 8 位 = ASCII
    if (!extended) {
        // 处理 0xE0 前缀的扩展键（书 17.3 小节）
        if (ascii == 0xe0 && keycode & 0xff00)
            keycode &= 0xff00;
        else if (keycode == 0xe00d || keycode == 0xe00a)
            keycode = 0x1c00 | ascii;     // 扩展回车 → 标准回车
        else if (keycode == 0xe02f)
            keycode = 0x352f;             // 扩展 '/' → 标准斜杠
    }
    if (ascii == 0xf0 && keycode & 0xff00)
        keycode &= 0xff00;                // 松键前缀处理
    regs->ax = keycode;                   // ⑤ AL=ASCII, AH=扫描码
    ...
}
```

新手逐点：

- ① `GET_BDA(...)`：读 BIOS 数据区（段 0x40）变量，宏展开为 far 访问，见 `seabios/src/std/bda.h`。BDA 的 `kbd_buf_head/tail` 就是书中说的**键盘缓冲区环形队列头尾指针**。
- ② `regs->flags |= F_ZF`：C 里写标志位，对应 DOS 下 `jz` 的判断来源。
- ③ `yield_toirq()`（stacks.c:651）：「等待期间允许硬中断线程运行」——BIOS 版 `hlt` 思路。
- ④ `GET_FARVAR(SEG_BDA, ...)`：等价 `mov ax, es:[bx]` 的远段访问（farptr.h 提供）。
- ⑤ 把 `keycode` 写回 `regs->ax`，POPBREGS 后用户的 AX 真的变了。

## 4. 塞一个键进去：AH=05

出处 `seabios/src/kbd.c:139-142`：

```c
// store key-stroke into buffer
static void
handle_1605(struct bregs *regs)
{
    regs->al = !enqueue_key(regs->cx);   // CX=键值入队，AL=0 表示成功
}
```

`enqueue_key` 在 kbd.c:33，实现「写环形缓冲 + 推进尾指针」。这就是书中 17.4 节实验「模拟键盘输入」的 BIOS 版。

## 5. 动手实验

用 QEMU 跑你自己的引导扇区（书 7.4 实验）：

```asm
mov ah, 0      ; 等待按键
int 16h
; AL = ASCII
```

在 QEMU 里 `gdb` 连接后于 `kbd.c:73`（GET_FARVAR 处）下断点，观察 `buffer_head` 变化——你会亲眼看到环形队列被消费。

## 6. 和书对应表

| 书中 | 代码 |
|---|---|
| 键盘缓冲区 16 字环形队列 | BDA `kbd_buf_head/tail`（bda.h） |
| AH=0 等待按键 | `dequeue_key(regs,1,0)` kbd.c:55 |
| AH=1 查询（ZF 判断） | kbd.c:66-69 置 F_ZF |
| AH=2 读移位状态 | `handle_1602` kbd.c:131-135 |
| 扩展键 0xE0 前缀 | kbd.c:75-89 |
