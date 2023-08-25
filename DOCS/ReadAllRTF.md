## ReadAllRTF

### 程序信息

- 名称：ReadAllRTF.sas
- 类型：Macro
- 依赖：[ReadRTF](./ReadRTF.md)
- 功能：将指定文件夹中的所有 RTF 文件转换为 SAS 数据集。

### 程序执行流程
1. 使用 DOS 命令获取指定文件夹中的所有 RTF 文件，将 RTF 文件列表存储在 `_tmp_rtf_list.txt` 中；
2. 读取 `_tmp_rtf_list.txt` 文件，获取 RTF 文件名称，构建并执行 filename 语句；
3. 调用宏 `%ReadRTF()`，将 RTF 文件转换为 SAS 数据集
4. 删除临时数据集
5. 删除 `_tmp_rtf_list.txt`

### 参数

#### DIR
类型 : 可选参数

取值 : 指定 RTF 文件所在文件夹名称，必须是一个合法的 Windows 文件夹路径，例如：`C:\Windows\Temp`

### 细节
#### 如何获取文件夹中所有 RTF 文件

### 示例程序

```sas
%ReadAllRTF(dir = %str(D:\~\TFL\table));
```