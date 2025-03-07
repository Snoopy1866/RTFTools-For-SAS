/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

options cmplib = sasuser.func;

%macro read_rtf(rtf,
                outdata,
                compress      = true,
                del_rtf_ctrl  = true,
                debug         = false
                ) / parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/read_rtf.md";
        %goto exit;
    %end;

    /*�������*/
    proc sql noprint;
        select * from DICTIONARY.CATALOGS where libname = "WORK" and memname = "SASMACR" and objname = "_MACRO_TRANSCODE";
    quit;
    %if &SQLOBS = 0 %then %do;
        %put ERROR: ǰ������ȱʧ�����ȼ����ļ� transcode.sas��;
        %goto exit;
    %end;

    /*�����ֲ�����*/
    %local i;

    /*����ȫ�ֱ���*/
    %if not %symexist(readrtf_exit_with_error) %then %do;
        %global readrtf_exit_with_error;
    %end;

    %if not %symexist(readrtf_exit_with_error_text) %then %do;
        %global readrtf_exit_with_error_text;
    %end;

    %let readrtf_exit_with_error = FALSE;
    %let readrtf_exit_with_error_text = %bquote();

    /*���� compress ����*/
    %if %upcase(&compress) = TRUE %then %do;
        %let compress = yes;
    %end;
    %else %if %upcase(&compress) = FALSE %then %do;
        %let compress = no;
    %end;
    %else %do;
        %put ERROR: ���� compress ֻ��ȡ TRUE �� FALSE��;
        %goto exit;
    %end;


    /*1. ��ȡ�ļ�·��*/
    %let reg_rtf_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_rtf_id = %sysfunc(prxparse(%superq(reg_rtf_expr)));
    %if %sysfunc(prxmatch(&reg_rtf_id, %superq(rtf))) %then %do;
        %let rtf_ref = %sysfunc(prxposn(&reg_rtf_id, 1, %superq(rtf)));
        %let rtf_loc = %sysfunc(prxposn(&reg_rtf_id, 2, %superq(rtf)));

        /*ָ�������ļ�������*/
        %if %bquote(&rtf_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&rtf_ref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&rtf_ref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtf_ref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&rtf_ref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtf_ref)) = 0 %then %do;
                %let fileloc = %qsysfunc(pathname(&rtf_ref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %superq(rtf_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(rtf_loc))) = 0 %then %do;
                %put ERROR: �ļ�·�� %superq(rtf_loc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;


    /*2. �Դ��ı���ʽ��ȡRTF�ļ�*/
    data _tmp_rtf_data(compress = &compress);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile %unquote(%str(%')&rtf_loc%str(%')) truncover;
        input line $char32767.;
    run;

    %if &SYSERR > 0 %then %do;
        %let readrtf_exit_with_error_text = %superq(SYSERRORTEXT);
        %goto exit_with_error;
    %end;


    /*3. ������ͷ��������ڱ�ͷ��Ƕ���з����µ� RTF �����������⣩*/
    data _tmp_rtf_data_polish_header(compress = &compress);
        set _tmp_rtf_data;

        len = length(line);

        length break_line $32767.;

        reg_header_break_id = prxparse("/^(\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{.*){\\line}$/o");
        reg_header_break_continue_id = prxparse("/^(.*){\\line}$/o");
        reg_header_break_end_id = prxparse("/^(.*\\cell})$/o");

        retain break_line "";
        retain break_line_found 0;

        if prxmatch(reg_header_break_id, strip(line)) then do; /*���ֱ�ͷ������������*/
            break_line = catt(break_line, prxposn(reg_header_break_id, 1, strip(line)));
            break_line_found = 1;
            delete;
        end;
        else if prxmatch(reg_header_break_continue_id, strip(line)) then do; /*������������*/
            if break_line_found = 1 then do;
                break_line = catt(break_line, "|", prxposn(reg_header_break_continue_id, 1, strip(line)));
                delete;
            end;
        end;
        else if prxmatch(reg_header_break_end_id, strip(line)) then do; /*���н���*/
            if break_line_found = 1 then do;
                break_line = catt(break_line, "|", prxposn(reg_header_break_end_id, 1, strip(line)));
                line = break_line;

                break_line_found = 0;
                break_line = "";
            end;
        end;
    run;


    /*5. ���������У�������ڳ����ַ������µ� RTF �����������⣩*/
    data _tmp_rtf_data_polish_body(compress = &compress);
        set _tmp_rtf_data_polish_header;

        length line_data_part $32767 line_data_part_buffer $32767;

        reg_data_line_start_id = prxparse("/^\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])*)$/o");
        reg_data_line_mid_id   = prxparse("/^((?:\\'[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])*)$/o");
        reg_data_line_end_id   = prxparse("/^((?:\\'[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])*)\\cell\}$/o");

        retain line_data_part "";
        retain line_data_part_found 0;

        if prxmatch(reg_data_line_start_id, strip(line)) then do;
            line_data_part_buffer = prxposn(reg_data_line_start_id, 1, strip(line));
            /*������ʽʹ����ASCII�ַ����ϣ�����ĳЩ�������б������ƥ�䣬��Ҫ��һ��ɸѡ*/
            if find(line_data_part_buffer, "\cell}") = 0 then do; /*������\cell}�����ܳ����������п�ͷ*/
                line_data_part_found = 1;
                line_data_part = strip(line);
                delete;
            end;
        end;

        if line_data_part_found = 1 then do;
            if prxmatch(reg_data_line_mid_id, strip(line)) then do;
                if find(strip(line), "\shppict") > 0 then do; /*������ \shppict ָ�� Word 97 ͼƬ����ͨ��������ҳü logo �У����������������г���*/
                    line_data_part_found = 0;
                    line_data_part = "";
                end;
                else do;
                    line_data_part_buffer = prxposn(reg_data_line_mid_id, 1, strip(line));
                    /*������ʽʹ����ASCII�ַ����ϣ�����ĳЩ�������б������ƥ�䣬��Ҫ��һ��ɸѡ*/
                    if find(line_data_part_buffer, "\cell}") = 0 and substr(line_data_part_buffer, 1, 5) ^= "\pard" then do; /*������ \cell}, \pard �����ܳ������������м�*/
                        if line_data_part_found = 1 then do;
                            line_data_part = cats(line_data_part, line_data_part_buffer);
                            delete;
                        end;
                    end;
                end;
            end;

            if prxmatch(reg_data_line_end_id, strip(line)) then do;
                line_data_part_buffer = prxposn(reg_data_line_end_id, 1, strip(line));
                if line_data_part_found = 1 then do;
                    line_data_part = cats(line_data_part, line_data_part_buffer, "\cell}");
                    line = line_data_part;

                    line_data_part_found = 0;
                    line_data_part = "";
                end;
            end;
        end;
    run;


    /*4. ʶ��������*/
    %let is_outlinelevel_found = 0;

    data _tmp_rtf_raw(compress = &compress);
        set _tmp_rtf_data_polish_body;
        
        /*��������*/
        retain var_n 0;

        /*����λ��*/;
        retain var_pointer 0;

        /*�Ƿ��ֱ�����*/
        retain is_outlinelevel_found 0;

        /*�Ƿ��ֱ�ͷ*/
        retain is_header_found 0;

        /*�Ƿ��ֱ�ͷ��Ԫ��߿�λ�ö���*/
        retain is_header_def_found 0;

        /*��ͷ��Ԫ�����λ��(�������µ���)*/
        retain header_cell_level 0;

        /*��ͷ��Ԫ�����߿�λ��*/
        retain header_cell_left_padding 0;

        /*��ͷ��Ԫ���Ҳ�߿�λ��*/
        retain header_cell_right_padding 0;

        /*�Ƿ��ֱ������*/
        retain is_data_found 0;

        /*
        ��ǰ rtf ����ָ��ı���λ��
        obs_var_pointer ���Ŷ�ȡ�� rtf ����������������󲻳��� var_n��
        ������һ�����ݵ���ʼλ�ñ�����Ϊ 0
        */
        retain obs_var_pointer 0;

        /*�۲����*/
        retain obs_seq 0;


        /*����������ʽɸѡ��ͷ������*/
        reg_outlinelevel_id    = prxparse("/\\outlinelevel\d/o");
        reg_header_line_id     = prxparse("/\\trowd\\trkeep\\trhdr\\trq[lcr]/o");
        reg_header_def_line_id = prxparse("/\\clbrdr[tlbr]\\brdrs\\brdrw\d*\\brdrcf\d*(?:\\clbrdr[tlbr]\\brdrs\\brdrw\d*\\brdrcf\d*)*\\cltxlrt[bl]\\clvertal[tcb](?:\\clcbpat\d*)?\\cellx(\d+)/o");
        reg_data_line_id       = prxparse("/^\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{1,5};|[\x20-\x7e])*)\\cell\}$/o");
        reg_sect_line_id       = prxparse("/\\sect\\sectd\\linex\d*\\endnhere\\pgwsxn\d*\\pghsxn\d*\\lndscpsxn\\headery\d*\\footery\d*\\marglsxn\d*\\margrsxn\d*\\margtsxn\d*\\margbsxn\d*/o");


        length context_raw $32767;

        /*���ֱ�����*/
        if prxmatch(reg_outlinelevel_id, strip(line)) then do;
            if is_outlinelevel_found = 0 then do;
                is_outlinelevel_found = 1;
                call symputx("is_outlinelevel_found", 1);
            end;
        end;

        /*���ֱ�ͷ*/
        else if prxmatch(reg_header_line_id, strip(line)) then do;
            is_header_found = 1;
            header_cell_level + 1;
        end;

        /*���ֱ�ͷ��Ԫ��߿�λ�õĶ���*/
        else if prxmatch(reg_header_def_line_id, strip(line)) then do;
            is_header_def_found = 1;
            header_cell_left_padding = header_cell_right_padding;
            header_cell_right_padding = input(prxposn(reg_header_def_line_id, 1, strip(line)), 8.);

            var_pointer + 1;
            var_n = max(var_n, var_pointer);
        end;


        /*��������*/
        else if prxmatch(reg_data_line_id, strip(line)) then do;
            if is_outlinelevel_found = 1 then do; /*�޶��ڱ������������У��ų�ҳü�е�����*/
                if is_header_found = 1 then do; /*�����ڿ����� \trhdr ��������У�ʵ���Ͼ��Ǳ�ͷ*/
                    if not prxmatch(reg_header_def_line_id, strip(line)) and is_header_def_found = 1 then do; /*��ͷ�߿�λ�ö����ѽ�������ָ������Ϊ 0*/
                        var_pointer = 0;
                    end;
                    flag_header = "Y";
                    var_pointer + 1;
                    var_n = max(var_n, var_pointer);
                    context_raw = prxposn(reg_data_line_id, 1, strip(line));
                end;
                else do; /*������*/
                    flag_data = "Y";
                    is_data_found = 1;
                    obs_var_pointer + 1;
                    if obs_var_pointer = 1 then do;
                        obs_seq + 1;
                    end;
                    context_raw = prxposn(reg_data_line_id, 1, strip(line));

                    header_cell_level = 0;
                end;
            end;

            is_header_def_found = 0;
            header_cell_left_padding = 0;
            header_cell_right_padding = 0;
        end;

        /*���ַֽڷ�*/
        else if prxmatch(reg_sect_line_id, strip(line)) then do;
            is_outlinelevel_found = 0;
        end;

        /*�������*/
        else do;
            if header_cell_right_padding > 0 then do;
                is_header_def_found = 0;
                header_cell_left_padding = 0;
                header_cell_right_padding = 0;
            end;

            if var_pointer > 0 then do; /*��ͷ������ʱ��������ָ��λ������Ϊ 0*/
                is_header_found = 0;
                var_pointer = 0;
            end;


            if obs_var_pointer = var_n then do; /*�����ж�����ʱ��������ָ��λ������Ϊ 0*/
                obs_var_pointer = 0;
            end;
        end;
    run;

    %if &is_outlinelevel_found = 0 %then %do;
        %put ERROR: �� RTF �ļ���δ���ִ�ټ���ı��⣬��ʹ�ÿ����� \outlinelevel ���� RTF �ļ��ı��⣡;
        %goto exit;
    %end;

    /*5. ɾ�� RTF ������*/
    %if %upcase(&del_rtf_ctrl) = TRUE %then %do;
        /*������-�յķ���*/
        %let reg_ctrl_1 = %bquote({\s*}|(?<!\\)[{}]);
        /*������-����*/
        %let reg_ctrl_2 = %bquote(\\li\d+);
        /*������-ȡ�����±�*/
        %let reg_ctrl_3 = %bquote(\\nosupersub);

        /*������-�ϱ�*/
        %let reg_ctrl_4 = %bquote(\{?\\super\s*((?:\\[\\\{\}]|[^\\\{\}])+)\}?); /*
                                                                               https://github.com/Snoopy1866/RTFTools-For-SAS/issues/20
                                                                               https://github.com/Snoopy1866/RTFTools-For-SAS/issues/26
                                                                              */

        /*�ϲ�reg_ctrl_1 ~ reg_ctrl_n*/
        %unquote(%nrstr(%%let reg_ctrl =)) %sysfunc(catx(%bquote(|) %unquote(%do i = 1 %to 3; %bquote(,)%bquote(&&reg_ctrl_&i) %end;)));

        data _tmp_rtf_raw_del_ctrl(compress = &compress);
            set _tmp_rtf_raw;
            reg_rtf_del_ctrl_id   = prxparse("s/(?:&reg_ctrl)\s*//o");
            reg_rtf_del_ctrl_id_4 = prxparse("s/(?:&reg_ctrl_4)\s*/$1/o");
            if flag_header = "Y" or flag_data = "Y" then do;
                context_raw = prxchange(reg_rtf_del_ctrl_id,   -1, strip(context_raw));
                context_raw = prxchange(reg_rtf_del_ctrl_id_4, -1, strip(context_raw));
            end;
        run;
    %end;
    %else %do;
        data _tmp_rtf_raw_del_ctrl(compress = &compress);
            set _tmp_rtf_raw;
        run;
    %end;


    /*6. ��ʼת��*/
    data _tmp_rtf_context(compress = &compress);
        set _tmp_rtf_raw_del_ctrl;
        if flag_header = "Y" or flag_data = "Y" then do;
            context = cell_transcode(context_raw);
        end;
    run;


    /*7. ����SAS���ݼ�*/
    proc sort data = _tmp_rtf_context(where = (flag_data = "Y")) out = _tmp_rtf_context_sorted(compress = &compress) presorted;
        by obs_seq obs_var_pointer;
    run;

    proc transpose data = _tmp_rtf_context_sorted out = _tmp_outdata prefix = COL;
        var context;
        id obs_var_pointer;
        by obs_seq;
    run;


    /*8. ���������ǩ*/
    proc sql noprint;
        /*��ȡ���в㼶�ı�ǩ*/
        create table _tmp_rtf_header as
            select
                a.header_cell_level,
                a.var_pointer,
                a.header_cell_left_padding,
                a.header_cell_right_padding,
                b.context
            from _tmp_rtf_context(where = (is_header_def_found = 1)) as a left join _tmp_rtf_context(where = (flag_header = "Y")) as b
                     on a.header_cell_level = b.header_cell_level and a.var_pointer = b.var_pointer;
        /*��ȡ��ǩ������*/
        select max(header_cell_level) into : max_header_level trimmed from _tmp_rtf_header;

        /*�ϲ����в㼶�ı�ǩ*/
        create table _tmp_rtf_header_expand as
            select
                a&max_header_level..var_pointer,
                catx("|", %unquote(%do i = 1 %to %eval(&max_header_level - 1);
                                       %bquote(a&i..context)%bquote(,)
                                   %end;)
                                   a&max_header_level..context)
                    as header_context length = 32767 /*������ length =32767 ���б�Ҫ�ģ���ʱ����� utf8 �ַ�ʱ����ֳ����쳣�����⣬ԭ��δ֪*/
            from _tmp_rtf_header(where = (header_cell_level = &max_header_level)) as a&max_header_level
                %do i = %eval(&max_header_level - 1) %to 1 %by -1;
                    left join _tmp_rtf_header(where = (header_cell_level = &i)) as a&i
                    on a&max_header_level..header_cell_left_padding >= a&i..header_cell_left_padding and a&max_header_level..header_cell_right_padding <= a&i..header_cell_right_padding
                %end;
                ;
    quit;

    /*��ǩ��һ������*/
    data _tmp_rtf_header_expand_polish;
        set _tmp_rtf_header_expand;
        reg_header_control_word_id = prxparse("s/\\animtext\d*\\ul\d*\\strike\d*\\b\d*\\i\d*\\f\d*\\fs\d*\\cf\d*\s*//o");
        
        header_context = prxchange(reg_header_control_word_id, -1, strip(header_context));

        if substr(header_context, 1, 1) = "|" then do;
            header_context = substr(header_context, 2);
        end;

        if header_context = "" then do;
            header_context = "�ձ�ǩ";
        end;
    run;


    /*9. �޸�SAS���ݼ�������*/
    proc sql noprint;
        /*��ȡ��������*/
        select nvar - 2 into : var_n from DICTIONARY.TABLES where libname = "WORK" and memname = "_TMP_OUTDATA";
        
        %do i = 1 %to &var_n;
            /*��ȡ����ʵ�����賤��*/
            select max(length(col&i)) into : var_&i._maxlen from _tmp_outdata;

            /*��ȡ������ǩ*/
            select header_context into : var_&i._label trimmed from _tmp_rtf_header_expand_polish where var_pointer = &i;
        %end;

        alter table _tmp_outdata
            modify %do i = 1 %to &var_n;
                       COL&i char(&&var_&i._maxlen) label = "%superq(var_&i._label)",
                   %end;
                       OBS_SEQ label = "���";
        alter table _tmp_outdata
            drop _NAME_;
    quit;
    

    /*10. �������*/
    data &outdata;
        set _tmp_outdata;
    run;

    %goto exit;


    /*�쳣�˳�*/
    %exit_with_error:
    %let readrtf_exit_with_error = TRUE;

    /*�����˳�*/
    %exit:
    /*11. ����м����ݼ�*/
    %if %upcase(&debug) = FALSE %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_outdata
                   _tmp_rtf_data
                   _tmp_rtf_data_polish_header
                   _tmp_rtf_data_polish_body
                   _tmp_rtf_context
                   _tmp_rtf_context_sorted
                   _tmp_rtf_header
                   _tmp_rtf_header_expand
                   _tmp_rtf_header_expand_polish
                   _tmp_rtf_raw
                   _tmp_rtf_raw_del_ctrl
                  ;
        quit;
    %end;

    %put NOTE: �� read_rtf �ѽ������У�;
%mend;

