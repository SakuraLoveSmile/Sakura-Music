# feedback-20261116a：升级 feedback 组件至 0.9.1 并发布 v0.3.9

- 项目 / 任务编号：personal-music / feedback-20261116a
- 状态：待体验（已实现并发布 v0.3.9；待真实安装包体验确认）
- 创建日期（Asia/Taipei）：2026-11-16
- 权威记录：本文件
- 基线：`origin/main` `3e863a8`。本地主工作树的 `main` 与 origin/main 为无关历史且含用户未提交改动，本次不改写或提交它；发布工作在本分支完成，FF 合入 `main`。
- 分支 / 工作树：`feat/20261116-mu-fb001-feedback-091` / `/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261116-feat-mu-fb001-feedback-091` → 合入 `main`

## 目标与范围

1. 把 `feedback_widget` 从 0.9.0（`7201756`）升级到上游最新正式版 **v0.9.1**（`f63dda82`）：修复能力探测失败被误判为「只能传一张图」的问题；Windows 宿主 `pub get` 的 ASCII 描述修复；Flutter 宿主 API 兼容。
2. 确认宿主日志采集仍按 integration.md §5.6 接入：`lib/core/feedback/feedback_logs.dart` 的 `collectFeedbackLogs`（播放诊断环形缓冲 + 崩溃日志尾部，均已脱敏）继续作为 `logProvider` 默认值，不新增/替换日志来源。
3. 发布**正式版** `v0.3.9`：走既有标签发布流水线（`release.yml`），`latest.json` 与 `preview.json` 同步推进，Release body 使用用户向更新日志。

不覆盖：Feedback 组件/服务端、宿主新功能、真实设备 E2E、本地旧历史工作树的整理。

## 已确认决定

- 应用版本取 **0.3.9**，构建号 `1794840601`（2026-11-16 时间戳）：严格大于 v0.3.8 的 `1793783648` 与 0.3.9 测试版构建号 `1794681479`，保证正式版可覆盖测试版与 0.3.8 安装。
- 用户向日志写入 `release/notes/v0.3.9.md`：包含 0.9.1 的多图修复与诊断日志、0.3.9 期间修复（切歌音量、设置页返回、歌词字号、首页统计面板移除）。发布流水线优先使用该文件作为 Release body。
- Windows 发布构建的 vendoring SHA 同步到 `f63dda82`；保留既有非 ASCII 清理步骤（对 0.9.1 的 ASCII pubspec 为无操作）。

## 验证（2026-11-16）

| 检查 | 命令 / 对象 | 结果 |
| --- | --- | --- |
| 依赖解析 | `flutter pub get`（Flutter 3.47.7 / Dart 3.13.5） | `feedback_widget 0.9.1`，lock 仅 feedback 块变化 |
| 静态分析 | `flutter analyze --no-pub` | No issues found |
| 组件与宿主测试 | `flutter test --no-pub` | **425 项通过**（含 feedback_integration_test 22 项，覆盖 logProvider 默认接线、附件构造、脱敏） |
| 发布脚本测试 | `python3 -m unittest discover -s .github/scripts/tests` | 51 项通过 |
| 版本/标签校验 | `pilot_release.py source-version pubspec.yaml v0.3.9` | version=0.3.9、build_number=1794840601、prerelease=false |
| 未验证 | 真实安装包升级与真机交互 | 未执行（发布流水线构建与身份核验后补记） |

## 提交与发布（2026-11-16）

- 实现提交 `93b67ed`：组件 ref、lock、release-build vendoring、版本 `0.3.9+1794840601`、用户向日志、本记录。
- main CI [43891039531](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/43891039531) 4 个 job 成功；签名标签 `v0.3.9` 指向 `93b67ed`（GPG 校验通过），标签 CI [43891486483](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/43891486483) 成功。
- 发布流水线 [43891486464](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/43891486464)：8 个 job 全部成功（Validate/Test/iOS/Windows/macOS/Android/Publish）。
- [Release v0.3.9](https://github.com/SakuraLoveSmile/Sakura-Music/releases/tag/v0.3.9)：2026-11-16T15:09:09Z 公开，非草稿、非预发布、Latest，**9 个资产**；body 为用户向日志 `release/notes/v0.3.9.md`。
- 渠道清单提交 `5f70eda`：`release/latest.json` 与 `release/preview.json` 均为 `v0.3.9` / `0.3.9` / `1794840601` / prerelease=false / 9 资产。
- 安装包身份（各平台版本号、反馈着色器/文案）与真机升级交互尚未逐项核验。

## 回退

- 还原 `pubspec.yaml` 的 ref/version、`pubspec.lock` feedback 块、`release-build.yml` SHA 与 `release/notes/v0.3.9.md`；已发布对象不回改。
