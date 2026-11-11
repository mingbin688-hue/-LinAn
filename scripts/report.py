"""Create the human-readable report from measured JSON results."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'data'/'experiment_results.json').read_text(encoding='utf-8'))
text=['# 邻安 · 实际实验报告','',
      '本报告从实际运行结果自动生成。活动识别与社区调度分别评估；不将仿真表现推断为真实社区效果。',
      '', '## 活动异常识别','',
      '数据按完整日期顺序近似60%／20%／20%划分。模型为80棵树的Isolation Forest（随机种子42），森林阈值取验证分数98分位；个人时段无活动90分位阈值只从训练数据学习，并设30分钟下限。两类判据取并集。',
      '', '基线为统一无活动60分钟规则。测试段白天注入不重叠的一小时活动置零情景，重算因果滚动次数和无活动时长。输入特征不使用未来事件或活动标签。', '']
for key,label in [('activity','合成活动数据'),('casas','公开数据 CASAS Aruba')]:
    a=data[key];s=a['split']
    text += [f'### {label}','',f'窗口数量：训练 {s["train"]}，验证 {s["validation"]}，测试 {s["test"]}。','',
             '| 方法 | 原始报警率 | 注入窗口召回 | 注入事件召回 | 已检出事件平均延迟 |',
             '|---|---:|---:|---:|---:|']
    for method,name in [('baseline','统一固定阈值'),('personalized','个人基线＋异常模型')]:
        m=a[method];delay=m['mean_detection_delay_minutes']
        text.append(f'| {name} | {m["original_alarm_rate"]:.2%} | {m["injected_window_recall"]:.2%} | {m["injected_episode_recall"]:.2%} | {delay if delay is not None else "未检出"} 分钟 |')
    text += ['',f'注入事件 {a["baseline"]["total_injected_episodes"]} 个；个人方法检出 {a["personalized"]["detected_episodes"]} 个。','']
text += ['### 结果解释与边界','',
         '- 原始数据没有真实紧急风险标签，因此报警率不能称作误报率。',
         '- 召回率只针对注入的无活动情景；注入位置原先也可能存在自然静止，合成风险标签不等同真实危险。',
         '- 检测延迟从异常起始到首个被检出的15分钟窗口结束计算；未检出事件不计入平均延迟，必须同时看事件召回率。',
         '- 公开数据中个人方法的事件召回率低于固定阈值。它减少报警但漏掉更多该类注入情景，当前版本不能作为独立安全保障。',
         '- 开发阶段已查看过测试段初测结果，当前报告为开发评估；正式效果主张仍需未接触数据独立验证。',
         '- Aruba是一个真实单住户数据源，不能据此主张多老人泛化或真实照护效果。',
         '', '## 社区任务调度仿真','',
         '20项任务、4名工作人员、固定随机种子42。仿真到达时间使用固定楼栋矩阵，单次处置12分钟，两种方法共享相同任务、人员、服务时长和时间轴。比较30分钟覆盖率仅是实验窗口。',
         '', '| 方法 | 全部任务平均响应 | P95响应 | 紧急任务平均响应 | 紧急任务30分钟覆盖 | 约束违反 |',
         '|---|---:|---:|---:|---:|---:|']
for key,label in [('baseline','先到先处理＋最近可用'),('optimized','风险优先＋最小费用匹配')]:
    m=data['scheduling'][key]
    text.append(f'| {label} | {m["mean_response_minutes"]} 分钟 | {m["p95_response_minutes"]} 分钟 | {m["urgent_mean_response_minutes"]} 分钟 | {m["urgent_covered_within_30_minutes"]:.2%} | {m["constraint_violations"]} |')
text += ['', '优化方法优先覆盖紧急任务，提高紧急任务响应，但整体平均和尾部等待未必改善。所有任务最终得到处置；不能仅选紧急指标宣称全面优于基线。',
         '', '## 数据来源与复现','',
         'Cook, Diane; Crandall, Aaron; Thomas, Brian (2025). CASAS Smart Home dataset. [Zenodo DOI:10.5281/zenodo.17180309](https://doi.org/10.5281/zenodo.17180309)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。本项目仅提取Aruba运动传感器ON事件，输出15分钟窗口，为原数据的派生处理。',
         '', '原始归档包含1,719,558行，未解析行0，保留797,981个运动ON事件。时间按采集地墙上时间保留，时区对象仅用于稳定计算，不声称采集地位于上海。',
         '', '完整来源、输入和归档SHA-256见 `data/source_manifest.json`。执行 `python scripts/experiments.py` 后执行 `python scripts/report.py` 可重建本报告；重新构造公开窗口执行 `python scripts/data_pipeline.py`。',
         '', '线上反馈经人工复核关闭后可导出；`scripts/train_model.py` 同步生成候选模型和反馈复盘材料，不会将结果安全直接转换成窗口正常标签，也不会自动替换在线模型。', '']
(ROOT/'docs'/'EXPERIMENT_REPORT.md').write_text('\n'.join(text),encoding='utf-8')
print('docs/EXPERIMENT_REPORT.md')
