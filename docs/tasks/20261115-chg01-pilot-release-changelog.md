# CHG01 · 测试版发布日志列出用户反馈的问题

日期：2026-11-15（Asia/Taipei）。状态：实现中（代码与隔离测试完成；尚未合入 `main`，未触发真实发布）。

## 背景

KaneoPilot 自动发布的测试版（tag `vX.Y.Z-pilot.<build>`）目前把内部归属标记写进 Release 正文，更新 feed 的 `body` 也是同一段内部标记；应用「设置 → 关于 → 检查更新」的发布说明因此看不到本次修复的用户反馈问题。用户要求：测试版本的更新日志要把用户反馈的问题写出来。

## 范围

- 仅改 Pilot 发布脚本 `.github/scripts/pilot_release.py` 及其 Python 隔离测试。
- 新 Release：正文首行保留内部归属标记（KaneoPilot 发布校验需要），其后追加用户可读的「本次更新」段落；段落内容取批次根任务交付提交 `kaneo(<task_id>): <标题>` 的标题，即 Kaneo 任务（用户反馈）的原始标题。缺失、非 Kaneo 或无法读取的提交不编造说明。
- 更新 feed 的 `body` 去掉有效的内部归属首行，只保留用户说明；这与 `docs/release-contract.md` 的「应用更新 feed 的 body 仅含用户说明」一致。
- 不改发布身份、标签、资产、渠道推进、任务 manifest schema、Kaneo 或 KaneoPilot 核心。

## 非目标

- 不回填已发布的历史 Release 与 feed。
- 不从 Feedback 服务或 Kaneo 查询反馈提交者姓名：Kaneo 任务由 Feedback 服务的 API Key 创建，`userId`/负责人是工作区所有者，任务正文只有「用户原话」「反馈ID」，没有提交者姓名。因此本次日志写「用户反馈：<任务标题>」，不编造姓名。若之后需要「小明反馈」，应在 Feedback 归档任务正文或 Kaneo 外部用户字段里带上提交者，再扩展本脚本。

## 实现

- `kaneo_task_title(manifest)`：按 `root_task_id` 找到 manifest 成员，读取其不可变 `head_sha` 对应提交的首行；仅接受 `kaneo(<id>): <title>` 形式，标题压平空白并限制 300 字符。读取失败/非 Kaneo 提交返回空。
- `release_body`：`<owner marker>\n\n【本次更新】…• 用户反馈：<title>\n\n<iOS note>`；无标题时保持原 marker + iOS 说明。说明在创建 tag/Release 之前读取，只在新建 Release 时读取；恢复已有 Release 不改正文。
- `user_feed_body`：首行为有效 `kaneopilot-owner:` JSON（裸行或 HTML 注释）时去掉该行；其他正文原样保留。
- `publish` 创建新 Release 时使用新正文；恢复已有 Release 时不改写其正文。

## 验证

在独立工作树执行：

- `python3 .github/scripts/tests/test_pilot_release.py`：23 项通过（新增 2 项：用户反馈标题进入 Release 正文与 feed；缺失/非 Kaneo 提交不编造）。
- `python3 .github/scripts/tests/test_update_channels.py`：12 项通过。
- 未运行 Flutter 分析/测试、原生构建或真实 Actions/Release：本次只改发布脚本，相关 Python 隔离测试已覆盖正文与 feed 生成。

## 部署与后续

- 分支 `fix/20261115-chg01-pilot-release-changelog`，工作树 `/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261115-fix-chg01-pilot-release-changelog`，未提交前基线 `6c132ed`。
- 合入 `main` 后，下一次 Pilot 发布（workflow 从 `main` 取脚本）生效；当前已发布的测试版仍显示旧正文，需要回填时走 KaneoPilot 的 `repair-release-notes` 显式修正。
- 真正生效需要用户确认合并与后续发布；本轮未推送、未合并、未触发 Actions。
