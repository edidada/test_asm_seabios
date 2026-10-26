# 新手向：逐行读 SeaBIOS 代码

本系列面向刚学完王爽《汇编语言》的读者，目标是用 SeaBIOS 的真实代码把书里的知识点「见工业版」。

前提：

- 你会书中的基础指令：`mov`、`push/pop`、`jmp/call/ret`、`int/iret`、段寄存器概念。
- 不必先懂 C，出现 C 代码时会逐行解释。
- 所有引用基于子模块锁定的 commit `28aa46349b97ef0ebf742ae4fb9f9fad03578670`。

## 阅读顺序

| 文件 | 内容 | 预备知识 |
|---|---|---|
| [01-entry-macros.md](01-entry-macros.md) | 最先读的汇编宏：保存寄存器、进入 C | push/pop、栈 |
| [02-int-entry-to-c.md](02-int-entry-to-c.md) | INT 中断从汇编入口到 C 分发 | int/iret、中断向量表 |
| [03-bregs.md](03-bregs.md) | bregs 结构：汇编↔C 的"寄存器快照" | 结构体（可选） |
| [04-int16-keyboard.md](04-int16-keyboard.md) | 完整案例：INT 16 读键盘 | 书第 17 章 |
| [05-int13-disk.md](05-int13-disk.md) | 完整案例：INT 13 读扇区/CHS→LBA | 书第 13 章 |
| [06-boot-mbr.md](06-boot-mbr.md) | 完整案例：读 MBR、校验 0x55AA | 书 7.4 节 |

## 约定

- 引用格式 `文件:行号`，相对 `seabios/` 目录。
- 代码片段上方注明出处；讲解按行号顺序。
- 新手只需跟着系列顺序读，遇到不懂的指令就查书附录。
