# feedback-20261102e：把「显示反馈悬浮球」改成悬浮球具体设置

- 项目 / 任务编号：personal-music / feedback-20261102e
- 状态：待体验
- 创建日期（Asia/Taipei）：2026-11-02
- 权威记录：本文件
- 主仓库 / 当前工作目录：`/Users/sakurasep/Documents/Code/Project/Personal Project/Music`
- 基线 / 分支 / 合入目标：`origin/main`（da8517d）/ `feat/20261102-feedback-orb-settings` → 合入 `main`
- 工作树：`/Users/sakurasep/Documents/Code/Project/Project Worktree/personal-music/20261102-feat-feedback-orb-settings`
- 当前 HEAD / 未提交差异：实现提交 `6742d48` 与复核修订 `c5cca9f` 已随 PR #25 合入 `main`（合并提交 `65152b3`）；本 closeout 只更新本记录

## 目标与范围

把 设置 → 关于 里的「显示反馈悬浮球」开关改成悬浮球的具体设置：

1. **悬浮球样式**：小把手（默认）/ 球体贴边 / 隐藏。`隐藏` 取代原来的关闭状态——不显示
   任何悬浮入口，但仍可从下方「问题反馈」打开面板改回。
2. **唤醒手势**：双指长按 / 三指上滑 / 双指双击，可多选，默认全部关闭（与组件内置语义一致）。

两项设置由宿主（本应用）保存并传给组件，组件内置的「设置 → 灵感球 / 唤醒方式」显示同一份
值并回调宿主，避免出现两套互相覆盖的偏好。

覆盖：`feedback_widget` 升级到 0.8.4（宿主托管 API）、设置页 UI、DB schema 19→20 迁移、
设置持久化、依赖 ref / lockfile / Windows 发布 vendoring SHA、测试与任务记录。不覆盖：
应用版本发布（用户本次只要求改设置，未授权发版）、组件仓库改动（已在
`personal-feedback / FB-HOST-ORB-001` 完成并发布 `v0.8.4`）、真实设备上的点击体验。

## 已确认决定

- 用户选择「改组件 + 应用设置」方案，并要求**样式 + 唤醒手势**一起做；组件仓库的提交与发版
  已获授权。组件 `v0.8.4` 已发布（非预发布，Release `SOURCE.txt` 的 `commit=` 为
  `b1a92cb050602baca089ad820dbf2c03b07ceed5`），本应用固定该提交。
- 组件新增宿主托管参数 `orbIdleStyle` / `onOrbIdleStyleChanged`、
  `wakeGestures` / `onWakeGesturesChanged`；未传参时组件行为不变。应用中这两项始终传入，
  数据源是本机 DB。
- DB schema 19 → 20：新增 `feedback_orb_idle_style`（默认 `handle`）与
  `feedback_wake_gestures`（默认 `[]`，JSON 数组存组件手势 id）。旧开关
  `feedback_launcher_enabled` 保留列不再读写，迁移时把 `false` 映射为 `hidden`，
  其余映射为 `handle`；老用户数据（主题、服务器、下载等）不动。
- 不再使用 `showLauncher: false` 隐藏入口：入口可见性统一由待机样式 `hidden` 表达，
  避免两个开关语义重叠。
- 本任务不发应用版本；合入 `main` 后由后续发版任务统一提升版本与更新日志。
- 本机 Flutter 3.41.3 / Dart 3.11.1 低于生成现有 lock 的工具链，`pub get` 顺带下调
  7 个 SDK 内置包；无关 lock 行已还原为基线，只保留 feedback_widget 的 ref/版本变化。

## 实现与验收

| 步骤 | 用户效果 / 实现范围 | 验收情形与预期 | 当前结果及证据 | 状态 |
| --- | --- | --- | --- | --- |
| T1 | 依赖组件 0.8.4，宿主托管两项设置 | 解析到 0.8.4（ref b1a92cb）；待机样式与唤醒手势由应用传给组件；面板内改选回调应用并保存 | 解析 0.8.4；`flutter analyze` 无问题；全量 409 项测试通过；macOS debug 构建成功且 kernel 含新设置文案 | 已完成 |
| T2 | 设置页改成具体设置 | 设置 → 关于显示「悬浮球样式」「唤醒手势」两行；样式弹窗三选一（隐藏=原关闭）；手势弹窗多选；选择立即生效并持久化 | 已实现；持久化/回滚/迁移有单测覆盖，analyze 与全量测试通过；尚未在真实窗口手动点击体验 | 已完成 |
| T3 | 老用户升级 | v18/v19 库升级到 v20；旧开关 `false` 变 `hidden`、`true` 变 `handle`；其他设置与数据不变；样式/手势重启后保留 | 迁移与回环测试通过（见执行记录） | 已完成 |

## 执行与验证记录

| 日期 | 代码版本 / 候选差异 | 环境与运行对象 | 命令或实际操作 | 结果 / 证据位置 |
| --- | --- | --- | --- | --- |
| 2026-11-02 | 组件 `v0.8.4`（b1a92cb） | GitHub Actions（ubuntu / macOS） | 组件仓库发布流水线 [41470747057](https://github.com/SakuraLoveSmile/Sakura-Feedback/actions/runs/41470747057) | 全部 job 成功；Release v0.8.4 非预发布、7 资产，`SOURCE.txt` commit=b1a92cb |
| 2026-11-02 | 工作树未提交（ref b1a92cb） | macOS arm64，Flutter 3.41.3 / Dart 3.11.1 | `flutter pub get` | 解析 `feedback_widget 0.8.4`（`~/.pub-cache/git/Sakura-Feedback-b1a92cb…`）；无关 lock 行已还原 |
| 2026-11-02 | 同上 | 同上 | `dart run build_runner build`、`flutter gen-l10n` | Drift 生成物与中英文本地化更新成功 |
| 2026-11-02 | 同上 | 同上 | `flutter analyze` | `No issues found!` |
| 2026-11-02 | 同上 | 同上 | `flutter test` | 409 项全部通过（新增 `test/feedback_orb_settings_test.dart` 4 项；迁移测试覆盖 v18/v19→v20） |
| 2026-11-02 | 同上 | macOS arm64 debug | `flutter build macos --debug --build-name 0.3.6 --build-number 1793626126` | 构建成功；Info.plist 0.3.6 / 1793626126；含 orb_lens 着色器；kernel 含「悬浮球样式」「唤醒手势」「球体贴边」「双指长按」与组件偏好键 |
| 2026-11-02 | 同上 | 同上 | `flutter test`（修订后） | 410 项通过（新增「旧包打开过 v20 库后再升级不重复加列」回归） |
| 2026-11-02 | `6742d48` + 复核修订 | 独立只读复核（orb-settings-reviewer） | 复核组件托管用法、迁移、UI、测试与 SHA 一致性 | 功能/迁移 0 阻塞；1 项差异卫生（lock 混入 7 个 SDK 包降级）已修复为只含 feedback_widget 变化；建议项（面板保存失败提示、hidden 路径测试、迁移可重复执行、英文连接符、记录措辞）已处理 |
| 2026-11-02 | `c5cca9f`（PR #25） | GitHub Actions（ubuntu / macOS） | PR CI [41476671771](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41476671771)、[41476682543](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41476682543) | Analyze / Test / Release workflow checks 全部通过；PR #25 以合并提交 `65152b3` 合入 `main` |
| 2026-11-02 | `65152b3`（合并后 main） | GitHub Actions（ubuntu / macOS） | main CI [41477172617](https://github.com/SakuraLoveSmile/Sakura-Music/actions/runs/41477172617) | Analyze / Test / Release workflow checks 全部通过 |
| — | — | — | 真实窗口点击设置项、真机安装、回退后再升级实测 | 未运行：需要交互式运行与安装包；回退场景用数据库测试模拟 |

## 提交与集成

| 提交 | 行为变化与原因 | 验证 | 合并 / 发布情况 |
| --- | --- | --- | --- |
| 6742d48 | 组件 0.8.4；设置页开关改为样式 + 唤醒手势；DB v20 迁移 | analyze + 409 项测试 + macOS debug 构建 | PR #25 合入 main（`65152b3`） |
| c5cca9f | 复核修订：lock 仅保留组件变化、面板保存失败提示、hidden 路径测试、迁移重复执行守卫与记录更正 | analyze + 410 项测试 | 随 PR #25 一起合入 main |
| 待定 | closeout：补记合入与验证状态 | 文档核对 | 本 PR 合入 main |

## 交付与恢复

- 体验入口和操作步骤：设置 → 关于 → 「悬浮球样式」选择小把手 / 球体贴边 / 隐藏；
  「唤醒手势」可多选。选择即时生效；「隐藏」后仍可通过同页「问题反馈」打开面板改回。
- 尚未完成 / 尚未验证：真实窗口里的弹窗交互、手机/桌面真机上的手势识别体验；应用版本发布
  （未授权，另行发起）。
- 已知边界：组件 0.8.2/0.8.3 在面板内保存过的待机样式/手势存在组件自己的偏好存储
  （`feedback:orb-idle:v1:<appId>` / `feedback:wake-gestures:v1:<appId>`）；改用宿主 DB 后
  这些旧值不迁移，升级后从默认「小把手 / 全关」开始。影响面是同日发布的 0.3.6 用户。
- 隐藏样式下唤醒手势不会触发（组件按「无入口」处理），设置弹窗文案已说明。
- 用户确认（明确确认后才改为已验收）：待体验。
- 下一步：合入后本地或真机体验设置项，确认后改为已验收；发版前再补应用版本与更新日志。
- 回退方式：还原 `pubspec.yaml` ref / `pubspec.lock` / `release-build.yml` vendoring SHA、
  设置页与 DB 迁移即可回到 0.3.6 行为。装过 schema 20 的库被旧包打开时 drift 会把
  `user_version` 写回 19（列仍在）；再次升级由 v20 迁移的列存在性守卫兜底，不会重复加列，
  也不会覆盖用户在旧包期间保存的样式（有回归测试）。
- 本任务 worktree 收尾：closeout 合入后检查清理（实现与 closeout 均已合入 main，无独有成果）。
