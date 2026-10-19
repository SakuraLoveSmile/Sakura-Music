# 更新渠道契约（2026-10-19）

状态：实现中（代码及本地功能核验已完成，Android 打包受环境阻塞，远端构建发布未开始）。目标：设置中选择正式版或测试版，保存后重新检查；连续测试构建按实际版本号与构建号更新，切回正式版不自动降级。本轮在独立 `codex/update-channels-20261019` 工作树实现、验证，远端发布需另行取得本次变更的授权。

## T1 客户端读取与比较

- `UpdateChannel.stable|prerelease` 定义在 `lib/core/update/update_models.dart`，持久化值取 `.name`，默认 stable。显示“正式版”“测试版”，测试版包含正式版本。旧设置迁移默认 stable，不改变其他设置、服务器、播放或下载数据。
- 正式版读取 `release/latest.json`；测试版读取 `release/preview.json`，并核对 `latest.json` 的正式版本，选择符合当前平台、可升级的最新候选。主源使用同仓库 main 的 raw.githubusercontent.com 文件，原 jsDelivr/fastly 镜像保留为各自同路径的失败回退；不能让测试版查询回退为只查 GitHub releases/latest 后误报无更新。
- 新清单兼容原 GitHub release JSON 形状，补充 `version`（真实构建的数字 X.Y.Z）、`build_number`（正整数 <=2147483647）、`prerelease` 和 `draft=false`。保留 tag_name/html_url/body/published_at/assets；资产仍包含 name/size/digest/browser_download_url。旧正式版清单缺新字段时保持原版本比较兼容，不能伪造构建号。
- `AppRelease` 保留现有构造/显示兼容，新增可选 `buildNumber` 与默认 false 的 `isPrerelease`；新字段从清单解析，数字版本用于比较，tag 继续用于展示。版本号优先、同数字版本再比较构建号；当前 PackageInfo 的 buildNumber 必须参与比较。同版本不重复提示，切渠道不提供降级。Android 按实际选中的 APK 计算候选 versionCode：universal=build_number，armeabi-v7a=build_number+1000，arm64-v8a=build_number+2000，x86_64=build_number+4000（沿现有 Flutter ABI_VERSION）；与本机 PackageInfo 实际 code 比较，不猜本机包的基础构建号。同版本递增判断和跨版本覆盖安装下限都用实际 code，不推送无法覆盖或越界的候选。
- `UpdateService.checkForUpdate({UpdateChannel channel=UpdateChannel.stable, String? platform, String? androidAbi})`；controller 传实际平台/ABI，服务保留无 platform 的既有测试兼容。Android/Windows/macOS 排除没有匹配且可校验安装包的候选；其他平台沿用手动发布页能力，不把 unsigned iOS 当可自动安装包。
- 完整性校验、取消/重试和平台安装流程沿用。未知/损坏清单、请求失败不能冒充“已是最新”；服务失败有明确反馈，镜像不会跨渠道。

## T2 保存与界面

- `lib/core/update/update_channel.dart` 提供 `updateChannelProvider`，类型 `AsyncNotifierProvider<UpdateChannelController,UpdateChannel>`；controller 的 `Future<void> setChannel(UpdateChannel)` 等待持久化成功后更新已选项，失败保留旧值并抛出错误。数据库 schema 16→17，保留既有 V16 webDavPaths 迁移，仅追加 settings.update_channel 默认 stable；采用 from>=4 && from<17 条件避免旧库重复加列，并覆盖 V15→17 与 V16→17 保留数据；生成文件通过现有 build_runner 生成。
- `UpdateController.setChannel(UpdateChannel)` 负责保存、清除旧查询/旧下载候选和重新检查。检查等待偏好加载，渠道改变/组件销毁后旧异步结果不覆盖新渠道；下载及安装期间禁止切换，检查期间可改渠道，保存/加载期间界面禁用选择。
- 设置“关于”卡片在“当前版本”后、“检查更新”前加入一行“更新渠道”，复用该卡片 action tile 和现有语言选择 AlertDialog 的字号、颜色、间距、勾选样式。选项各一行说明：正式版“仅接收稳定版本”；测试版“接收正式版和测试版本”。不改其他分区、全局样式、组件库。
- 中英文同步；提示保存失败，切换成功后沿用检查更新反馈。更新弹窗能区分正式/测试版本。最小手机宽度核验长 tag、说明、加载/失败状态及已有下载/取消流程。

## T3 发布端清单

- Pilot 发布成功后生成含实际 numeric version/build_number 与资产指纹的候选清单；稳定版同时推进 latest.json 和 preview.json，预发布只推进 preview.json。
- 原标签发布也生成对应清单。其构建号来自同一源码的 pubspec（共享构建未传覆盖时的实际值），不得把本次运行时间或 GitHub run id 冒充已发布安装包的构建号；标签、源码和实际保留包身份不符时停止，不能覆盖已发布包。构建开始冻结 target_sha，发布前与生成渠道候选前分别核对远端 tag 解引用后的提交仍等于冻结 SHA；标签被移动或删除就停止。
- 两个清单分别按版本与构建号单调推进。preview 是正式/测试版本共同的最新候选；较低版本不能覆盖较高版本；同 tag/构建号但包身份不符明确受阻。维持现有 git 乐观 CAS、重新读取再比较的策略，拒绝覆盖并发的新版本。预发布保持 make_latest=false，不改变 GitHub 稳定 latest 或 release/latest.json。
- 来源不完整时停止，不新增模型调用、无界重试或生产写；所有远端修改、Actions 与 Release 的本次真实运行留到主控完成审查后确认。本轮不对过去已发布包改标签/补写猜测元数据。

## 分工与验收

- 主控唯一维护本文件、pubspec 版本、集成及最终实机效果；使用隔离内存库预览，不改真实手机安装或偏好。验收日志保存在 build/update-channels/。本次准备 0.3.2+1792423078，让仍按数字版本检查的旧 0.3.1 预览包也能发现首次升级；构建号为本次新包明确分配的值，不用于追补历史包。
- 客户端 worker 独占 update_models.dart/update_service.dart/update_providers.dart 与其服务/控制器测试。接口按 T1/T2；不改数据库/UI/工作流，不派生。
- 设置 worker 独占 update_channel.dart、settings_repository、DB 定义/迁移/生成物、settings_screen/update_dialog、l10n 及对应迁移/偏好/UI 测试；不改服务/控制器/工作流，不派生。生成器由其单独运行，通知其他人生成期。
- 发布 worker 独占 .github 工作流、发布脚本和相关 Python 测试，按 T3；不改 Dart/本契约，不派生。不能启动远端工作流或发布。
- 共享接口冻结后三者并行；主控集成、运行适用分析/检查、真实原生窄窗核验，再准备具体可审查的远端发布材料。必要时独立 reviewer 只读检查实际变更。旧正式更新、测试构建连续更新、保存/重启/迁移、切回不降级、跨渠道网络失败、取消/切换竞争及两路清单并发/不回退是必要验证。

## 本次实现与证据

- T1：客户端已实现；根目录 `flutter analyze --no-pub` 无问题，`flutter test --no-pub --reporter expanded` 344 项通过，包含真实 localhost 下载竞争、取消及完整性校验。另按现有 CI 要求，`packages/subsonic_api` 分析无问题、11 项测试通过。日志为 `build/update-channels/{analyze-final,tests-final,subsonic-analyze,subsonic-tests}.log`。
- T2：schema 17 迁移、偏好与中英文界面已实现。主控在独立 macOS 原生预览中以 390 逻辑像素核验默认正式版、切换重查、长标签换行、正式渠道不降级、保存失败保留旧值、网络失败提示、取消下载与英文选项。预览复用真实设置页/更新组件，使用内存 SQLite 和 localhost 清单，模拟旧包 `0.3.1+1792417384`；不代表真实手机安装验收。原生截图及事件核对见 `build/update-channels/ui-final-*.png`、`ui-verification.json`；无 Flutter/未捕获错误，取消后无残留安装文件。320 像素中英文控件测试也已通过。
- T3：两个发布入口和清单推进已实现。主控独立运行 40 项发布离线测试，包含真实本地 bare Git 仓库的竞争与重读；日志为 `build/update-channels/release-independent-check.log`。独立只读审查发现的标签移动检查与下载收尾问题均先复现、修复、复核关闭。远端标签读校验仍不是服务端 CAS，不声称消除最终读取之后的远端竞争。
- 本次只读核对：手机为 `0.3.0+26`，GitHub latest 仍为正式版 `v0.3.0`。手机安装与偏好未改；原 Music 主工作树和 KaneoPilot 的既有改动保留。
- Android 本地 APK 构建未通过：直接下载等待在 TLS 握手；使用既有本机代理的第二次尝试明确报 `com.android.tools.build:gradle:8.11.0` 的 Google Maven TLS 握手失败，已停止自动重试。日志为 `build/update-channels/android-build{,-direct}.log`，没有可供手机安装验收的 APK。Flutter 被中断后返回 0 不能视为构建成功，状态以失败日志及产物缺失为准。
- 下一步仅为尚未授权的外部操作：推送本分支、创建并合并 PR，通过标签发布入口构建/发布 `v0.3.2` 正式版，核对九个平台资产、真实包身份及两个渠道清单。该步骤会写 GitHub 并使用 Actions 配额；本次实现阶段未执行。成功后旧版手机先升级一次，再在“设置 → 关于 → 更新渠道”选择测试版。
