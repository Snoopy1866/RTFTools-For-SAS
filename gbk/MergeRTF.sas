/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro MergeRTF(DIR,
                OUT              = #AUTO,
                RTF_LIST         = #NULL,
                DEPTH            = MAX,
                AUTOORDER        = YES,
                EXCLUDE          = #NULL,
                VD               = X,
                MERGE            = YES,
                MERGED_FILE_SHOW = SHORT,
                DEL_TEMP_DATA    = YES)
                /des = "合并RTF文件" parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/MergeRTF.md";
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

    X "subst &vd: ""&dirloc"" & exit"; /*建立虚拟磁盘*/

    /*2. 是否指定外部文件作为 RTF 合并清单*/
    %if %upcase(&rtf_list) = #NULL %then %do; /*未指定外部文件*/

        /*使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
        X "dir ""&vd:\*.rtf"" /b/on/s > ""&vd:\_tmp_rtf_list.txt"" & exit";


        %if %upcase(&autoorder) = YES %then %do; /*自动排序*/
            /*提取 RTF 文件名中的信息*/
            data _tmp_rtf_list;
                infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
                input rtf_path $char1000.;

                /*真实路径*/
                rtf_path_real = cats("&dirloc", substr(rtf_path, 3));

                /*识别表格和清单*/
                reg_table_id = prxparse("/^.*(((?:列)?表|清单|图)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf)\s*$/o");

                /*筛选命名规范的 rtf 文件*/
                if prxmatch(reg_table_id, rtf_path) then do;
                    rtf_name  = prxposn(reg_table_id, 1, rtf_path); /*RTF 文件名*/
                    rtf_type  = prxposn(reg_table_id, 2, rtf_path); /*RTF 类型*/
                    rtf_seq   = prxposn(reg_table_id, 3, rtf_path); /*RTF 编号*/
                    ref_label = prxposn(reg_table_id, 4, rtf_path); /*RTF 描述文字*/
         
                    rtf_filename_valid_flag = "Y";
                end;

                /*筛选指定深度的文件夹的 rtf 文件*/
                %if %upcase(&depth) = MAX %then %do;
                    rtf_depth_valid_flag = "Y";
                %end;
                %else %do;
                    if count(rtf_path, "\") <= &depth then do;
                        rtf_depth_valid_flag = "Y";
                    end;
                %end;
            run;


            /*计算 RTF 文件名包含的序号*/
            proc sql noprint;
                select max(count(rtf_seq, ".")) + 1 into : lv_max trimmed from _tmp_rtf_list; /*计算 rtf 文件名的序号的最大层级数量*/
                
                /*添加代表层级序号的变量，最多有 n 层，就添加 n 个变量，每个变量代表当前 rtf 文件在某个层级的顺序*/
                alter table _tmp_rtf_list
                        add %do i = 1 %to %eval(&lv_max - 1);
                                seq_lv_&i num,
                            %end;
                                seq_lv_&lv_max num
                            ;
            quit;

            data _tmp_rtf_list_add_lv;
                set _tmp_rtf_list;
                lv_max_curr_obs = countw(rtf_seq, "."); /*计算当前 rtf 文件名的序号的层级数量*/

                array seq_lv{&lv_max} seq_lv_1-seq_lv_&lv_max;

                do i = 1 to lv_max_curr_obs;
                    seq_lv{i} = input(scan(rtf_seq, i, "."), 8.);
                end;

                drop i lv_max_curr_obs;
            run;


            /*根据序号进行排序*/
            proc sort data = _tmp_rtf_list_add_lv out = _tmp_rtf_list_add_lv_sorted;
                by %do i = 1 %to &lv_max;
                       seq_lv_&i
                   %end;
                   ref_label
                   ;
            run;
        %end;
        %else %if %upcase(&autoorder) = NO %then %do; /*手动排序*/
            X explorer "&vd:\_tmp_rtf_list.txt";
            X mshta vbscript:msgbox("请在弹出的窗口中手动调整 RTF 文件的合并顺序，保存后回到此弹窗，按确认按钮继续。对于无需合并的 RTF 文件，您可以在对应行的开头使用 '//' 进行注释，或直接删除对应行，空行将被忽略。",4160,"提示")(window.close);

            /*手动排序后，保存一份副本，以供后续调用时指定参数 RTF_LIST = rtf_list_copy.txt*/
            X "copy ""&vd:\_tmp_rtf_list.txt"" ""&vd:\rtf_list_copy.txt"" & exit";

            /*递归调用自身*/
            %MergeRTF(dir              = &dir,
                      out              = &out,
                      rtf_list         = rtf_list_copy.txt,
                      depth            = &depth,
                      autoorder        = &autoorder,
                      exclude          = &exclude,
                      vd               = &vd,
                      merge            = &merge,
                      merged_file_show = &merged_file_show,
                      del_temp_data    = &del_temp_data);
            %goto exit_with_recursive_end;
        %end;
    %end;
    %else %do;
        /*直接读取外部文件*/
        data _tmp_rtf_list;
            infile "&vd:\&rtf_list" truncover encoding = 'gbke';
            input rtf_path $char1000.;

            if kcompress(rtf_path, , "s") = "" then delete; /*删除空行*/
            else if substr(strip(rtf_path), 1, 2) = "//" then delete; /*删除已注释的 RTF 文件*/
        run;

        /*兼容性处理*/
        data _tmp_rtf_list_add_lv_sorted;
            set _tmp_rtf_list;

            /*真实路径*/
            rtf_path_real = cats("&dirloc", substr(rtf_path, 3));

            /*文件名*/
            rtf_name = kscan(rtf_path, -1, "\");

            rtf_filename_valid_flag = "Y";
            rtf_depth_valid_flag = "Y";
        run;
    %end;


    %let run_start_time = %sysfunc(time()); /*记录开始时间*/


    /*3. 仅列出而不合并 rtf 文件，用于调试和试运行*/
    %if %upcase(&merge) = NO %then %do;
        data rtf_list;
            set _tmp_rtf_list_add_lv_sorted;
            label rtf_path = "虚拟磁盘路径"
                  rtf_path_real = "物理磁盘路径"
                  rtf_name = "文件名"
                  rtf_filename_valid_flag = "文件名是否规范"
                  rtf_depth_valid_flag = "文件是否在指定深度内";
            keep rtf_name rtf_path rtf_path_real rtf_filename_valid_flag rtf_depth_valid_flag;
        run;
        %goto exit_with_no_merge;
    %end;


    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;


    /*4. 构造 filename 语句，建立文件引用*/
    data _tmp_rtf_list_fnst;
        set _tmp_rtf_list_add_lv_sorted(where = (rtf_filename_valid_flag = "Y" and rtf_depth_valid_flag = "Y")) end = end;

        fileref = 'rtf' || strip(put(_n_, 8.));
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);

        if end then call symput("rtf_ref_max", put(_n_, 8.)); /*获取需要合并的 rtf 文件的引用总数*/
    run;


    /*5. 读取 rtf 文件*/
    %if &rtf_ref_max = 0 %then %do;
        %put ERROR: 文件夹 &dirloc 内没有符合要求的 rtf 文件可以合并！;
        %goto exit;
    %end;
    %else %if &rtf_ref_max = 1 %then %do;
        %put ERROR: 文件夹 &dirloc 内只有一个符合要求的 rtf 文件，无需合并！;
        %goto exit;
    %end;
    %else %do;
        %do i = 1 %to &rtf_ref_max;
            data _tmp_rtf&i(compress = yes);
                informat line $32767.;
                format line $32767.;
                length line $32767.;

                infile rtf&i truncover;
                input line $char32767.;
            run;
        %end;
    %end;

    
    /*6. 检测 rtf 文件是否被 SAS 之外的其他程序修改*/
    %do i = 1 %to &rtf_ref_max;
        data _null_;
            set _tmp_rtf&i(obs = 1);
            reg_rtf_file_valid_header_id = prxparse("/^{\\rtf1\\ansi\\ansicpg\d+\\uc\d+\\deff\d\\deflang\d+\\deflangfe\d+$/o");
            if prxmatch(reg_rtf_file_valid_header_id, strip(line)) then do;
                call symput("rtf&i._modified_flag", "N"); /*宏变量 rtf&i._modified_flag, 标识 rtf 文件是否被其他程序修改过*/
            end;
            else do;
                call symput("rtf&i._modified_flag", "Y");
            end;
        run;
    %end;



    /*7. 获取可合并的 rtf 文件引用列表*/
    %let mergeable_rtf_list = %bquote(); 
    %let unmergeable_rtf_index = 0;
    %do i = 1 %to &rtf_ref_max;
        %if &&rtf&i._modified_flag = N %then %do;
            %let mergeable_rtf_list = &mergeable_rtf_list rtf&i;
        %end;
        %else %do;
            %let unmergeable_rtf_index = %eval(&unmergeable_rtf_index + 1);
            proc sql noprint;
                select %if %upcase(&merged_file_show) = SHORT %then %do;
                           rtf_name
                       %end;
                       %else %if %upcase(&merged_file_show) = FULL %then %do;
                           rtf_path_real
                       %end;
                       %else %if %upcase(&merged_file_show) = VIRTUAL %then %do;
                           rtf_path
                       %end;
                       into : unmergeable_rtf_file_&unmergeable_rtf_index trimmed from _tmp_rtf_list_fnst where fileref = "rtf&i";
            quit;
        %end;
    %end;
    %let unmergeable_rtf_sum = &unmergeable_rtf_index;


    /*----------------恢复日志输出------------------*/
    proc printto log=log;
    run;


    %if &mergeable_rtf_list = %bquote() %then %do;
        %put ERROR: 文件夹 &dirloc 内没有可以合并的 rtf 文件！;
        %goto exit;
    %end;

    %do i = 1 %to &unmergeable_rtf_sum;
        %put ERROR: 文件 %superq(unmergeable_rtf_file_&i) 似乎被修改了，已跳过该文件！;
    %end;

    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;


    /*8. 处理 rtf 文件*/
    /*大致思路如下：
      开头的 rtf 文件，删除末尾的 }

      中间的 rtf 文件
      - 删除 \sectd 之前的所有行
      - 在 \sectd 前面添加 \sect
      - 删除末尾的 }
    

      结尾的 rtf 文件，保留末尾的 }
    */
    %let mergeable_rtf_ref_max = %sysfunc(countw(&mergeable_rtf_list, %bquote( )));
    %do i = 1 %to &mergeable_rtf_ref_max;
        %let mergeable_rtf_&i._start_time = %sysfunc(time()); /*记录单个 rtf 文件处理开始时间*/

        %let mergeable_rtf_ref = %scan(&mergeable_rtf_list, &i, %bquote( ));
        data _tmp_&mergeable_rtf_ref(compress = yes);
            set _tmp_&mergeable_rtf_ref end = end;
            
                %if %sysevalf(&i = 1) %then %do;
                    retain fst_sectd_found 1; /*开头的 rtf 文件不需要考虑是否已经找到第一行 \sectd，因此赋值为 1*/
                %end;
                %else %do;
                    retain fst_sectd_found 0; /*后续的 rtf 文件需要考虑是否找到第一行 \sectd，并添加 \sect，因此赋值为 0*/
                %end;

                /*分节符处理*/
                reg_sectd_id = prxparse("/^\\sectd\\linex\d\\endnhere\\pgwsxn\d+\\pghsxn\d+\\lndscpsxn\\headery\d+\\footery\d+\\marglsxn\d+\\margrsxn\d+\\margtsxn\d+\\margbsxn\d+$/o");
                if fst_sectd_found = 0 then do; /*首次发现 \sectd，在\sectd 前面添加 \sect，以便生成 rtf 文件之间的分节符*/
                    if prxmatch(reg_sectd_id, strip(line)) then do;
                        line = cats("\sect", strip(line)); 
                        fst_sectd_found = 1;
                    end;
                    else do;
                        delete; /*删除多余的元信息（字体表、颜色表等，这些信息在开头的 rtf 中已经被定义，无需重复定义）*/
                    end;
                end;

                /*大纲级别标记处理*/
                length former_outlinelevel_text latter_outlinelevel_text $32.;
                retain former_outlinelevel_text ""; /*用于比较的大纲级别文本*/
                reg_outlinelevel_id = prxparse("/\\outlinelevel\d{(.*)}/o");
                reg_outlinelevel_change_id = prxparse("s/\\outlinelevel\d//o");
                if prxmatch(reg_outlinelevel_id, strip(line)) then do;
                    latter_outlinelevel_text = hashing('MD5', prxposn(reg_outlinelevel_id, 1, strip(line)));
                    if former_outlinelevel_text = latter_outlinelevel_text then do;
                        line = prxchange(reg_outlinelevel_change_id, 1, strip(line)); /*删除重复的大纲级别标记*/
                    end;
                    else do;
                        former_outlinelevel_text = latter_outlinelevel_text; /*更新用于比较的大纲级别文本*/
                    end;
                end;
 
                drop fst_sectd_found reg_sectd_id;

            %if %sysevalf(&i < &mergeable_rtf_ref_max) %then %do; /*删除末尾的 }（结尾的 rtf 文件保留 }）*/
                if end then delete;
            %end;
        run;

        /*获取可合并的 rtf 文件名*/
        proc sql noprint;
            select %if %upcase(&merged_file_show) = SHORT %then %do;
                       rtf_name
                   %end;
                   %else %if %upcase(&merged_file_show) = FULL %then %do;
                       rtf_path_real
                   %end;
                   %else %if %upcase(&merged_file_show) = VIRTUAL %then %do;
                       rtf_path
                   %end;
                   into : merged_rtf_file_&i trimmed from _tmp_rtf_list_fnst where fileref = "&mergeable_rtf_ref";
        quit;
        %let mergeable_rtf_&i._end_time = %sysfunc(time()); /*记录单个 rtf 文件处理结束时间*/
        %let mergeable_rtf_&i._spend_time = %sysfunc(putn(%sysevalf(&&mergeable_rtf_&i._end_time - &&mergeable_rtf_&i._start_time), 8.2)); /*计算单个 rtf 文件处理耗时*/
    %end;


    /*9. 合并 rtf 文件*/
    data _tmp_rtf_merged(compress = yes);
        set %do i = 1 %to &mergeable_rtf_ref_max;
                _tmp_%scan(&mergeable_rtf_list, &i, %bquote( ))
            %end;
            ;
    run;


    /*----------------恢复日志输出------------------*/
    proc printto log=log;
    run;


    %do i = 1 %to &mergeable_rtf_ref_max;
        %put NOTE: 文件 %superq(merged_rtf_file_&i) 合并完成，耗时 &&mergeable_rtf_&i._spend_time s！;
    %end;


    /*10. 输出 rtf 文件*/
    %if %upcase(&out) = #AUTO %then %do;
        %let date = %sysfunc(putn(%sysfunc(today()), yymmdd10.));
        %let time = %sysfunc(time());
        %let hour = %sysfunc(putn(%sysfunc(hour(&time)), z2.));
        %let minu = %sysfunc(putn(%sysfunc(minute(&time)), z2.));
        %let secd = %sysfunc(putn(%sysfunc(second(&time)), z2.));
        %let out = %bquote(merged-&date &hour-&minu-&secd..rtf);
    %end;
    %else %do;
        %let reg_out_id = %sysfunc(prxparse(%bquote(/^[%str(%"%')]?(.+?)[%str(%"%')]?$/o)));
        %if %sysfunc(prxmatch(&reg_out_id, %superq(out))) %then %do;
            %let out = %bquote(%sysfunc(prxposn(&reg_out_id, 1, %superq(out))));
        %end;
        %put &=out;
    %end;

    data _null_;
        set _tmp_rtf_merged;
        file "X:\&out" lrecl = 32767;
        act_length = length(line);
        put line $varying32767. act_length;
    run;


    /*11. 弹出提示框*/
    %let run_end_time = %sysfunc(time()); /*记录结束时间*/
    %let run_spend_time = %sysfunc(putn(%sysevalf(&run_end_time - &run_start_time), 8.2)); /*计算耗时*/

    %if %sysevalf(&mergeable_rtf_ref_max < &rtf_ref_max) %then %do;
        X mshta vbscript:msgbox("合并成功，耗时 &run_spend_time s！部分已被修改的 rtf 文件未合并，请查看日志详情！",4144,"提示")(window.close);
    %end;
    %else %do;
        X mshta vbscript:msgbox("合并成功，耗时 &run_spend_time s！",4160,"提示")(window.close);
    %end;


    %exit:
    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;


    /*删除临时数据集*/
    proc datasets library = work nowarn noprint;
        delete %do i = 1 %to &rtf_ref_max;
                   _tmp_rtf&i
               %end;
              ;
    quit;


    %exit_with_no_merge:
    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;


    /*删除临时数据集*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_list
                   _tmp_rtf_list_add_lv
                   _tmp_rtf_list_add_lv_sorted
                   _tmp_rtf_list_fnst
                   _tmp_rtf_merged
                  ;
        quit;
    %end;
    

    /*----------------恢复日志输出------------------*/
    proc printto log=log;
    run;


    /*删除 _tmp_rtf_list.txt*/
    X "del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";

    /*删除 _null_.log 文件*/
    X "del _null_.log & exit";


    %put NOTE: 宏 MergeRTF 已结束运行！;

    %exit_with_recursive_end:
%mend;
