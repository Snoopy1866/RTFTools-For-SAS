/*
 * Macro Name:    Transcode
 * Macro Purpose: һЩ Fcmp �����ķ�װ����������ĵײ�����
 * Author:        wtwang
*/

/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

/*ɾ�����ݼ� SASUSER.FUNC����ֹ�л����뻷�������������޷�������*/
proc datasets library = sasuser noprint nowarn;
    delete func;
quit;


/*���ú꣬���� Fcmp ���� run_macro() ʹ��*/
%macro _macro_transcode;
    %let code_point = %sysfunc(dequote(%superq(code_point)));
    %let raw_encoding = %sysfunc(dequote(&raw_encoding));
    data _null_(encoding = asciiany);
        length char $32767;
        char = kcvt("&code_point"x, "&raw_encoding", getoption('encoding'));
        call symput("char", strip(char));
    run;

    %let is_transcode_success = 1;
%mend;


/*�Զ��庯�������ڽ������*/
proc fcmp outlib = sasuser.func.rtf;
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


/*�Զ��庯�������ڽ��� RTF ��Ԫ���ڵ��ַ���*/
proc fcmp outlib = sasuser.func.rtf inlib = sasuser.func;
    function cell_transcode(str $) $32767;
        reg_code_gbk_id = prxparse("/((?:\\\x27[0-9A-F]{2})+)/o");
        reg_code_utf8_id = prxparse("/((?:\\u\d{1,5};)+)/o");
        
        length str_decoded $32767 _tmp_str $32767 _tmp_str_nomarkup $32767 _tmp_str_decoded $32767;
        str_decoded = str;
        if prxmatch(reg_code_gbk_id, str_decoded) then do;
            do while(prxmatch(reg_code_gbk_id, str_decoded));
                _tmp_str = prxposn(reg_code_gbk_id, 1, str_decoded);
                _tmp_str_nomarkup = compress(_tmp_str, "\'");
                _tmp_str_decoded = transcode(_tmp_str_nomarkup, "gbk");
                reg_code_gbk_chg_id = prxparse("s/((?:\\\x27[0-9A-F]{2})+)/"||trim(_tmp_str_decoded)||"/");
                str_decoded = prxchange(reg_code_gbk_chg_id, 1, strip(str_decoded));
            end;
        end;
        else if prxmatch(reg_code_utf8_id, str_decoded) then do;
            _tmp_str = str_decoded;
            _tmp_str_nomarkup = transtrn(_tmp_str, "\u", "&#");
            _tmp_str_decoded = transcode(_tmp_str_nomarkup, "utf8");
            str_decoded = _tmp_str_decoded;
        end;
        return(str_decoded);
    endsub;
quit;
