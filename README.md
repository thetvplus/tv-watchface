# tv-watchface

四款面向 Garmin Forerunner 265S 的低功耗 AMOLED 表盘。GitHub Releases 提供已签名的 `.prg` 安装包。四款可同时安装，点表盘名可查看预览与设置。

[USB 安装](#install) · [覆盖更新](#update) · [卸载](#uninstall)

## 正式版下载

| 表盘与预览 | 风格 | 当前版本 | 265S 安装包 |
| --- | --- | --- | --- |
| [tv-orbit](tv-orbit/) | 太阳系表盘，含四种轨道样式和可调更新间隔 | [v1.1.1](https://github.com/thetvplus/tv-watchface/releases/tag/tv-orbit-v1.1.1) | [TVORBIT.prg](https://github.com/thetvplus/tv-watchface/releases/download/tv-orbit-v1.1.1/TVORBIT.prg) |
| [tv-led](tv-led/) | 复古七段数字时钟，大小和高度可调 | [v1.1.0](https://github.com/thetvplus/tv-watchface/releases/tag/tv-led-v1.1.0) | [TVLED.prg](https://github.com/thetvplus/tv-watchface/releases/download/tv-led-v1.1.0/TVLED.prg) |
| [tv-terminal](tv-terminal/) | 80 年代终端，点阵时间和三行可选读数 | [v1.0.2](https://github.com/thetvplus/tv-watchface/releases/tag/tv-terminal-v1.0.2) | [TVTERM.prg](https://github.com/thetvplus/tv-watchface/releases/download/tv-terminal-v1.0.2/TVTERM.prg) |
| [tv Minimal](tv-minimal/) | 系统字体，大号时间和三项日常读数 | [v1.0.1](https://github.com/thetvplus/tv-watchface/releases/tag/v1.0.1) | [TVMIN.prg](https://github.com/thetvplus/tv-watchface/releases/latest/download/TVMIN.prg) |

[全部发布](https://github.com/thetvplus/tv-watchface/releases)

<a name="install"></a>

## USB 安装

准备一台 Windows 电脑、一根支持数据传输的 USB 线和 Forerunner 265S。265S 使用 MTP，macOS 的 Finder 不会把它显示为普通 USB 磁盘。[Garmin MTP 设备说明](https://support.garmin.com/en-US/?faq=CZqibgTHMb0dAYEaj2UiU7)

1. 从上表下载想安装的 `.prg` 文件，保留原文件名。
2. 通过 USB 将手表连到电脑。在文件资源管理器中打开「此电脑 → Forerunner 265S → Internal Storage → GARMIN → Apps」，把 `.prg` 复制到 `Apps`。
3. 等待复制完成，再断开 USB。回到手表时间页，长按 **UP**，选「表盘」，用 **UP／DOWN** 找到刚安装的表盘，按 **START → 应用**。

如果手表连接电脑后只充电，检查手表的「系统 → USB 模式」是否选了 **MTP**。如果设备已连接但文件资源管理器看不到，先退出 Garmin Express，再重新连接。[Garmin 侧载指南](https://developer.garmin.com/connect-iq/connect-iq-basics/your-first-app/) · [265 系列系统设置](https://www8.garmin.com/manuals-apac/webhelp/forerunner265series/ZH-CN/GUID-C672ECF6-A8F1-427A-B405-BB7132F27A7A-819.html) · [265 系列表盘菜单](https://www8.garmin.com/manuals-apac/webhelp/forerunner265series/ZH-CN/GUID-6DBDF548-1D84-4D73-9A97-E5E25DA9E329-1709.html)

<a name="update"></a>

## 覆盖更新

下载同一款的新版 `.prg`，保留原文件名并按安装步骤复制到 `GARMIN/Apps`。如果 Windows 提示文件同名，选择替换。直接覆盖可保留表盘设置。已安装的 `.prg` 可能在文件资源管理器中隐藏，仍将新版复制到同一目录即可。[Garmin 开发者论坛的侧载说明](https://forums.garmin.com/developer/connect-iq/f/discussion/367718/sideload-prg-file-no-longer-working?pifragment-1298=1)

<a name="uninstall"></a>

## 卸载

1. 如果正在使用要卸载的表盘，先切换到手表自带表盘。
2. 用 USB 连接手表，打开 Garmin Express，选中手表并进入 **IQ Apps**。
3. 找到对应表盘，点击旁边的 **×**，再同步手表。同步完成后，回到「表盘」菜单确认该表盘已移除。

也可以在手表上按 **START** 打开活动与应用列表，进入 **Connect IQ Store**。如果表盘出现在已安装列表，选中它并确认卸载。[Garmin Express 卸载说明](https://support.garmin.com/in-ID/?faq=ZOJb1R5G9M4PKsnxOyIdv7) · [手表端 Connect IQ 商店说明](https://support.garmin.com/en-US/?faq=nHn3HyFFzr17WgC2tJ7sb8)

## 开发

[构建、测试与发布](DEVELOPMENT.md)
