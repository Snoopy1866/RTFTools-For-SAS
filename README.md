# RTFTools for SAS

![Github License](https://img.shields.io/github/license/Snoopy1866/sas-rtf-toolkit)

> [!WARNING]
>
> - [v1](https://github.com/Snoopy1866/sas-rtf-toolkit/tree/v1) 版本已不再维护，请使用 [v2](https://github.com/Snoopy1866/sas-rtf-toolkit/tree/v2) 版本；
> - [v2](https://github.com/Snoopy1866/sas-rtf-toolkit/tree/v2) 版本项目已更名为 **`sas-rtf-toolkit`**。

以下列举的是一些 v1 版本存在的已知问题，已在 v2 版本中修复：

| 宏程序      | 问题                                                                                     | PR                                                           |
| ----------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `%MergeRTF` | 正则表达式缺陷导致无法正确识别清单                                                       | [#73](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/73) |
| `%MergeRTF` | `\pgwsxn`, `\pghsxn` 和 `lndscpsxn` 差异导致中间部分的 RTF 文件未被合并                  | [#78](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/78) |
| `%MergeRTF` | `auto_order = false` 时，`link_to_prev = true` 未生效                                    | [#82](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/82) |
| `%ReadRTF`  | 未声明局部变量 `rtf_ref`, `rtf_loc` 导致被 `%CompareRTFWithDataset` 调用时未删除临时文件 | [#84](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/84) |
| `%ReadRTF`  | 数据行存在非打印字符 `\x08-\x0d` 导致资源耗尽                                            | [#85](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/85) |
| `%ReadRTF`  | 数据行存在转义字符 `\{`, `\}` 未处理                                                     | [#86](https://github.com/Snoopy1866/sas-rtf-toolkit/pull/86) |

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
