// 在仓库根目录运行：导出左向部件，生成角色场景、待机轨道及独立预览。
const fs = require('fs'); // 读取原始部件表并保存 Godot 文本资源。
const path = require('path'); // 定位项目中的素材与场景目录。
const sharp = require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 仅用于切分透明 PNG 及等比导出，不绘制角色。
const docDir = 'docs/art/bosses/da_fei_yu/idle_left_v1'; // 左向素材原图、清单与生成记录目录。
const assetDir = 'assets/image/character/boss/da_fei_yu/idle_left_parts_v1'; // 六个左向部件的导出目录。
const scenePath = 'scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_visual.tscn'; // 可独立复用的左向美术角色。
const animPath = 'animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left.tres'; // 四秒循环的左向待机动画资源。
const manifest = JSON.parse(fs.readFileSync(docDir + '/parts_manifest.json', 'utf8')); // 原始生成图中各部件的来源矩形及目标大小。
const duration = 4; // 单次待机循环的时长，单位为秒。
const samples = 32; // 连续轨道一圈的采样区间数，首尾保存相同姿势。
const format = value => String(Number(value.toFixed(6))); // 规整输出数值，避免浮点尾差进入资源。
const vector = (x, y) => 'Vector2(' + format(x) + ', ' + format(y) + ')'; // 将像素坐标序列化为 Godot 二维向量。
const phase = time => Math.PI * 2 * time / duration; // 将循环内秒数换成相位角。
const breathe = time => -2 * (1 - Math.cos(phase(time))); // 身体上升四个本地像素后缓慢落回起点。
const tracks = [ // 固定贴图仅随关节变换，五官和服饰保持一致。
  { target: 'BodyMotion:position', rest: vector(0, -150), value: time => vector(0, -150 + breathe(time)) },
  { target: 'BodyMotion:scale', rest: vector(1, 1), value: time => vector(1, 1 + 0.003 * (1 - Math.cos(phase(time)))) },
  { target: 'BodyMotion/HeadPivot:position', rest: vector(-18, -68), value: time => vector(-18, -68 - 0.25 * (1 - Math.cos(phase(time) - 0.15))) },
  { target: 'BodyMotion/HeadPivot:rotation', rest: '0.0', value: time => format(0.003 * Math.sin(phase(time) - 0.3)) },
  { target: 'HairPivot:position', rest: vector(28, -410), value: time => vector(28, -410 + 0.8 * breathe(time)) },
  { target: 'HairPivot:rotation', rest: '0.0', value: time => format(0.009 * Math.sin(phase(time) - 0.55)) },
  { target: 'TailPivot:position', rest: vector(30, -122), value: time => vector(30, -122 + 0.4 * breathe(time)) },
  { target: 'TailPivot:rotation', rest: '0.0', value: time => format(0.038 * Math.sin(phase(time) - 0.8)) },
  { target: 'BodyMotion/ArmPivot:rotation', rest: '0.0', value: time => format(0.014 * Math.sin(phase(time) - 0.4)) }
];

// 保存项目相对路径指向的文本资源，父目录不存在时自动创建。
function save(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

// 将单条部件变换轨道写为 Godot Animation 资源格式；reset 为真时仅写入静止姿势。
function trackText(track, index, reset = false) {
  const times = reset ? [0] : Array.from({ length: samples + 1 }, (_, key) => key * duration / samples); // 当前轨道的采样秒数。
  const values = reset ? [track.rest] : times.map(track.value); // 与采样时刻对应的变换值。
  const prefix = 'tracks/' + index + '/'; // 当前轨道在文本资源中的索引前缀。
  return [prefix + 'type = "value"', prefix + 'imported = false', prefix + 'enabled = true', prefix + 'path = NodePath("' + track.target + '")', prefix + 'interp = 1', prefix + 'loop_wrap = true', prefix + 'keys = {', '"times": PackedFloat32Array(' + times.map(format).join(', ') + '),', '"transitions": PackedFloat32Array(' + times.map(() => '1').join(', ') + '),', '"update": 0,', '"values": [' + values.join(', ') + ']', '}'].join('\n');
}

// 创建二维关节；位置以脚底原点为基准，层级决定遮挡顺序。
function joint(name, parent, x, y, layer = 0) {
  return '\n[node name="' + name + '" type="Node2D" parent="' + parent + '"]\nposition = ' + vector(x, y) + '\nz_index = ' + layer + '\n';
}

// 创建左上角定位的透明部件；位置对齐父关节，贴图本身无需每帧变化。
function sprite(name, parent, texture, x, y, layer = 0) {
  return '\n[node name="' + name + '" type="Sprite2D" parent="' + parent + '"]\nposition = ' + vector(x, y) + '\nz_index = ' + layer + '\ntexture = ExtResource("' + texture + '")\ncentered = false\n';
}

// 从统一左侧视角原图导出部件并建立 Godot 动画；不启动游戏，不运行测试。
async function main() {
  fs.mkdirSync(assetDir, { recursive: true });
  for (const part of manifest) { // 按已记录的来源矩形提取六个部件。
    const [left, top, width, height] = part.rect; // 当前部件在原始图中的像素区域。
    const cropped = await sharp(docDir + '/parts_raw.png').extract({ left, top, width, height }).png().toBuffer(); // 先独立切分，避免去透明留白改变坐标。
    const output = await sharp(cropped).trim({ threshold: 20 }).resize({ width: part.size[0], height: part.size[1], fit: 'inside' }).png().toFile(assetDir + '/' + part.name + '.png'); // 导出后实际尺寸供后续装配参考。
    part.width = output.width;
    part.height = output.height;
  }
  save(docDir + '/parts_manifest.json', JSON.stringify(manifest, null, 2) + '\n');
  save(animPath, '[gd_resource type="Animation" format=3]\n\n[resource]\nresource_name = "idle"\nlength = 4.0\nloop_mode = 1\nstep = 0.033333\n' + tracks.map((track, index) => trackText(track, index)).join('\n\n') + '\n');
  let scene = '[gd_scene load_steps=10 format=3]\n'; // 六张贴图、一动画与两个内置资源组成的左向角色场景。
  for (const part of manifest) { // 注册当前六个透明部件。
    scene += '\n[ext_resource type="Texture2D" path="res://' + assetDir + '/' + part.name + '.png" id="' + part.name + '"]';
  }
  scene += '\n[ext_resource type="Animation" path="res://' + animPath + '" id="idle"]\n';
  scene += '\n[sub_resource type="Animation" id="Animation_reset"]\nresource_name = "RESET"\nlength = 0.001\n' + tracks.map((track, index) => trackText(track, index, true)).join('\n\n') + '\n';
  scene += '\n[sub_resource type="AnimationLibrary" id="AnimationLibrary_idle"]\n_data = {\n&"RESET": SubResource("Animation_reset"),\n&"idle": ExtResource("idle")\n}\n';
  scene += '\n[node name="DaFeiYuLeftVisual" type="Node2D"]\ntexture_filter = 2\n';
  scene += joint('TailPivot', '.', 30, -122, 0) + sprite('Tail', 'TailPivot', 'tail', -9, -57);
  scene += joint('HairPivot', '.', 28, -410, 1) + sprite('Hair', 'HairPivot', 'hair', -110, 0);
  scene += sprite('Legs', '.', 'legs', -58, -72, 2);
  scene += joint('BodyMotion', '.', 0, -150, 3) + sprite('Dress', 'BodyMotion', 'dress', -98, -118, 1);
  scene += joint('ArmPivot', 'BodyMotion', 35, -85, 2) + sprite('Arm', 'BodyMotion/ArmPivot', 'arm', -27, -10);
  scene += joint('HeadPivot', 'BodyMotion', -18, -68, 3) + sprite('Head', 'BodyMotion/HeadPivot', 'head', -125, -268, 2);
  scene += sprite('CollarOverlay', 'BodyMotion', 'dress', -58, -118, 6) + 'region_enabled = true\nregion_rect = Rect2(40, 0, 82, 65)\n'; // 让领口遮住隐藏的颈根，保持短脖子的紧凑比例。
  scene += '\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = {\n&"": SubResource("AnimationLibrary_idle")\n}\nautoplay = "idle"\n';
  save(scenePath, scene);
  const preview = fs.readFileSync('scenes/art_preview/da_fei_yu_idle_preview.tscn', 'utf8')
    .replace('res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_visual.tscn', 'res://' + scenePath)
    .replace('name="DaFeiYuIdlePreview"', 'name="DaFeiYuIdleLeftPreview"')
    .replace('待机动画 · 部件版', '待机动画 · 面向左侧'); // 沿用已有的播放界面及控制脚本，仅引用新建的左向角色。
  save('scenes/art_preview/da_fei_yu_idle_left_preview.tscn', preview);
  console.log('已生成左向六部件角色、九条待机轨道及独立预览场景。');
}

main().catch(error => { console.error(error); process.exit(1); });
