// 普通待机独立于攻击动作1：呼吸、探头偷瞄、尾巴回应和收肩回正组成十二秒表演。
const fs=require('fs'); // 保存原生 Animation 资源。
const path=require('path'); // 定位当前仓库。
const root=path.resolve(__dirname,'../../../../..'); // 仓库根目录。
const length=12, samples=384; // 十二秒循环，1/32秒采样并使用三次插值。
const num=x=>String(Number(x.toFixed(6))); // 精简浮点。
const vec=(x,y)=>'Vector2('+num(x)+', '+num(y)+')'; // Godot 向量文本。
const ease=x=>{x=Math.max(0,Math.min(1,x));return x*x*x*(x*(x*6-15)+10);}; // 五阶缓入缓出，端点速度和加速度归零。
const pulse=(t,start,rise,hold,fall)=>t<start?0:t<start+rise?ease((t-start)/rise):t<start+rise+hold?1:1-ease((t-start-rise-hold)/fall); // 有意图的动作停顿与回正。
const peek=t=>pulse(t,2.65,0.75,0.7,1.15); // 身体先探看、头随后歪向前方。
const shrug=t=>pulse(t,8.25,0.45,0.18,1.1); // 轻轻收肩得意一下，脚底不跳。
const breathe=t=>{let c=((t%4)+4)%4;return -3.8*(c<1.5?ease(c/1.5):1-ease((c-1.5)/2.5));}; // 小呼吸让位于有意图的表演。
const breath=(t,d)=>breathe(t-d)-breathe(-d); // 首尾零位的延迟呼吸。
const wag=t=>0.050*pulse(t,6.0,0.22,0.03,0.33)-0.025*pulse(t,6.55,0.24,0.02,0.3)+0.035*pulse(t,7.05,0.2,0.02,0.4); // 两下大小不同的尾鳍回应。
const bones=[{name:'Body',x:104.4,y:335},{name:'Head',x:97.44,y:245},{name:'Hair',x:201.84,y:185},{name:'Tail',x:177.48,y:400}]; // 已有骨骼绑定值。
const tracks=[]; // 普通待机的身体与头发轨道。
for(const b of bones){ // 位移与旋转均从绑定姿势出发，脚骨骼完全不建轨道。
 const delay={Body:0,Head:0.12,Hair:0.28,Tail:0.45}[b.name]; // 意图先从躯干发起，再传到头、后发和鲸尾。
 tracks.push({target:'Rig/Skeleton2D/'+b.name+':position',value:t=>{
  const p=peek(t-delay),s=shrug(t-delay); // 当前关节的探看与收肩包络。
  const gain={Body:1,Head:0.92,Hair:0.72,Tail:0.25}[b.name]; // 呼吸传递比例。
  return vec(b.x-({Body:2,Head:4,Hair:2.5,Tail:0.5}[b.name])*p+0.8*s,b.y+gain*breath(t,delay)-({Body:2,Head:1.2,Hair:0.7,Tail:0.2}[b.name])*p-({Body:3.5,Head:3,Hair:2,Tail:0.5}[b.name])*s);
 }});
 tracks.push({target:'Rig/Skeleton2D/'+b.name+':rotation',value:t=>num(({Body:-0.009,Head:-0.035,Hair:-0.022,Tail:0.008}[b.name])*peek(t-delay)+({Body:0.006,Head:0.012,Hair:0.008,Tail:0}[b.name])*shrug(t-delay)+(b.name==='Tail'?wag(t):0))});
}
function write(file,extra=[]){
 const data=tracks.concat(extra); // 戴盆版本再追加次级运动，不触碰用户钢盆绑定位置。
 const times=Array.from({length:samples+1},(_,i)=>length*i/samples); // 所有轨道共用关键帧时间。
 const text=data.map((tr,i)=>{const p='tracks/'+i+'/';return p+'type = "value"\n'+p+'path = NodePath("'+tr.target+'")\n'+p+'interp = 2\n'+p+'loop_wrap = true\n'+p+'keys = {\n"times": PackedFloat32Array('+times.map(num).join(', ')+'),\n"transitions": PackedFloat32Array('+times.map(()=>1).join(', ')+'),\n"update": 0,\n"values": ['+times.map(tr.value).join(', ')+']\n}';}).join('\n\n'); // 原生轨道序列化。
 fs.writeFileSync(path.join(root,file),'[gd_resource type="Animation" format=3]\n\n[resource]\nresource_name = "idle"\nlength = 12.0\nloop_mode = 1\nstep = 0.03125\n'+text+'\n');
}
write('animation/character/zombie_boss/da_fei_yu/da_fei_yu_ordinary_idle.tres');
write('animation/character/zombie_boss/da_fei_yu/da_fei_yu_ordinary_idle_basin.tres',[
 {target:'Rig/Skeleton2D/Head/SteelBasin:rotation',value:t=>num(0.008*(peek(t-0.18)-peek(t))+0.006*(shrug(t-0.16)-shrug(t)))}
]);
