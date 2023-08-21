## Transcode

### 程序信息

- 名称：Transcode.sas
- 类型：PROC FCMP function
  - 函数存储位置：WORK.FUNC.RTF
  - 函数参数数量：2
    - 参数 1 ：CODE_POINT（一串码点，例如：`\\'CA\\'D4`）
    - 参数 2 ：RAW_ENCODING（码点使用的编码格式，例如：GBK）
  - 函数返回值：CHAR（转码后的字符串）
  - 函数依赖的宏程序：[%_MACRO_TRANSCODE](#_macro_transcode)
- 功能：RTF Specification 规定只能使用 7 位 ASCII 字符，若要显示非 ASCII 字符，必须使用转义符，对于 GBK 编码格式的字符串，使用类似 `\\'CA\\'D4` 的形式表示，对于 Unicode 字符，使用 `\\u21015;` 进行表示，本程序实现了将这些非 ASCII 字符转为原始字符串的功能



#### %_MACRO_TRANSCODE
程序 Transcode.sas 中包含了内置宏程序 %_MACRO_TRANSCODE，用于辅助实现转码，它在 PROC FCMP function 中被函数 `RUN_MACRO()` 调用，并返回一个状态码，变量 `IS_TRANSCODE_SUCCESS` 存储了这个状态码。

- IS_TRANSCODE_SUCCESS = 1，转码成功
- IS_TRANSCODE_SUCCESS = 0，转码失败

