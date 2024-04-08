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

### [Transcode.sas](./docs/Transcode.md)

转码相关的 Fcmp 函数。

## 实用程序

实用程序大多数都需要依赖基础程序，因此在调用它们时，必须先调用基础程序。

在 SAS 编辑器中运行 `%`_`macro`_`()` 或 `%`_`macro`_`(help)` 可打开对应实用程序的在线帮助文档，例如：`%ReadRTF()`。

### [ReadRTF.sas](./docs/ReadRTF.md)

**功能**：读取 RTF 文件中的数据，并将其转换为 SAS 数据集。由于 RTF 文件仅保留了变量标签，没有保留变量名，因此转换后的 SAS 数据集中的变量名用 COLx 表示，其中 x 代表变量出现在表格中的第 x 列。

**依赖**：[Transcode.sas](./docs/Transcode.md) -> [ReadRTF.sas](./docs/ReadRTF.md)

### [ReadAllRTF.sas](./docs/ReadAllRTF.md)

**功能**：读取单个文件夹中的所有 RTF 文档，并转化为 SAS 数据集。

**依赖**：[Transcode.sas](./docs/Transcode.md) -> [ReadRTF.sas](./docs/ReadRTF.md) -> [ReadAllRTF.sas](./docs/ReadAllRTF.md)

### [MergeRTF.sas](./docs/MergeRTF.md)

**功能**：合并文件夹内的 RTF 文件，支持递归检索子文件夹

**依赖**：无

### [CompareRTF.sas](./docs/CompareRTF.md)

**功能**：比较两个 RTF 文件

**依赖**：无

### [CompareAllRTF.sas](./docs/CompareAllRTF.md)

**功能**：比较两个文件夹下的 RTF 文件

**依赖**：[CompareRTF.sas](./docs/CompareRTF.md) -> [CompareAllRTF.sas](./docs/CompareAllRTF.md)

### [CompareRTFWithDataset](./docs/CompareRTFWithDataset.md)

**功能**：比较 RTF 文件与 SAS 数据集

**依赖**：[Transcode.sas](./docs/Transcode.md) -> [ReadRTF.sas](./docs/ReadRTF.md) -> [CompareRTFWithDataset](./docs/CompareRTFWithDataset.md)

### [DeletePicInHeader](./docs/assets/DeletePicInHeader.md) （未开发完成）

**功能**：去除 RTF 文件页眉 logo
