/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

options cmplib = sasuser.func;

%macro ReadAllRTF(dir, outlib = work, vd = X, compress = yes, del_rtf_ctrl = yes, del_temp_data = yes)/ parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/ReadAllRTF.md";
        %goto exit;
    %end;


    /*1. ��ȡĿ¼·��*/
    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(dir))) = 0 %then %do;
        %put ERROR: Ŀ¼���������� 8 �ֽڣ�����Ŀ¼�����ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
        %let dirref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(dir)));
        %let dirloc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(dir)));

        /*ָ������Ŀ¼������*/
        %if %bquote(&dirref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&dirref)) > 0 %then %do;
                %put ERROR: Ŀ¼���� %upcase(&dirref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&dirref)) < 0 %then %do;
                %put ERROR: Ŀ¼���� %upcase(&dirref) ָ���Ŀ¼�����ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&dirref)) = 0 %then %do;
                %let dirloc = %sysfunc(pathname(&dirref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&dirloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&dirloc)) = 0 %then %do;
                %put ERROR: Ŀ¼·�� %bquote(&dirloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;


    X "subst &vd: ""&dirloc"" & exit"; /*�����������*/

    /*1. ʹ�� DOS �����ȡ���� RTF �ļ����洢�� _tmp_rtf_list.txt ��*/
    X "dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";


    /*2. ��ȡ _tmp_rtf_list.txt �ļ������� filename ���*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767. fnstm $char32767.;
        rtf_path = cats("&vd:\", rtf_name);

        /*ʶ������嵥*/
        reg_table_id = prxparse("/^((?:��)?��|�嵥)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf\s*$/o");

        if prxmatch(reg_table_id, rtf_name) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_name);
            rtf_seq = prxposn(reg_table_id, 2, rtf_name);
            ref_label = prxposn(reg_table_id, 3, rtf_name);
            
            /*����������ݼ�����*/
            if rtf_type = "��" then outdata_prefix = "t";
            else if rtf_type in ("�б�", "�嵥") then outdata_prefix = "l";

            outdata_seq = transtrn(rtf_seq, ".", "_");

            outdata_name = "&outlib.." || outdata_prefix || "_" || outdata_seq;

            /*���� filename ��䣬�����ļ�����*/
            fileref = 'rtf' || put(_n_, 8. -L);
            fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

            call execute(fnstm);

            /*��������淶�� rtf �ļ�*/
            rtf_valid_flag = "Y";
        end;
    run;


    /*3. ���� %ReadRTF() ���� RTF �ļ�*/
    data _null_;
        set _tmp_rtf_list;
        retain call_macro_n 0;

        if rtf_valid_flag = "Y" then do;
            call_macro_n + 1;
            call_macro_expr = '%ReadRTF(file = ' || strip(fileref) || ', outdata = ' || strip(outdata_name) || '(label = "' || strip(ref_label) || '"), compress = ' || "&compress" || ', del_rtf_ctrl = ' || "&del_rtf_ctrl" || ');';

            call symputx(cats("call_macro_expr_", call_macro_n), call_macro_expr);
        end;
        call symputx("call_macro_n", call_macro_n);
    run;

    /*----------------��ʱ�ر���־���------------------*/
    proc printto log=_null_;
    run;

    %do i = 1 %to &call_macro_n;
        %unquote(%superq(call_macro_expr_&i));

        /*��׽����ȡ������Ҫ��ʱ�����־*/
        %if %bquote(&readrtf_exit_with_error) = TRUE %then %do;
            /*----------------��ʱ�ָ���־���------------------*/
            proc printto log=log;
            run;

            %put ERROR: %superq(readrtf_exit_with_error_text);

            /*----------------�ر���־���------------------*/
            proc printto log=_null_;
            run;
        %end;
    %end;

    /*----------------�ָ���־���------------------*/
    proc printto log=log;
    run;


    /*4. ɾ����ʱ���ݼ�*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_list
                  ;
        quit;
    %end;


    /*5. ɾ�� _tmp_rtf_list.txt*/
    X " del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";


    %exit:
    %put NOTE: �� ReadAllRTF �ѽ������У�;
%mend;
