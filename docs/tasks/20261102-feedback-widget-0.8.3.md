# feedback-20261102d：升级 feedback 组件至 0.8.3 并发布 v0.3.6 正式版

- 项目 / 任务编号：personal-music / feedback-20261102d
- 状态：实现中
- 创建日期（Asia/Taipei）：2026-11-02
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（c27d64b）/ `feat/20261102-feedback-widget-0.8.3` → 合入 `main`
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261102-feat-feedback-widget-0.8.3`
- 当前 HEAD / 未提交差异：工作树未提交（ref a1f1949，应用版本 0.3.6+1793626126）

## 目标与范围

1. 把内嵌的 `feedback_widget` 从 0.8.1（`620c82c`）升级到上游最新正式标签 `v0.8.3`
   （提交 `a1f1949`）：0.8.2 带来「我的反馈」一键已读、灵感球第三种待机样式「隐藏」、
   四种状态固定配色、移除入口未读数字角标；0.8.3 只改 Web 截图（保留页面样式、失败保护
   草稿）并统一版本号，Flutter 组件行为与 0.8.2 相同。
2. 发布**正式版** `v0.3.6`：上一版为测试渠道 `0.3.6-beta.1`；正式版把反馈组件体验带给
   正式版渠道，`latest.json` 与 `preview.json` 同步推进到 0.3.6。
3. 用户向更新日志（GitHub Release 与应用内更新弹窗读同一份 body）。

覆盖：依赖 `ref`、lockfile、Windows 发布构建的 vendoring SHA、应用版本号与构建号、
用户向更新日志、任务记录与发布核验。不覆盖：Feedback 服务端升级/部署（生产服务端已是
0.8.2，0.8.3 为 Web-only，本次不部署）、宿主代码改动、真实账号 E2E。

## 已确认决定

- 上游最新正式版是 `v0.8.3`（2026-11-02T12:53Z 发布，非预发布；标签对象指向提交
  `a1f1949a6378e62d8991a66755a100c2aa54548e`），与 Release `SOURCE.txt` 的
  `commit=` 和 `release-manifest.json` 的 `version=0.8.3` 一致。上游 `main`（10f42db）
  仍是 0.7.1 的发布记录，0.8.x 都发布在各自分支标签上，不能以 main 为准。
- 0.8.1 → 0.8.3 的宿主公共接口只有兼容新增（导出 `MarkAllReadResult`、
  `ApiClient.markAllRead`、状态色板与 `FeedbackOrbIdleStyle.hidden`）；现有
  `FeedbackOverlay` / `FeedbackConfig` / `FeedbackController` 用法无需改动，包依赖未新增。
- 应用版本取 `0.3.6`（正式版），构建号 `1793626126`（2026-11-02 时间戳，严格大于测试版
  `0.3.6-beta.1+1793614825`，且小于 Android versionCode 上限）；正式版清单的版本比较为
  0.3.6 > 0.3.5，测试版用户按同数字版本比较构建号升级。
- 「一键已读」依赖反馈服务端 0.8.2 及以上；生产服务端已于 0.8.2 部署（未登录
  `POST /api/feedback/read-all` 返回 `401 unauthorized`、其他不存在的端点返回 404，
  确认路由存在）。0.8.3 的 Web 截图修复不影响本客户端。
- 本机 Flutter 3.41.3 / Dart 3.11.1 低于生成现有 lock 的工具链，`pub get` 会顺带下调
  7 个 SDK 内置包；无关 lock 行已还原为基线值，只保留 `feedback_widget` 的 ref/版本变化。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 组件升级到 0.8.3 | 解析到 0.8.3（ref = a1f1949）；`flutter analyze` 无问题；现有反馈测试与全量测试通过；macOS 构建产物版本、着色器与新组件文案正确 | 解析 0.8.3；analyze、404 项单测、47 项发布脚本测试、macOS debug 构建（0.3.6 / 1793626126，含 orb_lens 着色器与「一键已读」文案）均通过 | 已完成 |
| T2 | 发布 v0.3.6 正式版 | 标签触发发布；Release 非预发布、9 资产；`latest.json`/`preview.json` 推进到 0.3.6；Release body 为用户向日志 | 待发布 | 未开始 |
| T3 | 新反馈体验随包生效 | 正式版渠道看到 v0.3.6；「我的反馈」有一键已读、状态颜色；反馈面板「设置」→「灵感球」可隐藏入口；入口无数字角标 | 尚未在真实安装包上验证 | 未开始 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-11-02 | 工作树未提交（ref a1f1949） | macOS arm64，Flutter 3.41.3 / Dart 3.11.1 | `flutter pub get` | 解析 `feedback_widget 0.8.3`（`~/.pub-cache/git/Sakura-Feedback-a1f1949…/flutter/feedback`）；同时下调 7 个 SDK 内置包，已还原为基线 lock 内容 |
| 2026-11-02 | 同上 | 同上 | `flutter analyze` | `No issues found!`（6.9s） |
| 2026-11-02 | 同上 | 同上 | `flutter test` | 404 项全部通过 |
| 2026-11-02 | 同上 | 同上 | `python3 -m unittest discover -s .github/scripts/tests -v` | 47 项通过（Python 3.10.10 / PyYAML 6.0.2） |
| 2026-11-02 | 同上 | macOS arm64 debug | `flutter build macos --debug --build-name 0.3.6 --build-number 1793626126` | 构建成功；Info.plist `CFBundleShortVersionString=0.3.6`、`CFBundleVersion=1793626126`；产物含 `feedback_widget/shaders/orb_lens.frag`；kernel_blob 含 0.8.2 独有文案「一键已读」「已全部标记为已读」 |
| 2026-11-02 | 生产反馈服务 | `https://feedback.xn--fhqths51enha.cn` | 未登录探测 `POST /api/feedback/read-all` | `401 unauthorized`（路由存在，服务端 ≥0.8.2） |
| — | — | — | 真实账号 E2E / 真机安装升级 | 未运行：需账号与真实安装包 |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| 待定 | 组件 0.8.1 → 0.8.3；应用版本 0.3.6-beta.1 → 0.3.6；用户向更新日志 | 本机分析 + 404 项单测 + 47 项发布脚本测试 + macOS 构建核验 | 待推送/PR |
| 待定 | closeout：补记 v0.3.6 发布证据与状态 | 文档核对 | 随 PR 合入 main |

## 交付与恢复

- 体验入口和操作步骤：安装 v0.3.6 正式包（或应用内 设置 → 关于 → 检查更新）→
  「我的反馈」一键已读、状态颜色；反馈面板「设置」→「灵感球」可选「隐藏」。
- 尚未完成 / 尚未验证：真实安装包升级路径与面板内新能力的点击体验；Android/iOS/
  Windows 本机安装（发布流水线已构建）；真实服务端 E2E。
- 用户确认（明确确认后才改为已验收）：待体验。
- 下一步：安装 v0.3.6 体验反馈面板新能力，确认后可改为已验收。
- 回退方式：还原 `pubspec.yaml` ref/版本、`pubspec.lock` 的 feedback 块、
  `release-build.yml` vendoring SHA，删除 `release/notes/v0.3.6.md` 即可回到
  0.8.1/0.3.6-beta.1；已发布对象不回改。
- 本任务 worktree 收尾：待发布与 closeout 合入后检查清理。
