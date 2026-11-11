# 邻安 · 本机完整版

![Flutter](https://img.shields.io/badge/Flutter-3.47.9-02569B?logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12%2B-3776AB?logo=python&logoColor=white)
![Tests](https://img.shields.io/badge/backend%20tests-56%20passed-brightgreen)
![License](https://img.shields.io/badge/license-Apache--2.0-blue)

完整的社区守护闭环、四类业务 Agent、四角色对话助手与可追踪的工作流中心。前后端同仓库运行：FastAPI + SQLite + scikit-learn 提供服务，Flutter 3 提供 Web / Windows / Android 三端界面。

![守护总览](docs/overview.png)

## 目录

- [快速开始](#快速开始)
- [三端入口](#三端入口)
- [走完一次闭环](#走完一次闭环)
- [页面与角色](#页面与角色)
- [验证](#验证)
- [数据与算法](#数据与算法)
- [文件结构](#文件结构)
- [接口摘要](#接口摘要)
- [打包与清理](#打包与清理)

## 快速开始

需要 **Python 3.12+**。首次安装联网拉取 Python 依赖；仓库已带 `app/build/web`，直接运行不需要 Flutter SDK。

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup.ps1
powershell -ExecutionPolicy Bypass -File .\Start.ps1 -Background -OpenBrowser
```

- Web：<http://127.0.0.1:8765>
- 接口文档：<http://127.0.0.1:8765/docs>
- 停止后台服务：`powershell -ExecutionPolicy Bypass -File .\Stop.ps1`
- 重复启动会复用同一个服务；日志在 `runtime/server.stdout.log` 与 `runtime/server.stderr.log`

局域网演示：

```powershell
powershell -ExecutionPolicy Bypass -File .\Start.ps1 -HostAddress 0.0.0.0
```

手机访问电脑的局域网 IP 与 8765 端口，Windows 防火墙需放行；Android 客户端或手机浏览器均可。

### 演示账号

所有账号初始密码均为 **Demo2026!**，只对应虚拟档案。

| 账号 | 角色 | 权限范围 |
|---|---|---|
| `admin` | 社区管理员 | 全部档案、派单、复核、实验、工作流 |
| `staff1`—`staff4` | 照护人员 | 自己的任务、当前关联老人、自己的人员状态 |
| `family` | 家属 | 仅王桂兰的状态、上报与消息 |
| `elder` | 老人本人 | 仅王桂兰的报平安、求助与状态 |

## 三端入口

同一套 `app/lib` Dart 代码，三种运行方式：

| 端 | 启动 | 默认后端 | 说明 |
|---|---|---|---|
| Web | `Start.ps1` 托管 `app/build/web` | 同源 | 无需安装，浏览器直接打开 |
| Windows | `flutter build windows --release` 后运行 `linan_app.exe` | `127.0.0.1:8765` | 桌面窗口，可缩到手机宽度演示 |
| Android | `flutter build apk --release` 安装 APK | `10.0.2.2:8765` | 模拟器地址；真机在登录页改局域网 IP |

登录页的“服务器地址”可保存自定义后端；Web 由 FastAPI 直接托管，因此默认同源。开发调试时后端已开启仅限 localhost 的 CORS。

重建 Web：

```powershell
powershell -ExecutionPolicy Bypass -File .\Setup.ps1 -RebuildFrontend -FlutterExecutable "E:/tools/flutter/bin/flutter.bat"
```

## 走完一次闭环

1. 管理员进入“回放与实验”，选择“三位老人，同时需要关注”；也可演示数据离线、外出、冷启动或资源冲突。
2. 风险事件或老人详情显示信息来源、个人基线、判断依据与建议措施。
3. 在任务中心“计算派单建议”，查看技能、值班状态与仿真到达时间；调整人员必须填写原因。
4. 确认时重新检查任务与人员版本、技能、值班、可用性及占用；旧推荐失效则重新计算。
5. 切换对应 `staffN`：接单 → 开始处理 → 提交处置结果。拒单需说明原因并释放占用。
6. 管理员复核：已确认安全或数据问题已核查才可关闭；未能联系、仍需帮助必须继续跟进。
7. 在任务详情查看风险输入快照、推荐理由、人工调整、审计时间线与 Agent 运行节点。

状态机：`待确认 → 已派单 → 已接单 → 处理中 → 待复核 → 已关闭`。管理员也可直接核实后关闭尚未执行的任务；家属一次报平安不会自动关闭紧急事件。

## 页面与角色

| 角色 | 导航 |
|---|---|
| 管理员（8 页） | 守护总览、老人档案与状态、风险事件、任务中心、人员资源、邻安助手、工作流中心、回放与实验 |
| 照护人员（4 页） | 我的任务、服务对象、我的状态、邻安助手 |
| 家属 / 老人（3 页） | 安心守护、状态记录、邻安助手 |

助手回答附带业务记录引用（老人、事件、任务），点击可跳转；工作流中心展示自动派单开关、三类流程图、Agent 目录与每次运行的全部节点、模式、耗时和输入输出。

## 验证

```powershell
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -FlutterExecutable "E:/tools/flutter/bin/flutter.bat"
```

`Verify.ps1` 依次执行：后端 `pytest` → `flutter analyze` → `flutter test` → `flutter build web --release`。支持 `-BackendOnly`、`-FrontendOnly`、`-Package`、`-InstallFrontendDependencies`；每次验证写入独立的 `runtime/verify/<时间戳>/`，不会覆盖旧记录。

2026-11-11 实测：后端 **56 passed / 16.3s**（1 条 Starlette-httpx 弃用警告）；`flutter analyze` No issues；`flutter test` 1 passed；Web 构建通过；管理员、照护、家属、老人四角色浏览器闭环与权限边界通过。详见 [VERIFICATION.md](docs/VERIFICATION.md)。

浏览器验收重点：SOS 不降级、报平安不关闭紧急事件、10 分钟未回应自动升级、越权 403、照护人员只见自己的任务、任务与人员版本冲突拦截、拒单不循环重派、实验三表与 JSON 一致。

## 数据与算法

- 20 位虚拟老人、4 位工作人员；合成基线与 CASAS Aruba 单住户基线分开标注。
- 每 15 分钟生成因果特征：活动次数、60 分钟滚动次数、距上次活动时长、时段；个人时段基线与 Isolation Forest 联合判断。
- 历史不足 14 天显示“基线学习中”；数据缺失单独显示未知；新档案累计足够历史窗口后，从自己的历史建立模型，训练排除当前待判断窗口。
- 主动求助直接进入紧急人工处理；1 级关注且需电话核实的任务，仅在管理员开启自动派单后才可自动派出，数据未知、优先与紧急任务仍人工确认。
- 人员推荐对全量待派任务按优先级分配；技能、值班、可用性、单人容量为硬约束；确认时复用版本校验。

公开实验的取舍（完整数据见 [EXPERIMENT_REPORT.md](docs/EXPERIMENT_REPORT.md)）：

| 指标 | 固定阈值基线 | 个性化模型 |
|---|---|---|
| 合成社区窗口召回 | 25.0% | **75.0%** |
| 合成社区事件召回 | 100% | 100% |
| CASAS 窗口召回 | 51.2% | 28.7% |
| CASAS 事件召回 | 100% | **45.0%** |
| 紧急任务平均响应 | 55.11 min | **25.67 min** |
| 紧急任务 30 分钟覆盖 | 11.1% | **77.8%** |

**局限**：个性化方法在 CASAS 上的事件召回率 45%，低于固定阈值，不能作为独立安全保障；整体平均响应与 P95 略变差（52.65→52.95、82.35→91.30 分钟），收益集中在紧急任务；开发阶段已查看测试段，非盲测。实验反馈只用于离线复盘与候选模型训练，不自动替换在线模型。

## 文件结构

| 位置 | 内容 |
|---|---|
| `backend/` | 鉴权、SQLite、风险引擎、调度、Agent/工作流、实验与回放 |
| `app/lib/src/` | Flutter 页面、状态层、API 客户端、模型、主题与组件 |
| `app/build/web/` | 已构建的 Web 产物（`Start.ps1` 直接托管） |
| `app/android/`、`app/windows/` | 原生平台工程与构建配置 |
| `scripts/` | 数据流水线、实验、离线训练、源码打包 |
| `tests/` | 后端测试（56 项） |
| `data/` | 标准化窗口、来源清单、实际实验结果 |
| `docs/` | 用户手册、Agent 说明、实验报告、验证记录与截图 |
| `runtime/` | 首次启动生成的数据库、日志、验证结果（不进源码包） |

## 接口摘要

`POST /api/auth/login`、`GET /api/elders`、`POST /api/events`、`GET /api/incidents`、`GET /api/tasks`、`POST /api/dispatch/recommend`、`POST /api/dispatch/confirm`、`POST /api/tasks/{id}/action`、`GET /api/staff`、`POST /api/assistant/messages`、`GET/PUT /api/workflows/settings`、`GET /api/workflows/runs`、`POST /api/experiments/run`、`POST /api/replay/window`、`GET /api/feedback/export`。

接口使用 Bearer 令牌与服务端角色、对象范围校验。SQLite 写入使用 `BEGIN IMMEDIATE`，部分唯一索引保证一人只占用一项执行任务；事件按 ID 去重，历史事件保留但不覆盖更新的当前状态，重启后继续扫描超时。

## 打包与清理

```powershell
powershell -ExecutionPolicy Bypass -File .\Verify.ps1 -Package
```

或直接生成源码包：

```powershell
.\.venv\Scripts\python.exe scripts\package.py
```

输出 `artifacts/linan-source.zip` 与 SHA256 清单。源码包排除 `runtime/`、数据库、会话令牌、`.venv`、`node_modules`、`.dart_tool`、Gradle/CMake 中间产物与 `.symbols` 调试文件，只保留可运行源码、Web 产物、Windows/APK 构建结果与处理后数据。

## 许可

Apache License 2.0，见仓库根目录 [LICENSE](../LICENSE)；第三方组件声明见 [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)。数据集署名与许可见 [README 根文档](../README.md#许可与署名)。
