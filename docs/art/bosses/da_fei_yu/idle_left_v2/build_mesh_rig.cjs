// 在仓库根目录运行：从完整参考造型导出贴图，并建立 Godot 原生二维骨骼待机。
const fs = require('fs'); // 保存角色场景、动画与构建记录。
const path = require('path'); // 根据仓库相对路径定位输出目录。
const sharp = require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 仅用于去除透明留白及等比导出完整贴图。
const docDir = 'docs/art/bosses/da_fei_yu/idle_left_v2'; // 本轮指定参考图、生成原图与提示词目录。
const assetPath = 'assets/image/character/boss/da_fei_yu/idle_left_v2/character.png'; // 一张完整的透明角色贴图，避免重复拼装改变造型。
const scenePath = 'scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_v2_visual.tscn'; // 新左侧美术角色的可复用场景。
const animationPath = 'animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v2.tres'; // 新骨骼待机的四秒循环轨道。
const columns = 28; // 网格横向划分数，用于平滑传递骨骼变换。
const rows = 40; // 网格纵向划分数，保证颈部、裙摆及尾巴附近有足够插值点。
const duration = 4; // 待机循环时长，单位为秒。
const samples = 32; // 每条变换轨道一圈的采样区间数。
const number = value => String(Number(value.toFixed(6))); // 规整浮点输出，确保首尾周期值一致。
const vector = (x, y) => 'Vector2(' + number(x) + ', ' + number(y) + ')'; // 将坐标转换为 Godot 文本资源格式。
const phase = time => Math.PI * 2 * time / duration; // 将循环内时间转换为角度相位。
const breathe = time => -2 * (1 - Math.cos(phase(time))); // 上半身上升四个本地像素后回到静止高度。

// 在给定区间平滑地从零过渡到一，用于避免骨骼影响区域出现硬折线。
function smooth(start, end, value) {
  const unit = Math.max(0, Math.min(1, (value - start) / (end - start))); // 限制到零至一的标准区间。
  return unit * unit * (3 - 2 * unit);
}

// 为归一化坐标 u、v 指定脚、身体、头发和尾巴的连续权重，总和为一。
function influences(u, v) {
  const foot = smooth(0.82, 0.94, v) * (1 - smooth(0.48, 0.60, u)); // 鞋底区域完全固定；小腿与躯干之间逐渐过渡。
  const flukeDistance = Math.hypot((u - 0.88) / 0.22, (v - 0.70) / 0.16); // 尾鳍周围的椭圆距离，避免整片后发随尾巴转动。
  const fluke = 1 - smooth(0.6, 1.2, flukeDistance); // 远端尾鳍的影响范围。
  const lowerTail = smooth(0.77, 0.86, v) * smooth(0.43, 0.61, u); // 裙摆后下方的弧形尾身区域。
  const tail = (1 - foot) * Math.max(fluke, lowerTail); // 排除腿脚后保留尾巴的局部摆动。
  const head = (1 - foot - tail) * (1 - smooth(0.46, 0.55, v)); // 五官区域保持整体刚性，颈部小范围平滑过渡。
  const hairMask = smooth(0.43, 0.65, u) * smooth(0.35, 0.55, v) * (1 - smooth(0.76, 0.86, v)); // 右侧后发与发梢的柔和跟随区域。
  const hair = Math.max(0, 1 - foot - tail - head) * hairMask; // 从剩余权重中分配后发，避免超过总权重。
  const body = Math.max(0, 1 - foot - tail - head - hair); // 其余衣裙与手臂区域随躯干小幅呼吸。
  return { Feet: foot, Body: body, Head: head, Hair: hair, Tail: tail };
}

// 保存一个仓库相对路径指向的文本资源，并创建所需父目录。
function save(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

// 将单条骨骼变换轨道写为 Godot Animation 格式；reset 为真时仅保存静止姿势。
function serializeTrack(track, index, reset = false) {
  const times = reset ? [0] : Array.from({ length: samples + 1 }, (_, key) => duration * key / samples); // 每个关键帧对应的秒数。
  const values = reset ? [track.rest] : times.map(track.value); // 静止姿势或连续循环采样值。
  const prefix = 'tracks/' + index + '/'; // 当前轨道的资源索引前缀。
  return [prefix + 'type = "value"', prefix + 'imported = false', prefix + 'enabled = true', prefix + 'path = NodePath("' + track.target + '")', prefix + 'interp = 1', prefix + 'loop_wrap = true', prefix + 'keys = {', '"times": PackedFloat32Array(' + times.map(number).join(', ') + '),', '"transitions": PackedFloat32Array(' + times.map(() => '1').join(', ') + '),', '"update": 0,', '"values": [' + values.join(', ') + ']', '}'].join('\n');
}

// 导出贴图并创建真实 Skeleton2D、Bone2D 与 Polygon2D 资源；不启动场景、不运行测试。
async function main() {
  fs.mkdirSync(path.dirname(assetPath), { recursive: true });
  const image = await sharp(docDir + '/character_source.png').trim({ threshold: 20 }).resize({ height: 500 }).png().toFile(assetPath); // 等比导出的完整透明形象。
  const width = image.width; // 完整贴图宽度，作为网格与 UV 的水平像素单位。
  const height = image.height; // 完整贴图高度，作为网格与 UV 的垂直像素单位。
  const bones = [ // 所有关节采用同一贴图坐标系，绑定姿势不改变绘制好的轮廓。
    { name: 'Feet', x: width * 0.32, y: height, length: 30 },
    { name: 'Body', x: width * 0.30, y: height * 0.67, length: 60 },
    { name: 'Head', x: width * 0.28, y: height * 0.49, length: 80 },
    { name: 'Hair', x: width * 0.58, y: height * 0.37, length: 100 },
    { name: 'Tail', x: width * 0.51, y: height * 0.80, length: 80 }
  ];
  const tracks = []; // 身体、头、后发与鲸尾的播放轨道，脚底关节保持不动。
  for (const bone of bones) { // 为可动关节建立位移及局部摆动轨道。
    if (bone.name === 'Feet') continue;
    const follow = { Body: 1, Head: 0.8, Hair: 0.65, Tail: 0.25 }[bone.name]; // 各关节对呼吸高度的跟随程度。
    tracks.push({ target: 'Rig/Skeleton2D/' + bone.name + ':position', rest: vector(bone.x, bone.y), value: time => vector(bone.x, bone.y + breathe(time) * follow) });
    const swing = { Body: 0, Head: 0.001, Hair: 0.006, Tail: 0.022 }[bone.name]; // 关节摆动角度系数，单位为弧度。
    const delay = bone.name === 'Tail' ? 0.8 : 0.6; // 后发与尾巴错开相位，避免同步摆动。
    if (swing > 0) tracks.push({ target: 'Rig/Skeleton2D/' + bone.name + ':rotation', rest: '0.0', value: time => number(swing * (Math.sin(phase(time) - delay) + Math.sin(delay))) });
  }
  save(animationPath, '[gd_resource type="Animation" format=3]\n\n[resource]\nresource_name = "idle"\nlength = 4.0\nloop_mode = 1\nstep = 0.033333\n' + tracks.map((track, index) => serializeTrack(track, index)).join('\n\n') + '\n');
  const points = []; // 网格顶点，与 UV 一一对应。
  const polygons = []; // 每个网格单元拆成两个三角形，避免整张图按外轮廓错误三角化。
  const weights = Object.fromEntries(bones.map(bone => [bone.name, []])); // 五个关节各自影响全部顶点的权重数组。
  for (let row = 0; row <= rows; row++) { // 从上到下构建规则网格。
    for (let column = 0; column <= columns; column++) { // 从左到右构建当前行的顶点。
      const u = column / columns; // 当前顶点的归一化水平坐标。
      const v = row / rows; // 当前顶点的归一化垂直坐标。
      const blend = influences(u, v); // 当前顶点对各关节的连续权重。
      points.push(number(u * width), number(v * height));
      for (const bone of bones) weights[bone.name].push(number(blend[bone.name])); // 保存与顶点顺序一致的权重。
      if (row < rows && column < columns) {
        const start = row * (columns + 1) + column; // 当前小格左上顶点的索引。
        polygons.push('PackedInt32Array(' + [start, start + 1, start + columns + 2].join(', ') + ')');
        polygons.push('PackedInt32Array(' + [start, start + columns + 2, start + columns + 1].join(', ') + ')');
      }
    }
  }
  let scene = '[gd_scene load_steps=5 format=3]\n\n[ext_resource type="Texture2D" path="res://' + assetPath + '" id="texture"]\n[ext_resource type="Animation" path="res://' + animationPath + '" id="idle"]\n'; // 一贴图、一动画及两个内置资源组成的可复用骨骼场景。
  scene += '\n[sub_resource type="Animation" id="Animation_reset"]\nresource_name = "RESET"\nlength = 0.001\n' + tracks.map((track, index) => serializeTrack(track, index, true)).join('\n\n') + '\n';
  scene += '\n[sub_resource type="AnimationLibrary" id="AnimationLibrary_idle"]\n_data = {\n&"RESET": SubResource("Animation_reset"),\n&"idle": ExtResource("idle")\n}\n';
  scene += '\n[node name="DaFeiYuLeftV2Visual" type="Node2D"]\ntexture_filter = 2\n\n[node name="Rig" type="Node2D" parent="."]\nposition = ' + vector(-width * 0.32, -height) + '\n\n[node name="Skeleton2D" type="Skeleton2D" parent="Rig"]\n';
  for (const bone of bones) { // 保存绑定姿势，叶骨骼关闭自动推算长度，避免无子骨骼警告。
    scene += '\n[node name="' + bone.name + '" type="Bone2D" parent="Rig/Skeleton2D"]\nposition = ' + vector(bone.x, bone.y) + '\nrest = Transform2D(1, 0, 0, 1, ' + number(bone.x) + ', ' + number(bone.y) + ')\nauto_calculate_length_and_angle = false\nlength = ' + bone.length + '.0\n';
  }
  scene += '\n[node name="Mesh" type="Polygon2D" parent="Rig"]\ntexture = ExtResource("texture")\nskeleton = NodePath("../Skeleton2D")\npolygon = PackedVector2Array(' + points.join(', ') + ')\nuv = PackedVector2Array(' + points.join(', ') + ')\npolygons = [' + polygons.join(', ') + ']\nbones = [' + bones.map(bone => '"' + bone.name + '", PackedFloat32Array(' + weights[bone.name].join(', ') + ')').join(', ') + ']\n';
  scene += '\n[node name="AnimationPlayer" type="AnimationPlayer" parent="."]\nlibraries = {\n&"": SubResource("AnimationLibrary_idle")\n}\nautoplay = "idle"\n';
  save(scenePath, scene);
  const oldPreview = 'scenes/art_preview/da_fei_yu_idle_left_preview.tscn'; // 保留上一版入口，便于回看与比较。
  const archivePreview = 'scenes/art_preview/da_fei_yu_idle_left_v1_preview.tscn'; // 上一版分部件场景的备份入口。
  if (!fs.existsSync(archivePreview) && fs.existsSync(oldPreview)) fs.copyFileSync(oldPreview, archivePreview);
  const preview = fs.readFileSync('scenes/art_preview/da_fei_yu_idle_preview.tscn', 'utf8')
    .replace('res://scenes/character/zombie_boss/da_fei_yu/da_fei_yu_visual.tscn', 'res://' + scenePath)
    .replace('name="DaFeiYuIdlePreview"', 'name="DaFeiYuIdleLeftV2Preview"')
    .replace('待机动画 · 部件版', '待机动画 · 左侧新版'); // 沿用已有的暂停、半速和重播界面。
  save('scenes/art_preview/da_fei_yu_idle_left_v2_preview.tscn', preview);
  save(oldPreview, preview);
  save(docDir + '/rig_manifest.json', JSON.stringify({ texture: assetPath, width, height, columns, rows, vertex_count: points.length / 2, triangle_count: polygons.length, duration_seconds: duration, bones, animation_tracks: tracks.length, foot_origin: [width * 0.32, height] }, null, 2) + '\n');
  console.log('已生成完整贴图、五个二维骨骼、加权网格及四秒待机。');
}

main().catch(error => { console.error(error); process.exit(1); });
