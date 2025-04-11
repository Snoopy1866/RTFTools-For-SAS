# RTFTools for SAS

![Github License](https://img.shields.io/github/license/Snoopy1866/sas-rtf-toolkit)

> [!WARNING]
>
> - [v1](https://github.com/Snoopy1866/sas-rtf-toolkit/tree/v1) 版本已不再维护，请使用 [v2](https://github.com/Snoopy1866/sas-rtf-toolkit/tree/v2) 版本；
> - [v2](https://github.com/Snoopy1866/sas-rtf-toolkit/tree/v2) 版本项目已更名为 **`sas-rtf-toolkit`**。

以下列举的是一些 v1 版本存在的已知问题，已在 v2 版本中修复：

| 宏程序      | 问题                                                                    | PR                                                           |
| ----------- | ----------------------------------------------------------------------- | ------------------------------------------------------------ |
| `%MergeRTF` | 正则表达式缺陷导致无法正确识别清单                                      | [#73](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/73) |
| `%MergeRTF` | `\pgwsxn`, `\pghsxn` 和 `lndscpsxn` 差异导致中间部分的 RTF 文件未被合并 | [#78](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/78) |

## 简介

适用于 SAS 的 RTF 文件处理程序。

以下编码环境可用：

- [utf8](src/utf8/)
- [utf16](src/utf16/)
- [gbk](src/gbk/)
- [gb18030](src/gb18030/)

## 详细文档

- [Transcode.sas](docs/Transcode.md)
- [ReadRTF.sas](docs/ReadRTF.md)
- [ReadAllRTF.sas](docs/ReadAllRTF.md)
- [MergeRTF.sas](docs/MergeRTF.md)
- [CompareRTF.sas](docs/CompareRTF.md)
- [CompareAllRTF.sas](docs/CompareAllRTF.md)
- [CompareRTFWithDataset](docs/CompareRTFWithDataset.md)
- [MixCWFont.sas](docs/MixCWFont.md)
