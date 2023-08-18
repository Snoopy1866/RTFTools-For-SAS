/*
名称：Cell_Transcode
功能：将 RTF 代码中单元格内的码点字符串转为当前环境下的编码对应的字符串
输出：字符串
细节：
1. 单元格内字符串开头的空格将被删除
*/
proc fcmp outlib = work.func.rtf inlib = work.func;
    function cell_transcode(str $) $5000;
        reg_code_id = prxparse("/((?:\\\x27[0-9A-F]{2})+)/o");
        
        length str_decoded $5000;
        str_decoded = str;
        do while(prxmatch(reg_code_id, str_decoded));
            _tmp_str = prxposn(reg_code_id, 1, str_decoded);
            _tmp_str_nomarkup = transtrn(_tmp_str, "\'", "");
            _tmp_str_decoded = transcode(_tmp_str_nomarkup, "gbk");
            str_decoded = transtrn(str_decoded, strip(_tmp_str), strip(_tmp_str_decoded));
        end;
        return(str_decoded);
    endsub;
quit;
