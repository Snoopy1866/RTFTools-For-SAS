/*
## Cell_Transcode

### 程序信息

- 名称：Cell_Transcode.sas
- 类型：PROC FCMP function
  - 函数存储位置：WORK.FUNC.RTF
  - 函数参数数量：1
    - 参数 1 ：STR（一串 RTF 的单元格内的字符，例如：`\'CA\'D4\'D1\'E9\'D7\'E9`，`\u35797;\u39564;\u32452;`）
  - 函数返回值：STR_DECODED（ASCII 字符保持不变，非 ASCII 字符转换为可阅读的字符）
  - 函数依赖的函数：[Transcode()](./Transcode.md)
- 功能：RTF Specification 规定只能使用 7 位 ASCII 字符，若要显示非 ASCII 字符，必须使用转义符，对于 GBK 编码格式的字符串，使用类似 `\'CA\'D4` 的形式表示，对于 Unicode 字符，使用 `\u21015;` 进行表示，本程序实现了将这些非 ASCII 字符转为原始字符串的功能

### 程序执行流程
1. 使用正则表达式判断参数 `STR` 的编码格式，具体如下：
  - GBK 编码格式：`/((?:\\\x27[0-9A-F]{2})+)/o`
  - UTF-8 编码格式：`/((?:\\u\d{5};)+)/o`
2. 根据编码格式，先对 RTF 中的非 ASCII 字符进行处理，对于 GBK 编码格式的转义字符，去除转义字符 `\'`；对于 UTF-8 编码格式的转义字符，将转义字符 `\u` 替换为 `&#`
3. 调用 PROC FCMP 函数 `Transcode()`，将返回值存储在变量 `STR_DECODED` 中
4. 返回变量 `STR_DECODED` 的值至调用环境
*/

proc fcmp outlib = work.func.rtf inlib = work.func;
    function cell_transcode(str $) $5000;
        reg_code_gbk_id = prxparse("/((?:\\\x27[0-9A-F]{2})+)/o");
        reg_code_utf8_id = prxparse("/((?:\\u\d{5};)+)/o");
        
        length str_decoded $5000;
        str_decoded = str;
        if prxmatch(reg_code_gbk_id, str_decoded) then do;
            do while(prxmatch(reg_code_gbk_id, str_decoded));
                _tmp_str = prxposn(reg_code_gbk_id, 1, str_decoded);
                _tmp_str_nomarkup = compress(_tmp_str, "\'");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "gbk");
                str_decoded = transtrn(str_decoded, strip(_tmp_str), strip(_tmp_str_decoded));
            end;
        end;
        else if prxmatch(reg_code_utf8_id, str_decoded) then do;
            do while(prxmatch(reg_code_utf8_id, str_decoded));
                _tmp_str = prxposn(reg_code_utf8_id, 1, str_decoded);
                _tmp_str_nomarkup = transtrn(_tmp_str, "\u", "&#");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "utf8");
                str_decoded = transtrn(str_decoded, strip(_tmp_str), strip(_tmp_str_decoded));
            end;
        end;
        return(str_decoded);
    endsub;
quit;
