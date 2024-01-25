/*
��ϸ�ĵ���ǰ�� Github ����: https://github.com/Snoopy1866/RTFTools-For-SAS
*/

%macro MergeRTF(dir,
                out = #auto,
                depth = 2,
                autoorder = yes,
                vd = X,
                exclude = #null,
                merge = yes)
                /des = "�ϲ�RTF�ļ�" parmbuff;

    /*�򿪰����ĵ�*/
    %if %qupcase(&SYSPBUFF) = %bquote((HELP)) or %qupcase(&SYSPBUFF) = %bquote(()) %then %do;
        X explorer "https://github.com/Snoopy1866/RTFTools-For-SAS/blob/main/docs/MergeRTF.md";
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

    
    /*2. ʹ�� DOS �����ȡ���� RTF �ļ����洢�� _tmp_rtf_list.txt ��*/
    X "subst &vd: ""&dirloc"" & dir ""&vd:\*.rtf"" /b/on/s > ""&vd:\_tmp_rtf_list.txt"" & exit";

    
    /*3. AUTOORDER = NO �ֶ�����*/
    %if %upcase(&autoorder) = NO %then %do;
        X explorer "&vd:\_tmp_rtf_list.txt";
        X mshta vbscript:msgbox("���ڵ����Ĵ����е��� RTF �ļ������˳��Ȼ��ȷ�ϰ�ť�������С���ע�⣺��ǰ�������Ϊ &depth.������ RTF �ļ��ᱻ��������",64,"��ʾ")(window.close);
    %end;

    %let run_start_time = %sysfunc(time()); /*��¼��ʼʱ��*/


    /*4. ��ȡ _tmp_rtf_list.txt��ʶ��ɸѡ rtf �ļ�*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_path $char1000.;

        /*ʶ������嵥*/
        reg_table_id = prxparse("/^.*((?:��)?��|�嵥|ͼ)\s*(\d+(?:\.\d+)*)\.?\s*(.*)\.rtf\s*$/o");

        /*ɸѡ�����淶�� rtf �ļ�*/
        if prxmatch(reg_table_id, rtf_path) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_path);
            rtf_seq = prxposn(reg_table_id, 2, rtf_path);
            ref_label = prxposn(reg_table_id, 3, rtf_path);
 
            rtf_filename_valid_flag = "Y";
        end;

        /*ɸѡָ����ȵ��ļ��е� rtf �ļ�*/
        if count(rtf_path, "\") <= &depth then do;
            rtf_depth_valid_flag = "Y";
        end;
    run;

    /*5. AUTOORDER = YES������ RTF �ļ����ڵ���ţ��Զ�����*/
    %if %upcase(&autoorder) = YES %then %do;
        proc sql noprint;
            select max(count(rtf_seq, ".")) + 1 into : lv_max trimmed from _tmp_rtf_list; /*���� rtf �ļ�������ŵ����㼶����*/
            
            /*��Ӵ���㼶��ŵı���������� n �㣬����� n ��������ÿ����������ǰ rtf �ļ���ĳ���㼶��˳��*/
            alter table _tmp_rtf_list
                    add %do i = 1 %to %eval(&lv_max - 1); 
                            seq_lv_&i num,
                        %end;
                            seq_lv_&lv_max num
                        ;
        quit;

        data _tmp_rtf_list_add_lv;
            set _tmp_rtf_list;
            lv_max_curr_obs = countw(rtf_seq, "."); /*���㵱ǰ rtf �ļ�������ŵĲ㼶����*/

            array seq_lv{&lv_max} seq_lv_1-seq_lv_&lv_max;

            do i = 1 to lv_max_curr_obs;
                seq_lv{i} = input(scan(rtf_seq, i, "."), 8.);
            end;

            drop i lv_max_curr_obs;
        run;

        /*������Ž�������*/
        proc sort data = _tmp_rtf_list_add_lv out = _tmp_rtf_list_add_lv_sorted;
            by %do i = 1 %to &lv_max;
                   seq_lv_&i
               %end;
               ref_label
               ;
        run;
    %end;
    %else %if %upcase(&autoorder) = NO %then %do; /*�Ѿ��ֶ������ˣ�����ԭ��˳��*/
        data _tmp_rtf_list_add_lv_sorted;
            set _tmp_rtf_list;
        run;
    %end;


    /*���г������ϲ� rtf �ļ������ڵ��Ժ�������*/
    %if %upcase(&merge) = NO %then %do;
        data rtf_list;
            set _tmp_rtf_list_add_lv_sorted;
            label rtf_path = "·��"
                  rtf_filename_valid_flag = "�ļ����Ƿ�淶"
                  rtf_depth_valid_flag = "�ļ��Ƿ���ָ�������";
            keep rtf_path rtf_filename_valid_flag rtf_depth_valid_flag;
        run;
        %goto exit_with_no_merge;
    %end;

    /*----------------��ʱ�ر���־���------------------*/
    proc printto log=_null_; 
    run;

    /*6. ���� filename ��䣬�����ļ�����*/
    data _tmp_rtf_list_fnst;
        set _tmp_rtf_list_add_lv_sorted(where = (rtf_filename_valid_flag = "Y" and rtf_depth_valid_flag = "Y")) end = end;

        fileref = 'rtf' || strip(put(_n_, 8.));
        fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

        call execute(fnstm);

        if end then call symput("rtf_ref_max", put(_n_, 8.)); /*��ȡ��Ҫ�ϲ��� rtf �ļ�����������*/
    run;


    /*7. ��ȡ rtf �ļ�*/
    %if &rtf_ref_max = 0 %then %do;
        %put ERROR: �ļ��� &dirloc ��û�з���Ҫ��� rtf �ļ����Ժϲ���;
        %goto exit;
    %end;
    %else %if &rtf_ref_max = 1 %then %do;
        %put ERROR: �ļ��� &dirloc ��ֻ��һ������Ҫ��� rtf �ļ�������ϲ���;
        %goto exit;
    %end;
    %else %do;
        %do i = 1 %to &rtf_ref_max;
            data _tmp_rtf&i(compress = yes);
                informat line $32767.;
                format line $32767.;
                length line $32767.;

                infile rtf&i truncover;
                input line $char32767.;
            run;
        %end;
    %end;

    
    /*8. ��� rtf �ļ��Ƿ� SAS ֮������������޸�*/
    %do i = 1 %to &rtf_ref_max;
        data _null_;
            set _tmp_rtf&i(obs = 1);
            reg_rtf_file_valid_header_id = prxparse("/^{\\rtf1\\ansi\\ansicpg\d+\\uc\d+\\deff\d\\deflang\d+\\deflangfe\d+$/o");
            if prxmatch(reg_rtf_file_valid_header_id, strip(line)) then do;
                call symput("rtf&i._modified_flag", "N"); /*����� rtf&i._modified_flag, ��ʶ rtf �ļ��Ƿ����������޸Ĺ�*/
            end;
            else do;
                call symput("rtf&i._modified_flag", "Y");
            end;
        run;
    %end;



    /*9. ��ȡ�ɺϲ��� rtf �ļ������б�*/
    %let mergeable_rtf_list = %bquote(); 
    %let unmergeable_rtf_index = 0;
    %do i = 1 %to &rtf_ref_max;
        %if &&rtf&i._modified_flag = N %then %do;
            %let mergeable_rtf_list = &mergeable_rtf_list rtf&i;
        %end;
        %else %do;
            %let unmergeable_rtf_index = %eval(&unmergeable_rtf_index + 1);
            proc sql noprint;
                select rtf_path into : rtf_path_&unmergeable_rtf_index trimmed from _tmp_rtf_list_fnst where fileref = "rtf&i";
            quit;
        %end;
    %end;
    %let unmergeable_rtf_sum = &unmergeable_rtf_index;

    /*----------------�ָ���־���------------------*/
    proc printto log=log;
    run;

    %if &mergeable_rtf_list = %bquote() %then %do;
        %put ERROR: �ļ��� &dirloc ��û�п��Ժϲ��� rtf �ļ���;
        %goto exit;
    %end;

    %do i = 1 %to &unmergeable_rtf_sum;
        %put ERROR: �ļ� %superq(rtf_path_&i) �ƺ����޸��ˣ����������ļ���;
    %end;

    /*----------------��ʱ�ر���־���------------------*/
    proc printto log=_null_;
    run;

    /*10. ���� rtf �ļ�*/
    /*����˼·���£�
      ��ͷ�� rtf �ļ���ɾ��ĩβ�� }

      �м�� rtf �ļ�
      - ɾ�� \sectd ֮ǰ��������
      - �� \sectd ǰ����� \sect
      - ɾ��ĩβ�� }
    

      ��β�� rtf �ļ�������ĩβ�� }
    */
    %let mergeable_rtf_ref_max = %sysfunc(countw(&mergeable_rtf_list, %bquote( )));
    %do i = 1 %to &mergeable_rtf_ref_max;
        %let mergeable_rtf_&i._start_time = %sysfunc(time()); /*��¼���� rtf �ļ�����ʼʱ��*/

        %let mergeable_rtf_ref = %scan(&mergeable_rtf_list, &i, %bquote( ));
        data _tmp_&mergeable_rtf_ref(compress = yes);
            set _tmp_&mergeable_rtf_ref end = end;
            
                %if %sysevalf(&i = 1) %then %do;
                    retain fst_sectd_found 1; /*��ͷ�� rtf �ļ�����Ҫ�����Ƿ��Ѿ��ҵ���һ�� \sectd����˸�ֵΪ 1*/
                %end;
                %else %do;
                    retain fst_sectd_found 0; /*������ rtf �ļ���Ҫ�����Ƿ��ҵ���һ�� \sectd������� \sect����˸�ֵΪ 0*/
                %end;

                /*�ֽڷ�����*/
                reg_sectd_id = prxparse("/^\\sectd\\linex\d\\endnhere\\pgwsxn\d+\\pghsxn\d+\\lndscpsxn\\headery\d+\\footery\d+\\marglsxn\d+\\margrsxn\d+\\margtsxn\d+\\margbsxn\d+$/o");
                if fst_sectd_found = 0 then do; /*�״η��� \sectd����\sectd ǰ����� \sect���Ա����� rtf �ļ�֮��ķֽڷ�*/
                    if prxmatch(reg_sectd_id, strip(line)) then do;
                        line = cats("\sect", strip(line)); 
                        fst_sectd_found = 1;
                    end;
                    else do;
                        delete; /*ɾ�������Ԫ��Ϣ���������ɫ��ȣ���Щ��Ϣ�ڿ�ͷ�� rtf ���Ѿ������壬�����ظ����壩*/
                    end;
                end;

                /*��ټ����Ǵ���*/
                length former_outlinelevel_text latter_outlinelevel_text $32.;
                retain former_outlinelevel_text ""; /*���ڱȽϵĴ�ټ����ı�*/
                reg_outlinelevel_id = prxparse("/\\outlinelevel\d{(.*)}/o");
                reg_outlinelevel_change_id = prxparse("s/\\outlinelevel\d//o");
                if prxmatch(reg_outlinelevel_id, strip(line)) then do;
                    latter_outlinelevel_text = hashing('MD5', prxposn(reg_outlinelevel_id, 1, strip(line)));
                    if former_outlinelevel_text = latter_outlinelevel_text then do;
                        line = prxchange(reg_outlinelevel_change_id, 1, strip(line)); /*ɾ���ظ��Ĵ�ټ�����*/
                    end;
                    else do;
                        former_outlinelevel_text = latter_outlinelevel_text; /*�������ڱȽϵĴ�ټ����ı�*/
                    end;
                end;
 
                drop fst_sectd_found reg_sectd_id;

            %if %sysevalf(&i < &mergeable_rtf_ref_max) %then %do; /*ɾ��ĩβ�� }����β�� rtf �ļ����� }��*/
                if end then delete;
            %end;
        run;

        /*��ȡ�ɺϲ��� rtf �ļ���*/
        proc sql noprint;
            select rtf_path into : rtf_path_&i trimmed from _tmp_rtf_list_fnst where fileref = "&mergeable_rtf_ref";
        quit;
        %let mergeable_rtf_&i._end_time = %sysfunc(time()); /*��¼���� rtf �ļ��������ʱ��*/
        %let mergeable_rtf_&i._spend_time = %sysfunc(putn(%sysevalf(&mergeable_rtf_&i._end_time - &mergeable_rtf_&i._start_time), 8.2)); /*���㵥�� rtf �ļ������ʱ*/
    %end;


    /*11. �ϲ� rtf �ļ�*/
    data _tmp_rtf_merged(compress = yes);
        set %do i = 1 %to &mergeable_rtf_ref_max;
                _tmp_%scan(&mergeable_rtf_list, &i, %bquote( ))
            %end;
            ;
    run;

    /*----------------�ָ���־���------------------*/
    proc printto log=log;
    run;

    %do i = 1 %to &mergeable_rtf_ref_max;
        %put NOTE: �ļ� %superq(rtf_path_&i) �ϲ���ɣ���ʱ &&mergeable_rtf_&i._spend_time s��;
    %end;


    /*12. ��� rtf �ļ�*/
    %if %upcase(&out) = #AUTO %then %do;
        %let date = %sysfunc(putn(%sysfunc(today()), yymmdd10.));
        %let time = %sysfunc(time());
        %let hour = %sysfunc(putn(%sysfunc(hour(&time)), z2.));
        %let minu = %sysfunc(putn(%sysfunc(minute(&time)), z2.));
        %let secd = %sysfunc(putn(%sysfunc(second(&time)), z2.));
        %let out = %bquote(merged-&date &hour-&minu-&secd..rtf);
    %end;
    %else %do;
        %let reg_out_id = %sysfunc(prxparse(%bquote(/^[%str(%"%')]?(.+?)[%str(%"%')]?$/o)));
        %if %sysfunc(prxmatch(&reg_out_id, %superq(out))) %then %do;
            %let out = %bquote(%sysfunc(prxposn(&reg_out_id, 1, %superq(out))));
        %end;
        %put &=out;
    %end;
    data _null_;
        set _tmp_rtf_merged;
        file "X:\&out" lrecl = 32767;
        act_length = length(line);
        put line $varying32767. act_length;
    run;

    /*13. ������ʾ��*/
    %let run_end_time = %sysfunc(time()); /*��¼����ʱ��*/
    %let run_spend_time = %sysfunc(putn(%sysevalf(&run_end_time - &run_start_time), 8.2)); /*�����ʱ*/

    %if %sysevalf(&mergeable_rtf_ref_max < &rtf_ref_max) %then %do;
        X mshta vbscript:msgbox("�ϲ��ɹ�����ʱ &run_spend_time s�������ѱ��޸ĵ� rtf �ļ�δ�ϲ�����鿴��־���飡",48,"��ʾ")(window.close);
    %end;
    %else %do;
        X mshta vbscript:msgbox("�ϲ��ɹ�����ʱ &run_spend_time s��",64,"��ʾ")(window.close);
    %end;


    %exit:
    /*----------------��ʱ�ر���־���------------------*/
    proc printto log=_null_;
    run;

    /*ɾ����ʱ���ݼ�*/
    proc datasets library = work nowarn noprint;
        delete %do i = 1 %to &rtf_ref_max;
                   _tmp_rtf&i
               %end;
              ;
    quit;

    %exit_with_no_merge:
    /*----------------��ʱ�ر���־���------------------*/
    proc printto log=_null_;
    run;

    /*ɾ����ʱ���ݼ�*/
    proc datasets library = work nowarn noprint;
        delete _tmp_rtf_list
               _tmp_rtf_list_add_lv
               _tmp_rtf_list_add_lv_sorted
               _tmp_rtf_list_fnst
               _tmp_rtf_merged
              ;
    quit;
    


    /*----------------�ָ���־���------------------*/
    proc printto log=log;
    run;

    /*ɾ�� _tmp_rtf_list.txt*/
    X "del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";

    /*ɾ�� _null_.log �ļ�*/
    X "del _null_.log & exit";

    %put NOTE: �� MergeRTF �ѽ������У�;
%mend;
