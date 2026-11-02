// 生成大肥鱼待机 v3：12 秒三层表演循环（呼吸 / 眨眼 / 三次小俏皮）。
// 只写动画资源与清单，不改角色贴图、骨骼、比例或既有场景结构。
// 用法：node docs/art/bosses/da_fei_yu/idle_v3/build_idle_v3.cjs
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '../../../../..');
const n = value => String(Number(value.toFixed(6)));
const v = (x, y) => 'Vector2(' + n(x) + ', ' + n(y) + ')';

const DURATION = 12;       // 完整循环长度，包含三次呼吸、三次眨眼、三次俏皮拍点
const STEP = 1 / 32;       // 连续轨道的采样间隔，配合三次插值
const FPS = 30;            // 眨眼轨道按游戏帧率对齐

// 骨骼绑定值，与原场景保持一致
const BONES = {
  Body: { x: 104.4, y: 335 },
  Head: { x: 97.44, y: 245 },
  Hair: { x: 201.84, y: 185 },
  Tail: { x: 177.48, y: 400 },
  SteelBasin: { x: 30.920002, y: -196.49997 },
};

const ease = u => (1 - Math.cos(Math.PI * Math.min(1, Math.max(0, u)))) / 2;
const smooth = (a, b, value) => {
  const u = Math.min(1, Math.max(0, (value - a) / (b - a)));
  return u * u * (3 - 2 * u);
};

// 三次呼吸：吸气 1.4 秒、顶点 0.15 秒、呼气 2.45 秒；第二、三次略浅
const BREATH_AMP = [6.0, 5.2, 4.6];
function breathBase(u) {
  if (u < 1.4) return ease(u / 1.4);
  if (u < 1.55) return 1;
  // 呼气：把时间轴在 1/3 处压出一段静止的“叹气停顿”，再用 0.9 归一化保证末端回到 0
  const ex = (u - 1.55) / 2.45;
  const held = ex < 0.33 ? ex : (ex < 0.43 ? 0.33 : ex - 0.10);
  return 1 - ease(held / 0.9);
}
function breath(time) {
  const cycle = Math.floor(time / 4);
  const u = time - cycle * 4;
  const amp = BREATH_AMP[((cycle % 3) + 3) % 3];
  return -amp * breathBase(u);
}

// 延迟采样并重新归零，保证循环首尾同值同速
const delayed = (time, delay) => breath(time - delay) - breath(-delay);

// 12 秒周期的缓慢重心摆动，同样做归零处理
const wave = (time, delay) => {
  const phi = Math.PI * 2 / DURATION;
  return Math.sin(phi * (time - delay)) - Math.sin(-phi * delay);
};

// 关键点曲线：段间用 smoothstep 过渡，端点速度为零
function keyed(points, time) {
  if (time <= points[0][0] || time >= points[points.length - 1][0]) return 0;
  for (let i = 0; i < points.length - 1; i++) {
    const [t0, v0] = points[i];
    const [t1, v1] = points[i + 1];
    if (time >= t0 && time <= t1) {
      const u = (time - t0) / (t1 - t0);
      return v0 + (v1 - v0) * (u * u * (3 - 2 * u));
    }
  }
  return 0;
}

// 俏皮拍点①：尾鳍得意地点两下（单位：弧度）
const TAIL_FLICK_POINTS = [
  [3.60, 0], [3.75, 0.078], [3.87, -0.026], [3.97, 0.052], [4.075, 0.012], [4.30, 0],
];
// 俏皮拍点②：歪头偷瞄 -3.6°，保持时再缓慢漂 -0.3°，回正带 0.45° 过冲
const HEAD_TILT_POINTS = [
  [6.80, 0], [6.98, -0.063], [7.75, -0.068], [7.95, 0.008], [8.05, 0],
];
// 俏皮拍点③：钢盆阻尼回正（单位：弧度）
const BASIN_WOBBLE_POINTS = [
  [10.10, 0], [10.22, 0.038], [10.40, -0.020], [10.60, 0.011], [10.80, -0.005], [11.10, 0],
];
const BASIN_SLIDE_POINTS = [
  [10.10, 0], [10.30, 1.2], [10.55, -0.6], [10.80, 0.3], [11.10, 0],
];

const tilt = time => keyed(HEAD_TILT_POINTS, time);
const tailFlick = time => keyed(TAIL_FLICK_POINTS, time);
const basinWobble = time => keyed(BASIN_WOBBLE_POINTS, time);
const basinSlide = time => keyed(BASIN_SLIDE_POINTS, time);

// 眨眼时间线：状态切换点全部落在 1/30 秒网格上
const BLINKS = [
  ['open', 0], ['half', 1.2000], ['closed', 1.2333], ['half', 1.3000], ['open', 1.3333],
  ['half', 5.4500], ['closed', 5.4833], ['half', 5.5500], ['open', 5.5833],
  ['half', 5.7833], ['closed', 5.8167], ['half', 5.8833], ['open', 5.9167],
  ['half', 9.3000], ['closed', 9.3333], ['half', 9.4667], ['open', 9.8333],
];

function blinkTracks() {
  const times = BLINKS.map(([, t]) => t);
  const half = BLINKS.map(([s]) => s === 'half');
  const closed = BLINKS.map(([s]) => s === 'closed');
  return [
    { path: 'Rig/Skeleton2D/Head/EyeHalf:visible', bool: half, times },
    { path: 'Rig/Skeleton2D/Head/EyeClosed:visible', bool: closed, times },
  ];
}

function boneTracks() {
  const tracks = [
    {
      path: 'Rig/Skeleton2D/Body:position',
      value: t => v(BONES.Body.x + 2.0 * wave(t, 0), BONES.Body.y + delayed(t, 0)),
    },
    {
      path: 'Rig/Skeleton2D/Head:position',
      value: t => v(BONES.Head.x + 1.6 * wave(t, 0.06), BONES.Head.y + 0.92 * delayed(t, 0.06)),
    },
    {
      path: 'Rig/Skeleton2D/Head:rotation',
      value: t => n(0.006 * wave(t, 0.30) + tilt(t)),
    },
    {
      path: 'Rig/Skeleton2D/Hair:position',
      value: t => v(BONES.Hair.x + 2.4 * wave(t, 0.25), BONES.Hair.y + 0.70 * delayed(t, 0.25)),
    },
    {
      path: 'Rig/Skeleton2D/Hair:rotation',
      value: t => n(0.012 * wave(t, 0.50) + 0.35 * tilt(t - 0.12)),
    },
    {
      path: 'Rig/Skeleton2D/Tail:position',
      value: t => v(BONES.Tail.x + 1.4 * wave(t, 0.50), BONES.Tail.y + 0.30 * delayed(t, 0.50)),
    },
    {
      path: 'Rig/Skeleton2D/Tail:rotation',
      value: t => n(0.030 * wave(t, 0.70) + tailFlick(t)),
    },
  ];
  return tracks;
}

// 钢盆的两条次级运动轨道，只写进戴盆版本
function basinTracks() {
  return [
    {
      path: 'Rig/Skeleton2D/Head/SteelBasin:position',
      value: t => v(BONES.SteelBasin.x + basinSlide(t), BONES.SteelBasin.y + 0.4 * basinSlide(t)),
    },
    {
      path: 'Rig/Skeleton2D/Head/SteelBasin:rotation',
      value: t => n(0.32 * tilt(t - 0.10) + basinWobble(t)),
    },
  ];
}

function sampleTimes() {
  const times = [];
  for (let t = 0; t <= DURATION + 1e-9; t += STEP) times.push(Math.min(DURATION, Number(t.toFixed(6))));
  return times;
}

function serialize(track, index) {
  const prefix = 'tracks/' + index + '/';
  const times = track.bool ? track.times : sampleTimes();
  const values = track.bool ? track.bool.map(b => (b ? 'true' : 'false')) : times.map(track.value);
  const interp = track.bool ? 1 : 2; // 布尔轨道用最近插值，变换轨道用三次插值
  return [
    prefix + 'type = "value"',
    prefix + 'imported = false',
    prefix + 'enabled = true',
    prefix + 'path = NodePath("' + track.path + '")',
    prefix + 'interp = ' + interp,
    prefix + 'loop_wrap = true',
    prefix + 'keys = {',
    '"times": PackedFloat32Array(' + times.map(n).join(', ') + '),',
    '"transitions": PackedFloat32Array(' + times.map(() => 1).join(', ') + '),',
    '"update": ' + (track.bool ? 1 : 0) + ',',
    '"values": [' + values.join(', ') + ']',
    '}',
  ].join('\n');
}

function writeAnimation(file, tracks) {
  const body = tracks.map((track, i) => serialize(track, i)).join('\n\n');
  const text = '[gd_resource type="Animation" format=3]\n\n[resource]\n'
    + 'resource_name = "idle"\nlength = 12.0\nloop_mode = 1\nstep = 0.033333\n'
    + body + '\n';
  fs.writeFileSync(path.join(root, file), text);
}

const baseTracks = boneTracks().concat(blinkTracks());
writeAnimation('animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v3.tres', baseTracks);
writeAnimation('animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v3_basin.tres',
  baseTracks.concat(basinTracks()));

// 记录本次改动涉及的尺寸、骨骼与眨眼区间，方便后续复现
const manifest = {
  animation: 'animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v3.tres',
  animation_basin: 'animation/character/zombie_boss/da_fei_yu/da_fei_yu_idle_left_v3_basin.tres',
  duration_seconds: DURATION,
  fps: FPS,
  sample_step: STEP,
  tracks: baseTracks.map(t => t.path),
  track_count: baseTracks.length,
  track_count_basin: baseTracks.length + 2,
  eye_layers: {
    texture_size: [348, 500],
    anchor_head: [BONES.Head.x, BONES.Head.y],
    sprite_local_position: [-BONES.Head.x, -BONES.Head.y],
    eye_box: [53, 166, 96, 208],
  },
  blink_windows: [
    { kind: 'normal', at: 1.2 },
    { kind: 'double', at: 5.45 },
    { kind: 'slow', at: 9.3 },
  ],
  beats: {
    tail_flick: [3.6, 4.3],
    head_tilt: [6.8, 8.05],
    basin_wobble: [10.1, 11.1],
  },
};
fs.writeFileSync(path.join(root, 'docs/art/bosses/da_fei_yu/idle_v3/rig_manifest.json'),
  JSON.stringify(manifest, null, 2) + '\n');

console.log('已生成 12 秒待机动画：基础版 ' + baseTracks.length + ' 条轨道，戴盆版 ' + (baseTracks.length + 2) + ' 条轨道。');
