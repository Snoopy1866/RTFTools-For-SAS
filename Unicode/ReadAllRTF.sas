options cmplib = work.func;
options cpucount = actual;
%macro ReadAllRTF(dir, tag = %str(列表 = L|表 = T|清单 = L), dlm = %str(_));

    /*1. 使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
    X "dir ""&dir\*.rtf"" /b/on > ""&dir\_tmp_rtf_list.txt"" & exit";

    /*2. 读取 _tmp_rtf_list.txt 文件，构建 filename 语句*/
    data _tmp_rtf_list;
        infile "&dir\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&dir", "\", rtf_name);

        /*识别表格和清单*/
        reg_table_id = prxparse("/^((?:列)?表|清单)(\d+(?:\.\d+)*)\s+(.*)\.rtf\s*$/o");

        if prxmatch(reg_table_id, rtf_name) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_name);
            rtf_seq = prxposn(reg_table_id, 2, rtf_name);
            ref_label = prxposn(reg_table_id, 3, rtf_name);
            
            /*构造输出数据集名称*/
            if rtf_type = "表" then outdata_prefix = "t";
            else if rtf_type in ("列表", "清单") then outdata_prefix = "l";

            outdata_seq = transtrn(rtf_seq, ".", "_");

            outdata_name = outdata_prefix || "_" || outdata_seq;

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
            call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || ', compress = yes' || '));');
        end;
    run;
%mend;

