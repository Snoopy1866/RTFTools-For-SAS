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

    /*1. ��ȡ�ļ�·��*/
    %let reg_file_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|((?:[A-Za-z]:\\)[^\\\/:?"<>|]+(?:\\[^\\\/:?"<>|]+)*))$/)));
    %if %sysfunc(prxmatch(&reg_file_id, %superq(file))) = 0 %then %do;
        %put ERROR: �ļ����������� 8 �ֽڣ������ļ������ַ������ Winodws �淶��;
        %goto exit;
    %end;
    %else %do;
        %let fileref = %sysfunc(prxposn(&reg_file_id, 1, %superq(file)));
        %let fileloc = %sysfunc(prxposn(&reg_file_id, 2, %superq(file)));

        /*ָ�������ļ�������*/
        %if %bquote(&fileref) ^= %bquote() %then %do;
            %if %sysfunc(fileref(&fileref)) > 0 %then %do;
                %put ERROR: �ļ������� %upcase(&fileref) δ���壡;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&fileref)) < 0 %then %do;
                %put ERROR: �ļ������� %upcase(&fileref) ָ����ļ������ڣ�;
                %goto exit;
            %end;
            %else %if %sysfunc(fileref(&fileref)) = 0 %then %do;
                %let fileloc = %sysfunc(pathname(&fileref, F));
            %end;
        %end;

        /*ָ����������·��*/
        %if %bquote(&fileloc) ^= %bquote() %then %do;
            %if %sysfunc(fileexist(&fileloc)) = 0 %then %do;
                %put ERROR: �ļ�·�� %bquote(&fileloc) �����ڣ�;
                %goto exit;
            %end;
        %end;
    %end;


    /*2. �Դ��ı���ʽ��ȡRTF�ļ�*/
    data _tmp_rtf_data;
        informat line $32767.;
        format line $32767.;
        length line $32767.;

        infile "&fileloc" truncover;
        input line $char32767.;
    run;


    /*3. ������ͷ��������ڱ�ͷ��Ƕ�س����µ� RTF �����������⣩*/
    data _tmp_rtf_data_polish;
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


    /*4. ʶ��������*/
    data _tmp_rtf_raw;
        set _tmp_rtf_data_polish;
        
        /*��������*/
        retain var_n 0;

        /*����λ��*/;
        retain var_pointer 0;

        /*�Ƿ��ֱ�����*/
        retain is_outlinelevel_found 0;

        /*�Ƿ��ֱ�ͷ*/
        retain is_header_found 0;

        /*�Ƿ��ֱ�ͷ��Ԫ��߿�λ�ö���*/
        retain is_header_def_found 0;

        /*��ͷ��Ԫ�����λ��(�������µ���)*/
        retain header_cell_level 0;

        /*��ͷ��Ԫ�����߿�λ��*/
        retain header_cell_left_padding 0;

        /*��ͷ��Ԫ���Ҳ�߿�λ��*/
        retain header_cell_right_padding 0;

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
        reg_header_line_id = prxparse("/\\trowd\\trkeep\\trhdr\\trq[lcr]/o");
        reg_header_def_line_id = prxparse("/\\clbrdr[tlbr]\\brdrs\\brdrw\d*\\brdrcf\d*(?:\\clbrdr[tlbr]\\brdrs\\brdrw\d*\\brdrcf\d*)*\\cltxlrt[bl]\\clvertal[tcb](?:\\clcbpat\d*)?\\cellx(\d+)/o");
        reg_data_line_id = prxparse("/^\\pard\\plain\\intbl(?:\\keepn)?\\sb\d*\\sa\d*\\q[lcr]\\f\d*\\fs\d*\\cf\d*\{((?:\\'[0-9A-F]{2}|\\u\d{1,5};|[[:ascii:]])*)\\cell\}$/o");
        reg_sect_line_id = prxparse("/\\sect\\sectd\\linex\d*\\endnhere\\pgwsxn\d*\\pghsxn\d*\\lndscpsxn\\headery\d*\\footery\d*\\marglsxn\d*\\margrsxn\d*\\margtsxn\d*\\margbsxn\d*/o");


        length header_context_raw $1000
               data_context_raw $32767;

        /*���ֱ�����*/
        if prxmatch(reg_outlinelevel_id, strip(line)) then do;
            if is_outlinelevel_found = 0 then do;
                is_outlinelevel_found = 1;
            end;
        end;

        /*���ֱ�ͷ*/
        else if prxmatch(reg_header_line_id, strip(line)) then do;
            is_header_found = 1;
            header_cell_level + 1;
        end;

        /*���ֱ�ͷ��Ԫ��߿�λ�õĶ���*/
        else if prxmatch(reg_header_def_line_id, strip(line)) then do;
            is_header_def_found = 1;
            header_cell_left_padding = header_cell_right_padding;
            header_cell_right_padding = input(prxposn(reg_header_def_line_id, 1, strip(line)), 8.);

            var_pointer + 1;
            var_n = max(var_n, var_pointer);
        end;


        /*��������*/
        else if prxmatch(reg_data_line_id, strip(line)) then do;
            if is_outlinelevel_found = 1 then do; /*�޶��ڱ������������У��ų�ҳü�е�����*/
                if is_header_found = 1 then do; /*�����ڿ����� \trhdr ��������У�ʵ���Ͼ��Ǳ�ͷ*/
                    if not prxmatch(reg_header_def_line_id, strip(line)) and is_header_def_found = 1 then do; /*��ͷ�߿�λ�ö����ѽ�������ָ������Ϊ 0*/
                        var_pointer = 0;
                    end;
                    flag_header = "Y";
                    var_pointer + 1;
                    var_n = max(var_n, var_pointer);
                    header_context_raw = prxposn(reg_data_line_id, 1, strip(line));
                end;
                else do; /*������*/
                    flag_data = "Y";
                    is_data_found = 1;
                    obs_var_pointer + 1;
                    if obs_var_pointer = 1 then do;
                        obs_seq + 1;
                    end;
                    data_context_raw = prxposn(reg_data_line_id, 1, strip(line));

                    header_cell_level = 0;
                end;
            end;

            is_header_def_found = 0;
            header_cell_left_padding = 0;
            header_cell_right_padding = 0;
        end;

        /*���ַֽڷ�*/
        else if prxmatch(reg_sect_line_id, strip(line)) then do;
            is_outlinelevel_found = 0;
        end;

        /*�������*/
        else do;
            if header_cell_right_padding > 0 then do;
                is_header_def_found = 0;
                header_cell_left_padding = 0;
                header_cell_right_padding = 0;
            end;

            if var_pointer > 0 then do; /*��ͷ������ʱ��������ָ��λ������Ϊ 0*/
                is_header_found = 0;
                var_pointer = 0;
            end;


            if obs_var_pointer = var_n then do; /*�����ж�����ʱ��������ָ��λ������Ϊ 0*/
                obs_var_pointer = 0;
            end;
        end;
    run;


    /*5. ��ʼת��*/
    data _tmp_rtf_context;
        set _tmp_rtf_raw;
        if flag_header = "Y" then do;
            header_context = cell_transcode(header_context_raw); /*�����Զ��庯�� cell_transcode*/
        end;

        if flag_data = "Y" then do;
            data_context = cell_transcode(data_context_raw); /*�����Զ��庯�� cell_transcode*/
        end;
    run;


    /*6. ����SAS���ݼ�*/
    proc sort data = _tmp_rtf_context(where = (flag_data = "Y")) out = _tmp_rtf_context_sorted;
        by obs_seq obs_var_pointer;
    run;

    proc transpose data = _tmp_rtf_context_sorted out = _tmp_outdata prefix = COL;
        var data_context;
        id obs_var_pointer;
        by obs_seq;
    run;


    /*7. ���������ǩ*/
    proc sql noprint;
        /*��ȡ���в㼶�ı�ǩ*/
        create table _tmp_rtf_header as
            select
                a.header_cell_level,
                a.var_pointer,
                a.header_cell_left_padding,
                a.header_cell_right_padding,
                b.header_context
            from _tmp_rtf_context(where = (is_header_def_found = 1)) as a left join _tmp_rtf_context(where = (flag_header = "Y")) as b
                     on a.header_cell_level = b.header_cell_level and a.var_pointer = b.var_pointer;
        /*��ȡ��ǩ������*/
        select max(header_cell_level) into : max_header_level trimmed from _tmp_rtf_header;

        /*�ϲ����в㼶�ı�ǩ*/
        create table _tmp_rtf_header_expand as
            select
                a&max_header_level..var_pointer,
                catx("|", %unquote(%do i = 1 %to %eval(&max_header_level - 1);
                                       %bquote(a&i..header_context)%bquote(,)
                                   %end;)
                                   a&max_header_level..header_context)
                    as header_context
            from _tmp_rtf_header(where = (header_cell_level = &max_header_level)) as a&max_header_level
                %do i = %eval(&max_header_level - 1) %to 1 %by -1;
                    left join _tmp_rtf_header(where = (header_cell_level = &i)) as a&i
                    on a&max_header_level..header_cell_left_padding >= a&i..header_cell_left_padding and a&max_header_level..header_cell_right_padding <= a&i..header_cell_right_padding
                %end;
                ;
    quit;

    /*��ǩ��һ������*/
    data _tmp_rtf_header_expand_polish;
        set _tmp_rtf_header_expand;
        reg_header_control_word_id = prxparse("s/\\animtext\d*\\ul\d*\\strike\d*\\b\d*\\i\d*\\f\d*\\fs\d*\\cf\d*\s*//o");
        
        header_context = prxchange(reg_header_control_word_id, -1, strip(header_context));

        if substr(header_context, 1, 1) = "|" then do;
            header_context = substr(header_context, 2);
        end;

        if header_context = "" then do;
            header_context = "�ձ�ǩ";
        end;
    run;


    /*8. �޸�SAS���ݼ�������*/
    proc sql noprint;
        /*��ȡ��������*/
        select nvar - 2 into : var_n from DICTIONARY.TABLES where libname = "WORK" and memname = "_TMP_OUTDATA";
        
        %do i = 1 %to &var_n;
            /*��ȡ����ʵ�����賤��*/
            select max(length(col&i)) into : var_&i._maxlen from _tmp_outdata;

            /*��ȡ������ǩ*/
            select header_context into : var_&i._label from _tmp_rtf_header_expand_polish where var_pointer = &i;
        %end;

        alter table _tmp_outdata
            modify %do i = 1 %to &var_n;
                       COL&i char(&&var_&i._maxlen) label = "%sysfunc(strip(%superq(var_&i._label)))",
                   %end;
                       OBS_SEQ label = "���";
        alter table _tmp_outdata
            drop _NAME_;
    quit;
    

    /*9. �������*/
    data &outdata;
        set _tmp_outdata;
    run;


    %exit:
    /*10. ����м����ݼ�*/
    %if 1 > 2 %then %do;
    proc datasets library = work nowarn noprint;
        delete _tmp_outdata
               _tmp_rtf_data
               _tmp_rtf_data_polish
               _tmp_rtf_context
               _tmp_rtf_context_sorted
               _tmp_rtf_raw
              ;
    quit;
    %end;

    %put NOTE: �� ReadRTF �ѽ������У�;
%mend;

