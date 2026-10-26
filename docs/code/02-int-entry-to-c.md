# 02 一条 INT 指令的旅程：从汇编入口到 C 分发

以 `int 16h`（读键盘）为例，跟踪它如何变成 C 函数调用。

## 1. 中断向量表里放的什么？

出处 `seabios/src/romlayout.S:560-572`：

```asm
        .macro DECL_IRQ_ENTRY_ARG num   ; 定义 entry_XX 符号
        DECLFUNC entry_\num
        IRQ_ENTRY_ARG \num
        .endm

        .macro IRQ_ENTRY_ARG num
        .global entry_\num
        entry_\num :
        pushl $ handle_\num             ; 压入对应的 C 处理函数地址
        jmp irqentry_arg                ; 跳到公共 stub
        .endm

        // 实例
        DECL_IRQ_ENTRY_ARG 13           ; entry_13 → push handle_13
        DECL_IRQ_ENTRY 76 70 74 75      ; 硬中断系列
        DECL_IRQ_ENTRY hwpic1 hwpic2
```

- `pushl $ handle_\num`：`$` 表示立即数，把 `handle_16` 这样的 **C 函数地址**当作常量压栈。
- 也就是说：向量表里不是直接放 C 地址，而是放一个小跳板 `entry_16`（固定地址入口见 [03-interrupts.md](../03-interrupts.md)）。
- 注意 romlayout.S:574 的注释：INT 18/19 特殊，直接 `ENTRY_INTO32`。

## 2. 公共 stub：irqentry_arg

`irqentry_arg` 及其 32 位切换逻辑也在 entryfuncs.S/romlayout.S 的协作下工作，整体效果是：

1. 中断发生，CPU 自动把 FLAGS/CS/IP 压栈（书中 15.4 节的知识）；
2. 跳板 `entry_16` 再把 `handle_16` 地址压栈；
3. 公共 stub 进入 16 位→32 位切换，用 `SAVEBREGS_POP_DSEAX`（entryfuncs.S:43-53）把寄存器拷贝进 C 结构体；
4. 调用 C：`handle_16(&regs)`。

新手只需记住效果：**`int 16h` ⇔ C 里调用 `handle_16(struct bregs *regs)`，regs 里是全部寄存器快照**。

## 3. C 端两级分发

出处 `seabios/src/kbd.c:246`（主分发）：

```c
// INT 16h entry point.
void
handle_16(struct bregs *regs)   // kbd.c:246
{
    // AH = 功能号
    switch (regs->ah) {
    case 0x00: handle_1600(regs); break;   // 读键盘，kbd.c:117
    case 0x01: handle_1601(regs); break;   // 查缓冲区，kbd.c:124
    case 0x02: handle_1602(regs); break;   // 读移位状态，kbd.c:131
    case 0x05: handle_1605(regs); break;   // 塞键，kbd.c:139
    case 0x09: handle_1609(regs); break;   // kbd.c:146
    ...
    default: handle_16XX(regs); break;     // 不认识的功能，kbd.c:222
    }
}
```

（结构按源码语义简写，帮助理解分发骨架。）

- C 语言 `switch` 正是汇编里 `cmp ah,0 / je ...` 链的语法糖。
- `handle_1600` 等函数名就是 "INT 16 / AH=00" 的编码，扫一眼函数名就等于扫一眼功能表。
- 兜底函数 `handle_16XX` 负责把 AH 设置成"不支持"状态，等价书中 `jmp 不认识的分支处理`。

## 4. 返回

C 函数改完 `regs->al` 等后返回，stub 用 `RESTOREBREGS_DSEAX`（entryfuncs.S:56-67）把结构体内容写回真实寄存器，最后 `iret`。你的 `mov ah,01; int 16h` 拿到的 AH/AL 就这样被填充。

## 5. 和书对应

| 书中 | SeaBIOS |
|---|---|
| 向量表是 `CS:IP` 二字 | 向量表指向汇编跳板，跳板存 C 函数地址 |
| 中断处理程序开头 push 现场 | stub 自动构造 `struct bregs` |
| `int` 后 CPU 压 FLAGS/CS/IP | 一样（CPU 硬件行为不变） |
| 处理程序末尾 `iret` | stub 恢复寄存器后 `iret` |
