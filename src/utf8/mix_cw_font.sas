/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/sas-rtf-toolkit
*/

%macro mix_cw_font(rtf,
                   out   = #auto,
                   cfont = #auto,
                   wfont = #auto,
                   debug = false
                   ) / parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/sas-rtf-toolkit/blob/v2/docs/mix_cw_font.md";
        %goto exit;
    %end;


    /*1. 获取文件路径*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    %if %sysfunc(prxmatch(&reg_file_id, %superq(rtf))) %then %do;
        %let rtf_ref = %sysfunc(prxposn(&reg_file_id, 1, %superq(rtf)));
        %let rtf_loc = %sysfunc(prxposn(&reg_file_id, 2, %superq(rtf)));

        /*指定的是文件引用名*/
        %if %bquote(&rtf_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&rtf_ref)) > 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&rtf_ref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtf_ref)) < 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&rtf_ref) 指向的文件不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtf_ref)) = 0 %then %do;
                %let rtf_loc = %qsysfunc(pathname(&rtf_ref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %superq(rtf_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(rtf_loc))) = 0 %then %do;
                %put ERROR: 文件路径 %superq(rtf_loc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: 文件引用名超出 8 字节，或者文件物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;


    /*2 复制一份文件，规避文件已被外部打开导致读取冲突的问题*/
    %let file_suffix = %qscan(%superq(rtf_loc), -1, %str(.));
    %if %qupcase(&file_suffix) = RTF %then %do;
        %let rtf_loc_mixed = %qsysfunc(substr(%superq(rtf_loc), 1, %length(%superq(rtf_loc)) - 4))-mixed.rtf;
    %end;
    %else %do;
        %let rtf_loc_mixed = %superq(rtf_loc)-mixed.rtf;
    %end;
    X "copy ""&rtf_loc"" ""&rtf_loc_mixed"" & exit";


    /*3. 读取 rtf 文件*/
    data _tmp_rtf(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&rtf_loc_mixed" truncover;
        input line $char32767.;
    run;


    /*4. 识别字体表*/

    /*已知的常用字体，当 CFONT = #AUTO 或 WFONT = #AUTO，且在字体表中发现这些字体时，会自动应用到文本中*/
    %let cfont_predefined_list = %upcase('CSongGB18030C-Light', 'CSongGB18030C-LightHWL', 'DengXian', 'FangSong', 'KaiTi', 'Lisu', 'Noto Sans SC Regular', 'SimSun', 'YouYuan');
    %let wfont_predefined_list = %upcase('Arial', 'Calibri', 'Cascadia Code', 'Consolas', 'HelveticaNeueforSAS', 'HelveticaNeueforSAS Light', 'Times', 'Times New Roman');

    data _tmp_rtf_font_spec(compress = yes);
        set _tmp_rtf;

        seq = _n_;

        length is_fonttable_def       $1
               is_fonttable_def_start $1
               is_fonttable_def_end   $1
               font_name              $40
               font_lang              $1;
        /*使用正则识别字体表的定义*/
        if strip(line) = '{\fonttbl'    then is_fonttable_def_start = 'Y';
        if strip(line) = '}{\colortbl;' then is_fonttable_def_end   = 'Y';

        reg_fonttable_def_id = prxparse("/^\{\\f(\d+)\\froman\\fprq\d+\\fcharset\d+\\cpg\d+\s(.+)\x3B\}$/o");
        if prxmatch(reg_fonttable_def_id, strip(line)) then do;
            is_fonttable_def = 'Y';
            font_id   = input(prxposn(reg_fonttable_def_id, 1, strip(line)), 8.);
            font_name = prxposn(reg_fonttable_def_id, 2, strip(line));

            /*中西文字体分类*/
            retain cfont_seq wfont_seq;
            if upcase(font_name) in (&cfont_predefined_list) then do;
                font_lang = 'C';
                cfont_seq + 1;
            end;
            else if upcase(font_name) in (&wfont_predefined_list) then do;
                font_lang = 'W';
                wfont_seq + 1;
            end;
            else font_lang = 'O';
        end;
        else do;
            cfont_seq = .;
            wfont_seq = .;
        end;

        if font_lang = 'C' then call symputx('is_cfont_found', 'TRUE');
        if font_lang = 'W' then call symputx('is_wfont_found', 'TRUE');
    run;

    /*5. 提取或补充字体表*/
    %let is_cw_font_found = TRUE;
    %let is_cfont_found = FALSE;
    %let is_wfont_found = FALSE;

    %let last_font_id = 0;

    /*复制从开头到字体表定义结束位置的 RTF 代码行*/
    proc sql noprint;
        select seq into : font_def_end_seq trimmed from _tmp_rtf_font_spec where is_fonttable_def_end = 'Y'; /*字体表定义结束的行号*/
        create table _tmp_rtf_font_added as select * from _tmp_rtf_font_spec(firstobs = 1 obs = %eval(&font_def_end_seq - 1));
    quit;

    /*根据参数 CFONT 决定是否插入中文字体定义*/
    %if %qupcase(&cfont) = #AUTO %then %do;
        proc sql noprint;
            select font_id into : cfont_id trimmed from _tmp_rtf_font_spec where cfont_seq = 1;
        quit;

        /*字体表未定义中文字体*/
        %if &SQLOBS = 0 %then %do;
            %let is_cw_font_found = FALSE;
            X mshta vbscript:msgbox("未找到字体表中的中文字体，请手动指定参数 CFONT 为一个合适的中文字体名称！",4112,"提示")(window.close);
        %end;
    %end;
    %else %do;
        proc sql noprint;
            select ifn(not missing(font_id), font_id + 1, 1) into : last_font_id     trimmed from _tmp_rtf_font_spec where seq = &font_def_end_seq - 1;
        quit;

        %let cfont_id = &last_font_id;

        proc sql noprint;
            insert into _tmp_rtf_font_added
                set line             = "{\f&cfont_id\froman\fprq2\fcharset134\cpg936 %superq(cfont);}",
                    is_fonttable_def = 'Y',
                    font_name        = "%superq(cfont)",
                    font_lang        = 'C',
                    font_id          = &cfont_id;
        quit;
    %end;

    /*根据参数 WFONT 决定是否插入西文字体定义*/
    %if %qupcase(&wfont) = #AUTO %then %do;
        proc sql noprint;
            select font_id into : wfont_id trimmed from _tmp_rtf_font_spec where wfont_seq = 1;
        quit;

        /*字体表未定义西文字体*/
        %if &SQLOBS = 0 %then %do;
            %let is_cw_font_found = FALSE;
            X mshta vbscript:msgbox("未找到字体表中的西文字体，请手动指定参数 WFONT 为一个合适的西文字体名称！",4112,"提示")(window.close);
        %end;
    %end;
    %else %do;
        %if &last_font_id > 0 %then %do;
            %let wfont_id = %eval(&cfont_id + 1);
        %end;
        %else %do;
            proc sql noprint;
                select ifn(not missing(font_id), font_id + 1, 1) into : last_font_id     trimmed from _tmp_rtf_font_spec where seq = &font_def_end_seq - 1;
            quit;

            %let wfont_id = &last_font_id;
        %end;

        proc sql noprint;
            insert into _tmp_rtf_font_added
                set line             = "{\f&wfont_id\froman\fprq2\fcharset134\cpg936 %superq(wfont);}",
                    is_fonttable_def = 'Y',
                    font_name        = "%superq(wfont)",
                    font_lang        = 'W',
                    font_id          = &wfont_id;
        quit;
    %end;

    /*补齐剩余的 RTF 代码行*/
    data _tmp_rtf_font_added(compress = yes);
        set _tmp_rtf_font_added
            _tmp_rtf_font_spec(firstobs = &font_def_end_seq);
    run;

    %if &is_cw_font_found = FALSE %then %do;
        %goto exit;
    %end;


    /*6. 处理表头文字折行的问题*/
    data _tmp_rtf_polish(compress = yes);
        set _tmp_rtf_font_added;

        reg_header_cell_id = prxparse("/\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])+)\{\\line\}/o");

        length tmp_line $32767;
        retain tmp_line;

        if missing(tmp_line) then do;
            if prxmatch(reg_header_cell_id, trim(line)) then do;
                tmp_line = trim(line);

                if substr(trim(line), length(line) - 5) = '\cell}' then do; /*如果单元格内含有 {\line} 且以 \cell 结尾，则不保留 tmp_line 的值到下一个观测*/
                    line = tmp_line;
                    tmp_line = '';
                end;

                delete;
            end;
        end;
        else if not missing(tmp_line) then do;
            tmp_line = trim(tmp_line) || trim(line);

            if substr(trim(line), length(line) - 6) = '{\line}' then do; /*折行中间的文本，以 {\line} 结尾*/
                delete;
            end;
            else if substr(trim(line), length(line) - 5) = '\cell}' then do; /*折行末尾的文本，以 {\cell} 结尾*/
                line = tmp_line;
                tmp_line = '';
            end;
        end;

        keep line;
    run;


    /*7. 修改字体*/
    data _tmp_rtf_mixed(compress = yes);
        set _tmp_rtf_polish;
        length context_mixed $32767;

        /*修改单元格文本字体*/
        reg_cell_id = prxparse("/\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])+)\\cell\}/o");
        reg_cell_inside_id = prxparse("/\\animtext\d*\\ul\d*\\strike\d*\\b\d*\\i\d*\\f\d*\\fs\d*\\cf\d*((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])+)/o");
        reg_cell_change_font_id = prxparse("s/(?!<\\f&cfont_id )((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};)+)/\\f&cfont_id $1\\f&wfont_id /o");
        if prxmatch(reg_cell_id, trim(line)) then do;
            call prxposn(reg_cell_id, 1, st, len);
            context_mixed = substr(trim(line), st, len);

            if prxmatch(reg_cell_inside_id, trim(line)) then do; /*表头不止一行，需要进一步定位*/
                call prxposn(reg_cell_inside_id, 1, st, len);
                context_mixed = substr(trim(line), st, len);
            end;
            
            /*修改字体*/
            call prxchange(reg_cell_change_font_id, -1, trim(context_mixed), context_mixed);
            if find(context_mixed, "\f&cfont_id") ^= 1 then do;
                context_mixed = "\f&wfont_id " || trim(context_mixed);
            end;

            line = substr(line, 1, st - 1) || trim(context_mixed) || substr(line, st + len);
        end;

        /*修改标题文本字体*/
        reg_outllv_id = prxparse("/\\outlinelevel\d*\{((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])+)\}/o");
        reg_outlnlv_change_font_id = prxparse("s/(?!<\\f&cfont_id )((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};)+)/\\f&cfont_id $1\\f&wfont_id /o");

        if prxmatch(reg_outllv_id, trim(line)) then do;
            call prxposn(reg_outllv_id, 1, st, len);
            context_mixed = substr(trim(line), st, len);

            /*修改字体*/
            call prxchange(reg_outlnlv_change_font_id, -1, trim(context_mixed), context_mixed);
            if find(context_mixed, "\f&cfont_id") ^= 1 then do;
                context_mixed = "\f&wfont_id " || trim(context_mixed);
            end;

            line = substr(line, 1, st - 1) || trim(context_mixed) || substr(line, st + len);
        end;

        /*修改脚注文本字体*/
        reg_ftnt_id = prxparse("/\\pard\\b\d*\\i\d*\\chcbpat\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{\}\\q[lcr]\\fs\d*((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])+)\\cf\d*\\chcbpat\d*/o");
        reg_ftnt_change_font_id = prxparse("s/(?!<\\f&cfont_id )((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};)+)/\\f&cfont_id $1\\f&wfont_id /o");

        if prxmatch(reg_ftnt_id, trim(line)) then do;
            call prxposn(reg_ftnt_id, 1, st, len);
            context_mixed = substr(trim(line), st, len);

            /*修改字体*/
            call prxchange(reg_ftnt_change_font_id, -1, trim(context_mixed), context_mixed);
            if find(context_mixed, "\f&cfont_id") ^= 1 then do;
                context_mixed = "\f&wfont_id " || trim(context_mixed);
            end;

            line = substr(line, 1, st - 1) || trim(context_mixed) || substr(line, st + len);
        end;
    run;


    /*8. 输出文件*/
    %if %qupcase(&out) = #AUTO %then %do;
        %let outloc = %superq(rtf_loc_mixed);
    %end;
    %else %do;
        %let reg_out_id = %sysfunc(prxparse(%bquote(/^[\x22\x27]?(.+?)[\x22\x27]?$/o)));
        %if %sysfunc(prxmatch(&reg_out_id, %superq(out))) %then %do;
            %let outloc = %bquote(%sysfunc(prxposn(&reg_out_id, 1, %superq(out))));
        %end;
    %end;

    data _null_;
        set _tmp_rtf_mixed(keep = line);
        file "&outloc" lrecl = 32767;
        act_length = length(line);
        put line $varying32767. act_length;
    run;


    /*9. 删除中间数据集*/
    %if %qupcase(&debug) = FALSE %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf
                   _tmp_rtf_font_spec
                   _tmp_rtf_font_added
                   _tmp_rtf_polish
                   _tmp_rtf_list_fnst
                   _tmp_rtf_mixed
                  ;
        quit;
    %end;

    %if %qupcase(&out) ^= #AUTO %then %do;
        X "del ""&rtf_loc_mixed"" & exit";
    %end;


    %exit:
    %put NOTE: 宏 mix_cw_font 已结束运行！;
%mend;
