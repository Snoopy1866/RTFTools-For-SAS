/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareRTFWithDataset(rtf, dataset, del_temp_data = yes,
                             ignoreLeadBlank = yes,
                             ignoreEmptyColumn = yes,
                             ignoreHalfOrFullWidth = yes) / parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/CompareRTFWithDataset.md";
        %goto exit;
    %end;

    /*1. ��ȡ�ļ�·��*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    %if %sysfunc(prxmatch(&reg_file_id, %superq(rtf))) = 0 %then %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
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
                %let rtfloc = %sysfunc(pathname(&rtfref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&rtfloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&rtfloc)) = 0 %then %do;
                %put ERROR: �ļ�·�� %bquote(&rtfloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;


    /*2. ���� %ReadRTF ��ȡRTF�ļ�*/
    %ReadRTF(file = "&rtfloc", outdata = _tmp_rtf(drop = obs_seq), compress = yes, del_rtf_ctrl = yes);


    /*3. ������ԱȽ�*/
    data _tmp_dataset;
        set &dataset;
    run;

    proc sql noprint;
        select name into : dataset_col_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_DATASET";
        %let dataset_col_n = &SQLOBS;
    quit;

    %if %upcase(&ignoreLeadBlank) = YES %then %do;
        data _tmp_dataset;
            set _tmp_dataset;
            %do i = 1 %to &dataset_col_n;
                &&dataset_col_&i = strip(&&dataset_col_&i);
            %end;
        run;
    %end;

    /*4. ͬ��������*/
    proc sql noprint;
        select name into : rtf_col_1-     from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF";
        %let rtf_col_n = &SQLOBS;
        
        %if &rtf_col_n ^= &dataset_col_n %then %do;
            %put ERROR: ����������ƥ�䣡;
            %goto exit;
        %end;
    quit;

    proc datasets library = work nowarn noprint;
        modify _tmp_rtf;
            rename %do i = 1 %to &rtf_col_n;
                       &&rtf_col_&i = &&dataset_col_&i
                   %end;
                   ;
    quit;



    /*5. �Ƚ� RTF �ļ������ݼ�*/
    proc compare base = _tmp_rtf compare = _tmp_dataset;
    run;


    %exit:
    /*6. ����м����ݼ�*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf
                   _tmp_dataset
                  ;
        quit;
    %end;

    %put NOTE: �� CompareRTFWithDataset �ѽ������У�;
%mend;
