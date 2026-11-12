# 验证记录

本文件记录本地实际执行的验证，不代表生产或真实社区验证。每条记录保留独立日志目录，旧记录的通过结果不能当作本次结果。

## 2026年11月11日 Flutter 迁移验证

环境：Windows 11，Asia/Shanghai；Flutter 3.47.9 / Dart 3.13.7（`E:\tools\flutter`）；Python 3.14.8 + `.venv`；Android SDK 36.0.0；Visual Studio Build Tools 2022 17.14。统一入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -FlutterExecutable E:\tools\flutter\bin\flutter.bat
```

结果文件：`runtime/verify/20261111-222829-f4911657/verification.json`，`success: true`，四个步骤（backend、flutter-analyze、flutter-test、flutter-build-windows）退出码均为 0。

| 项目 | 结果 |
|---|---|
| Python 后端测试 | 56 项通过，16.0 秒，1 条 Starlette/httpx 弃用警告 |
| Flutter 静态检查 | `flutter analyze`：No issues found |
| Flutter 单元测试 | `flutter test`：1 项通过（登录页渲染演示身份与服务器设置） |
| 本地开发 | `Start.ps1 -Background` 起后端，`flutter run -d windows` 热重载；API 与客户端分离，无静态页面托管 |
| Windows 客户端联调 | exe 启动后连接 `127.0.0.1:8765`；管理员/照护/家属/老人四角色登录与页面渲染通过 |
| 业务闭环 | 情景注入→事件→派单建议→人工确认→接单→开始处理→处置反馈→复核关闭，审计与 Agent 运行记录完整 |
| 权限边界 | 家属只看到关联老人；他人档案 403；老人不能访问任务列表；照护人员只看到自己的任务；未登录 401 |
| SOS 规则 | 3 级安全事件不因报平安或模型文字降级/关闭；10 分钟未回应自动升级为优先并改派上门核实 |
| 实验页 | 合成数据、CASAS Aruba、人员调度三张对照表均显示，数值与实验 JSON 一致 |
| Windows 构建 | `flutter build windows --release` 通过（清理旧 CMake 缓存后 40.8 秒），exe 实际启动并连接 `127.0.0.1:8765`，标题「邻安 · 社区守护」 |
| Windows 窄窗口 | 406×819 手机宽度下登录页、安心守护页无横向溢出 |
| Android 构建 | `flutter build apk --release` 通过，`app-release.apk` 51.8 MB |
| APK 清单 | package `com.wutongli.linan_app`，versionName 1.0.0，minSdk 24，targetSdk 36，INTERNET 权限，`usesCleartextTraffic=true`，应用名「邻安」 |
| 启动/停止脚本 | `Start.ps1 -Background` 后台就绪后可访问；`Stop.ps1` 校验进程路径与启动时间后停止 |
| 源码包 | `-Package` 生成 `artifacts/linan-source.zip`，排除 runtime、数据库、会话与构建缓存 |

界面验收覆盖：管理员总览/老人档案/风险事件/任务中心/人员资源/邻安助手/工作流中心/回放与实验八个页面；照护人员接单、处置反馈；家属安心守护、状态记录与助手问答；老人上报平安后事件仍保留。手机宽度用 Windows 窗口缩至 406×819 验证，布局无横向溢出。界面截图：`overview.png`、`experiments.png`、`tasks.png`、`decision-trace.png`、`mobile.png`。

已修复的迁移期缺陷：

- 后端业务 ID 为字符串（`TK-`、`EV-`、`REC-`、`WF-`），Flutter 模型曾按整数解析导致显示 `#0` 且动作无效；现全部按字符串处理。
- 生产端口为 8765，Flutter 默认地址曾误写 8798；Windows `127.0.0.1:8765`、Android `10.0.2.2:8765` 已统一，登录页可修改服务器地址。
- `Verify.ps1` 旧实现用 `Start-Process` + `WaitForExit(ms)` 取不到退出码；现改用 `System.Diagnostics.Process` 读取真实退出码。
- Windows 标题中文乱码；`main.cpp` 改为 UTF-8 转义文本后重建。
- Android Gradle 缓存跨盘（C: 的 pub cache 与 E: 的工程）导致 Kotlin 增量编译失败；`android/gradle.properties` 关闭 Kotlin 增量并改用 in-process 编译后通过。

已知限制：

- 本机没有 Android 设备、模拟器与 system image，APK 已构建并通过清单校验，但未做真机安装运行；Android 端仅验证了构建与配置。
- 本机无 macOS 构建机，iOS/macOS 未产出。
- 未接入真实社区、短信、电话或救援调度；助手为规则模式，模型只解释证据与建议。
- 服务空闲超过 30 分钟后老人会因缺少新活动数据进入「状态未知」，这是「数据缺失=未知」的既有规则，不是崩溃。

## 2026年11月11日 持久化任务、上下文封装与 MCP 验证

环境同上（Windows 11，Flutter 3.47.9，Python 3.14.8 + `.venv`）。统一入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\Verify.ps1
```

结果文件：`runtime/verify/20261111-235615-86dba58e/verification.json`，`success: true`，四个步骤退出码均为 0。

| 项目 | 结果 |
|---|---|
| Python 后端测试 | 60 项通过，16.8 秒，1 条 Starlette/httpx 弃用警告 |
| Flutter 静态检查 | `flutter analyze --no-pub`：No issues found |
| Flutter 单元测试 | `flutter test --no-pub`：1 项通过 |
| Windows 构建 | `flutter build windows --release --no-pub` 通过，18.9 秒 |
| 存储迁移 | 测试模拟 v1/v2 旧库：账号、会话、任务与事件保留，补齐 `jobs`、`mcp_tokens`、运行定义版本与上下文摘要列，`schema_version` 升到 `3`，同一任务只重建 1 条风险运行 |
| 持久化任务 | 解释任务先入 `jobs` 排队，规则节点与自动派单不等待模型；重启和过期租约只恢复一次，`dispatch_confirmed` 不重复；死信运行标记失败并可重试 |
| 上下文封装 | 助手响应返回预算、实际字符、脱敏、规则、缺口与工具调用；联系人不出现在模型提示中；小预算时按顺序裁剪并标记截断 |
| MCP HTTP | 管理员签发一次性明文令牌 → `initialize`、`tools/list`、`linan_scope`、越权工具报错 → 撤销后 401；`/api/mcp/status` 返回协议、工具/资源/提示计数 |
| MCP 对象权限 | 家属令牌只能查询关联老人；查询其他老人和 `linan_jobs` 返回 `isError`，不泄露对象内容 |
| MCP stdio | 临时数据库实测 `python -m backend.mcp_stdio`：3 条 JSON-RPC（initialize、tools/list、linan_scope）全部正确响应，退出码 0；临时文件已删除 |

新增界面（持久化任务卡、MCP 接入卡、助手上下文摘要、运行重试）已通过 `flutter analyze`、`flutter test` 与 Windows Release 构建；本次未逐项人工点击这些新卡片，界面验收仍以隔离实例人工操作为准。MCP 与模型均未接入真实供应商，规则模式结论不受影响。

## 2026年11月12日 三轮审计、修复与重构后验证

环境同上（Windows 11，Flutter 3.47.9，Python 3.14.8 + `.venv`）。统一入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -FlutterExecutable E:\tools\flutter\bin\flutter.bat
```

结果文件：`runtime/verify/20261112-005439-cc1fc2a6/verification.json`，`success: true`，四个步骤退出码均为 0。

| 项目 | 结果 |
|---|---|
| Python 后端测试 | 70 项通过，16.8 秒，1 条 Starlette/httpx 弃用警告 |
| Flutter 静态检查 | `flutter analyze --no-pub`：No issues found（4.1 秒） |
| Flutter 单元测试 | `flutter test --no-pub`：4 项通过（3.5 秒） |
| Windows 构建 | `flutter build windows --release --no-pub` 通过（20.6 秒） |
| 源码包 | `runtime/verify/20261112-005532-39364b73`：148 个文件，`artifacts/linan-source.zip`，逐文件字节数与 SHA256 与磁盘一致（清单见 `artifacts/linan-source.manifest.json`） |

本轮审计发现并修复的主要问题：

| 类别 | 问题 | 修复 |
|---|---|---|
| 通知越权 | `/api/notifications` 先取全局 300 条再按角色过滤，家属/照护人员可能看不到自己的通知 | 改为 SQL 内按 `role`/`staff_id`/`elder_id` 过滤后再取 30 条，并加测试覆盖 |
| 人员更新 | 客户端只提交单个字段，后端要求全量字段，开关操作恒 422 | 后端改为可选字段合并更新（空对象 422），客户端乐观更新并失败回滚 |
| 请求风暴 | 任务详情与助手引用详情在 `build()` 里发请求，抽屉打开期间无限重取 | 改为 StatefulWidget 缓存 future，仅在显式刷新时重取 |
| 会话失效 | 仅刷新接口处理 401，其它页面遇 401 静默失败 | `ApiClient` 统一回调清会话，UI 自动回登录页 |
| 作业失败 | 解释任务异常时只靠租约过期重试，`jobs.fail` 无调用方 | `drain()` 捕获异常、写失败节点、按退避重排，达上限转死信；补持久化与重启测试 |
| 登录限流 | 失败计数只按用户名清理，长期运行会累积 | 超过阈值整体裁剪并保留近 10 次 |
| MCP 鉴权 | 普通登录会话令牌也可当 MCP Bearer 使用 | 仅接受专用 MCP 令牌，登录令牌返回 401；补充文档与测试 |
| 元数据 | 界面写死规则版本、统计卡按整页拉取、健康信息不暴露版本 | `/api/health` 返回规则/模型/数据结构版本，界面读取真实值 |
| 打包 | 源码包混入 `app/build/web` 与 `.flutter-plugins-dependencies`（含本机路径），清单与实际文件不一致 | 打包器改为流式写入并排除上述文件与 `.metadata`，重新打包后清单哈希与磁盘逐一核对 |
| 启动脚本 | 非本机地址时健康检查指向 127.0.0.1；后台启动失败会留下隐藏进程与 pid 文件 | 健康检查按绑定地址推导，成功后才写 `server.json`，失败清理进程与 pid 文件；`Stop.ps1` 按启动时间校验并删除记录 |
| 文档/依赖 | README 徽章与实测数不一致、`joblib` 未列入 `requirements.txt`、第三方声明缺后端依赖 | 数字以本次实测为准，补齐依赖与声明，实验报告改为按结果数据生成 |

结构重构：`backend/api.py` 由 617 行拆为应用工厂（87 行）+ `backend/routes/` 六个路由模块 + `schemas.py`/`deps.py`/`session.py`/`serializers.py` 公共层；`scope.py` 成为唯一的可见范围实现，删除 `agents.py`、`api.py` 中的重复定义；`workflow_store.py` 移除无调用方的接口并新增 `finish()`；`ml.py` 训练改为 numpy 向量化并对模型缓存设上限。所有改动均有 `tests/test_hardening.py`（10 项）与本轮既有测试覆盖，业务规则、状态机、唯一索引与审计行为保持不变。

已知限制：桌面客户端仅完成静态检查、单元测试与 Release 构建，没有在本轮逐页人工点击；模型与 MCP 仍是规则模式与本地令牌演练，未接入真实供应商；实验数据是 CASAS 与合成数据的离线评估，不代表真实社区效果。

## 历史记录（迁移前 Vue 版本，已由 Flutter 版替代）

- 2026-11-10：修复本地启动入口，新增 `Stop.ps1`；后台隐藏启动、健康轮询、重复启动复用、停止校验均实测通过。
- 2026-11-09 初版：Python 后端 21 项通过约 14 秒；`vue-tsc --noEmit` 通过；Vite 生产构建通过；1440×1080 桌面与 390×844 手机闭环通过；浏览器 JS 错误 0 条。早期机器可读结果已随 Vue 版本清理，仅保留本节文字记录。
