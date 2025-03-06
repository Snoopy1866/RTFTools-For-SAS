/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro compare_rtf_dir(base_dir,
                       compare_dir,
                       ignore_create_time = true,
                       ignore_header      = true,
                       ignore_footer      = true,
                       ignore_cell_style  = true,
                       ignore_font_table  = true,
                       ignore_color_table = true,
                       outdata            = diff,
                       debug              = false
                       ) / parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/compare_rtf_dir.md";
        %goto exit;
    %end;

    /*检查依赖*/
    proc sql noprint;
        select * from DICTIONARY.CATALOGS where libname = "WORK" and memname = "SASMACR" and objname = "COMPARE_RTF";
    quit;
    %if &SQLOBS = 0 %then %do;
        %put ERROR: 前置依赖缺失，请先加载宏程序 %nrstr(%%)compare_rtf！;
        %goto exit;
    %end;

    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));

    /*1. 获取目录路径*/
    /*base*/
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(base_dir))) %then %do;
        %let base_dir_ref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(base_dir)));
        %let base_dir_loc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(base_dir)));

        /*指定的是目录引用名*/
        %if %bquote(&base_dir_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&base_dir_ref)) > 0 %then %do;
                %put ERROR: 目录引用 %upcase(&base_dir_ref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&base_dir_ref)) < 0 %then %do;
                %put ERROR: 目录引用 %upcase(&base_dir_ref) 指向的目录不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&base_dir_ref)) = 0 %then %do;
                %let base_dir_loc = %qsysfunc(pathname(&base_dir_ref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %superq(base_dir_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(base_dir_loc))) = 0 %then %do;
                %put ERROR: 目录路径 %superq(base_dir_loc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: 目录引用名超出 8 字节，或者目录物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;

    /*compare*/
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(compare_dir))) %then %do;
        %let compare_dir_ref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(compare_dir)));
        %let compare_dir_loc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(compare_dir)));

        /*指定的是目录引用名*/
        %if %bquote(&compare_dir_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&compare_dir_ref)) > 0 %then %do;
                %put ERROR: 目录引用 %upcase(&compare_dir_ref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compare_dir_ref)) < 0 %then %do;
                %put ERROR: 目录引用 %upcase(&compare_dir_ref) 指向的目录不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&compare_dir_ref)) = 0 %then %do;
                %let compare_dir_loc = %qsysfunc(pathname(&compare_dir_ref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %superq(compare_dir_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(compare_dir_loc))) = 0 %then %do;
                %put ERROR: 目录路径 %superq(compare_dir_loc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: 目录引用名超出 8 字节，或者目录物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;


    /*2. 使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list_base.txt 和 _tmp_rtf_list_compare.txt 中*/
    X "dir ""&base_dir_loc\*.rtf"" /b/on > ""&base_dir_loc\_tmp_rtf_list_base.txt"" & exit";
    X "dir ""&compare_dir_loc\*.rtf"" /b/on > ""&compare_dir_loc\_tmp_rtf_list_compare.txt"" & exit";


    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_; 
    run;

    /*3. 读取 _tmp_rtf_list.txt 文件，构建 filename 语句*/
    data _tmp_rtf_list_base;
        infile "&base_dir_loc\_tmp_rtf_list_base.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&base_dir_loc\", rtf_name);

        /*构造 filename 语句，建立文件引用*/
        fileref = 'brtf' || strip(_n_);
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);
    run;

    data _tmp_rtf_list_compare;
        infile "&compare_dir_loc\_tmp_rtf_list_compare.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&compare_dir_loc\", rtf_name);

        /*构造 filename 语句，建立文件引用*/
        fileref = 'crtf' || strip(_n_);
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);
    run;


    /*4. 合并 _tmp_rtf_list_base 和 _tmp_rtf_list_compare*/
    proc sql noprint;
        create table _tmp_rtf_list_bc as
            select
                ifc(not missing(a.rtf_name), a.rtf_name, b.rtf_name)
                                 as rtf_name,
                a.rtf_name       as base_rtf_name,
                a.fileref        as baseref,
                b.rtf_name       as compare_rtf_name,
                b.fileref        as compareref
            from _tmp_rtf_list_base as a full join _tmp_rtf_list_compare as b on a.rtf_name = b.rtf_name;
    quit;

    
    /*5. 调用 %compare_rtf() 比较 RTF 文件*/
    data _null_;
        set _tmp_rtf_list_bc;
        retain n 0;
        if not missing(base_rtf_name) and not missing(compare_rtf_name) then do;
            n + 1;
            call execute('%nrstr(%compare_rtf(base = ' || baseref ||
                                           ', compare = ' || compareref ||
                                           ', ignore_create_time = ' || "&ignore_create_time" ||
                                           ', ignore_header = ' || "&ignore_header" ||
                                           ', ignore_footer = ' || "&ignore_footer" ||
                                           ', ignore_cell_style = ' || "&ignore_cell_style" ||
                                           ', ignore_font_table = ' || "&ignore_font_table" ||
                                           ', ignore_color_table = ' || "&ignore_color_table" ||
                                           ', outdata = _tmp_diff_' || strip(n) || '));');
        end;
        call symputx("diff_n_max", n);
    run;

    /*----------------恢复日志输出------------------*/
    proc printto log=log;
    run;

    
    /*6. 输出差异比较结果*/
    %if &diff_n_max > 0 %then %do;
        proc sql noprint;
            create table _tmp_diff as
                select * from _tmp_diff_1
                %do i = 2 %to &diff_n_max;
                    outer union corr select * from _tmp_diff_&i
                %end;
                ;
        quit;
    %end;

    proc sql noprint;
        create table _tmp_outdata as
            select
                a.rtf_name,
                a.base_rtf_name,
                a.compare_rtf_name,
                (case when missing(a.base_rtf_name) and not missing(a.compare_rtf_name) then "Y" else "" end) as addyn length = 4, /*base -> compare 新增*/
                (case when not missing(a.base_rtf_name) and missing(a.compare_rtf_name) then "Y" else "" end) as delyn length = 4, /*base -> compare 删除*/
                (case when not missing(a.base_rtf_name) and not missing(a.compare_rtf_name) then
                    (select diffyn from _tmp_diff as b where a.base_rtf_name = b.base_name and a.compare_rtf_name = b.compare_name)
                      else ""
                end) as diffyn length = 4 /*base -> compare 差异*/
            from _tmp_rtf_list_bc as a;
    quit;

    proc sort data = _tmp_outdata sortseq = linguistic(numeric_collation = on) out = _tmp_outdata(drop = rtf_name);
        by rtf_name;
    run;


    /*7. 最终输出*/
    data &outdata;
        set _tmp_outdata;
        label base_rtf_name    = "base 文件"
              compare_rtf_name = "compare 文件"
              addyn            = "compare 中新增"
              delyn            = "base 中删除"
              diffyn           = "存在差异";
    run;


    %exit:
    /*8. 清除中间数据集*/
    %if %upcase(&debug) = FALSE %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_list_base
                   _tmp_rtf_list_compare
                   _tmp_rtf_list_bc
                   _tmp_diff
                   _tmp_outdata
                   %if %symexist(diff_n_max) %then %do;
                       %do i = 1 %to &diff_n_max;
                           _tmp_diff_&i
                       %end;
                   %end;
                  ;
        quit;
    %end;

    %if %symexist(base_dir_loc) and %symexist(compare_dir_loc) %then %do;
        /*删除 _tmp_rtf_list_base.txt 和 _tmp_rtf_list_compare.txt*/
        X "del ""&base_dir_loc\_tmp_rtf_list_base.txt"" & exit";
        X "del ""&compare_dir_loc\_tmp_rtf_list_compare.txt"" & exit";
    %end;

    /*删除 _null_.log 文件*/
    X "del _null_.log & exit";

    %put NOTE: 宏 compare_rtf_dir 已结束运行！;
%mend;
