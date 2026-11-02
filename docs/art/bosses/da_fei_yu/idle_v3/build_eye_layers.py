# -*- coding: utf-8 -*-
"""生成大肥鱼待机 v3 的眨眼图层（半闭 / 全闭）。

做法：不重画眼睛，只用肤色盖住“眼球本身”（虹膜 + 眼白），保留原图的睫毛与
下眼睑线。全闭时整块盖住，由原睫毛线充当闭眼线；半闭时只盖住上半部分，让眼球
看起来被上眼皮压住。

覆盖色按列取眼睛上下边缘附近的真实肤色做渐变，避免出现一块比脸更亮的补丁。
输出与角色贴图同尺寸、同原点的透明 PNG，可直接作为 Head 骨骼下的叠加精灵。
依赖：Pillow、numpy。用法：python build_eye_layers.py
"""

import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../../.."))
SRC = os.path.join(ROOT, "assets/image/character/boss/da_fei_yu/idle_left_v2/character.png")
OUT_DIR = os.path.join(ROOT, "assets/image/character/boss/da_fei_yu/idle_v3")
DEBUG_DIR = os.path.join(ROOT, "artifacts/art/da_fei_yu/idle_v3")

# 可见眼球的外轮廓（原图像素坐标）：上缘贴着睫毛下沿，下缘是下眼睑
EYE_OPENING = np.array([
    (54, 180), (57, 172), (63, 168), (70, 166), (76, 167), (82, 170),
    (88, 175), (93, 181), (96, 186), (93, 194), (87, 201), (79, 206),
    (71, 208), (63, 206), (57, 201), (54, 192), (53, 185),
], dtype=np.int32)

# 外扩一圈，用于取上下缘肤色
EYE_POLYGON = EYE_OPENING

# 睫毛内部种子点（沿上睫毛中线）
LASH_SEEDS = [(58, 172), (64, 167), (70, 165), (78, 166), (86, 170), (92, 176)]
LASH_MAX_Y = 184  # 睫毛最低不会超过这里，防止扩散跑进瞳孔

HALF_RATIO = 0.55  # 半闭时盖住眼球高度的比例
RING_OUTER = 4     # 取肤色时向外搜索的最大距离


def polygon_mask(size, pts=None):
    """把点列栅格化成蒙版。"""
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon([tuple(int(v) for v in p) for p in (EYE_OPENING if pts is None else pts)], fill=255)
    return np.array(m) > 127


def skin_like(rgb):
    """肤色判据：偏暖、有一定饱和度、不是纯白也不是蓝色。"""
    r, g, b = rgb[:, :, 0].astype(int), rgb[:, :, 1].astype(int), rgb[:, :, 2].astype(int)
    spread = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    return (r > 170) & (g > 120) & ((r - b) > 14) & ((r - g) > 5) & (spread > 13)


def eyeball_mask(rgb, poly):
    """眼球像素：轮廓内的蓝色虹膜与近白眼白。"""
    r, g, b = rgb[:, :, 0].astype(int), rgb[:, :, 1].astype(int), rgb[:, :, 2].astype(int)
    iris = (b - r > 40) & (b > 120)
    sclera = (r > 235) & (g > 225) & (b > 210)
    return poly & (iris | sclera)


def flood_lash(rgb, poly):
    """从种子点出发，在轮廓内沿近黑像素扩散，得到睫毛蒙版。"""
    lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
    dark = lum < 55
    h, w = dark.shape
    seen = np.zeros((h, w), bool)
    q = deque()
    for x, y in LASH_SEEDS:
        if poly[y, x] and dark[y, x]:
            q.append((y, x))
            seen[y, x] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if (0 <= ny < h and 0 <= nx < w and not seen[ny, nx]
                    and dark[ny, nx] and poly[ny, nx] and ny <= LASH_MAX_Y):
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def dilate(mask, radius, vertical_only=False):
    """方形结构元膨胀；vertical_only 时只向下生长。"""
    out = mask.copy()
    for _ in range(radius):
        src = out.copy()
        out[1:, :] |= src[:-1, :]
        if not vertical_only:
            out[:-1, :] |= src[1:, :]
            out[:, 1:] |= src[:, :-1]
            out[:, :-1] |= src[:, 1:]
    return out


def column_skin(rgb, skin, mask):
    """逐列取眼球上下最近肤色与位置；缺失列用邻列补齐后平滑。"""
    h, w = mask.shape
    top = np.zeros((w, 3), np.float32)
    bot = np.zeros((w, 3), np.float32)
    ty = np.zeros(w, np.float32)
    by = np.zeros(w, np.float32)
    ok = np.zeros(w, bool)
    for x in range(w):
        rows = np.where(mask[:, x])[0]
        if len(rows) == 0:
            continue
        y0, y1 = rows.min(), rows.max()
        above = np.where(skin[:, x] & (np.arange(h) < y0))[0]
        below = np.where(skin[:, x] & (np.arange(h) > y1))[0]
        if not len(above) or not len(below):
            continue
        if (y0 - above.max()) > RING_OUTER or (below.min() - y1) > RING_OUTER:
            continue
        top[x] = rgb[above.max(), x]
        bot[x] = rgb[below.min(), x]
        ty[x], by[x] = above.max(), below.min()
        ok[x] = True
    idx = np.where(ok)[0]
    if len(idx) == 0:
        raise RuntimeError("找不到可用肤色，检查眼睛轮廓与肤色判据")
    for x in range(w):
        if ok[x]:
            continue
        j = idx[np.argmin(np.abs(idx - x))]
        top[x], bot[x], ty[x], by[x] = top[j], bot[j], ty[j], by[j]
    for _ in range(3):
        for arr in (top, bot):
            arr[1:-1] = (arr[:-2] + 2 * arr[1:-1] + arr[2:]) / 4.0
        ty[1:-1] = (ty[:-2] + 2 * ty[1:-1] + ty[2:]) / 4.0
        by[1:-1] = (by[:-2] + 2 * by[1:-1] + by[2:]) / 4.0
    return top, bot, ty, by


def make_layer(base_rgb, fill_mask, poly, lid_edge=False):
    """生成叠加层：按列肤色渐变填充，边缘羽化，贴睫毛处略压暗。"""
    h, w = fill_mask.shape
    skin = skin_like(base_rgb)
    top, bot, ty, by = column_skin(base_rgb, skin, poly)
    rgb = base_rgb.astype(np.float32).copy()
    for x in range(w):
        rows = np.where(fill_mask[:, x])[0]
        if len(rows) == 0:
            continue
        t = np.clip((rows - ty[x]) / max(1.0, by[x] - ty[x]), 0, 1)[:, None]
        rgb[rows, x] = top[x] * (1 - t) + bot[x] * t

    rim = fill_mask & ~dilate(fill_mask, 2, vertical_only=True)
    rgb[rim] *= 0.97
    if lid_edge:
        # 半闭时把下缘压成一条很淡的眼皮线，避免像一块贴上去的色块
        edge = fill_mask & ~dilate(fill_mask, 1, vertical_only=True)
        edge = np.array(Image.fromarray((edge * 255).astype(np.uint8)).filter(
            ImageFilter.GaussianBlur(0.4))) > 40
        rgb[edge] = rgb[edge] * 0.82 + np.array([150, 120, 112], np.float32) * 0.18

    out = np.zeros((h, w, 4), np.uint8)
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    alpha = (fill_mask * 255).astype(np.uint8)
    out[:, :, 3] = np.array(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.5)))
    return Image.fromarray(out, "RGBA")


def main():
    base = Image.open(SRC).convert("RGBA")
    base_rgb = np.array(base)[:, :, :3].astype(np.uint8)
    size = (base.width, base.height)
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(DEBUG_DIR, exist_ok=True)

    poly = polygon_mask(size)
    ball = poly

    # 半闭：每列从眼球上缘往下盖住固定比例
    half_fill = np.zeros_like(ball)
    for x in np.where(ball.any(axis=0))[0]:
        rows = np.where(ball[:, x])[0]
        cut = int(rows.min() + HALF_RATIO * (rows.max() - rows.min()))
        half_fill[rows[rows <= cut], x] = True

    half = make_layer(base_rgb, half_fill, poly, lid_edge=True)
    closed = make_layer(base_rgb, ball, poly)
    half.save(os.path.join(OUT_DIR, "eye_half.png"))
    closed.save(os.path.join(OUT_DIR, "eye_closed.png"))

    panels = []
    for layer in (None, half, closed):
        comp = base.copy()
        if layer is not None:
            comp.alpha_composite(layer)
        crop = comp.crop((45, 155, 105, 215)).resize((420, 420), Image.LANCZOS)
        bg = Image.new("RGBA", crop.size, (235, 240, 248, 255))
        bg.alpha_composite(crop)
        panels.append(bg)
    sheet = Image.new("RGBA", (sum(p.width for p in panels), 420), (235, 240, 248, 255))
    x = 0
    for p in panels:
        sheet.alpha_composite(p, (x, 0))
        x += p.width
    sheet.save(os.path.join(DEBUG_DIR, "eye_states.png"))
    print("已生成 eye_half.png / eye_closed.png；对比图 artifacts/art/da_fei_yu/idle_v3/eye_states.png")


if __name__ == "__main__":
    main()
