# 大肥鱼：钢盆头部配件

按照用户提供的 [不锈钢盆照片](reference.webp)，新增倒扣佩戴的银灰色钢盆。保留盆体外扩侧壁、上方平底和下沿卷边，使用适合现有角色的金属高光与轮廓。

## 查看

- [实际预览截图](preview.png)与[四秒待机动图](steel_basin_preview.gif)。
- [钢盆版 Godot 预览场景](../../../../../scenes/art_preview/da_fei_yu_steel_basin_preview.tscn)：打开后按 F6，可暂停、半速或重播。
- [常用左向入口](../../../../../scenes/art_preview/da_fei_yu_idle_left_preview.tscn)现引用钢盆版。
- [完整界面录像](../../../../../artifacts/art/da_fei_yu/steel_basin_preview.mp4)：1066 × 600，三十帧每秒。

## 素材及装配

- 配件由内置 imagegen 生成；[原始生成图](basin_source.png)与[完整提示词](prompt.txt)。
- 导出的透明 PNG 位于 `res://assets/image/character/boss/da_fei_yu/steel_basin_v1/basin.png`，尺寸 245 × 103 像素；沿用项目已有的 assets 忽略规则，本目录保留重建源图。
- [钢盆外观场景](../../../../../scenes/character/zombie_boss/da_fei_yu/da_fei_yu_steel_basin_visual.tscn)继承既有左向骨骼角色，新增一个 `SteelBasin` 精灵子节点，挂在 `Rig/Skeleton2D/Head` 下。
- 钢盆随头部现有位移和旋转一起运动，保持盆体刚性；盆沿遮住头顶和呆毛，眼睛及侧面发饰仍然可见。
- 仅增加美术配件，不修改基础角色贴图、身体比例、网格权重和待机轨道。
- [装配记录](attachment.json)保存参考坐标、配件尺寸与骨骼局部偏移。
- [本地导出工具](build_steel_basin.cjs)使用本机已有 Sharp 依赖，可在仓库根目录执行 `node docs/art/bosses/da_fei_yu/steel_basin_v1/build_steel_basin.cjs` 重建配件和预览。若先重建了基础骨骼版本，再运行此工具即可恢复钢盆版的常用入口。

## 运行记录

已单独运行 Godot 钢盆版场景，录制四秒、三十帧每秒的画面，查看静止形象及循环中四个时刻的佩戴位置。运行日志未见脚本或资源加载错误。未新增或运行自动化测试，未添加护甲数值或战斗逻辑。
