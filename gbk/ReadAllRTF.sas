/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
## ReadAllRTF

### ������Ϣ

- ���ƣ�ReadAllRTF.sas
- ���ͣ�Macro
- ������[ReadRTF](./ReadRTF.md)
- ���ܣ���ָ���ļ����е����� RTF �ļ�ת��Ϊ SAS ���ݼ���

### ����ִ������
1. ʹ�� DOS �����ȡָ���ļ����е����� RTF �ļ����� RTF �ļ��б��洢�� `_tmp_rtf_list.txt` �У�
2. ��ȡ `_tmp_rtf_list.txt` �ļ�����ȡ RTF �ļ����ƣ�������ִ�� filename ��䣻
3. ���ú� `%ReadRTF()`���� RTF �ļ�ת��Ϊ SAS ���ݼ�
4. ɾ����ʱ���ݼ�
5. ɾ�� `_tmp_rtf_list.txt`

### ����

#### DIR
���� : ��ѡ����

ȡֵ : ָ�� RTF �ļ�����Ŀ¼·�������á�ָ����Ŀ¼·���������õ�Ŀ¼·��������һ���Ϸ��� Windows ·����
- ָ������·��ʱ�����Դ�������ŵ�·���򲻴����ŵ�·���������벻�����ŵ�·��������ʹ�� `%str()` ��·����Χ
- ��ָ��������·��̫��ʱ��Ӧ��ʹ�� filename ��佨��Ŀ¼���ã�Ȼ����Ŀ¼���ã�����ᵼ�� SAS �޷���ȷ��ȡ��

���� : 
```
DIR = "D:\~\01 table"
```

```
DIR = %str(D:\~\01 table)
```

```
filename ref "D:\~\01 table";
DIR = ref;
```

#### OUTLIB
���� : ��ѡ����

ȡֵ : ָ��������ݼ���ŵ��߼��⣬���߼���������ȶ��壬���߼����Ӧ������·���������

Ĭ��ֵ : WORK

#### VD
���� : ��ѡ����

ȡֵ : ָ����ʱ������������̵��̷������̷���������ĸ A ~ Z ��δ��ʹ�õ�һ���ַ�

Ĭ��ֵ : X

#### COMPRESS
�μ� [COMPRESS](./ReadRTF.md#compress)

#### DEL_RTF_CTRL
�μ� [DEL_RTF_CTRL](./ReadRTF.md#del_rtf_ctrl)
*/

options cmplib = sasuser.func;
%macro ReadAllRTF(dir, outlib = work, vd = X, compress = yes, del_rtf_ctrl = yes);
    /*1. ��ȡĿ¼·��*/
    %let reg_dir_expr = %bquote(/^(?:([A-Za-z_][A-Za-z_0-9]{0,7})|[%str(%"%')]?((?:[A-Za-z]:\\|\\\\[^\\\/:?%str(%")<>|]+)[^\\\/:?%str(%")<>|]+(?:\\[^\\\/:?%str(%")<>|]+)*)[%str(%"%')]?)$/);
    %let reg_dir_id = %sysfunc(prxparse(%superq(reg_dir_expr)));
    %if %sysfunc(prxmatch(&reg_dir_id, %superq(dir))) = 0 %then %do;
        %put ERROR: Ŀ¼���������� 8 �ֽڣ�����Ŀ¼������ַ������ Winodws �淶��;
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

    /*1. ʹ�� DOS �����ȡ���� RTF �ļ����洢�� _tmp_rtf_list.txt ��*/
    X "subst &vd: ""&dirloc"" & dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";

    /*2. ��ȡ _tmp_rtf_list.txt �ļ������� filename ���*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&vd:\", rtf_name);

        /*ʶ�������嵥*/
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
            call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || '(label = "' || ref_label || '"), compress = ' || "&compress" || ', del_rtf_ctrl = ' || "&del_rtf_ctrl" || '));');
        end;
    run;

    /*4. ɾ����ʱ���ݼ�*/
    %if 1 > 2 %then %do;
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
