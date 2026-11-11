# Agent、助手与开发工作流

本次扩展保持邻安的本地比赛原型定位。没有模型凭证也能运行风险响应、关注任务自动派单、处置复核摘要及四角色助手；页面会明确显示当前使用规则、模型还是回退结果。

## 业务 Agent

| Agent | 输入与职责 | 输出 |
|---|---|---|
| 上下文整理 | 读取当前授权档案、数据状态和事件 | 当前状态、数据缺口和依据记录 |
| 风险解释 | 使用规则与已有异常模型的风险结论 | 风险原因、证据和建议，不另行修改等级 |
| 调度建议 | 对全量待派任务运行优先级和技能匹配 | 推荐人员、等待原因与自动或人工派单结果 |
| 处置复核 | 汇总任务经过和人员反馈 | 已解决事项、未解决问题和待人工复核内容 |

风险工作流在新增或更新风险时触发；反馈工作流在处置反馈后触发；对话工作流由助手消息触发。运行记录和节点结果保存在 SQLite。模型生成在后台执行，不持有写事务，也不延迟规则判断和可执行的自动派单。

管理员可在“工作流中心”查看节点输入、结果、耗时、运行模式和等待原因；任务详情显示与该任务有关的 Agent 建议。模型结果是解释和建议，实际派单仍复用现有事务、版本和人员校验。

## 自动派单

首次运行默认关闭。管理员在“工作流中心”开启后，仅自动确认 **1级关注、电话核实、待派发** 的任务，开关会保存在本机数据库。

全量任务先统一推荐，使优先和紧急任务保留所需资源；人员必须同时满足值班、可用、空闲与技能条件。无合适人员时保留待确认并解释原因。数据未知、优先和紧急任务仍需管理员确认；任务关闭始终需要管理员复核。拒单或管理员要求继续跟进后，该任务转为人工派单，避免循环自动重派。

## 四角色对话助手

从侧栏进入“邻安助手”。管理员可问“今天哪些老人需要关注？”；照护人员可问“我的待办任务有哪些？”；家属可问“王桂兰现在是什么状态？”；老人可问“我下一步应该怎么做？”。回答附业务记录依据。

助手只查询和解释，提交求助、报平安、人工确认派单与关闭使用现有按钮。管理员可查询全社区；照护人员仅查询自己的任务和当前关联老人；家属与老人仅查询关联对象。每轮查询和会话历史读取均重新验证权限。切换登录身份后，前端清除上个身份的聊天状态。

## 可选模型配置

默认 `LINAN_LLM_ENABLED=0`。如果需要真实模型，在启动服务的同一 PowerShell 会话设置环境变量，然后启动邻安：

```powershell
$env:LINAN_LLM_ENABLED = '1'
$env:LINAN_LLM_BASE_URL = 'https://your-provider.example/v1'
$env:LINAN_LLM_MODEL = 'your-model-id'
# 将供应商凭证写入当前进程环境，不要把真实凭证保存到源码或截图。
$linanCredential = Read-Host 'Provider API key' -AsSecureString
$env:LINAN_LLM_API_KEY = [System.Net.NetworkCredential]::new('', $linanCredential).Password
Remove-Variable linanCredential
powershell -ExecutionPolicy Bypass -File ./Start.ps1 -Background -OpenApp
```

接口使用兼容 Chat Completions 的 `/chat/completions`，基础地址填写至 `/v1` 等供应商前缀，不要重复包含 `/chat/completions`。需要供应商支持模型输出的 JSON 内容，以及助手查询时的工具调用；调用轮数有上限。配置缺失、20秒超时、网络错误或输出校验失败时，保留规则结果并显示回退原因。

环境变量在服务启动时读取。如果本机邻安已运行，`Start.ps1` 会复用旧服务；应先执行 `Stop.ps1` 再启动，以载入新配置。`Verify.ps1` 则临时关闭真实模型调用，测试规则模式和模拟供应商响应，不消费真实模型额度。**当前交付的模型适配以模拟响应验证；没有配置凭证并实际调用时，不代表已完成真实供应商联调。**

## 开发 Agent 与技能

项目根 `AGENTS.md` 给出启动、验证和关键业务约束。`.codex/agents/` 的三个项目角色继承当前模型与权限：`linan-backend`、`linan-frontend`、`linan-verifier`。独立前后端工作可按文件范围委派，主 Agent 负责接口与最终集成；前端范围为 `app/lib/src/`。

项目技能位于 `.agents/skills/`，可直接请求：

- `$linan-dev`：实现功能或修复，按需要协调角色并验证行为。
- `$linan-verify`：执行针对性或完整验证，报告实际结果和复现证据。
- `$linan-demo`：准备隔离演示、验证结果与干净源码包。

使用这些配置时从项目根启动 Codex，以便找到根指令和项目技能。配置不修改个人全局设置，也不固定模型名称。Agent 和技能机制分别参考 [OpenAI 项目 Agent 配置](https://learn.chatgpt.com/docs/agent-configuration/subagents)、[项目技能发现](https://learn.chatgpt.com/docs/build-skills)。

## 统一验证

```powershell
# 后端测试、Flutter analyze/test、Windows Release 构建
powershell -ExecutionPolicy Bypass -File .\Verify.ps1
# 针对性验证
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -BackendOnly
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -FrontendOnly
# 缺少 Flutter 依赖时执行 flutter pub get（需要 Flutter SDK）
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -InstallFrontendDependencies
# 打包源码包
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -Package
```

Flutter 客户端验证依赖可用的 SDK；脚本依次查找 PATH、`E:/tools/flutter/bin/flutter.bat` 和 `%LOCALAPPDATA%/flutter`，也可用 `-FlutterExecutable` 指定。桌面验收使用隔离实例：`Start.ps1` 以临时 `LINAN_DB` 启动后运行 `linan_app.exe`；开发时可用 `flutter run -d windows` 热重载。Android 用 APK 或 `flutter run -d <device>` 连接。验收结束只停止自己启动的服务，不使用或修改 `runtime/linan.sqlite3`。

每次执行在 `runtime/verify/日期-编号/` 保存步骤日志和 `verification.json`。单步默认超时 600 秒，可用 `-StepTimeoutSeconds` 调整。部分 Windows 受限沙箱不允许 asyncio 建立本机回环套接字，此时后端检查应在允许本机网络的终端重跑；这是环境条件，不应据此改动业务权限或测试断言。

源码包保存在 `artifacts/linan-source.zip`，同目录清单包含各文件和压缩包 SHA256。打包不包含数据库、登录会话、凭证、缓存、依赖、原始数据归档和打包目录本身。它包含已构建的 Windows 客户端与 Android 安装包（若已生成），解压后按 README 启动后端与客户端。

## 答辩演示顺序

1. 管理员展示“邻安助手”的全社区风险汇总及依据，打开工作流中心，说明规则或模型模式。
2. 开启关注级电话核实自动派单；通过“信息上报”添加“请求联系”，查看匹配人员与自动派单节点。
3. 切换对应 `staffN`，查看自己的助手和任务，接单、开始处理并提交已确认安全的反馈。
4. 管理员在详情查看复核摘要，人工复核关闭；再展示紧急主动求助仍需人工确认派单。
5. 切换家属和老人，展示单人范围和手机端界面。桌面与 Android 验收在独立实例上人工执行，结果记录在 `VERIFICATION.md`。

紧急求助、数据未知和未解决反馈的处理边界与原有系统一致；公开数据和模型效果的局限继续参见实验报告。
