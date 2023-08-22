## ReadRTF

### 程序信息

- 名称：ReadRTF.sas
- 类型：Macro
  - 参数数量：2
    - 参数 1：FILE（待转换的 RTF 文件的物理路径）
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

### 细节
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
%ReadRTF(file = rtf, outdata = s1);


/*Unicdoe*/
filename rtf "D:\~\表6.4.1 生命体征汇总 安全性分析集.rtf";

%ReadRTF(file = rtf, outdata = s1);
```