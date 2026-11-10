<script setup lang="ts">
type Row = Record<string, any>
defineProps<{ run: Row; compact?: boolean }>()
const statusNames: Record<string, string> = { queued:'等待执行', running:'执行中', waiting_human:'等待人工', completed:'已完成', failed:'执行失败', stale:'业务已更新', cancelled:'已取消' }
const modeNames: Record<string, string> = { rules:'规则模式', llm:'模型模式', fallback:'规则回退' }
const kindNames: Record<string, string> = { risk:'风险响应', review:'处置复核', chat:'对话查询' }
const agentNames: Record<string,string> = {context:'上下文整理',risk:'风险解释',dispatch:'调度建议',review:'处置复核'}
const format = (value: unknown) => typeof value === 'string' ? value : JSON.stringify(value, null, 2)
</script>

<template>
 <section class="agent-run-detail" :class="{compact}">
  <div class="agent-run-heading"><b>{{kindNames[run.kind]||run.kind}}</b><span v-if="run.historical" class="agent-status stale">历史快照 · 版本 {{run.snapshot_version}}</span><span class="agent-status" :class="run.status">{{statusNames[run.status]||run.status}}</span><span class="agent-mode" :class="run.mode">{{modeNames[run.mode]||run.mode||'规则模式'}}</span></div>
  <p v-if="run.historical" class="agent-run-history-note">任务已推进，以下内容保留生成时的判断依据；当前操作请以任务最新状态为准。</p>
  <p class="agent-run-summary">{{run.summary||'流程已建立，等待节点结果。'}}</p>
  <small class="agent-run-id">{{run.id}}</small>
  <div class="agent-node-list">
   <article v-for="(node,index) in run.nodes||[]" :key="node.id||index" data-testid="workflow-node" class="agent-node" :class="node.status">
    <div class="agent-node-number">{{Number(index)+1}}</div>
    <div class="agent-node-body">
     <div class="agent-node-heading"><b>{{node.name}}</b><span class="agent-status" :class="node.status">{{statusNames[node.status]||node.status}}</span></div>
     <div class="agent-node-meta"><span>{{agentNames[node.agent]||node.agent}}</span><span>{{modeNames[node.mode]||node.mode||'规则模式'}}</span><span>{{Math.round(Number(node.elapsed_ms)||0)}} ms</span></div>
     <p>{{node.output?.summary||'等待执行'}}</p>
     <ul v-if="node.output?.actions?.length" class="agent-action-list"><li v-for="(action,n) in node.output.actions" :key="n">{{typeof action==='string'?action:action.label||action.summary||format(action)}}</li></ul>
     <p v-if="node.error||node.output?.fallback_reason" class="agent-node-error">{{node.error||node.output.fallback_reason}}</p>
     <div v-if="node.output?.evidence?.length" class="agent-evidence-tags"><span v-for="(e,n) in node.output.evidence" :key="n">{{typeof e==='string'?e:e.label||e.id}}</span></div>
     <details><summary>查看节点输入与结果</summary><b class="agent-json-label">输入摘要</b><pre>{{format(node.input)}}</pre><b class="agent-json-label">结构化结果</b><pre>{{format(node.output)}}</pre></details>
    </div>
   </article>
  </div>
 </section>
</template>
