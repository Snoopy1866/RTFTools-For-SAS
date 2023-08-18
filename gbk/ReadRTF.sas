/*
���ƣ�ReadRTF.sas
���ܣ���ȡRTF�ļ�
�����SAS ���ݼ�
ϸ�ڣ�
1. ��ȡ�ĵ���RTF�����Ϊ32767�ַ�����ĳЩ��������¿��ܵ���������ݼ���ĳЩ������ֵ���ݱ��ض�
*/


options cmplib = work.func;

%macro ReadRTF(file, outdata);
    /*1. �Դ��ı���ʽ��ȡRTF�ļ�*/
    data _tmp_rtf_data(compress = yes);
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&file" truncover;
        input line $char32767.;
    run;



    /*2. ʶ��������*/
    data _tmp_rtf_raw(compress = yes);
        set _tmp_rtf_data;
        
        /*��������*/
        retain var_n 0;

        /*�Ƿ��һ�η���keepn������*/
        retain is_keepn_first_found 0;


        /*
        ��ǰ rtf ����ָ��ı���λ��
        obs_var_pointer ���Ŷ�ȡ�� rtf ���������������� var_n �����ֵ��
        ������һ�����ݵ���ʼλ�ñ�����Ϊ 0
        */
        retain obs_var_pointer 0;

        /*�۲����*/
        retain obs_seq 0;


        /*����������ʽɸѡ��ͷ������*/
        reg_header_line_id = prxparse("/^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\qc\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|[[:ascii:]])*)\\cell\}$/o");
        reg_data_line_id = prxparse("/^\\pard\\plain\\intbl\\sb\d*\\sa\d*\\qc\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|[[:ascii:]])*)\\cell\}$/o");

        length header_context_raw $1000
               data_context_raw $32767;
        /*��ʼ��ȡ��Ч����*/
        if prxmatch(reg_header_line_id, strip(line)) then do;
            if is_keepn_first_found = 0 then do; /*�״η���keepn�����֣��������Ǳ�ͷ*/
                var_n + 1;
                flag_header = "Y";
                header_context_raw = prxposn(reg_header_line_id, 1, strip(line));
            end;
            else do; /*���״η���keepn�����֣������ⲻ�Ǳ�ͷ�����Ǳ���ҳ��ĵ�һ������*/
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
            if obs_var_pointer = var_n then do; /*ָ��ָ�������һ����������ָ��λ������Ϊ 1*/
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



    /*3. ��ʼת��*/
    data _tmp_rtf_context;
        set _tmp_rtf_raw;
        if flag_header = "Y" then do;
            header_context = cell_transcode(header_context_raw); /*�����Զ��庯�� cell_transcode*/
        end;

        if flag_data = "Y" then do;
            data_context = cell_transcode(data_context_raw); /*�����Զ��庯�� cell_transcode*/
        end;
    run;



    /*4. ����SAS���ݼ�*/
    proc sort data = _tmp_rtf_context(where = (flag_data = "Y")) out = _tmp_rtf_context_sorted;
        by obs_seq obs_var_pointer;
    run;

    proc transpose data = _tmp_rtf_context_sorted out = _tmp_outdata prefix = COL;
        var data_context;
        id obs_var_pointer;
        by obs_seq;
    run;

    

    /*5. �޸�SAS���ݼ�������*/
    proc sql noprint;
        /*��ȡ��������*/
        select nvar - 2 into : var_n from DICTIONARY.TABLES where libname = "WORK" and memname = "_TMP_OUTDATA";
        
        %do i = 1 %to &var_n;
            /*��ȡ�����ַ�ʵ�ʳ������ֵ*/
            select max(length(col&i)) into : var_&i._maxlen from _tmp_outdata;
            /*��ȡ������ǩ*/
            select header_context into : var_&i._label from _tmp_rtf_context where flag_header = "Y" and var_n = &i;
        %end;

        alter table _tmp_outdata
            modify %do i = 1 %to &var_n;
                       COL&i char(&&var_&i._maxlen) label = "%sysfunc(strip(&&var_&i._label))",
                   %end;
                       OBS_SEQ label = "���";
        alter table _tmp_outdata
            drop _NAME_;
    quit;

    

    /*6. �������*/
    data &outdata;
        set _tmp_outdata;
    run;


    
    /*7. ����м����ݼ�*/
/*    proc datasets library = work nowarn noprint;*/
/*        delete _tmp_outdata*/
/*               _tmp_rtf_data*/
/*               _tmp_rtf_context*/
/*               _tmp_rtf_context_sorted*/
/*               _tmp_rtf_raw*/
/*              ;*/
/*    quit;*/
%mend;

