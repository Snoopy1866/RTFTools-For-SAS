## %mix_cw_font

中西文字体混排。

**Compatibility** : RTF 1.6 specification

> [!Caution]
>
> - 若在已经使用 `%mix_cw_font` 处理后生成的 RTF 文件上再次使用此宏，则会发生堆栈溢出错误。
> - 若某个单元格或段落中的字符数量超出 700（GBK）或 350（UTF8），则会发生堆栈溢出错误。

## 语法

### 必选参数

- [rtf](#rtf)

### 可选参数

- [out](#out)
- [cfont](#cfont)
- [wfont](#wfont)

### 调试参数

- [debug](#debug)

## 参数说明

### rtf

**Syntax** : _path_ | _fileref_

指定需进行处理的 RTF 文件的物理路径或 _filename_ 引用。

**Caution** : 如果路径过长，应当事先使用 `filename` 语句为文件定义引用，再将文件引用名传入参数 `rtf`。

**Example** :

```sas
rtf = "~\表 7.1.1 受试者入组完成情况.rtf"
```

```sas
filename rtfref "~\表 7.1.1 受试者入组完成情况.rtf";
rtf = rtfref
```

---

### out

**Syntax** : _path_ | `#auto`

指定处理后输出的 RTF 文件路径。

**Default** : `#auto`

默认情况下，处理后的 RTF 文件名将遵循以下规则：

- 若源 RTF 文件名以 `.rtf` 结尾，则修改后的 RTF 文件名将使用 _`source_name`_`-mixed.rtf` 作为新的文件名，其中 _`source_name`_ 为源 RTF 文件名，不包含 `.rtf` 后缀。例如：`~\表 7.1.1 受试者入组完成情况-mixed.rtf`。

- 若源 RTF 文件名不以 `.rtf` 结尾，则修改后的 RTF 文件名将使用 _`source_name`_`-mixed.rtf` 作为新的文件名，其中 _`source_name`_ 为源 RTF 文件名（可能包含其他后缀名）。例如：`~\表 7.1.1 受试者入组完成情况.sfx-mixed.rtf`。

**Example** :

```
out = ~\表 7.1.1 受试者入组完成情况-ChangeFont.rtf
```

---

### cfont

**Syntax** : _font_ | `#auto`

指定中文字体。

**Default** : `#auto`

默认情况下，宏程序会查找 RTF 文件的字体表，从字体表已定义的字体中选择第一个匹配程序内部预定义的中文字体作为中文文本显示的字体。

预定义的中文字体如下：

- CSongGB18030C-Light
- CSongGB18030C-LightHWL
- DengXian
- FangSong
- KaiTi
- Lisu
- SimSun
- YouYuan

**Example** :

```
cfont = Noto Sans SC Regular
```

---

### wfont

**Syntax** : _font_ | `#auto`

指定西文字体。

**Default** : `#auto`

默认情况下，宏程序会查找 RTF 文件的字体表，从字体表已定义的字体中选择第一个匹配程序内部预定义的西文字体作为西文文本显示的字体。

预定义的西文字体如下：

- Arial
- Calibri
- Cascadia Code
- Consolas
- HelveticaNeueforSAS
- HelveticaNeueforSAS Light
- Times
- Times New Roman

**Example** :

```
wfont = Monoca
```

---

### debug

**Syntax** : `true` | `false`

指定是否删除宏程序运行产生的中间数据集

**Default** : `false`

> [!NOTE]
>
> - 该参数通常用于调试，用户无需关注。
