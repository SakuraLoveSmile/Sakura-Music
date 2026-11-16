# feedback-20261116a：升级 feedback 组件至 0.9.1 并发布 v0.3.9

- 项目 / 任务编号：personal-music / feedback-20261116a
- 状态：实现中（发布核验后更新为待体验）
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

## 提交与发布

- 实现提交（本分支）：组件 ref、lock、release-build vendoring、版本号、用户向日志、本记录。
- 计划：FF 推送到 `main` → main CI 通过 → 签名标签 `v0.3.9` → 发布流水线 → 核对 Release/资产/双渠道清单。
- 尚未验证：发布后 9 资产、渠道清单与安装包身份；发布失败时的重跑按既有流程处理。

## 回退

- 还原 `pubspec.yaml` 的 ref/version、`pubspec.lock` feedback 块、`release-build.yml` SHA 与 `release/notes/v0.3.9.md`；已发布对象不回改。
