/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/sas-rtf-toolkit
*/

%macro compare_rtf(base,
                   compare,
                   outdata            = diff,
                   ignore_create_time = true,
                   ignore_header      = true,
                   ignore_footer      = true,
                   ignore_cell_style  = true,
                   ignore_font_table  = true,
                   ignore_color_table = true,
                   debug              = false
                   ) / parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/sas-rtf-toolkit/blob/v2/docs/compare_rtf.md";
        %goto exit;
    %end;

    /*1. ��ȡ�ļ�·��*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    /*base*/
    %if %sysfunc(prxmatch(&reg_file_id, %superq(base))) %then %do;
        %let base_ref = %sysfunc(prxposn(&reg_file_id, 1, %superq(base)));
        %let base_loc = %sysfunc(prxposn(&reg_file_id, 2, %superq(base)));

        /*ָ�������ļ�������*/
        %if %bquote(&base_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&base_ref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&base_ref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&base_ref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&base_ref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&base_ref)) = 0 %then %do;
                %let base_loc = %qsysfunc(pathname(&base_ref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %superq(base_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(base_loc))) = 0 %then %do;
                %put ERROR: �ļ�·�� %superq(base_loc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;

    /*compare*/
    %if %sysfunc(prxmatch(&reg_file_id, %superq(compare))) %then %do;
        %let compare_ref = %sysfunc(prxposn(&reg_file_id, 1, %superq(compare)));
        %let compare_loc = %sysfunc(prxposn(&reg_file_id, 2, %superq(compare)));

        /*ָ�������ļ�������*/
        %if %bquote(&compare_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&compare_ref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&compare_ref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compare_ref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&compare_ref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compare_ref)) = 0 %then %do;
                %let compare_loc = %qsysfunc(pathname(&compare_ref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %superq(compare_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(compare_loc))) = 0 %then %do;
                %put ERROR: �ļ�·�� %superq(compare_loc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;


    /*2. �Դ��ı���ʽ��ȡRTF�ļ�*/
    data _tmp_rtf_data_base(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile %unquote(%str(%')%superq(base_loc)%str(%')) truncover;
        input line $char32767.;
    run;

    data _tmp_rtf_data_compare(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile %unquote(%str(%')%superq(compare_loc)%str(%')) truncover;
        input line $char32767.;
    run;

    /*3. ������ԱȽϵĲ���*/
    /*3.1 ���������*/
    %if %upcase(&ignore_font_table) = TRUE %then %do;
        %let reg_fonttable_ini_expr = %bquote(/^\{\\fonttbl$/o);
        %let reg_fonttable_def_expr = %bquote(/^\{\\f\d+\\froman\\fprq\d+\\fcharset\d+\\cpg\d+\s.+\x3B\}$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_fonttable_ini_id = prxparse("&reg_fonttable_ini_expr");
            reg_fonttable_def_id = prxparse("&reg_fonttable_def_expr");

            if prxmatch(reg_fonttable_ini_id, strip(line)) then delete;
            if prxmatch(reg_fonttable_def_id, strip(line)) then delete;
        run;

        data _tmp_rtf_data_compare;
            set _tmp_rtf_data_compare;
            reg_fonttable_ini_id = prxparse("&reg_fonttable_ini_expr");
            reg_fonttable_def_id = prxparse("&reg_fonttable_def_expr");

            if prxmatch(reg_fonttable_ini_id, strip(line)) then delete;
            if prxmatch(reg_fonttable_def_id, strip(line)) then delete;
        run;
    %end;

    /*3.2 ������ɫ��*/
    %if %upcase(&ignore_color_table) = TRUE %then %do;
        %let reg_colortable_ini_expr = %bquote(/^\}?\{\\colortbl\x3B$/o);
        %let reg_colortable_def_expr = %bquote(/^\\red\d+\\green\d+\\blue\d+\x3B$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_colortable_ini_id = prxparse("&reg_colortable_ini_expr");
            reg_colortable_def_id = prxparse("&reg_colortable_def_expr");

            if prxmatch(reg_colortable_ini_id, strip(line)) then desc = "delete";
            if prxmatch(reg_colortable_def_id, strip(line)) then desc = "delete";
        run;

        data _tmp_rtf_data_compare;
            set _tmp_rtf_data_compare;
            reg_colortable_ini_id = prxparse("&reg_colortable_ini_expr");
            reg_colortable_def_id = prxparse("&reg_colortable_def_expr");

            if prxmatch(reg_colortable_ini_id, strip(line)) then desc = "delete";
            if prxmatch(reg_colortable_def_id, strip(line)) then desc = "delete";
        run;
    %end;

    /*3.3 ���Դ���ʱ��*/
    %if %upcase(&ignore_create_time) = TRUE %then %do;
        %let reg_creatim_expr = %bquote(/\\creatim\\yr\d{1,4}\\mo\d{1,2}\\dy\d{1,2}\\hr\d{1,2}\\min\d{1,2}\\sec\d{1,2}/o);
        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_creatim_id = prxparse("&reg_creatim_expr");

            if prxmatch(reg_creatim_id, strip(line)) then delete;
        run;

        data _tmp_rtf_data_compare;
            set _tmp_rtf_data_compare;
            reg_creatim_id = prxparse("&reg_creatim_expr");

            if prxmatch(reg_creatim_id, strip(line)) then delete;
        run;
    %end;

    /*3.4 ����ҳü*/
    %if %upcase(&ignore_header) = TRUE %then %do;
        %let reg_header_expr = %bquote(/^\{\\header\\pard\\plain\\q[lcr]\{$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_header_id = prxparse("&reg_header_expr");

            retain header_brace_unclosed; /*δ�պϵĴ���������*/
            retain header_start_flag 0
                   header_end_flag 0;
            if prxmatch(reg_header_id, strip(line)) then do; /*ҳü��ʼ*/
                header_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                header_start_flag = 1;
                delete;
            end;
            else if header_start_flag = 1 and header_end_flag = 0 then do;
                header_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if header_brace_unclosed = 0 then do; /*ҳü����*/
                    header_end_flag = 1;
                    header_brace_unclosed = .;
                    delete;
                end;
                else do; /*ҳü�м�*/
                    delete;
                end;
            end;
            else if header_brace_unclosed = . then do;
                header_start_flag = 0;
                header_end_flag = 0;
            end;
        run;

        data _tmp_rtf_data_compare;
            set _tmp_rtf_data_compare;
            reg_header_id = prxparse("&reg_header_expr");

            retain header_brace_unclosed; /*δ�պϵĴ���������*/
            retain header_start_flag 0
                   header_end_flag 0;
            if prxmatch(reg_header_id, strip(line)) then do; /*ҳü��ʼ*/
                header_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                header_start_flag = 1;
                delete;
            end;
            else if header_start_flag = 1 and header_end_flag = 0 then do;
                header_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if header_brace_unclosed = 0 then do; /*ҳü����*/
                    header_end_flag = 1;
                    header_brace_unclosed = .;
                    delete;
                end;
                else do; /*ҳü�м�*/
                    delete;
                end;
            end;
            else if header_brace_unclosed = . then do;
                header_start_flag = 0;
                header_end_flag = 0;
            end;
        run;
    %end;

    /*3.5 ����ҳ��*/
    %if %upcase(&ignore_footer) = TRUE %then %do;
        %let reg_footer_expr = %bquote(/^\{\\footer\\pard\\plain\\q[lcr]\{$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_footer_id = prxparse("&reg_footer_expr");

            retain footer_brace_unclosed; /*δ�պϵĴ���������*/
            retain footer_start_flag 0
                   footer_end_flag 0;
            if prxmatch(reg_footer_id, strip(line)) then do; /*ҳ�ſ�ʼ*/
                footer_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                footer_start_flag = 1;
                delete;
            end;
            else if footer_start_flag = 1 and footer_end_flag = 0 then do;
                footer_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if footer_brace_unclosed = 2 and strip(line) = "{\row}" then do; /*ҳ�Ž���*/
                    footer_end_flag = 1;
                    footer_brace_unclosed = .;
                    delete;
                end;
                else do; /*ҳ���м�*/
                    delete;
                end;
            end;
            else if footer_brace_unclosed = . then do;
                footer_start_flag = 0;
                footer_end_flag = 0;
            end;
        run;

        data _tmp_rtf_data_compare;
            set _tmp_rtf_data_compare;
            reg_footer_id = prxparse("&reg_footer_expr");

            retain footer_brace_unclosed; /*δ�պϵĴ���������*/
            retain footer_start_flag 0
                   footer_end_flag 0;
            if prxmatch(reg_footer_id, strip(line)) then do; /*ҳ�ſ�ʼ*/
                footer_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                footer_start_flag = 1;
                delete;
            end;
            else if footer_start_flag = 1 and footer_end_flag = 0 then do;
                footer_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if footer_brace_unclosed = 2 and strip(line) = "{\row}" then do; /*ҳ�Ž���*/
                    footer_end_flag = 1;
                    footer_brace_unclosed = .;
                    delete;
                end;
                else do; /*ҳ���м�*/
                    delete;
                end;
            end;
            else if footer_brace_unclosed = . then do;
                footer_start_flag = 0;
                footer_end_flag = 0;
            end;
        run;
    %end;

    /*3.6 ���Ե�Ԫ����ʽ*/
    %if %upcase(&ignore_cell_style) = TRUE %then %do;
        %let reg_cellstyle_expr = %bquote(/^(?:\\clbrdr[tblr]\\brdrs\\brdrw\d+\\brdrcf\d+)*\\cltxlrtb\\clvertal[tc](?:\\clcbpat\d+)?(?:\\clpadt\d+\\clpadft\d+\\clpadr\d+\\clpadfr\d+)?\\cellx\d+$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_cellstyle_id = prxparse("&reg_cellstyle_expr");

            if prxmatch(reg_cellstyle_id, strip(line)) then delete;
        run;

        data _tmp_rtf_data_compare;
            set _tmp_rtf_data_compare;
            reg_cellstyle_id = prxparse("&reg_cellstyle_expr");

            if prxmatch(reg_cellstyle_id, strip(line)) then delete;
        run;
    %end;


    /*4. �Ƚ��¾����ݼ�*/
    proc compare base = _tmp_rtf_data_base compare = _tmp_rtf_data_compare noprint;
    run;


    /*5. ����ȽϽ��*/
    %let _sysinfo = &sysinfo;
    data _tmp_outdata;
        base_path    = "&base_loc";
        compare_path = "&compare_loc";
        base_name    = scan(base_path, -1, "\");
        compare_name = scan(compare_path, -1, "\");
        diffyn       = ifc(&_sysinfo > 0, "Y", "");

        label base_path    = "base�ļ�·��"
              compare_path = "compare�ļ�·��"
              base_name    = "base�ļ���"
              compare_name = "compare�ļ���"
              diffyn       = "���ڲ���";
    run;


    /*6. �������*/
    data &outdata;
        set _tmp_outdata;
    run;


    %exit:
    /*7. ����м����ݼ�*/
    %if %upcase(&debug) = FALSE %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_data_base
                   _tmp_rtf_data_compare
                   _tmp_outdata
                  ;
        quit;
    %end;

    %put NOTE: �� compare_rtf �ѽ������У�;
%mend;
