包含一个内置宏和两个 Fcmp 函数：

- [\_macro_transcode](#_macro_transcode)
- [transcode](#transcode)
- [cell_transcode](#cell_transcode)

# \_macro_transcode

内置宏程序 `%_macro_transcode`，用于辅助实现转码，它在 PROC FCMP function 中被函数 `run_macro()` 调用，并返回一个状态码，变量 `is_transcode_success` 存储了这个状态码。

- `is_transcode_success = 1` 表示转码成功
- `is_transcode_success = 0` 表示转码失败

---

# transcode

将不同编码格式的码点转换为当前 SAS 环境下的字符串。

例如：将字符串 `CAD4D1E9D7E9` 转为 `试验组`；将字符串 `&#35797;&#39564;&#32452;` 转为 `试验组`。

## 参数

### code_point

需要转换的码点字符串。例如，`CAD4`，`&#21015`。

### raw_encoding

码点使用的编码格式。例如，`gbk`，`utf8`。

## 返回值

### char

一个字符串，表示使用 `raw_encoding` 指定的编码格式对 `code_point` 指定的码点进行转换后的在当前编码环境下显示的字符串。

### 程序执行流程

1. 判断参数 `raw_encoding` 的值，若为 `utf8`，则调用 SAS 自带函数 `unicode()` 进行转换；若为其他值，则调用 `run_macro` 函数；

2. 获取 `unicode()` 函数或 `run_macro()` 函数的返回值，并返回至调用环境。

---

# cell_transcode

## 参数

### str

RTF 单元格内的字符串。例如，`\'CA\'D4\'D1\'E9\'D7\'E9`，`\u35797;\u39564;\u32452;`。

## 返回值

### str_decoded

以当前 SAS 环境下的编码格式重新存储的字符串。ASCII 编码的字符可兼容大多数编码格式，因此未进行转码。

### 程序执行流程

1. 使用正则表达式判断参数 `str` 的编码格式，具体如下：

   - gbk 编码格式：`/((?:\\\x27[0-9A-F]{2})+)/o`
   - utf8 编码格式：`/((?:\\u\d{1,5};)+)/o`

2. 根据编码格式，先对 RTF 中的非 ASCII 字符进行处理，对于 gbk 编码格式的转义字符，去除转义字符 `\'`；对于 utf8 编码格式的转义字符，将转义字符 `\u` 替换为 `&#`；

3. 调用 PROC FCMP 函数 [transcode()](#transcode)，将返回值存储在变量 `str_decoded` 中；

4. 返回变量 `str_decoded` 的值至调用环境。

> [!NOTE]
>
> 由于同一份 RTF 文档，其单元格内的转义字符要么遵循 gbk 编码格式，要么遵循 utf8 编码格式，因此只需对单元格内的字符串进行一次正则匹配，即可获得其使用的编码格式。
