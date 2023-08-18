/*
名称：ReadRTF.sas
功能：读取RTF文件
输出：SAS 数据集
细节：
1. 读取的单行RTF代码最长为32767字符，在某些极端情况下可能导致输出数据集中某些变量的值数据被截断
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



    /*2. 识别表格数据*/
    data _tmp_rtf_raw(compress = yes);
        set _tmp_rtf_data;
        
        /*变量个数*/
        retain var_n 0;

        /*是否第一次发现keepn控制字*/
        retain is_keepn_first_found 0;


        /*
        当前 rtf 代码指向的变量位置
        obs_var_pointer 随着读取的 rtf 行数自增，不超过 var_n 的最大值，
        且在下一段数据的起始位置被重置为 0
        */
        retain obs_var_pointer 0;

        /*观测序号*/
        retain obs_seq 0;


        /*定义正则表达式筛选表头和数据*/
        reg_header_line_id = prxparse("/^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\qc\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|[[:ascii:]])*)\\cell\}$/o");
        reg_data_line_id = prxparse("/^\\pard\\plain\\intbl\\sb\d*\\sa\d*\\qc\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|[[:ascii:]])*)\\cell\}$/o");

        length header_context_raw $1000
               data_context_raw $32767;
        /*开始提取有效数据*/
        if prxmatch(reg_header_line_id, strip(line)) then do;
            if is_keepn_first_found = 0 then do; /*首次发现keepn控制字，表明这是表头*/
                var_n + 1;
                flag_header = "Y";
                header_context_raw = prxposn(reg_header_line_id, 1, strip(line));
            end;
            else do; /*非首次发现keepn控制字，表明这不是表头，而是表格跨页后的第一行数据*/
                flag_data = "Y";
                obs_var_pointer + 1;
                if obs_var_pointer = 1 then do;
                    obs_seq + 1;
                end;
                data_context_raw = prxposn(reg_header_line_id, 1, strip(line));
            end;
        end;
        else do;
            if var_n > 0 then do;
                is_keepn_first_found = 1;
            end;
            if obs_var_pointer = var_n then do; /*指针指向了最后一个变量，将指针位置重置为 1*/
                obs_var_pointer = 0;
            end;
        end;

        if prxmatch(reg_data_line_id, strip(line)) then do;
            flag_data = "Y";
            obs_var_pointer + 1;
            if obs_var_pointer = 1 then do;
                obs_seq + 1;
            end;
            data_context_raw = prxposn(reg_data_line_id, 1, strip(line));
        end;
    run;



    /*3. 开始转码*/
    data _tmp_rtf_context;
        set _tmp_rtf_raw;
        if flag_header = "Y" then do;
            header_context = cell_transcode(header_context_raw); /*调用自定义函数 cell_transcode*/
        end;

        if flag_data = "Y" then do;
            data_context = cell_transcode(data_context_raw); /*调用自定义函数 cell_transcode*/
        end;
    run;



    /*4. 生成SAS数据集*/
    proc sort data = _tmp_rtf_context(where = (flag_data = "Y")) out = _tmp_rtf_context_sorted;
        by obs_seq obs_var_pointer;
    run;

    proc transpose data = _tmp_rtf_context_sorted out = _tmp_outdata prefix = COL;
        var data_context;
        id obs_var_pointer;
        by obs_seq;
    run;

    

    /*5. 修改SAS数据集的属性*/
    proc sql noprint;
        /*获取变量个数*/
        select nvar - 2 into : var_n from DICTIONARY.TABLES where libname = "WORK" and memname = "_TMP_OUTDATA";
        
        %do i = 1 %to &var_n;
            /*获取变量字符实际长度最大值*/
            select max(length(col&i)) into : var_&i._maxlen from _tmp_outdata;
            /*获取变量标签*/
            select header_context into : var_&i._label from _tmp_rtf_context where flag_header = "Y" and var_n = &i;
        %end;

        alter table _tmp_outdata
            modify %do i = 1 %to &var_n;
                       COL&i char(&&var_&i._maxlen) label = "%sysfunc(strip(&&var_&i._label))",
                   %end;
                       OBS_SEQ label = "序号";
        alter table _tmp_outdata
            drop _NAME_;
    quit;

    

    /*6. 最终输出*/
    data &outdata;
        set _tmp_outdata;
    run;


    
    /*7. 清除中间数据集*/
    proc datasets library = work nowarn noprint;
        delete _tmp_outdata
               _tmp_rtf_data
               _tmp_rtf_context
               _tmp_rtf_context_sorted
               _tmp_rtf_raw
              ;
    quit;
%mend;

