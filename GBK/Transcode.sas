/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
## Transcode

### ������Ϣ

- ���ƣ�Transcode.sas
- ���ͣ�PROC FCMP function
- ������[%_MACRO_TRANSCODE](#_macro_transcode)
- ���ܣ���ͬ�����ʽ���ַ������ܻ������ݣ����磺GBK ��ʽ������ַ����� Unicode �����»���ʾ���룬������ʵ���˽���ͬ�����ʽ�����ת��Ϊ��ǰ SAS �����µ��ַ����Ĺ��ܡ����磺���ַ��� `CAD4D1E9D7E9` תΪ `������`�����ַ��� `&#35797;&#39564;&#32452;` תΪ `������`��
- �洢λ�ã�SASUSER.FUNC.RTF

### ����ִ������
1. �жϲ��� RAW_ENCODING ��ֵ����Ϊ UTF8������� SAS �Դ����� `UNICODE()` ����ת������Ϊ����ֵ������� `RUN_MACRO` ������
2. ��ȡ UNICODE() ������ RUN_MACRO() �����ķ���ֵ�������������û���

### ����ֵ
#### CHAR
���� : �ַ�

ȡֵ : ת�����ַ���

### ����

#### CODE_POINT
���� : �ַ�

ȡֵ : һ����㣬���磺`CAD4`��`&#21015`

#### RAW_ENCODING
���� : �ַ�

ȡֵ : ���ʹ�õı����ʽ�����磺`GBK`��`UTF8`

#### %_MACRO_TRANSCODE
���� Transcode.sas �а��������ú���� `%_MACRO_TRANSCODE`�����ڸ���ʵ��ת�룬���� PROC FCMP function �б����� `RUN_MACRO()` ���ã�������һ��״̬�룬���� `IS_TRANSCODE_SUCCESS` �洢�����״̬�롣

- IS_TRANSCODE_SUCCESS = 1��ת��ɹ�
- IS_TRANSCODE_SUCCESS = 0��ת��ʧ��
*/

%macro _macro_transcode;
    %let code_point = %sysfunc(dequote(&code_point));
    %let raw_encoding = %sysfunc(dequote(&raw_encoding));
    data _null_(encoding = asciiany);
        length char $32767;
        char = kcvt("&code_point"x, "&raw_encoding", getoption('encoding'));
        call symput("char", strip(char));
    run;

    %let is_transcode_success = 1;
%mend;



proc fcmp outlib = .func.rtf;
    function transcode(code_point $, raw_encoding $) $ 32767;
        length char $32767;

        is_transcode_success = 0;
        char = "";
        if raw_encoding = "utf8" then do; /*UTF-8 ����ֱ�ӵ������ú���*/
            char = unicode(code_point, "NCR");
            return(char);
        end;
        else do;
            rc = run_macro('_macro_transcode', code_point, raw_encoding, char, is_transcode_success); /*����������� KVCT ���������� KVCT �����������ԣ���Ҫ�����ض������ DATA ����ʹ��*/
            if rc = 0 and is_transcode_success = 1 then do;
                return(char);
            end;
            else do;
                return("ERROR: ת��ʧ�ܣ�");
            end;
        end;
    endsub;
quit;
