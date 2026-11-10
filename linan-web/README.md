# 邻安 · 公开网页版本

可部署至Sites / Cloudflare Workers + D1的公开比赛演示。Vue界面保留，云端API和云端数据库独立于本地电脑运行。

## 使用与边界

任何访客可打开网址并选择演示角色，密码为 `Demo2026!`。每位访客拥有独立云端演示社区；相同浏览器切换管理员、照护人员、家属和老人时共享本次社区，访客之间不互相改数据。角色不是实际社区账户，只使用20位虚拟老人和4位虚拟工作人员。

记录存储于D1，保留Cookie后可恢复。演示空间有效期7天，角色令牌有效期8小时。每个空间最多50位老人、200项任务、700条事件，保留最近200条审计和160条消息；达到上限后提示新建空间。没有真实电话、短信或救援接入。超时在API请求时巡检，无人访问后下一次请求补记。

## 模型与数据一致性

Python离线导出20个个人模型及CASAS Aruba模型的数值树，云端执行森林推理；已用52个窗口与Python评分和分类对照。导出过程在 `scripts/export_models.py`，Python原版在相邻 `linan/` 项目。

调度按紧急程度、等待时间选择可覆盖任务，以最多4位工作人员的动态规划精确最小化本批仿真到达时间，目标和约束与Python版本一致。实验页读取随机种子42的已运行Python离线报告，不宣称云端重新训练。公开数据注入异常事件召回率仍为45%，完整保留局限。

D1表 `demo_rooms` 持久化社区状态和版本。写入通过 `WHERE version=?` 原子条件更新，冲突后重读并重新检查，防止并发双重占用。演示空间密钥使用HttpOnly、SameSite Cookie，数据库只保存其SHA-256；角色令牌也哈希保存并绑定空间。服务端执行角色和关联范围检查，拒绝跨站写入。演示角色不能代替真实社区授权体系。

## 构建、迁移与发布

需要Node.js 24+，依赖由 `pnpm-lock.yaml` 固定。

```powershell
pnpm install --frozen-lockfile
node scripts/build.mjs
node --test tests/cloud.test.mjs
node scripts/preview.mjs
```

本地兼容预览为 http://127.0.0.1:8787，使用Node内置SQLite模拟D1；生产使用云端D1。构建先检查TypeScript、编译Vue，再生成含页面、模型和API的ESM Worker。产物为 `dist/server/index.js`，托管声明在 `.openai/hosting.json`。

表结构由 `db/schema.ts` 和Drizzle迁移管理。变更后执行 `pnpm db:generate` 追加迁移，不修改已应用历史。迁移打包到 `.openai/drizzle`，请求中不执行DDL。

通过Sites源码仓库、保存版本、正式部署流程发布，复用清单现有项目ID。禁止上传runtime、本地数据库、会话或密钥。

## 来源

Cook, Diane; Crandall, Aaron; Thomas, Brian (2025). *CASAS Smart Home dataset.* [DOI:10.5281/zenodo.17180309](https://doi.org/10.5281/zenodo.17180309)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。仅使用Aruba，派生为15分钟窗口与已导出模型。人物、联系方式、人员和到达时间矩阵均为合成数据。
