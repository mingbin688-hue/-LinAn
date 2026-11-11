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

## 历史记录（迁移前 Vue 版本，已由 Flutter 版替代）

- 2026-11-10：修复本地启动入口，新增 `Stop.ps1`；后台隐藏启动、健康轮询、重复启动复用、停止校验均实测通过。
- 2026-11-09 初版：Python 后端 21 项通过约 14 秒；`vue-tsc --noEmit` 通过；Vite 生产构建通过；1440×1080 桌面与 390×844 手机闭环通过；浏览器 JS 错误 0 条。早期机器可读结果已随 Vue 版本清理，仅保留本节文字记录。
