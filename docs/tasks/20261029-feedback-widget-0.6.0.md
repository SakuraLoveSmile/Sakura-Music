# feedback-20261029：升级 feedback 组件至 0.6.0 并发布 v0.3.3

- 项目 / 任务编号：personal-music / feedback-20261029
- 状态：实现中
- 创建日期（Asia/Taipei）：2026-10-29
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（eae4b9f）/ `feat/20261029-feedback-widget-0.6.0` / `main`
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261029-feat-feedback-widget-0.6.0`

## 目标与范围

把 Music 内嵌的 `feedback_widget` 从 0.5.2（`60a9b22`）升级到 Sakura-Feedback 最新
`main`（`404f7cf`，0.6.0），随正式版 v0.3.3 发布。覆盖：依赖 ref 与 lockfile、
Windows 发布构建的 vendoring SHA、应用版本号。不覆盖：Feedback 服务端部署、
组件自身测试、需要真实账号的 E2E。

## 已确认决定

- 组件 0.6.0 对宿主稳定 API 保持兼容（`FeedbackConfig` / `FeedbackController` /
  `FeedbackWidget` 签名与默认值不变）；宿主已有的 orb、视口截图、深色主题、
  显示开关配置继续有效，新风控（拖拽局部选区、会话式面板、多图）由组件内部提供。
- 固定上游合并提交 `404f7cf05088f9d40f1a1a6e395e0db377f0a8c5`，不用分支名。
- 发布版本取 0.3.3，构建号取 2026-10-29 时间戳，严格大于已发布的
  0.3.2+1792423078 与测试版 0.3.3-pilot.1792941786。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 组件升级到 0.6.0 | 新版灵感球/会话式面板随包生效；`flutter analyze` 无问题；现有反馈测试通过 | 见下方执行记录 | 实现中 |
| T2 | 发布 v0.3.3 正式版 | 标签触发发布工作流；九类平台资产生成；`latest.json`/`preview.json` 推进到 0.3.3 | 未运行 | 未开始 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-10-29 | 工作树未提交（ref 404f7cf） | macOS arm64，Flutter 3.47.7 / Dart 3.13.5 | `flutter pub get`（一次性 HTTPS 重写） | 解析 feedback_widget 0.6.0；lock 同步 SDK 自带 test/intl 小版本 |
| 2026-10-29 | 同上 | 同上 | `flutter analyze` | No issues found |
| 2026-10-29 | 同上 | 同上 | `flutter test test/feedback_*` | 26 项通过 |
| 2026-10-29 | 同上 | 同上 | `flutter test` | 404 项通过 |
| 2026-10-29 | 同上 | macOS arm64 release + 生产 Feedback 地址 | `flutter build macos --release` 后启动，仅截取自研窗口 | 新 0.6.0 灵感球在窗口右侧渲染；未用合成键鼠点击，面板交互由组件/宿主 widget 测试覆盖 |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| 待定 | 升级 feedback 组件 0.5.2 → 0.6.0，版本 0.3.2 → 0.3.3 | 分析 + 全量单测 | 未提交 / 未发布 |

## 交付与恢复

- 体验入口和操作步骤：运行正式构建 → 右下角灵感球打开反馈面板（可在设置 → 关于隐藏球体，保留“问题反馈”入口）。
- 尚未完成 / 尚未验证：macOS 原生运行观感、真实服务端 E2E（需账号）、CI 多平台构建。
- 用户确认：待体验。
- 下一步：完成原生观感核验 → 推送并合入 main → 打 v0.3.3 标签发布。
- 回退方式：还原 `pubspec.yaml` ref 与版本号后重新构建；已发布包不回改标签。
- 本任务 worktree 收尾：待发布验证后清理。
