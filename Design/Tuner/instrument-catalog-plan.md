# 调音器乐器目录与文化入口

更新于 2026-11-22。这里记录后续扩库和文化发现的候选。公开上架以 [首发范围与里程碑](release-scope.md) 为准。[TunerCatalog](../../TheMetronome/TunerCatalog.swift) 保留首发和扩库配置。[TunerLibrary](../../TheMetronome/TunerLibrary.swift) 在正式版本仅显示首发范围，开发构建可评审完整目录。乐器页面按 [调音器页面标准](page-standards.md) 验收。

## 目录结构

- 保留原来的常用入口。Chromatic、吉他、贝斯、尤克里里、提琴等照旧直接找。文化是同一目录的发现路径，可以与乐器家族并存。比如尤克里里可从弦乐入口或夏威夷找到，曼陀林也可从拨弦或民间音乐传统找到。
- 把地区和传统做成可多选的浏览标签，用单一乐器 ID 关联。型号、定弦、曲种、谱音规则、本地显示名和搜索别名各自维护。目前代码里的 family 同时控制部分文案和画法，先加发现层元数据，逐步解除耦合。保留既有 preset ID、乐器 ID、已存配置和界面回归。
- 一级入口用用户会找的名字，例如中国民乐、日本传统、韩国传统、南亚、中东与北非、拉美与加勒比。只有已有适用条目的地区才显示，数量增加后再细分。原文和常见拼写都能定位。中文的古筝／古箏／guzheng、日文的箏／琴／koto、阿拉伯文的 عود／oud 归到相同 ID。阿拉伯和土耳其定弦等有实质差异的选项仍应清楚可选。考虑全名、单字别名误命中和 RTL。
- 设置三个清楚的任务入口。**调音**服务可主动改变的弦、音片或鼓皮。**校音与练习**服务合奏调基准、移调读谱和长音。**音高检查**服务检验固定音高或维修前诊断。用户需要的只有一个通用读数时，文化入口可打开共享校音或 Chromatic 并附有针对性的默认项。
- 专页门槛。能说清玩家会改动哪个部件或演奏动作、怎么定位目标、什么算完成。至少获得一个可信实物型号或演奏传统的参考，配上可复现的录音／演奏流程，再做专页。文化覆盖和值得做独立调音页是两项独立判断。

## 笛子怎么处理

竹笛适合在「中国民乐」里被找到。带铜接头的笛可以伸缩以粗调整体音高，口风和吹奏角度也会改变发声的音高。一体笛没有这个日常机械调节，逐孔改制属于制作或维修。建议**保留笛子入口，落到共享校音／长音页**。有证据显示玩家会用到时，再提供选笛调、合奏基准、相关指法和长音稳定反馈。当前公共目标音表不够定义所有调号的笛。箫、尺八同样先走丝竹管乐校音流程，以各自实际的口风与奏法教学验证。 [笛子实际调音动作](https://www.easonmusicschool.com/dizi-tuning/) · [尺八音高与吹奏法](https://www.soundhouse.co.jp/en/contents/staff-blog/index?post=1306)

## 现有 69 项逐组审计

表中的动作决定下一版入口。已有配置在此阶段继续兼容。

| 项目（当前 ID） | 建议 | 真实任务与验收 |
| --- | --- | --- |
| `Guitar`、`7-string guitar`、`12-string guitar` | 主调音 | 每根空弦，按布局映射琴钮。12 弦区分八度组与同音组。7 弦验证低 B、降调和强泛音。 |
| `8-string guitar`、`Baritone guitar` | 内部候选 | 有真实调弦需求。分别验证低 F♯、降调和长尺度常用定弦后，再放进吉他子项。 |
| `Bass`、`5-string bass`、`6-string bass` | 主调音 | 分弦确认，实琴测试低 E、低 B、降调和弱拨。各弦轴布局独立。 |
| `Violin`、`Viola`、`Cello`、`Double bass` | 主调音 | 调空弦，保留拨弦与弓弦路径。大提琴低 C、低音提琴低 E、微调器及低音延伸可逐项验证。 |
| `Ukulele`、`Baritone ukulele` | 主调音 | 高 G／低 G 的八度区别、返身定弦和常用独立低音配置。可从拨弦和夏威夷入口找到。 |
| `Mandolin`、`5-string banjo` | 主调音 | 成对弦和第五短弦各有实物定位。区分按组完成和按物理弦完成。 |
| `Mandola` | 内部候选 | 确认四组弦定弦与逐弦流程，和曼陀林分清音域。 |
| `Harp`、`Lyre`、`Dulcimer` | 内部候选 | 值得做的是真实弦表与物理布局。竖琴区分拨杆／踏板；里拉以具体弦数和音阶为单位；Dulcimer 明确锤击式或阿巴拉契亚式后才做配置。 [拨杆竖琴厂家定弦](https://manufacturing.dustystrings.com/harps/about-harps/strings-tuning) |
| `Flute`、`Piccolo`、`Recorder` | 合奏校音 | 热身后校基准，用头管或接头微调（视型号）并练长音。短笛保留实际升高一八度的谱音规则。 |
| `Oboe`、`English horn`、`Bassoon` | 合奏校音 | 参考音、簧片和长音稳定。英国管应按谱音与实音显示。校音方式因乐器和簧片而异，避免统一给出机械操作指示。 |
| `B♭ clarinet`、`A clarinet`、`Bass clarinet` | 合奏校音 | 管节位置与移调有价值，核对低音单簧管的记谱传统。 [Yamaha 的单簧管管节与音准](https://hub.yamaha.com/winds/wood/advanced-instrument-design-and-maintenance-clarinet-replacement-barrels-and-tuning/) |
| `Soprano sax`、`Alto sax`、`Tenor sax`、`Baritone sax` | 合奏校音 | 吹嘴位置校整体，长音练口风。校正 B♭ 和 E♭ 各音区的实音／谱音。 |
| `B♭ trumpet`、`C trumpet`、`Flugelhorn`、`Horn in F`、`Cornet in B♭` | 合奏校音 | 核对总调音管、常用目标音和移调。 [Yamaha 的小号调音管说明](https://www.yamaha.com/en/musical_instrument_guide/trumpet/mechanism/mechanism002.html) |
| `Trombone`、`Euphonium`、`Tuba` | 合奏校音 | 总体校准与滑管／指法音准练习。若扩展移调，应按谱法、声部和地区单独验证。 |
| `Piano` | 共享音高检查 | 适合测单键。整琴涉及分弦、非谐性和伸展调律，专业流程单独评估。 [Yamaha 钢琴调律](https://www.yamaha.com/en/musical_instrument_guide/piano/maintenance/maintenance002.html) |
| `Keyboard` | 合并到检查 | 可核对电子琴的 A4 校准和全局移调，普通单键检查用 Chromatic 即可。 |
| `Organ` | 合并到检查 | 区分电子风琴与管风琴。前者校全局音高，后者逐管属于专业维护。 |
| `Accordion`、`Harmonica` | 共享检查／练习 | 手风琴多簧拍频、口琴低吹高吸与压音各有用途，逐簧调音属于维修。有可靠孔位和簧片模式后再评估专页。 |
| `Timpani` | 主调音 | 可改鼓皮张力，按实际锅径和音域选目标，用鼓皮不同位置的测音校验。 [Yamaha 定音鼓维护](https://hub.yamaha.com/drums/percussion/timpani-maintenance/) |
| `Marimba`、`Vibraphone`、`Xylophone`、`Glockenspiel` | 合并到检查 | 检查音板和谱音八度。演奏者通常不现场逐板调音。 [Yamaha 音板制作与调音](https://www.yamaha.com/en/musical_instrument_guide/marimba/manufacturing/manufacturing002.html) |
| `Steel pan`、`Handpan` | 共享音高检查 | 可按音区核对成品和诊断，专业整形再调音。地图和基频检测通过实物验证后才扩展。 [手碟制作者维护说明](https://www.isthmusinstruments.com/handpan-faq) |
| `Kalimba` | 主调音 | 音片可调，绑定琴键位置和实际音阶。先以 17 键 C 调实琴验证，其他布局单独选。 |
| `Erhu`、`Pipa`、`Guzheng`、`Guqin`、`Yangqin` | 中国民乐主调音 | 每根弦、成对弦或同音组要定位，校验弦序、定弦和真正可操作的旋钮／琴码。 [古筝校音](https://yunyangmusic.com/pages/how-to-set-up-tune-your-guzheng) · [大都会博物馆琵琶说明](https://www.metmuseum.org/ja/essays/the-pipa) |
| `Dizi`、`Xiao`、`Suona` | 中国民乐共享校音 | 笛校接头或口风，箫和唢呐练长音、音准、合奏基准。唢呐的簧片和管体调别需分辨。 |
| `Sheng` | 中国民乐音高检查 | 可检查簧片和合奏基准。把簧片保养、维修校准作为独立专业任务。 [中国乐器维修分项](https://www.easonmusicschool.com/our-services/music-instrument-repair/) |
| `Koto`、`Shamisen` | 日本传统主调音 | 箏以调式、移柱与弦号定位；三味线区分本調子、二上り、三下り和主音。 [箏与调弦研究](https://www.jstage.jst.go.jp/article/ast1980/10/5/10_5_279/_article) · [三味线实物](https://www.metmuseum.org/art/collection/search/503799) |
| `Shakuhachi` | 日本传统共享校音 | 核对管长或常用标准音，再练メリ／カリ和长音。 |
| `Sitar` | 南亚主调音 | 区分主弦、chikari 和共鸣弦。按 Sa 和具体传统配置，不能把一种 C♯ 配列写成普遍标准。 [大都会博物馆南亚乐器](https://www.metmuseum.org/en/essays/musical-instruments-of-the-indian-subcontinent) |
| `Oud · Arabic` | 中东与北非主调音 | 验证阿拉伯乌德琴的弦组、低单弦及预设。土耳其乌德琴用单独的型号／预设，避免共用默认定弦。 [乌德演奏课程的定弦比较](https://studyoud.com/lessons/oud-tuning-guide/) |
| `Voice` | 共享练习 | 固定目标、持续音和自然颤音的稳定反馈。人声可以是入口，和机械调音分开。 |

## 地区发现和扩展候选

P0 是重用已支持乐器做发现入口。P1 需要核对代表型号、固定音名、传统定弦和演奏者验证。后续候选用来覆盖检索需求，优先做易验证的子集。

| 文化与传统 | P0 可重用／优先接入 | P1 及后续调研 |
| --- | --- | --- |
| 中国民乐 | 二胡、琵琶、古筝、古琴、扬琴。竹笛、箫、唢呐用于校音，笙用于检查。 | 先看中阮，再看柳琴、三弦、月琴、京胡／板胡、民族低音拉弦的具体型号。葫芦丝等先给共享校音。 |
| 日本与冲绳传统 | 箏、三味线、尺八。 | 三線、津轻三味线选型、十七弦箏、琵琶。篠笛、能管的参考音依传统分开。 [冲绳三線](https://visitokinawajapan.com/discover/traditional-culture/traditional-okinawan-arts/) |
| 韩国传统 | 首批验证后开放。 | 伽倻琴（가야금／gayageum，区分正乐、散调、改良多弦）、玄琴、奚琴。大笒先做校音。 [伽倻琴实物与传统](https://www.metmuseum.org/art/collection/search/503206) |
| 越南及东南亚 | 首批验证后开放。 | 越南 Đàn tranh、Đàn nguyệt、Đàn nhị、Đàn bầu；泰国 khim／saw duang；缅甸 saung；印尼 kacapi／sasando。甘美兰以具体合奏套件校音为主，避免把 sléndro 或 pélog 映射成一组普遍频率。 [越南传统乐器演出](https://vietnamtourism.gov.vn/en/post/5676) |
| 南亚 | 西塔琴。 | 坦普拉（tanpura）、萨罗德（sarod）、维纳琴（veena）、萨朗吉（sarangi）。塔布拉先验证可定目标的鼓面校准。班苏里（bansuri）走校音。按具体传统和基音做预设。 [南亚乐器综述](https://www.metmuseum.org/en/essays/musical-instruments-of-the-indian-subcontinent) |
| 阿拉伯传统／中东与北非 | 阿拉伯乌德琴。 | 阿拉伯 qanun、摩洛哥 guembri、具体传统的 rebab。Ney 先支持校音。开放弦或弦组、曲式变音与音律分开验证。 [大都会博物馆 Qānūn 实物](https://www.metmuseum.org/art/collection/search/500957) |
| 土耳其与安纳托利亚 | 阿拉伯乌德琴可被相关查询找到；具体屏直接标清传统。 | 土耳其乌德、bağlama／saz、kanun、卡拉德尼兹 kemençe。候选按琴型与弦组验证；避免把阿拉伯与土耳其调法合并。 |
| 伊朗／波斯传统 | 首批验证后开放。 | 塔尔（tār）、塞塔尔（setār）、桑图尔（santur）、卡曼恰（kamancheh）。按定弦传统和音律分别验收。 [伊朗塔尔](https://www.metmuseum.org/art/collection/search/502242) |
| 中亚、蒙古高原与草原 | 首批验证后开放。 | 哈萨克冬不拉（dombra）、吉尔吉斯 komuz、中亚／维吾尔 dutar、蒙古／内蒙古马头琴。跨传统允许多个入口。 [冬不拉传统](https://ich.unesco.org/en/RL/kazakh-traditional-art-of-dombra-kuy-00996) · [马头琴传统](https://ich.unesco.org/en/RL/traditional-music-of-the-morin-khuur-00068) · [都塔尔传统](https://ich.unesco.org/en/RL/dutar-making-craftsmanship-and-traditional-music-performing-art-combined-with-singing-01565) |
| 欧洲古典、凯尔特与民间 | 提琴家族、曼陀林、管弦乐队；校音入口。 | 凯尔特竖琴、希腊 bouzouki、葡萄牙吉他、巴拉莱卡、bandura、瑞典 nyckelharpa。具体地区和曲种不写成泛欧洲标准。 |
| 北美、夏威夷及太平洋 | 吉他、班卓、曼陀林、尤克里里；电贝斯在常用入口。 | 阿巴拉契亚 dulcimer、dobro、踏板钢吉他与不同琴调。夏威夷松弦调弦可先做吉他预设，不必重复做一把吉他。 |
| 拉美与加勒比 | 可关联吉他、钢鼓检查。 | 安第斯 charango、委内瑞拉 cuatro、波多黎各 cuatro（另设身份）、波多黎各 tiple、mexican vihuela、jarana、巴西 cavaquinho／viola caipira。先选型号和弦组，再做画法。 [Smithsonian 的 cuatro 实物与传统](https://latino.si.edu/exhibitions/presente/latino-identity/cuatro) |
| 西非、南部非洲和其他非洲传统 | 校音器可重用，kalimba 与 mbira 仅共享可复用的结构能力。 | 西非 kora、ngoni；津巴布韦 mbira 先做具名琴型和本地调法；埃塞俄比亚 krar 等可排在后续。避免用单一“非洲音阶”。 [kora 实物](https://www.metmuseum.org/art/collection/search/501115) · [mbira 演奏者的定弦说明](https://mbira.org/learn-mbira/how-to-tune-your-mbira/) |

## 排工和放行

1. **目录和本地化**先完成中国、日本、南亚、中东与北非等有条目的入口，标明调音／校音／检查。验证常用家族入口一键可达、文化别名可查、跨入口选中的是同一乐器、切换和重开不丢预设，长文案及 RTL 可读。
2. **校音界面**先验证真实交互差异。笛子和尺八找一个老师／乐手走一遍合奏热身与长音，管乐走谱音／实音及选目标流程，固定音高乐器验证一个可信的检查模式。定制面板只在共享页面确实做不到时增加。
3. **弦乐扩展**优先并行核对中阮、冲绳三線、伽倻琴、Đàn tranh、具体型号的 qanun 或 bağlama、坦普拉、charango 或 cuatro。每个候选给弦序、音域、至少一套实证定弦、参考实物及各位测试。再用同一门槛开放更多地区。
4. **检测与回归**独立检查低音、八度、邻弦共鸣、同音弦、尾音、持续音和偏差撤销。优先运行现有单测与模拟器旅程。同时记录真实设备及实琴验证边界。
