// 仅生成本轮新增场景，不写入用户已有造型或钢盆场景。
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../../../../..');
const assets='res://assets/image/character/boss/da_fei_yu/basin_actions_v1/';
const actionPath='res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_basin_actions_visual.tscn';
let scene='[gd_scene format=3]\n\n';
const ext=(type,file,id)=>'[ext_resource type="'+type+'" path="'+file+'" id="'+id+'"]\n';
scene+=ext('Script','res://scripts/art_preview/da_fei_yu_basin_actions.gd','controller');
scene+=ext('Script','res://scripts/art_preview/da_fei_yu_thought_bubble.gd','bubble');
scene+=ext('PackedScene','res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_steel_basin_visual.tscn','standing');
scene+=ext('PackedScene','res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_hold_idle_visual.tscn','hold');
for(const name of ['reach','angry','throw','rice_basin']) scene+=ext('Texture2D',assets+name+'.png',name);
scene+='\n[node name="DaFeiYuBasinActionsVisual" type="Node2D"]\nscript = ExtResource("controller")\n';
scene+='\n[node name="Standing" parent="." instance=ExtResource("standing")]\n';
scene+='\n[node name="Poses" type="Node2D" parent="."]\nvisible = false\n';
for(const [index,name] of ['reach','hold','angry','throw'].entries()){
 if(name==='hold') {
  scene+='\n[node name="hold" parent="Poses" instance=ExtResource("hold")]\nvisible = false\n';
  continue;
 }
 scene+='\n[node name="'+name+'" type="Sprite2D" parent="Poses"]\nvisible = false\nposition = Vector2('+(-[146,168,150,220][index])+', -500)\ncentered = false\ntexture = ExtResource("'+name+'")\n';
}
scene+='\n[node name="Basin" type="Sprite2D" parent="."]\nvisible = false\nz_index = 5\n';
scene+='\n[node name="Thought" type="Node2D" parent="."]\nvisible = false\nz_index = 20\nposition = Vector2(10, -650)\nscript = ExtResource("bubble")\n';
scene+='\n[node name="Rice" type="Sprite2D" parent="Thought"]\nposition = Vector2(0, -4)\nscale = Vector2(0.65, 0.65)\ntexture = ExtResource("rice_basin")\n';
fs.writeFileSync(path.join(root,actionPath.replace('res://','')),scene);
let preview='[gd_scene format=3]\n\n';
preview+=ext('PackedScene',actionPath,'visual');
preview+=ext('Script','res://scripts/art_preview/da_fei_yu_basin_preview.gd','controller');
preview+=ext('Texture2D','res://assets/reanim/PeaShooter_Head.png','plant');
preview+=ext('Texture2D','res://assets/reanim/PeaShooter_Lips.png','lips');
preview+='\n[sub_resource type="StyleBoxFlat" id="card"]\nbg_color = Color(0.95, 0.97, 0.995, 1)\ncorner_radius_top_left = 24\ncorner_radius_top_right = 24\ncorner_radius_bottom_left = 24\ncorner_radius_bottom_right = 24\n';
preview+='\n[node name="DaFeiYuBasinActionsPreview" type="Node2D"]\nscript = ExtResource("controller")\n';
preview+='\n[node name="Backdrop" type="ColorRect" parent="."]\noffset_right = 1066.0\noffset_bottom = 600.0\ncolor = Color(0.83, 0.89, 0.96, 1)\nmouse_filter = 2\n';
preview+='\n[node name="Card" type="Panel" parent="."]\noffset_left = 24.0\noffset_top = 24.0\noffset_right = 1042.0\noffset_bottom = 576.0\nmouse_filter = 2\ntheme_override_styles/panel = SubResource("card")\n';
preview+='\n[node name="Ground" type="Line2D" parent="."]\npoints = PackedVector2Array(320, 537, 990, 537)\nwidth = 2.0\ndefault_color = Color(0.7, 0.78, 0.88, 1)\n';
preview+='\n[node name="Character" parent="." instance=ExtResource("visual")]\nposition = Vector2(760, 535)\nscale = Vector2(0.66, 0.66)\n';
preview+='\n[node name="Plant" type="Node2D" parent="."]\nposition = Vector2(390, 473)\n';
preview+='\n[node name="Stem" type="Line2D" parent="Plant"]\nz_index = 0\npoints = PackedVector2Array(0, 54, 5, 23, 0, -15)\nwidth = 12.0\ndefault_color = Color(0.24, 0.56, 0.15, 1)\n';
preview+='\n[node name="Leaves" type="Polygon2D" parent="Plant"]\npolygon = PackedVector2Array(0, 56, -40, 49, -54, 30, -26, 29, 0, 47, 25, 29, 52, 34, 35, 53)\ncolor = Color(0.32, 0.66, 0.18, 1)\n';
preview+='\n[node name="Head" type="Sprite2D" parent="Plant"]\nposition = Vector2(0, -22)\nscale = Vector2(1.25, 1.25)\ntexture = ExtResource("plant")\n';
preview+='\n[node name="Mouth" type="Sprite2D" parent="Plant"]\nposition = Vector2(-6, 2)\ntexture = ExtResource("lips")\n';
preview+='\n[node name="Pea" type="Node2D" parent="."]\nvisible = false\nz_index = 30\n';
preview+='\n[node name="Shape" type="Polygon2D" parent="Pea"]\npolygon = PackedVector2Array(9, 0, 6.4, 6.4, 0, 9, -6.4, 6.4, -9, 0, -6.4, -6.4, 0, -9, 6.4, -6.4)\ncolor = Color(0.46, 0.78, 0.2, 1)\n';
preview+='\n[node name="DemoTimer" type="Timer" parent="."]\none_shot = true\n';
preview+='\n[node name="Interface" type="CanvasLayer" parent="."]\n';
function label(name,text,x,y,w,h,size=19){
preview+='\n[node name="'+name+'" type="Label" parent="Interface"]\noffset_left = '+x+'.0\noffset_top = '+y+'.0\noffset_right = '+(x+w)+'.0\noffset_bottom = '+(y+h)+'.0\nmouse_filter = 2\ntheme_override_colors/font_color = Color(0.12, 0.22, 0.38, 1)\ntheme_override_font_sizes/font_size = '+size+'\ntext = '+JSON.stringify(text)+'\n';
}
label('Title','大肥鱼',52,55,230,52,34);
label('Subtitle','攻击动作1 · 取盆反击',52,118,250,35,19);
label('Notes','① 双手取盆，端在身前\n     幻想一大盆米饭\n\n② 幻想被打破后\n     鼓脸生气，丢盆反击',52,180,260,165,18);
label('Status','戴盆待机',570,552,450,30,18);
label('PlantLabel','打破幻想的植物',321,548,220,30,17);
function button(name,text,y){
preview+='\n[node name="'+name+'" type="Button" parent="Interface"]\noffset_left = 52.0\noffset_top = '+y+'.0\noffset_right = 277.0\noffset_bottom = '+(y+42)+'.0\ntheme_override_font_sizes/font_size = 18\ntext = '+JSON.stringify(text)+'\n';
}
button('Dream','攻击动作1：取盆幻想',365);
button('Hit','植物攻击：打破幻想',417);
button('Reset','普通待机',469);
preview+='\n[node name="Auto" type="CheckButton" parent="Interface"]\noffset_left = 52.0\noffset_top = 521.0\noffset_right = 277.0\noffset_bottom = 558.0\nbutton_pressed = true\ntext = "自动演示"\ntheme_override_font_sizes/font_size = 17\n';
preview += 'theme_override_colors/font_color = Color(0.12, 0.22, 0.38, 1)\ntheme_override_colors/font_hover_color = Color(0.12, 0.22, 0.38, 1)\ntheme_override_colors/font_pressed_color = Color(0.12, 0.22, 0.38, 1)\n';
fs.writeFileSync(path.join(root,'scenes/art_preview/da_fei_yu_basin_actions_preview.tscn'),preview);
// 保留最新的逐姿势眼睑绑定，避免重建旧场景时丢失真实眨眼。
require('../blink_v4/attach_blinks.cjs');
