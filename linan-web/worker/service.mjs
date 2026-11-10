import {assign} from './scheduler.mjs';
import {evaluateModel} from './model.mjs';
export const ACTIVE=['dispatched','accepted','processing'];
export const now=()=>Date.now()/1000;
export const uid=p=>p+'-'+crypto.randomUUID().replaceAll('-','').slice(0,12);
export const fail=(status,message)=>{const e=new Error(message);e.status=status;throw e};
export const get=(rows,id)=>rows.find(r=>r.id===id)||fail(404,'记录不存在');
export const audit=(s,actor,action,entity_id,payload)=>{s.audit.push({id:uid('AU'),actor,action,entity_id,payload,created:now()});s.audit=s.audit.slice(-200)};
export function notify(s,title,body,role='admin',elder_id=null,staff_id=null){s.notifications.unshift({id:uid('NT'),title,body,role,elder_id,staff_id,created:now()});s.notifications=s.notifications.slice(0,160)}
const names=['王桂兰','李建国','张秀英','陈文华','刘淑珍','赵德明','周玉芳','吴志远','徐惠琴','孙福安','胡美玲','朱永康','高月娥','林振华','何秋菊','郭长青','马桂芬','罗文清','梁瑞莲','郑国祥'];
export function seed(models){
 const at=now(),s={elders:[],staff:[],incidents:[],tasks:[],events:[],audit:[],feedback:[],notifications:[],recommendations:[],sessions:[],experiment:null,last_tick:at};
 for(let id=1;id<=20;id++)s.elders.push({id,name:names[id-1],age:69+id%17,building:`${1+Math.floor((id-1)/4)}号楼 · ${101+(id-1)%4*100}`,contact:`演示联系人 ${id}`,version:1,
  profile:{routine:'通常07:00起床，22:00休息',checkin_hour:9,history_days:30,activity_scale:Math.round((.8+id*.035)*1000)/1000,origin:'synthetic',note:'虚拟演示档案，合成个人基线'},
  state:{online:true,last_seen:at,last_checkin:at,last_contact:at,presence:'home',presence_until:0,unreachable:false,count15:12,count60:48,gap:3,anomaly_streak:0,anomaly:false,score:0,evidence:[],observed_at:at,source:'合成演示数据'}});
 const specs=[['陈晓',['phone','visit','device'],1],['林悦',['phone','visit'],3],['赵海',['phone','device'],5],['许宁',['phone','visit'],2]];
 s.staff=specs.map(([name,skills,location],i)=>({id:i+1,name,skills,location,on_duty:1,available:1,version:1}));
 for(const [elder_id,kind,payload] of [[1,'missed_checkin',{}],[2,'activity',{count15:0,count60:0,gap:180}],[3,'sos',{}]])ingest(s,'system',{id:uid('SEED'),elder_id,kind,payload,source:'合成演示数据'},models);
 return s;
}
export function visibleIds(s,u){return u.role==='admin'?s.elders.map(e=>e.id):u.role==='staff'?[...new Set(s.tasks.filter(t=>t.staff_id===u.staff_id&&t.state!=='closed').map(t=>t.elder_id))]:[u.elder_id]}
export function scope(s,u,id){if(!visibleIds(s,u).includes(id))fail(403,'无权访问此老人记录')}
export const requireAdmin=u=>{if(u.role!=='admin')fail(403,'需要社区管理员权限')};
export const requireOperator=u=>{if(!['admin','staff'].includes(u.role))fail(403,'需要社区工作人员权限')};
export function workers(s){return s.staff.map(w=>{const task=s.tasks.find(t=>t.staff_id===w.id&&ACTIVE.includes(t.state));return {...w,busy:!!task,active_task:task?.id||null}})}
export function decorateElder(s,e){const i=s.incidents.filter(i=>i.elder_id===e.id&&i.status==='open').sort((a,b)=>b.level-a.level);return {...e,level:i.length?Math.max(...i.map(i=>i.level)):-1,data_unknown:i.some(i=>i.category==='data'),incident_count:i.length,latest_incident:i[0]?.id||null}}
export function decorateTask(s,t){const i=get(s.incidents,t.incident_id),e=get(s.elders,t.elder_id);return {...t,elder_name:e.name,title:i.title,category:i.category,evidence:i.evidence,advice:i.advice,staff_name:s.staff.find(w=>w.id===t.staff_id)?.name||null}}
export function incident(s,eid,category,level,title,evidence,advice,actor='system',at=now()){
 const e=get(s.elders,eid),old=s.incidents.find(i=>i.elder_id===eid&&i.category===category&&i.status==='open');
 const snapshot={level,evidence,rule_version:'risk-rules-v1',model_version:'iforest-personal-v1-edge',input_snapshot:structuredClone({elder_id:eid,profile:e.profile,state:e.state,assessed_at:at})};
 if(old){
  if(level<old.level)return;
  if(old.level===level&&old.title===title&&JSON.stringify(old.evidence)===JSON.stringify(evidence))return;
  if(level>old.level){const t=s.tasks.find(t=>t.incident_id===old.id);t.level=level;t.required_skill=level>=2?'visit':'phone';t.due=Math.min(t.due,at+({1:1800,2:600,3:120}[level]));t.version++;t.updated=at;t.overdue=0;
   if(t.staff_id&&!get(s.staff,t.staff_id).skills.includes(t.required_skill)){t.state='pending';t.staff_id=null}
   notify(s,'风险等级已升级',title,'admin',eid);
  }
  Object.assign(old,{level,title,evidence,advice,updated:at});audit(s,actor,'risk_updated',old.id,snapshot);return;
 }
 if(s.tasks.length>=200)fail(409,'当前演示空间记录已满，请建立新的演示空间');
 const i={id:uid('EV'),elder_id:eid,category,level,title,evidence,advice,status:'open',created:at,updated:at,model_version:'iforest-personal-v1-edge'};s.incidents.push(i);
 s.tasks.push({id:uid('TK'),incident_id:i.id,elder_id:eid,level,state:'pending',required_skill:category==='data'?'device':level>=2?'visit':'phone',staff_id:null,created:at,updated:at,due:at+({0:600,1:1800,2:600,3:120}[level]),overdue:0,version:1});
 audit(s,actor,'risk_created',i.id,snapshot);notify(s,title,advice,'admin',eid);notify(s,'有一条状态需要核实',title,'family',eid);notify(s,'请确认当前状态',advice,'elder',eid);
}
export function evaluate(s,eid,reason='',actor='system',at=now()){
 const e=get(s.elders,eid),v=e.state,p=e.profile,presence=v.presence_until>at?v.presence:'unknown';
 const pending=s.incidents.find(i=>i.elder_id===eid&&i.category==='safety'&&i.status==='open'&&i.level===1);
 const unanswered=!!pending&&at-pending.created>=600&&v.last_contact<pending.created;
 if(!v.online||at-v.last_seen>1800)incident(s,eid,'data',0,'活动数据暂不可用',['数据源离线或超过30分钟未提供约定的活动窗口','信息缺失不能推断当前安全'],'核查数据来源，并保留人工联系渠道',actor,at);
 if(reason==='sos')incident(s,eid,'safety',3,'老人主动求助',['收到主动求助信息','主动求助直接进入紧急人工处理'],'立即联系老人并提醒社区负责人启动人工紧急处置',actor,at);
 else if(reason==='need_help'||v.unreachable||unanswered)incident(s,eid,'safety',2,'需要优先联系核实',[unanswered?'核实请求已超过10分钟未获回应（演示规则）':'人工报告需要帮助或核实未获回应',...v.evidence],'优先电话联系，必要时安排上门走访',actor,at);
 else if(!['away','rest'].includes(presence)){
  const day=Math.floor((at+8*3600)/86400)*86400-8*3600,due=day+p.checkin_hour*3600;
  if(reason==='missed_checkin'||(v.last_checkin<due&&at>due+3600))incident(s,eid,'safety',1,'未按约定报平安',['今日约定的报平安尚未收到','尚未取得外出或休息确认'],'请求老人确认状态，并通知关联家属协助核实',actor,at);
  else if(v.online&&at-v.last_seen<=1800&&v.anomaly)incident(s,eid,'safety',1,'活动规律出现偏离',v.evidence,'先核实当前状态；持续异常且未回应时升级处理',actor,at);
 }
}
export function tick(s,at=now()){
 for(const e of s.elders)evaluate(s,e.id,'','system',at);
 for(const t of s.tasks)if(t.state!=='closed'&&!t.overdue&&t.due<at){t.overdue=1;notify(s,'任务已超时，请跟进',t.id,'admin',t.elder_id);audit(s,'system','task_overdue',t.id,{state:t.state,due:t.due})}
 s.last_tick=at;
}
const KINDS=['activity','safe','contact','sos','away','home','rest','need_help','unreachable','data_offline','data_online','missed_checkin'];
export function ingest(s,actor,input,models){
 const event={id:input.id||uid('IN'),source:'人工上报',payload:{},...input};
 if(typeof event.id!=='string'||event.id.length>100||!event.id.length||!KINDS.includes(event.kind))fail(422,'事件编号或类型无效');
 const e=get(s.elders,event.elder_id),old=s.events.find(x=>x.id===event.id);if(old){if(old.elder_id!==event.elder_id)fail(409,'事件编号已被使用');return {id:event.id,duplicate:true}}
 if(s.events.length>=700)fail(409,'当前演示空间已达到700条事件，请新建演示空间');
 const at=event.observed_at??now(),p=event.payload||{},kind=event.kind;
 if(typeof at!=='number'||!Number.isFinite(at)||at<=0||at>now()+30)fail(422,'观察时间无效');
 if(typeof event.source!=='string'||event.source.length>80||JSON.stringify(p).length>4000)fail(422,'来源或上报内容过长');
 if(p.hours!==undefined&&(typeof p.hours!=='number'||!Number.isFinite(p.hours)||p.hours<=0||p.hours>24))fail(422,'有效期需为0到24小时');
 if(kind==='activity'){
  for(const k of ['count15','count60','gap'])if(typeof p[k]!=='number'||!Number.isFinite(p[k])||p[k]<0||p[k]>100000)fail(422,'活动窗口需包含有效count15、count60、gap');
  if(p.count60<p.count15)fail(422,'60分钟活动数不能小于15分钟活动数');
 }
 s.events.push({...event,actor,observed_at:at,received_at:now()});
 if(at<e.state.observed_at){audit(s,actor,'historical_event',event.id,{kind,observed_at:at});return {id:event.id,duplicate:false,historical:true}}
 const v=e.state;v.observed_at=at;e.version++;
 if(kind==='activity'){
  Object.assign(v,{count15:p.count15,count60:p.count60,gap:p.gap,online:true,last_seen:at,source:event.source,model_timestamp:p.original_timestamp||at});
  const model=e.profile.origin==='CASAS Aruba replay'?models.casas:models[String(e.id)];
  const result=e.profile.history_days>=14&&model?evaluateModel(model,{timestamp:p.original_timestamp||at,count15:p.count15,count60:p.count60,gap:p.gap},e.profile.origin):{anomaly:false,score:0,evidence:['基线学习中；云端仅推理已导出的个人模型，保留人工核实与报平安规则']};
  Object.assign(v,result);v.anomaly_streak=result.anomaly?v.anomaly_streak+1:0;
 }else if(kind==='safe')Object.assign(v,{last_checkin:at,last_contact:at,unreachable:false});
 else if(['away','home','rest'].includes(kind))Object.assign(v,{presence:kind,presence_until:at+(p.hours||4)*3600,last_contact:at,unreachable:false});
 else if(kind==='unreachable')v.unreachable=true;
 else if(kind==='data_offline')v.online=false;
 else if(kind==='data_online')Object.assign(v,{online:true,last_seen:at});
 else if(kind==='missed_checkin')v.last_checkin=at-86400;
 audit(s,actor,'event_received',event.id,{kind,source:event.source,payload:p,observed_at:at});
 if(kind==='contact')incident(s,e.id,'safety',1,'老人请求联系',['收到老人请求联系的上报'],'安排电话联系，了解具体需求',actor);
 evaluate(s,e.id,kind,actor);return {id:event.id,duplicate:false};
}
export function recommend(s,actor){
 const pending=s.tasks.filter(t=>t.state==='pending'),matched=assign(pending,workers(s));
 const results=matched.map(m=>{const t=get(s.tasks,m.task_id),w=get(s.staff,m.staff_id),r={...m,id:uid('REC'),staff_name:w.name,task_version:t.version,staff_version:w.version,created:now(),level:t.level,snapshot:structuredClone({task:t,staff:w,reason:m.reason,travel_origin:'synthetic-fixed-matrix'})};s.recommendations.push(r);return r});
 s.recommendations=s.recommendations.slice(-80);audit(s,actor,'dispatch_recommended','batch',{recommendations:results.map(r=>({task_id:r.task_id,staff_id:r.staff_id,eta:r.eta})),rule_version:'lexicographic-match-v1'});
 return {recommendations:results,unassigned:pending.filter(t=>!results.some(r=>r.task_id===t.id)).map(t=>t.id)};
}
export function confirm(s,actor,body){
 const rec=get(s.recommendations,body.recommendation_id),t=get(s.tasks,rec.task_id),chosen=body.staff_id||rec.staff_id,w=get(s.staff,chosen);
 if(now()-rec.created>300||t.state!=='pending'||t.version!==rec.task_version)fail(409,'任务或推荐已变化，请重新计算');
 if(chosen!==rec.staff_id&&String(body.reason||'').trim().length<2)fail(422,'调整人员时请填写原因');
 if(chosen===rec.staff_id&&w.version!==rec.staff_version)fail(409,'人员状态已变化，请重新计算');
 if(!w.on_duty||!w.available||s.tasks.some(t=>t.staff_id===chosen&&ACTIVE.includes(t.state)))fail(409,'人员不在岗、不可用或已有任务');
 if(!w.skills.includes(t.required_skill))fail(409,'人员不具备所需技能');
 Object.assign(t,{state:'dispatched',staff_id:chosen,updated:now(),version:t.version+1});audit(s,actor,'dispatch_confirmed',t.id,{recommendation:rec.snapshot,chosen_staff:chosen,adjustment_reason:body.reason||''});notify(s,'收到新的守护任务',t.id,'staff',t.elder_id,chosen);return {id:t.id,state:t.state};
}
export function action(s,u,id,body){
 const t=get(s.tasks,id),current=t.state,kind=body.action,note=String(body.note||''),outcome=body.outcome||'';
 if(u.role==='staff'&&t.staff_id!==u.staff_id)fail(403,'仅任务负责人可操作');
 if(['close','followup'].includes(kind))requireAdmin(u);
 let next;
 if(kind==='accept'&&current==='dispatched')next='accepted';
 else if(kind==='start'&&current==='accepted')next='processing';
 else if(kind==='reject'&&['dispatched','accepted'].includes(current)){if(note.trim().length<2)fail(422,'请填写拒单原因');next='pending';t.staff_id=null}
 else if(kind==='feedback'&&['accepted','processing'].includes(current)){
  if(!['safe','needs_help','unreachable','data_issue'].includes(outcome)||note.trim().length<2)fail(422,'请选择有效结果并填写说明');
  next='review';s.feedback.push({id:uid('FB'),task_id:id,actor:u.username,outcome,note,created:now()});notify(s,'处置结果待复核',id,'admin',t.elder_id);
 }else if(kind==='followup'&&current==='review'){next='pending';t.staff_id=null}
 else if(kind==='close'&&current!=='closed'){
  if(current==='review'){const f=s.feedback.filter(f=>f.task_id===id).at(-1);if(!f||!['safe','data_issue'].includes(f.outcome))fail(409,'尚未解决的任务需继续跟进，不能关闭')}
  else{if(!['safe','data_issue'].includes(outcome)||note.trim().length<2)fail(422,'直接核实关闭需填写已确认安全或数据核查结果');s.feedback.push({id:uid('FB'),task_id:id,actor:u.username,outcome,note,created:now()})}
  next='closed';Object.assign(get(s.incidents,t.incident_id),{status:'closed',updated:now()});const v=get(s.elders,t.elder_id).state;
  if(t.required_skill==='device')Object.assign(v,{online:true,last_seen:now()});else Object.assign(v,{last_checkin:now(),last_contact:now(),unreachable:false,anomaly:false,anomaly_streak:0});
 }else fail(409,'当前状态不允许该操作');
 Object.assign(t,{state:next,updated:now(),version:t.version+1,due:now()+({0:600,1:1800,2:600,3:120}[t.level]),overdue:0});audit(s,u.username,'task_'+kind,id,{before:current,after:next,outcome,note});return {id,state:next};
}
