/*
ÏêÏ¸ÎÄµµÇëÇ°Íù Github ²éÔÄ: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

proc fcmp outlib = sasuser.func.rtf inlib = sasuser.func flow;
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
            do while(prxmatch(reg_code_utf8_id, str_decoded));
                _tmp_str = prxposn(reg_code_utf8_id, 1, str_decoded);
                _tmp_str_nomarkup = transtrn(_tmp_str, "\u", "&#");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "utf8");
                reg_code_utf8_chg_id = prxparse("s/((?:\\u\d{1,5};)+)/"||trim(_tmp_str_decoded)||"/");
                str_decoded = prxchange(reg_code_utf8_chg_id, 1, strip(str_decoded));
            end;
        end;
        return(str_decoded);
    endsub;
quit;
