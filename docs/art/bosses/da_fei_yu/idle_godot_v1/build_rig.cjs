// 大肥鱼部件动画的本地素材装配工具；从仓库根目录运行，不涉及游戏战斗逻辑。
const fs = require('fs'); // 用于读取部件清单及保存场景、动画资源。
const path = require('path'); // 用于定位当前仓库中的输出目录。
const sharp = require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 现有图像依赖，仅用于切分和导出 PNG。
const root = process.cwd(); // 当前执行目录应为本项目仓库根目录。
const docDir = 'docs/art/bosses/da_fei_yu/idle_godot_v1'; // 生成记录及原始部件表目录。
const assetDir = 'assets/image/character/boss/da_fei_yu/idle_parts_v1'; // Godot 读取的透明部件贴图目录。
const sceneDir = 'scenes/character/zombie_boss/da_fei_yu'; // 可复用美术角色场景目录。
const animDir = 'animation/character/zombie_boss/da_fei_yu'; // 可在 Godot 动画面板中编辑的待机资源目录。
const specs = JSON.parse(fs.readFileSync(path.join(root, docDir, 'parts_manifest.json'), 'utf8')); // 部件来源矩形、目标尺寸及命名。
const duration = 4.0; // 单次呼吸与尾巴摆动的循环时长，单位为秒。
const sampleCount = 32; // 每条连续轨道一圈的采样区间数，首尾同时保存以闭合循环。
const proportions = { // 固定部件的装配比例；不改动原始贴图内容。
  headY: -56, // 头部相对身体的连接点，降低后让下巴贴近白色领口。
  dressScaleX: 1.08, // 略微加宽裙装，恢复参考图中饱满的 Q 版轮廓。
  dressScaleY: 0.92, // 压缩躯干纵向长度，同时保持裙摆下沿的位置。
  armScale: 0.68, // 缩短袖子和手掌组成的完整部件，避免双臂伸出裙摆过远。
  shoulderX: 61, // 左右手臂在身体中心两侧的连接距离，单位为本地像素。
  shoulderY: -55, // 将缩短后的袖子根部藏入已有肩袖，让双手落在腰线稍下方。
  legScaleX: 0.84, // 收窄双脚站距及鞋子宽度，使双脚比例与裙摆宽度协调。
  legScaleY: 0.65, // 压低原贴图中过高的鞋面，让短袜在裙摆下可见；脚底仍固定在原点。
  frontLockScale: 0.7, // 缩短前侧发束，露出袖口与手臂轮廓，避免头发遮出断臂感。
  previewScale: 0.84 // 紧凑比例调整后略微放大演示，使整体显示高度接近上一版。
};
const number = value => String(Number(value.toFixed(6))); // 去除浮点误差并避免向资源中写入负零。
const vec = (x, y) => 'Vector2(' + number(x) + ', ' + number(y) + ')'; // 将二维坐标序列化为 Godot 资源格式。
const angle = t => Math.PI * 2 * t / duration; // 将循环内秒数换算成连续周期相位。
const breathe = t => -2 * (1 - Math.cos(angle(t))); // 身体从基准高度缓慢上升四像素，再回到基准高度。
const tracks = [ // 仅动画化关节与部件变换，脸部及衣服始终使用同一张贴图。
  { node: 'BodyMotion:position', rest: vec(0, -160), value: t => vec(0, -160 + breathe(t)) },
  { node: 'BodyMotion:scale', rest: vec(1, 1), value: t => vec(1, 1 + 0.003 * (1 - Math.cos(angle(t)))) },
  { node: 'BodyMotion/HeadPivot:position', rest: vec(0, proportions.headY), value: t => vec(0, proportions.headY - 0.25 * (1 - Math.cos(angle(t) - 0.15))) },
  { node: 'BodyMotion/HeadPivot:rotation', rest: '0.0', value: t => number(0.006 * Math.sin(angle(t) - 0.3)) },
  { node: 'BackHairPivot:position', rest: vec(0, -435), value: t => vec(0, -435 + breathe(t) * 0.8) },
  { node: 'BackHairPivot:rotation', rest: '0.0', value: t => number(0.012 * Math.sin(angle(t) - 0.55)) },
  { node: 'TailPivot:position', rest: vec(0, -125), value: t => vec(0, -125 + 0.4 * breathe(t)) },
  { node: 'TailPivot:rotation', rest: '0.0', value: t => number(0.038 * Math.sin(angle(t) - 0.8)) },
  { node: 'BodyMotion/ArmLeftPivot:rotation', rest: '0.0', value: t => number(0.012 * Math.sin(angle(t) - 0.4)) },
  { node: 'BodyMotion/ArmRightPivot:rotation', rest: '0.0', value: t => number(-0.012 * Math.sin(angle(t) - 0.4)) },
  { node: 'BodyMotion/HeadPivot/LockLeftPivot:rotation', rest: '0.0', value: t => number(0.022 * Math.sin(angle(t) - 0.65)) },
  { node: 'BodyMotion/HeadPivot/LockRightPivot:rotation', rest: '0.0', value: t => number(-0.022 * Math.sin(angle(t) - 0.85)) }
];

// 将字符串保存到仓库相对路径，自动创建尚不存在的父目录。
function save(relativePath, content) {
  const target = path.join(root, relativePath); // 当前文件的绝对保存路径。
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content, 'utf8');
}

// 将一个变换轨道序列化；重置轨道仅记录静止姿势，待机轨道记录闭合周期。
function serializeTrack(track, index, reset = false) {
  const times = reset ? [0] : Array.from({ length: sampleCount + 1 }, (_, key) => key * duration / sampleCount); // 以秒记录当前轨道的采样时刻。
  const values = reset ? [track.rest] : times.map(track.value); // 静止姿势或循环内逐个采样的部件变换。
  const prefix = 'tracks/' + index + '/'; // Godot 文本资源中的轨道索引前缀。
  return [prefix + 'type = "value"', prefix + 'imported = false', prefix + 'enabled = true', prefix + 'path = NodePath("' + track.node + '")', prefix + 'interp = 1', prefix + 'loop_wrap = true', prefix + 'keys = {', '"times": PackedFloat32Array(' + times.map(number).join(', ') + '),', '"transitions": PackedFloat32Array(' + times.map(() => '1').join(', ') + '),', '"update": 0,', '"values": [' + values.join(', ') + ']', '}'].join('\n');
}

// 创建可复用的 Node2D 关节；坐标是脚底为原点的本地像素坐标。
function pivot(name, parent, x, y, z = 0) {
  return '\n[node name="' + name + '" type="Node2D" parent="' + parent + '"]\nposition = ' + vec(x, y) + '\nz_index = ' + z + '\n';
}

// 创建固定贴图部件；位置对齐连接点，scaleX 与 scaleY 分别控制横纵比例，默认等比缩放。
function sprite(name, parent, texture, x, y, z = 0, scaleX = 1, scaleY = scaleX) {
  return '\n[node name="' + name + '" type="Sprite2D" parent="' + parent + '"]\nz_index = ' + z + '\nposition = ' + vec(x, y) + '\nscale = ' + vec(scaleX, scaleY) + '\ntexture = ExtResource("' + texture + '")\ncentered = false\n';
}

// 创建预览页文字；所有页面坐标均基于项目原有的 1066×600 视口。
function label(name, x, y, width, height, text, size, color) {
  return '\n[node name="' + name + '" type="Label" parent="Interface"]\noffset_left = ' + x + '.0\noffset_top = ' + y + '.0\noffset_right = ' + (x + width) + '.0\noffset_bottom = ' + (y + height) + '.0\nmouse_filter = 2\ntheme_override_colors/font_color = ' + color + '\ntheme_override_font_sizes/font_size = ' + size + '\ntext = "' + text + '"\n';
}

// 创建仅影响此预览播放器的按钮。
function button(name, y, text) {
  return '\n[node name="' + name + '" type="Button" parent="Interface"]\noffset_left = 60.0\noffset_top = ' + y + '.0\noffset_right = 270.0\noffset_bottom = ' + (y + 42) + '.0\ntheme_override_font_sizes/font_size = 18\ntext = "' + text + '"\n';
}

// 切分原始生成图并构建 Godot 场景；不启动游戏，也不运行测试。
async function main() {
  fs.mkdirSync(path.join(root, assetDir), { recursive: true });
  for (const spec of specs) { // 按原图的实际部件布局导出，保留完整透明通道。
    const [left, top, width, height] = spec.rect; // 当前部件来源矩形，单位为像素。
    const cropped = spec.source_file
      ? await sharp(path.join(root, docDir, spec.source_file)).png().toBuffer()
      : await sharp(path.join(root, docDir, 'parts_source.png')).extract({ left, top, width, height }).png().toBuffer(); // 独立重绘的部件直接读取，其余部件先从表中提取。
    const exported = await sharp(cropped).trim({ threshold: 20 }).resize({ width: spec.size[0], height: spec.size[1], fit: 'inside', withoutEnlargement: true }).png().toFile(path.join(root, assetDir, spec.name + '.png')); // 记录实际导出尺寸，便于后续调整部件原点。
    spec.width = exported.width;
    spec.height = exported.height;
  }
  save(docDir + '/parts_manifest.json', JSON.stringify(specs, null, 2) + '\n');
  save(animDir + '/da_fei_yu_idle.tres', '[gd_resource type="Animation" format=3]\n\n[resource]\nresource_name = "idle"\nlength = 4.0\nloop_mode = 1\nstep = 0.033333\n' + tracks.map((track, index) => serializeTrack(track, index)).join('\n\n') + '\n');
  let character = '[gd_scene load_steps=13 format=3]\n'; // 角色场景的完整文本，包含九贴图、一动画及两个内置资源。
  for (const spec of specs) { // 注册九个固定透明部件。
    character += '\n[ext_resource type="Texture2D" path="res://' + assetDir + '/' + spec.name + '.png" id="' + spec.name + '"]';
  }
  character += '\n[ext_resource type="Animation" path="res://' + animDir + '/da_fei_yu_idle.tres" id="idle"]\n';
  character += '\n[sub_resource type="Animation" id="Animation_reset"]\nresource_name = "RESET"\nlength = 0.001\n' + tracks.map((track, index) => serializeTrack(track, index, true)).join('\n\n') + '\n';
  character += '\n[sub_resource type="AnimationLibrary" id="AnimationLibrary_idle"]\n_data = {\n&"RESET": SubResource("Animation_reset"),\n&"idle": ExtResource("idle")\n}\n';
  character += '\n[node name="DaFeiYuVisual" type="Node2D"]\ntexture_filter = 2\n';
  character += pivot('TailPivot', '.', 0, -125, 0) + sprite('Tail', 'TailPivot', 'tail', -22, -77);
  character += pivot('BackHairPivot', '.', 0, -435, 1) + sprite('BackHair', 'BackHairPivot', 'back_hair', -176, 0);
  character += sprite('Legs', '.', 'legs', -68 * proportions.legScaleX, -105 * proportions.legScaleY, 2, proportions.legScaleX, proportions.legScaleY);
  character += pivot('BodyMotion', '.', 0, -160, 3);
  character += pivot('ArmLeftPivot', 'BodyMotion', -proportions.shoulderX, proportions.shoulderY) + sprite('ArmLeft', 'BodyMotion/ArmLeftPivot', 'arm_left', -122 * proportions.armScale, -15 * proportions.armScale, 0, proportions.armScale);
  character += pivot('ArmRightPivot', 'BodyMotion', proportions.shoulderX, proportions.shoulderY) + sprite('ArmRight', 'BodyMotion/ArmRightPivot', 'arm_right', -20 * proportions.armScale, -15 * proportions.armScale, 0, proportions.armScale);
  const dressX = -117.5 * proportions.dressScaleX; // 对称加宽后，裙装仍以身体中心为水平基准。
  const dressY = 110 - 226 * proportions.dressScaleY; // 纵向压缩后保持裙摆下沿在角色本地 y=-50。
  character += sprite('Dress', 'BodyMotion', 'dress', dressX, dressY, 1, proportions.dressScaleX, proportions.dressScaleY);
  character += pivot('HeadPivot', 'BodyMotion', 0, proportions.headY, 3) + sprite('Head', 'BodyMotion/HeadPivot', 'head', -152, -264, 2);
  character += pivot('LockLeftPivot', 'BodyMotion/HeadPivot', -76, -9, 1) + sprite('LockLeft', 'BodyMotion/HeadPivot/LockLeftPivot', 'lock_left', -28 * proportions.frontLockScale, 0, 0, proportions.frontLockScale);
  character += pivot('LockRightPivot', 'BodyMotion/HeadPivot', 76, -9, 1) + sprite('LockRight', 'BodyMotion/HeadPivot/LockRightPivot', 'lock_right', -27 * proportions.frontLockScale, 0, 0, proportions.frontLockScale);
  character += sprite('CollarOverlay', 'BodyMotion', 'dress', dressX + 70 * proportions.dressScaleX, dressY + 8 * proportions.dressScaleY, 6, proportions.dressScaleX, proportions.dressScaleY);
  character += 'region_enabled = true\nregion_rect = Rect2(70, 8, 95, 57)\n'; // 复用原裙装的领口小区域，在前景遮住头部贴图多余的颈根，不遮住其余头发。
  character += '\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = {\n&"": SubResource("AnimationLibrary_idle")\n}\nautoplay = "idle"\n';
  save(sceneDir + '/da_fei_yu_visual.tscn', character);
  let preview = '[gd_scene load_steps=5 format=3]\n\n[ext_resource type="PackedScene" path="res://' + sceneDir + '/da_fei_yu_visual.tscn" id="visual"]\n[ext_resource type="Script" path="res://scripts/art_preview/da_fei_yu_idle_preview.gd" id="controller"]\n\n[sub_resource type="StyleBoxFlat" id="StyleBox_card"]\nbg_color = Color(0.965, 0.979, 0.995, 1)\ncorner_radius_top_left = 28\ncorner_radius_top_right = 28\ncorner_radius_bottom_left = 28\ncorner_radius_bottom_right = 28\n\n[sub_resource type="StyleBoxFlat" id="StyleBox_stage"]\nbg_color = Color(0.9, 0.935, 0.975, 1)\ncorner_radius_top_left = 24\ncorner_radius_top_right = 24\ncorner_radius_bottom_left = 24\ncorner_radius_bottom_right = 24\n\n[node name="DaFeiYuIdlePreview" type="Node2D"]\nscript = ExtResource("controller")\n\n[node name="Backdrop" type="ColorRect" parent="."]\noffset_right = 1066.0\noffset_bottom = 600.0\nmouse_filter = 2\ncolor = Color(0.82, 0.875, 0.94, 1)\n\n[node name="Card" type="Panel" parent="."]\noffset_left = 28.0\noffset_top = 28.0\noffset_right = 1038.0\noffset_bottom = 572.0\nmouse_filter = 2\ntheme_override_styles/panel = SubResource("StyleBox_card")\n\n[node name="Stage" type="Panel" parent="."]\noffset_left = 330.0\noffset_top = 47.0\noffset_right = 1017.0\noffset_bottom = 553.0\nmouse_filter = 2\ntheme_override_styles/panel = SubResource("StyleBox_stage")\n'; // 独立预览页面的静态背景和播放界面。
  const ellipse = Array.from({ length: 48 }, (_, index) => { // 脚下淡影仅用于交代地面，不参与角色变形。
    const phase = index * Math.PI * 2 / 48; // 当前椭圆顶点的圆周角度。
    return number(Math.cos(phase) * 91) + ', ' + number(Math.sin(phase) * 9);
  }).join(', ');
  preview += '\n[node name="GroundShadow" type="Polygon2D" parent="."]\nposition = Vector2(672, 535)\ncolor = Color(0.21, 0.3, 0.48, 0.12)\npolygon = PackedVector2Array(' + ellipse + ')\n';
  preview += '\n[node name="Character" parent="." instance=ExtResource("visual")]\nposition = Vector2(672, 535)\nscale = ' + vec(proportions.previewScale, proportions.previewScale) + '\n';
  preview += '\n[node name="Interface" type="CanvasLayer" parent="."]\n';
  preview += label('Title', 60, 62, 250, 50, '大肥鱼', 34, 'Color(0.1, 0.17, 0.31, 1)');
  preview += label('Subtitle', 60, 116, 250, 35, '待机动画 · 部件版', 19, 'Color(0.29, 0.39, 0.55, 1)');
  preview += label('Notes', 60, 190, 250, 160, '轻微呼吸起伏\n发梢柔和跟随\n鲸尾缓慢摆动\n双脚稳定着地', 19, 'Color(0.25, 0.34, 0.5, 1)');
  preview += button('PauseButton', 370, '暂停动画') + button('SpeedButton', 425, '播放速度：1×') + button('RestartButton', 480, '重新播放');
  save('scenes/art_preview/da_fei_yu_idle_preview.tscn', preview);
  console.log('已生成九个透明部件、十二条动画轨道、可复用角色场景及独立预览场景。');
}

main().catch(error => { console.error(error); process.exit(1); });
