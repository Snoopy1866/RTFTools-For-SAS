## ReadRTF

### 程序信息

- 名称：ReadRTF.sas
- 类型：Macro
  - 参数数量：2
    - 参数 1：FILE（待转换的 RTF 文件的物理路径或文件引用，指定文件路径时不加引号，使用 %str() 进行屏蔽）
    - 参数 2：OUTDATA（转换后的 SAS 数据集名称）
- 依赖：[Cell_Transcode](./Cell_Transcode.md)
- 功能：SAS ODS RTF 使用 RTF 1.6 specification 输出 RTF 文件，本程序实现了将输出的 RTF 文件逆向转为 SAS 数据集的功能。

### 程序执行流程
1. 根据参数 FILE 的值获取文件的物理路径
2. 读取 RTF 文件，单行 RTF 字符串存储在变量 `line` 中；
3. 调整表头，部分 RTF 的表头含有回车，这可能会导致 RTF 代码在回车处折行，这一步解决了折行导致的变量标签无法正常解析的问题，该问题在 Table 中经常出现；
4. 识别表格中的数据。表格出现在标题后面，对于表格跨页的第一行数据，对应的 RTF 代码会稍有不同，使用以下正则表达式进行识别：
    - 标题：`/\\outlinelevel\d/o`
    - 表头定义起始行：`/\\trowd\\trkeep\\trhdr\\trq[lcr]/o`
    - 表头属性定义行：`/\\clbrdr[tlbr]\\brdrs\\brdrw\d*\\brdrcf\d*(?:\\clbrdr[tlbr]\\brdrs\\brdrw\d*\\brdrcf\d*)*\\cltxlrt[bl]\\clvertal[tcb](?:\\clcbpat\d*)?\\cellx(\d+)/o`
    - 数据行：`/^\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])*)\\cell\}$/o`
    - 分节符标识行：`/\\sect\\sectd\\linex\d*\\endnhere\\pgwsxn\d*\\pghsxn\d*\\lndscpsxn\\headery\d*\\footery\d*\\marglsxn\d*\\margrsxn\d*\\margtsxn\d*\\margbsxn\d*/o`
5. 开始转换数据。调用 [Cell_Transcode](./Cell_Transcode.md) 函数，将单元格内的字符串转换为可读的字符串；
6. 使用 `PROC TRANSPOSE` 对上一步产生的数据集进行转置；
7. 处理变量标签，这一步主要是解决表头标签跨越多行可能导致的标签错位的问题
8. 修改数据集属性，包括缩减变量长度，添加标签
9. 输出至参数 `OUTDATA` 指定的数据集中
10. 删除中间步骤产生的数据集

### 参数
#### FILE
类型 : 必选参数

取值 : 指定 RTF 文件路径或引用。指定的文件路径或者引用的文件路径必须是一个合法的 Windows 路径。您应当使用 `%str()` 函数将路径包围，路径不包含引号；当指定的 Windows 路径太长时，应当使用 filename 语句建议文件引用，否则会导致 SAS 无法正确读取。

举例 : 
```
FILE = %str(D:\~\表7.1.1 受试者分布 筛选人群.rtf)
```

```
filename ref "D:\~\表7.1.1 受试者分布 筛选人群.rtf";
FILE = ref;
```

#### OUTDATA
类型 : 必选参数

取值 : 指定输出数据集名称。

举例 :

```
OUTDATA = t_7_1_1
```

#### COMPRESS
类型 : 可选参数

取值 : 指定临时数据集是否压缩，可选 YES | NO

默认值 : YES

### 细节

#### 1. 如何根据参数 FILE 的值获取文件的物理路径

首先，SAS 文件引用名称不超过 8 个字符，且必须是一个合法的 SAS 名称；可根据下列正则表达式初步判断是文件路径还是文件引用：

```
/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|((?:[A-Za-z]:\\)[^\\\/:?"<>|]+(?:\\[^\\\/:?"<>|]+)*))$/
```

上述正则表达式包含两个 buffer：
- buffer1 : 匹配文件引用
- buffer2 : 匹配 Windows 路径名称，不支持匹配含有环境变量的路径（例如：`%TEMP%\~.rtf`）

若 buffer 1 的内容不为空，则参数 FILE 指定的可能是一个文件引用
若 buffer 2 的内容不为空，则参数 FILE 指定的可能是一个 Windows 文件路径

在 buffer1 的内容不为空的前提下，使用 SAS 函数 `fileref()` 判断文件引用是否存在：
- fileref() 函数返回正数，则 FILE 指定的文件引用未定义
- fileref() 函数返回负数，则 FILE 指定的文件引用已定义，但文件引用的物理路径不存在
- fileref() 函数返回零，则 FILE 指定的文件引用已定义，且文件引用的物理路径存在

在上述 fileref() 函数返回零的情况下，使用 SAS 函数 `pathname()` 获取文件引用的物理路径。


#### 2. 如何读取外部 RTF 文件
SAS ODS RTF 使用 RTF 1.6 specification 输出 RTF 文件，本质上是一些纯文本标记（markup）字符。使用 `infile` 读取 RTF 文件，并存储在临时数据集 `_tmp_rtf_data` 中。

RTF 文件单行字符串没有限制长度，为确保读取的 RTF 标记字符不会被截断，数据集 `_tmp_rtf_data` 中的变量均使用 SAS 允许的最大长度 32767，同时默认使用 `compress = yes` 数据集选项，防止因磁盘空间不足导致程序无法运行。

#### 3. 如何解决表头内嵌换行符导致的 RTF 标记字符跨越多行的问题
对于使用了 `split = char` 在表头内部进行换行的 RTF 文件，根据观察，SAS 输出 RTF 文件时，当遇到指定的 split 字符时，SAS 将在 RTF 文件中写入控制字 `{\line}`，并在下一行继续写入 split 字符之后的文本，当某个单元格内的文本结束时，SAS 在 RTF 文件中写入控制字 `\cell`，表示这个单元格的字符串已经全部写入完成。

根据上述规律，可以采用下列逻辑识别 RTF 文件中的表头内嵌换行符的问题：
1. 使用以下正则表达式识别出现内嵌换行符的表头

```
/^(\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{.*){\\line}$/o
```

2. 在上一步成功匹配正则表达式的基础上，连续使用以下正则表达式识别连续的内嵌换行符

```
/^(.*){\\line}$/o
```

3. 直到使用以下正则表达式识别到单元格的结束位置

```
^(.*\\cell})$/o
```

上述步骤中，步骤2可能会重复多次，每次识别到内嵌的换行符时，都将文本提取出来，并与上一步骤提取的文本拼接，同时删除当前行，直到步骤3，此时所有内嵌的换行符均已删除，拼接后的文本即为单元格内的完整文本。

![](./assets/ReadRTF-detail-q1.png)

#### 

- 由于 ODS RTF 输出至外部 RTF 文件时，丢失了变量名称，因此转换回 SAS 数据集时，变量名称根据变量出现的顺序，依次为 `COL1`, `COL2`, `COL3`, ...
- 输出数据集中额外新增一列变量 `OBS_SEQ`，表示观测序号
- 对于单元格内的控制字，本程序将其当做普通 ASCII 字符处理，不会进行解析。例如：`\super` 将保留在 SAS 数据中
- 对于单元格内的转义字符，目前支持的编码有：GBK、UTF-8
- RTF 文件对单行文本长度没有限制，但是 SAS 数据集的变量长度有限制，尽管本程序使用了 32767 长度的变量用于存储 RTF 单行字符串的值，但仍然存在潜在的截断问题，此问题受限于 SAS 自身限制，无法修复
- 由于部分 RTF 表格的表头存在单元格合并，因此转换后的 SAS 数据集标签可能会错位，但不影响数据集的观测

### 示例程序

```sas
/*GBK*/
filename rtf "D:\~\表7.1.1 受试者分布 筛选人群.rtf";
%ReadRTF(file = rtf, outdata = t_7_1_1);

%ReadRTF(file = %str(D:\~\表7.1.1 受试者分布 筛选人群.rtf), outdata = t_7_1_1);

/*Unicode*/
filename rtf "D:\~\表6.4.1 生命体征汇总 安全性分析集.rtf";

%ReadRTF(file = rtf, outdata = t_6_4_1);

%ReadRTF(file = %str(D:\~\表6.4.1 生命体征汇总 安全性分析集.rtf), outdata = t_6_4_1);

```