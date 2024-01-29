包含以下 Fcmp 函数：

- [Transcode](#transcode)
- [Cell_Transcode](#cell_transcode)

## Transcode

### 程序信息

- 名称：Transcode.sas
- 类型：PROC FCMP function
- 依赖：[%\_MACRO_TRANSCODE](#_macro_transcode)（内置）
- 功能：不同编码格式的字符串可能互不兼容，例如：GBK 格式编码的字符串在 Unicode 环境下会显示乱码，本程序实现了将不同编码格式的码点转换为当前 SAS 环境下的字符串的功能。例如：将字符串 `CAD4D1E9D7E9` 转为 `试验组`；将字符串 `&#35797;&#39564;&#32452;` 转为 `试验组`。
- 存储位置：SASUSER.FUNC.RTF

### 程序执行流程

1. 判断参数 RAW_ENCODING 的值，若为 UTF8，则调用 SAS 自带函数 `UNICODE()` 进行转换；若为其他值，则调用 `RUN_MACRO` 函数；
2. 获取 UNICODE() 函数或 RUN_MACRO() 函数的返回值，并返回至调用环境

### 返回值

#### CHAR

类型 : 字符

取值 : 转码后的字符串

### 参数

#### CODE_POINT

类型 : 字符

取值 : 一串码点，例如：`CAD4`，`&#21015`

#### RAW_ENCODING

类型 : 字符

取值 : 码点使用的编码格式，例如：`GBK`，`UTF8`

### %\_MACRO_TRANSCODE

程序 Transcode.sas 中包含了内置宏程序 `%_MACRO_TRANSCODE`，用于辅助实现转码，它在 PROC FCMP function 中被函数 `RUN_MACRO()` 调用，并返回一个状态码，变量 `IS_TRANSCODE_SUCCESS` 存储了这个状态码。

- IS_TRANSCODE_SUCCESS = 1，转码成功
- IS_TRANSCODE_SUCCESS = 0，转码失败

## Cell_Transcode

### 程序信息

- 名称：Cell_Transcode.sas
- 类型：PROC FCMP function
- 依赖：[Transcode()](./Transcode.md)
- 功能：RTF Specification 规定只能使用 7 位 ASCII 字符，若要显示非 ASCII 字符，必须使用转义符，对于 GBK 编码格式的字符串，使用类似 `\'CA\'D4` 的形式表示，对于 Unicode 字符，使用 `\u21015;` 进行表示，本程序实现了将这些非 ASCII 字符转为原始字符串的功能
- 存储位置：SASUSER.FUNC.RTF

### 程序执行流程

1. 使用正则表达式判断参数 `STR` 的编码格式，具体如下：

- GBK 编码格式：`/((?:\\\x27[0-9A-F]{2})+)/o`
- UTF-8 编码格式：`/((?:\\u\d{1,5};)+)/o`

2. 根据编码格式，先对 RTF 中的非 ASCII 字符进行处理，对于 GBK 编码格式的转义字符，去除转义字符 `\'`；对于 UTF-8 编码格式的转义字符，将转义字符 `\u` 替换为 `&#`
3. 调用 PROC FCMP 函数 `Transcode()`，将返回值存储在变量 `STR_DECODED` 中
4. 返回变量 `STR_DECODED` 的值至调用环境

### 返回值

#### STR_DECODED

类型 : 字符

取值 : 以当前 SAS 环境下的编码格式重新存储的字符串，ASCII 编码的字符可兼容大多数编码格式，因此未进行转码

### 参数

#### STR

类型 : 字符

取值 : RTF 单元格内的字符串，例如：`\'CA\'D4\'D1\'E9\'D7\'E9`, `\u35797;\u39564;\u32452;`

### 细节

- 由于同一份 RTF 文档，其单元格内的转义字符要么遵循 GBK 编码格式，要么遵循 UTF-8 编码格式，因此只需对单元格内的字符串进行一次正则匹配，即可获得其使用的编码格式
