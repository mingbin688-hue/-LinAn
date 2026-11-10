---
name: linan-verify
description: 验证邻安的后端、前端构建、角色权限、Agent 与自动派单闭环，并返回实测结果；不用于实现新功能。
---

# 邻安验证

在项目根读取 `AGENTS.md`，使用 `Verify.ps1` 作为统一入口。默认检查后端与前端；`-BackendOnly`、`-FrontendOnly` 用于已知范围，`-Browser` 加入隔离浏览器闭环。缺少前端依赖时可使用 `-InstallFrontendDependencies`；缺少 Playwright 时明确说明并参考 `docs/AGENT_WORKFLOWS.md`。

检查本次实际生成的 `runtime/verify/<本次编号>/verification.json` 与日志。浏览器验收必须使用脚本创建的数据库、端口和输出目录；不要改用正在运行的用户服务，不覆盖已有截图来伪造当前验证。

根据改动选择重点：四角色与会话权限、自动派单开关与资源优先级、版本及并发保护、模型回退、拒单防循环、重启恢复、人工复核和手机布局。

若验证暴露问题，返回具体触发条件、请求或操作、预期与实际行为和日志位置。除非明确授权修复，否则只报告；不要把环境错误记为业务通过，也不要把模拟模型测试记为真实供应商联调。
