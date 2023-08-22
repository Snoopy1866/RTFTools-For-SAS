/*
## ReadRTF

### ������Ϣ

- ���ƣ�ReadRTF.sas
- ���ͣ�Macro
  - ����������2
    - ���� 1��FILE����ת���� RTF �ļ�������·����
    - ���� 2��OUTDATA��ת����� SAS ���ݼ����ƣ�
- ������[Cell_Transcode](./Cell_Transcode.md)
- ���ܣ�SAS ODS RTF ʹ�� RTF 1.6 specification ��� RTF �ļ���������ʵ���˽������ RTF �ļ�����תΪ SAS ���ݼ��Ĺ��ܡ�

### ����ִ������
1. ��ȡ RTF �ļ������� RTF �ַ����洢�ڱ��� `line` �У�
2. ������ͷ������ RTF �ı�ͷ���лس�������ܻᵼ�� RTF �����ڻس������У���һ����������е��µı�����ǩ�޷��������������⣬�������� Table �о������֣�
3. ʶ�����е����ݡ������ֵı�����棬���ڱ���ҳ�ĵ�һ�����ݣ���Ӧ�� RTF ��������в�ͬ��ʹ������������ʽ����ʶ��
    - �����⣺`/\\outlinelevel\d/o`
    - ������ݣ�`\\pard\\plain\\intbl\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o`
    - ����ҳ�ĵ�һ�����ݣ�`^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o`
    - ��ͷ��ǩ��`^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o` 
    �������ҳ�ĵ�һ�����ݵ�������ʽ��ͬ��������ͨ���� RTF �ļ��е�λ�ý������֡��ڱ������֮ǰƥ�䵽�ļ�Ϊ��ͷ��ǩ��֮��ƥ�䵽�ļ�Ϊ��ҳ�ĵ�һ�����ݡ���
4. ��ʼת�����ݡ����� [Cell_Transcode](./Cell_Transcode.md) ����������Ԫ���ڵ��ַ���ת��Ϊ�ɶ����ַ�����
5. ʹ�� `PROC TRANSPOSE` ����һ�����������ݼ�����ת�ã�
6. Ϊ���ݼ���ӱ�ǩ
7. ��������� `OUTDATA` ָ�������ݼ���
8. ɾ���м䲽����������ݼ�

### ϸ��
- ���� ODS RTF ������ⲿ RTF �ļ�ʱ����ʧ�˱������ƣ����ת���� SAS ���ݼ�ʱ���������Ƹ��ݱ������ֵ�˳������Ϊ `COL1`, `COL2`, `COL3`, ...
- ���ڵ�Ԫ���ڵĿ����֣��������䵱����ͨ ASCII �ַ�����������н��������磺`\super` �������� SAS ������
- ���ڵ�Ԫ���ڵ�ת���ַ���Ŀǰ֧�ֵı����У�GBK��UTF-8
- RTF �ļ��Ե����ı�����û�����ƣ����� SAS ���ݼ��ı������������ƣ����ܱ�����ʹ���� 32767 ���ȵı������ڴ洢 RTF �����ַ�����ֵ������Ȼ����Ǳ�ڵĽض����⣬������������ SAS �������ƣ��޷��޸�
- ���ڲ��� RTF ���ı�ͷ���ڵ�Ԫ��ϲ������ת����� SAS ���ݼ���ǩ���ܻ��λ������Ӱ�����ݼ��Ĺ۲�

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

    /*2. ������ͷ��������ڱ�ͷ��Ƕ�س����µ� RTF �����������⣩*/
    data _tmp_rtf_data_polish(compress = yes);
        set _tmp_rtf_data;

        length break_line $32767.;

        reg_header_break_id = prxparse("/^(\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{.*){\\line}$/o");
        reg_header_break_continue_id = prxparse("/^(.*){\\line}$/o");
        reg_header_break_end_id = prxparse("/^(.*\\cell})$/o");

        retain break_line "";
        retain break_line_found 0;

        if prxmatch(reg_header_break_id, strip(line)) then do; /*���ֱ�ͷ������������*/
            break_line = catt(break_line, prxposn(reg_header_break_id, 1, strip(line)));
            break_line_found = 1;
            delete;
        end;
        else if prxmatch(reg_header_break_continue_id, strip(line)) then do; /*������������*/
            if break_line_found = 1 then do;
                break_line = catt(break_line, "|", prxposn(reg_header_break_continue_id, 1, strip(line)));
                delete;
            end;
        end;
        else if prxmatch(reg_header_break_end_id, strip(line)) then do; /*���н���*/
            if break_line_found = 1 then do;
                break_line = catt(break_line, "|", prxposn(reg_header_break_end_id, 1, strip(line)));
                line = break_line;

                break_line_found = 0;
                break_line = "";
            end;
        end;
    run;



    /*3. ʶ��������*/
    data _tmp_rtf_raw(compress = yes);
        set _tmp_rtf_data_polish;
        
        /*��������*/
        retain var_n 0;

        /*����λ��*/;
        retain var_pointer 0;

        /*�Ƿ��ֱ�����*/
        retain is_outlinelevel_found 0;

        /*�Ƿ��һ�η���keepn������*/
        retain is_keepn_first_found 0;

        /*�Ƿ��ֱ������*/
        retain is_data_found 0;

        /*
        ��ǰ rtf ����ָ��ı���λ��
        obs_var_pointer ���Ŷ�ȡ�� rtf ����������������󲻳��� var_n��
        ������һ�����ݵ���ʼλ�ñ�����Ϊ 0
        */
        retain obs_var_pointer 0;

        /*�۲����*/
        retain obs_seq 0;


        /*����������ʽɸѡ��ͷ������*/
        reg_outlinelevel_id = prxparse("/\\outlinelevel\d/o");
        reg_header_line_id = prxparse("/^\\pard\\plain\\intbl\\keepn\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o");
        reg_data_line_id = prxparse("/^\\pard\\plain\\intbl\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{5};|[[:ascii:]])*)\\cell\}$/o");

        length header_context_raw $1000
               data_context_raw $32767;

        /*��ʼ��ȡ��Ч����*/
        if prxmatch(reg_outlinelevel_id, strip(line)) then do;
            if is_outlinelevel_found = 0 then do;
                is_outlinelevel_found = 1;
            end;
        end;

        if prxmatch(reg_header_line_id, strip(line)) then do;
            if is_keepn_first_found = 0 and is_outlinelevel_found = 1 then do; /*�״η��� keepn �����֣��������Ǳ�ͷ*/
                var_pointer + 1;
                var_n = max(var_n, var_pointer);
                flag_header = "Y";
                header_context_raw = prxposn(reg_header_line_id, 1, strip(line));
            end;
            else do; /*���״η��� keepn ������*/
                if is_data_found = 0 then do; /*�������� keepn �����֣��������Ǳ�ͷ�ĵڶ����ı�*/
                    var_pointer + 1;
                    var_n = max(var_n, var_pointer);
                    flag_header = "Y";
                    header_context_raw = prxposn(reg_header_line_id, 1, strip(line));
                end;
                else do; /*�ٴη��� keepn �����֣������ⲻ�Ǳ�ͷ�����Ǳ���ҳ��ĵ�һ������*/
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
            if obs_var_pointer = var_n then do; /*ָ��ָ�������һ����������ָ��λ������Ϊ 1*/
                obs_var_pointer = 0;
            end;
        end;

        if prxmatch(reg_data_line_id, strip(line)) then do; /*����������*/
            if is_outlinelevel_found = 1 then do; /*�ų�ҳü����*/
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



    /*4. ��ʼת��*/
    data _tmp_rtf_context;
        set _tmp_rtf_raw;
        if flag_header = "Y" then do;
            header_context = cell_transcode(header_context_raw); /*�����Զ��庯�� cell_transcode*/
        end;

        if flag_data = "Y" then do;
            data_context = cell_transcode(data_context_raw); /*�����Զ��庯�� cell_transcode*/
        end;
    run;



    /*5. ����SAS���ݼ�*/
    proc sort data = _tmp_rtf_context(where = (flag_data = "Y")) out = _tmp_rtf_context_sorted;
        by obs_seq obs_var_pointer;
    run;

    proc transpose data = _tmp_rtf_context_sorted out = _tmp_outdata prefix = COL;
        var data_context;
        id obs_var_pointer;
        by obs_seq;
    run;

    

    /*6. �޸�SAS���ݼ�������*/
    proc sql noprint;
        /*��ȡ��������*/
        select nvar - 2 into : var_n from DICTIONARY.TABLES where libname = "WORK" and memname = "_TMP_OUTDATA";
        
        %do i = 1 %to &var_n;
            /*��ȡ�����ַ�ʵ�ʳ������ֵ*/
            select max(length(col&i)) into : var_&i._maxlen from _tmp_outdata;
            /*��ȡ������ǩ*/
            select header_context into : var_&i._label separated by "|" from _tmp_rtf_context where flag_header = "Y" and var_pointer = &i;
                /*��ǩ��һ������*/
                %if %superq(var_&i._label) = %nrbquote() %then %do;
                    %let var_&i._label = %nrbquote(�ձ�ǩ);
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
                       OBS_SEQ label = "���";
        alter table _tmp_outdata
            drop _NAME_;
    quit;

    

    /*7. �������*/
    data &outdata;
        set _tmp_outdata;
    run;


    
    /*8. ����м����ݼ�*/
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

