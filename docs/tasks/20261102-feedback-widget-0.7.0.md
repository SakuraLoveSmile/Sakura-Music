# feedback-20261102：升级 feedback 组件至 0.7.0

- 项目 / 任务编号：personal-music / feedback-20261102
- 状态：待体验
- 创建日期（Asia/Taipei）：2026-11-02
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（9fd4ec9）/ `feat/20261102-feedback-widget-0.7.0` → 合入 `main`（`d3643ca`）
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261102-feat-feedback-widget-0.7.0`
- 当前 HEAD / 未提交差异：实现提交 `2c44921` 已随 PR #17 合入 `main`（合并提交 `d3643ca`），渠道清单提交 `b54c0d7`；本 closeout 只更新本记录

## 目标与范围

把 Music 内嵌的 `feedback_widget` 从 0.6.0（`404f7cf`）升级到 Sakura-Feedback 最新发布
0.7.0（标签 `v0.7.0`，提交 `49470c8`）。0.7.0 将三端灵感球统一为液态体验
（透明柔光待机、闲置 5 秒收为小把手/贴边球、拖拽松手以球心生成局部选区并截图、
真实放大透镜）、并带来会话式问题追踪（“我的反馈”状态/未读/对话续写）、
多图与图片编辑（裁剪/标注/遮挡，至多 5 张）、可选唤醒手势（双指长按/三指上滑/
双指双击，默认关闭）。

覆盖：依赖 `ref` 与 lockfile、Windows 发布构建的 vendoring SHA、应用版本号
0.3.3 → 0.3.4 及 `v0.3.4` 正式发布。不覆盖：Feedback 服务端升级/部署
（0.7.0 服务端 schema 14）、真实账号 E2E、组件自身仓库。

## 已确认决定

- 宿主稳定 API 未变：0.6.0 → 0.7.0 的公共 barrel 完全一致，`FeedbackConfig` /
  `FeedbackController` / `api_client` 零 diff；新增的 `unreadCount`、`imagePicker`
  等均为可选。宿主现有的 `FeedbackOverlay`（orb、视口截图、深色主题、显示开关）
  无需改动，已验证 `flutter analyze` 无问题。
- 固定标签 `v0.7.0` 对应提交 `49470c8d8c635046161b1e51bc3dfb5ed7190b65`，不用分支名；
  `main` 在标签之后只有文档提交，`flutter/` 内容与标签一致。
- 发布 0.3.4：构建号取 2026-11-02 时间戳 `1793600077`（严格大于已发布的
  `0.3.3+1793213802`，且 Android 各 ABI versionCode 均在上限内）；发布入口为
  推送标签 `v0.3.4` 触发 `release.yml`（标签/source 版本一致性由发布脚本强制校验）。
- 本机 Flutter 3.41.3 / Dart 3.11.1 低于生成现有 lock 的工具链（记录为 3.47.7 /
  3.13.5），`pub get` 会顺带下调 SDK 内置包（`test` / `test_api` / `test_core` /
  `intl` / `meta` / `matcher` / `vector_math`）。这些与本任务无关的 lock 行已还原为
  基线值，只保留 `feedback_widget` 的 ref/版本变化，避免把本机工具链差异写进仓库。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 组件升级到 0.7.0 | 解析到 0.7.0（ref = 49470c8）；`flutter analyze` 无问题；现有反馈测试与全量测试通过；macOS 构建把新着色器打进产物 | lock/package_config 解析 0.7.0；analyze、404 项单测、macOS debug 构建均通过（见执行记录） | 已完成 |
| T2 | 发布 v0.3.4 正式版 | 标签触发发布工作流；九类平台资产生成；`latest.json`/`preview.json` 推进到 0.3.4 | [Release v0.3.4](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.4) 已发布（9 个资产、非草稿、非预发布，2026-11-02T06:35:13Z）；两渠道清单推进到 `v0.3.4+1793600077`（`b54c0d7`）；标签 GitHub 验证 `verified=true` | 已完成 |
| T3 | 新交互随包生效 | 液态灵感球、局部选区截图、多图编辑、会话式追踪在应用内可用且顺畅 | 尚未在原生窗口手动操作体验 | 未开始 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-11-02 | 工作树未提交（ref 49470c8） | macOS arm64，Flutter 3.41.3 / Dart 3.11.1 | `flutter pub get` | 解析 `feedback_widget 0.7.0`（`~/.pub-cache/git/Sakura-Feedback-49470c8…/flutter/feedback/pubspec.yaml` 的 `version: 0.7.0`）；同时下调 7 个 SDK 内置包，已还原为基线 lock 内容 |
| 2026-11-02 | 同上 | 同上 | `flutter analyze` | `No issues found!`（6.4s） |
| 2026-11-02 | 同上 | 同上 | `flutter test test/feedback_integration_test.dart test/feedback_launcher_migration_test.dart` | 26 项通过 |
| 2026-11-02 | 同上 | 同上 | `flutter test` | 404 项全部通过 |
| 2026-11-02 | 同上 | macOS arm64 debug | `flutter build macos --debug` | `✓ Built build/macos/Build/Products/Debug/SakuraMusic.app`；产物含 `flutter_assets/packages/feedback_widget/shaders/orb_lens.frag`，`AssetManifest.bin` 有对应条目（新液态透镜着色器已被打包） |
| — | — | — | 真实服务端 E2E（`integration_test/feedback_e2e_test.dart`） | 未运行：需可达服务端 + submitter/admin 账号 dart-define；0.7.0 服务端为 schema 14，生产服务是否已升级需另行确认 |
| 2026-11-02 | `2c44921`（PR #17） | GitHub Actions（ubuntu / macOS） | 推送分支与 PR CI：[41399162743](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41399162743)、[41399199752](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41399199752) | Analyze / Test / Release workflow checks 全部通过；PR #17 以合并提交 `d3643ca` 合入 `main` |
| 2026-11-02 | `d3643ca`（v0.3.4） | GitHub Actions（ubuntu / macOS / windows） | 推送签名标签 `v0.3.4`，运行 [41399651149](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41399651149)；标签 CI [41399651196](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41399651196)；main CI [41399527942](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41399527942) | 发布工作流全部作业成功（Validate / Test / Android / iOS / macOS / Windows / Publish）；Release 已发布，9 资产；标签对象 `5ce11be` 解析到 `d3643ca`，GitHub 验证通过 |
| 2026-11-02 | v0.3.4 清单 | GitHub main（`b54c0d7`） | 核对 `release/latest.json`、`release/preview.json` 与 Release 资产 | 两清单 tag/version/build 一致（`v0.3.4` / `0.3.4` / `1793600077`），9 个资产 URL 指向 v0.3.4；清单由发布流水线自动提交 |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| 2c44921 | 组件 0.6.0 → 0.7.0：`pubspec.yaml` ref、lock 解析版本、Windows 发布 vendoring SHA；应用版本 0.3.3 → 0.3.4 | 本机分析 + 404 项单测 + macOS debug 构建；PR CI 全绿 | PR #17 合入 main（`d3643ca`）；标签 `v0.3.4`；Release 已发布；清单推进（`b54c0d7`） |
| 待定 | closeout：补记 v0.3.4 发布证据与状态 | 文档核对 | 随 PR 合入 main |

## 交付与恢复

- 体验入口和操作步骤：安装 [v0.3.4 正式包](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.4)（或在应用内“设置 → 关于 → 检查更新”，正式/测试渠道均已指向 0.3.4）→ 右侧灵感球
  待机 5 秒后收为小把手/贴边球，拖动松手进入局部选区截图，面板内可多图编辑、登录后
  “我的反馈”查看会话；设置 → 关于 的反馈开关仍只隐藏悬浮球、保留“问题反馈”入口。
- 尚未完成 / 尚未验证：原生窗口内的真实点击/拖动/截图体验；真实服务端 E2E（需账号）；
  Android/iOS/Windows 本机运行（发布流水线已构建，未逐一安装）；0.7.0 服务端升级与
  生产服务兼容性（服务端未随本次发布升级，新交互会按能力协商降级）。
- 用户确认（明确确认后才改为已验收）：待体验。
- 下一步：从 v0.3.4 正式包或更新渠道体验新灵感球与反馈面板，确认后改为已验收。
- 回退方式：还原 `pubspec.yaml` ref、`pubspec.lock` 的 feedback 块与
  `release-build.yml` 的 vendoring SHA，重新 `flutter pub get` 即可回到 0.6.0；
  已发布的 `v0.3.4` 标签/Release 与清单不回改，旧版用户可继续使用 v0.3.3。
- 本任务 worktree 收尾：已检查并清理（实现与 closeout 均已合入 main，无独有成果）。
