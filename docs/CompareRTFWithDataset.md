## 简介

比较两个 RTF 文件的内容。

## 语法

### 必选参数

- [RTF](#rtf)
- [DATASET](#dataset)

### 可选参数

- [IGNORELEADBLANK](#ignoreleadblank)
- [IGNOREEMPTYCOLUMN](#ignoreemptycolumn)
- [IGNOREHALFORFULLWIDTH](#ignorehalforfullwidth)

### 调试参数

- [DEL_TEMP_DATA](#del_temp_data)

## 参数说明

### RTF

**Syntax** : _path_ | _fileref_

指定比较的 RTF 文件路径或文件引用。

**Caution** : 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 BASE。

**Example** :

```sas
RTF = "~\draft\表 7.1.1 受试者入组完成情况.rtf"
```

```sas
filename rtfref "~\draft\表 7.1.1 受试者入组完成情况.rtf";
RTF = rtfref
```

---

### DATASET

**Syntax** : <_libname._>_dataset_(_dataset-options_)

指定输出差异比较结果的数据集。

_libname_: 数据集所在的逻辑库名称

_dataset_: 数据集名称

_dataset-options_: 数据集选项，兼容 SAS 系统支持的所有数据集选项

指定比较的数据集名称。

**Example** :

```sas
DATASET = qc_t_7_1_1
```

---

### IGNORELEADBLANK

**Syntax** : YES | NO

指定是否忽略文本的前置空格。

出于缩进的需要，某些单元格内的文本开头可能包含空格，指定 `IGNORELEADBLANK = YES` 时将忽略这些空格。

**Default** : YES

**Example** :

```sas
IGNORELEADBLANK = NO
```

---

### IGNOREEMPTYCOLUMN

⚠ 尚未开发完成！

**Syntax** : YES | NO

指定是否忽略空列。

出于格式的需要，某些列可能完全为空，指定 `IGNOREEMPTYCOLUMN = YES` 时将忽略这些列。

**Default** : YES

**Example** :

```sas
IGNOREEMPTYCOLUMN = NO
```

---

### IGNOREHALFORFULLWIDTH

⚠ 尚未开发完成！

**Syntax** : YES | NO

指定是否忽略全角字符和半角字符的差异。

**Default** : YES

**Example** :

```sas
IGNOREHALFORFULLWIDTH = NO
```

---

### DEL_TEMP_DATA

**Syntax** : YES | NO

指定是否删除宏程序运行过程产生的临时数据集，可选 YES | NO

**Default** : YES

⚠ 该参数通常用于调试，用户无需关注。
