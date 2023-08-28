/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
## ReadAllRTF

### ������Ϣ

- ���ƣ�ReadAllRTF.sas
- ���ͣ�Macro
- ������[ReadRTF](./ReadRTF.md)
- ���ܣ���ָ���ļ����е����� RTF �ļ�ת��Ϊ SAS ���ݼ���

### ����ִ������
1. ʹ�� DOS �����ȡָ���ļ����е����� RTF �ļ����� RTF �ļ��б�洢�� `_tmp_rtf_list.txt` �У�
2. ��ȡ `_tmp_rtf_list.txt` �ļ�����ȡ RTF �ļ����ƣ�������ִ�� filename ��䣻
3. ���ú� `%ReadRTF()`���� RTF �ļ�ת��Ϊ SAS ���ݼ�
4. ɾ����ʱ���ݼ�
5. ɾ�� `_tmp_rtf_list.txt`

### ����

#### DIR
���� : ��ѡ����

ȡֵ : ָ�� RTF �ļ������ļ������ƣ�������һ���Ϸ��� Windows �ļ���·�������磺`C:\Windows\Temp`

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

options cmplib = work.func;
%macro ReadAllRTF(dir, outlib = work, vd = X, compress = yes, del_rtf_ctrl = yes);

    /*1. ʹ�� DOS �����ȡ���� RTF �ļ����洢�� _tmp_rtf_list.txt ��*/
    X "subst &vd: ""&dir"" & dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";

    /*2. ��ȡ _tmp_rtf_list.txt �ļ������� filename ���*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&vd:\", rtf_name);

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
            call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || '(label = "' || ref_label || '"), compress = ' || "&compress" || ', del_rtf_ctrl = ' || &del_rtf_ctrl || '));');
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

    %put NOTE: �� ReadAllRTF �ѽ������У�;
%mend;

