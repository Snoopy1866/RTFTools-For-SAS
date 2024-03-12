/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareRTF(base, compare, outdata = diff, del_temp_data = yes,
                  ignorecreatim = yes,
                  ignoreheader = yes,
                  ignorefooter = yes,
                  ignorecellstyle = yes,
                  ignorefonttable = yes);
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
    /*3.1 忽略字体表*/
    %if %upcase(&ignorefonttable) = YES %then %do;
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

    /*3.2 忽略创建时间*/
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

    /*3.3 忽略页眉*/
    %if %upcase(&ignoreheader) = YES %then %do;
        %let reg_header_expr = %bquote(/^\{\\header\\pard\\plain\\q[lcr]\{$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_header_id = prxparse("&reg_header_expr");

            retain header_brace_unclosed; /*未闭合的大括号数量*/
            retain header_start_flag 0
                   header_end_flag 0;
            if prxmatch(reg_header_id, strip(line)) then do; /*页眉开始*/
                header_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                header_start_flag = 1;
                delete;
            end;
            else if header_start_flag = 1 and header_end_flag = 0 then do;
                header_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if header_brace_unclosed = 0 then do; /*页眉结束*/
                    header_end_flag = 1;
                    header_brace_unclosed = .;
                    delete;
                end;
                else do; /*页眉中间*/
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

            retain header_brace_unclosed; /*未闭合的大括号数量*/
            retain header_start_flag 0
                   header_end_flag 0;
            if prxmatch(reg_header_id, strip(line)) then do; /*页眉开始*/
                header_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                header_start_flag = 1;
                delete;
            end;
            else if header_start_flag = 1 and header_end_flag = 0 then do;
                header_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if header_brace_unclosed = 0 then do; /*页眉结束*/
                    header_end_flag = 1;
                    header_brace_unclosed = .;
                    delete;
                end;
                else do; /*页眉中间*/
                    delete;
                end;
            end;
            else if header_brace_unclosed = . then do;
                header_start_flag = 0;
                header_end_flag = 0;
            end;
        run;
    %end;

    /*3.4 忽略页脚*/
    %if %upcase(&ignorefooter) = YES %then %do;
        %let reg_footer_expr = %bquote(/^\{\\footer\\pard\\plain\\q[lcr]\{$/o);

        data _tmp_rtf_data_base;
            set _tmp_rtf_data_base;
            reg_footer_id = prxparse("&reg_footer_expr");

            retain footer_brace_unclosed; /*未闭合的大括号数量*/
            retain footer_start_flag 0
                   footer_end_flag 0;
            if prxmatch(reg_footer_id, strip(line)) then do; /*页脚开始*/
                footer_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                footer_start_flag = 1;
                delete;
            end;
            else if footer_start_flag = 1 and footer_end_flag = 0 then do;
                footer_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if footer_brace_unclosed = 2 and strip(line) = "{\row}" then do; /*页脚结束*/
                    footer_end_flag = 1;
                    footer_brace_unclosed = .;
                    delete;
                end;
                else do; /*页脚中间*/
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

            retain footer_brace_unclosed; /*未闭合的大括号数量*/
            retain footer_start_flag 0
                   footer_end_flag 0;
            if prxmatch(reg_footer_id, strip(line)) then do; /*页脚开始*/
                footer_brace_unclosed = (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                footer_start_flag = 1;
                delete;
            end;
            else if footer_start_flag = 1 and footer_end_flag = 0 then do;
                footer_brace_unclosed + (count(strip(line), "{") - count(strip(line), "\{")) - (count(strip(line), "}") - count(strip(line), "\}"));
                if footer_brace_unclosed = 2 and strip(line) = "{\row}" then do; /*页脚结束*/
                    footer_end_flag = 1;
                    footer_brace_unclosed = .;
                    delete;
                end;
                else do; /*页脚中间*/
                    delete;
                end;
            end;
            else if footer_brace_unclosed = . then do;
                footer_start_flag = 0;
                footer_end_flag = 0;
            end;
        run;
    %end;

    /*3.5 忽略单元格样式*/
    %if %upcase(&ignorecellstyle) = YES %then %do;
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
        diffyn       = ifc(&_sysinfo > 0, "Y", "");

        label base_path    = "base文件路径"
              compare_path = "compare文件路径"
              base_name    = "base文件名"
              compare_name = "compare文件名"
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
                   _tmp_outdata
                  ;
        quit;
    %end;

    %put NOTE: 宏 CompareRTF 已结束运行！;
%mend;
