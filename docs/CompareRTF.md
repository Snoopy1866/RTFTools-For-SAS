## CompareRTF

比较两个 RTF 文件的内容。

**Compatibility** : RTF 1.6 specification

## 语法

### 必选参数

- [BASE](#base)
- [COMPARE](#compare)

### 可选参数

- [IGNORECREATIM](#ignorecreatim)
- [IGNOREHEADER](#ignoreheader)
- [IGNOREFOOTER](#ignorefooter)
- [IGNORECELLSTYLE](#ignorecellstyle)
- [IGNOREFONTTABLE](#ignorefonttable)
- [IGNORECOLORTABLE](#ignorecolortable)
- [OUTDATA](#outdata)

### 调试参数

- [DEL_TEMP_DATA](#del_temp_data)

## 参数说明

### BASE

**Syntax** : _path_ | _fileref_

指定比较的 BASE 文件路径或文件引用。

> [!IMPORTANT]
>
> - 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 BASE。

**Example** :

```sas
BASE = "~\draft\表 1. 受试者入组完成情况.rtf"
```

```sas
filename baseref "~\draft\表 1. 受试者入组完成情况.rtf";
BASE = baseref
```

---

### COMPARE

**Syntax** : _path_ | _fileref_

指定比较的 COMPARE 文件路径或文件引用。

> [!IMPORTANT]
>
> - 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 COMPARE。

**Example** :

```sas
COMPARE = "~\表 1. 受试者入组完成情况.rtf"
```

```sas
filename cmpref "~\表 1. 受试者入组完成情况.rtf";
BASE = cmpref
```

---

### IGNORECREATIM

**Syntax** : YES | NO

指定是否忽略文件创建时间。

RTF 文件元信息中包含文件创建时间，指定 `IGNORECREATIM = YES` 可以防止因创建时间不同而产生无意义的比较结果。

**Default** : YES

**Example** :

```sas
IGNORECREATIM = NO
```

---

### IGNOREHEADER

**Syntax** : YES | NO

指定是否忽略页眉。

**Default** : YES

**Example** :

```sas
IGNOREHEADER = NO
```

---

### IGNOREFOOTER

**Syntax** : YES | NO

指定是否忽略页脚。

**Default** : YES

**Example** :

```sas
IGNOREFOOTER = NO
```

### IGNORECELLSTYLE

**Syntax** : YES | NO

指定是否忽略单元格样式。

**Default** : YES

**Example** :

```sas
IGNORECELLSTYLE = NO
```

---

### IGNOREFONTTABLE

**Syntax** : YES | NO

指定是否忽略字体表。

**Default** : YES

> [!IMPORTANT]
>
> - 忽略字体表并不代表会忽略文本字体差异，若字体表相同，但实际文本内容使用了字体表中的不同字体，则宏程序仍然会检测出差异。

**Example** :

```sas
IGNOREFONTTABLE = NO
```

---

### IGNORECOLORTABLE

**Syntax** : YES | NO

指定是否忽略颜色表。

> [!IMPORTANT]
>
> - 忽略颜色表并不代表会忽略文本颜色差异，若颜色表相同，但实际文本内容使用了颜色表中的不同颜色，则宏程序仍然会检测出差异。

**Default** : YES

**Example** :

```sas
IGNORECOLORTABLE = NO
```

---

### OUTDATA

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

**Default** : DIFF

**Example** :

```sas
OUTDATA = DIFF
INDATA = CMP.DIFF
INDATA = CMP.DIFF(keep = BASE_NAME DIFFYN)
```

---

### DEL_TEMP_DATA

**Syntax** : YES | NO

指定是否删除宏程序运行过程产生的临时数据集，可选 YES | NO

**Default** : YES

> [!NOTE]
>
> - 该参数通常用于调试，用户无需关注。
