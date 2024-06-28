/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro MixCWFont(RTF,
                 OUT              = #AUTO,
                 CFONT            = #AUTO,
                 WFONT            = #AUTO,
                 DEL_TEMP_DATA    = YES)
                 /des = "�������������" parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/MixCWFont.md";
        %goto exit;
    %end;


    /*1. ��ȡ�ļ�·��*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    %if %sysfunc(prxmatch(&reg_file_id, %superq(rtf))) %then %do;
        %let rtfref = %sysfunc(prxposn(&reg_file_id, 1, %superq(rtf)));
        %let rtfloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(rtf)));

        /*ָ�������ļ�������*/
        %if %bquote(&rtfref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&rtfref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&rtfref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtfref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&rtfref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtfref)) = 0 %then %do;
                %let rtfloc = %qsysfunc(pathname(&rtfref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %superq(rtfloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(rtfloc))) = 0 %then %do;
                %put ERROR: �ļ�·�� %superq(rtfloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;


    /*2 ����һ���ļ�������ļ��ѱ��ⲿ�򿪵��¶�ȡ��ͻ������*/
    %let file_suffix = %qscan(%superq(rtfloc), -1, %str(.));
    %if %qupcase(&file_suffix) = RTF %then %do;
        %let rtfloc_mixed = %qsysfunc(substr(%superq(rtfloc), 1, %length(%superq(rtfloc)) - 4))-mixed.rtf;
    %end;
    %else %do;
        %let rtfloc_mixed = %superq(rtfloc)-mixed.rtf;
    %end;
    X "copy ""&rtfloc"" ""&rtfloc_mixed"" & exit";


    /*3. ��ȡ rtf �ļ�*/
    data _tmp_rtf(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&rtfloc_mixed" truncover;
        input line $char32767.;
    run;


    /*4. ʶ�������*/

    /*��֪�ĳ������壬�� CFONT = #AUTO �� WFONT = #AUTO������������з�����Щ����ʱ�����Զ�Ӧ�õ��ı���*/
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
        /*ʹ������ʶ�������Ķ���*/
        if strip(line) = '{\fonttbl'    then is_fonttable_def_start = 'Y';
        if strip(line) = '}{\colortbl;' then is_fonttable_def_end   = 'Y';

        reg_fonttable_def_id = prxparse("/^\{\\f(\d+)\\froman\\fprq\d+\\fcharset\d+\\cpg\d+\s(.+)\x3B\}$/o");
        if prxmatch(reg_fonttable_def_id, strip(line)) then do;
            is_fonttable_def = 'Y';
            font_id   = input(prxposn(reg_fonttable_def_id, 1, strip(line)), 8.);
            font_name = prxposn(reg_fonttable_def_id, 2, strip(line));

            /*�������������*/
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

    /*5. ��ȡ�򲹳������*/
    %let is_cw_font_found = TRUE;
    %let is_cfont_found = FALSE;
    %let is_wfont_found = FALSE;

    %let last_font_id = 0;

    /*���ƴӿ�ͷ������������λ�õ� RTF ������*/
    proc sql noprint;
        select seq into : font_def_end_seq trimmed from _tmp_rtf_font_spec where is_fonttable_def_end = 'Y'; /*�������������к�*/
        create table _tmp_rtf_font_added as select * from _tmp_rtf_font_spec(firstobs = 1 obs = %eval(&font_def_end_seq - 1));
    quit;

    /*���ݲ��� CFONT �����Ƿ�����������嶨��*/
    %if %qupcase(&cfont) = #AUTO %then %do;
        proc sql noprint;
            select font_id into : cfont_id trimmed from _tmp_rtf_font_spec where cfont_seq = 1;
        quit;

        /*�����δ������������*/
        %if &SQLOBS = 0 %then %do;
            %let is_cw_font_found = FALSE;
            X mshta vbscript:msgbox("δ�ҵ�������е��������壬���ֶ�ָ������ CFONT Ϊһ�����ʵ������������ƣ�",4112,"��ʾ")(window.close);
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

    /*���ݲ��� WFONT �����Ƿ�����������嶨��*/
    %if %qupcase(&wfont) = #AUTO %then %do;
        proc sql noprint;
            select font_id into : wfont_id trimmed from _tmp_rtf_font_spec where wfont_seq = 1;
        quit;

        /*�����δ������������*/
        %if &SQLOBS = 0 %then %do;
            %let is_cw_font_found = FALSE;
            X mshta vbscript:msgbox("δ�ҵ�������е��������壬���ֶ�ָ������ WFONT Ϊһ�����ʵ������������ƣ�",4112,"��ʾ")(window.close);
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

    /*����ʣ��� RTF ������*/
    data _tmp_rtf_font_added(compress = yes);
        set _tmp_rtf_font_added
            _tmp_rtf_font_spec(firstobs = &font_def_end_seq);
    run;

    %if &is_cw_font_found = FALSE %then %do;
        %goto exit;
    %end;


    /*6. �����ͷ�������е�����*/
    data _tmp_rtf_polish(compress = yes);
        set _tmp_rtf_font_added;

        reg_header_cell_id = prxparse("/\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])+)\{\\line\}/o");

        length tmp_line $32767;
        retain tmp_line;

        if missing(tmp_line) then do;
            if prxmatch(reg_header_cell_id, trim(line)) then do;
                tmp_line = trim(line);

                if substr(trim(line), length(line) - 5) = '\cell}' then do; /*�����Ԫ���ں��� {\line} ���� \cell ��β���򲻱��� tmp_line ��ֵ����һ���۲�*/
                    line = tmp_line;
                    tmp_line = '';
                end;

                delete;
            end;
        end;
        else if not missing(tmp_line) then do;
            tmp_line = trim(tmp_line) || trim(line);

            if substr(trim(line), length(line) - 6) = '{\line}' then do; /*�����м���ı����� {\line} ��β*/
                delete;
            end;
            else if substr(trim(line), length(line) - 5) = '\cell}' then do; /*����ĩβ���ı����� {\cell} ��β*/
                line = tmp_line;
                tmp_line = '';
            end;
        end;

        keep line;
    run;


    /*7. �޸�����*/
    data _tmp_rtf_mixed(compress = yes);
        set _tmp_rtf_polish;
        length context_mixed $32767;

        /*�޸ĵ�Ԫ���ı�����*/
        reg_cell_id = prxparse("/\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])+)\\cell\}/o");
        reg_cell_inside_id = prxparse("/\\animtext\d*\\ul\d*\\strike\d*\\b\d*\\i\d*\\f\d*\\fs\d*\\cf\d*((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])+)/o");
        reg_cell_change_font_id = prxparse("s/(?!<\\f&cfont_id )((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};)+)/\\f&cfont_id $1\\f&wfont_id /o");
        if prxmatch(reg_cell_id, trim(line)) then do;
            call prxposn(reg_cell_id, 1, st, len);
            context_mixed = substr(trim(line), st, len);

            if prxmatch(reg_cell_inside_id, trim(line)) then do; /*��ͷ��ֹһ�У���Ҫ��һ����λ*/
                call prxposn(reg_cell_inside_id, 1, st, len);
                context_mixed = substr(trim(line), st, len);
            end;
            
            /*�޸�����*/
            call prxchange(reg_cell_change_font_id, -1, trim(context_mixed), context_mixed);
            if find(context_mixed, "\f&cfont_id") ^= 1 then do;
                context_mixed = "\f&wfont_id " || trim(context_mixed);
            end;

            line = substr(line, 1, st - 1) || trim(context_mixed) || substr(line, st + len);
        end;

        /*�޸ı����ı�����*/
        reg_outllv_id = prxparse("/\\outlinelevel\d*\{((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])+)\}/o");
        reg_outlnlv_change_font_id = prxparse("s/(?!<\\f&cfont_id )((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};)+)/\\f&cfont_id $1\\f&wfont_id /o");

        if prxmatch(reg_outllv_id, trim(line)) then do;
            call prxposn(reg_outllv_id, 1, st, len);
            context_mixed = substr(trim(line), st, len);

            /*�޸�����*/
            call prxchange(reg_outlnlv_change_font_id, -1, trim(context_mixed), context_mixed);
            if find(context_mixed, "\f&cfont_id") ^= 1 then do;
                context_mixed = "\f&wfont_id " || trim(context_mixed);
            end;

            line = substr(line, 1, st - 1) || trim(context_mixed) || substr(line, st + len);
        end;

        /*�޸Ľ�ע�ı�����*/
        reg_ftnt_id = prxparse("/\\pard\\b\d*\\i\d*\\chcbpat\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{\}\\q[lcr]\\fs\d*((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])+)\\cf\d*\\chcbpat\d*/o");
        reg_ftnt_change_font_id = prxparse("s/(?!<\\f&cfont_id )((?:\\\x27[0-9A-F]{2}|\\u\d{1,5};)+)/\\f&cfont_id $1\\f&wfont_id /o");

        if prxmatch(reg_ftnt_id, trim(line)) then do;
            call prxposn(reg_ftnt_id, 1, st, len);
            context_mixed = substr(trim(line), st, len);

            /*�޸�����*/
            call prxchange(reg_ftnt_change_font_id, -1, trim(context_mixed), context_mixed);
            if find(context_mixed, "\f&cfont_id") ^= 1 then do;
                context_mixed = "\f&wfont_id " || trim(context_mixed);
            end;

            line = substr(line, 1, st - 1) || trim(context_mixed) || substr(line, st + len);
        end;
    run;


    /*8. ����ļ�*/
    %if %qupcase(&out) = #AUTO %then %do;
        %let outloc = %superq(rtfloc_mixed);
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


    /*9. ɾ���м����ݼ�*/
    %if %qupcase(&del_temp_data) = YES %then %do;
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
        X "del ""&rtfloc_mixed"" & exit";
    %end;


    %exit:
    %put NOTE: �� MixCWFont �ѽ������У�;
%mend;
