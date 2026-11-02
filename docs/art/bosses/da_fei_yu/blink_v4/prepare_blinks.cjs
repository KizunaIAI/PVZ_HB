// 仅归档、裁切和等比适配内置 imagegen 重画的眼睑关键帧，不程序绘制或覆盖眼球。
const fs=require('fs'); // 读取生成原图和保存派生贴图。
const path=require('path'); // 定位仓库与内置工具输出。
const sharp=require('C:/Users/QiQi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); // 只做图集分格与尺寸适配。
const root=path.resolve(__dirname,'../../../../..'); // 仓库根目录。
const generated='C:/Users/QiQi/.codex/generated_images/01a1818b-82d4-7ac3-8736-0a614f7836f2'; // 内置工具保存目录。
const output=path.join(root,'assets/image/character/boss/da_fei_yu/blink_v4'); // 游戏使用的局部眼睑贴图。
const entries=[ // 每个姿势的原图及人工对齐的源裁切、目标眼部矩形。
 {name:'standing',file:'exec-ddaefe31-db9c-4258-9825-0bab4d48f521.png',crop:[32,19,55,53],target:[48,158,54,64]},
 {name:'reach',file:'exec-521a6c02-1c72-4c65-aa53-f58629d04495.png',crop:[36,19,54,42],target:[52,150,60,62]},
 {name:'hold',file:'exec-2e6e0ffd-0188-439a-b50e-e9d855cf5267.png',crop:[36,20,56,52],target:[75,157,60,65]},
 {name:'angry',file:'exec-00fa74e0-3765-4caa-b600-6fbd9f43bda0.png',crop:[37,30,58,48],target:[75,167,64,58]},
 {name:'throw',file:'exec-f15a1b78-16cb-4bd9-a966-3a3b3a4a3d7c.png',crop:[24,34,60,52],target:[116,183,64,62]}
];
async function main(){
 fs.mkdirSync(output,{recursive:true});
 for(const entry of entries){ // 五个姿势各自两帧，避免把同一只眼生硬套到不同透视。
  const archived=path.join(__dirname,entry.name+'_source.png'); // 保存项目内的生成原图，后续无需依赖工具缓存。
  if(!fs.existsSync(archived))fs.copyFileSync(path.join(generated,entry.file),archived);
  const meta=await sharp(archived).metadata(); // 两列图集的实际分辨率。
  for(let state=0;state<2;state++){ // 左格半闭、右格全闭。
   const cell=await sharp(archived).extract({left:Math.floor(meta.width/2)*state,top:0,width:Math.floor(meta.width/2),height:meta.height}).resize(110,115,{fit:'fill'}).png().toBuffer(); // 回到参考脸部裁切坐标。
   const [left,top,width,height]=entry.crop; // 只提取包含运动睫毛及眼睑的区域。
   await sharp(cell).extract({left,top,width,height}).resize(entry.target[2],entry.target[3],{fit:'fill'}).png().toFile(path.join(output,entry.name+'_'+(state?'closed':'half')+'.png'));
  }
 }
 fs.writeFileSync(path.join(__dirname,'manifest.json'),JSON.stringify(entries,null,2)+'\n');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
