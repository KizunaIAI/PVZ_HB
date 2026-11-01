// 在仓库根目录运行：导出钢盆配件，并绑定到现有左向角色的头部骨骼。
const fs = require('fs'); // 读取配件原图、基础预览及保存场景。
const path = require('path'); // 创建输出资源所需的父目录。
const sharp = require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 仅去除透明留白并等比导出钢盆 PNG。
const docDir = 'docs/art/bosses/da_fei_yu/steel_basin_v1'; // 钢盆参考、生成原图、提示词与装配记录目录。
const texturePath = 'assets/image/character/boss/da_fei_yu/steel_basin_v1/basin.png'; // 角色佩戴的独立透明配件。
const scenePath = 'scenes/character/zombie_boss/da_fei_yu/da_fei_yu_steel_basin_visual.tscn'; // 继承既有完整角色的钢盆外观场景。
const baseScene = 'scenes/character/zombie_boss/da_fei_yu/da_fei_yu_left_v2_visual.tscn'; // 保持现有造型、网格与待机动画的基础场景。
const manifest = JSON.parse(fs.readFileSync('docs/art/bosses/da_fei_yu/idle_left_v2/rig_manifest.json', 'utf8')); // 用于定位头部骨骼的已有绑定位置。
const headBone = manifest.bones.find(bone => bone.name === 'Head'); // 既有头部骨骼的局部绑定姿势。

// 保存仓库相对路径指向的文本资源，父目录不存在时自动创建。
function save(file, content) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content, 'utf8');
}

// 导出配件并继承基础角色；不重建基础网格、不改写动画轨道，不运行测试。
async function main() {
  fs.mkdirSync(path.dirname(texturePath), { recursive: true });
  const output = await sharp(docDir + '/basin_source.png').trim({ threshold: 20 }).resize({ width: 245 }).png().toFile(texturePath); // 等比导出的实际钢盆尺寸。
  const crownX = 118; // 钢盆在完整角色贴图坐标系中的水平中心，覆盖头顶与呆毛。
  const rimY = 80; // 钢盆最下沿在完整贴图中的高度，保证露出眼睛与侧面发饰。
  const offsetX = Number((crownX - headBone.x).toFixed(6)); // 将配件水平中心换算为头部骨骼的局部位置。
  const offsetY = Number((rimY - output.height / 2 - headBone.y).toFixed(6)); // 将钢盆下沿对齐头顶，配件随头部动画一同起伏。
  const scene = '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="PackedScene" path="res://' + baseScene + '" id="base"]\n[ext_resource type="Texture2D" path="res://' + texturePath + '" id="basin"]\n\n[node name="DaFeiYuSteelBasinVisual" instance=ExtResource("base")]\n\n[node name="SteelBasin" type="Sprite2D" parent="Rig/Skeleton2D/Head" index="0"]\nposition = Vector2(' + offsetX + ', ' + offsetY + ')\nz_index = 10\ntexture = ExtResource("basin")\n'; // 配件作为头骨骼子节点添加，保持钢盆金属形状为刚性。
  save(scenePath, scene);
  const preview = fs.readFileSync('scenes/art_preview/da_fei_yu_idle_left_v2_preview.tscn', 'utf8')
    .replace('res://' + baseScene, 'res://' + scenePath)
    .replace('name="DaFeiYuIdleLeftV2Preview"', 'name="DaFeiYuSteelBasinPreview"')
    .replace('待机动画 · 左侧新版', '待机动画 · 钢盆版'); // 沿用既有暂停、半速及重播功能。
  save('scenes/art_preview/da_fei_yu_steel_basin_preview.tscn', preview);
  save('scenes/art_preview/da_fei_yu_idle_left_preview.tscn', preview);
  save(docDir + '/attachment.json', JSON.stringify({ texture: texturePath, base_scene: baseScene, scene: scenePath, bone: 'Rig/Skeleton2D/Head', width: output.width, height: output.height, image_center_x: crownX, image_rim_y: rimY, local_position: [offsetX, offsetY] }, null, 2) + '\n');
  console.log('已将倒扣钢盆绑定到头部骨骼，并更新左向预览入口。');
}

main().catch(error => { console.error(error); process.exit(1); });
