# 03 struct bregs：一张寄存器全家福

出处：`seabios/src/bregs.h:18-35`

## 1. 先看原文

```c
// UREG 宏：让同一个 32 位寄存器能按 32/16/8 位三种视图访问
#define UREG(ER, R, RH, RL) union { u32 ER; struct { u16 R; u16 R ## _hi; }; struct { u8 RL; u8 RH; u8 R ## _hilo; u8 R ## _hihi; }; }

// Layout of registers passed in to irq handlers.  Note that this
// layout corresponds to code in romlayout.S - don't change it here
// without also updating the assembler code.
struct bregs {
    u16 ds;
    u16 es;
    UREG(edi, di, di8u, di8l);
    UREG(esi, si, si8u, si8l);
    UREG(ebp, bp, bp8u, bp8l);
    UREG(ebx, bx, bh, bl);
    UREG(edx, dx, dh, dl);
    UREG(ecx, cx, ch, cl);
    UREG(eax, ax, ah, al);
    struct segoff_s code;   // 压栈时的返回 CS:IP
    u16 flags;
} PACKED;
```

（引用自 bregs.h:18-35，注释保留原文。）

## 2. UREG 宏在做什么？

展开 `UREG(eax, ax, ah, al)` 后是：

```c
union {
    u32 eax;                    // 32 位视图
    struct { u16 ax; u16 ax_hi; };  // 16 位视图
    struct { u8 al; u8 ah; ... };   // 8 位视图
};
```

- `union`（联合体）：几个视图**共享同一块 4 字节内存**，正是真 CPU 上 AX/EAX/AL 共存的方式。
- 书中"AX 的高 8 位是 AH、低 8 位是 AL"在这里变成了编译器帮你算好的字节偏移。
- `##` 是 C 宏的记号粘贴：`R ## _hi` 拼出 `ax_hi`。

## 3. 字段顺序就是 push 顺序

对照 `entryfuncs.S:15-25` 的 `PUSHBREGS`：

```text
push 顺序: eax, ecx, edx, ebx, ebp, esi, edi, es, ds
bregs 顺序: ds, es, edi, esi, ebp, ebx, edx, ecx, eax   ← 正好逆序！
```

为什么？栈从高地址往低地址生长：**先压的在栈顶之下**。压完后栈顶是 `ds`，而结构体基地址（低地址）也是 `ds`，所以：

- `regs->eax` 对应 `movl BREGS_eax(%eax), %eax` 这类汇编访问（entryfuncs.S:44-66 中同样用偏移访问）。
- 注释 bregs.h:20-22 强调：**改结构体必须同步改汇编**——布局即 ABI。

`PACKED` 要求编译器去掉对齐填充，否则 AH/AL 的偏移就错了。

## 4. code 与 flags

- `struct segoff_s code;`：中断发生时 CPU 压栈的返回地址（CS:IP），stub 也把它收进结构体，`iret` 前写回。
- `u16 flags;`：EFLAGS 低 16 位。

## 5. 实用小函数

出处 `bregs.h:42-49`：

```c
static inline void
set_cf(struct bregs *regs, int cond)
{
    if (cond)
        regs->flags |= F_CF;    // 置进位标志 CF=1
    else
        regs->flags &= ~F_CF;   // 清 CF
}
```

INT 13 出错时 `set_cf(regs, 1)`、成功时 `set_cf(regs, 0)`——这就是 DOS 程序判断 `jc/jnc` 的来源。汇编里的 `stc/clc` 变成了 C 里的一行。

## 6. 和书对应

- 寄存器组=一本书反复说的 AX/BX/CX/DX…，这里成了结构体。
- "中断返回后寄存器被处理程序修改"= C 指针修改 `regs`。
- 高低 8 位视图 = union。
