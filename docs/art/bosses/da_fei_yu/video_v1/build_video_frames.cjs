// 将用户提供的视频机械转成透明图集及 SpriteFrames，不重绘人物或添加眨眼。
const fs = require('fs'); // 文件复制与资源写入。
const path = require('path'); // 项目相对路径。
const {spawn} = require('child_process'); // 仅调用本机 ffmpeg 解码原视频。
const sharp = require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 原帧尺寸适配、透明通道与图集打包。
const root = path.resolve(__dirname, '../../../../..'); // 仓库根目录。
const input = process.argv[2] || path.resolve(root, '../动画'); // 可选参数为原视频目录。
const output = path.join(root, 'assets/image/character/boss/da_fei_yu/video_v1'); // 透明运行图集。
const source = path.join(output, 'source'); // 原始视频原样保留，便于替换重建。
const width = 384, height = 288, fps = 24; // 原 960×720 视频缩到 40%，保留全部 24 帧动作。
const columns = 6, pageFrames = 48; // 每页最多 6×8 帧，避免超出 4096 纹理尺寸。
const bytes = width * height * 4; // 一帧 RGBA 字节数。
const releaseFrame = 87; // 幻想下第 87 帧（从零计）为盆与双手明确分离的第一帧，24 FPS 下为 3.625 秒。
let basinRelease = null; // 原视频盆的像素裁切与中心，作为运行时道具接棒的唯一依据。
const detachedCounts = []; // 记录每个离手后原帧清除的盆像素，便于核对不出现双盆。
const releaseOutline = [[12,208],[17,183],[35,160],[61,143],[89,131],[120,129],[155,137],[194,158],[230,192],[255,228],[270,261],[273,286],[267,310],[255,332],[238,350],[212,365],[182,371],[150,369],[116,358],[82,339],[50,312],[27,282],[14,254]]; // 包含原盆抗锯齿的外轮廓；相接鱼鳍和双手按原帧蓝色、肤色分离。
const basinContactEdge = [[260,270],[280,263],[300,253],[320,236],[340,215],[360,185],[375,160]]; // 原图右下钢盆边缘的 Y/X 采样，排除相接鱼鳍白边及手指残片。
const smooth = value => {const t = Math.max(0, Math.min(1, value)); return t * t * (3 - 2 * t);}; // 键控边缘缓动。

// 只根据源视频绿色背景生成 alpha，人物颜色和动作来自原帧。
function matte(frame) {
  const result = Buffer.from(frame); // 输出为非预乘 RGBA。
  const visited = new Uint8Array(width * height); // 四邻域连通域的访问状态。
  const queue = new Int32Array(width * height); // 边角文字小连通域的遍历队列。
  for (let pixel = 0; pixel < width * height; pixel++) { // 每个原帧像素。
    const offset = pixel * 4; // 当前 RGBA 偏移。
    const excess = result[offset + 1] - Math.max(result[offset], result[offset + 2]); // 绿色背景相对红蓝的超量。
    const alpha = 1 - smooth((excess - 0.5) / 6.5); // 人物为蓝、白、肤色；收紧绿色键控，避免地面绿影与压缩噪声残留。
    result[offset + 3] = alpha < 0.04 ? 0 : Math.round(alpha * 255); // 极低透明度压缩噪点直接清除。
    if (alpha < 1) result[offset + 1] = Math.min(result[offset + 1], Math.max(result[offset], result[offset + 2]) + 2); // 清理半透明边缘的绿溢色。
  }
  for (let start = 0; start < width * height; start++) { // 独立处理边角背景上的小文字，不切断与人物相连的尾巴。
    if (visited[start] || result[start * 4 + 3] < 12) continue;
    let head = 0, tail = 1; // 当前连通域的出队和入队位置。
    let minX = width, maxX = 0, minY = height, maxY = 0; // 连通域包围框。
    queue[0] = start;
    visited[start] = 1;
    while (head < tail) {
      const pixel = queue[head++]; // 当前连通像素。
      const x = pixel % width, y = Math.floor(pixel / width); // 像素坐标。
      minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      for (const next of [x > 0 ? pixel - 1 : -1, x + 1 < width ? pixel + 1 : -1, y > 0 ? pixel - width : -1, y + 1 < height ? pixel + width : -1]) { // 有效四邻域。
        if (next >= 0 && !visited[next] && result[next * 4 + 3] >= 12) {visited[next] = 1; queue[tail++] = next;}
      }
    }
    const corner = (maxY < height * 0.13 && (maxX < width * 0.25 || minX > width * 0.75)) || (minY > height * 0.89 && minX > width * 0.79); // 视频文字出现的背景边角。
    if (corner && tail < 450) { // 只移除小文字域，大人物及相连尾巴始终保留。
      for (let index = 0; index < tail; index++) result[queue[index] * 4 + 3] = 0; // 本域透明化。
    }
  }
  return result;
}

// 用原帧轮廓提取钢盆，再清除仅有盆经过的左侧空间；不重画角色、鱼鳍或双手。
async function detachBasin(frame, index) {
  if (index < releaseFrame) return frame;
  if (index === releaseFrame) { // 首帧盆与头侧鱼鳍的抗锯齿像素相接，使用标定轮廓分离，不切掉角色。
    const isolated = Buffer.alloc(bytes); // 原盆像素独立画布。
    let minX = width, maxX = 0, minY = height, maxY = 0, count = 0; // 本帧钢盆边界和像素数。
    for (let y = 0; y < height; y++) for (let x = 0; x < 120; x++) { // 只在画布左侧检查盆轮廓。
      let inside = false; // 射线法判断当前像素中心是否在原盆轮廓内。
      let edgeDistance = Infinity; // 原视频抗锯齿距标定轮廓的最小平方距离。
      const px = (x + 0.5) / 0.4, py = (y + 0.5) / 0.4; // 回到视频原始像素坐标。
      for (let a = 0, b = releaseOutline.length - 1; a < releaseOutline.length; b = a++) { // 当前多边形边的首尾索引。
        const start = releaseOutline[a], end = releaseOutline[b]; // 该边的两个原图坐标。
        if ((start[1] > py) !== (end[1] > py) && px < (end[0] - start[0]) * (py - start[1]) / (end[1] - start[1]) + start[0]) inside = !inside;
        const dx = end[0] - start[0], dy = end[1] - start[1]; // 当前轮廓边方向。
        const along = Math.max(0, Math.min(1, ((px - start[0]) * dx + (py - start[1]) * dy) / Math.max(1, dx * dx + dy * dy))); // 像素到边的最近投影。
        edgeDistance = Math.min(edgeDistance, (px - start[0] - along * dx) ** 2 + (py - start[1] - along * dy) ** 2);
      }
      const pixel = y * width + x; // 当前画布像素。
      if ((!inside && edgeDistance > 64) || !frame[pixel * 4 + 3]) continue; // 包含原图 8 像素内抗锯齿，避免留下钢盆亮边。
      const red = frame[pixel * 4], green = frame[pixel * 4 + 1], blue = frame[pixel * 4 + 2]; // 原帧局部颜色，用于保留贴着盆边的鱼鳍与手指。
      if (x > 90 && y > 105 && ((blue - red > 12 && blue - green > 5) || (red - blue > 15 && red - green > 7))) continue; // 仅在与角色相接的右下小角保护鱼鳍和手指，其余钢盆反光全部原样保留。
      frame.copy(isolated, pixel * 4, pixel * 4, pixel * 4 + 4);
      frame[pixel * 4 + 3] = 0;
      minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y); count++;
    }
    if (count < 500) throw new Error('钢盆轮廓未覆盖完整道具，请重新标定');
    const eroded = new Uint8Array(width * height), opened = new Uint8Array(width * height); // 只处理透明通道的 5×5 开运算，去掉与盆边粘连的细碎角色像素。
    for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) { // 先收缩遮罩，去除细小突刺。
      let alpha = 255; // 当前邻域的最低透明度。
      for (let oy = -2; oy <= 2; oy++) for (let ox = -2; ox <= 2; ox++) alpha = Math.min(alpha, isolated[((y + oy) * width + x + ox) * 4 + 3] || 0); // 范围外视为透明。
      eroded[y * width + x] = alpha;
    }
    for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) { // 再恢复主体轮廓，不重画金属纹理。
      let alpha = 0; // 当前邻域的最高透明度。
      for (let oy = -2; oy <= 2; oy++) for (let ox = -2; ox <= 2; ox++) alpha = Math.max(alpha, eroded[(y + oy) * width + x + ox] || 0);
      opened[y * width + x] = Math.min(alpha, isolated[(y * width + x) * 4 + 3]);
    }
    for (let pixel = 0; pixel < width * height; pixel++) { // 保持原帧颜色与尺寸，仅修整与角色相接的透明边缘。
      const sourceX = (pixel % width + 0.5) / 0.4, sourceY = (Math.floor(pixel / width) + 0.5) / 0.4; // 原视频坐标。
      let edgeAlpha = 1; // 默认完整保留钢盆。
      for (let part = 0; part + 1 < basinContactEdge.length; part++) { // 当前右下边缘线段。
        const a = basinContactEdge[part], b = basinContactEdge[part + 1]; // 以 Y 为首项的相邻轮廓点。
        if (sourceY < a[0] || sourceY >= b[0]) continue;
        const boundary = a[1] + (b[1] - a[1]) * (sourceY - a[0]) / (b[0] - a[0]); // 当前原图行的实际盆边。
        edgeAlpha = smooth((boundary - sourceX + 1.25) / 2.5); // 保留约一个输出像素的抗锯齿过渡。
      }
      isolated[pixel * 4 + 3] = Math.round(opened[pixel] * edgeAlpha);
    }
    const left = Math.max(0, minX - 2), top = Math.max(0, minY - 2); // 抗锯齿透明余量。
    const cropWidth = maxX + 3 - left, cropHeight = maxY + 3 - top; // 保持原像素尺寸的紧包围框。
    await sharp(isolated, {raw: {width, height, channels: 4}}).extract({left, top, width: cropWidth, height: cropHeight}).png().toFile(path.join(output, 'basin_projectile.png'));
    basinRelease = {frame: releaseFrame, time: releaseFrame / fps, crop: [left, top, cropWidth, cropHeight], position: [left + cropWidth / 2 - 192, top + cropHeight / 2 - 273.6]};
    await sharp(frame, {raw: {width, height, channels: 4}}).png().toFile(path.join(__dirname, 'release_without_basin.png')); // 归档清除盆后的角色，便于检查双手和鱼鳍。
    detachedCounts.push({frame: index, removed: count});
    return frame;
  }
  let removed = 0; // 本帧被替换的原视频飞行盆像素数。
  if (index <= 99) for (let y = 0; y < 160; y++) for (let x = 0; x < 100; x++) { // 第 100 帧起盆已完全离开画布，不再处理角色恢复动作。
    const sourceX = (x + 0.5) / 0.4, sourceY = (y + 0.5) / 0.4; // 原视频坐标。
    const boundary = sourceY <= 300 ? 248 : 248 - (sourceY - 300) * 58 / 70; // 向左收拢下边界，完整避开前伸双手。
    if (sourceX >= boundary) continue;
    const pixel = y * width + x; // 位于独立飞行盆经过区域的像素。
    if (frame[pixel * 4 + 3]) removed++;
    frame[pixel * 4 + 3] = 0;
  }
  detachedCounts.push({frame: index, removed});
  return frame;
}

// [name]是动画名，[file]是视频文件名；保持原有帧序与帧率。
async function decode(name, file) {
  const frames = []; // 当前动画的透明原帧。
  const process = spawn('ffmpeg', ['-v', 'error', '-i', path.join(source, file), '-an', '-vf', `scale=${width}:${height}:flags=lanczos`, '-pix_fmt', 'rgba', '-f', 'rawvideo', 'pipe:1'], {windowsHide: true}); // 静默解码，不创建可见窗口。
  let pending = Buffer.alloc(0); // 跨管道数据块的不完整帧。
  let errors = ''; // 只在解码失败时报告 ffmpeg 错误。
  process.stderr.on('data', chunk => errors += chunk.toString()); // 收集解码诊断。
  const completion = new Promise((resolve, reject) => { // 解码退出状态，避免把不完整图集当成成功。
    process.on('error', reject);
    process.on('close', code => code === 0 ? resolve() : reject(new Error(errors || 'ffmpeg exit ' + code)));
  });
  for await (const chunk of process.stdout) { // 管道返回的原始 RGBA 数据块。
    pending = Buffer.concat([pending, chunk]);
    while (pending.length >= bytes) {
      const frame = matte(pending.subarray(0, bytes)); // 当前源视频帧，保留原始动作序号。
      frames.push(name === 'dream_down' ? await detachBasin(frame, frames.length) : frame);
      pending = pending.subarray(bytes);
    }
  }
  await completion;
  if (pending.length || !frames.length) throw new Error(name + ' 视频帧不完整');
  const pages = []; // 图集文件名与各页帧数。
  for (let begin = 0; begin < frames.length; begin += pageFrames) { // 按页打包，人物始终共享同一画布与脚底锚点。
    const count = Math.min(pageFrames, frames.length - begin); // 本页有效帧数。
    const page = name + '_' + String(pages.length).padStart(2, '0') + '.png'; // 稳定的资源文件名。
    const layers = frames.slice(begin, begin + count).map((frame, index) => ({input: frame, raw: {width, height, channels: 4}, left: index % columns * width, top: Math.floor(index / columns) * height})); // 每帧仅复制到对应图格。
    await sharp({create: {width: width * columns, height: height * Math.ceil(count / columns), channels: 4, background: '#00000000'}}).composite(layers).png().toFile(path.join(output, page));
    pages.push({page, count});
  }
  if (name === 'idle') await sharp(frames[0], {raw: {width, height, channels: 4}}).png().toFile(path.join(output, 'idle_poster.png')); // 图鉴头像与初始预览用原待机首帧。
  console.log(name + ': ' + frames.length + ' frames, ' + pages.length + ' atlases');
  return {name, frameCount: frames.length, pages};
}

// 写入 Godot 原生帧资源，所有动画共享脚底锚点，不叠加额外身体动作。
function resource(clips) {
  const definitions = [], animations = []; // 图集纹理、全部视频动画与幻想等待循环的文本。
  let ordinal = 0; // 全资源中唯一的帧索引。
  let text = '[gd_resource type="SpriteFrames" format=3]\n\n'; // Godot 原生资源头。
  for (const clip of clips) { // 入场和待机分别控制是否循环。
    const sequence = []; // 当前动画按原序排列的帧。
    for (const [index, page] of clip.pages.entries()) { // 当前图集及局部帧。
      const id = clip.name + '_' + index; // 外部图集资源 ID。
      text += `[ext_resource type="Texture2D" path="res://assets/image/character/boss/da_fei_yu/video_v1/${page.page}" id="${id}"]\n`;
      for (let frame = 0; frame < page.count; frame++) { // 当前图格索引。
        const frameId = 'frame_' + ordinal++; // 当前 AtlasTexture 子资源 ID。
        definitions.push(`[sub_resource type="AtlasTexture" id="${frameId}"]\natlas = ExtResource("${id}")\nregion = Rect2(${frame % columns * width}, ${Math.floor(frame / columns) * height}, ${width}, ${height})\nfilter_clip = true\n`);
        sequence.push(`{ "duration": 1.0, "texture": SubResource("${frameId}") }`);
      }
    }
    const playbackFps = fps * (clip.name === 'entrance' ? 1.5 : clip.name === 'idle' ? 1.3 : 1); // 只加速入场和普通待机，其余技能及帧触发时点保持原速。
    animations.push(`{\n"name": &"${clip.name}",\n"loop": ${clip.name === 'idle'},\n"speed": ${playbackFps},\n"frames": [${sequence.join(',\n')}]\n}`);
    if (clip.name === 'dream_up') animations.push(`{\n"name": &"dream_hold",\n"loop": true,\n"speed": ${fps}.0,\n"frames": [${sequence.slice(-24).join(',\n')}]\n}`); // 仅复用原视频第121～144帧（零基，最后1秒）：望着米饭流口水，不再循环前面的表情变化。
  }
  text += '\n' + definitions.join('\n') + '\n[resource]\nanimations = [' + animations.join(',\n') + ']\n';
  fs.writeFileSync(path.join(root, 'animation/character/zombie_boss/da_fei_yu/da_fei_yu_video_frames.tres'), text);
}

async function main() {
  fs.mkdirSync(source, {recursive: true});
  fs.writeFileSync(path.join(source, '.gdignore'), ''); // 原始 MP4 仅用于重建，不作为运行资源导入或导出。
  for (const file of ['入场动画.mp4', '待机动画.mp4', '攻击动作-幻想上.mp4', '攻击动作-幻想下.mp4', '交互动作 - Token来.mp4', '换行动作-上.mp4', '换行动作-下.mp4', '召唤动作.mp4', '退场动作.mp4']) fs.copyFileSync(path.join(input, file), path.join(source, file)); // 用户原文件不移动、不改写。
  const clips = []; // 记录实际解码帧数，而不是猜测视频容器时长。
  for (const [name, file] of [['entrance', '入场动画.mp4'], ['idle', '待机动画.mp4'], ['dream_up', '攻击动作-幻想上.mp4'], ['dream_down', '攻击动作-幻想下.mp4'], ['token', '交互动作 - Token来.mp4'], ['lane_dive', '换行动作-上.mp4'], ['lane_emerge', '换行动作-下.mp4'], ['summon', '召唤动作.mp4'], ['exit', '退场动作.mp4']]) clips.push(await decode(name, file)); // 保持输入顺序。
  resource(clips);
  fs.writeFileSync(path.join(root, 'animation/character/zombie_boss/da_fei_yu/da_fei_yu_video_cues.tres'), '[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/basin_release_frame = '+releaseFrame+'\nmetadata/basin_release_position = Vector2('+basinRelease.position.join(', ')+')\nmetadata/entrance_music_frame = 138\nmetadata/dream_ready_frame = 100\nmetadata/token_frame = 48\nmetadata/summon_frame = 78\n'); // 时间与离手位置来自同一处理流程。
  fs.writeFileSync(path.join(__dirname, 'manifest.json'), JSON.stringify({width, height, fps, anchor: [192, 273.6], clips, basinRelease, detachedCounts}, null, 2) + '\n');
}
main().catch(error => {console.error(error); process.exitCode = 1;}); // 失败明确退出，不继续接入缺失图集。
