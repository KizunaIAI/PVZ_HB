// 创建八秒自然呼吸循环及端盆姿势的骨骼网格，不修改角色贴图、身体比例或用户钢盆变换。
const fs = require('fs'); // 写入原生 Godot 文本资源。
const path = require('path'); // 将输出定位到当前仓库。
const root = path.resolve(__dirname, '../../../..'); // 本脚本位于 docs/art/bosses/da_fei_yu。
const duration = 8; // 完整循环包含两次略有差异的呼吸，单位为秒。
const samples = 128; // 关键帧采样间隔为 1/16 秒，配合三次插值。
const n = value => String(Number(value.toFixed(6))); // 稳定资源中的浮点序列化。
const v = (x,y) => 'Vector2('+n(x)+', '+n(y)+')'; // Godot 像素向量。
const phase = time => time * Math.PI * 2 / duration; // 八秒重心与尾巴相位。
const ease = value => (1-Math.cos(Math.PI*value))/2; // 吸气和呼气端点速度均为零。
function breath(time) {
  const cycle = ((time%4)+4)%4; // 四秒呼吸子周期，支持后发延迟采样。
  const amount = cycle < 1.5 ? ease(cycle/1.5) : 1-ease((cycle-1.5)/2.5); // 吸气较快、呼气稍长。
  return -4.5*amount*(1+0.1*Math.sin(phase(time))); // 第二口气略有差异，避免机械重复。
}
const delayed = (time,delay) => breath(time-delay)-breath(-delay); // 以零位开始的延迟呼吸。
const wave = (time,delay) => Math.sin(phase(time)-delay)+Math.sin(delay); // 首尾同位、同速度的缓慢摆动。
function track(target,rest,value) { return {target,rest,value}; } // 一条原生 Animation 轨道的数据。
function tracksFor(bones) {
  const tracks=[]; // 每个可动骨骼的位移及旋转轨道。
  for(const bone of bones) { // Feet 不建立轨道，保持脚掌着地。
    if(bone.name==='Feet') continue;
    const follow={Body:1,Head:0.9,Hair:0.72,Tail:0.25,Hands:0.95}[bone.name]; // 呼吸高度传递比例。
    const delay={Body:0,Head:0.06,Hair:0.25,Tail:0.5,Hands:0.03}[bone.name]; // 先躯干、再头和手、最后发尾。
    const sway={Body:1.1,Head:1.4,Hair:2.0,Tail:0.8,Hands:1.0}[bone.name]; // 重心水平摆幅，单位为原图像素。
    tracks.push(track('Rig/Skeleton2D/'+bone.name+':position',v(bone.x,bone.y),t=>v(bone.x+sway*wave(t,delay),bone.y+delayed(t,delay)*follow)));
    const swing={Body:0,Head:0.005,Hair:0.016,Tail:0.036,Hands:0.003}[bone.name]; // 小角度跟随，不摇晃整个人。
    if(swing) tracks.push(track('Rig/Skeleton2D/'+bone.name+':rotation','0.0',t=>n(swing*wave(t,delay+0.6))));
  }
  return tracks;
}
function serialize(track,index,reset=false) {
  const times=reset?[0]:Array.from({length:samples+1},(_,i)=>duration*i/samples); // 原生关键帧时间。
  const prefix='tracks/'+index+'/'; // 当前轨道的 Godot 属性前缀。
  return prefix+'type = "value"\n'+prefix+'imported = false\n'+prefix+'enabled = true\n'+prefix+'path = NodePath("'+track.target+'")\n'+prefix+'interp = 2\n'+prefix+'loop_wrap = true\n'+prefix+'keys = {\n"times": PackedFloat32Array('+times.map(n).join(', ')+'),\n"transitions": PackedFloat32Array('+times.map(()=>1).join(', ')+'),\n"update": 0,\n"values": ['+times.map(t=>reset?track.rest:track.value(t)).join(', ')+']\n}';
}
function save(file,text) { fs.writeFileSync(path.join(root,file),text); } // 只写入指定的动画或新端盆场景。
function animation(file,tracks) {
  save(file,'[gd_resource type="Animation" format=3]\n\n[resource]\nresource_name = "idle"\nlength = 8.0\nloop_mode = 1\nstep = 0.033333\n'+tracks.map((t,i)=>serialize(t,i)).join('\n\n')+'\n');
}
const standingBones=[ // 现有五骨骼绑定值，保持原场景及钢盆配置不变。
  {name:'Feet',x:111.36,y:500},{name:'Body',x:104.4,y:335},{name:'Head',x:97.44,y:245},{name:'Hair',x:201.84,y:185},{name:'Tail',x:177.48,y:400}
];
animation('animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v2.tres',tracksFor(standingBones));
const bones=[ // 端盆贴图的骨骼，Hands 单独跟随盆，Feet 独立固定。
  {name:'Feet',x:168,y:500},{name:'Body',x:168,y:345},{name:'Head',x:146,y:245},{name:'Hair',x:264,y:190},{name:'Tail',x:255,y:400},{name:'Hands',x:65,y:305}
];
const tracks=tracksFor(bones); // 端盆九条变换轨道。
const animPath='animation/character/zombie_boss/da_fei_yu/da_fei_yu_hold_idle.tres'; // 新增可编辑的端盆循环。
animation(animPath,tracks);
const smooth=(a,b,value)=>{const u=Math.max(0,Math.min(1,(value-a)/(b-a)));return u*u*(3-2*u);}; // 权重柔和过渡。
function influences(u,w) {
  const feet=smooth(0.82,0.94,w)*(1-smooth(0.50,0.64,u)); // 鞋袜区域固定，不整体上下漂浮。
  const fluke=1-smooth(0.6,1.2,Math.hypot((u-0.91)/0.24,(w-0.72)/0.17)); // 右侧尾鳍区域。
  const lower=smooth(0.79,0.88,w)*smooth(0.5,0.7,u); // 身后鲸尾的下弧。
  const tail=(1-feet)*Math.max(fluke,lower); // 避开双脚后分配尾巴。
  const handMask=(1-smooth(0.25,0.36,u))*smooth(0.49,0.54,w)*(1-smooth(0.64,0.7,w)); // 前方双手和袖口，保持脸部刚性。
  const hands=(1-feet-tail)*handMask; // 手臂跟随独立手部关节。
  const head=(1-feet-tail-hands)*(1-smooth(0.46,0.55,w)); // 头与五官整体移动，避免面部拉伸。
  const hairMask=smooth(0.44,0.68,u)*smooth(0.35,0.55,w)*(1-smooth(0.76,0.86,w)); // 长发下半部分的延迟跟随。
  const hair=Math.max(0,1-feet-tail-hands-head)*hairMask; // 剩余范围分配给后发。
  const body=Math.max(0,1-feet-tail-hands-head-hair); // 衣裙及躯干承接其余权重。
  return {Feet:feet,Body:body,Head:head,Hair:hair,Tail:tail,Hands:hands};
}
const columns=32,rows=48; // 覆盖手臂、头发及裙摆的网格密度。
const points=[],polygons=[]; // 顶点、UV 和逐格三角形。
const weights=Object.fromEntries(bones.map(b=>[b.name,[]])); // 每个骨骼的归一化权重。
for(let row=0;row<=rows;row++) { // 逐行构造网格。
  for(let column=0;column<=columns;column++) { // 当前网格列。
    const u=column/columns,w=row/rows; // 归一化贴图坐标。
    const blend=influences(u,w); // 当前顶点的连续骨骼权重。
    points.push(n(u*424),n(w*500));
    for(const bone of bones) weights[bone.name].push(n(blend[bone.name])); // 与顶点顺序完全一致。
    if(row<rows&&column<columns) {
      const start=row*(columns+1)+column; // 当前网格单元左上角索引。
      polygons.push('PackedInt32Array('+[start,start+1,start+columns+2].join(', ')+')','PackedInt32Array('+[start,start+columns+2,start+columns+1].join(', ')+')');
    }
  }
}
let scene='[gd_scene format=3]\n\n[ext_resource type="Texture2D" path="res://assets/image/character/boss/da_fei_yu/basin_actions_v1/hold.png" id="texture"]\n[ext_resource type="Animation" path="res://'+animPath+'" id="idle"]\n'; // 完整端盆贴图，不拆画或增减手脚。
scene+='\n[sub_resource type="Animation" id="reset"]\nlength = 0.001\n'+tracks.map((t,i)=>serialize(t,i,true)).join('\n\n')+'\n';
scene+='\n[sub_resource type="AnimationLibrary" id="library"]\n_data = { &"RESET": SubResource("reset"), &"idle": ExtResource("idle") }\n';
scene+='\n[node name="DaFeiYuHoldIdle" type="Node2D"]\ntexture_filter = 2\n\n[node name="Rig" type="Node2D" parent="."]\nposition = Vector2(-168, -500)\n\n[node name="Skeleton2D" type="Skeleton2D" parent="Rig"]\n';
for(const bone of bones) { // 绑定姿势与原始完整贴图逐像素重合。
  scene+='\n[node name="'+bone.name+'" type="Bone2D" parent="Rig/Skeleton2D"]\nposition = '+v(bone.x,bone.y)+'\nrest = Transform2D(1, 0, 0, 1, '+bone.x+', '+bone.y+')\nauto_calculate_length_and_angle = false\nlength = 50.0\n';
}
scene+='\n[node name="Mesh" type="Polygon2D" parent="Rig"]\ntexture = ExtResource("texture")\nskeleton = NodePath("../Skeleton2D")\npolygon = PackedVector2Array('+points.join(', ')+')\nuv = PackedVector2Array('+points.join(', ')+')\npolygons = ['+polygons.join(', ')+']\nbones = ['+bones.map(b=>'"'+b.name+'", PackedFloat32Array('+weights[b.name].join(', ')+')').join(', ')+']\n';
scene+='\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = { &"": SubResource("library") }\nautoplay = &"idle"\n';
save('scenes/character/zombie_boss/da_fei_yu/da_fei_yu_hold_idle_visual.tscn',scene);
console.log('已生成八秒站立待机、端盆待机及六骨骼网格；基础钢盆场景与所有贴图保持原样。');
// 本脚本可复现旧自然呼吸基础，但重建端盆网格后仍保留当前真实眼睑。
require('./blink_v4/attach_blinks.cjs');
