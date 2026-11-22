# 构建、测试与发布

四款表盘分别编译为 Forerunner 265S 的 Connect IQ 应用。各项目的 `manifest.xml` 指定入口、设备、语言和应用 ID。覆盖安装沿用相同的签名、应用 ID 和 PRG 文件名。

## 源码与设置

| 位置 | 职责 |
| --- | --- |
| 每款表盘的 `source/*App.mc` | 系统生命周期、设备设置通知、一级菜单及其顺序 |
| `source/*Face.mc` | 亮屏、常亮和关屏的绘制，决定何时查询时间或活动数据 |
| `source/*Settings.mc` | 读取本款的设置、默认值、子菜单和输入处理 |
| [shared/Settings.mc](shared/Settings.mc) | Terminal、LED、Orbit 编译时引用的六位 HEX 校验和属性保存逻辑 |
| [Orbits.mc](tv-orbit/source/Orbits.mc) | Orbit 专用的八颗行星位置计算、缓存和绘制 |
| 各项目的 `resources*` | 设备资源、三种菜单语言和设备图像 |

Minimal 沿用手表本地 Storage 和 12 个预设色。其他三款的手表菜单和配套设置页共用 Properties。Terminal 的时间制式存储为 0／1／2，Orbit 存储为 0／12／24，分别代表跟随、12 小时和 24 小时。Orbit 的轨道比例以 2 表示内圈优先（默认），0 表示线性实距，1 表示对数距离。维护菜单时保留这些值、Storage 键、属性类型和各款默认值。

菜单先放时间制式和颜色，再放布局、电量、数据行，最后放采样频率。每款只列出实际支持的设置。配套设置的项目顺序与手表一致。经 USB 侧载的 PRG 使用手表菜单。手机设置页适用于通过 Connect IQ 商店安装的应用，直接输入 HEX。[Garmin 设置说明](https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq#app-settings)

## 本地构建与验证

安装 Garmin Connect IQ SDK 9.3.0 和 `fr265s` 设备定义，将 SDK 的 `bin` 加入 PATH，并让 `CIQ_DEVELOPER_KEY` 指向本地签名密钥。从**仓库根目录**运行以下 PowerShell，`$face` 可改为表中的任一项目。启动 Connect IQ Simulator 后运行最后一行，可以在模拟器中打开安装包。

| 项目 | 安装包 | 标签前缀 |
| --- | --- | --- |
| tv-minimal | TVMIN.prg | `v` |
| tv-terminal | TVTERM.prg | `tv-terminal-v` |
| tv-led | TVLED.prg | `tv-led-v` |
| tv-orbit | TVORBIT.prg | `tv-orbit-v` |

```powershell
$face = 'tv-minimal'
$packages = @{'tv-minimal'='TVMIN'; 'tv-terminal'='TVTERM'; 'tv-led'='TVLED'; 'tv-orbit'='TVORBIT'}
$file = $packages[$face]
monkeyc -f "$face/monkey.jungle" -d fr265s -y $env:CIQ_DEVELOPER_KEY -o "bin/$face/$file.prg" -r -w -l 3 -O 2
monkeydo "bin/$face/$file.prg" fr265s
```

仓库根目录的 `monkey.jungle` 可构建 Minimal。其他项目从同一份仓库检出构建，以便引用相邻的 `shared`。Terminal 和 LED 的字模已随项目提交。运行 `python tv-orbit/tools/make_orbits.py` 可用 Pillow 重建三张轨道底图，运行 `python tv-led/tools/make_fonts.py` 可重建七段字模。测试套件和星历核对脚本由维护者在本地运行。

## v1.0.0 性能与验证

| 表盘 | 亮屏开销 | 常亮 |
| --- | --- | --- |
| Minimal | 背景按需更新，心率单独绘制。活动数据与电量按用户设置取样。 | 系统时间配合交替遮罩，暂停活动与心率查询。 |
| Terminal | 复用整帧。三行共享一次活动数据查询，仅在选中心率时读取心率。 | 只画时间，交替点亮奇偶行。 |
| LED | 换分时重排一行字，默认在换分边界校时。 | 全日两种制式最大 1,006 个亮点，占圆屏 0.99%，相邻分钟零重合。 |
| Orbit | 轨道离线预绘。首次亮屏、跨 UTC 日或切换比例时合成星图，换分只更新时钟和日历。 | 只画调暗的时间，暂停轨道计算。 |

在 265S 模拟器上，内圈优先模式交替测量四轮，每轮重复绘制星图 100 次。直接绘制底图和圆点耗时中位数 1,930 ms，复用合成图为 734 ms，约减少 62%。设备图形内存紧张时可退回直接绘制。实表续航还需控制屏幕亮度、抬腕频率和常亮设置后佩戴测量。

亮屏与常亮分别检查 12／24 小时制、图形位置与关屏路径。菜单使用系统控件，手表及配套设置的项目顺序逐款检查。英文、简体中文和繁體中文逐项比对编译后的字符串资源。用于中文截图的 265S 模拟器以本机 Noto Sans SC Medium 补足设备包缺失的系统点阵字形，实表字形以固件为准。[Orbit 位置对照](tv-orbit/README.md) · [Minimal 布局与功耗](tv-minimal/构建与功耗评估.md)

## 发布与更新

推送审查后的提交及版本标签，GitHub Actions 从标签检出源码，严格编译、签名并核对上传资产的 SHA-256。发布标题和正文写明表盘名和版本号，版本号与对应 manifest 一致。预览标签追加 `-preview.N`。一次发布四款时分批推送标签，每次最多三个，以触发每个标签的工作流。Minimal 稳定版使用仓库 Latest，其余下载链接固定到各自标签。[发布工作流](.github/workflows/release.yml) · [GitHub 标签推送规则](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#push)

发布完成后，从每个 Release 下载 PRG 并核对摘要、发布状态和首页入口。重建已有发布时，在其标签上手动运行同一工作流并启用 `rebuild_release`。签名材料由 GitHub 的 `release` 环境管理，加密备份位于 `CIQ_RECOVERY_PEM_B64`，恢复口令由维护者单独保管。
