options cmplib = work.func;
%macro ReadAllRTF(dir, tag = %str(�б� = L|�� = T|�嵥 = L), dlm = %str(_));

    /*1. ʹ�� DOS �����ȡ���� RTF �ļ����洢�� _tmp_rtf_list.txt ��*/
    X "dir ""&dir\*.rtf"" /b/on > ""&dir\_tmp_rtf_list.txt"" & exit";

    /*2. ��ȡ _tmp_rtf_list.txt �ļ������� filename ���*/
    data _tmp_rtf_list;
        infile "&dir\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&dir", "\", rtf_name);

        /*ʶ������嵥*/
        reg_table_id = prxparse("/^((?:��)?��|�嵥)(\d+(?:\.\d+)*)\s+(.*)\.rtf\s*$/o");

        if prxmatch(reg_table_id, rtf_name) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_name);
            rtf_seq = prxposn(reg_table_id, 2, rtf_name);
            ref_label = prxposn(reg_table_id, 3, rtf_name);
            
            /*����������ݼ�����*/
            if rtf_type = "��" then outdata_prefix = "t";
            else if rtf_type in ("�б�", "�嵥") then outdata_prefix = "l";

            outdata_seq = transtrn(rtf_seq, ".", "_");

            outdata_name = outdata_prefix || "_" || outdata_seq;

            /*���� filename ��䣬�����ļ�����*/
            fileref = 'rtf' || strip(_n_);
            fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

            call execute(fnstm);

            /*��������淶�� rtf �ļ�*/
            rtf_valid_flag = "Y";
        end;
    run;

    /*3. ���� %ReadRTF() ���� RTF �ļ�*/
    data _null_;
        set _tmp_rtf_list;
        if rtf_valid_flag = "Y" then do;
            call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || ', compress = yes' || '));');
        end;
    run;
%mend;

