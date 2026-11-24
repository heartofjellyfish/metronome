# 下一版乐器库 · 地区入口审计与中阮配置

核对基线 `a3699e6615c82aeb30bf0f6588b133556c8e1e11`。首发由[发布范围](release-scope.md)独立验收。这里的名称、入口和中阮配置供下一版评审。实际界面按[调音页标准](page-standards.md)验收。

## 当前地区乐器

当前选择器按乐器家族分行。下表的 ID 和定弦来自代码，别名和后续路径是提案。文化入口与常用家族入口指向同一 ID，原选择器、已存定弦及用户自定义配置继续可恢复。 [目录](../../TheMetronome/TunerCatalog.swift) · [选择器](../../TheMetronome/TunerLibrary.swift) · [预设](../../TheMetronome/TunerPresets.swift)

| 地区 | 现有 ID 与拟加检索词 | 当前调弦入口与下一版验收 |
| --- | --- | --- |
| 中国民乐 | `Erhu` · 二胡 · èrhú | Chinese instruments。D₄–A₄，另有半音升降和全音降。核对内外弦与各自琴轴，分别试空弦弓奏和拨奏。 |
| 中国民乐 | `Pipa` · 琵琶 · pípá | Chinese instruments。A₂–D₃–E₃–A₃ 为默认，另有三种整体移调。保留 4–1 弦序，最下轴按正面遮挡。现有移调预设目前只按整体音高标注。 [教学定弦](https://www.easonmusicschool.com/how-to-tune-zhongruan-liuqin-and-pipa/) |
| 中国民乐 | `Guzheng` · 古筝 · 古箏 · gǔzhēng | Chinese instruments。21 弦、D 大调五声音阶，另有 G／C／A／F。沿用远侧 21 弦到近侧 1 弦和 Far／Middle／Near／All。验收切换时定位、完成勾与对应弦轴一致。 [实物调音教学](https://yunyangmusic.com/pages/how-to-set-up-tune-your-guzheng) |
| 中国民乐 | `Guqin` · 古琴 · gǔqín | Chinese instruments。七弦，正调默认 C₂–D₂–F₂–G₂–A₂–C₃–D₃，另有蕤宾调、慢角调。进入时显示实际目标音，比对每个调式的实琴定弦。 |
| 中国民乐 | `Yangqin` · 扬琴 · 揚琴 · yángqín | Chinese instruments。410 型专页有 47 个物理弦组，其中 44 个有参考音、3 个由用户指定。普通预设数组为空，弦组与逐弦定位来自专用路径。需在另一把 410 上复核，402 型待独立映射。 [弦组实现](../../TheMetronome/TunerYangqin.swift) · [410 型实测论文](https://bioresources.cnr.ncsu.edu/wp-content/uploads/2025/12/BioRes_21_1_1084_Sinin_HJSM_Yangqin_Acoustic_Study_Chinese_Dulcimer_24951-1.pdf) |
| 中国民乐 | `Dizi` · 笛子 · 竹笛。另有 `Xiao`（箫／簫）、`Suona`（唢呐／嗩吶）、`Sheng`（笙） | World instruments。笛子复用合奏校音／长音。带接头的竹笛可粗调整体音高，再用吹奏校准。箫、唢呐走合奏校音，笙走音高检查。文化入口继续能找到。 [笛子教学](https://www.easonmusicschool.com/dizi-tuning/) |
| 日本传统 | `Koto` · 箏 · こと · koto | Japanese instruments。13 弦，平調子默认第 1 与第 5 弦都为 D₄，独立点选和完成。另有低首弦、C 调、E 调和雲井調子。俯视图从远至近为 1–13，龙头向右，琴柱随预设示意移动，实物位置取决于张力。 [Suzuki 箏说明书](https://www.suzuki-music.co.jp/app/uploads/WK-1_2_3_manual.pdf) · [福田恭子的调弦教学](https://yasuko-fukuda.com/learning/koto-tuning/) |
| 日本传统 | `Shamisen` · 三味線 · しゃみせん · samisen | Japanese instruments。本調子 C₃–F₃–C₄，另有二上り、三下り和对应的 D 调。参考津轻三味线实物正面，三根弦从粗到细接上、中、下轴，旋钮右、左、右。尺八 `Shakuhachi` 复用校音，沖縄三線为候选。 [实物琴头](https://itonejapan.com/cdn/shop/files/0018.jpg?v=1720849209&width=1445) · [日本艺术文化振兴会](https://www2.ntj.jac.go.jp/dglib/contents/learn/edc6/edc_new/html/231_hosozao_sp.html) |
| 南亚 | `Sitar` · सितार · 西塔琴 · 锡塔琴 · sitār | World instruments。Sa=C♯ 为 20 弦配置，C、D 为整体移调，另有 18 弦、11 根 taraf。保留主奏弦和共鸣弦的物理编号。每套预设标明相应实琴传统，实际验证走分组和总览两条路。 [南亚馆藏综述](https://www.metmuseum.org/en/essays/musical-instruments-of-the-indian-subcontinent) |
| 中东 | `Oud · Arabic` · Arabic oud · عود عربي · 乌德琴 · 烏德琴 | Middle East。六组十一弦，C₂–F₂–A₂–D₃–G₃–C₄，另有 High F、Low D。拨一根、转对应轴，成对弦逐根确认。 [Sala Muzik 调弦指南](https://salamuzik.com/blogs/news/how-to-tune-oud-instrument-easily) · [实物琴头](https://musicaldose88.com/oudtech-rzn205/p800475619) |
| 中东 | `Oud · Turkish` · ud | Middle East。支持十一弦版，Bolahenk 为 C♯₂–F♯₂–B₂–E₃–A₃–D₄，另有低音 D–A 的配置。独立于阿拉伯乌德琴保存音高和预设。 [D’Addario EJ95 弦表](https://www.daddario.com/en-gb/products/ej95-oud-11-string-set) · [Sala Muzik 调弦指南](https://salamuzik.com/blogs/news/how-to-tune-oud-instrument-easily) |
| 中东 | `Bağlama` · 短颈 saz | Middle East。短颈七弦分 2＋2＋3 三组。A 档依次是 A₂/A₃、G₃/G₃、D₃/D₄/D₄。B 档整套升全音。拨弦时隔开同组邻弦，按单根和对应轴验收。 [短颈实物](https://salamuzik.com/products/professional-short-neck-baglama-mss-207) · [Tapadum 调弦示范](https://www.youtube.com/watch?v=0Xj-mfq8uF0) |
| 中东 | `Setar` · سه‌تار · 波斯塞塔尔琴 | Middle East。按图由粗至细为第 4、3、2、1 弦。C–G 配列是 C₃、C₄、G₃、C₄，两根 C₄ 分开确认。另提供第二弦 F 和 D 八度共鸣弦的调法。演奏前拨一根、逐轴调准。预设使用实音，曲式相关的微分音由后续独立验证。 [Kiya Tabassian 的 Setār 指南](https://www.atlasensemble.nl/assets/files/instruments/Setar/Setar%20by%20Kiya%20Tabassian.pdf) · [Mohammadi 琴头参考](https://musicbalcony.com/products/persian-setar-made-by-mohammadi-2) |

发现层验收用例：

- `中阮`、`zhōngruǎn`、`zhong ruan` 命中同一候选；`ruan` 允许返回阮族结果，不直接打开一个成员。 `大阮`、`柳琴` 保持各自身份。
- `古筝`、`古箏`、`guzheng` 同一结果；由家族入口切换定弦后，从文化入口打开仍恢复同一 preset。关记忆后验证首次进入的默认行为。
- `三味線` 和 `三線` 分别命中；`琴` 在中文全库不自动跳转日本箏。 `عود عربي` 从 RTL 搜索进入后，实音次序和主读数仍一致。
- `dizi`、`竹笛` 打开共享长音校音并保留笛子语境；无结果能退回 Chromatic 或自定义调弦。

## 样板 · 四弦中阮

**场景**　乐团排练前按 4、3、2、1 弦逐一拨空弦，确认发声和琴头上的目标相符，每次转同一根弦对应的弦钮，再拨一次复核。四根弦各用一条完成链路。教学资料明确列出琴弦号和国际音名，香港中乐团也将中阮列为独立声部，课程大纲涵盖调音。选它作为第一项扩展，是因为演奏动作清楚、专用页面有定位价值，四弦结构可复用。 [中阮调音教学与示范](https://www.easonmusicschool.com/how-to-tune-zhongruan-liuqin-and-pipa/) · [香港中乐团编制与音域](https://lebf.hkco.org/uploads/docs/682542ced6d771.pdf) · [香港音乐事务处中阮课程](https://www.lcsd.gov.hk/en/mo/common/doc/faq/faq_01_syb_0204.pdf)

| 物理弦号 | 4 · 最粗 | 3 | 2 | 1 · 最细 |
| --- | ---: | ---: | ---: | ---: |
| 默认空弦 | G₂ | D₃ | G₃ | D₄ |
| 实音 MIDI | 43 | 50 | 55 | 62 |
| A4=440 Hz | 98.00 | 146.83 | 196.00 | 293.66 |
| 京剧候选空弦 | A₂ | D₃ | A₃ | D₄ |
| 京剧候选 MIDI | 45 | 50 | 57 | 62 |

- 候选乐器的稳定 ID 用 `Zhongruan`，默认沿用 base ID。京剧档待乐手确认后再启用，采用现有规则 `Zhongruan · Jingju`，显示名可本地化。排练默认按实音；香港中乐团资料注明中阮有高八度记谱的谱例，转换仅用于后续明确的读谱场景，绝不将弦的检测或参考音提高八度。京剧档基于田森对伴奏定弦的记录，琴弦规格和调高前的检查由乐手或教师验证。 [编配手册的 4→1 弦序](https://intermusic.lmta.lt/pluginfile.php/1547/mod_resource/content/2/QI-An_Instrumental_Guide_To_The_Chinese_Orchestra.pdf) · [京剧定弦](https://www.huain.com/article/zhongruan/2025/0102/2985.html) · [香港中乐团谱音说明](https://lebf.hkco.org/uploads/docs/682542ced6d771.pdf)
- 实物底稿选敦煌 662 如意头，先用厂家目录比对头部、侧钮和琴颈比例，再用中阮实琴正面照及可看清箱内的近照核对箱内遮挡与弦去向。当前有厂家型号与教学参考，四根弦到具体轴座的可见路径尚待逐根确认。画法沿用琵琶和提琴的正面琴头、单色轮廓及分部件路径。取琴头、弦枕和一小段琴颈，保留如意外轮廓，简化装饰。每根弦号与音名靠近自己的轴，镜头左右以实物正视图记录。 [敦煌厂家目录](https://cdnc.heyzine.com/files/uploaded/v2/46e635e2f2a748e9df5ebf888f5237aac44424e8.pdf) · [中阮结构演示](https://www.youtube.com/watch?v=O121kwdWLz4)

### 可复现验收

| 操作 | 通过标准 |
| --- | --- |
| 依次拨 4、3、2、1 空弦，再按 1、3、2 跳调 | 弦号和轴一一对应。调准后弦、连接处、轴和勾一起亮，换弦保留此前状态，全部确认后才点亮琴身。 |
| 输入 4 弦 G₂ 加较强的 196 Hz 和 294 Hz 泛音，再测真实 G₃；对 D₃ 加强二次泛音，再测真实 D₄ | 真正单独拨高弦可以确认。低弦的强泛音不能点亮高八度弦或邻弦。实录覆盖拨片攻击和箱体共鸣。 |
| 四弦调好后，让 G₂ 尾音消失；重新拨偏低的 G₂；再拨准 | 衰减和短抖时保留勾。稳定的新偏差只清该弦、该轴及琴身全绿；重调回准后恢复。 |
| 点一根目标，连续比较三次；从调音页到节拍器再回来，结束参考音后继续监听 | 当前目标准确，比较可重复；回到调音页可按用户设置恢复所用定弦。参考音停止且监听恢复以后才可由新拾音确认。 |
| 对照真实照片逐轴核对，检查截图中的边缘留白、偏低、调准、偏高和最长本地化标题 | 弦进箱或绕轴沿真实路径，触区不串弦，图与音名不碰撞。曲线和针保持吉他页的短针比例。 |

频率可用 `f = A4 × 2^((MIDI − 69 + cents/100)/12)` 复算。合成输入先分别测标准、+15¢、−15¢，以及 A4 改成 442 Hz 的输出。合成音验证音高逻辑，拾音、强泛音和弦轴位置仍须按样琴实录复核。建议每根录三次正常拨弦、一次弱拨和一次自然衰减，另录两根同音名不同八度及一次相邻弦共鸣。把源文件记录为琴型、弦号、录音条件和独立参考读数，由测试人员重放后核对状态。

## 后续顺序

1. **冲绳三線**。本調子、二揚げ、三下げ有教师资料。专页可同时给工工四的弦位和实际目标，先用人声合奏的样本验基音可变。 [三線教室教学](https://sakai-sanshin.com/sanshin/chindami.html) · [教师的可变基音解释](https://ks-sanshin.com/%E4%B8%89%E7%B7%9A%E3%81%AE%E8%AA%BF%E5%BC%A6%EF%BC%88%E3%83%81%E3%83%A5%E3%83%BC%E3%83%8B%E3%83%B3%E3%82%B0%EF%BC%89%EF%BD%9C%E5%BF%85%E3%81%9Acfc%E3%81%AB%E5%90%88%E3%82%8F%E3%81%9B%E3%82%8B/)
2. **Đàn tranh 与 伽倻琴**。可沿用古筝的分组体验，各自以一种明确的弦数、桥位和传统先录制空弦；实际可验证的样琴决定两项先后。 [越南官方演出资料](https://vietnamtourism.gov.vn/en/post/5676) · [伽倻琴馆藏](https://www.metmuseum.org/art/collection/search/503206)
3. **坦普拉、长颈 bağlama、qanun**。先取得演奏者认可的具体配置。坦普拉验证相同音高的物理弦、嗡鸣和 Sa。长颈 bağlama 单独核对空弦；qanun 的成组弦和演奏变音机构分别验证。 [坦普拉声学测量](https://www.mtg.upf.edu/files/publications/Sankalp_Gulati_MasterThesis_MTG_2012.pdf) · [土耳其教育部 bağlama 教材](https://megep.meb.gov.tr/mte_program_modul/moduller_pdf/Ba%C4%9Flama%20Projesi%20Ve%20%C5%9Eablonu.pdf) · [Qānūn 馆藏](https://www.metmuseum.org/art/collection/search/500957)

## 阮族预览实现

下一版 worktree 为中阮、大阮、小阮、高音阮和低音阮分别提供四弦配置，复用批准的如意头正视图作为一种 2+2 机械轴的代表。轴盖只画轮廓，弦从弦枕到轴盖边缘，盖后绕线及横杆保持遮挡。调音页的每根弦、轴盖与旋钮共用同一个状态，选择器和顶栏图标沿用同一轮廓。完整实物对应仍以具体琴型为准。

| 新 ID | 默认空弦（4 至 1） |
| --- | --- |
| `Zhongruan` | G₂ · D₃ · G₃ · D₄ |
| `Daruan` | D₂ · A₂ · D₃ · A₃ |
| `Xiaoruan` | D₃ · A₃ · D₄ · A₄ |
| `Gaoyinruan` | G₃ · D₄ · G₄ · D₅ |
| `Diyinruan` | G₁ · D₂ · G₂ · D₃ |

表中小阮采用编配手册的定弦。香港常见的小阮同名配置可能高一个纯四度，可按实琴配置自定义。京剧中阮先保留在调研档，待样琴确认。 [编配手册](https://intermusic.lmta.lt/pluginfile.php/1547/mod_resource/content/2/QI-An_Instrumental_Guide_To_The_Chinese_Orchestra.pdf) · [乐器名称与地区区别](https://rism.info/resources-old-website/workgroups/Bilingual_Chart_of_Common_Chinese_Instrument_Names.pdf) · [大阮藏品](https://www.musikwissenschaft.uni-wuerzburg.de/en/musikinstrumente/bestand/inventarliste/de365-da-ruan/)

## 中国民乐扩展 · 调弦专页

以拿到乐器后、排练开始前要实际调整的部件为范围。第一批补齐民乐团常见声部，并把蒙古族、哈萨克族乐器纳入同一中国民乐入口，保留各自的名称和定弦传统。当前的二胡、琵琶、古筝、古琴、410 型扬琴和五种现代四弦阮继续保留。 [国家大剧院的民乐团声部介绍](https://www.chncpa.org/zxdtxlm/rdjjjhlm/rdjj_wx/202009/t20200930_221354.shtml) · [香港中乐团音域表](https://hkco.org/uploads/docs/682542ced6d771.pdf)

| 这版新增 | 默认空弦（实音） | 演奏前的实际任务 |
| --- | --- | --- |
| 马头琴 | G₃–C₄，另有 F₃–B♭₃ | 面对琴头时，右边粗弦是低音，左边细弦是高音。各拉一根空弦，转对应侧轴。保留马首和前方遮住的轴，预设使用各自实际音高。 [齐·宝力高谈 G–C](https://www.chncpa.org/zwzt/spzt/jdysjtzt/videos/ztyyh/202012/t20201208_223789.shtml) · [C₄–G₃等实音的研究记录](https://www.sinoss.net/uploadfile/2015/0922/20150922102349292.pdf) · [四度定弦的田野记录](https://static1.squarespace.com/static/5df8496c2958657b98af69f5/t/5f22ee990e10120e8fef4816/1596124828733/Hutchins_MusicAnimalsHeritageMongolia_Dissertation_June_9_2020.pdf) · [琴头制作者实物](https://munguntalst.mn/products/29869) |
| 柳琴 | G₃–D₄–G₄–D₅ | 按 4 至 1 弦单拨。线稿以梁浩四轴实物的正反面为参考，弦轴箱留窄槽。尾部微调器因型号而异，此页以琴头定位。 [教师实操](https://www.easonmusicschool.com/how-to-tune-zhongruan-liuqin-and-pipa/) · [琴头正反面近照](https://www.easonmusicstore.com/collections/pluckings/products/professional-wenge-wood-liuqin-by-liang-hao) |
| 高胡、中胡 | G₄–D₅、G₃–D₄ | 分别拉内外空弦。张连军款高胡和敦煌 92C 中胡各画琴杆、琴首和旋钮，两根轴与千斤沿用同一种结构表达，按乐器显示实际八度。 [温哥华跨文化乐团弦序](https://vi-co.org/resources-study/instrument-corner/erhu/) · [民族乐团弓弦编配资料](https://timbreandorchestration.org/instruments/ensembles/chinese-orchestra/bowed-strings) |
| 大三弦 | G₂–D₃–G₃，另有 D₂–A₂–D₃ | 用大三弦的 1+2 琴轴、开放的轴箱及无品短颈，逐根拨空弦。伴唱可用自定义调弦，小三弦与四弦改良型需各自配琴。 [乐手提供的实物照片及调弦研究](https://etheses.whiterose.ac.uk/id/eprint/33230/129/Yue%20Ming_202044062_Doctoral%20Dissertation.pdf#page=117) · [三弦藏品和伴唱用途](https://www.metmuseum.org/art/collection/search/505692) |
| 冬不拉 | 两弦 D₃–G₃ | 每次只拨一根，按相对粗细和对应的轴定位。用双弦哈萨克冬不拉的扁琴头，其他弦数和调法需配琴。 [冬不拉实物](https://wmic.net/kazakhstan-dombra/) · [D–G 开放弦示例](https://dombra.online/tuner) · [伊犁乐团演奏背景](https://ojs.s-p.sg/index.php/whyscx/article/viewFile/28590/pdf) |

### 后续扩展顺序

1. **京胡、板胡、月琴和小三弦。** 直接服务戏曲和地方曲艺。京胡以西皮、二黄及具体声腔的弦式作为入口。板胡先定高音与中音型号和各自的八度。月琴先确认京剧两组同音弦和改良型各自的物理弦数。小三弦独立定弦与近照。 [香港中乐团非常规乐器音域](https://www.hkco.org/uploads/docs/56011001d28aa1.pdf) · [中国民族音乐资料馆的拨弦乐器](https://chinesemusics.com/zh/info-db/instrument/%E6%A8%82%E5%99%A8%E5%BD%88/)
2. **新疆和西藏等地区的拨、拉弦。** 优先都塔尔、热瓦普、弹布尔、扎念，再做萨塔尔、艾捷克、必旺、火不思、库木孜。用演奏者实际用的琴定开放弦，热瓦普先选明确形制，弹布尔、艾捷克和扎念区分单弦、同音弦组及共鸣弦。 [新疆维吾尔木卡姆](https://ich.unesco.org/en/RL/uyghur-muqam-of-xinjiang-00109) · [中国民族民间器乐综述](https://chinesemusics.com/zh_cn/2022/02/10/e-general002/)
3. **继续补地方胡琴和多弦。** 四胡、椰胡、坠胡、京二胡、广东二弦、马骨胡，以及革胡、低音革胡。箜篌、瑟与其他需逐弦调音的多弦乐器按代表型号做，键位长度、两排琴弦或活动琴码决定分组与触区。 [地方拉弦资料](https://chinesemusics.com/zh/info-db/instrument/%E6%A8%82%E5%99%A8%E6%8B%89/) · [现代乐团编配](https://hkco.org/uploads/docs/682542ced6d771.pdf)

放行前逐项确认代表型号的正视照片、最低与最高弦的实音、物理轴序、可调部件和辨识单弦的方法。合成测试先验证目标与状态，实录用来验基频、跳弦和重新跑音。笛、箫、唢呐、葫芦丝归共享校音与合奏基准，笙归音高检查。 [竹笛调音教学](https://www.easonmusicschool.com/dizi-tuning/)
