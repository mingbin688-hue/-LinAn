<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { ChatLineRound, Connection, ArrowRight, Refresh, Promotion, Plus } from '@element-plus/icons-vue'
import AgentRunDetail from './AgentRunDetail.vue'

type Row = Record<string, any>
type Citation = { type: string; id: string | number; label: string; elder_id?: number; task_id?: string }
type Message = { role: 'user' | 'assistant'; content: string; citations?: Citation[]; mode?: string; fallback_reason?: string; created?: number }
const props = defineProps<{ view: 'assistant' | 'workflows'; active: boolean; user: Row; elders: Row[]; tasks: Row[]; api: (path:string,options?:RequestInit)=>Promise<any> }>()
const emit = defineEmits<{ navigate: [citation: Citation]; changed: [] }>()
const catalogue = ref<Row>({agents:[],mode:'rules',configured:false})
const settings = ref({auto_dispatch:false}), settingsReady=ref(false), saving=ref(false)
const runs=ref<Row[]>([]), chosenRun=ref<Row|null>(null), runFilter=ref('all'), statusFilter=ref('all'), runLoading=ref(false), loadError=ref('')
const messages=ref<Message[]>([]), draft=ref(''), sessionId=ref<string>(), sending=ref(false), selectedElder=ref<number>(), selectedTask=ref<string>(), chatError=ref(''), chatList=ref<HTMLElement>()
const runDrawer=ref(false), detailLoading=ref(false)
let chatEpoch=0
const compact=computed(()=>['family','elder'].includes(props.user.role))
const modeNames: Record<string,string> = {rules:'规则模式',llm:'模型模式',fallback:'规则回退'}
const kindNames: Record<string,string> = {risk:'风险响应',review:'处置复核',chat:'对话查询'}
const statusNames: Record<string,string> = {queued:'等待执行',running:'执行中',waiting_human:'等待人工',completed:'已完成',failed:'执行失败',stale:'业务已更新',cancelled:'已取消'}
const filteredRuns=computed(()=>runs.value.filter(r=>(runFilter.value==='all'||r.kind===runFilter.value)&&(statusFilter.value==='all'||r.status===statusFilter.value)))
const suggestions=computed(()=>props.user.role==='admin'?['今天有哪些需要关注的老人？','王桂兰现在的状态如何？','有哪些待处理任务？']:props.user.role==='staff'?['我的待办任务有哪些？','服务对象现在的状态如何？','下一步该怎么处理？']:props.user.role==='family'?['王桂兰现在的状态如何？','为什么需要关注？','家属下一步可以做什么？']:['我现在的状态怎么样？','社区正在为我做什么？','我该怎么报平安？'])
const contextTasks=computed(()=>props.tasks.filter(t=>!selectedElder.value||t.elder_id===selectedElder.value))
const formatTime=(stamp:number)=>stamp?new Date(stamp*1000).toLocaleString('zh-CN',{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'}):'—'
const workflows=[
 {kind:'risk',name:'风险响应',description:'先按业务规则处理，再生成解释。',steps:['状态与风险判断','统一人员调度','自动派单 / 人工确认','生成风险解释']},
 {kind:'review',name:'处置复核',description:'反馈有摘要，关闭有人工复核。',steps:['接收处置反馈','整理经过与证据','指出未解决问题','等待管理员复核']},
 {kind:'chat',name:'对话查询',description:'回答来自当前身份可查看的记录。',steps:['核验身份与范围','查询授权记录','整理结论与依据','返回回答与入口']}
]

async function loadCatalogue(){try{catalogue.value=await props.api('/agents');loadError.value=''}catch(e){loadError.value=(e as Error).message}}
async function loadWorkflows(quiet=false){
 if(props.user.role!=='admin')return
 if(!quiet)runLoading.value=true
 try{
  const [s,r]=await Promise.all([props.api('/workflows/settings'),props.api('/workflows/runs')])
  if(!saving.value)settings.value={auto_dispatch:!!s.auto_dispatch}
  settingsReady.value=true;runs.value=Array.isArray(r)?r:r.items||[];loadError.value=''
  if(runDrawer.value&&chosenRun.value)chosenRun.value=await props.api('/workflows/runs/'+chosenRun.value.id)
 }catch(e){if(!quiet)loadError.value=(e as Error).message}finally{runLoading.value=false}
}
async function changeAutoDispatch(value:unknown){
 const previous=!Boolean(value);saving.value=true
 try{settings.value=await props.api('/workflows/settings',{method:'PUT',body:JSON.stringify({auto_dispatch:Boolean(value)})});ElMessage.success(settings.value.auto_dispatch?'关注级电话核实自动派单已开启':'自动派单已关闭');await loadWorkflows(true);emit('changed')}
 catch(e){settings.value.auto_dispatch=previous;ElMessage.error((e as Error).message)}finally{saving.value=false}
}
async function showRun(run:Row){
 detailLoading.value=true;runDrawer.value=true;chosenRun.value=null
 try{chosenRun.value=await props.api('/workflows/runs/'+run.id)}catch(e){ElMessage.error((e as Error).message);runDrawer.value=false}finally{detailLoading.value=false}
}
async function scrollChat(){await nextTick();chatList.value?.scrollTo({top:chatList.value.scrollHeight,behavior:'smooth'})}
async function send(text?:string){
 const message=(text||draft.value).trim();if(!message||sending.value)return
 const requestEpoch=chatEpoch
 draft.value='';chatError.value='';messages.value.push({role:'user',content:message});sending.value=true;await scrollChat()
 try{
  const answer=await props.api('/assistant/messages',{method:'POST',body:JSON.stringify({message,...(sessionId.value?{session_id:sessionId.value}:{}),...(selectedElder.value?{elder_id:selectedElder.value}:{}),...(selectedTask.value?{task_id:selectedTask.value}:{})})})
  if(requestEpoch!==chatEpoch)return
  sessionId.value=answer.session_id
  messages.value.push({role:'assistant',content:answer.reply,citations:answer.citations||[],mode:answer.mode,fallback_reason:answer.fallback_reason,created:Date.now()/1000})
 }catch(e){if(requestEpoch===chatEpoch)chatError.value=(e as Error).message}finally{if(requestEpoch===chatEpoch){sending.value=false;await scrollChat()}}
}
function newConversation(){if(sending.value)return;chatEpoch++;messages.value=[];sessionId.value=undefined;chatError.value='';draft.value='';selectedTask.value=undefined;selectedElder.value=undefined}
async function refreshAll(){await loadCatalogue();if(props.view==='workflows')await loadWorkflows()}
watch(selectedElder,()=>{selectedTask.value=undefined})
watch(()=>props.elders.map(e=>e.id).sort().join(',')+'|'+props.tasks.map(t=>t.id).sort().join(','),()=>{
 if(props.user.role==='staff'&&(messages.value.length||sending.value)){
  chatEpoch++;messages.value=[];sessionId.value=undefined;sending.value=false;selectedTask.value=undefined;selectedElder.value=undefined
  chatError.value='当前关联任务已变化，已清除先前对话。请重新提问。'
 }
})
watch(()=>props.active,active=>{if(active)refreshAll()})
watch(()=>props.view,view=>{if(props.active&&view==='workflows')loadWorkflows()})
let poll:ReturnType<typeof setInterval>
onMounted(()=>{if(props.active)refreshAll();poll=setInterval(()=>{if(props.active&&props.view==='workflows'&&!saving.value)loadWorkflows(true)},5000)})
onUnmounted(()=>clearInterval(poll))
</script>

<template>
 <div class="agent-workspace" :class="{'agent-simple':compact}">
  <template v-if="view==='assistant'">
   <section class="panel assistant-panel">
    <div class="assistant-header"><div class="assistant-symbol"><el-icon><ChatLineRound/></el-icon></div><div><h2>{{compact?'邻安关怀助手':'邻安协同助手'}}</h2><p>{{compact?'一起了解当前状态和社区跟进情况。':'查询状态、解释风险，找到下一步该做的事。'}}</p></div><span class="agent-mode" :class="catalogue.mode">{{modeNames[catalogue.mode]||'规则模式'}}</span></div>
    <div class="assistant-scope"><i class="dot green-dot"/><span>{{user.role==='admin'?'当前身份可查询全社区记录':user.role==='staff'?'仅查询你的任务与当前关联服务对象':'仅查询本人或关联老人的守护记录'}}</span></div>
    <div v-if="!compact" class="assistant-context"><el-select v-model="selectedElder" placeholder="全部授权服务对象" clearable aria-label="助手关联老人"><el-option v-for="elder in elders" :key="elder.id" :label="elder.name" :value="elder.id"/></el-select><el-select v-model="selectedTask" placeholder="选择关联任务（可选）" clearable aria-label="助手关联任务"><el-option v-for="task in contextTasks" :key="task.id" :label="task.elder_name+' · '+task.title" :value="task.id"/></el-select><el-button :icon="Plus" :disabled="sending" @click="newConversation">新对话</el-button></div>
    <div ref="chatList" class="assistant-chat" role="log" aria-label="助手对话记录" aria-live="polite" :aria-busy="sending">
     <div v-if="!messages.length" class="assistant-welcome"><span class="eyebrow green">CARE WITH EVIDENCE</span><h3>{{compact?'有什么想了解的？':'让每一个判断，都能找到依据。'}}</h3><p>{{catalogue.configured?'模型已配置，回答会结合授权业务记录。':'当前使用规则助手，离线也能查询状态、风险和任务。'}}</p><div class="assistant-suggestions"><button v-for="question in suggestions" :key="question" @click="send(question)" :disabled="sending">{{question}}<el-icon><ArrowRight/></el-icon></button></div></div>
     <article v-for="(message,index) in messages" :key="index" class="assistant-message" :class="message.role" :data-testid="message.role==='assistant'?'assistant-reply':undefined"><div class="assistant-message-label">{{message.role==='user'?'我':'邻安助手'}}<span v-if="message.mode" class="agent-mode" :class="message.mode">{{modeNames[message.mode]||message.mode}}</span></div><p>{{message.content}}</p><p v-if="message.fallback_reason" class="assistant-fallback">{{message.fallback_reason}}</p><div v-if="message.citations?.length" class="assistant-citations"><span>回答依据</span><button v-for="(citation,n) in message.citations" :key="n" @click="emit('navigate',citation)">{{citation.label||citation.id}}<el-icon><ArrowRight/></el-icon></button></div></article>
     <div v-if="sending" class="assistant-thinking">正在核对当前可查看的记录…</div>
     <div v-if="chatError" class="assistant-error" role="alert">{{chatError}}<span>请检查后重新发送；若数据权限发生变化，可新建对话。</span></div>
    </div>
    <form class="assistant-composer" @submit.prevent="send()"><el-input data-testid="assistant-input" v-model="draft" type="textarea" :rows="compact?3:2" :maxlength="2000" placeholder="例如：王桂兰现在的状态如何？" aria-label="向邻安助手提问" resize="none" :disabled="sending"/><div><span>助手提供查询和解释；报平安、求助和处置请使用对应按钮。</span><el-button type="primary" :icon="Promotion" data-testid="assistant-send" native-type="submit" :loading="sending" :disabled="!draft.trim()">发送</el-button></div></form>
   </section>
   <p v-if="loadError" class="agent-load-error" role="alert">{{loadError}} <button @click="refreshAll">重新加载</button></p>
  </template>

  <template v-else-if="user.role==='admin'">
   <section class="panel workflow-control"><div><span class="eyebrow green">HUMAN + AGENTS</span><h2>让协同过程看得见</h2><p>自动派单仅覆盖 1 级关注的电话核实任务。数据未知、优先和紧急任务仍等待管理员确认。</p></div><div class="workflow-toggle"><label for="auto-dispatch">关注级电话核实自动派单</label><el-switch data-testid="auto-dispatch-switch" id="auto-dispatch" v-model="settings.auto_dispatch" :disabled="!settingsReady||saving" :loading="saving" active-text="已开启" inactive-text="已关闭" @change="changeAutoDispatch"/><small>默认关闭 · 设置保存在本机</small></div></section>
   <div class="workflow-map-grid"><section v-for="flow in workflows" :key="flow.kind" class="panel workflow-map"><h3>{{flow.name}}</h3><p>{{flow.description}}</p><ol><li v-for="(step,index) in flow.steps" :key="step"><b>{{index+1}}</b><span>{{step}}</span><el-icon v-if="index<flow.steps.length-1"><ArrowRight/></el-icon></li></ol></section></div>
   <div class="agent-catalogue"><article v-for="agent in catalogue.agents" :key="agent.id" class="agent-card"><span class="agent-card-icon"><el-icon><Connection/></el-icon></span><div><h3>{{agent.name}}</h3><p>{{agent.description}}</p></div></article></div>
   <section class="panel workflow-history"><div class="panel-title"><div><h3>工作流运行记录 <span class="section-count">{{runs.length}}</span></h3><p>查看节点输入、结果、运行模式与等待人工处理的原因</p></div><el-button :icon="Refresh" :loading="runLoading" @click="loadWorkflows()">刷新记录</el-button></div><div class="workflow-filters"><el-select v-model="runFilter" aria-label="筛选工作流类型"><el-option label="全部工作流" value="all"/><el-option v-for="(name,key) in kindNames" :key="key" :label="name" :value="key"/></el-select><el-select v-model="statusFilter" aria-label="筛选运行状态"><el-option label="全部状态" value="all"/><el-option v-for="(name,key) in statusNames" :key="key" :label="name" :value="key"/></el-select></div><p v-if="loadError" class="agent-load-error" role="alert">{{loadError}}</p><div class="workflow-run-list"><button v-for="run in filteredRuns" :key="run.id" class="workflow-run-row" @click="showRun(run)"><div class="workflow-run-type"><el-icon><Connection/></el-icon><b>{{kindNames[run.kind]||run.kind}}</b></div><div class="workflow-run-copy"><b>{{run.summary||'等待节点执行'}}</b><small>{{run.id}} · {{formatTime(run.created)}}</small></div><div class="workflow-run-badges"><span class="agent-status" :class="run.status">{{statusNames[run.status]||run.status}}</span><span class="agent-mode" :class="run.mode">{{modeNames[run.mode]||run.mode}}</span></div><el-icon class="workflow-run-arrow"><ArrowRight/></el-icon></button></div><el-empty v-if="!filteredRuns.length&&!runLoading" description="暂无此类运行记录；上报事件或使用助手后可在此查看"/></section>
   <el-drawer v-model="runDrawer" title="工作流运行详情" size="min(730px,96vw)"><p v-if="detailLoading" class="muted">正在加载节点结果…</p><AgentRunDetail v-if="chosenRun" :run="chosenRun"/></el-drawer>
  </template>
 </div>
</template>

<style src="./agent.css"></style>

<style>
.agent-run-detail>.agent-run-history-note{padding:10px 12px;background:#f3f0e3;color:#9b8b58;font-size:11px;line-height:1.9;border-radius:6px}
</style>
