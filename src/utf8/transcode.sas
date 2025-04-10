/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/sas-rtf-toolkit
*/

/*删除数据集 SASUSER.FUNC，防止切换编码环境后重新运行无法被覆盖*/
proc datasets library = sasuser noprint nowarn;
    delete func;
quit;


/*内置宏，仅供 Fcmp 函数 run_macro() 使用*/
%macro _macro_transcode;
    %let code_point = %sysfunc(dequote(%superq(code_point)));
    %let raw_encoding = %sysfunc(dequote(&raw_encoding));
    data _null_(encoding = asciiany);
        length char $32767;
        char = kcvt("&code_point"x, "&raw_encoding", getoption('encoding'));
        call symput("char", strip(char));
    run;

    %let is_transcode_success = 1;
%mend;


/*自定义函数，用于解析码点*/
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


/*自定义函数，用于解析 RTF 单元格内的字符串*/
proc fcmp outlib = sasuser.func.rtf inlib = sasuser.func;
    function cell_transcode(str $) $32767;
        reg_code_gbk_id = prxparse("/((?:\\\x27[0-9A-F]{2})+)/o");
        reg_code_utf8_id = prxparse("/((?:\\u\d{1,5};)+)/o");
        
        length str_decoded $32767 _tmp_str $32767 _tmp_str_nomarkup $32767 _tmp_str_decoded $32767;
        str_decoded = str;
        if prxmatch(reg_code_gbk_id, str_decoded) then do;
            do while(prxmatch(reg_code_gbk_id, str_decoded));
                _tmp_str = prxposn(reg_code_gbk_id, 1, str_decoded);
                _tmp_str_nomarkup = compress(_tmp_str, "\'");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "gbk");
                reg_code_gbk_chg_id = prxparse("s/((?:\\\x27[0-9A-F]{2})+)/"||trim(_tmp_str_decoded)||"/");
                str_decoded = prxchange(reg_code_gbk_chg_id, 1, strip(str_decoded));
            end;
        end;
        else if prxmatch(reg_code_utf8_id, str_decoded) then do;
            _tmp_str = str_decoded;
            _tmp_str_nomarkup = transtrn(_tmp_str, "\u", "&#");
            _tmp_str_decoded = transcode(_tmp_str_nomarkup, "utf8");
            str_decoded = _tmp_str_decoded;
        end;
        return(str_decoded);
    endsub;
quit;
