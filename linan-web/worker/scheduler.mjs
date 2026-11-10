// Exact search is bounded by four workers: enumerate eligible assignments with DP.
export const eta=(w,t)=>2+3*Math.abs((w.location-1)%5-Math.floor((t.elder_id-1)/4)%5);
function best(items,workers){
 let states=new Map([[0,{cost:0,rows:[]}]]);
 for(const task of items){const next=new Map();for(const [mask,s] of states)for(let j=0;j<workers.length;j++){
  const w=workers[j];if(mask&(1<<j)||!w.skills.includes(task.required_skill))continue;
  const key=mask|(1<<j),cost=s.cost+eta(w,task),old=next.get(key);
  if(!old||cost<old.cost)next.set(key,{cost,rows:[...s.rows,{task_id:task.id,staff_id:w.id,eta:eta(w,task)}]});
 }states=next;if(!states.size)return null}
 return [...states.values()].sort((a,b)=>a.cost-b.cost)[0]||{cost:0,rows:[]};
}
export function assign(tasks,allWorkers){
 const workers=allWorkers.filter(w=>w.on_duty&&w.available&&!w.busy),selected=[];
 const sorted=[...tasks].sort((a,b)=>b.level-a.level||a.created-b.created||a.id.localeCompare(b.id));
 for(const t of sorted){if(selected.length>=workers.length)break;if(best([...selected,t],workers))selected.push(t)}
 return (best(selected,workers)?.rows||[]).map(r=>({...r,reason:'先按紧急程度与等待时间覆盖可行任务，再在技能、值班、空闲约束下最小化总仿真到达时间'}));
}
