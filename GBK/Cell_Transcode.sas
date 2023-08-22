/*
## Cell_Transcode

### ������Ϣ

- ���ƣ�Cell_Transcode.sas
- ���ͣ�PROC FCMP function
  - �����洢λ�ã�WORK.FUNC.RTF
  - ��������������1
    - ���� 1 ��STR��һ�� RTF �ĵ�Ԫ���ڵ��ַ������磺`\'CA\'D4\'D1\'E9\'D7\'E9`��`\u35797;\u39564;\u32452;`��
  - ��������ֵ��STR_DECODED��ASCII �ַ����ֲ��䣬�� ASCII �ַ�ת��Ϊ���Ķ����ַ���
  - ���������ĺ�����[Transcode()](./Transcode.md)
- ���ܣ�RTF Specification �涨ֻ��ʹ�� 7 λ ASCII �ַ�����Ҫ��ʾ�� ASCII �ַ�������ʹ��ת��������� GBK �����ʽ���ַ�����ʹ������ `\'CA\'D4` ����ʽ��ʾ������ Unicode �ַ���ʹ�� `\u21015;` ���б�ʾ��������ʵ���˽���Щ�� ASCII �ַ�תΪԭʼ�ַ����Ĺ���

### ����ִ������
1. ʹ��������ʽ�жϲ��� `STR` �ı����ʽ���������£�
  - GBK �����ʽ��`/((?:\\\x27[0-9A-F]{2})+)/o`
  - UTF-8 �����ʽ��`/((?:\\u\d{5};)+)/o`
2. ���ݱ����ʽ���ȶ� RTF �еķ� ASCII �ַ����д������� GBK �����ʽ��ת���ַ���ȥ��ת���ַ� `\'`������ UTF-8 �����ʽ��ת���ַ�����ת���ַ� `\u` �滻Ϊ `&#`
3. ���� PROC FCMP ���� `Transcode()`��������ֵ�洢�ڱ��� `STR_DECODED` ��
4. ���ر��� `STR_DECODED` ��ֵ�����û���
*/

proc fcmp outlib = work.func.rtf inlib = work.func;
    function cell_transcode(str $) $5000;
        reg_code_gbk_id = prxparse("/((?:\\\x27[0-9A-F]{2})+)/o");
        reg_code_utf8_id = prxparse("/((?:\\u\d{5};)+)/o");
        
        length str_decoded $5000;
        str_decoded = str;
        if prxmatch(reg_code_gbk_id, str_decoded) then do;
            do while(prxmatch(reg_code_gbk_id, str_decoded));
                _tmp_str = prxposn(reg_code_gbk_id, 1, str_decoded);
                _tmp_str_nomarkup = compress(_tmp_str, "\'");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "gbk");
                str_decoded = transtrn(str_decoded, strip(_tmp_str), strip(_tmp_str_decoded));
            end;
        end;
        else if prxmatch(reg_code_utf8_id, str_decoded) then do;
            do while(prxmatch(reg_code_utf8_id, str_decoded));
                _tmp_str = prxposn(reg_code_utf8_id, 1, str_decoded);
                _tmp_str_nomarkup = transtrn(_tmp_str, "\u", "&#");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "utf8");
                str_decoded = transtrn(str_decoded, strip(_tmp_str), strip(_tmp_str_decoded));
            end;
        end;
        return(str_decoded);
    endsub;
quit;
