<p align="center">
    <h2 align="center">RTFTools for SAS</h2>
</p>

<p align="left">
    <a href="https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/LICENSE">
        <img src="https://img.shields.io/github/license/Snoopy1866/RTFTools-For-SAS">
    </a>
</p>


# 简介
适用于 SAS 的 RTF 文件处理程序。

由于 SAS 程序包含非 ASCII 字符的注释，为确保在 GBK 和 Unicode 环境下均可正常使用，所有程序都有两个编码版本，分别存储在 GBK 和 Unicode 文件夹中。

下面是对单个的 SAS 程序的功能介绍：

## 基础程序
下列程序单独调用的作用有限，更多的情况是作为实用程序的依赖而存在。

### [Transcode.sas](./DOCS/Transcode.md)
**功能**：RTF 中的非 ASCII 字符通过转义字符表示，本程序实现了将转义字符解析为当前 SAS 编码环境下的可读字符串。例如：在 RTF 中，某个单元格的字符串为 `CAD4D1E9D7E9`，字符编码为 GBK，本程序将其解析为 `试验组`。



### [Cell_Transcode.sas](./DOCS/Cell_Transcode.md)
**功能**：RTF 中某个单元格可能混杂 ASCII 字符和以转义字符存在的非 ASCII 字符，本程序对单个单元格内的字符串进行解析，ASCII 字符保持不变，非 ASCII 的转义字符解析为可读字符串。

**依赖**：[Transcode.sas](./DOCS/Transcode.md)

## 实用程序
实用程序大多数都需要依赖基础程序，因此在调用它们时，必须先调用基础程序。

### [ReadRTF.sas](./DOCS/ReadRTF.md)
**功能**：读取 RTF 文件中的数据，并将其转换为 SAS 数据集。由于 RTF 文件仅保留了变量标签，没有保留变量名，因此转换后的 SAS 数据集中的变量名用 COLx 表示，其中 x 代表变量出现在表格中的第 x 列。

**依赖**：[Cell_Transcode.sas](./DOCS/Cell_Transcode.md)


### [ReadAllRTF.sas](./DOCS/ReadAllRTF.md)
**功能**：读取单个文件夹中的所有 RTF 文档，并转化为 SAS 数据集。

**依赖**：[ReadRTF.sas](./DOCS/ReadRTF.md)