# 邻安 · LinAn

独居老人社区协同守护智能决策系统（比赛原型）。跑通 **状态上报 → 异常识别 → 风险分级 → 人员推荐 → 自动或人工确认派单 → 处置反馈 → 人工复核关闭** 的完整闭环，并在风险引擎与调度状态机之上提供四类业务 Agent、四角色对话助手和可追踪的工作流中心。

本仓库包含两个可运行版本，业务规则、界面与算法假设保持一致：

| 目录 | 版本 | 技术栈 |
|---|---|---|
| [`linan/`](linan/README.md) | 本机完整版：完整业务闭环、四角色助手、工作流中心、实验回放与验证脚本 | FastAPI + SQLite + scikit-learn / SciPy · Vue 3 + TypeScript + Element Plus + ECharts |
| [`linan-web/`](linan-web/README.md) | 云端公开网页版：同一套界面与规则，每个访客独立演示社区 | Cloudflare Workers + D1 + Drizzle · Vue 3 |

## 快速开始

### 本机完整版（linan/）

需要 **Python 3.12+**，首次安装需联网拉取依赖；包内已带构建好的前端与处理后的公开数据，运行不需要 Node.js、外部大模型 API 或再次下载数据。

```powershell
cd linan
powershell -ExecutionPolicy Bypass -File .\Setup.ps1
powershell -ExecutionPolicy Bypass -File .\Start.ps1 -Background -OpenBrowser
```

打开 <http://127.0.0.1:8765>，接口文档在 <http://127.0.0.1:8765/docs>。也可直接双击 `Start-Linan.cmd`。重建前端时才需要 Node.js 22+：`Setup.ps1 -RebuildFrontend`。

统一验证：`powershell -ExecutionPolicy Bypass -File .\Verify.ps1`（浏览器验收加 `-Browser`，打包加 `-Package`）。

### 云端网页版（linan-web/）

需要 **Node.js 24+**，依赖由 `pnpm-lock.yaml` 固定。

```powershell
cd linan-web
pnpm install --frozen-lockfile
node scripts/build.mjs
node scripts/preview.mjs
```

本地兼容预览为 <http://127.0.0.1:8787>，使用 Node 内置 SQLite 模拟 D1；生产环境部署到 Cloudflare Workers + D1，产物为 `dist/server/index.js`。

## 演示账号

所有账号初始密码均为 **Demo2026!**，只对应虚拟档案。

| 账号 | 角色 | 权限范围 |
|---|---|---|
| `admin` | 社区管理员 | 全部演示档案、派单、复核、实验 |
| `staff1`—`staff4` | 照护人员 | 自己的任务、当前关联服务对象、自己的人员状态 |
| `family` | 家属 | 仅王桂兰的状态、上报与消息 |
| `elder` | 老人本人 | 仅王桂兰的报平安、求助与状态 |

## 项目能力

- **风险识别**：每 15 分钟生成因果特征（活动次数、60 分钟滚动次数、距上次活动时长、时段），个人时段基线与 Isolation Forest 联合判断；历史不足 14 天时显示"基线学习中"，数据缺失表示未知而不是"正常"。
- **人员调度**：按紧急程度与等待时间优先覆盖任务，再最小化本批总仿真到达时间；技能、值班、可用性和单任务容量均为硬约束，确认派单时重新校验版本与占用。
- **Agent 与助手**：大模型只解释证据、查询授权记录并生成建议，风险等级仍由规则与模型决定；每次读取工具和会话历史都重新校验角色与对象权限。
- **可追溯**：风险输入快照、推荐理由、人工调整、操作人与时间均留痕；写入使用 `BEGIN IMMEDIATE` 与部分唯一索引保证一人只占用一项执行任务。
- **可复现**：数据流水线、离线实验、候选模型训练与源码打包脚本齐全，验证结果保留独立日志。

## 数据与已知局限

公开实验基于 CASAS Aruba，按完整日期顺序近似 60% / 20% / 20% 划分，基线只用训练段、森林阈值只用验证段。**当前公开数据结果存在明显局限：个性化方法对注入异常的事件召回率为 45%，低于固定阈值的 100%，不能作为独立安全保障。** 原始报警率不等于误报率，当前为开发评估，不是盲测或真实社区效果。

社区、老人、联系人、工作人员与到达时间矩阵均为合成数据；演示密码与角色体系不能替代真实社区的账户管理和数据授权流程。

## 许可与署名

- 代码以 **Apache License 2.0** 发布，见 [LICENSE](LICENSE)；第三方组件声明见 [linan/THIRD_PARTY_NOTICES.txt](linan/THIRD_PARTY_NOTICES.txt)。
- 数据集：Cook, Diane; Crandall, Aaron; Thomas, Brian. *CASAS Smart Home dataset (aruba, cairo, milan, tulum)* (2025). Zenodo. [DOI:10.5281/zenodo.17180309](https://doi.org/10.5281/zenodo.17180309)，许可 [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。本项目仅使用 Aruba，派生方式与校验值见 `linan/scripts/data_pipeline.py` 与 `linan/data/source_manifest.json`。
