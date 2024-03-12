/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro CompareAllRTF(basedir,
                     comparedir,
                     ignorecreatim = yes,
                     ignoreheader = yes,
                     ignorefooter = yes,
                     ignorecellstyle = yes,
                     ignorefonttable = yes,
                     ignorecolortable = yes,
                     outdata = diff,
                     del_temp_data = yes)
                     / parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/CompareAllRTF.md";
        %goto exit;
    %end;

    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));

    /*1. ��ȡĿ¼·��*/
    /*base*/
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(basedir))) = 0 %then %do;
        %put ERROR: Ŀ¼���������� 8 �ֽڣ�����Ŀ¼�����ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
        %let basedirref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(basedir)));
        %let basedirloc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(basedir)));

        /*ָ������Ŀ¼������*/
        %if %bquote(&basedirref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&basedirref)) > 0 %then %do;
                %put ERROR: Ŀ¼���� %upcase(&basedirref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&basedirref)) < 0 %then %do;
                %put ERROR: Ŀ¼���� %upcase(&basedirref) ָ���Ŀ¼�����ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&basedirref)) = 0 %then %do;
                %let basedirloc = %sysfunc(pathname(&basedirref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&basedirloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&basedirloc)) = 0 %then %do;
                %put ERROR: Ŀ¼·�� %bquote(&basedirloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;

    /*compare*/
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(comparedir))) = 0 %then %do;
        %put ERROR: Ŀ¼���������� 8 �ֽڣ�����Ŀ¼�����ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
        %let comparedirref = %sysfunc(prxposn(&reg_dir_id, 1, %superq(comparedir)));
        %let comparedirloc = %sysfunc(prxposn(&reg_dir_id, 2, %superq(comparedir)));

        /*ָ������Ŀ¼������*/
        %if %bquote(&comparedirref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&comparedirref)) > 0 %then %do;
                %put ERROR: Ŀ¼���� %upcase(&comparedirref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&comparedirref)) < 0 %then %do;
                %put ERROR: Ŀ¼���� %upcase(&comparedirref) ָ���Ŀ¼�����ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&comparedirref)) = 0 %then %do;
                %let comparedirloc = %sysfunc(pathname(&comparedirref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&comparedirloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&comparedirloc)) = 0 %then %do;
                %put ERROR: Ŀ¼·�� %bquote(&comparedirloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;


    /*2. ʹ�� DOS �����ȡ���� RTF �ļ����洢�� _tmp_rtf_list_base.txt �� _tmp_rtf_list_compare.txt ��*/
    X "dir ""&basedirloc\*.rtf"" /b/on > ""&basedirloc\_tmp_rtf_list_base.txt"" & exit";
    X "dir ""&comparedirloc\*.rtf"" /b/on > ""&comparedirloc\_tmp_rtf_list_compare.txt"" & exit";


    /*----------------��ʱ�ر���־���------------------*/
    proc printto log=_null_; 
    run;

    /*3. ��ȡ _tmp_rtf_list.txt �ļ������� filename ���*/
    data _tmp_rtf_list_base;
        infile "&basedirloc\_tmp_rtf_list_base.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&basedirloc\", rtf_name);

        /*���� filename ��䣬�����ļ�����*/
        fileref = 'brtf' || strip(_n_);
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);
    run;

    data _tmp_rtf_list_compare;
        infile "&comparedirloc\_tmp_rtf_list_compare.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&comparedirloc\", rtf_name);

        /*���� filename ��䣬�����ļ�����*/
        fileref = 'crtf' || strip(_n_);
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);
    run;


    /*4. �ϲ� _tmp_rtf_list_base �� _tmp_rtf_list_compare*/
    proc sql noprint;
        create table _tmp_rtf_list_bc as
            select
                ifc(not missing(a.rtf_name), a.rtf_name, b.rtf_name)
                                 as rtf_name,
                a.rtf_name       as base_rtf_name,
                a.fileref        as baseref,
                b.rtf_name       as compare_rtf_name,
                b.fileref        as compareref
            from _tmp_rtf_list_base as a full join _tmp_rtf_list_compare as b on a.rtf_name = b.rtf_name;
    quit;

    
    /*5. ���� %CompareRTF() �Ƚ� RTF �ļ�*/
    data _null_;
        set _tmp_rtf_list_bc;
        retain n 0;
        if not missing(base_rtf_name) and not missing(compare_rtf_name) then do;
            n + 1;
            call execute('%nrstr(%CompareRTF(base = ' || baseref ||
                                          ', compare = ' || compareref ||
                                          ', ignorecreatim = ' || "&ignorecreatim" ||
                                          ', ignoreheader = ' || "&ignoreheader" ||
                                          ', ignorefooter = ' || "&ignorefooter" ||
                                          ', ignorecellstyle = ' || "&ignorecellstyle" ||
                                          ', ignorefonttable = ' || "&ignorefonttable" ||
                                          ', ignorecolortable = ' || "&ignorecolortable" ||
                                          ', outdata = _tmp_diff_' || strip(n) || '));');
        end;
        call symputx("diff_n_max", n);
    run;

    /*----------------�ָ���־���------------------*/
    proc printto log=log;
    run;

    
    /*6. �������ȽϽ��*/
    proc sql noprint;
        create table _tmp_diff as
            select * from _tmp_diff_1
            %do i = 2 %to &diff_n_max;
                outer union corr select * from _tmp_diff_&i
            %end;
            ;
    quit;

    proc sql noprint;
        create table _tmp_outdata as
            select
                a.rtf_name,
                a.base_rtf_name,
                a.compare_rtf_name,
                (case when missing(a.base_rtf_name) and not missing(a.compare_rtf_name) then "Y" else "" end) as addyn length = 4, /*base -> compare ����*/
                (case when not missing(a.base_rtf_name) and missing(a.compare_rtf_name) then "Y" else "" end) as delyn length = 4, /*base -> compare ɾ��*/
                (case when not missing(a.base_rtf_name) and not missing(a.compare_rtf_name) then
                    (select diffyn from _tmp_diff as b where a.base_rtf_name = b.base_name and a.compare_rtf_name = b.compare_name)
                      else ""
                end) as diffyn length = 4 /*base -> compare ����*/
            from _tmp_rtf_list_bc as a;
    quit;

    proc sort data = _tmp_outdata sortseq = linguistic(numeric_collation = on) out = _tmp_outdata(drop = rtf_name);
        by rtf_name;
    run;


    /*7. �������*/
    data &outdata;
        set _tmp_outdata;
        label base_rtf_name    = "base �ļ�"
              compare_rtf_name = "compare �ļ�"
              addyn            = "compare ������"
              delyn            = "base ��ɾ��"
              diffyn           = "���ڲ���";
    run;


    %exit:
    /*8. ����м����ݼ�*/
    %if %upcase(&del_temp_data) = YES %then %do;
        proc datasets library = work nowarn noprint;
            delete _tmp_rtf_list_base
                   _tmp_rtf_list_compare
                   _tmp_rtf_list_bc
                   _tmp_diff
                   _tmp_outdata
                   %if %symexist(diff_n_max) %then %do;
                       %do i = 1 %to &diff_n_max;
                           _tmp_diff_&i
                       %end;
                   %end;
                  ;
        quit;
    %end;

    %if %symexist(basedirloc) and %symexist(comparedirloc) %then %do;
        /*ɾ�� _tmp_rtf_list_base.txt �� _tmp_rtf_list_compare.txt*/
        X "del ""&basedirloc\_tmp_rtf_list_base.txt"" & exit";
        X "del ""&comparedirloc\_tmp_rtf_list_compare.txt"" & exit";
    %end;

    /*ɾ�� _null_.log �ļ�*/
    X "del _null_.log & exit";

    %put NOTE: �� CompareAllRTF �ѽ������У�;
%mend;
