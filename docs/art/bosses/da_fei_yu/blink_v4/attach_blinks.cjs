// 将五个姿势切换为原画 UV 形变，移除眼部贴片资源和可视节点；重建场景时同样保持此方案。
const fs=require('fs'); // 场景文本读写。
const path=require('path'); // 仓库定位。
const root=path.resolve(__dirname,'../../../../..'); // 仓库根目录。
const script='res://scripts/art_preview/da_fei_yu_blink.gd'; // 连续形变控制器，没有可视子节点。
function ext(type,file,id){return '[ext_resource type="'+type+'" path="'+file+'" id="'+id+'"]\n';} // 显式资源引用。
function patch(file,transform){
 const at=path.join(root,file); // 当前场景完整路径。
 let text=fs.readFileSync(at,'utf8'); // 仅对指定场景做局部修改。
 text=transform(text);
 fs.writeFileSync(at,text);
}
function cleanLegacy(text){
 let index=0; // 移除旧遮眼可见性轨道后，重排 RESET 中的轨道编号。
 return text.replace(/tracks\/(\d+)\/type = "value"[\s\S]*?\n\}/g,block=>{
  if(/EyeHalf|EyeClosed/.test(block))return '';
  return block.replace(/tracks\/\d+\//g,'tracks/'+(index++)+'/');
 });
}
function attach(text,entries){
 // 移除旧版贴片控制器和纹理引用；重跑只保留一份当前控制器。
 text=text.replace(/^\[ext_resource[^\n]*(?:id="blink_script"|id="(?:standing|reach|hold|angry|throw)_?(?:half|closed)"|id="eye_(?:half|closed)")[^\n]*\r?\n/gm,'');
 text=text.replace(/\[node name="Blink"[^\n]*\][\s\S]*?(?=\n\[node |$)/g,'');
 const end=text.indexOf('\n',text.indexOf('[ext_resource')); // 在首个资源后插入自己的脚本和眼部纹理。
 let resources='\n'+ext('Script',script,'blink_script'); // 当前场景的脚本引用。
 text=text.slice(0,end+1)+resources+text.slice(end+1);
 for(const e of entries){ // 控制原人物表面，没有独立眼睛绘制节点。
  text+='\n[node name="Blink" type="Node2D" parent="'+e.parent+'"]\nscript = ExtResource("blink_script")\nmesh_path = NodePath("'+e.mesh+'")\neye_shape = Vector4('+e.shape.join(', ')+')\nupper_line = PackedFloat32Array('+e.upper.join(', ')+')\nlower_line = PackedFloat32Array('+e.lower.join(', ')+')\n';
  if(e.player)text+='player_path = NodePath("'+e.player+'")\n';
 }
 // Godot 的加载步数只作提示，重新计算避免保留旧贴片的数量。
 text=text.replace(/\[gd_scene[^\n]*\]/,'[gd_scene load_steps='+((text.match(/^\[(?:ext_resource|sub_resource) /gm)||[]).length+1)+' format=3]');
 return text;
}
patch('scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_v2_visual.tscn',text=>{
 text=cleanLegacy(text);
 text=text.replace('da_fei_yu_idle_left_v3.tres','da_fei_yu_ordinary_idle.tres');
 text=text.replace(/\[node name="Eye(?:Half|Closed)"[\s\S]*?(?=\n\[node )/g,''); // 移除原先整个人物叠加的假闭眼层。
 return attach(text,[{parent:'Rig/Skeleton2D/Head',mesh:'../../../Mesh',shape:[53,93,168,181],upper:[168,164,163,163,165,168,172,177,181],lower:[168,193,202,207,205,201,194,186,181],player:'../../../../AnimationPlayer'}]);
});
patch('scenes/character/zombie_boss/da_fei_yu/da_fei_yu_steel_basin_visual.tscn',text=>cleanLegacy(text).replace('da_fei_yu_idle_left_v3_basin.tres','da_fei_yu_ordinary_idle_basin.tres'));
patch('scenes/character/zombie_boss/da_fei_yu/da_fei_yu_hold_idle_visual.tscn',text=>attach(text,[{parent:'Rig/Skeleton2D/Head',mesh:'../../../Mesh',shape:[82,129,173,181],upper:[173,162,157,156,158,163,170,176,181],lower:[173,190,200,202,202,199,192,187,181],player:'../../../../AnimationPlayer'}]));
patch('scenes/character/zombie_boss/da_fei_yu/da_fei_yu_basin_actions_visual.tscn',text=>attach(text,[
 {parent:'Poses/reach',mesh:'..',shape:[58,103,169,174],upper:[169,158,153,151,153,157,163,169,174],lower:[169,182,192,195,195,192,186,180,174]},
 {parent:'Poses/angry',mesh:'..',shape:[77,129,190,193],upper:[190,180,175,172,173,177,183,188,193],lower:[190,203,213,217,216,212,205,200,193]},
 {parent:'Poses/throw',mesh:'..',shape:[112,165,197,201],upper:[197,190,185,182,182,185,190,197,201],lower:[197,212,221,225,224,220,215,208,201]}
]));
