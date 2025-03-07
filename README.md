# RTFTools for SAS

![Github License](https://img.shields.io/github/license/Snoopy1866/RTFTools-For-SAS)

> [!IMPORTANT]
>
> [v2](https://github.com/Snoopy1866/RTFTools-For-SAS) 和 [v1](https://github.com/Snoopy1866/RTFTools-For-SAS/tree/v1) 互不兼容，
> 如果你使用的是 v1 版本，请参考 [v1 帮助文档](https://github.com/Snoopy1866/RTFTools-For-SAS/tree/v1)。

## 简介

适用于 SAS 的 RTF 文件处理程序。

以下编码环境可用：

- [utf8](src/utf8/)
- [utf16](src/utf16/)
- [gbk](src/gbk/)
- [gb18030](src/gb18030/)

## 详细文档

| 🧩 程序名称              | ✨ 描述                                    | 📚 文档                             |
| ------------------------ | ------------------------------------------ | ----------------------------------- |
| `Transcode`              | 一些 Fcmp 函数的封装，其他程序的底层依赖   | [↗️](docs/Transcode.md)             |
| `%ReadRTF`               | 读取单个 RTF 文件并转为 SAS 数据集         | [↗️](docs/ReadRTF.md)               |
| `%ReadAllRTF`            | 读取目录中的所有 RTF 文件并转为 SAS 数据集 | [↗️](docs/ReadAllRTF.md)            |
| `%MergeRTF`              | 合并 RTF 文件                              | [↗️](docs/MergeRTF.md)              |
| `%CompareRTF`            | 比较两个 RTF 文件                          | [↗️](docs/CompareRTF.md)            |
| `%CompareAllRTF`         | 比较两个目录中的所有 RTF 文件              | [↗️](docs/CompareAllRTF.md)         |
| `%CompareRTFWithDataset` | 比较一个 RTF 文件和一个 SAS 数据集         | [↗️](docs/CompareRTFWithDataset.md) |
| `%MixCWFont`             | 中西文字体混排                             | [↗️](docs/MixCWFont.md)             |
