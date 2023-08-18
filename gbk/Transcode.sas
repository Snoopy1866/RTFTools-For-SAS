/*
���ƣ�transcode
���ܣ���������������תΪ��ǰ�����µı����Ӧ���ַ�
�����ת��״̬��0 - �ɹ���1 - ʧ��
��ϸ˵����
1. ����� _macro_transcode ������ת��ĳ��򣬲�ʹ�ú���� is_transcode_success ������ת��״̬��0 ����ɹ���1 ����ʧ��
2. ʹ�� PROC FCMP �������Զ��庯�� transcode��ʹ�� run_macro ���ú���� _macro_transcode������ֵΪת�����ַ�
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



proc fcmp outlib = work.func.rtf;
    function transcode(code_point $, raw_encoding $) $ 32767;
        length char $32767;

        is_transcode_success = 0;
        char = "";
        rc = run_macro('_macro_transcode', code_point, raw_encoding, char, is_transcode_success);
        if rc = 0 and is_transcode_success = 1 then do;
            return(char);
        end;
        else do;
            return("ERROR: ת��ʧ�ܣ�");
        end;
    endsub;
quit;
