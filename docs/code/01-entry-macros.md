# 01 入口宏：汇编世界和 C 世界的桥

出处：`seabios/src/entryfuncs.S`（150 行，全是 GNU 汇编 `.macro` 宏）

新手第一个问题：BIOS 用汇编写？不全是。SeaBIOS 的策略是——**汇编只负责"门口"，进门后全是 C**。本篇讲解门口的宏。

## 1. PUSHBREGS / POPBREGS：对称的保存恢复

出处 `entryfuncs.S:15-25` 和 `entryfuncs.S:28-38`：

```asm
        .macro PUSHBREGS        ; 保存寄存器（顺序和 struct bregs 一致）
        pushl %eax
        pushl %ecx
        pushl %edx
        pushl %ebx
        pushl %ebp
        pushl %esi
        pushl %edi
        pushw %es
        pushw %ds
        .endm

        .macro POPBREGS         ; 从栈里恢复（逆序！）
        popw %ds
        popw %es
        popl %edi
        popl %esi
        popl %ebp
        popl %ebx
        popl %edx
        popl %ecx
        popl %eax
        .endm
```

逐点讲解：

- `.macro 名字 ... .endm`：定义"文本替换"式的宏，等价书里用 `%macro` 写的宏（王爽书第 9 章）。
- 指令后缀 `l` = 32 位（long），`w` = 16 位（word）。`pushl %eax` 压 32 位 EAX；`pushw %es` 压 16 位段寄存器。
- `PUSHBREGS` 依次压入 ax,cx,dx,bx,bp,si,di,es,ds；`POPBREGS` 必须**倒序**弹出——这就是书中讲的"栈后进先出"。

## 2. ENTRY：最小限度调用 C 函数

出处 `entryfuncs.S:77-96`：

```asm
        .macro ENTRY cfunc
        cli                     ; 关中断，防止 C 执行一半被打断破坏栈
        cld                     ; 清方向标志，让串指令正向（C 编译器约定）
        pushl %eax              ; 保存 C 会弄脏的寄存器
        pushl %ecx
        pushl %edx
        pushw %es
        pushw %ds
        movw %ss, %ax           ; 把 SS 拷到 DS —— ①
        movw %ax, %ds           ;   （16 位不能 mov ss, ds 直接拷段，借 AX 中转）
        pushl %esp              ; 备份 ESP
        movzwl %sp, %esp        ; 把 ESP 高 16 位清零 —— ②
        calll \cfunc            ; 调用 C 函数（宏参数）
        popl %esp               ; 恢复 ESP
        popw %ds
        popw %es
        popl %edx
        popl %ecx
        popl %eax
        .endm
```

新手要懂的四个点：

- ① 段寄存器之间不能直接 `mov`，必须经通用寄存器中转——书中"段寄存器不能作为数据目标"的真实用法。
- ② `movzwl %sp, %esp`：零扩展（z=zero, w→l），因为 C 函数假定 `SP` 始终在 64KB 段内。
- `cli/cld`：C 代码不可重入且期望方向标志为 0，所以进门前关中断、清 DF。
- `\cfunc`：宏参数展开成实际 C 符号，如 `_cfunc16_handle_16`。

## 3. ENTRY_ARG：把寄存器打包传给 C

出处 `entryfuncs.S:102-114`。与 ENTRY 的区别：它不丢寄存器，而是把**全部寄存器**按 `struct bregs` 布局压栈，然后把栈指针当作参数传给 C：

```asm
        PUSHBREGS               ; 把所有寄存器压栈（=在栈上构造 struct bregs）
        movw %ss, %ax
        movw %ax, %ds
        movl %esp, %ebx         ; 备份栈指针
        movzwl %sp, %esp
        movl %esp, %eax         ; EAX = 栈顶地址 = struct bregs 的地址
        calll \cfunc            ; C 函数收到 &bregs，想改哪个寄存器就改哪个
        movl %ebx, %esp         ; 栈指针复位到 bregs 起始
        POPBREGS                ; 弹回所有寄存器（C 里的修改生效！）
```

这是整个 SeaBIOS 的核心魔法：**C 函数通过指针修改结构体 = 汇编层面修改寄存器**。INT 服务改 `regs->al` 后，POPBREGS 一弹，AH/AL 就真的变了。

## 4. ENTRY_INTO32：彻底换世界

出处 `entryfuncs.S:153-159`：

```asm
        .macro ENTRY_INTO32 cfunc
        xorw %dx, %dx
        movw %dx, %ss           ; SS = 0（重建栈段）
        movl $BUILD_STACK_ADDR, %esp  ; ESP 指向编译时定好的大栈
        movl $\cfunc, %edx      ; 目标 C 函数放进 EDX
        jmp transition32        ; 跳去切换保护模式，然后 call EDX
        .endm
```

- `xorw %dx, %dx`：自己与自己异或 = 清零，比 `mov dx,0` 短，是真实工程惯例。
- 16 位入口（如 INT 19）不需要"回来"，一去不返，所以可以重建栈、直切 32 位。

## 5. 和书对应

| 书中知识 | 这里的实现 |
|---|---|
| 宏 `%macro ... %endmacro` | `.macro ... .endm` |
| 栈 LIFO、push/pop 对称 | PUSHBREGS/POPBREGS |
| 段寄存器不可直接传送 | `movw %ss, %ax; movw %ax, %ds` |
| INT 前保存现场 | PUSHBREGS |
| 中断返回恢复现场 | POPBREGS |
