# %compare_rtf

比较两个 RTF 文件的内容。

**Compatibility** : RTF 1.6 specification

## 语法

### 必选参数

- [base](#base)
- [compare](#compare)

### 可选参数

- [ignore_create_time](#ignore_create_time)
- [ignore_header](#ignore_header)
- [ignore_footer](#ignore_footer)
- [ignore_cell_style](#ignore_cell_style)
- [ignore_font_table](#ignore_font_table)
- [ignore_color_table](#ignore_color_table)
- [outdata](#outdata)

### 调试参数

- [debug](#debug)

## 参数说明

### base

**Syntax** : _path_ | _fileref_

指定基准文件的物理路径或 _filename_ 引用。

> [!IMPORTANT]
>
> - 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 `base`。

**Example** :

```sas
base = "~\draft\表 1. 受试者入组完成情况.rtf"
```

```sas
filename bfile "~\draft\表 1. 受试者入组完成情况.rtf";
base = bfile
```

---

### compare

**Syntax** : _path_ | _fileref_

指定比较文件的物理路径或 _filename_ 引用。

> [!IMPORTANT]
>
> - 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 `compare`。

**Example** :

```sas
compare = "~\表 1. 受试者入组完成情况.rtf"
```

```sas
filename cfile "~\表 1. 受试者入组完成情况.rtf";
compare = cfile
```

---

### ignore_create_time

**Syntax** : `true` | `false`

指定是否忽略文件创建时间。

RTF 文件元信息中包含文件创建时间，指定 `ignore_create_time = true` 可以防止因创建时间不同而产生无意义的比较结果。

**Default** : `true`

**Example** :

```sas
ignore_create_time = false
```

---

### ignore_header

**Syntax** : `true` | `false`

指定是否忽略页眉。

**Default** : `true`

**Example** :

```sas
ignore_header = false
```

---

### ignore_footer

**Syntax** : `true` | `false`

指定是否忽略页脚。

**Default** : `true`

**Example** :

```sas
ignore_footer = false
```

### ignore_cell_style

**Syntax** : `true` | `false`

指定是否忽略单元格样式。

**Default** : `true`

**Example** :

```sas
ignore_cell_style = false
```

---

### ignore_font_table

**Syntax** : `true` | `false`

指定是否忽略字体表。

**Default** : `true`

> [!IMPORTANT]
>
> - 忽略字体表并不代表会忽略文本字体差异，若字体表相同，但实际文本内容使用了字体表中的不同字体，则宏程序仍然会检测出差异。

**Example** :

```sas
ignore_font_table = false
```

---

### ignore_color_table

**Syntax** : `true` | `false`

指定是否忽略颜色表。

> [!IMPORTANT]
>
> - 忽略颜色表并不代表会忽略文本颜色差异，若颜色表相同，但实际文本内容使用了颜色表中的不同颜色，则宏程序仍然会检测出差异。

**Default** : `true`

**Example** :

```sas
ignore_color_table = false
```

---

### outdata

**Syntax** : <_libname._>_dataset_(_dataset-options_)

指定输出差异比较结果的数据集。

_libname_: 数据集所在的逻辑库名称

_dataset_: 数据集名称

_dataset-options_: 数据集选项，兼容 SAS 系统支持的所有数据集选项

输出数据集有 5 个变量，具体如下：

| 变量名       | 含义             |
| ------------ | ---------------- |
| BASE_PATH    | base 文件路径    |
| COMPARE_PATH | compare 文件路径 |
| BASE_NAME    | base 文件名      |
| COMPARE_NAME | compare 文件名   |
| DIFFYN       | 存在差异         |

**Default** : `diff`

**Example** :

```sas
outdata = diff
outdata = cmp.diff
outdata = cmp.diff(keep = BASE_NAME DIFFYN)
```

---

### debug

**Syntax** : `true` | `false`

指定是否删除宏程序运行过程产生的临时数据集。

**Default** : `false`

> [!NOTE]
>
> - 该参数通常用于调试，用户无需关注。
