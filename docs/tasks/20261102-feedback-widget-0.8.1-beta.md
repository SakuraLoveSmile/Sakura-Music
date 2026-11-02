# feedback-20261102c：升级 feedback 组件至 0.8.1 并发布测试版 0.3.6-beta.1

- 项目 / 任务编号：personal-music / feedback-20261102c
- 状态：实现中
- 创建日期（Asia/Taipei）：2026-11-02
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（f743eab）/ `feat/20261102-feedback-widget-0.8.1-beta` / `main`
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261102-feat-feedback-widget-0.8.1-beta`
- 当前 HEAD / 未提交差异：`f743eab` + 未提交（feedback ref/lock/vendoring SHA、应用测试版版本号、发布工作流与用户向更新日志、本记录）

## 目标与范围

1. 把内嵌的 `feedback_widget` 从 0.8.0（`693e693`）升级到 0.8.1（标签 `v0.8.1`，
   提交 `620c82c`）。
2. 发布**测试版** `v0.3.6-beta.1`：走 `preview.json` 测试渠道，不影响正式版清单与
   正式版用户。
3. 这次发布要带**偏向用户**的更新日志（GitHub Release 与应用内更新弹窗都读同一份
   body）。

0.8.1 组件相对 0.8.0 **只有版本号变化**（`flutter/feedback/lib` 零 diff；CHANGELOG：
服务端/管理端页面修订，组件运行时行为无变化）。因此相对 0.3.5 正式版，本次客户端
没有用户可见的功能/界面变化；更新日志如实说明这一点，并说明如何体验测试版渠道。

覆盖：依赖 ref 与 lockfile、Windows vendoring SHA、测试版应用版本号与发布、
发布流水线的两项必要调整（见下）、用户向更新日志、任务记录。不覆盖：Feedback 服务端
升级/部署、真实账号 E2E、正式版 0.3.6 发布。

## 已确认决定

- 固定上游标签提交 `620c82ca93d68ee931aa2181df20f49f5a3205c1`；与 Release 的
  `SOURCE.txt`（`commit=`）一致，`v0.8.1` 为非预发布正式标签。
- 测试版版本取 `0.3.6-beta.1`，构建号 `1793614825`（2026-11-02 时间戳，严格大于
  正式版 `0.3.5+1793611631`）；标签 `v0.3.6-beta.1` 触发 `release.yml`，发布脚本据
  pubspec 的预发布后缀生成 `prerelease=true`、`make_latest=false`，只推进
  `release/preview.json`。
- **发布流水线调整 1（版本身份透传）**：`release.yml` 把 `source-version` 得到的
  数字 `version`/`build_number` 显式传给 `release-build.yml`（该工作流原本就支持
  `version`/`build_number` 覆盖，Pilot 构建在用）。原因：带后缀的 pubspec 版本会让
  Flutter 把 macOS/iOS 版本写成 `0.3.6.1` 之类、与清单的数字版本不一致，导致测试版
  用户每次检查更新都重复提示同一个构建；透传后安装包版本与清单一致（0.3.6+N）。
  正式版发布传入的值与 pubspec 完全相同，产物行为不变。
- **发布流水线调整 2（用户向更新日志）**：`release.yml` 支持
  `release/notes/<tag>.md`；存在时用 `body_path` 写入 Release，不存在时沿用自动
  生成的 PR 列表。更新日志会随 `legacy-manifest` 进入渠道清单 body，应用内更新弹窗
  直接展示，因此 GitHub 与应用内看到的是同一份用户向文案。
- 更新日志内容（`release/notes/v0.3.6-beta.1.md`）：说明这是测试版、反馈组件 0.8.1
  仅版本对齐、应用无界面变化；给出切换测试版渠道与验证步骤；说明正式版用户不受影响、
  0.3.5 已包含反馈组件 0.8.0 的改进、服务端/管理端新能力需另行升级服务端。
- 本机 Flutter 3.41.3 / Dart 3.11.1 低于生成现有 lock 的工具链，`pub get` 会顺带
  下调 SDK 内置包；无关 lock 行已还原为基线值。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 组件升级到 0.8.1 | 解析到 0.8.1（ref = 620c82c）；`flutter analyze` 无问题；全量测试通过；发布工作流脚本测试通过 | 解析 0.8.1；analyze、404 项单测、47 项发布脚本测试均通过 | 已完成 |
| T2 | 发布测试版 v0.3.6-beta.1 | 标签触发发布；Release 为预发布、9 资产；`preview.json` 推进到 0.3.6，`latest.json` 保持 0.3.5；Release body 为用户向日志 | 进行中（见执行记录） | 进行中 |
| T3 | 测试版更新体验 | 测试渠道能看到 v0.3.6-beta.1；安装后不再重复提示同一构建；正式版渠道不受影响 | 尚未在真实安装包上验证 | 未开始 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-11-02 | 工作树未提交（ref 620c82c） | macOS arm64，Flutter 3.41.3 / Dart 3.11.1 | `flutter pub get` | 解析 `feedback_widget 0.8.1`；同时下调 7 个 SDK 内置包，已还原为基线 lock 内容 |
| 2026-11-02 | 同上 | 同上 | `flutter analyze` | `No issues found!`（7.8s） |
| 2026-11-02 | 同上 | 同上 | `flutter test test/feedback_integration_test.dart test/feedback_launcher_migration_test.dart` | 26 项通过 |
| 2026-11-02 | 同上 | 同上 | `flutter test` | 404 项全部通过 |
| 2026-11-02 | 同上 | 同上 | `python3 -m unittest discover -s .github/scripts/tests -v` | 47 项通过（含新增的用户向更新日志选择测试） |
| 2026-11-02 | 同上 | macOS arm64 debug | `flutter build macos --debug --build-name 0.3.6 --build-number 1793614825`（模拟发布流水线的数字身份透传） | 构建成功；Info.plist `CFBundleShortVersionString=0.3.6`、`CFBundleVersion=1793614825`，与渠道清单身份一致；产物含 `packages/feedback_widget/shaders/orb_lens.frag` |
| 2026-11-02 | 同上 | macOS arm64 debug | `flutter build macos --debug`（不带覆盖，验证带后缀 pubspec 也能构建） | 构建成功；但 Apple 版本被 Flutter 写成 `0.3.6.1`，正是需要在发布流水线透传数字版本的原因 |
| — | — | — | 真实服务端 E2E / 测试渠道真机升级 | 未运行：需账号与真实安装包 |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| 未提交 | 组件 0.8.0 → 0.8.1；应用版本 0.3.5 → 0.3.6-beta.1；发布流水线数字版本透传 + 用户向更新日志 | 分析 + 404 项单测 + 47 项发布脚本测试 + macOS 构建核验 | 未提交 / 未推送 / 未发布 |

## 交付与恢复

- 体验入口和操作步骤：发布后安装 v0.3.6-beta.1（或在应用内 设置 → 关于 →
  更新渠道 → 测试版 → 检查更新）；更新弹窗会显示本次用户向更新日志。
- 尚未完成 / 尚未验证：测试渠道真实升级路径（需要一台已装 0.3.5 的设备/桌面机）；
  安装后重复更新提示是否消失的端到端确认；正式版渠道是否保持 0.3.5。
- 用户确认（明确确认后才改为已验收）：待体验。
- 下一步：合入 main → 推送 `v0.3.6-beta.1` 标签触发发布 → 核对预发布状态、9 个资产、
  `preview.json` 推进与 `latest.json` 不变、Release body 为用户向日志。
- 回退方式：还原 `pubspec.yaml` ref、`pubspec.lock` 的 feedback 块、
  `release-build.yml` vendoring SHA 与 `release.yml` 两处调整，删除
  `release/notes/v0.3.6-beta.1.md` 即可回到 0.8.0/0.3.5；已发布对象不回改。
- 本任务 worktree 收尾：尚不满足清理条件（待发布核验）。
