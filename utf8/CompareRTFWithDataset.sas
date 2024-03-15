/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareRTFWithDataset(rtf, dataset, del_temp_data = yes,
                             ignoreLeadBlank = yes,
                             ignoreEmptyColumn = yes,
                             ignoreHalfOrFullWidth = yes) / parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/CompareRTFWithDataset.md";
        %goto exit;
    %end;

    /*1. 获取文件路径*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    %if %sysfunc(prxmatch(&reg_file_id, %superq(rtf))) = 0 %then %do;
        %put ERROR: 文件引用名超出 8 字节，或者文件物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;
    %else %do;
        %let rtfref = %sysfunc(prxposn(&reg_file_id, 1, %superq(rtf)));
        %let rtfloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(rtf)));

        /*指定的是文件引用名*/
        %if %bquote(&rtfref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&rtfref)) > 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&rtfref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtfref)) < 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&rtfref) 指向的文件不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&rtfref)) = 0 %then %do;
                %let rtfloc = %sysfunc(pathname(&rtfref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %bquote(&rtfloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&rtfloc)) = 0 %then %do;
                %put ERROR: 文件路径 %bquote(&rtfloc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;


    /*2. 调用 %ReadRTF 读取RTF文件*/
    %ReadRTF(file = "&rtfloc", outdata = _tmp_rtf(drop = obs_seq), compress = yes, del_rtf_ctrl = yes);


    /*3. 处理忽略比较*/
    data _tmp_dataset;
        set &dataset;
    run;

    proc sql noprint;
        select name into : dataset_col_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_DATASET"; /*dataset 变量名*/
        %let dataset_col_n = &SQLOBS;

        select name into : rtf_col_1-     from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF"; /*rtf 变量名*/
        %let rtf_col_n = &SQLOBS;

        select name into : rtf_col_eq1_1- from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF" and length = 1; /*rtf 疑似空列变量名*/
        %let rtf_col_eq1_n = &SQLOBS;
    quit;

    /*3.1 忽略前置空格*/
    %if %upcase(&ignoreLeadBlank) = YES %then %do;
        data _tmp_dataset;
            set _tmp_dataset;
            %do i = 1 %to &dataset_col_n;
                &&dataset_col_&i = strip(&&dataset_col_&i);
            %end;
        run;
    %end;

    /*3.2 忽略空列*/
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

    /*4. 同步变量名*/
    proc sql noprint;
        select name into : rtf_col_1-     from DICTIONARY.COLUMNS where libname = "WORK" and memname = "_TMP_RTF";
        %let rtf_col_n = &SQLOBS;
        
        %if &rtf_col_n ^= &dataset_col_n %then %do;
            %put ERROR: 变量数量不匹配！;
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



    /*5. 比较 RTF 文件与数据集*/
    proc compare base = _tmp_rtf compare = _tmp_dataset;
    run;


    %exit:
    /*6. 清除中间数据集*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf
                   _tmp_dataset
                  ;
        quit;
    %end;

    %put NOTE: 宏 CompareRTFWithDataset 已结束运行！;
%mend;
