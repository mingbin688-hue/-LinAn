# MCP 接入（只读）

邻安提供标准 MCP（Model Context Protocol）服务，让 Claude Desktop、Codex、Cursor 等外部客户端在**不接触用户数据库写权限**的前提下查询授权范围内的社区档案、风险事件、任务、工作流运行与持久化队列。

协议版本：`2025-06-18`，JSON-RPC 2.0，无状态 Streamable HTTP；也可通过 stdio 启动。

## 能力边界

- 全部工具、资源和提示均为只读，不提供 SQL、派单、关闭事件或修改档案的能力。
- 每次调用都重新按令牌对应的登录身份校验角色与对象范围，不信任客户端缓存。
- 老人联系人字段不会出现在工具结果、资源或上下文包中。
- 不调用大模型；`linan_context` 只生成有预算上限、带脱敏说明和缺口的上下文包，供客户端自己的模型引用。
- 每次工具调用写入审计表：成功为 `tool:<工具名>`，越权为 `mcp_denied`。

## 签发令牌

管理员登录后在“工作流中心 → MCP 接入”创建令牌，明文只显示一次。也可调用 API：

```powershell
$admin = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8765/api/auth/login `
  -ContentType 'application/json' -Body '{"username":"admin","password":"..."}'
$issued = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8765/api/mcp/tokens `
  -Headers @{ Authorization = "Bearer $($admin.token)" } -ContentType 'application/json' `
  -Body '{"label":"答辩演示","expires_hours":24}'
$issued.token   # 复制到客户端，离开页面后不可再次查看
```

`expires_hours` 为 `0` 表示不过期；建议演示令牌设为数小时，结束后立即撤销。

## HTTP 接入

客户端把 MCP 端点配置为 `http://127.0.0.1:8765/mcp`，并发送 `Authorization: Bearer <MCP 令牌>`。只接受通过 `/api/mcp/tokens` 签发的 MCP 令牌；普通 `/api/auth/login` 会话令牌会被拒绝（401），避免把交互式登录凭证扩散给外部客户端。

```powershell
$token = '<MCP 令牌>'
$headers = @{ Authorization = "Bearer $token" }
$body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"demo","version":"1"}}}'
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8765/mcp -Headers $headers `
  -ContentType 'application/json' -Body $body
```

无状态端点不要求先握手；`initialize`、`tools/list` 等请求可直接发送。响应为单个 JSON-RPC 结果，通知（无 `id`）返回 HTTP 202。

## stdio 接入

`backend.mcp_stdio` 从环境变量读取令牌和数据库路径，通过标准输入输出收发 JSON-RPC，日志只写 stderr。

```powershell
$env:LINAN_MCP_TOKEN = '<MCP 令牌>'
$env:LINAN_DB = 'E:\daxue\-LinAn\runtime\linan.sqlite3'   # 可省略，默认仓库 runtime/linan.sqlite3
$env:PYTHONPATH = 'E:\daxue\-LinAn'
E:\daxue\-LinAn\.venv\Scripts\python.exe -m backend.mcp_stdio
```

Claude Desktop（`claude_desktop_config.json`）：

```json
{
  "mcpServers": {
    "linan": {
      "command": "E:\\daxue\\-LinAn\\.venv\\Scripts\\python.exe",
      "args": ["-m", "backend.mcp_stdio"],
      "env": {
        "LINAN_MCP_TOKEN": "<MCP 令牌>",
        "LINAN_DB": "E:\\daxue\\-LinAn\\runtime\\linan.sqlite3",
        "PYTHONPATH": "E:\\daxue\\-LinAn"
      }
    }
  }
}
```

Codex（`~/.codex/config.toml`）：

```toml
[mcp_servers.linan]
command = 'E:\daxue\-LinAn\.venv\Scripts\python.exe'
args = ['-m', 'backend.mcp_stdio']
env = { LINAN_MCP_TOKEN = '<MCP 令牌>', LINAN_DB = 'E:\daxue\-LinAn\runtime\linan.sqlite3', PYTHONPATH = 'E:\daxue\-LinAn' }
```

stdio 模式启动时校验一次令牌；令牌失效会以退出码 2 结束。演示时不要用管理员令牌开放给不可信客户端。

## 工具

| 工具 | 作用 | 权限 |
|---|---|---|
| `linan_scope` | 当前身份可见的老人与任务、上下文摘要 | 全部角色 |
| `linan_elders` | 老人档案与在线状态（不含联系人） | 按对象范围 |
| `linan_incidents` | 未关闭风险事件与规则证据 | 按对象范围 |
| `linan_tasks` | 未关闭任务与负责人 | 按角色/任务 |
| `linan_task_detail` | 单个任务的老人、事件、反馈与运行摘要 | 按任务 |
| `linan_context` | 生成有预算、脱敏与缺口的上下文包 | 按对象范围 |
| `linan_dispatch_recommendations` | 全量待派任务的只读调度建议 | 仅管理员 |
| `linan_workflow_runs` | 最近的流程运行 | 管理员或本人对话 |
| `linan_workflow_run` | 单个运行的节点时间线 | 按运行归属 |
| `linan_jobs` | 持久化任务队列（不含载荷与结果） | 仅管理员 |
| `linan_health` | 数据库、流程与队列健康摘要 | 全部角色 |

家属与老人只能访问关联对象；照护人员只能访问自己的任务和当前关联老人。越权调用返回 `isError: true` 的中文说明，不泄露对象是否存在。

## 资源与提示

固定资源：`linan://scope`、`linan://elders`、`linan://incidents`、`linan://tasks`。
资源模板：`linan://elders/{elder_id}`、`linan://tasks/{task_id}`、`linan://workflows/{run_id}`。

提示：`risk_brief`（风险研判简报）与 `shift_handover`（值班交接摘要），只生成提示文本和可引用的工具清单，不执行写操作。

## 撤销与排障

- 撤销：`DELETE /api/mcp/tokens/{id}`，撤销后 HTTP 返回 401，stdio 需重启。
- 401：令牌过期、拼写错误或已撤销；重新签发。
- stdio 无输出：确认客户端用绝对路径启动 `.venv` 中的 Python，并设置 `PYTHONPATH` 指向项目根；stdout 只允许 JSON-RPC。
- 工具返回“任务不存在或无权访问”：这是权限结果，不是服务故障。
- 审计：管理员可在数据库 `audit` 表查看 `tool:<名称>` 与 `mcp_denied` 记录。
