## 简介

比较两个 RTF 文件的内容。

## 语法

### 必选参数

- [BASE](#base)
- [COMPARE](#compare)

### 可选参数

- [IGNORECREATIM](#ignorecreatim)
- [OUTDATA](#outdata)

### 调试参数

- [DEL_TEMP_DATA](#del_temp_data)

## 参数说明

### BASE

**Syntax** : _path_ | _fileref_

指定比较的 BASE 文件路径或文件引用。

**Caution** : 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 BASE。

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

**Caution** : 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 COMPARE。

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

### OUTDATA

**Syntax** : <_libname._>_dataset_(_dataset-options_)

指定输出差异比较结果的数据集。

_libname_: 数据集所在的逻辑库名称

_dataset_: 数据集名称

_dataset-options_: 数据集选项，兼容 SAS 系统支持的所有数据集选项

输出数据集有 6 个变量，具体如下：

| 变量名       | 含义             |
| ------------ | ---------------- |
| BASE_PATH    | base 文件路径    |
| COMPARE_PATH | compare 文件路径 |
| BASE_NAME    | base 文件名      |
| COMPARE_NAME | compare 文件名   |
| CODE         | 返回码           |
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

⚠ 该参数通常用于调试，用户无需关注。
