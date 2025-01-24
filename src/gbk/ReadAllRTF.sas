/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

options cmplib = sasuser.func;

%macro ReadAllRTF(dir,
                  outlib        = work,
                  vd            = #AUTO,
                  compress      = yes,
                  del_rtf_ctrl  = yes,
                  del_temp_data = yes)/ parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/ReadAllRTF.md";
        %goto exit;
    %end;

    /*检测虚拟磁盘盘符使用状态*/
    %let is_disk_symbol_all_used = FALSE;
    filename dlist pipe "wmic logicaldisk get deviceid";
    data a;
        infile dlist truncover end = end;
        input disk_symbol $1.;
        retain unused_disk_symbol 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        unused_disk_symbol = transtrn(unused_disk_symbol, disk_symbol, trimn(''));
        if end then do;
            if length(unused_disk_symbol) = 0 then do;
                call symputx('is_disk_symbol_all_used', 'TRUE');
            end;
            else do;
                call symputx('unused_disk_symbol', unused_disk_symbol);
            end;
        end;
    run;

    %if &is_disk_symbol_all_used = TRUE %then %do;
        %put ERROR: 无剩余盘符可用，程序无法运行！;
        %goto exit_with_error;
    %end;

    %if %upcase(&vd) = #AUTO %then %do;
        %let vd = %substr(&unused_disk_symbol, 1, 1);
        %put NOTE: 自动选择可用的盘符 %upcase(&vd);
    %end;
    %else %do;
        %if not %sysfunc(find(&unused_disk_symbol, &vd)) %then %do;
            %put ERROR: 盘符 %upcase(&vd) 不合法或被占用，请指定其他合法或未被使用的盘符！;
            %goto exit_with_error;
        %end;
    %end;


    /*1. 获取目录路径*/
    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(dir))) %then %do;
        %let dirref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(dir)));
        %let dirloc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(dir)));

        /*指定的是目录引用名*/
        %if %bquote(&dirref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&dirref)) > 0 %then %do;
                %put ERROR: 目录引用 %upcase(&dirref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&dirref)) < 0 %then %do;
                %put ERROR: 目录引用 %upcase(&dirref) 指向的目录不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&dirref)) = 0 %then %do;
                %let dirloc = %qsysfunc(pathname(&dirref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %superq(dirloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(dirloc))) = 0 %then %do;
                %put ERROR: 目录路径 %superq(dirloc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: 目录引用名超出 8 字节，或者目录物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;


    X "subst &vd: ""&dirloc"" & exit"; /*建立虚拟磁盘*/

    /*1. 使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
    X "dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";


    /*2. 读取 _tmp_rtf_list.txt 文件，构建 filename 语句*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767. fnstm $char32767.;
        rtf_path = cats("&vd:\", rtf_name);

        /*识别表格和清单*/
        reg_table_id = prxparse("/^((?:列)?表|清单)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf\s*$/o");

        if prxmatch(reg_table_id, rtf_name) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_name);
            rtf_seq = prxposn(reg_table_id, 2, rtf_name);
            ref_label = prxposn(reg_table_id, 3, rtf_name);
            
            /*构造输出数据集名称*/
            if rtf_type = "表" then outdata_prefix = "t";
            else if rtf_type in ("列表", "清单") then outdata_prefix = "l";

            outdata_seq = transtrn(rtf_seq, ".", "_");

            outdata_name = "&outlib.." || outdata_prefix || "_" || outdata_seq;

            /*构造 filename 语句，建立文件引用*/
            fileref = 'rtf' || put(_n_, 8. -L);
            fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

            call execute(fnstm);

            /*标记命名规范的 rtf 文件*/
            rtf_valid_flag = "Y";
        end;
    run;


    /*3. 调用 %ReadRTF() 解析 RTF 文件*/
    data _null_;
        set _tmp_rtf_list;
        retain call_macro_n 0;

        if rtf_valid_flag = "Y" then do;
            call_macro_n + 1;
            call_macro_expr = '%ReadRTF(file = ' || strip(fileref) || ', outdata = ' || strip(outdata_name) || '(label = "' || strip(ref_label) || '"), compress = ' || "&compress" || ', del_rtf_ctrl = ' || "&del_rtf_ctrl" || ');';

            call symputx(cats("call_macro_expr_", call_macro_n), call_macro_expr);
        end;
        call symputx("call_macro_n", call_macro_n);
    run;

    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;

    %do i = 1 %to &call_macro_n;
        %unquote(%superq(call_macro_expr_&i));

        /*捕捉到读取错误，需要临时输出日志*/
        %if %bquote(&readrtf_exit_with_error) = TRUE %then %do;
            /*----------------临时恢复日志输出------------------*/
            proc printto log=log;
            run;

            %put ERROR: %superq(readrtf_exit_with_error_text);

            /*----------------关闭日志输出------------------*/
            proc printto log=_null_;
            run;
        %end;
    %end;

    /*----------------恢复日志输出------------------*/
    proc printto log=log;
    run;


    /*4. 删除临时数据集*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_list
                  ;
        quit;
    %end;


    /*5. 删除 _tmp_rtf_list.txt*/
    X " del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";


    %exit:
    %put NOTE: 宏 ReadAllRTF 已结束运行！;
%mend;
