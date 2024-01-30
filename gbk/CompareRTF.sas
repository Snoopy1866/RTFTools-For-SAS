/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareRTF(base, compare, ignorecreatim = yes, outdata = diff, del_temp_data = yes);
    /*1. ��ȡ�ļ�·��*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    /*base*/
    %if %sysfunc(prxmatch(&reg_file_id, %superq(base))) = 0 %then %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
        %let baseref = %sysfunc(prxposn(&reg_file_id, 1, %superq(base)));
        %let baseloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(base)));

        /*ָ�������ļ�������*/
        %if %bquote(&baseref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&baseref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&baseref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&baseref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&baseref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&baseref)) = 0 %then %do;
                %let baseloc = %sysfunc(pathname(&baseref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&baseloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&baseloc)) = 0 %then %do;
                %put ERROR: �ļ�·�� %bquote(&baseloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;

    /*compare*/
    %if %sysfunc(prxmatch(&reg_file_id, %superq(compare))) = 0 %then %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
        %let compareref = %sysfunc(prxposn(&reg_file_id, 1, %superq(compare)));
        %let compareloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(compare)));

        /*ָ�������ļ�������*/
        %if %bquote(&compareref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&compareref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&compareref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compareref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&compareref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compareref)) = 0 %then %do;
                %let compareloc = %sysfunc(pathname(&compareref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&compareloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&compareloc)) = 0 %then %do;
                %put ERROR: �ļ�·�� %bquote(&compareloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;


    /*2. �Դ��ı���ʽ��ȡRTF�ļ�*/
    data _tmp_rtf_data_base(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&baseloc" truncover;
        input line $char32767.;
    run;

    data _tmp_rtf_data_compare(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&compareloc" truncover;
        input line $char32767.;
    run;

    /*3. ������ԱȽϵĲ���*/
    %if %upcase(&ignorecreatim) = YES %then %do;
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

    /*4. �Ƚ��¾����ݼ�*/
    proc compare base = _tmp_rtf_data_base compare = _tmp_rtf_data_compare noprint;
    run;

    /*5. ����ȽϽ��*/
    %let _sysinfo = &sysinfo;
    data _tmp_outdata;
        base_path    = "&baseloc";
        compare_path = "&compareloc";
        base_name    = scan(base_path, -1, "\");
        compare_name = scan(compare_path, -1, "\");
        code         = &_sysinfo;
        diffyn       = ifc(code > 0, "Y", "");

        label base_path    = "base�ļ�·��"
              compare_path = "compare�ļ�·��"
              base_name    = "base�ļ���"
              compare_name = "compare�ļ���"
              code         = "������"
              diffyn       = "���ڲ���";
    run;

    /*6. �������*/
    data &outdata;
        set _tmp_outdata;
    run;

    %exit:
    /*7. ����м����ݼ�*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_data_base
                   _tmp_rtf_data_compare
                  ;
        quit;
    %end;

    %put NOTE: �� CompareRTF �ѽ������У�;
%mend;
