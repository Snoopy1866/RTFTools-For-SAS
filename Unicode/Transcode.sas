/*
名称    transcode
类型    PROC FCMP function
        存储位置    WORK.FUNC.RTF
        参数数量    2
                    参数1    CODE_POINT    码点
                    参数2    RAW_POINT     编码格式
        返回值      CHAR    转码后的字符串
        依赖宏      _MACRO_TRANSCODE
功能：将RTF文件中使用其他编码格式编码的字符串的码点转为当前环境下的编码对应的字符串
输出：转码状态，0 - 成功，1 - 失败
详细说明：
1. 宏程序 _macro_transcode 定义了转码的程序，并使用宏变量 is_transcode_success 定义了转码状态，0 代表成功，1 代表失败
2. 使用 PROC FCMP 定义了自定义函数 transcode，使用 run_macro 调用宏程序 _macro_transcode，返回值为转码后的字符
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



proc fcmp outlib = work.func.rtf;
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
