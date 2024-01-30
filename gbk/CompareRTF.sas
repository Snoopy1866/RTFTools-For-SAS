/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareRTF(base, compare, ignorecreatim = yes, outdata = diff, del_temp_data = yes);
    /*1. 获取文件路径*/
    %let reg_file_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_file_id = %sysfunc(prxparse(%superq(reg_file_expr)));

    /*base*/
    %if %sysfunc(prxmatch(&reg_file_id, %superq(base))) = 0 %then %do;
        %put ERROR: 文件引用名超出 8 字节，或者文件物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;
    %else %do;
        %let baseref = %sysfunc(prxposn(&reg_file_id, 1, %superq(base)));
        %let baseloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(base)));

        /*指定的是文件引用名*/
        %if %bquote(&baseref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&baseref)) > 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&baseref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&baseref)) < 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&baseref) 指向的文件不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&baseref)) = 0 %then %do;
                %let baseloc = %sysfunc(pathname(&baseref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %bquote(&baseloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&baseloc)) = 0 %then %do;
                %put ERROR: 文件路径 %bquote(&baseloc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;

    /*compare*/
    %if %sysfunc(prxmatch(&reg_file_id, %superq(compare))) = 0 %then %do;
        %put ERROR: 文件引用名超出 8 字节，或者文件物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;
    %else %do;
        %let compareref = %sysfunc(prxposn(&reg_file_id, 1, %superq(compare)));
        %let compareloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(compare)));

        /*指定的是文件引用名*/
        %if %bquote(&compareref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&compareref)) > 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&compareref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compareref)) < 0 %then %do;
                %put ERROR: 文件名引用 %upcase(&compareref) 指向的文件不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compareref)) = 0 %then %do;
                %let compareloc = %sysfunc(pathname(&compareref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %bquote(&compareloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&compareloc)) = 0 %then %do;
                %put ERROR: 文件路径 %bquote(&compareloc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;


    /*2. 以纯文本形式读取RTF文件*/
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

    /*3. 处理忽略比较的部分*/
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

    /*4. 比较新旧数据集*/
    proc compare base = _tmp_rtf_data_base compare = _tmp_rtf_data_compare noprint;
    run;

    /*5. 储存比较结果*/
    %let _sysinfo = &sysinfo;
    data _tmp_outdata;
        base_path    = "&baseloc";
        compare_path = "&compareloc";
        base_name    = scan(base_path, -1, "\");
        compare_name = scan(compare_path, -1, "\");
        code         = &_sysinfo;
        diffyn       = ifc(code > 0, "Y", "");

        label base_path    = "base文件路径"
              compare_path = "compare文件路径"
              base_name    = "base文件名"
              compare_name = "compare文件名"
              code         = "返回码"
              diffyn       = "存在差异";
    run;

    /*6. 最终输出*/
    data &outdata;
        set _tmp_outdata;
    run;

    %exit:
    /*7. 清除中间数据集*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_data_base
                   _tmp_rtf_data_compare
                  ;
        quit;
    %end;

    %put NOTE: 宏 CompareRTF 已结束运行！;
%mend;
