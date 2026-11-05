# MU-UI01 · Glasmio 风格实验界面

状态：待体验（测试版已发布）。创建于 2026-11-04（Asia/Taipei）。

## 目标与现场

用户要求参照 NEORUAA/Glasmio 改造 SakuraMusic，并在实验性分支实现。交付可运行的 Flutter 界面：玻璃导航与迷你播放器、发现页、全屏播放器和一致的基础控件；原有路由、播放、收藏、队列、服务器与离线数据行为保留。

- 初始基线：本机 `main`，`3f7050027a087999c3ca5ef1b97af62b8ca01c58`；发布基线改为正式 v0.3.8，`daa82d7e419a2740ac963d94a5ee7d680a574c7d`，原因和验证见 T5。本任务不处理主工作区与远端的历史整合。
- 分支：`feat/20261104-mu-ui01-glasmio-experiment`。
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261104-feat-mu-ui01-glasmio-experiment`。
- 主工作区已有未跟踪 `AGENTS.md`，原样保留；工作树带一份相同指导文件，不归入功能提交。
- 合入目标：保留独立实验分支，不合入正式主线。用户于 2026-11-05 追加“发布一个测试版”，已授权为测试版发布所需的提交、推送、创建标签、运行既有打包流程及发布 GitHub prerelease；仅推进测试更新清单。
- 视觉验证用内存数据库、合成音乐数据与模拟播放服务，不运行正式启动流程中的凭据迁移，不读取真实服务器凭据。

## 冻结的实现规格

参考 Glasmio `700a611f9024c8f3bd9f0b8dd26d939a0dcbeb72` 的 [设计说明](https://github.com/NEORUAA/Glasmio/blob/700a611f9024c8f3bd9f0b8dd26d939a0dcbeb72/docs/design-reference.md)、[材质说明](https://github.com/NEORUAA/Glasmio/blob/700a611f9024c8f3bd9f0b8dd26d939a0dcbeb72/docs/native-materials.md) 和 `GlassTokens.kt` / `GlassBottomBar.kt`。它是 Android Compose 库（Apache-2.0、min API 33），不直接引入 Flutter，不复制字体、壁纸、图标或上游渲染源码，不抬高本应用 Android 最低版本。

本轮为 Flutter 视觉移植，不宣称 1:1 复刻或实现上游折射 shader。真实背景采样用裁剪的 `BackdropFilter`，叠加染色、渐变高光边框和阴影；渐进模糊用分带 Gaussian 近似。Flutter 的 sigma 独立调整，不套用上游 shader 单位。

- 沿用深色模式和用户强调色。底色接近 `#08090D`，提升表面 `#1C1C1E`，正文白色、次级文字约 60% 白；不引入新字体或 UI 依赖。
- 共享圆角：紧凑 16、普通 26、sheet 38，胶囊完整圆角。移动端图标按钮触摸框至少 44；保留 tooltip、键盘与语义能力。新增循环动画与导航过渡遵守 Flutter `disableAnimations`；高对比模式关闭共享表面的背景模糊并使用不透明底色。Flutter 未提供可直接读取的系统“降低透明度”信号，不宣称已支持该独立设置。
- 窄屏五目的地映射继续为 `[0,1,2,6,3]`；720 起显示侧栏。底部胶囊高 62、内边距 4、选中胶囊高 54，窄屏必要时随文字缩放增长，不能裁字。迷你播放器在其上方，以独立玻璃岛呈现。
- 发现页保持区块顺序、数据来源与全部操作：标题/服务器、分类、每日推荐、随机、最近播放、最近添加、歌单、统计。改进材质、层级与间距，不重新定义每日推荐刷新/播放语义。
- 全屏播放器保留封面环境光、封面/黑胶/歌词模式、进度、队列、音量、循环、随机及现有操作；顶部按钮与模式切换、底部 dock 使用一致玻璃材质。
- 共享组件位于 `lib/core/widgets/glass.dart`，由主 agent 独占：`GlassSurface(child, borderRadius, padding, clear, tint)`、`GlassIconButton(icon, tooltip, onPressed, selected, size, color)`、`GlassBackdrop(child)`、`ProgressiveGlassBlur(height, bottom)`。图标参数为 Widget，onPressed 可空，size 默认 44。

## 实现与分工

T1：查证参照与当前入口；已由只读调研专家分别核实 Glasmio 和本应用 UI，主 agent 冻结以上规格。主 agent 实现共享材质、主题、文档与集成。

T2：独立原生预览入口 `tool/glasmio_preview.dart`，使用生产页面和路由、内存数据库与合成数据，不访问真实音乐服务器。worker 独占此文件；不派下级。主 agent 先核验基线，再核验最终组合态。

T3：界面实施可在共享 API 冻结后并行。导航专家独占 `app_shell.dart` / `mini_player_bar.dart`；发现页专家独占 `home_screen.dart`；播放器专家独占 `player_screen.dart`。仅修改表现层，业务逻辑与测试预期不变。每人使用同一工作树，不提交或启动服务，不派下级。

T4：主 agent 检查集成 diff、执行 `flutter analyze` 和受影响既有 widget 测试，构建并在 macOS 原生预览核验。预览服务、端口及进程仅属本任务；后续记录实际信息。

## 验收场景

1. 390×844 和 320×740 的窄屏：底部五项、迷你播放器、长标题、播放/下一首均可用且无溢出；安全区域与滚动末尾可见。
2. 1280×800 和至少 960×640 的桌面：侧栏切换、搜索、设置、首页推荐与滚动正常，玻璃材质有真实背景取样，文字/图标清晰。
3. 发现页每日推荐刷新不启动播放，点击卡片播放当前批次；既有对应测试通过。
4. 全屏播放器与歌词/黑胶切换、进度、队列和返回可用。模拟服务验证界面接线，不当作真实音频播放证据。
5. 现有无服务器欢迎页和设置流程保持可用。`flutter analyze` 无新增问题；相关 widget 检查结果绑定最终修改。

## 实施结果

- T1 已完成：固定上游参照；采用 Flutter 视觉移植，保持平台兼容性与数据层。没有新增依赖或修改依赖锁。
- T2 已完成：独立预览入口使用内存 Drift、内存凭据和 loopback 合成 Subsonic 服务；包含 24 首歌、8 张专辑、4 位艺术家，模拟播放、搜索、收藏、队列与歌词。禁用真实音频、下载、更新和反馈；图片缓存仍使用平台缓存。分发的本任务预览包使用独立 bundle ID 隔离缓存。
- T3 已完成：共享连续圆角玻璃组件、基础主题、桌面侧栏、五项底栏、迷你播放器、发现页和全屏播放器。发现页固定页头接入 24 带渐进模糊，sigma 从 18 二次衰减至 0，最后一带不加滤镜，前景控件保持清晰；文字测量决定单行/双行页头。玻璃 dock 位于进度监听器之外，避免随播放位置反复重建材质。
- T4 已完成本轮适用的本地检查：静态检查、受影响 widget 测试、macOS/Android 构建和 macOS 原生预览回归均已完成。用户解锁后继续检查，发现的两处布局溢出与模糊接缝已修正并复核；Android 实机及真实音乐服务的限制见下文。

### 本轮修正与测试依据

- 390px 原生预览发现首页动作组未靠右与高光过强，已修正并重新构建核验。
- 新导航测试使用真实 `AppShell`、隔离的八分支路由、内存数据库及不可用音频服务，在 320×740、1.0/1.8 倍文字下点击五个目的地，检查实际路由、可见页面与无异常；含长服务器名。
- 原有播放器窄屏测试从 `[360, 390, 430]` 扩大到 `[320, 360, 390, 430]`，保留原断言。新增宽度暴露次级操作行 8px 溢出：IconButton 默认触摸占位仍为 48。显式使用 44px shrinkWrap 触摸框并将 dock 内侧水平留白从 16 改为 12 后通过，所有操作保留。
- 首页在 320px 原生滚到非空“最近添加”时，专辑卡片出现 4px 高度溢出：固定 195px 列表不能容纳 136px 封面及三行元数据。列表现在按封面高度加随文字缩放的 80px 元数据空间计算。新增回归先在旧高度复现，再覆盖 320/390px、1.0/1.4 倍文字共四种情况通过；原生确认年份完整、没有溢出条。
- 960×640 桌面播放器的固定封面区曾溢出约 60px。封面改为 `Flexible(loose)`，在保留标题、元数据和 dock 后使用剩余高度，保持正方形与 360px 上限。新增回归先复现 59px 溢出，再检查封面可见且元数据位于 dock 上方；主 agent 使用最终包原生复核通过。
- 原六带渐进模糊在滚动位置出现水平接缝。改为上述 24 带，并在同一原生滚动场景对照修复前后，接缝明显改善、前景文字清晰。仍为 Gaussian 分带近似，未引入仅支持部分渲染后端的 shader；Android 性能尚未验证。
- 独立 reviewer 已只读核查共享材质、渐进模糊接入、高对比/减少动画行为、导航和预览隔离；后续布局修复及最终组合态由主 agent 核对并运行回归。审查结论不代替原生操作及性能验证。

## 界面实现阶段验证与证据（初始基线）

环境：Flutter 3.41.3 / Dart 3.11.1，macOS 27.0.1 arm64。以下为 2026-11-04 初始基线 `3f7050027a087999c3ca5ef1b97af62b8ca01c58` 上的验证，当时改动尚未提交，不作为移植后全部发布检查的替代。10 个改动 Dart 文件的 SHA-256 记录在 `build/mu-ui01-evidence/final-source-manifest.json`，组合指纹为 `0828b33eed29239707bdceba06d697413e8f25edcf8b5a1b05cc8ef7385d812a`；下表针对同一份文件内容执行。旧 `final-*.log` 与溢出截图仅保留调试历史，该阶段通过证据使用 `verified-*.log`。

| 检查 | 本次结果 | 证据（工作树内） |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed`，10 个改动 Dart 文件 | 通过，0 个需格式化 | 命令输出；文件哈希见 manifest |
| `flutter analyze --no-pub` | 通过，无问题 | `build/mu-ui01-evidence/verified-analyze.log` |
| `flutter test --no-pub test/glass_navigation_test.dart test/player_widgets_test.dart test/home_daily_card_widget_test.dart test/widget_test.dart test/artists_screen_test.dart --reporter expanded` | 58 项全部通过 | `build/mu-ui01-evidence/verified-widget-tests.log` |
| `git diff --check` | 通过 | 最终工作区检查 |
| `flutter build macos --debug --no-pub --target tool/glasmio_preview.dart` | 通过；已复制并重签独立 bundle ID，签名校验通过 | `build/mu-ui01-evidence/verified-preview-build.log` |
| 同一预览入口，分别加 `GLASS_PREVIEW_ROUTE=/settings`、`GLASS_PREVIEW_EMPTY=true` | 均通过，已复制并重签独立 bundle ID，签名校验通过 | `build/mu-ui01-evidence/verified-settings-build.log`、`verified-empty-build.log` |
| `flutter build macos --debug --no-pub`，普通入口 | 通过；默认构建目录最终保留普通入口版本 | `build/mu-ui01-evidence/verified-app-build.log` |
| `flutter build apk --debug --no-pub`，普通入口 | 通过；未安装 | `build/mu-ui01-evidence/verified-android-build.log`，产物 `build/app/outputs/flutter-apk/app-debug.apk` |

既有 TrackDiscoverySheet 测试夹具输出 Drift 多数据库 debug warning，但测试通过；没有关闭警告、跳过用例或降低门禁。Android 构建输出 SDK XML 版本差异警告后成功；未修改 SDK、最低版本或项目配置。协议/音频数据层未改，本轮未额外运行全部协议测试或所有平台构建。

### 原生预览已查与未查

- 已查基线 1280×800 首页与播放器。最终改造在 macOS 原生预览检查 1280×800、960×640、390×844 与 320×740；手机预设使用 Android 主题分支，不能当作 Android 实机。
- 320px 下实际点击底栏全部五个目的地：发现、歌曲（24 首）、专辑（8 张）、喜欢（2 首）、艺术家（4 位）；首页滚动到末尾统计可见，浮层占位正常。非空专辑卡片、滚动渐进模糊的修后截图为 `home-320-albums-fixed.png`、`home-320-scroll-fixed.png`。
- 播放器实际检查封面、黑胶、歌词、OLED 模式、播放开关、下一首、拖动进度（00:43→02:33）、队列中选择第二首并回到播放器。最终包再次检查 960×640 封面区与 320/390px 布局，并从迷你播放器打开后用顶部按钮收起回首页。最终截图为 `player-960-fixed.png`、`player-320-final.png`、`player-390-final.png`。
- 搜索输入 Blue，显示 1 张专辑与 5 首歌曲并返回；设置页滚动、语言弹窗及关闭正常；未更改用户设置。证据为 `search-960-final.png`、`settings-1280-final.png`、`settings-dialog-final.png`。
- 无服务器欢迎页正常，点击“新增服务器”进入类型选择页后返回，没有输入凭据或保存服务器。该页沿用既有局域网探索。证据为 `welcome-1280-final.png`、`welcome-add-server-final.png`。
- 手机最终首页截图为 `home-390-final.png`；`glasmio-mobile-preview.png` 仅将首页和播放器实际截图等比缩小并排，方便查看。全部截图在 `build/mu-ui01-evidence/`。此前锁屏已由用户解锁，不再是未完成项；工具偶发 AX 错误通过刷新应用绑定继续验证，未据此认定产品卡死。
- Android 设备未连接；Android 触摸、玻璃渲染性能、系统媒体控件、真实服务器与音频播放没有本次证据。模拟服务不证明这些能力。

## 体验与下一步

在本工作树运行 `flutter run -d macos -t tool/glasmio_preview.dart`。macOS 菜单“预览”提供桌面 1280×800、手机 390×844、手机 320×740、桌面 960×640 以及首页/播放器切换。手机预设仅切换 Android UI 分支，不模拟 Android 设备。无服务器页面可通过 `--dart-define=GLASS_PREVIEW_EMPTY=true` 启动。

初始基线预览构建副本：`build/glass-preview/SakuraMusic.app`，bundle ID `local.sakuramusic.mu-ui01.preview`。2026-11-04 预览进程 PID 20401 曾留在 1280×800 首页，loopback TCP 监听端口为 49630、49645；2026-11-05 发布准备时核对已退出。旧预览、设置预览 PID 18928、空资料库预览 PID 19384 均在核对完整路径后停止。后续发布基线的原生核验另记 T5。

设置与空资料库副本分别为 `build/glass-settings/SakuraMusic.app`（`local.sakuramusic.mu-ui01.settings`）和 `build/glass-empty/SakuraMusic.app`（`local.sakuramusic.mu-ui01.empty`）；基线副本 `build/glass-baseline/SakuraMusic.app` 仅用于比较。它们都位于本任务构建目录，没有安装到正式应用位置。普通入口仍为 `lib/main.dart`，连接自己的音乐服务时应使用该入口；普通 Android debug APK 使用项目原有应用标识，本轮未覆盖安装到任何设备。

界面实现阶段已达到“待体验”；用户随后要求发布测试版，当前发布步骤见 T5。Android 设备和隔离音乐服务上的真实渲染性能、音频及系统媒体控制仍待体验，没有用户确认前不标“已验收”。

实验尚未合入，因此保留本任务工作树供体验，不触发合入后清理。其他任务工作树与归档不操作；以后合入且验证完成后按既有规则清理本工作树，先保存所需忽略证据。

## T5 · 发布 Glasmio 测试版（2026-11-05）

- 已发布 [v0.3.9-glasmio.1](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.9-glasmio.1)，发布时间为 2026-11-05 12:16:45（Asia/Taipei）。冻结版本 `0.3.9-glasmio.1+1793850934`，沿用既有 `release.yml` 的多平台安装包与签名，使用普通 `lib/main.dart`；合成数据预览入口不作为公开安装包入口。构建号大于正式版所有 ABI 实际 code 的最大值 `1793787648`，并为 ABI 偏移预留范围。
- 发布前查明：初始实验基线数据库为 schema 17，已发布 v0.3.8 为 schema 20。直接沿旧基线覆盖安装有数据降级风险，因此先保存本任务提交，再仅把本任务 UI、预览、测试和记录移植到 v0.3.8 的冻结提交 `daa82d7e419a2740ac963d94a5ee7d680a574c7d`。这不整合或重写主工作区 main 的分歧历史。
- 原 UI 签名提交 `29b28c6` 通过本地 `refs/task-snapshots/mu-ui01/pre-release-port` 保留恢复点；移植后的签名 UI 提交为 `fe69d3d`。`git range-diff` 确认补丁等价，全部原 UI 文件与 v0.3.8 均无同文件上游差异。保留 schema 20、凭据、服务器、下载和稳定版反馈/歌词/WebDAV 契约；只读兼容性分析也确认这一方向。先前 58 项结果仅证明旧基线的组合态，发布前重新执行检查。
- prerelease 必须为 true、make_latest 为 false，仅允许 `release/preview.json` 单调推进；正式版 latest 与 `release/latest.json` 保持原有候选。
- 发布前本地检查：47 项发布工作流离线测试通过（任务内 Python 3.12 环境、PyYAML 6.0.2），`source-version` 解析为 numeric version `0.3.9`、build `1793850934`、prerelease=true、draft=false；`git diff --check` 通过，10 个 UI/test 文件仍与既有指纹完全一致。证据在 `build/mu-ui01-release/`。
- 本机 Flutter 3.41.3 的 SDK 固定依赖与 v0.3.8 的锁文件不一致，`pub get --enforce-lockfile` 明确拒绝改写 7 个依赖。锁文件保持发布基线原值，不为本机降级依赖。当前完整代码验证和打包使用项目既有 GitHub CI 与 Release workflow 的 stable SDK；只有全部必要检查通过才认为发布完成。
- 发布源码冻结为签名提交 `0b8a528f7aac26419c1140c98df2ba585e56695b`，分支已推送；签名标签 `v0.3.9-glasmio.1` 对应标签对象 `4df3eb49af1f1a9e1b0dca2bd90b00d5a2af4f85`，解引用提交与冻结源码一致，已验证本地 GPG 签名和远端引用。
- 候选 [CI 41965238107](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41965238107) 四项作业全部通过：Flutter 3.47.9 stable，根目录和协议库分析无问题，应用 416 项及协议库 11 项测试通过，macOS/Linux 各 47 项发布工作流检查通过。日志与 API 快照为 `build/mu-ui01-release/{ci-run.json,ci-full.log,ci-summary.txt}`。
- `git diff --exit-code v0.3.8 v0.3.9-glasmio.1 -- lib/data lib/audio lib/main.dart lib/app.dart pubspec.lock android ios macos windows` 通过，确认发布相对 v0.3.8 没有改动数据、音频、启动入口、锁文件和平台签名/应用标识配置。初始原生截图仍对应同一份 UI 补丁，但 SDK 为 3.41.3，不作为最终公开安装包已经实机验收的证据。
- [Release 41965619505](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41965619505) 的 8 个作业全部通过，按同一 SHA 构建并发布 Android、Windows、macOS、iOS；发布流程内分析和完整应用测试也通过。版本身份、原始快照与正式清单哈希见 `build/mu-ui01-release/frozen-release.json`，作业与日志为 `release-run.json`、`release-full.log`。
- 标签 [CI 41965619452](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41965619452) 首轮为 415 项通过、1 项失败：既有 `webdav_client_test.dart` A1 的服务端写入计数达到 8MiB，512KiB 返回值上限断言仍通过；同一源码的分支 CI 和 Release 测试均完整通过。该测试和 WebDAV 实现与 v0.3.8 无差异，服务端计数发生在 `add/flush` 返回后，并不等于客户端实际接收量，存在传输观测与调度敏感性；具体触发机制尚未确认。仅对失败 Test 作业重跑一次，第 2 次完整通过。未为重跑改源码、断言或门禁，不宣称已修复该既有非确定性；首次失败与重跑证据保留在 `tag-ci-{failed,rerun}.log`、`tag-ci-final-api.json`。全部冻结源码的 CI/Release 当前均为 success，见 `all-source-runs.json`。
- 9 个公开资产已下载并逐个核对大小与 GitHub SHA-256：4 个 Android APK、Windows ZIP、macOS ZIP/DMG、iOS unsigned IPA/Runner.app ZIP。首次 GitHub API 下载有一个 iOS 资源发生 EOF，其余 8 个文件完整；用公开下载地址补取该资源后，9 个全部通过校验，没有替换或重传已发布资产。
- 四种新 APK 的应用 ID 均为 `com.sakuramusic.app`，平台数字版本均为 `0.3.9`，实际 code 分别为 universal `1793850934`、armeabi-v7a `1793851934`、arm64-v8a `1793852934`、x86_64 `1793854934`。全部 APK 签名证书 SHA-256 与实际下载的正式 v0.3.8 arm64 APK 一致：`b2bb4810ec0074fe6e2341689fde03755f5be7567d779d2cce9d9318d0fc7a8d`。macOS ZIP 和两个 iOS 包的 Info.plist 同样确认正式应用 ID、数字版本 `0.3.9` 与构建号 `1793850934`；预发布身份由 tag 与 prerelease 标志表达，符合既有更新契约。
- GitHub Release 已确认 prerelease=true、draft=false，远端标签仍解引用至冻结 SHA，发布说明与源码中的说明文件一致。`release/preview.json` 已推进，应用实际主源 `https://raw.githubusercontent.com/SakuraLoveSmile/Sakura-Music/main/release/preview.json` 也读取到新 tag 和构建号；GitHub latest 仍为 v0.3.8，正式清单与发布前逐字节一致。综合结果为 `build/mu-ui01-release/verification-result.json`，另存 `release-api.json`、`preview-after.json`、`latest-after.json`、`public-preview.json`。
- 收尾提交只更新本任务记录，采用仓库已有 `[skip ci]` 约定，避免对纯发布证据重复执行代码 CI；冻结标签的源码检查已全部完成，未更改测试或工作流门禁。分支与标签已推送，没有合入 UI 到正式主线、没有移动标签，也没有覆盖安装到本机或设备。
- 发布工作已完成，仍待用户体验与 Android 实机性能、真实音频、系统媒体控件核验；iOS 资产未签名。工作树保留在本文件顶部的路径，供本次实验反馈和后续调整；尚未合入，因此不清理该活跃实验工作树，后续合入且验证后依既有规则收尾。
