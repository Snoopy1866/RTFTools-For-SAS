/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

options cmplib = sasuser.func;

%macro ReadAllRTF(dir, outlib = work, vd = X, compress = yes, del_rtf_ctrl = yes)/ parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/ReadAllRTF.md";
        %goto exit;
    %end;

    /*1. 获取目录路径*/
    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(dir))) = 0 %then %do;
        %put ERROR: 目录引用名超出 8 字节，或者目录物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;
    %else %do;
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
                %let dirloc = %sysfunc(pathname(&dirref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %bquote(&dirloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&dirloc)) = 0 %then %do;
                %put ERROR: 目录路径 %bquote(&dirloc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;

    /*1. 使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
    X "subst &vd: ""&dirloc"" & dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";

    /*2. 读取 _tmp_rtf_list.txt 文件，构建 filename 语句*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
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
            fileref = 'rtf' || strip(_n_);
            fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

            call execute(fnstm);

            /*标记命名规范的 rtf 文件*/
            rtf_valid_flag = "Y";
        end;
    run;

    /*3. 调用 %ReadRTF() 解析 RTF 文件*/
    data _null_;
        set _tmp_rtf_list;
        if rtf_valid_flag = "Y" then do;
            call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || '(label = "' || ref_label || '"), compress = ' || "&compress" || ', del_rtf_ctrl = ' || "&del_rtf_ctrl" || '));');
        end;
    run;

    /*4. 删除临时数据集*/
    proc datasets library = work nowarn noprint;
        delete _tmp_rtf_list
              ;
    quit;

    /*5. 删除 _tmp_rtf_list.txt*/
    X " del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";

    %exit:
    %put NOTE: 宏 ReadAllRTF 已结束运行！;
%mend;

