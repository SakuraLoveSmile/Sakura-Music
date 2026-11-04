# feedback-20261104a：升级 feedback 组件至 0.9.0 并发布 v0.3.8

- 项目 / 任务编号：personal-music / feedback-20261104a
- 状态：待体验
- 创建日期（Asia/Taipei）：2026-11-04
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（763c7f2）/ `feat/20261104-feedback-widget-0.9.0` → 合入 `main`
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261104-feat-feedback-widget-0.9.0`
- 当前 HEAD / 未提交差异：实现提交 `c623084` 与修订 `1c9cc47` 已随 PR #29 合入 `main`（合并提交 `daa82d7`），
  渠道清单提交 `47d41ea`；本 closeout 只更新本记录

## 目标与范围

1. 把内嵌的 `feedback_widget` 从 0.8.4（`b1a92cb`）升级到上游最新正式版 **v0.9.0**（提交
   `7201756`）：0.9.0 的 Flutter 包本身只改版本号，实际组件行为差异来自 0.8.5（「隐藏」语义
   修正）与 0.8.6（待机背景跟随当前画面）。
2. 按组件新语义更新宿主设置文案、注释与集成测试，避免应用内说明与组件面板内的同一份设置
   互相矛盾。
3. 发布**正式版** `v0.3.8`：走 `release.yml` 既有标签发布流水线，`latest.json` 与
   `preview.json` 同步推进，Release body 使用用户向更新日志。

覆盖：`pubspec.yaml` 组件 ref、`pubspec.lock`、Windows 发布构建的 vendoring SHA、中英文设置
文案与生成物、集成测试与注释、应用版本号与构建号、用户向更新日志、任务记录与发布核验。
不覆盖：Feedback 组件/服务端改动（0.9.0 已发布并部署，生产服务端已在 0.9.0）、宿主新增
「更新日志」展示能力（0.9.0 服务端能力的可选接入，本次未要求）、真实设备 E2E。

## 已确认决定

- 上游最新正式版是 `v0.9.0`（[Release](https://github.com/SakuraLoveSmile/Sakura-Feedback/releases/tag/v0.9.0)，
  2026-11-04 02:35:48 台北公开，非 draft、非 prerelease、Latest）；签名标签 `v0.9.0` 解引用到
  提交 `7201756d698f4f2e77154d02a2bac6d132acf24f`，该提交的 `flutter/feedback/pubspec.yaml`
  版本为 0.9.0。
- 0.9.0 的 Flutter 包相对 0.8.6 只改 `pubspec.yaml` 版本号（`a345ca6..7201756` 的
  `flutter/feedback` diff 仅 pubspec）；相对当前固定的 0.8.4，宿主公共导出符号 diff 为空，
  包依赖未新增。因此宿主代码无需适配 API，只需更新文案/注释/测试与版本固定。
- **采用上游 0.8.5 的「隐藏」语义**：`hidden` 只隐藏待机（收起）状态；完整球在初始、唤醒后、
  面板关闭后仍显示，闲置 5 秒后进入待机隐藏；已开启的唤醒手势仍可唤醒完整球。该语义与原
  0.3.7 的宿主文案（「隐藏」完全不显示入口、手势不触发）不同，本次同步修改宿主文案与更新
  日志。理由：组件面板内的「设置 → 灵感球」展示同一份宿主设置，其文案已按新语义描述；
  若宿主继续用 `showLauncher: false` 完全隐藏，会与面板内文案和手势能力矛盾。
- 应用版本取 **0.3.8**，构建号 `1793783648`（2026-11-04 时间戳，严格大于
  `0.3.7+1793638899`，且在 Android 各 ABI versionCode 上限内）。
- 复用 `v0.3.6` 起建立的用户向更新日志机制：`release/notes/v0.3.8.md` 存在时发布流水线用
  `body_path` 写入 Release，同一份文案进入渠道清单 body。
- 本机 Flutter 3.41.3 / Dart 3.11.1 低于生成现有 lock 的工具链，`flutter pub get` 会顺带下调
  7 个 SDK 内置包；无关 lock 行已还原为基线值，只保留 `feedback_widget` 的 ref/版本变化。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 组件升级到 0.9.0 | 解析到 0.9.0（ref = 7201756）；`flutter analyze` 无问题；现有测试全部通过 | 解析 `feedback_widget 0.9.0`（`~/.pub-cache/git/Sakura-Feedback-7201756…`）；analyze 无问题；全量 410 项测试通过；47 项发布脚本测试通过 | 已完成 |
| T2 | 宿主文案/测试对齐新「隐藏」语义 | 设置 → 关于 的悬浮球样式说明只承诺「隐藏闲置入口、手势仍可唤醒」；集成测试覆盖「初始完整球 → 闲置隐藏 → 问题反馈可打开面板」 | 中英文文案、注释、DB 列注释与 drift 生成物已更新；`feedback_integration_test` hidden 用例按 5 秒闲置后的待机隐藏断言；独立复核 0 阻塞 | 已完成 |
| T3 | 发布 v0.3.8 正式版 | 标签触发发布；Release 非预发布、9 资产；`latest.json`/`preview.json` 推进到 0.3.8；body 为用户向日志 | [Release v0.3.8](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.8) 已发布（2026-11-04T10:08:21Z，非草稿、非预发布、Latest、9 资产）；两渠道清单均为 `v0.3.8` / `0.3.8` / `1793783648` / prerelease=false（清单提交 `47d41ea`），body 为用户向日志；发布流水线首跑 iOS/Windows 因 SSH 认证瞬时失败，重跑失败 job 后全部成功 | 已完成 |
| T4 | 新组件行为随包生效 | 正式渠道看到 v0.3.8；安装后「隐藏」样式按新语义工作；面板可改回其他样式 | 发布包已核验版本、着色器与新文案；真实安装包上的升级与交互体验尚未验证 | 未开始 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-11-04 | Feedback `v0.9.0`（上游） | 本机 Feedback 仓库 / GitHub | 核对标签、Release 与包版本 | 标签对象 `99cc816`（签名 Good）→ 提交 `7201756`；Release 非 draft/非 prerelease/Latest；包版本 0.9.0；`flutter/feedback` 相对 0.8.4 的公共导出 diff 为空、依赖未变 |
| 2026-11-04 | 工作树未提交（ref 7201756） | macOS arm64，Flutter 3.41.3 / Dart 3.11.1 | `flutter pub get` | 解析 `feedback_widget 0.9.0`；无关 lock 行已还原为基线 |
| 2026-11-04 | 同上 | 同上 | `flutter gen-l10n` | 中英文本地化生成成功，生成物与 ARB 同步 |
| 2026-11-04 | 同上 | 同上 | `flutter analyze` | `No issues found!` |
| 2026-11-04 | 同上 | 同上 | `flutter test` | 410 项全部通过 |
| 2026-11-04 | 同上 | Python 3.10.10 / PyYAML 6.0.2 | `python3 -m unittest discover -s .github/scripts/tests` | 47 项通过 |
| 2026-11-04 | 同上 | 同上 | `python3 .github/scripts/pilot_release.py source-version pubspec.yaml v0.3.8` | `version=0.3.8`、`build_number=1793783648`、`prerelease=false`；同一文件对 `v0.3.7` 报 tag/source mismatch |
| 2026-11-04 | 同上 | macOS arm64 debug | `flutter build macos --debug --build-name 0.3.8 --build-number 1793783648` | 构建成功；Info.plist `CFBundleShortVersionString=0.3.8`、`CFBundleVersion=1793783648`；产物含 `packages/feedback_widget/shaders/orb_lens.frag`；kernel_blob 含新文案「只隐藏闲置后的悬浮入口」3 处与英文新文案 5 处 |
| 2026-11-04 | `c623084` | GitHub Actions（ubuntu / macOS） | PR CI [41806323451](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41806323451)、[41806350054](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41806350054) | Analyze / Test / Release workflow checks 全部通过；随后独立复核发现 db 注释残留旧语义 |
| 2026-11-04 | `1c9cc47`（修订） | 同上 | PR CI [41808250113](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41808250113)、[41808257575](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41808257575)；`flutter analyze --no-pub`、针对性 28 项测试 | 全部通过；修订仅注释/生成镜像（0 运行时代码变化）；PR #29 以合并提交 `daa82d7` 合入 `main`（mergedAt 2026-11-04T09:35:02Z） |
| 2026-11-04 | `daa82d7`（合并后 main） | GitHub Actions（ubuntu / macOS） | main CI [41808727560](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41808727560) | Analyze / Test / Release workflow checks 全部通过，之后才创建标签 |
| 2026-11-04 | `v0.3.8`（daa82d7） | GitHub Actions（ubuntu / macOS） | 推送签名标签；标签 CI [41810183715](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41810183715) | 4 job 全部通过；标签对象 `21734536…` 解引用 `daa82d7`，GitHub `verified=true` |
| 2026-11-04 | 发布流水线首跑 | GitHub Actions（ubuntu / macOS / windows） | 发布工作流 [41810183995](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41810183995) attempt 1 | Validate/Test/macOS/Android 成功；iOS 与 Windows 在 `flutter pub get` 拉取私有组件时 `git@github.com: Permission denied (publickey)` 失败，Publish 跳过；同一 deploy key 在同次 CI 与 macOS/Android job 正常，判定为 runner 侧 SSH 认证瞬时失败 |
| 2026-11-04 | 发布流水线重跑 | 同上 | `gh run rerun 41810183995 --failed`（attempt 2） | 8 个 job 全部成功（含 Publish）；未移动/重建标签 |
| 2026-11-04 | v0.3.8 发布包 | 本机 macOS arm64 + `/tmp` 下载 | 对照清单 SHA256；解包检查 Info.plist、着色器与 AOT 文案 | macOS/Windows/Android 资产 SHA256 与清单一致；macOS 0.3.8/1793783648、`orb_lens.frag` 存在、AOT（UTF-16LE）新文案 2 处、旧「完全不显示/手势失效」文案 0；Android `versionName=0.3.8`，Windows VERSIONINFO 0.3.8/1793783648 |
| 2026-11-04 | v0.3.8 清单 | GitHub main（`47d41ea`） | 核对 `release/latest.json`、`release/preview.json` 与公开 raw | 两清单 `v0.3.8` / `0.3.8` / `1793783648` / prerelease=false / 9 资产；body 与更新日志一致；raw 与 git blob 逐字节一致 |
| 2026-11-04 | `c623084` + `1c9cc47` | 独立只读复核（integration-reviewer） | 身份链、语义一致性、生成物同步、发布元数据、差异卫生；修订后增量复核 | 0 阻塞；1 项「重要」（db 列注释仍按旧语义）已由 `1c9cc47` 修复并经增量复核关闭 |
| 2026-11-04 | v0.3.8 | 独立只读发布核验（integration-reviewer） | 标签/Release/流水线/渠道清单/安装包身份/范围卫生 | 0 阻塞；9 资产名与 digest、tag verified、两渠道 raw、macOS/Android/Windows 安装包身份均通过；建议项仅「发布工作流可为首跑 SSH 增加重试」 |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| `c623084` | 组件 0.8.4 → 0.9.0；宿主文案/注释/测试适配；应用版本 0.3.8 + 用户向更新日志 | 本机 analyze + 410 项单测 + 47 项发布脚本测试 + macOS debug 构建；PR CI | PR #29 合入 main（`daa82d7`） |
| `1c9cc47` | 修正 db 列注释及 drift 生成物中的旧「隐藏」语义 | 增量只读复核 + PR CI | 随 PR #29 合入 main |
| `daa82d7` | PR #29 合并提交（`v0.3.8` 标签来源） | main CI、标签 CI、发布流水线 | 已发布 Release v0.3.8 |
| `47d41ea` | 发布流水线自动更新 `latest.json` / `preview.json` | 清单与 Release/资产 digest 核对；独立核验 | 直接推送 main（`[skip ci]`） |
| 待定 | closeout：补记发布证据并更新状态 | 文档核对 | 本 PR 合入 main |

## 交付与恢复

- 体验入口和操作步骤：安装 [v0.3.8 正式包](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.8)
  （或应用内 设置 → 关于 → 检查更新）→ 设置 → 关于 → 「悬浮球样式」选择「隐藏」：
  完整球在启动/唤醒后会先显示，闲置 5 秒后隐藏；开启的唤醒手势可再次唤醒；从同页
  「问题反馈」可把样式改回「小把手」或「球体贴边」。
- 关键行为变化（相对 0.3.7）：`0.3.7` 文案承诺「隐藏」完全不显示入口且唤醒手势不触发；
  `0.3.8` 采用组件 0.8.5 的新语义——只隐藏闲置（收起）入口。更新日志已向用户说明。
- 尚未完成 / 尚未验证：真实安装包的升级路径与「隐藏」交互/手势真机体验；
  Android/iOS/Windows 本机安装（发布流水线已构建并核验身份，未逐平台启动）。
- 用户确认（明确确认后才改为已验收）：待体验。
- 下一步：安装 v0.3.8 体验新的「隐藏」语义与反馈面板，确认后改为已验收。
- 回退方式：还原 `pubspec.yaml` ref/版本、`pubspec.lock` 的 feedback 块、
  `release-build.yml` vendoring SHA、宿主文案/注释/测试与生成物，删除
  `release/notes/v0.3.8.md`；已发布对象不回改。
- 本任务 worktree 收尾：closeout 合入后检查清理（实现与 closeout 均已合入 main，无独有成果）。
