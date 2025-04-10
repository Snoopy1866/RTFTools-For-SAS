/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro merge_rtf(dir,
                 out              = #auto,
                 rtf_list         = #null,
                 depth            = max,
                 auto_order       = true,
                 exclude          = #null,
                 vd               = #auto,
                 merge            = true,
                 merged_file_show = short,
                 link_to_prev     = false,
                 debug            = false
                ) / parmbuff;

    /*打开帮助文档*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/merge_rtf.md";
        %goto exit;
    %end;


    /*1. 获取目录路径*/
    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[\x22\x27]?((?:[A-Za-z]:\\|\\\\[^\\\/:?\x22\x27<>|]+)[^\\\/:?\x22\x27<>|]+(?:\\[^\\\/:?\x22\x27<>|]+)*)[\x22\x27]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(dir))) %then %do;
        %let dir_ref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(dir)));
        %let dir_loc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(dir)));

        /*指定的是目录引用名*/
        %if %bquote(&dir_ref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&dir_ref)) > 0 %then %do;
                %put ERROR: 目录引用 %upcase(&dir_ref) 未定义！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&dir_ref)) < 0 %then %do;
                %put ERROR: 目录引用 %upcase(&dir_ref) 指向的目录不存在！;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&dir_ref)) = 0 %then %do;
                %let dir_loc = %qsysfunc(pathname(&dir_ref, F));
            %end;
        %end;

        /*指定的是物理路径*/
        %if %superq(dir_loc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(%superq(dir_loc))) = 0 %then %do;
                %put ERROR: 目录路径 %superq(dir_loc) 不存在！;
                %goto exit;
            %end;
        %end;
    %end;
    %else %do;
        %put ERROR: 目录引用名超出 8 字节，或者目录物理地址不符合 Winodws 规范！;
        %goto exit;
    %end;

    /*2. 建立虚拟磁盘*/
    %if %sysmexecname(%sysmexecdepth - 1) ^= MERGE_RTF %then %do;
        %let is_disk_symbol_all_used = FALSE;
        filename dlist pipe "wmic logicaldisk get deviceid";
        data _null_;
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

        X "subst &vd: ""&dir_loc"" & exit";
    %end;

    
    /*3. 是否指定外部文件作为 RTF 合并清单*/
    %if %upcase(&rtf_list) = #NULL %then %do; /*未指定外部文件*/

        /*使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
        X "dir ""&vd:\*.rtf"" /b/on/s > ""&vd:\_tmp_rtf_list.txt"" & exit";


        %if %upcase(&auto_order) = TRUE %then %do; /*自动排序*/
            /*提取 RTF 文件名中的信息*/
            data _tmp_rtf_list;
                infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
                input rtf_path $char1000.;

                /*真实路径*/
                rtf_path_real = cats("&dir_loc", substr(rtf_path, 3));

                /*识别表格和清单*/
                reg_table_id = prxparse("/^.*((列表|清单|(?<!列)表|图)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf)\s*$/o");

                /*筛选命名规范的 rtf 文件*/
                if prxmatch(reg_table_id, rtf_path) then do;
                    rtf_name  = prxposn(reg_table_id, 1, rtf_path); /*RTF 文件名*/
                    rtf_type  = prxposn(reg_table_id, 2, rtf_path); /*RTF 类型*/
                    rtf_seq   = prxposn(reg_table_id, 3, rtf_path); /*RTF 编号*/
                    ref_label = prxposn(reg_table_id, 4, rtf_path); /*RTF 描述文字*/
         
                    rtf_filename_valid_flag = "Y";
                end;

                /*文件类型衍生编码*/
                select (rtf_type);
                    when ("表") rtf_type_n = 1;
                    when ("图") rtf_type_n = 2;
                    when ("列表") rtf_type_n = 3;
                    when ("清单") rtf_type_n = 4;
                    otherwise rtf_type_n = constant("BIG");
                end;

                /*文件所在文件夹的深度*/
                rtf_dir_depth = count(rtf_path, "\");

                /*筛选指定深度的文件夹的 rtf 文件*/
                %if %upcase(&depth) = MAX %then %do;
                    rtf_depth_valid_flag = "Y";
                %end;
                %else %do;
                    if rtf_dir_depth <= &depth then do;
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
                   rtf_type_n
                   ref_label
                   rtf_dir_depth
                   ;
            run;
        %end;
        %else %if %upcase(&auto_order) = FALSE %then %do; /*手动排序*/
            X explorer "&vd:\_tmp_rtf_list.txt";
            X mshta vbscript:msgbox("请在弹出的窗口中手动调整 RTF 文件的合并顺序，保存后回到此弹窗，按确认按钮继续。对于无需合并的 RTF 文件，您可以在对应行的开头使用 '//' 进行注释，或直接删除对应行，空行将被忽略。",4160,"提示")(window.close);

            /*手动排序后，保存一份副本，以供后续调用时指定参数 RTF_LIST = rtf_list_copy.txt*/
            X "copy ""&vd:\_tmp_rtf_list.txt"" ""&vd:\rtf_list_copy.txt"" & exit";

            /*递归调用自身*/
            %merge_rtf(dir              = &dir,
                       out              = &out,
                       rtf_list         = rtf_list_copy.txt,
                       depth            = &depth,
                       auto_order       = &auto_order,
                       exclude          = &exclude,
                       vd               = &vd,
                       merge            = &merge,
                       merged_file_show = &merged_file_show,
                       debug            = &debug);
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
            rtf_path_real = cats("&dir_loc", substr(rtf_path, 3));

            /*文件名*/
            rtf_name = kscan(rtf_path, -1, "\");

            rtf_filename_valid_flag = "Y";
            rtf_depth_valid_flag = "Y";
        run;
    %end;


    %let run_start_time = %sysfunc(time()); /*记录开始时间*/


    /*4. 仅列出而不合并 rtf 文件，用于调试和试运行*/
    %if %upcase(&merge) = FALSE %then %do;
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


    /*5. 构造 filename 语句，建立文件引用*/
    data _tmp_rtf_list_fnst;
        set _tmp_rtf_list_add_lv_sorted(where = (rtf_filename_valid_flag = "Y" and rtf_depth_valid_flag = "Y")) end = end;

        fileref = 'rtf' || strip(put(_n_, 8.));
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);

        if end then call symput("rtf_ref_max", put(_n_, 8.)); /*获取需要合并的 rtf 文件的引用总数*/
    run;


    /*6. 读取 rtf 文件*/
    %if &rtf_ref_max = 0 %then %do;
        %put ERROR: 文件夹 &dir_loc 内没有符合要求的 rtf 文件可以合并！;
        %goto exit;
    %end;
    %else %if &rtf_ref_max = 1 %then %do;
        %put ERROR: 文件夹 &dir_loc 内只有一个符合要求的 rtf 文件，无需合并！;
        %goto exit;
    %end;
    %else %do;
        %do i = 1 %to &rtf_ref_max;
            %if %sysfunc(fileref(rtf&i)) < 0 %then %do;
                X mshta vbscript:msgbox("合并失败，文件 %qsysfunc(pathname(rtf&i, F)) 不存在！",4112,"提示")(window.close);
                %goto exit_with_no_merge;
            %end;
            %else %do;
                data _tmp_rtf&i(compress = yes);
                    informat line $32767.;
                    format line $32767.;
                    length line $32767.;

                    infile rtf&i truncover;
                    input line $char32767.;
                run;
            %end;
        %end;
    %end;

    
    /*7. 检测 rtf 文件是否被 SAS 之外的其他程序修改*/
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



    /*8. 获取可合并的 rtf 文件引用列表*/
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
        %put ERROR: 文件夹 &dir_loc 内没有可以合并的 rtf 文件！;
        %goto exit;
    %end;

    %do i = 1 %to &unmergeable_rtf_sum;
        %put ERROR: 文件 %superq(unmergeable_rtf_file_&i) 似乎被修改了，已跳过该文件！;
    %end;

    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;


    /*9. 处理 rtf 文件*/
    /*大致思路如下：

      预处理，删除第 2 个及之后的RTF文件的页眉页脚

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

        /*预处理，删除第 2 个及之后的RTF文件的页眉页脚*/
        %if %sysevalf(&i >= 2) %then %do;
            %if %upcase(&link_to_prev) = TRUE %then %do;
                %let reg_header_expr = %bquote(/^\{\\header\\pard\\plain\\q[lcr]\{$/o);
                %let reg_footer_expr = %bquote(/^\{\\footer\\pard\\plain\\q[lcr]\{$/o);

                /*页眉*/
                data _tmp_&mergeable_rtf_ref(compress = yes);
                    set _tmp_&mergeable_rtf_ref;

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

                /*页脚*/
                data _tmp_&mergeable_rtf_ref(compress = yes);
                    set _tmp_&mergeable_rtf_ref;

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
                            footer_brace_unclosed = -2;
                            delete;
                        end;
                        else do; /*页脚中间*/
                            delete;
                        end;
                    end;
                    else if footer_brace_unclosed = -2 then do; /*末尾 \pard}} 处理*/
                        if substr(strip(line), 1, 7) = "\pard}}" then do;
                            line = strip(substr(line, 8));
                            footer_brace_unclosed = .;
                        end;
                    end;
                    else if footer_brace_unclosed = . then do;
                        footer_start_flag = 0;
                        footer_end_flag = 0;
                    end;
                run;
            %end;
        %end;

        /*正式处理*/
        data _tmp_&mergeable_rtf_ref(compress = yes);
            set _tmp_&mergeable_rtf_ref end = end;
            
                %if %sysevalf(&i = 1) %then %do;
                    retain fst_sectd_found 1; /*开头的 rtf 文件不需要考虑是否已经找到第一行 \sectd，因此赋值为 1*/
                %end;
                %else %do;
                    retain fst_sectd_found 0; /*后续的 rtf 文件需要考虑是否找到第一行 \sectd，并添加 \sect，因此赋值为 0*/
                %end;

                /*分节符处理*/
                reg_sectd_id = prxparse("/^\\sectd\\linex\d\\endnhere(\\pgwsxn\d+\\pghsxn\d+\\lndscpsxn)?\\headery\d+\\footery\d+\\marglsxn\d+\\margrsxn\d+\\margtsxn\d+\\margbsxn\d+$/o");
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


    /*10. 合并 rtf 文件*/
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


    /*11. 输出 rtf 文件*/
    %if %upcase(&out) = #AUTO %then %do;
        %let date = %sysfunc(putn(%sysfunc(today()), yymmdd10.));
        %let time = %sysfunc(time());
        %let hour = %sysfunc(putn(%sysfunc(hour(&time)), z2.));
        %let minu = %sysfunc(putn(%sysfunc(minute(&time)), z2.));
        %let secd = %sysfunc(putn(%sysfunc(second(&time)), z2.));
        %let out = %bquote(merged-&date &hour-&minu-&secd..rtf);
    %end;
    %else %do;
        %let reg_out_id = %sysfunc(prxparse(%bquote(/^[\x22\x27]?(.+?)[\x22\x27]?$/o)));
        %if %sysfunc(prxmatch(&reg_out_id, %superq(out))) %then %do;
            %let out = %bquote(%sysfunc(prxposn(&reg_out_id, 1, %superq(out))));
        %end;
    %end;

    data _null_;
        set _tmp_rtf_merged;
        file "&vd:\&out" lrecl = 32767;
        act_length = length(line);
        put line $varying32767. act_length;
    run;


    /*12. 弹出提示框*/
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
    %if %upcase(&debug) = FALSE and %symexist(rtf_ref_max) %then %do;
        proc datasets library = work nowarn noprint;
            delete %do i = 1 %to &rtf_ref_max;
                       _tmp_rtf&i
                   %end;
                  ;
        quit;
    %end;


    %exit_with_no_merge:
    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;


    /*删除临时数据集*/
    %if %upcase(&debug) = FALSE %then %do;
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


    %put NOTE: 宏 merge_rtf 已结束运行！;

    %exit_with_recursive_end:
    %exit_with_error:
%mend;
