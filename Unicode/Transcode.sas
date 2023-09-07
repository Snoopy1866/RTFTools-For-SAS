/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
## Transcode

### 程序信息

- 名称：Transcode.sas
- 类型：PROC FCMP function
- 依赖：[%_MACRO_TRANSCODE](#_macro_transcode)
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

#### %_MACRO_TRANSCODE
程序 Transcode.sas 中包含了内置宏程序 `%_MACRO_TRANSCODE`，用于辅助实现转码，它在 PROC FCMP function 中被函数 `RUN_MACRO()` 调用，并返回一个状态码，变量 `IS_TRANSCODE_SUCCESS` 存储了这个状态码。

- IS_TRANSCODE_SUCCESS = 1，转码成功
- IS_TRANSCODE_SUCCESS = 0，转码失败
*/

%macro _macro_transcode;
    %let code_point = %sysfunc(dequote(&code_point));
    %let raw_encoding = %sysfunc(dequote(&raw_encoding));
    data _null_(encoding = asciiany);
        length char $32767;
        char = kcvt("&code_point"x, "&raw_encoding", getoption('encoding'));
        call symput("char", strip(char));
    run;

    %let is_transcode_success = 1;
%mend;



proc fcmp outlib = sasuser.func.rtf;
    function transcode(code_point $, raw_encoding $) $ 32767;
        length char $32767;

        is_transcode_success = 0;
        char = "";
        if raw_encoding = "utf8" then do; /*UTF-8 编码直接调用内置函数*/
            char = unicode(code_point, "NCR");
            return(char);
        end;
        else do;
            rc = run_macro('_macro_transcode', code_point, raw_encoding, char, is_transcode_success); /*其他编码调用 KVCT 函数，由于 KVCT 函数的特殊性，需要在无特定编码的 DATA 步中使用*/
            if rc = 0 and is_transcode_success = 1 then do;
                return(char);
            end;
            else do;
                return("ERROR: 转码失败！");
            end;
        end;
    endsub;
quit;
