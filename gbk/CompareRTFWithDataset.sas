/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareRTFWithDataset(rtf, dataset, del_temp_data = yes,
                             ignoreLeadBlank = yes,
                             ignoreEmptyColumn = yes,
                             ignoreHalfOrFullWidth = no,
                             ignoreEmbeddedBlank = no
                             ) / parmbuff;

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


    /*3. ���� dataset��ʹ�� sql into ��䴴�������*/
    data _tmp_dataset;
        set &dataset;
    run;

    proc sql noprint;
        select name into : dataset_col_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_DATASET"; /*dataset ������*/
        %let dataset_col_n = &SQLOBS;

        select type into : dataset_col_type_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_DATASET"; /*dataset ��������*/
        %let dataset_col_type_n = &SQLOBS;

        select ifc(not missing(format), format, "best.") into : dataset_col_format_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_DATASET"; /*dataset ���������ʽ*/
        %let dataset_col_format_n = &SQLOBS;

        select name into : rtf_col_1-     from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF"; /*rtf ������*/
        %let rtf_col_n = &SQLOBS;

        select name into : rtf_col_eq1_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF" and length = 1; /*rtf ���ƿ��б�����*/
        %let rtf_col_eq1_n = &SQLOBS;
    quit;


    /*4. Ԥ����*/
    /*4.1 dataset ����ֵת�����ַ���*/
    proc sql noprint;
        create table _tmp_dataset_char_ver as
            select
                %do i = 1 %to &dataset_col_n;
                    %if &&dataset_col_type_&i = num %then %do;
                        put(&&dataset_col_&i, &&dataset_col_format_&i) as &&dataset_col_&i
                    %end;
                    %else %do;
                        &&dataset_col_&i
                    %end;

                    %if &i < &dataset_col_n %then %do; %bquote(,) %end;
                %end;
            from _tmp_dataset;
    quit;

    /*4.2 dataset ����ǰ�ÿո�*/
    %if %upcase(&ignoreLeadBlank) = YES %then %do;
        data _tmp_dataset_char_ver;
            set _tmp_dataset_char_ver;
            %do i = 1 %to &dataset_col_n;
                &&dataset_col_&i = strip(&&dataset_col_&i);
            %end;
        run;
    %end;

    /*4.3 rtf ���Կ���*/
    %if %upcase(&ignoreEmptyColumn) = YES %then %do;
        %if &rtf_col_eq1_n > 0 %then %do;
            %do i = 1 %to &rtf_col_eq1_n;
                proc sql noprint;
                    select max(lengthn(&&rtf_col_eq1_&i)) into : col_len_max from _tmp_rtf;

                    %if &col_len_max = 0 %then %do;
                        alter table _tmp_rtf drop &&rtf_col_eq1_&i;
                    %end;
                quit;
            %end;
        %end;
    %end;

    /*4.4 rtf ����ȫ�ǰ�Ƿ���*/
    %if %upcase(&ignoreHalfOrFullWidth) = YES %then %do;
        %let HalfOrWidthTranslation = %nrstr(/*�����ţ��������ţ�*/
                                             ",", "��",
                                             ".", "��",
                                             "?", "��",
                                             "!", "��",
                                             ":", "��",
                                             ";", "��",
                                             "~", "��",

                                             /*����*/
                                             """", "��",
                                             """", "��",
                                             """", "��",
                                             """", "��",
                                             """", "��",
                                             '''', "��",
                                             '''', "��",
                                             '''', "��",
                                             '''', "��",
                                             '''', "��",

                                             /*����*/
                                             "(", "��",
                                             ")", "��",
                                             "<", "��",
                                             "<", "��",
                                             ">", "��",
                                             ">", "��",
                                             "[", "��",
                                             "]", "��",
                                             "{", "��",
                                             "}", "��",

                                             /*��ѧ����*/
                                             "0", "��", "1", "��", "2", "��", "3", "��", "4", "��",
                                             "5", "��", "6", "��", "7", "��", "8", "��", "9", "��",
                                             "+", "��", "-", "��", "*", "��", "/", "��", "\", "��", "^", "��",
                                             "=", "��",
                                             "%%", "��",

                                             /*������ĸ*/
                                             "a", "��", "b", "��", "c", "��", "d", "��", "e", "��", "f", "��", "g", "��", "h", "��", "i", "��", "j", "��", "k", "��", "l", "��", "m", "��",
                                             "n", "��", "o", "��", "p", "��", "q", "��", "r", "��", "s", "��", "t", "��", "u", "��", "v", "��", "w", "��", "x", "��", "y", "��", "z", "��",
                                             "A", "��", "B", "��", "C", "��", "D", "��", "E", "��", "F", "��", "G", "��", "H", "��", "I", "��", "J", "��", "K", "��", "L", "��", "M", "��",
                                             "N", "��", "O", "��", "P", "��", "Q", "��", "R", "��", "S", "��", "T", "��", "U", "��", "V", "��", "W", "��", "X", "��", "Y", "��", "Z", "��",

                                             /*�������*/
                                             "&", "��",
                                             "@", "��",
                                             "#", "��",
                                             "$", "��",
                                             "|", "��",
                                             "_", "��"
                                            );

        data _tmp_dataset_char_ver;
            set _tmp_dataset_char_ver;
            %do i = 1 %to &dataset_col_n;
                &&dataset_col_&i = ktranslate(&&dataset_col_&i, %unquote(%superq(HalfOrWidthTranslation)));
            %end;
        run;

        data _tmp_rtf;
            set _tmp_rtf;
            %do i = 1 %to &rtf_col_n;
                &&rtf_col_&i = ktranslate(&&rtf_col_&i, %unquote(%superq(HalfOrWidthTranslation)));
            %end;
        run;
    %end;

    /*4.5 ������Ƕ�ո�*/
    %if %upcase(&ignoreembeddedblank = yes) %then %do;
        data _tmp_dataset_char_ver;
            set _tmp_dataset_char_ver;
            %do i = 1 %to &dataset_col_n;
                &&dataset_col_&i = kcompress(&&dataset_col_&i, , "s");
            %end;
        run;

        data _tmp_rtf;
            set _tmp_rtf;
            %do i = 1 %to &rtf_col_n;
                &&rtf_col_&i = kcompress(&&rtf_col_&i, , "s");
            %end;
        run;
    %end;


    /*5. ͬ��������*/
    proc sql noprint;
        select name into : rtf_col_1-     from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF"; /*rtf ������*/
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


    /*6. �Ƚ� RTF �ļ������ݼ�*/
    proc compare base = _tmp_rtf compare = _tmp_dataset_char_ver;
    run;


    %exit:
    /*7. ����м����ݼ�*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf
                   _tmp_dataset
                   _tmp_dataset_char_ver
                  ;
        quit;
    %end;

    %put NOTE: �� CompareRTFWithDataset �ѽ������У�;
%mend;
