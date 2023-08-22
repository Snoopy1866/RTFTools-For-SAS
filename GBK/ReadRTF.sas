/*
## ReadRTF

### 程序信息

- 名称：ReadRTF.sas
- 类型：Macro
  - 参数数量：2
    - 参数 1：FILE（待转换的 RTF 文件的物理路径）
    - 参数 2：OUTDATA（转换后的 SAS 数据集名称）
- 依赖：[Cell_Transcode](./Cell_Transcode.md)
- 功能：SAS ODS RTF 使用 RTF 1.6 specification 输出 RTF 文件，本程序实现了将输出的 RTF 文件逆向转为 SAS 数据集的功能。

### 程序执行流程
1. 读取 RTF 文件，单行 RTF 字符串存储在变量 `line` 中；
2. 调整表头，部分 RTF 的表头含有回车，这可能会导致 RTF 代码在回车处折行，这一步解决了折行导致的变量标签无法正常解析的问题，该问题在 Table 中经常出现；
3. 识别表格中的数据。表格出现的标题后面，对于表格跨页的第一行数据，对应的 RTF 代码会稍有不同，使用以下正则表达式进行识别：
    - 表格标题：`/\\outlinelevel\d/o`
    - 表格数据：`\\pard\\plain\\intbl\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o`
    - 表格跨页的第一行数据：`^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o`
    - 表头标签：`^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o` 
    （与表格跨页的第一行数据的正则表达式相同，但可以通过在 RTF 文件中的位置进行区分。在表格数据之前匹配到的即为表头标签，之后匹配到的即为跨页的第一行数据。）
4. 开始转换数据。调用 [Cell_Transcode](./Cell_Transcode.md) 函数，将单元格内的字符串转换为可读的字符串；
5. 使用 `PROC TRANSPOSE` 对上一步产生的数据集进行转置；
6. 为数据集添加标签
7. 输出至参数 `OUTDATA` 指定的数据集中
8. 删除中间步骤产生的数据集

### 细节
- 由于 ODS RTF 输出至外部 RTF 文件时，丢失了变量名称，因此转换回 SAS 数据集时，变量名称根据变量出现的顺序，依次为 `COL1`, `COL2`, `COL3`, ...
- 对于单元格内的控制字，本程序将其当做普通 ASCII 字符处理，不会进行解析。例如：`\super` 将保留在 SAS 数据中
- 对于单元格内的转义字符，目前支持的编码有：GBK、UTF-8
- RTF 文件对单行文本长度没有限制，但是 SAS 数据集的变量长度有限制，尽管本程序使用了 32767 长度的变量用于存储 RTF 单行字符串的值，但仍然存在潜在的截断问题，此问题受限于 SAS 自身限制，无法修复
- 由于部分 RTF 表格的表头存在单元格合并，因此转换后的 SAS 数据集标签可能会错位，但不影响数据集的观测

*/


options cmplib = work.func;

%macro ReadRTF(file, outdata);
    /*1. 以纯文本形式读取RTF文件*/
    data _tmp_rtf_data(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&file" truncover;
        input line $char32767.;
    run;

    /*2. 调整表头（解决由于表头内嵌回车导致的 RTF 代码折行问题）*/
    data _tmp_rtf_data_polish(compress = yes);
        set _tmp_rtf_data;

        length break_line $32767.;

        reg_header_break_id = prxparse("/^(\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{.*){\\line}$/o");
        reg_header_break_continue_id = prxparse("/^(.*){\\line}$/o");
        reg_header_break_end_id = prxparse("/^(.*\\cell})$/o");

        retain break_line "";
        retain break_line_found 0;

        if prxmatch(reg_header_break_id, strip(line)) then do; /*发现表头出现折行问题*/
            break_line = catt(break_line, prxposn(reg_header_break_id, 1, strip(line)));
            break_line_found = 1;
            delete;
        end;
        else if prxmatch(reg_header_break_continue_id, strip(line)) then do; /*发现连续折行*/
            if break_line_found = 1 then do;
                break_line = catt(break_line, "|", prxposn(reg_header_break_continue_id, 1, strip(line)));
                delete;
            end;
        end;
        else if prxmatch(reg_header_break_end_id, strip(line)) then do; /*折行结束*/
            if break_line_found = 1 then do;
                break_line = catt(break_line, "|", prxposn(reg_header_break_end_id, 1, strip(line)));
                line = break_line;

                break_line_found = 0;
                break_line = "";
            end;
        end;
    run;



    /*3. 识别表格数据*/
    data _tmp_rtf_raw(compress = yes);
        set _tmp_rtf_data_polish;
        
        /*变量个数*/
        retain var_n 0;

        /*变量位置*/;
        retain var_pointer 0;

        /*是否发现表格标题*/
        retain is_outlinelevel_found 0;

        /*是否第一次发现keepn控制字*/
        retain is_keepn_first_found 0;

        /*是否发现表格数据*/
        retain is_data_found 0;

        /*
        当前 rtf 代码指向的变量位置
        obs_var_pointer 随着读取的 rtf 数据行数自增，最大不超过 var_n，
        且在下一段数据的起始位置被重置为 0
        */
        retain obs_var_pointer 0;

        /*观测序号*/
        retain obs_seq 0;


        /*定义正则表达式筛选表头和数据*/
        reg_outlinelevel_id = prxparse("/\\outlinelevel\d/o");
        reg_header_line_id = prxparse("/^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o");
        reg_data_line_id = prxparse("/^\\pard\\plain\\intbl\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o");

        length header_context_raw $1000
               data_context_raw $32767;

        /*开始提取有效数据*/
        if prxmatch(reg_outlinelevel_id, strip(line)) then do;
            if is_outlinelevel_found = 0 then do;
                is_outlinelevel_found = 1;
            end;
        end;

        if prxmatch(reg_header_line_id, strip(line)) then do;
            if is_keepn_first_found = 0 and is_outlinelevel_found = 1 then do; /*首次发现 keepn 控制字，表明这是表头*/
                var_pointer + 1;
                var_n = max(var_n, var_pointer);
                flag_header = "Y";
                header_context_raw = prxposn(reg_header_line_id, 1, strip(line));
            end;
            else do; /*非首次发现 keepn 控制字*/
                if is_data_found = 0 then do; /*连续发现 keepn 控制字，表明这是表头的第二行文本*/
                    var_pointer + 1;
                    var_n = max(var_n, var_pointer);
                    flag_header = "Y";
                    header_context_raw = prxposn(reg_header_line_id, 1, strip(line));
                end;
                else do; /*再次发现 keepn 控制字，表明这不是表头，而是表格跨页后的第一行数据*/
                    flag_data = "Y";
                    obs_var_pointer + 1;
                    if obs_var_pointer = 1 then do;
                        obs_seq + 1;
                    end;
                    data_context_raw = prxposn(reg_header_line_id, 1, strip(line));
                end;
            end;
        end;
        else do;
            if var_n > 0 then do;
                is_keepn_first_found = 1;
                var_pointer = 0;
            end;
            if obs_var_pointer = var_n then do; /*指针指向了最后一个变量，将指针位置重置为 1*/
                obs_var_pointer = 0;
            end;
        end;

        if prxmatch(reg_data_line_id, strip(line)) then do; /*发现数据行*/
            if is_outlinelevel_found = 1 then do; /*排除页眉文字*/
                flag_data = "Y";
                is_data_found = 1;
                obs_var_pointer + 1;
                if obs_var_pointer = 1 then do;
                    obs_seq + 1;
                end;
                data_context_raw = prxposn(reg_data_line_id, 1, strip(line));
            end;
        end;
    run;



    /*4. 开始转码*/
    data _tmp_rtf_context;
        set _tmp_rtf_raw;
        if flag_header = "Y" then do;
            header_context = cell_transcode(header_context_raw); /*调用自定义函数 cell_transcode*/
        end;

        if flag_data = "Y" then do;
            data_context = cell_transcode(data_context_raw); /*调用自定义函数 cell_transcode*/
        end;
    run;



    /*5. 生成SAS数据集*/
    proc sort data = _tmp_rtf_context(where = (flag_data = "Y")) out = _tmp_rtf_context_sorted;
        by obs_seq obs_var_pointer;
    run;

    proc transpose data = _tmp_rtf_context_sorted out = _tmp_outdata prefix = COL;
        var data_context;
        id obs_var_pointer;
        by obs_seq;
    run;

    

    /*6. 修改SAS数据集的属性*/
    proc sql noprint;
        /*获取变量个数*/
        select nvar - 2 into : var_n from DICTIONARY.TABLES where libname = "WORK" and memname = "_TMP_OUTDATA";
        
        %do i = 1 %to &var_n;
            /*获取变量字符实际长度最大值*/
            select max(length(col&i)) into : var_&i._maxlen from _tmp_outdata;
            /*获取变量标签*/
            select header_context into : var_&i._label separated by "|" from _tmp_rtf_context where flag_header = "Y" and var_pointer = &i;
                /*标签进一步处理*/
                %if %superq(var_&i._label) = %nrbquote() %then %do;
                    %let var_&i._label = %nrbquote(空标签);
                %end;
                %else %if %qsubstr(%superq(var_&i._label), 1, 1) = %nrbquote(|) %then %do;
                    %let var_&i._label = %substr(%superq(var_&i._label), 2);
                %end;
                %let reg_header_control_word_id = %sysfunc(prxparse(%nrbquote(s/\\animtext\d+\\ul\d+\\strike\d+\\b\d+\\i\d+\\f\d+\\fs\d+\\cf\d+\s+//o)));
                %let var_&i._label = %sysfunc(prxchange(&reg_header_control_word_id, -1, %superq(var_&i._label)));
        %end;

        alter table _tmp_outdata
            modify %do i = 1 %to &var_n;
                       COL&i char(&&var_&i._maxlen) label = "%sysfunc(strip(%superq(var_&i._label)))",
                   %end;
                       OBS_SEQ label = "序号";
        alter table _tmp_outdata
            drop _NAME_;
    quit;

    

    /*7. 最终输出*/
    data &outdata;
        set _tmp_outdata;
    run;


    
    /*8. 清除中间数据集*/
    proc datasets library = work nowarn noprint;
        delete _tmp_outdata
               _tmp_rtf_data
               _tmp_rtf_data_polish
               _tmp_rtf_context
               _tmp_rtf_context_sorted
               _tmp_rtf_raw
              ;
    quit;
%mend;

