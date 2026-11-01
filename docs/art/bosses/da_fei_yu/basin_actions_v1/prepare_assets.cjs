// 将内置 imagegen 的透明图集机械裁切、统一尺寸；不修改角色绘画内容。
const fs = require('fs'); // 保存项目中的素材归档和导出贴图。
const path = require('path'); // 将脚本目录转换为项目绝对路径。
const sharp = require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 仅做机械裁切与等比缩放。
const root = path.resolve(__dirname, '../../../../..'); // 仓库根目录。
const output = path.join(root, 'assets/image/character/boss/da_fei_yu/basin_actions_v1'); // Godot 消费的透明贴图目录。
const generated = 'C:/Users/QiQi/.codex/generated_images/01a1818b-82d4-7ac3-8736-0a614f7836f2'; // 首次生成时的内置工具输出目录。
async function main() {
  fs.mkdirSync(output, {recursive:true});
  if (!fs.existsSync(path.join(__dirname,'poses_source.png'))) fs.copyFileSync(path.join(generated,'exec-94838628-a4a7-4f21-9cb0-962d112eb643.png'),path.join(__dirname,'poses_source.png'));
  if (!fs.existsSync(path.join(__dirname,'props_source.png'))) fs.copyFileSync(path.join(generated,'exec-52c19482-ebd4-4cb7-af6c-ee050ef53aec.png'),path.join(__dirname,'props_source.png'));
  const poseMeta = await sharp(path.join(__dirname,'poses_source.png')).metadata(); // 原始四姿势图集的尺寸。
  console.log({poseMeta});
  for (let index=0;index<4;index++) { // 按取盆、端盆、蓄力、丢盆依次裁切。
    const width=Math.floor(poseMeta.width/2), height=Math.floor(poseMeta.height/2); // 单格像素尺寸。
    const cell=await sharp(path.join(__dirname,'poses_source.png')).extract({left:(index%2)*width,top:Math.floor(index/2)*height,width,height}).png().toBuffer(); // 独立格子，先提取再裁透明边。
    const buffer=await sharp(cell).trim({threshold:5}).resize({height:500}).png().toBuffer(); // 统一为与基础角色相同的 500 像素高度。
    await sharp(buffer).toFile(path.join(output,['reach','hold','angry','throw'][index]+'.png'));
    console.log(index, await sharp(buffer).metadata());
  }
  const propMeta=await sharp(path.join(__dirname,'props_source.png')).metadata(); // 空盆与米饭盆图集的尺寸。
  for(let index=0;index<2;index++) { // 左格空盆、右格米饭盆。
    const cell=await sharp(path.join(__dirname,'props_source.png')).extract({left:index*Math.floor(propMeta.width/2),top:0,width:Math.floor(propMeta.width/2),height:propMeta.height}).png().toBuffer(); // 当前独立道具格子。
    await sharp(cell).trim({threshold:5}).resize({width:268}).png().toFile(path.join(output,index===0?'empty_basin.png':'rice_basin.png'));
  }
  const corrected=path.join(__dirname,'reach_corrected_source.png'); // 用户红框指定修正后的取盆图，覆盖有多余手的初稿。
  if (!fs.existsSync(corrected)) fs.copyFileSync(path.join(generated,'exec-8692ce6b-3405-417f-9875-7a92bc71c3d4.png'),corrected);
  await sharp(corrected).trim({threshold:5}).resize({height:500}).png().toFile(path.join(output,'reach.png'));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
