import models from '../generated/models.json' with {type:'json'};
import replay from '../generated/replay.json' with {type:'json'};
import experiments from '../generated/experiments.json' with {type:'json'};
import assets from '../generated/assets.json' with {type:'json'};
import {ACTIVE,now,uid,fail,get,audit,seed,scope,requireAdmin,requireOperator,workers,decorateElder,decorateTask,tick,ingest,recommend,confirm,action} from './service.mjs';

const COOKIE='linan_demo';
const json=(data,status=200,extra={})=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff',...extra}});
const digest=async value=>[...new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value)))].map(b=>b.toString(16).padStart(2,'0')).join('');
function demoUser(name){
 if(name==='admin')return {username:name,role:'admin',name:'社区管理员',elder_id:null,staff_id:null};
 if(name==='family'||name==='elder')return {username:name,role:name,name:name==='family'?'王桂兰的家属':'王桂兰',elder_id:1,staff_id:null};
 const m=/^staff([1-4])$/.exec(name);if(m)return {username:name,role:'staff',name:['陈晓','林悦','赵海','许宁'][+m[1]-1],elder_id:null,staff_id:+m[1]};
 return null;
}
const bounded=(s,n)=>typeof s==='string'&&s.trim().length>0&&s.length<=n;
function profileInput(body){
 if(!bounded(body.name,40)||!Number.isInteger(body.age)||body.age<60||body.age>120||!bounded(body.building,80)||!bounded(body.contact,80))fail(422,'请填写有效姓名、年龄、楼栋与联系人');
 if(!Number.isInteger(body.checkin_hour??9)||(body.checkin_hour??9)<0||(body.checkin_hour??9)>23)fail(422,'报平安小时需为0到23');
 return {name:body.name,age:body.age,building:body.building,contact:body.contact,routine:String(body.routine||'07:00起床，22:00休息').slice(0,300),checkin_hour:body.checkin_hour??9};
}
function route(s,u,path,method,body,tokenHash){
 if(path==='/api/me')return u;
 if(path==='/api/auth/logout'){s.sessions=s.sessions.filter(x=>x.token!==tokenHash);return {ok:true}}
 if(path==='/api/elders'&&method==='GET'){return s.elders.filter(e=>{try{scope(s,u,e.id);return true}catch{return false}}).map(e=>decorateElder(s,e))}
 const elderMatch=/^\/api\/elders\/(\d+)$/.exec(path);
 if(elderMatch){const id=+elderMatch[1],e=get(s.elders,id);scope(s,u,id);
  if(method==='GET')return {...decorateElder(s,e),events:s.events.filter(x=>x.elder_id===id).reverse().slice(0,80)};
  if(method==='PUT'){requireAdmin(u);const p=profileInput(body);Object.assign(e,{name:p.name,age:p.age,building:p.building,contact:p.contact,version:e.version+1});Object.assign(e.profile,{routine:p.routine,checkin_hour:p.checkin_hour});audit(s,u.username,'elder_updated',String(id),p);return {ok:true}}
 }
 if(path==='/api/elders'&&method==='POST'){
  requireAdmin(u);if(s.elders.length>=50)fail(409,'每个演示社区最多50位虚拟老人');const p=profileInput(body),id=Math.max(...s.elders.map(e=>e.id))+1,at=now();
  const e={id,name:p.name,age:p.age,building:p.building,contact:p.contact,version:1,profile:{routine:p.routine,checkin_hour:p.checkin_hour,history_days:0,baseline_ready:false,origin:'manual-demo',activity_scale:1},state:{online:false,last_seen:0,last_checkin:at,last_contact:0,observed_at:0,presence:'unknown',presence_until:0,count15:0,count60:0,gap:0,score:0,anomaly:false,anomaly_streak:0,evidence:[],source:'尚未接入数据'}};
  s.elders.push(e);tick(s);audit(s,u.username,'elder_created',String(id),p);return {id};
 }
 if(path==='/api/events'&&method==='POST'){
  scope(s,u,body.elder_id);if(['family','elder'].includes(u.role)&&!['safe','contact','sos','away','home','rest'].includes(body.kind))fail(403,'当前演示角色不能提交此类型事件');return ingest(s,u.username,body,models);
 }
 if(path==='/api/incidents')return s.incidents.filter(i=>{try{scope(s,u,i.elder_id);return true}catch{return false}}).map(i=>({...i,elder_name:get(s.elders,i.elder_id).name})).sort((a,b)=>(a.status==='open'?0:1)-(b.status==='open'?0:1)||b.level-a.level||a.created-b.created);
 if(path==='/api/tasks'){requireOperator(u);return s.tasks.filter(t=>u.role==='admin'||t.staff_id===u.staff_id).sort((a,b)=>b.level-a.level||a.created-b.created).map(t=>decorateTask(s,t))}
 const taskMatch=/^\/api\/tasks\/(TK-[a-z0-9]+)(\/action)?$/.exec(path);
 if(taskMatch){requireOperator(u);const t=get(s.tasks,taskMatch[1]);if(u.role==='staff'&&t.staff_id!==u.staff_id)fail(403,'无权访问此任务');
  if(taskMatch[2]&&method==='POST'){if(String(body.note||'').length>2000)fail(422,'说明过长');return action(s,u,t.id,body)}
  if(method==='GET')return {...decorateTask(s,t),feedback:s.feedback.filter(f=>f.task_id===t.id),audit:s.audit.filter(a=>a.entity_id===t.id||a.entity_id===t.incident_id)};
 }
 if(path==='/api/dispatch/recommend'&&method==='POST'){requireAdmin(u);return recommend(s,u.username)}
 if(path==='/api/dispatch/confirm'&&method==='POST'){requireAdmin(u);return confirm(s,u.username,body)}
 if(path==='/api/staff'){requireOperator(u);return workers(s).filter(w=>u.role==='admin'||w.id===u.staff_id)}
 const staffMatch=/^\/api\/staff\/(\d+)$/.exec(path);
 if(staffMatch&&method==='PUT'){
  requireOperator(u);const id=+staffMatch[1];if(u.role==='staff'&&u.staff_id!==id)fail(403,'只能更新自己的状态');
  if(typeof body.available!=='boolean'||typeof body.on_duty!=='boolean'||!Number.isInteger(body.location)||body.location<1||body.location>5)fail(422,'人员状态无效');
  const w=get(s.staff,id);Object.assign(w,{available:+body.available,on_duty:+body.on_duty,location:body.location,version:w.version+1});audit(s,u.username,'staff_updated',String(id),body);return {ok:true};
 }
 if(path==='/api/notifications')return s.notifications.filter(n=>n.role===u.role&&(u.role==='admin'||u.role==='staff'&&n.staff_id===u.staff_id||['family','elder'].includes(u.role)&&n.elder_id===u.elder_id)).slice(0,30);
 if(path==='/api/demo/scenario'&&method==='POST'){
  requireAdmin(u);const id=body.elder_id||1,kinds={story:[[1,'missed_checkin',{}],[2,'activity',{count15:0,count60:0,gap:180}],[3,'sos',{}]],offline:[[id,'data_offline',{}]],away:[[id,'away',{hours:4}]],normal:[[id,'safe',{}]],cold_start:[[id,'activity',{count15:0,count60:0,gap:60}]],conflict:[[4,'sos',{}],[5,'need_help',{}],[6,'sos',{}]]};
  const events=kinds[body.scenario];if(!events)fail(422,'未知情景');if(body.scenario==='cold_start'){get(s.elders,id).profile.history_days=3;get(s.elders,id).profile.baseline_ready=false}
  return {origin:'synthetic',events:events.map(([elder_id,kind,payload])=>ingest(s,u.username,{elder_id,kind,payload,source:'合成情景回放'},models))};
 }
 if(path==='/api/replay/window'&&method==='POST'){
  requireAdmin(u);const e=get(s.elders,body.elder_id),offset=body.offset??0;if(!Number.isInteger(offset)||offset<0||offset>=replay.length)fail(422,'窗口偏移超出测试段');const r=replay[offset];
  Object.assign(e.profile,{origin:'CASAS Aruba replay',history_days:130,baseline_ready:true});
  const result=ingest(s,u.username,{id:`CASAS-${e.id}-${r.timestamp}`,elder_id:e.id,kind:'activity',source:'CASAS Aruba公开数据窗口回放',payload:{count15:r.count15,count60:r.count60,gap:r.gap,original_timestamp:r.timestamp}},models);
  return {...result,offset,total:replay.length,original_timestamp:r.timestamp,count15:r.count15,gap:r.gap,origin:'CASAS replay in virtual profile'};
 }
 if(path==='/api/experiments/run'&&method==='POST'){requireAdmin(u);s.experiment=now();audit(s,u.username,'experiment_report_loaded','offline-python-report',{seed:42,computed:'Python offline; verified report served by cloud'});return {...experiments,execution:'离线Python实验报告，云端读取已验证结果'}}
 if(path==='/api/experiments'){requireAdmin(u);return s.experiment?{...experiments,execution:'离线Python实验报告，云端读取已验证结果'}:null}
 if(path==='/api/feedback/export'){requireAdmin(u);return {purpose:'已复核反馈供离线分析，不直接修改模型',items:s.feedback.filter(f=>get(s.tasks,f.task_id).state==='closed').map(f=>({...f,elder_id:get(s.tasks,f.task_id).elder_id}))}}
 fail(404,'接口不存在');
}
export async function handle(request,env){
 const url=new URL(request.url),path=url.pathname;
 if(path==='/api/health')return json({status:'ok',app:'linan-community-guard',version:'1.0.0-cloud',storage:env.DB?'D1':'unavailable',mode:'public independent demo rooms'});
 if(!path.startsWith('/api/')){
  const asset=assets[path==='/'?'/index.html':path];if(!asset)return new Response('Not found',{status:404});
  return new Response(asset.body,{headers:{'Content-Type':asset.mime,'X-Content-Type-Options':'nosniff','Referrer-Policy':'same-origin','Cache-Control':path.startsWith('/assets/')?'public, max-age=31536000, immutable':'no-cache'}});
 }
 if(!env.DB)return json({detail:'云端数据库尚未就绪'},503);
 try{
  if(!['GET','POST','PUT'].includes(request.method))fail(405,'不支持此请求方式');
  const origin=request.headers.get('Origin');if(request.method!=='GET'&&(origin&&origin!==url.origin||request.headers.get('Sec-Fetch-Site')==='cross-site'))fail(403,'请从本站页面发起操作');
  let body={};if(request.method!=='GET'){const text=await request.text();if(text.length>16000)fail(413,'请求内容过长');try{body=text?JSON.parse(text):{}}catch{fail(422,'请求需为有效JSON')}if(!body||typeof body!=='object'||Array.isArray(body))fail(422,'请求需为JSON对象')}
  let secret=request.headers.get('Cookie')?.split(';').map(s=>s.trim()).find(s=>s.startsWith(COOKIE+'='))?.slice(COOKIE.length+1);
  if(secret&&!/^[a-f0-9]{64}$/.test(secret))secret=null;
  let cookie=null;
  if(!secret){if(path!=='/api/auth/login'||request.method!=='POST')fail(401,'请先选择演示身份');secret=[...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('');cookie=`${COOKIE}=${secret}; Path=/; HttpOnly; SameSite=Lax; Max-Age=604800${url.protocol==='https:'?'; Secure':''}`}
  const roomId=await digest(secret),bearer=request.headers.get('Authorization')?.replace(/^Bearer /,'')||'',tokenHash=bearer?await digest(bearer):null;
  const loginUser=path==='/api/auth/login'&&request.method==='POST'?demoUser(body.username):null;
  if(path==='/api/auth/login'&&(!loginUser||body.password!=='Demo2026!'))fail(401,'演示账号或密码不正确');
  for(let attempt=0;attempt<6;attempt++){
   let record=await env.DB.prepare('SELECT payload,version,expires FROM demo_rooms WHERE id=?').bind(roomId).first();
   if(!record||record.expires<now()){
    if(path!=='/api/auth/login')fail(401,'演示空间已过期，请重新进入');
    const initial=seed(models);await env.DB.prepare('INSERT INTO demo_rooms(id,payload,version,updated,expires) VALUES(?,?,1,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,version=demo_rooms.version+1,updated=excluded.updated,expires=excluded.expires WHERE demo_rooms.expires<?').bind(roomId,JSON.stringify(initial),Math.floor(now()),Math.floor(now()+604800),Math.floor(now())).run();
    record=await env.DB.prepare('SELECT payload,version,expires FROM demo_rooms WHERE id=?').bind(roomId).first();
   }
   const s=JSON.parse(record.payload);let dirty=request.method!=='GET'||now()-s.last_tick>=5;
   if(now()-s.last_tick>=5)tick(s);
   let result;
   if(loginUser){
    const token=crypto.randomUUID()+crypto.randomUUID();s.sessions=s.sessions.filter(x=>x.expires>now()).slice(-15);
    s.sessions.push({token:await digest(token),user:loginUser,expires:now()+28800});result={token,user:loginUser};dirty=true;
   }else{
    const session=s.sessions.find(x=>x.token===tokenHash&&x.expires>now());if(!session)fail(401,'演示身份已过期，请重新选择');
    result=route(s,session.user,path,request.method,body,tokenHash);
   }
   if(dirty){
    const payload=JSON.stringify(s);if(payload.length>900000)fail(409,'演示空间记录已达上限，请新建空间');
    const saved=await env.DB.prepare('UPDATE demo_rooms SET payload=?,version=version+1,updated=?,expires=? WHERE id=? AND version=?').bind(payload,Math.floor(now()),Math.floor(now()+604800),roomId,record.version).run();
    if(saved.meta.changes!==1)continue;
   }
   return json(result,200,cookie?{'Set-Cookie':cookie}:{});
  }
  fail(409,'同时操作较多，请刷新后重试');
 }catch(e){if(!e.status)console.error('Linan API error',e);return json({detail:e.status?e.message:'云端服务暂时不可用，请稍后重试'},e.status||500)}
}
export default {fetch:handle};
