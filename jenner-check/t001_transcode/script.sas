/* Adapted from src/utf8/transcode.sas (Snoopy1866/sas-rtf-toolkit) */
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
            rc = run_macro('_macro_transcode', code_point, raw_encoding, char, is_transcode_success); /*其他编码调用 KVCT 函数*/
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

/* --- caller: exercise transcode()/cell_transcode() on the UTF-8 path using the
   repo's own documented example (docs/transcode.md): the NCR sequence
   &#35797;&#39564;&#32452; decodes to the Chinese string meaning "trial group". --- */
options cmplib = sasuser.func;

data transcode_check;
    length source_code_point $60 raw_encoding $10 decoded $200;
    source_code_point = "&#35797;&#39564;&#32452;";
    raw_encoding = "utf8";
    decoded = transcode(source_code_point, raw_encoding);
run;

data cell_transcode_check;
    length cell_source $60 cell_decoded $200;
    cell_source = "\u35797;\u39564;\u32452;";
    cell_decoded = cell_transcode(cell_source);
run;

proc print data = transcode_check noobs;
    var source_code_point raw_encoding decoded;
run;

proc print data = cell_transcode_check noobs;
    var cell_source cell_decoded;
run;
