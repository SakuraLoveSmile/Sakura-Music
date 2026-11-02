# feedback-20261102b：升级 feedback 组件至 0.8.0 并发布 v0.3.5

- 项目 / 任务编号：personal-music / feedback-20261102b
- 状态：待体验
- 创建日期（Asia/Taipei）：2026-11-02
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（c1b6f2f）/ `feat/20261102-feedback-widget-0.8.0` → 合入 `main`（`e548504`）
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261102-feat-feedback-widget-0.8.0`
- 当前 HEAD / 未提交差异：实现提交 `ac0adea` 已随 PR #19 合入 `main`（合并提交 `e548504`），渠道清单提交 `e8b08e1`；本 closeout 只更新本记录

## 目标与范围

把 Music 内嵌的 `feedback_widget` 从 0.7.0（`49470c8`）升级到 Sakura-Feedback 最新正式发布
0.8.0（标签 `v0.8.0`，提交 `693e693`），并随应用发布 0.3.5 正式版。

0.8.0 的组件侧变化：`FeedbackConfig.apiBase` 在构造时把中文等国际化域名（IDN）按 IDNA
转为 ASCII/punycode（此前 Dart 的 `Uri` 会百分号编码成无法解析的主机名）；深色模式待机
状态的通透玻璃与小把手尺寸调整（深色小把手 10×48、距安全边 10）；面板内服务器地址留空
保存按“保持当前地址”处理。其余新增（Kaneo 完成状态回读、管理端工作台）在服务端/管理端，
不改宿主接口。

覆盖：依赖 `ref` 与 lockfile、Windows 发布构建的 vendoring SHA、应用版本号
0.3.4 → 0.3.5 及 `v0.3.5` 正式发布。不覆盖：Feedback 服务端升级/部署（0.8.0 服务端
schema 仍为 14，无迁移）、真实账号 E2E、上游仓库改动。

## 已确认决定

- 上游最新正式版为 `v0.8.0`（发布于 2026-11-02T09:16Z；`v0.7.1` 同日发布已被覆盖）。
  固定标签对应提交 `693e693d7462c0f748e6bdfef1aa7f9dac29acda`；该提交与 Release 的
  `SOURCE.txt`（`commit=`）和 `release-manifest.json`（`version=0.8.0`）一致。
  上游 `main`（10f42db）不领先于该标签（本次发布从 `feat/20261102-fb-20261102-kaneo-sync`
  切出），因此不能以 main 为准。
- 宿主稳定 API 未变：0.7.0 → 0.8.0 的公共 barrel 完全一致，`FeedbackConfig` /
  `FeedbackController` / `api_client` 无签名变化，包依赖未新增；宿主现有
  `FeedbackOverlay`（orb、视口截图、深色主题、显示开关）无需改动。
- 发布 0.3.5：构建号取 2026-11-02 时间戳 `1793611631`（严格大于已发布的
  `0.3.4+1793600077`，Android 各 ABI versionCode 均在上限内）；发布入口为推送标签
  `v0.3.5` 触发 `release.yml`（标签/source 版本一致性由发布脚本强制校验）。
- 本机 Flutter 3.41.3 / Dart 3.11.1 低于生成现有 lock 的工具链（记录为 3.47.7 /
  3.13.5），`pub get` 会顺带下调 SDK 内置包；这些与本任务无关的 lock 行已还原为基线值，
  只保留 `feedback_widget` 的 ref/版本变化。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 组件升级到 0.8.0 | 解析到 0.8.0（ref = 693e693）；`flutter analyze` 无问题；现有反馈测试与全量测试通过；macOS 构建产物版本与着色器正确 | lock/package_config 解析 0.8.0；analyze、404 项单测、macOS debug 构建（0.3.5 / 1793611631、含 orb_lens 着色器）均通过 | 已完成 |
| T2 | 发布 v0.3.5 正式版 | 标签触发发布工作流；九类平台资产生成；`latest.json`/`preview.json` 推进到 0.3.5 | [Release v0.3.5](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.5) 已发布（9 个资产、非草稿、非预发布，2026-11-02T09:46:35Z）；两渠道清单推进到 `v0.3.5+1793611631`（`e8b08e1`）；标签 GitHub 验证 `verified=true` | 已完成 |
| T3 | 新交互随包生效 | 深色待机灵感球观感、中文域名服务器地址可用 | 尚未在原生窗口手动操作体验 | 未开始 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-11-02 | 工作树未提交（ref 693e693） | macOS arm64，Flutter 3.41.3 / Dart 3.11.1 | `flutter pub get` | 解析 `feedback_widget 0.8.0`（`~/.pub-cache/git/Sakura-Feedback-693e693…/flutter/feedback/pubspec.yaml` 的 `version: 0.8.0`）；同时下调 7 个 SDK 内置包，已还原为基线 lock 内容 |
| 2026-11-02 | 同上 | 同上 | `flutter analyze` | `No issues found!`（7.7s） |
| 2026-11-02 | 同上 | 同上 | `flutter test test/feedback_integration_test.dart test/feedback_launcher_migration_test.dart` | 26 项通过 |
| 2026-11-02 | 同上 | 同上 | `flutter test` | 404 项全部通过 |
| 2026-11-02 | 同上 | macOS arm64 debug | `flutter build macos --debug` | `✓ Built build/macos/Build/Products/Debug/SakuraMusic.app`；Info.plist `CFBundleShortVersionString=0.3.5`、`CFBundleVersion=1793611631`；产物含 `flutter_assets/packages/feedback_widget/shaders/orb_lens.frag` |
| — | — | — | 真实服务端 E2E（`integration_test/feedback_e2e_test.dart`） | 未运行：需可达服务端 + submitter/admin 账号 dart-define |
| 2026-11-02 | `ac0adea`（PR #19） | GitHub Actions（ubuntu / macOS） | 推送分支与 PR CI：[41421304748](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41421304748)、[41421313065](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41421313065) | Analyze / Test / Release workflow checks 全部通过；PR #19 以合并提交 `e548504` 合入 `main` |
| 2026-11-02 | `e548504`（v0.3.5） | GitHub Actions（ubuntu / macOS / windows） | 推送签名标签 `v0.3.5`，运行 [41421707946](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41421707946)；标签 CI [41421707864](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41421707864)；main CI [41421635736](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41421635736) | 发布工作流全部作业成功（Validate / Test / Android / iOS / macOS / Windows / Publish）；Release 已发布，9 资产；标签对象 `731cfdb` 解析到 `e548504`，GitHub 验证通过 |
| 2026-11-02 | v0.3.5 清单 | GitHub main（`e8b08e1`） | 核对 `release/latest.json`、`release/preview.json` 与 Release 资产 | 两清单 tag/version/build 一致（`v0.3.5` / `0.3.5` / `1793611631`），9 个资产 URL 指向 v0.3.5；清单由发布流水线自动提交 |
| 2026-11-02 | v0.3.5 发布包 | 下载 `SakuraMusic-macos.zip` 核对 | 解包检查 Info.plist、着色器与 AOT 快照 | `CFBundleShortVersionString=0.3.5`、`CFBundleVersion=1793611631`；含 `packages/feedback_widget/shaders/orb_lens.frag`；AOT 含 0.8.0 独有文案“未填写服务器地址，保持当前服务器不变”（说明发布包确实带 0.8.0 组件） |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| ac0adea | 组件 0.7.0 → 0.8.0：`pubspec.yaml` ref、lock 解析版本、Windows 发布 vendoring SHA；应用版本 0.3.4 → 0.3.5 | 本机分析 + 404 项单测 + macOS debug 构建；PR CI 全绿 | PR #19 合入 main（`e548504`）；标签 `v0.3.5`；Release 已发布；清单推进（`e8b08e1`） |
| 待定 | closeout：补记 v0.3.5 发布证据与状态 | 文档核对 | 随 PR 合入 main |

## 交付与恢复

- 体验入口和操作步骤：安装 [v0.3.5 正式包](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.5)（或在应用内“设置 → 关于 → 检查更新”）
  → 右侧灵感球深色待机观感（完整球/贴边半球/小把手）；面板“服务器设置”可输入中文域名。
- 尚未完成 / 尚未验证：原生窗口内的真实点击/拖动体验；中文域名在实际网络下的连通性
  （需真实服务器）；真实服务端 E2E（需账号）；Android/iOS/Windows 本机运行（由发布流水线覆盖）。
- 用户确认（明确确认后才改为已验收）：待体验。
- 下一步：从 v0.3.5 正式包或更新渠道体验深色待机灵感球与中文域名地址，确认后改为已验收。
- 回退方式：还原 `pubspec.yaml` ref、`pubspec.lock` 的 feedback 块与
  `release-build.yml` 的 vendoring SHA，重新 `flutter pub get` 即可回到 0.7.0；
  已发布的 `v0.3.5` 不回改，旧版用户可继续使用 v0.3.4。
- 本任务 worktree 收尾：已检查并清理（实现与 closeout 均已合入 main，无独有成果）。
