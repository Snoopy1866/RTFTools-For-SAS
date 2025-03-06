## ReadAllRTF

读取指定文件夹中的所有 RTF 文件，将所有 RTF 文件转为 SAS 数据集。

**Compatibility** : RTF 1.6 specification

## 依赖

[Transcode](Transcode.md#transcode) -> [Cell_Transcode](Transcode.md#cell_transcode) -> [ReadRTF](ReadRTF.md) -> [ReadAllRTF](ReadAllRTF.md)

## 语法

### 必选参数

- [DIR](#dir)

### 可选参数

- [OUTLIB](#outlib)
- [VD](#vd)
- [COMPRESS](#compress)
- [DEL_RTF_CTRL](#del_rtf_ctrl)

### 调试参数

- [debug](#debug)

## 参数说明

### DIR

**Syntax** : _path_ | _fileref_

指定 RTF 文件所在目录路径或引用。指定的目录路径必须是一个合法的 Windows 路径。

> [!IMPORTANT]
>
> - 当指定的物理路径太长时，应当使用 filename 语句建立目录引用，然后传入目录引用，否则会导致 SAS 无法正确读取。

**Example** :

```
DIR = "D:\~\01 table"
```

```
filename ref "D:\~\01 table";
DIR = ref;
```

---

### OUTLIB

**Syntax** : _libname_

指定输出数据集存放的逻辑库，该逻辑库必须事先定义，且逻辑库对应的物理路径必须存在

**Default** : `work`

---

### VD

**Syntax** : _drive_ | `#auto`

指定临时创建的虚拟磁盘的盘符，该盘符必须是字母 A ~ Z 中未被操作系统使用的一个字符。

**Default** : `#auto`

默认情况下，宏程序将自动选择一个未被操作系统使用的字母作为虚拟磁盘的盘符。

---

### COMPRESS

同 [COMPRESS](./ReadRTF.md#compress)

---

### DEL_RTF_CTRL

同 [DEL_RTF_CTRL](./ReadRTF.md#del_rtf_ctrl)

---

### debug

**Syntax** : `true` | `false`

指定是否删除宏程序运行产生的中间数据集

**Default** : `false`

> [!NOTE]
>
> - 该参数通常用于调试，用户无需关注。

---

## 程序执行流程

1. 使用 DOS 命令获取指定文件夹中的所有 RTF 文件，将 RTF 文件列表存储在 `_tmp_rtf_list.txt` 中；
2. 读取 `_tmp_rtf_list.txt` 文件，获取 RTF 文件名称，构建并执行 filename 语句；
3. 调用宏 `%ReadRTF()`，将 RTF 文件转换为 SAS 数据集
4. 删除临时数据集
5. 删除 `_tmp_rtf_list.txt`

## 细节

### 1. 如何获取文件夹中所有 RTF 文件

使用全局语句 `X ...` 调用 Windows 下的 DOS 命令，使用 `DIR` 命令获取文件夹中后缀为 `.rtf` 的文件列表，并存储在文件夹中的 `_tmp_rtf_list.txt` 中。

在 CMD 中，该命令如下所示：

```cmd
dir "~\*.rtf" /b/on > "~\_tmp_rtf_list.txt" & exit
```

注意，不要忘记使用 `exit` 退出终端窗口；

在 SAS 中，上述命令改写为：

```sas
X "dir ""~\*.rtf"" /b/on > ""~\_tmp_rtf_list.txt"" & exit"
```

将 `~` 替换为宏变量 `&dir`，即可。

⚠ 在 Unicode 环境下，SAS 对于含中文字符的超长路径（超过 262 字符）支持不够友好，为了防止部分 RTF 文件因路径过长导致无法读取，可以使用命令 `subst` 临时建立虚拟磁盘映射，从而缩短文件路径，以便 SAS 能够正确读取 RTF 文件。

因此，在 SAS 中，上述命令进一步改写为：

```sas
X "subst &vd: ""&dir"" & dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";
```

所有 RTF 文件读取完成后，记得删除虚拟磁盘映射：

```sas
X " del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";
```

### 2. 如何识别符合命名要求的 RTF 文件

通常情况下，输出的 RTF 文件名都含有一个序号，例如：`表7.1.1 受试者分布 筛选人群.rtf` 中的 `7.1.1`，此外前缀 `表` 也是固定的字符，通过这一规律，可以识别那些通过 SAS 输出的 RTF 文件。因此，可以构建以下正则表达式识别可以处理的 RTF 文件：

```
/^((?:列)?表|清单)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf\s*$/o
```

该正则表达式包含 3 个 buffer，各自含义如下：

- buffer1 : 文件名类型，如：`列表`、`表`、`清单`
- buffer2 : 文件名序号，如：7.1.1
- buffer3 : 文件名主体，如：受试者分布 筛选人群

若 RTF 文件名匹配上述正则表达式，则在临时数据集 `_tmp_rtf_list` 中，变量 `rtf_valid_flag` 将被标记为 `Y`。

### 3. 如何读取符合命名要求的 RTF 文件并转换为 SAS 数据集

在 [#2](#2-如何识别符合命名要求的-rtf-文件) 的临时数据集 `_tmp_rtf_list` 中，筛选变量 `rtf_valid_flag`
的值为 `Y` 的观测，然后通过使用 `call execute` 调用宏 `%ReadRTF()`，具体如下：

```
call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || '(label = "' || ref_label || '"), compress = true' || '));');
```

注意：需要给输出数据集添加标签，因此参数 `outdata` 需要添加数据集选项 `label = "xxx"`。

### 3. 如何给输出的 SAS 数据集自动命名和添加标签

根据 [#2](#2-如何识别符合命名要求的-rtf-文件) 获取的 buffer，自动为输出的数据集附加属性。
buffer1 和 buffer2 将作为输出数据集的名称，具体操作如下：

- 若 buffer1 = "表"，则数据集名称以 ‘T’ 开头
- 若 buffer1 = "列表" or "清单"，则数据集名称以 ‘L’ 开头
- 将 buffer2 中的句点（.）替换为下划线（\_），以符合 SAS 名称规范

连接上述处理后的字符串，即为输出数据集的名称，例如：T_7_1_1

buffer3 的内容将作为输出数据集的标签。

## 示例程序

```sas
%ReadAllRTF(dir = "D:\~\TFL\table");

libname qc "D:\qc";
%ReadAllRTF(dir = "D:\~\TFL\table", outlib = qc);

%ReadAllRTF(dir = "D:\~\TFL\table", outlib = qc, vd = X);

%ReadAllRTF(dir = "D:\~\TFL\table", outlib = qc, vd = X, compress = true);

%ReadAllRTF(dir = "D:\~\TFL\table", outlib = qc, vd = X, compress = true, del_rtf_ctrl = true);

%ReadAllRTF(dir = %str(D:\~\TFL\table), outlib = qc, vd = X, compress = true, del_rtf_ctrl = true);

filename dirref "D:\~\TFL\table";
%ReadAllRTF(dir = dirref, outlib = qc, vd = X, compress = true, del_rtf_ctrl = true);
```
