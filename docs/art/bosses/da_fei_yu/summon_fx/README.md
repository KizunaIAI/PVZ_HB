# 大肥鱼召唤法阵

素材：Luke.RUSTLTD，4 summoning circles，circle6.svg。
来源：https://opengameart.org/content/4-summoning-circles
下载：https://opengameart.org/sites/default/files/summoning_circles.zip
许可：CC0（页面确认，2026-11-02）。source目录由.gdignore隔离，保留下载原包与源文件。

运行SVG原样复制；Godot材质将符文渲染为蓝青发光色，UV旋转后以120×48像素贴地显示。每只真实召唤僵尸脚底播放1.45原速秒，快速亮起后淡出；宿主死亡/删除立即清理，个体冻结和全局暂停同步。

逐帧观察：尾巴在约3秒后上抬，3.25秒明显翘起。召唤结算从第36帧改到第78帧（零基，24FPS），创建僵尸与法阵同帧触发。生成脚本同步修改，重建素材不会回退旧时点。

未新增或运行测试；动作/法阵预览仅检查显示，不代替战斗回归。
