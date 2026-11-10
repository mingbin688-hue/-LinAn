# 邻安项目指令

邻安是使用虚拟社区档案的比赛原型。后端为 FastAPI、SQLite、scikit-learn；前端为 Vue 3、TypeScript、Element Plus。业务 Agent 在现有风险引擎和调度状态机之上提供编排与解释。

## 工作入口

- 后端：`backend/api.py`（鉴权与接口）、`engine.py`（风险和任务状态机）、`scheduler.py`（人员匹配）。
- 前端：`frontend/src/`；构建产物 `frontend/dist/` 随源码交付。
- 测试：`tests/test_*.py`；浏览器验收使用临时数据库，不能指向用户正在使用的数据库。
- 运行数据、令牌和模型产物保存在 `runtime/`，不纳入交付包。
- Agent 配置、演示步骤和模型环境变量见 `docs/AGENT_WORKFLOWS.md`。

## 启动与验证

首次安装执行 `powershell -ExecutionPolicy Bypass -File .\Setup.ps1`；需要重建前端时加 `-RebuildFrontend`。日常启动用 `Start-Linan.cmd`，或 `Start.ps1 -Background -OpenBrowser`。

统一验证：`powershell -ExecutionPolicy Bypass -File .\Verify.ps1`。浏览器验收加 `-Browser`；打包加 `-Package`。脚本在项目的 `.venv` 与原工作区 `..\..\work\.venv` 中查找 Python；也可通过 `-PythonExecutable` 指定。

前端验证需要本地 `frontend/node_modules`；缺少时用 `Verify.ps1 -InstallFrontendDependencies` 按锁文件安装。使用 `-BackendOnly` 或 `-FrontendOnly` 可做针对性验证。测试临时目录统一放在 `runtime/verify/`，避免沙箱默认临时目录权限差异。每次验证保留独立日志与结果，不能把旧文档的通过记录当成本次结果。

## 必须保留的业务行为

- 主动求助直接进入紧急人工处理，报平安、外出确认和模型文字不能降低未关闭的紧急事件。
- 数据缺失表示未知；历史不足时显示学习中，不生成虚构成熟基线。
- 风险等级由现有规则和模型判断；大模型只能解释证据、查询授权记录和生成建议。
- 仅管理员开启后，1级关注且需电话核实的待派任务可以自动派单。数据未知、优先和紧急任务、复核关闭仍由管理员确认。
- 人员推荐必须对全量待派任务按优先级分配；确认派单复用版本、技能、值班、可用性和单任务容量校验，保持 `BEGIN IMMEDIATE` 与唯一索引约束。
- 拒单和人工继续跟进后不循环自动重派；模型调用不得持有 SQLite 写事务。
- 每次读取助手工具与会话历史均重验角色和对象权限。家属、老人只访问关联对象；照护人员只访问自己的任务与当前关联老人。
- 保留事件去重、重启恢复和审计；候选模型离线训练，不自动替换在线模型。

## 协作与交付

按实际任务选择后端、前端、验证角色；独立部分可以委派给项目角色 Agent，主 Agent 负责接口约定和集成。不要让两个 Agent 同时修改同一文件。修改业务规则或接口时补充有实际行为断言的测试；验证角色报告发现和证据，不擅自扩大实现范围。

保留用户数据库和当前服务。需要运行验收服务时启动自己的临时实例并只停止自己启动的进程。源码包输出 `artifacts/linan-source.zip`；凭证、会话、数据库、缓存、依赖和打包产物本身必须排除。交付说明区分规则模式、模拟模型验证和真实供应商联调。
