/*
���ƣ�Cell_Transcode
���ܣ��� RTF �����е�Ԫ���ڵ�����ַ���תΪ��ǰ�����µı����Ӧ���ַ���
������ַ���
ϸ�ڣ�
1. ��Ԫ�����ַ�����ͷ�Ŀո񽫱�ɾ��
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
