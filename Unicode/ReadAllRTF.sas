options cmplib = work.rtf;

%macro ReadAllRTF(dir);

    /*使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
    X "dir ""&dir\*.rtf"" /b/on > ""&dir\_tmp_rtf_list.txt"" & exit";

    /*读取 _tmp_rtf_list.txt 文件，构建 filename 语句*/
    data _tmp_rtf_list;
        infile "&dir\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&dir", "\", rtf_name);

        /*识别表格和清单*/
        reg_table_id = prxparse("//o");
    run;
%mend;


%ReadAllRTF(%str(D:\坚果云同步\统计部\项目\MD\2022\03 天智航-骨科手术（THA）导航定位系统\04 统计分析\06 TFL\01 table));
