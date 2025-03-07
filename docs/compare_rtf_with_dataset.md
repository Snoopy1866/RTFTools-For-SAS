# %compare_rtf_with_dataset

比较 RTF 文件与 SAS 数据集的内容。

**Compatibility** : RTF 1.6 specification

## 依赖

[transcode](transcode.md) -> [%read_rtf](read_rtf.md) -> [%compare_rtf_with_dataset](compare_rtf_with_dataset.md)

## 语法

### 必选参数

- [rtf](#rtf)
- [dataset](#dataset)

### 可选参数

- [ignore_crlf](#ignore_crlf)
- [ignore_lead_blank](#ignore_lead_blank)
- [ignore_empty_column](#ignore_empty_column)
- [ignore_half_or_full_width](#ignore_half_or_full_width)
- [ignore_embedded_blank](#ignore_embedded_blank)

### 调试参数

- [debug](#debug)

## 参数说明

### rtf

**Syntax** : _path_ | _fileref_

指定 RTF 文件的物理路径或 _filename_ 引用。

> [!IMPORTANT]
>
> - 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 `rtf`。

**Example** :

```sas
rtf = "~\draft\表 7.1.1 受试者入组完成情况.rtf"
```

```sas
filename rtfref "~\draft\表 7.1.1 受试者入组完成情况.rtf";
rtf = rtfref
```

---

### dataset

**Syntax** : <_libname._>_dataset_(_dataset-options_)

指定 SAS 数据集。

_libname_: 数据集所在的逻辑库名称

_dataset_: 数据集名称

_dataset-options_: 数据集选项，兼容 SAS 系统支持的所有数据集选项

指定比较的数据集名称。

**Example** :

```sas
dataset = qc_t_7_1_1
```

---

### ignore_crlf

**Syntax**: `true` | `false`

指定是否忽略 `0D0A`x 字符，其中 `0D`x 表示 `回车`，`0A`x 表示 `换行`，均为不可见的 ASCII 控制字符。

> [!NOTE]
>
> - `kstrip()` 函数无法去除字符串开头和结尾的 `0D0A`x，所以就有了这个参数。

**Default** : `true`

**Example** :

```sas
ignore_crlf = false
```

---

### ignore_lead_blank

**Syntax** : `true` | `false`

指定是否忽略文本的前置空格。

出于缩进的需要，某些单元格内的文本开头可能包含空格，指定 `ignore_lead_blank = true` 时将忽略这些空格。

**Default** : `true`

**Example** :

```sas
ignore_lead_blank = false
```

---

### ignore_empty_column

**Syntax** : `true` | `false`

指定是否忽略空列。

出于格式的需要，某些列可能完全为空，指定 `ignore_empty_column = true` 时将忽略这些列。

**Default** : `true`

**Example** :

```sas
ignore_empty_column = false
```

---

### ignore_half_or_full_width

**Syntax** : `true` | `false`

指定是否忽略字符的半/全角差异。

支持忽略半/全角差异的字符如下表所示：

| 分类                 | 半角字符 | 全角字符                   |
| -------------------- | -------- | -------------------------- |
| 标点符号（不含引号） | `,`      | `，`                       |
|                      | `.`      | `。`                       |
|                      | `?`      | `？`                       |
|                      | `!`      | `！`                       |
|                      | `:`      | `：`                       |
|                      | `;`      | `；`                       |
|                      | `~`      | `～`                       |
| 引号                 | `"`      | `“`, `”`, `〝`, `〞`, `＂` |
|                      | `'`      | `‘`, `’`, `｀`, `＇`, `′`  |
| 括号                 | `(`      | `（`                       |
|                      | `)`      | `）`                       |
|                      | `<`      | `＜`, `〈`                 |
|                      | `>`      | `＞`, `〉`                 |
|                      | `[`      | `［`                       |
|                      | `]`      | `］`                       |
|                      | `{`      | `｛`                       |
|                      | `}`      | `｝`                       |
| 数学符号             | `0`      | `０`                       |
|                      | `1`      | `１`                       |
|                      | `2`      | `２`                       |
|                      | `3`      | `３`                       |
|                      | `4`      | `４`                       |
|                      | `5`      | `５`                       |
|                      | `6`      | `６`                       |
|                      | `7`      | `７`                       |
|                      | `8`      | `８`                       |
|                      | `9`      | `９`                       |
|                      | `+`      | `＋`                       |
|                      | `-`      | `－`                       |
|                      | `*`      | `＊`                       |
|                      | `/`      | `／`                       |
|                      | `\`      | `＼`                       |
|                      | `^`      | `＾`                       |
|                      | `=`      | `＝`                       |
|                      | `%`      | `％`                       |
| 拉丁字母             | `a`      | `ａ`                       |
|                      | `b`      | `ｂ`                       |
|                      | `c`      | `ｃ`                       |
|                      | `d`      | `ｄ`                       |
|                      | `e`      | `ｅ`                       |
|                      | `f`      | `ｆ`                       |
|                      | `g`      | `ｇ`                       |
|                      | `h`      | `ｈ`                       |
|                      | `i`      | `ｉ`                       |
|                      | `j`      | `ｊ`                       |
|                      | `k`      | `ｋ`                       |
|                      | `l`      | `ｌ`                       |
|                      | `m`      | `ｍ`                       |
|                      | `n`      | `ｎ`                       |
|                      | `o`      | `ｏ`                       |
|                      | `p`      | `ｐ`                       |
|                      | `q`      | `ｑ`                       |
|                      | `r`      | `ｒ`                       |
|                      | `s`      | `ｓ`                       |
|                      | `t`      | `ｔ`                       |
|                      | `u`      | `ｕ`                       |
|                      | `v`      | `ｖ`                       |
|                      | `w`      | `ｗ`                       |
|                      | `x`      | `ｘ`                       |
|                      | `y`      | `ｙ`                       |
|                      | `z`      | `ｚ`                       |
|                      | `A`      | `Ａ`                       |
|                      | `B`      | `Ｂ`                       |
|                      | `C`      | `Ｃ`                       |
|                      | `D`      | `Ｄ`                       |
|                      | `E`      | `Ｅ`                       |
|                      | `F`      | `Ｆ`                       |
|                      | `G`      | `Ｇ`                       |
|                      | `H`      | `Ｈ`                       |
|                      | `I`      | `Ｉ`                       |
|                      | `J`      | `Ｊ`                       |
|                      | `K`      | `Ｋ`                       |
|                      | `L`      | `Ｌ`                       |
|                      | `M`      | `Ｍ`                       |
|                      | `N`      | `Ｎ`                       |
|                      | `O`      | `Ｏ`                       |
|                      | `P`      | `Ｐ`                       |
|                      | `Q`      | `Ｑ`                       |
|                      | `R`      | `Ｒ`                       |
|                      | `S`      | `Ｓ`                       |
|                      | `T`      | `Ｔ`                       |
|                      | `U`      | `Ｕ`                       |
|                      | `V`      | `Ｖ`                       |
|                      | `W`      | `Ｗ`                       |
|                      | `X`      | `Ｘ`                       |
|                      | `Y`      | `Ｙ`                       |
|                      | `Z`      | `Ｚ`                       |
| 特殊符号             |          |                            |
|                      | `&`      | `＆`                       |
|                      | `@`      | `＠`                       |
|                      | `#`      | `＃`                       |
|                      | `$`      | `＄`                       |
|                      | `\|`     | `｜`                       |
|                      | `_`      | `＿`                       |

**Default** : `false`

**Example** :

```sas
ignore_half_or_full_width = true
```

---

### ignore_embedded_blank

**Syntax** : `true` | `false`

指定是否忽略嵌在字符串中间的空白字符。

**Default** : `false`

**Example** :

```sas
ignore_embedded_blank = true
```

---

### debug

**Syntax** : `true` | `false`

指定是否删除宏程序运行过程产生的临时数据集。

**Default** : `false`

> [!NOTE]
>
> - 该参数通常用于调试，用户无需关注。
