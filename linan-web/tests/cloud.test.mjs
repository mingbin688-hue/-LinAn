import test from 'node:test';
import assert from 'node:assert/strict';
import models from '../generated/models.json' with {type:'json'};
import fixtures from '../generated/parity.json' with {type:'json'};
import {evaluateModel} from '../worker/model.mjs';
import {assign} from '../worker/scheduler.mjs';
import {seed,ingest,decorateElder} from '../worker/service.mjs';
import {localD1} from '../scripts/d1-local.mjs';
import {handle} from '../worker/index.mjs';

test('all exported forests match Python raw scores and classifications',()=>{
 for(const f of fixtures){const result=evaluateModel(models[f.key],f.row);assert.equal(result.anomaly,f.anomaly);assert.ok(Math.abs(result.raw_score-f.raw)<.00002,JSON.stringify({key:f.key,actual:result.raw_score,expected:f.raw}))}
});
test('bounded exact matching preserves urgency and scarce skills',()=>{
 const tasks=[{id:'a',elder_id:1,created:0,level:3,required_skill:'phone'},{id:'b',elder_id:2,created:1,level:3,required_skill:'visit'},{id:'c',elder_id:3,created:-3,level:1,required_skill:'phone'}];
 const workers=[{id:1,location:1,on_duty:1,available:1,skills:['phone','visit']},{id:2,location:2,on_duty:1,available:1,skills:['phone']}];
 const r=assign(tasks,workers);assert.deepEqual(r.map(x=>x.task_id),['a','b']);assert.equal(r.find(x=>x.task_id==='b').staff_id,1);
 workers[1].available=0;assert.equal(assign(tasks,workers)[0].task_id,'a');
});
test('unknown data and family reply do not close an emergency',()=>{
 const s=seed(models);ingest(s,'elder',{elder_id:3,kind:'safe'},models);ingest(s,'admin',{elder_id:3,kind:'data_offline'},models);
 const e=decorateElder(s,s.elders[2]);assert.equal(e.level,3);assert.equal(e.data_unknown,true);
});
function client(env){
 let cookie='',token='';
 return {get cookie(){return cookie},async req(path,body,method){const r=await handle(new Request('http://localhost'+path,{method:method||(body?'POST':'GET'),headers:{...(cookie?{Cookie:cookie}:{}),...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})}),env);
 const set=r.headers.get('Set-Cookie');if(set)cookie=set.split(';')[0];let data;try{data=await r.json()}catch{data=null}return {status:r.status,data};},
 async login(name='admin'){const r=await this.req('/api/auth/login',{username:name,password:'Demo2026!'});assert.equal(r.status,200);token=r.data.token;return r;}};
}
test('cloud sessions are durable and visitors have independent rooms',async()=>{
 const env={DB:localD1()},a=client(env),b=client(env);await a.login();await b.login();
 const first=(await a.req('/api/elders/1')).data;assert.equal(first.name,'王桂兰');
 await a.req('/api/events',{elder_id:1,kind:'sos',id:'only-in-a'});
 assert.equal((await a.req('/api/elders/1')).data.level,3);assert.equal((await b.req('/api/elders/1')).data.level,1);
 await a.login('family');assert.equal((await a.req('/api/elders')).data.length,1);assert.equal((await a.req('/api/elders/2')).status,403);assert.equal((await a.req('/api/tasks')).status,403);env.DB.close();
});
test('cloud lifecycle, stale recommendations and unresolved feedback',async()=>{
 const env={DB:localD1()},a=client(env);await a.login();
 let rr=(await a.req('/api/dispatch/recommend',{})).data.recommendations,rec=rr[0];
 const w=(await a.req('/api/staff')).data.find(w=>w.id===rec.staff_id);
 await a.req('/api/staff/'+w.id,{available:false,on_duty:true,location:w.location},'PUT');
 assert.equal((await a.req('/api/dispatch/confirm',{recommendation_id:rec.id})).status,409);
 await a.req('/api/staff/'+w.id,{available:true,on_duty:true,location:w.location},'PUT');
 rec=(await a.req('/api/dispatch/recommend',{})).data.recommendations[0];
 assert.equal((await a.req('/api/dispatch/confirm',{recommendation_id:rec.id})).status,200);
 assert.equal((await a.req('/api/dispatch/confirm',{recommendation_id:rec.id})).status,409);
 await a.login('staff'+rec.staff_id);
 assert.equal((await a.req('/api/tasks/'+rec.task_id+'/action',{action:'accept'})).status,200);
 assert.equal((await a.req('/api/tasks/'+rec.task_id+'/action',{action:'start'})).status,200);
 assert.equal((await a.req('/api/tasks/'+rec.task_id+'/action',{action:'feedback',outcome:'unreachable',note:'尚未联系到'})).status,200);
 await a.login();assert.equal((await a.req('/api/tasks/'+rec.task_id+'/action',{action:'close'})).status,409);
 assert.equal((await a.req('/api/tasks/'+rec.task_id+'/action',{action:'followup'})).status,200);
 assert.equal((await a.req('/api/tasks/'+rec.task_id+'/action',{action:'close',outcome:'safe',note:'已完成核实，确认安全'})).status,200);
 const detail=(await a.req('/api/tasks/'+rec.task_id)).data;assert.equal(detail.state,'closed');assert.ok(detail.audit.length>4);env.DB.close();
});
test('concurrent confirmations cannot reserve a worker twice',async()=>{
 const env={DB:localD1()},a=client(env);await a.login();const rr=(await a.req('/api/dispatch/recommend',{})).data.recommendations;
 const responses=await Promise.all(rr.slice(0,2).map(r=>a.req('/api/dispatch/confirm',{recommendation_id:r.id,staff_id:rr[0].staff_id,reason:'并发测试'})));
 assert.deepEqual(responses.map(x=>x.status).sort(),[200,409]);env.DB.close();
});
test('CASAS replay deduplicates and offline reports preserve limitations',async()=>{
 const env={DB:localD1()},a=client(env);await a.login();assert.equal((await a.req('/api/replay/window',{elder_id:2,offset:0})).status,200);
 assert.equal((await a.req('/api/replay/window',{elder_id:2,offset:0})).data.duplicate,true);
 const report=(await a.req('/api/experiments/run',{})).data;assert.equal(report.casas.personalized.injected_episode_recall,.45);assert.match(report.execution,/离线/);env.DB.close();
});
