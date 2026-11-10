const EULER=.5772156649015329;
export const slotAt=t=>{const d=new Date((t+8*3600)*1000);return d.getUTCHours()*4+Math.floor(d.getUTCMinutes()/15)};
const c=n=>n<=1?0:n===2?1:2*(Math.log(n-1)+EULER)-2*(n-1)/n;
export function evaluateModel(model,row,origin='synthetic'){
 const slot=row.slot??slotAt(row.timestamp),typical=Math.max(.2,model.baseline[slot]);
 const x=[row.count15/typical,row.count60/Math.max(1,typical*4),Math.log1p(row.gap),Math.sin(slot*2*Math.PI/96),Math.cos(slot*2*Math.PI/96)].map(Math.fround);
 let depth=0;
 for(const t of model.trees){let n=0,d=0;while(t.left[n]!==-1){n=x[t.feature[n]]<=t.threshold[n]?t.left[n]:t.right[n];d++}depth+=d+c(t.count[n])}
 const raw=2**(-depth/(model.trees.length*c(model.samples)));
 const percentile=100*model.reference.filter(r=>r<=raw+1e-12).length/model.reference.length;
 const baselineFlag=row.gap>model.idle_limits[slot]&&row.count15<=Math.max(0,Math.round(model.baseline[slot]*10)/10*.1);
 return {anomaly:raw>model.threshold||baselineFlag,score:Math.round(percentile*10)/10,raw_score:Math.round(raw*1e5)/1e5,threshold:model.threshold,
  evidence:[`近15分钟活动 ${row.count15} 次；个人同时间段基线约 ${model.baseline[slot].toFixed(1)} 次`,`距上次活动 ${row.gap.toFixed(0)} 分钟；异常分数分位 ${percentile.toFixed(1)}`,`个人时段无活动90分位阈值 ${model.idle_limits[slot].toFixed(0)} 分钟`,`基线来源：${origin}；分位分数不代表疾病概率`]};
}
