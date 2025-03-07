# RTFTools for SAS

![Github License](https://img.shields.io/github/license/Snoopy1866/RTFTools-For-SAS)
![GitHub Release](https://img.shields.io/github/v/release/Snoopy1866/RTFTools-For-SAS)

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

| 🧩 程序名称                 | ✨ 描述                                    | 📚 文档                                |
| --------------------------- | ------------------------------------------ | -------------------------------------- |
| `transcode`                 | 一些 Fcmp 函数的封装，其他程序的底层依赖   | [↗️](docs/transcode.md)                |
| `%read_rtf`                 | 读取单个 RTF 文件并转为 SAS 数据集         | [↗️](docs/read_rtf.md)                 |
| `%read_rtf_dir`             | 读取目录中的所有 RTF 文件并转为 SAS 数据集 | [↗️](docs/read_rtf_dir.md)             |
| `%merge_rtf`                | 合并 RTF 文件                              | [↗️](docs/merge_rtf.md)                |
| `%compare_rtf`              | 比较两个 RTF 文件                          | [↗️](docs/compare_rtf.md)              |
| `%compare_rtf_dir`          | 比较两个目录中的所有 RTF 文件              | [↗️](docs/compare_rtf_dir.md)          |
| `%compare_rtf_with_dataset` | 比较一个 RTF 文件和一个 SAS 数据集         | [↗️](docs/compare_rtf_with_dataset.md) |
| `%mix_cw_font`              | 中西文字体混排                             | [↗️](docs/mix_cw_font.md)              |
