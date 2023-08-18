/*
名称：Cell_Transcode
功能：将 RTF 代码中单元格内的码点字符串转为当前环境下的编码对应的字符串
输出：字符串
细节：
1. 单元格内字符串开头的空格将被删除
*/

proc fcmp outlib = work.func.rtf inlib = work.func;
    function cell_transcode(str $) $;
        reg_code_id = prxparse("/(?:(\\'[0-9A-F]{2})+)/o");
        start = 1;
        position = 1;
        last_position = 1;
        str_decoded = "";

        length str_decoded $32767;
        length _tmp_str $32767;
        do while(position > 0);
            call prxnext(reg_code_id, start, -1, str, position, length);
            if position >= last_position then do; /*下一段字符串存在码点*/
                _tmp_str = substr(str, position, length);
                _tmp_str_nomarkup = transtrn(_tmp_str, "\'", "");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "gbk");
                _tmp_decoded = substr(str, last_position, position - last_position) || _tmp_str_decoded;
                str_decoded = substr(trim(str_decoded), 1, length(trim(str_decoded)) - 1) || _tmp_decoded || '*';
                last_position = start;
            end;
            else if position = 0 then do; /*下一段字符串不存在码点*/
                str_decoded = substr(trim(str_decoded), 1, length(trim(str_decoded)) - 1) || substr(str, start);
            end;
        end;
        return(left(str_decoded));
    endsub;
quit;
