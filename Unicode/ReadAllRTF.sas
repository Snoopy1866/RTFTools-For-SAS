/*
详细文档请前往 Github 查阅: https://github.com/Snoopy1866/RTFTools-For-SAS
## ReadAllRTF

### 程序信息

- 名称：ReadAllRTF.sas
- 类型：Macro
- 依赖：[ReadRTF](./ReadRTF.md)
- 功能：将指定文件夹中的所有 RTF 文件转换为 SAS 数据集。

### 程序执行流程
1. 使用 DOS 命令获取指定文件夹中的所有 RTF 文件，将 RTF 文件列表存储在 `_tmp_rtf_list.txt` 中；
2. 读取 `_tmp_rtf_list.txt` 文件，获取 RTF 文件名称，构建并执行 filename 语句；
3. 调用宏 `%ReadRTF()`，将 RTF 文件转换为 SAS 数据集
4. 删除临时数据集
5. 删除 `_tmp_rtf_list.txt`

### 参数

#### DIR
类型 : 必选参数

取值 : 指定 RTF 文件所在文件夹名称，必须是一个合法的 Windows 文件夹路径，例如：`C:\Windows\Temp`

#### OUTLIB
类型 : 可选参数

取值 : 指定输出数据集存放的逻辑库，该逻辑库必须事先定义，且逻辑库对应的物理路径必须存在

默认值 : WORK

#### VD
类型 : 可选参数

取值 : 指定临时创建的虚拟磁盘的盘符，该盘符必须是字母 A ~ Z 中未被使用的一个字符

默认值 : X

#### COMPRESS
参见 [COMPRESS](./ReadRTF.md#compress)

#### DEL_RTF_CTRL
参见 [DEL_RTF_CTRL](./ReadRTF.md#del_rtf_ctrl)
*/

options cmplib = sasuser.func;
%macro ReadAllRTF(dir, outlib = work, vd = X, compress = yes, del_rtf_ctrl = yes);

    /*1. 使用 DOS 命令获取所有 RTF 文件，存储在 _tmp_rtf_list.txt 中*/
    X "subst &vd: ""&dir"" & dir ""&vd:\*.rtf"" /b/on > ""&vd:\_tmp_rtf_list.txt"" & exit";

    /*2. 读取 _tmp_rtf_list.txt 文件，构建 filename 语句*/
    data _tmp_rtf_list;
        infile "&vd:\_tmp_rtf_list.txt" truncover encoding = 'gbke';
        input rtf_name $char1000. rtf_path $char32767.;
        rtf_path = cats("&vd:\", rtf_name);

        /*识别表格和清单*/
        reg_table_id = prxparse("/^((?:列)?表|清单)(\d+(?:\.\d+)*)\s+(.*)\.rtf\s*$/o");

        if prxmatch(reg_table_id, rtf_name) then do;
            rtf_type = prxposn(reg_table_id, 1, rtf_name);
            rtf_seq = prxposn(reg_table_id, 2, rtf_name);
            ref_label = prxposn(reg_table_id, 3, rtf_name);
            
            /*构造输出数据集名称*/
            if rtf_type = "表" then outdata_prefix = "t";
            else if rtf_type in ("列表", "清单") then outdata_prefix = "l";

            outdata_seq = transtrn(rtf_seq, ".", "_");

            outdata_name = "&outlib.." || outdata_prefix || "_" || outdata_seq;

            /*构造 filename 语句，建立文件引用*/
            fileref = 'rtf' || strip(_n_);
            fnstm = 'filename ' || strip(fileref) || ' "' || strip(rtf_path) || '";';

            call execute(fnstm);

            /*标记命名规范的 rtf 文件*/
            rtf_valid_flag = "Y";
        end;
    run;

    /*3. 调用 %ReadRTF() 解析 RTF 文件*/
    data _null_;
        set _tmp_rtf_list;

        if rtf_valid_flag = "Y" then do;
            call execute('%nrstr(%ReadRTF(file = ' || fileref || ', outdata = ' || outdata_name || '(label = "' || ref_label || '"), compress = ' || "&compress" || ', del_rtf_ctrl = ' || &del_rtf_ctrl || '));');
        end;
    run;

    /*4. 删除临时数据集*/
    %if 1 > 2 %then %do;
    proc datasets library = work nowarn noprint;
        delete _tmp_rtf_list
              ;
    quit;
    %end;

    /*5. 删除 _tmp_rtf_list.txt*/
    X " del ""&vd:\_tmp_rtf_list.txt"" & subst &vd: /D & exit";

    %put NOTE: 宏 ReadAllRTF 已结束运行！;
%mend;

