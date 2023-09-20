/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS

## MergeRTF

### 程序信息

- 名称：MergeRTF.sas
- 类型：Macro
- 依赖：无
- 功能：合并文件夹中的 RTF 文件。

### 程序执行流程

1. 根据参数 DIR 的值获取文件夹的物理路径
2. 使用 DOS 命令 `dir` 获取所有 RTF 文件，将文件路径存储在参数 DIR 指定的文件夹下的 `_tmp_rtf_list.txt` 中
3. 读取 `_tmp_rtf_list.txt`，识别、筛选符合要求的 RTF 文件
4. 对 RTF 文件进行排序
5. 对 RTF 文件建立文件引用（`filename` 语句）
6. 读取 RTF 文件
7. 检测 RTF 文件是否由 SAS 生成，且未被其他应用程序修改
8. 获取可以合并的 RTF 文件的引用列表
9. 处理 RTF 文件
10. 合并 RTF 文件
11. 输出合并后的 RTF 文件

### 参数

#### DIR

类型 : 必选参数

取值 : 指定 RTF 文件夹路径或引用。指定的文件夹路径或者引用的文件夹路径必须是一个合法的 Windows 路径。

- 指定物理路径时，可以传入带引号的路径或不带引号的路径，若传入不带引号的路径，建议使用 `%str()` 将路径包围
- 当指定的物理路径太长时，应当使用 filename 语句建立文件引用，然后传入文件引用，否则会导致 SAS 无法正确读取。

举例 :

```
DIR = "D:\~\TFL"
```

```
FILE = %str(D:\~\TFL)
```

```
filename ref "D:\~\TFL";
FILE = ref;
```

#### OUT

类型 : 可选参数

取值 : 指定合并后的 RTF 文件名称

默认值 : `merged-yyyy-mm-dd hh-mm-ss.rtf`，其中 `yyyy-mm-dd` 表示当前系统日期，`hh-mm-ss` 表示当前系统时间。

举例 :

```
out = "合并表格.rtf"

out = #auto
```

#### DEPTH

类型 : 可选参数

取值 : 指定读取子文件夹中 RTF 文件的递归深度

默认值 : 2

该参数适用于 `DIR` 指定的文件夹根目录没有任何 RTF 文件，但其子文件夹存在文件的情况。

例如：某项目的 RTF 文件按照其类型，存储在 `~\TFL` 目录下的 `table`, `figure`, `listing` 中，此时指定 `depth = 2`，宏程序将读取根目录 `~\TFL` 及其子文件夹 `~\TFL\table`, `~\TFL\figure`, `~\TFL\listing` 中的所有 RTF 文件，但不会读取 `~\TFL\table`, `~\TFL\figure`, `~\TFL\listing` 下的子文件夹中的 RTF 文件。

#### ORDER

类型 : 可选参数

取值 : 指定排列顺序，暂无作用

默认值 : #auto

#### VD

类型：可选参数

取值：指定临时创建的虚拟磁盘的盘符，该盘符必须是字母 A ~ Z 中未被使用的一个字符

默认值：X

#### EXCLUDE

类型：可选参数

取值：指定排除名单，暂无作用

默认值：#null

#### MERGE

类型：可选参数

取值：指定是否执行合并，可选 `YES|NO`

默认值：yes

💡 这个参数通常用于对宏程序的调试，不过如果你需要合并的 RTF 文件过多，或者你不确定指定的参数是否正确（尤其是参数 `DEPTH`），可以先指定参数 `MERGE = NO`，此时宏程序将不会执行合并操作，但会输出数据集 `WORK.RTF_LIST`，你可以查看此数据集，了解具体将会被合并的 RTF 文件。在该数据集中，仅当变量 `rtf_filename_valid_flag` 和 `rtf_depth_valid_flag` 同时为 `Y` 时，对应路径上的 RTF 文件才会被合并。
*/

%macro MergeRTF(dir, out = #auto, depth = 2, order = #auto, vd = X, exclude = #null, merge = yes);
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

    
    %let run_start_time = %sysfunc(time()); /*记录开始时间*/
    /*2. 使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
    X "subst &vd: ""&dirloc"" & dir ""&vd:\*.rtf"" /b/on/s > ""&vd:\_tmp_rtf_list.txt"" & exit";



    /*3. 读取 _tmp_rtf_list.txt，识别、筛选 rtf 文件*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_path $char1000.;

        /*识别表格和清单*/
        reg_table_id = prxparse("/^.*((?:列)?表|清单|图)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf\s*$/o");

        /*筛选命名规范的 rtf 文件*/
        if prxmatch(reg_table_id, rtf_path) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_path);
            rtf_seq = prxposn(reg_table_id, 2, rtf_path);
            ref_label = prxposn(reg_table_id, 3, rtf_path);
 
            rtf_filename_valid_flag = "Y";
        end;

        /*筛选指定深度的文件夹的 rtf 文件*/
        if count(rtf_path, "\") <= &depth then do;
            rtf_depth_valid_flag = "Y";
        end;
    run;

    /*4. 根据 RTF 文件名内的序号，自动排序*/
    %if %upcase(&order) = #AUTO %then %do;
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

    /*仅列出而不合并 rtf 文件，用于调试和试运行*/
    %if %upcase(&merge) = NO %then %do;
        data rtf_list;
            set _tmp_rtf_list_add_lv_sorted;
            label rtf_path = "路径"
                  rtf_filename_valid_flag = "文件名是否规范"
                  rtf_depth_valid_flag = "文件是否在指定深度内";
            keep rtf_path rtf_filename_valid_flag rtf_depth_valid_flag;
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
                select rtf_path into : rtf_path_&unmergeable_rtf_index trimmed from _tmp_rtf_list_fnst where fileref = "rtf&i";
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
        %put ERROR: 文件 %superq(rtf_path_&i) 似乎被修改了，已跳过该文件！;
    %end;

    /*----------------临时关闭日志输出------------------*/
    proc printto log=_null_;
    run;

    /*9. 处理 rtf 文件*/
    /*大致思路如下：
      开头的 rtf 文件，删除末尾的 }

      中间的 rtf 文件
      - 删除 \sectd 之前的所有行
      - 在 \sectd 前面添加 \sect
      - 删除末尾的 }
    

      结尾的 rtf 文件，保留末尾的 }
    */
    options symbolgen mlogic mprint;
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
                reg_sectd_id = prxparse("/^\\sectd\\linex\d\\endnhere\\pgwsxn\d+\\pghsxn\d+\\lndscpsxn(?:\\pgnrestart\\pgnstarts\d)?\\headery\d+\\footery\d+\\marglsxn\d+\\margrsxn\d+\\margtsxn\d+\\margbsxn\d+$/o");
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
                reg_outlinelevel_id = prxparse("/{\\\*\\bkmkstart\sIDX\d*}.*{\\\*\\bkmkend\sIDX\d*}/o");
                reg_outlinelevel_change_id = prxparse("s/{\\\*\\bkmkstart\sIDX\d*}.*{\\\*\\bkmkend\sIDX\d*}//o");
                reg_outlinelevel_delmark_id = prxparse("s/\\outlinelevel|\\s\d+//o");
                if prxmatch(reg_outlinelevel_id, strip(line)) then do;
                    latter_outlinelevel_text = hashing('MD5', prxchange(reg_outlinelevel_change_id, 1, strip(line)));

/*                    latter_outlinelevel_text = hashing('MD5', prxposn(reg_outlinelevel_id, 1, strip(line)));*/
                    if former_outlinelevel_text = latter_outlinelevel_text then do;
                        line = prxchange(reg_outlinelevel_delmark_id, 1, strip(line)); /*删除重复的大纲级别标记*/
                    end;
                    else do;
                        former_outlinelevel_text = latter_outlinelevel_text; /*更新用于比较的大纲级别文本*/
                    end;
                end;
 
                drop fst_sectd_found reg_sectd_id;


            %if %sysevalf(&i < &mergeable_rtf_ref_max) %then %do; /*删除末尾的 }（结尾的 rtf 文件保留 }）*/
                /*
                  防止空表导致下一张表跑到前一张表的结尾，加上这么一段控制字，正好要删掉结尾的 }，所以就直接修改了，
                  具体为什么这么写我也忘记了，最后一张表是空表的情况无需加上这段，因为没必要，后面也没有表了
                */
                if end then line = "\pard\pard\b0\i0\chcbpat8\qc\f1\fs21\cf1{}\ql\cf0\chcbpat0";
            %end;
        run;

        /*获取可合并的 rtf 文件名*/
        proc sql noprint;
            select rtf_path into : rtf_path_&i trimmed from _tmp_rtf_list_fnst where fileref = "&mergeable_rtf_ref";
        quit;
        %let mergeable_rtf_&i._end_time = %sysfunc(time()); /*记录单个 rtf 文件处理结束时间*/
        %let mergeable_rtf_&i._spend_time = %sysfunc(putn(%sysevalf(&&mergeable_rtf_&i._end_time - &&mergeable_rtf_&i._start_time), 8.2)); /*计算单个 rtf 文件处理耗时*/
    %end;
    options nosymbolgen nomlogic nomprint;


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
        %put NOTE: 文件 %superq(rtf_path_&i) 合并完成，耗时 &&mergeable_rtf_&i._spend_time s！;
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

    /*12. 弹出提示框*/
    %let run_end_time = %sysfunc(time()); /*记录结束时间*/
    %let run_spend_time = %sysfunc(putn(%sysevalf(&run_end_time - &run_start_time), 8.2)); /*计算耗时*/

    %if %sysevalf(&mergeable_rtf_ref_max < &rtf_ref_max) %then %do;
        X mshta vbscript:msgbox("合并成功，耗时 &run_spend_time s！部分已被修改的 rtf 文件未合并，请查看日志详情！",48,"提示")(window.close);
    %end;
    %else %do;
        X mshta vbscript:msgbox("合并成功，耗时 &run_spend_time s！",64,"提示")(window.close);
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
    proc datasets library = work nowarn noprint;
        delete _tmp_rtf_list
               _tmp_rtf_list_add_lv
               _tmp_rtf_list_add_lv_sorted
               _tmp_rtf_list_fnst
               _tmp_rtf_merged
              ;
    quit;


    /*----------------恢复日志输出------------------*/
    proc printto log=log;
    run;

    /*删除 _tmp_rtf_list.txt*/
    X "del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";

    /*删除 _null_.log 文件*/
    X "del _null_.log & exit";

    %put NOTE: 宏 MergeRTF 已结束运行！;
%mend;
